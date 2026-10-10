"""Regression checks for the published-image consumer gate."""

import copy
import contextlib
import hashlib
import http.server
import io
import json
import subprocess
import threading
import unittest
from unittest import mock

import verify_release_images as verifier


REPOSITORY = "ghcr.io/example/backend"
ALIAS = "ghcr.io/example/public"
VERSION = "1.2.3"
SHA = "a" * 40


def digest(value):
    return "sha256:" + hashlib.sha256(value.encode()).hexdigest()


class PublishedImages:
    """Registry and Docker responses for six independently published images."""

    def __init__(self):
        self.manifests = {}
        self.images = {}
        self.pulls = []
        for suffix, release in (
            ("", "gsmlg_app_backend"),
            ("-admin", "gsmlg_app_admin"),
            ("-public", "gsmlg_app"),
        ):
            entries = []
            for architecture in ("amd64", "arm64"):
                child_digest = digest(suffix + architecture)
                reference = REPOSITORY + "@" + child_digest
                config_digest = digest("config" + suffix + architecture)
                self.manifests[reference] = {
                    "schemaVersion": 2,
                    "config": {"digest": config_digest},
                    "layers": [{"digest": digest("layer" + suffix + architecture)}],
                }
                self.images[reference] = {
                    "Id": config_digest,
                    "Architecture": architecture,
                    "Os": "linux",
                    "Config": {
                        "Cmd": ["/app/bin/" + release, "start"],
                        "Labels": {
                            "RELEASE_VERSION": VERSION,
                            "org.opencontainers.image.revision": SHA,
                        },
                    },
                }
                entries.append(
                    {
                        "digest": child_digest,
                        "platform": {"os": "linux", "architecture": architecture},
                    }
                )
            index = {"schemaVersion": 2, "manifests": entries}
            for tag in (VERSION + suffix, "latest" + suffix):
                self.manifests[REPOSITORY + ":" + tag] = copy.deepcopy(index)
        public = self.manifests[REPOSITORY + ":" + VERSION + "-public"]
        for tag in (VERSION, "latest"):
            self.manifests[ALIAS + ":" + tag] = copy.deepcopy(public)
        for entry in public["manifests"]:
            original = REPOSITORY + "@" + entry["digest"]
            alias = ALIAS + "@" + entry["digest"]
            self.manifests[alias] = copy.deepcopy(self.manifests[original])
            self.images[alias] = copy.deepcopy(self.images[original])

    def run(self, arguments, *, timeout=60, check=True):
        if arguments[:3] == ["buildx", "imagetools", "inspect"]:
            reference = arguments[3]
            if reference not in self.manifests:
                raise verifier.VerificationError("MANIFEST_UNKNOWN: " + reference)
            return json.dumps(self.manifests[reference])
        if arguments[0] == "pull":
            reference = arguments[-1]
            self.pulls.append((arguments[2], reference))
            if reference not in self.images:
                raise verifier.VerificationError("blob unknown: " + reference)
            return "Downloaded newer image"
        if arguments[:2] == ["image", "inspect"]:
            return json.dumps([self.images[arguments[-1]]])
        raise AssertionError("Unexpected Docker command: " + repr(arguments))


class ImageVerificationTests(unittest.TestCase):
    def setUp(self):
        self.docker = PublishedImages()

    def verify(self, **options):
        return verifier.verify_images(
            self.docker, REPOSITORY, VERSION, SHA, **options
        )

    def child(self, suffix="-public", architecture="amd64", repository=REPOSITORY):
        return repository + "@" + digest(suffix + architecture)

    def test_every_variant_and_architecture_is_pulled_by_exact_child_digest(self):
        images = self.verify()
        self.assertEqual(set(images), {"backend", "admin", "public"})
        self.assertEqual(len(self.docker.pulls), 6)
        self.assertEqual({p for p, _ in self.docker.pulls}, {"linux/amd64", "linux/arm64"})
        self.assertTrue(all("@sha256:" in ref for _, ref in self.docker.pulls))

    def test_existing_index_with_missing_child_is_rejected(self):
        del self.docker.manifests[self.child()]
        with self.assertRaisesRegex(verifier.VerificationError, "MANIFEST_UNKNOWN"):
            self.verify(target="public")

    def test_wrong_public_release_command_is_rejected(self):
        self.docker.images[self.child()]["Config"]["Cmd"] = [
            "/app/bin/gsmlg_app_backend", "start"
        ]
        with self.assertRaisesRegex(verifier.VerificationError, "Cmd"):
            self.verify(target="public")

    def test_stale_latest_index_is_rejected_before_pulling(self):
        self.docker.manifests[REPOSITORY + ":latest-public"]["manifests"].pop()
        with self.assertRaisesRegex(verifier.VerificationError, "latest"):
            self.verify(target="public")
        self.assertFalse(self.docker.pulls)

    def test_public_alias_mismatch_is_rejected(self):
        self.docker.manifests[ALIAS + ":latest"]["manifests"].pop()
        with self.assertRaisesRegex(verifier.VerificationError, "alias"):
            self.verify(target="public", public_repository=ALIAS)

    def test_public_alias_children_are_also_pulled(self):
        images = self.verify(target="public", public_repository=ALIAS)
        self.assertEqual(set(images), {"public", "public_alias"})
        self.assertEqual(len(self.docker.pulls), 4)
        self.assertEqual(sum(ref.startswith(ALIAS + "@") for _, ref in self.docker.pulls), 2)

    def test_missing_layer_fails_even_when_index_and_child_exist(self):
        del self.docker.images[self.child()]
        with self.assertRaisesRegex(verifier.VerificationError, "blob unknown"):
            self.verify(target="public")

    def test_wrong_source_revision_is_rejected(self):
        self.docker.images[self.child()]["Config"]["Labels"][
            "org.opencontainers.image.revision"
        ] = "b" * 40
        with self.assertRaisesRegex(verifier.VerificationError, "revision"):
            self.verify(target="public")

    def test_pulled_config_must_match_child_manifest(self):
        self.docker.images[self.child()]["Id"] = digest("unrelated config")
        with self.assertRaisesRegex(verifier.VerificationError, "config"):
            self.verify(target="public")

    def test_both_platforms_are_required(self):
        for tag in (VERSION + "-public", "latest-public"):
            self.docker.manifests[REPOSITORY + ":" + tag]["manifests"].pop()
        with self.assertRaisesRegex(verifier.VerificationError, "arm64"):
            self.verify(target="public")

    def add_public_descriptor(self, platform, annotations=None):
        descriptor = {"digest": digest("extra descriptor"), "platform": platform}
        if annotations is not None:
            descriptor["annotations"] = annotations
        for tag in (VERSION + "-public", "latest-public"):
            self.docker.manifests[REPOSITORY + ":" + tag]["manifests"].append(
                copy.deepcopy(descriptor)
            )

    def test_identified_buildx_attestation_is_allowed(self):
        self.add_public_descriptor(
            {"os": "unknown", "architecture": "unknown"},
            {"vnd.docker.reference.type": "attestation-manifest"},
        )
        images = self.verify(target="public")
        self.assertEqual(set(images["public"]), {"linux/amd64", "linux/arm64"})
        self.assertEqual(len(self.docker.pulls), 2)

    def test_extra_runnable_platform_is_rejected(self):
        self.add_public_descriptor({"os": "linux", "architecture": "s390x"})
        with self.assertRaisesRegex(verifier.VerificationError, "unexpected.*linux/s390x"):
            self.verify(target="public")
        self.assertFalse(self.docker.pulls)

    def test_unidentified_unknown_descriptor_is_rejected(self):
        self.add_public_descriptor({"os": "unknown", "architecture": "unknown"})
        with self.assertRaisesRegex(verifier.VerificationError, "unexpected.*unknown/unknown"):
            self.verify(target="public")

    def test_attestation_annotation_cannot_hide_a_runnable_extra_platform(self):
        self.add_public_descriptor(
            {"os": "linux", "architecture": "s390x"},
            {"vnd.docker.reference.type": "attestation-manifest"},
        )
        with self.assertRaisesRegex(verifier.VerificationError, "unexpected.*linux/s390x"):
            self.verify(target="public")

    def test_cli_starts_both_public_repositories_on_both_platforms(self):
        output = io.StringIO()
        with mock.patch.object(verifier, "Docker", return_value=self.docker), mock.patch.object(
            verifier, "smoke_public"
        ) as smoke, contextlib.redirect_stdout(output):
            status = verifier.main([
                "--repository", REPOSITORY, "--version", VERSION,
                "--source-sha", SHA, "--target", "public",
                "--public-repository", ALIAS,
            ])
        self.assertEqual(status, 0)
        started = {(call.args[2], call.args[1]) for call in smoke.call_args_list}
        self.assertEqual(started, set(self.docker.pulls))
        self.assertEqual(len(started), 4)
        self.assertEqual(len(json.loads(output.getvalue())["started_public_images"]), 4)

    def test_backend_target_pulls_only_backend_and_does_not_start_public(self):
        with mock.patch.object(verifier, "Docker", return_value=self.docker), mock.patch.object(
            verifier, "smoke_public"
        ) as smoke, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(verifier.main([
                "--repository", REPOSITORY, "--version", VERSION,
                "--source-sha", SHA, "--target", "backend",
                "--public-repository", ALIAS,
            ]), 0)
        self.assertEqual(len(self.docker.pulls), 2)
        smoke.assert_not_called()


class SmokeDocker:
    def __init__(self, address, *, fail_start=False, fail_cleanup=False):
        self.address = address
        self.fail_start = fail_start
        self.fail_cleanup = fail_cleanup
        self.containers = set()
        self.removed = []
        self.start_arguments = []
        self.state = "running"

    def run(self, arguments, *, timeout=60, check=True):
        if arguments[0] == "run":
            self.start_arguments = arguments
            name = arguments[arguments.index("--name") + 1]
            self.containers.add(name)
            if self.fail_start:
                raise verifier.VerificationError("consumer startup failed")
            return "container-id"
        if arguments[0] == "port":
            return self.address
        if arguments[0] == "inspect":
            return self.state
        if arguments[0] == "logs":
            return "consumer logs"
        if arguments[0] == "rm":
            name = arguments[-1]
            self.removed.append(name)
            if self.fail_cleanup:
                raise verifier.VerificationError("cannot remove consumer container")
            self.containers.discard(name)
            return name
        raise AssertionError(arguments)


class SmokeTests(unittest.TestCase):
    def setUp(self):
        self.status = 200
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(owner.status)
                if owner.status == 302:
                    self.send_header("Location", "http://example.invalid/")
                self.end_headers()
                self.wfile.write(b"release readiness")

            def log_message(self, *_arguments):
                pass

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.docker = SmokeDocker("127.0.0.1:" + str(self.server.server_port))

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def smoke(self):
        with contextlib.redirect_stderr(io.StringIO()):
            return verifier.smoke_public(
                self.docker, REPOSITORY + "@" + digest("public"), "linux/arm64",
                readiness_timeout=0.04, poll_interval=0.005,
            )

    def test_ready_consumer_is_removed_and_has_required_runtime_secrets(self):
        self.smoke()
        self.assertFalse(self.docker.containers)
        self.assertEqual(len(self.docker.removed), 1)
        args = self.docker.start_arguments
        environment = dict(item.split("=", 1) for item in args if "=" in item)
        for key in ("SECRET_KEY_BASE", "ADMIN_SECRET_KEY_BASE", "TOKEN_SIGNING_SECRET"):
            self.assertGreaterEqual(len(environment[key]), 64)
        self.assertIn("DATABASE_URL", environment)
        self.assertEqual(args[args.index("--platform") + 1], "linux/arm64")
        self.assertIn("127.0.0.1::4152", args)

    def test_http_failure_is_bounded_and_removes_consumer(self):
        self.status = 503
        with self.assertRaisesRegex(verifier.VerificationError, "readiness"):
            self.smoke()
        self.assertFalse(self.docker.containers)
        self.assertEqual(len(self.docker.removed), 1)

    def test_redirect_cannot_pass_readiness_using_another_site(self):
        self.status = 302
        with self.assertRaisesRegex(verifier.VerificationError, "readiness"):
            self.smoke()
        self.assertFalse(self.docker.containers)

    def test_partially_started_container_is_removed_after_start_failure(self):
        self.docker.fail_start = True
        with self.assertRaisesRegex(verifier.VerificationError, "startup failed"):
            self.smoke()
        self.assertFalse(self.docker.containers)

    def test_cleanup_failure_prevents_a_successful_gate(self):
        self.docker.fail_cleanup = True
        with self.assertRaisesRegex(verifier.VerificationError, "remove"):
            self.smoke()
        self.assertEqual(len(self.docker.removed), 1)

    def test_crashed_consumer_is_rejected_and_removed(self):
        self.docker.state = "exited"
        with self.assertRaisesRegex(verifier.VerificationError, "exited"):
            self.smoke()
        self.assertFalse(self.docker.containers)

    def test_cleanup_failure_preserves_the_original_readiness_error(self):
        self.status = 503
        self.docker.fail_cleanup = True
        with self.assertRaisesRegex(verifier.VerificationError, "readiness.*cleanup failed"):
            self.smoke()


class DockerTransportTests(unittest.TestCase):
    def test_timeout_error_does_not_include_runtime_secrets(self):
        secret = "generated-secret-that-must-not-be-printed"
        args = ["run", "--env", "SECRET_KEY_BASE=" + secret, "image"]
        with mock.patch.object(verifier.subprocess, "run", side_effect=subprocess.TimeoutExpired(args, 1)):
            with self.assertRaises(verifier.VerificationError) as error:
                verifier.Docker().run(args, timeout=1)
        self.assertIn("timed out", str(error.exception))
        self.assertNotIn(secret, str(error.exception))

    def test_docker_failure_redacts_a_secret_echoed_in_stderr(self):
        secret = "generated-secret-that-must-not-be-printed"
        args = ["run", "--env", "SECRET_KEY_BASE=" + secret, "image"]
        result = subprocess.CompletedProcess(args, 1, "", "failure: " + secret)
        with mock.patch.object(verifier.subprocess, "run", return_value=result):
            with self.assertRaises(verifier.VerificationError) as error:
                verifier.Docker().run(args)
        self.assertIn("[redacted]", str(error.exception))
        self.assertNotIn(secret, str(error.exception))


if __name__ == "__main__":
    unittest.main()
