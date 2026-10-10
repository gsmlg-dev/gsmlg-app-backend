#!/usr/bin/env python3
"""Verify published indexes, consumer pulls, and public release startup.

Requires an authenticated Docker CLI, Buildx, and QEMU for foreign-platform
startup. It creates only uniquely named public smoke containers and removes
them before returning. Run this in a fresh consumer job after publication.
"""

import argparse
import json
import re
import secrets
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid


PLATFORMS = ("linux/amd64", "linux/arm64")
TARGETS = {
    "backend": ("", "gsmlg_app_backend"),
    "admin": ("-admin", "gsmlg_app_admin"),
    "public": ("-public", "gsmlg_app"),
}
SECRET_NAMES = ("SECRET_KEY_BASE", "ADMIN_SECRET_KEY_BASE", "TOKEN_SIGNING_SECRET")


class VerificationError(RuntimeError):
    """A published image failed a consumer acceptance check."""


def redact(text, values):
    for value in values:
        text = text.replace(value, "[redacted]")
    return text


class Docker:
    """Use Docker's existing registry authentication and consumer transport."""

    def run(self, arguments, *, timeout=60, check=True):
        secret_values = [
            argument.split("=", 1)[1]
            for argument in arguments
            if any(argument.startswith(name + "=") for name in SECRET_NAMES)
        ]
        try:
            result = subprocess.run(
                ["docker", *arguments], capture_output=True, text=True, timeout=timeout
            )
        except subprocess.TimeoutExpired as error:
            raise VerificationError(
                f"docker {arguments[0]} timed out after {timeout}s"
            ) from error
        except OSError as error:
            raise VerificationError(f"cannot execute docker: {error}") from error
        if check and result.returncode:
            detail = redact(result.stderr.strip() or result.stdout.strip(), secret_values)
            raise VerificationError(f"docker {arguments[0]} failed: {detail}")
        if arguments[0] == "logs":
            return result.stdout + result.stderr
        return result.stdout


def read_json(docker, arguments):
    output = docker.run(arguments)
    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        raise VerificationError(f"invalid JSON from docker {arguments[0]}") from error


def manifest(docker, reference):
    document = read_json(docker, ["buildx", "imagetools", "inspect", reference, "--raw"])
    if not isinstance(document, dict):
        raise VerificationError(f"{reference}: expected a manifest object")
    return document


def require_digest(descriptor, reference):
    value = descriptor.get("digest", "") if isinstance(descriptor, dict) else ""
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", value):
        raise VerificationError(f"{reference}: missing or invalid content digest")
    return value


def platform_children(index, reference):
    children = {}
    entries = index.get("manifests")
    if not isinstance(entries, list):
        raise VerificationError(f"{reference}: expected a multi-platform index")
    for entry in entries:
        platform = entry.get("platform", {})
        name = f"{platform.get('os')}/{platform.get('architecture')}"
        annotations = entry.get("annotations") or {}
        if (
            name == "unknown/unknown"
            and annotations.get("vnd.docker.reference.type") == "attestation-manifest"
        ):
            continue
        if name not in PLATFORMS:
            raise VerificationError(f"{reference}: unexpected platform descriptor {name}")
        if name in children:
            raise VerificationError(f"{reference}: duplicate {name} child")
        children[name] = require_digest(entry, reference)
    missing = set(PLATFORMS) - children.keys()
    if missing:
        raise VerificationError(f"{reference}: missing {', '.join(sorted(missing))} child")
    return children


def verify_children(docker, repository, index, version, source_sha, release):
    verified = {}
    for platform, child_digest in platform_children(index, repository).items():
        reference = f"{repository}@{child_digest}"
        child = manifest(docker, reference)
        config_digest = require_digest(child.get("config"), reference)
        layers = child.get("layers")
        if not isinstance(layers, list) or not layers:
            raise VerificationError(f"{reference}: missing filesystem layers")
        for layer in layers:
            require_digest(layer, reference)

        # In a fresh consumer job this fetches and verifies the config and every
        # layer, detecting missing blobs that an existing index cannot expose.
        docker.run(["pull", "--platform", platform, reference], timeout=600)
        images = read_json(docker, ["image", "inspect", reference])
        if not isinstance(images, list) or len(images) != 1:
            raise VerificationError(f"{reference}: expected one pulled image config")
        image = images[0]
        if image.get("Id") != config_digest:
            raise VerificationError(f"{reference}: pulled config differs from child manifest")
        if f"{image.get('Os')}/{image.get('Architecture')}" != platform:
            raise VerificationError(f"{reference}: pulled platform differs from index")
        config = image.get("Config") or {}
        labels = config.get("Labels") or {}
        if labels.get("RELEASE_VERSION") != version:
            raise VerificationError(f"{reference}: RELEASE_VERSION differs from {version}")
        if labels.get("org.opencontainers.image.revision") != source_sha:
            raise VerificationError(f"{reference}: source revision differs from {source_sha}")
        expected_command = [f"/app/bin/{release}", "start"]
        if config.get("Cmd") != expected_command:
            raise VerificationError(f"{reference}: Cmd differs from {expected_command}")
        verified[platform] = reference
    return verified


def verify_images(docker, repository, version, source_sha, *, target="all", public_repository=None):
    """Verify selected variants and return their exact runnable child references."""
    selected = TARGETS if target == "all" else {target: TARGETS[target]}
    verified = {}
    for name, (suffix, release) in selected.items():
        reference = f"{repository}:{version}{suffix}"
        index = manifest(docker, reference)
        latest_reference = f"{repository}:latest{suffix}"
        if index != manifest(docker, latest_reference):
            raise VerificationError(f"{latest_reference}: latest index differs from {reference}")
        verified[name] = verify_children(
            docker, repository, index, version, source_sha, release
        )
        if name == "public" and public_repository:
            for tag in (version, "latest"):
                alias_reference = f"{public_repository}:{tag}"
                if index != manifest(docker, alias_reference):
                    raise VerificationError(f"{alias_reference}: public alias index differs from {reference}")
            verified["public_alias"] = verify_children(
                docker, public_repository, index, version, source_sha, release
            )
    return verified


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, _request, _response, _code, _message, _headers, _url):
        return None


def smoke_public(docker, reference, platform, *, readiness_timeout=120, poll_interval=1):
    """Boot a public release without a database and always remove its container."""
    name = "gsmlg-release-smoke-" + uuid.uuid4().hex[:16]
    environment = {key: secrets.token_urlsafe(64) for key in SECRET_NAMES}
    environment.update(
        DATABASE_URL="ecto://release:release@127.0.0.1/release",
        PORT="4152",
        ADMIN_PORT="4153",
        PHX_SERVER="true",
    )
    arguments = [
        "run", "--detach", "--name", name, "--platform", platform,
        "--pull", "never", "--publish", "127.0.0.1::4152",
    ]
    for key, value in environment.items():
        arguments.extend(["--env", f"{key}={value}"])
    arguments.append(reference)
    failure = None
    try:
        docker.run(arguments)
        address = docker.run(["port", name, "4152/tcp"], timeout=10).strip()
        if not re.fullmatch(r"127\.0\.0\.1:[0-9]+", address):
            raise VerificationError(f"{name}: expected a localhost-only published port")
        opener = urllib.request.build_opener(NoRedirect)
        deadline = time.monotonic() + readiness_timeout
        while time.monotonic() < deadline:
            state = docker.run(
                ["inspect", "--format", "{{.State.Status}}", name], timeout=5
            ).strip()
            if state != "running":
                raise VerificationError(f"{reference} ({platform}): container {state} before HTTP readiness")
            try:
                remaining = max(0.001, deadline - time.monotonic())
                with opener.open(f"http://{address}/", timeout=min(2, remaining)) as response:
                    if response.status == 200:
                        break
            except (urllib.error.URLError, TimeoutError, OSError):
                pass
            time.sleep(min(poll_interval, max(0, deadline - time.monotonic())))
        else:
            raise VerificationError(f"{reference} ({platform}): HTTP readiness timed out after {readiness_timeout}s")
    except BaseException as error:
        failure = error
    finally:
        if failure:
            try:
                logs = docker.run(["logs", "--tail", "80", name], timeout=10, check=False)
                print(redact(logs, (environment[key] for key in SECRET_NAMES)), file=sys.stderr)
            except VerificationError:
                pass
        try:
            docker.run(["rm", "--force", name], timeout=30)
        except VerificationError as cleanup_error:
            if "No such container" not in str(cleanup_error):
                if failure:
                    raise VerificationError(f"{failure}; cleanup failed: {cleanup_error}") from failure
                raise
    if failure:
        raise failure


def repository_argument(value):
    if not re.fullmatch(r"[a-z0-9.-]+(?::[0-9]+)?/[a-z0-9._/-]+", value):
        raise argparse.ArgumentTypeError("expected a registry/repository without a tag or digest")
    return value


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True, type=repository_argument)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--public-repository", type=repository_argument)
    parser.add_argument("--target", choices=("all", *TARGETS), default="all")
    parser.add_argument("--readiness-timeout", type=float, default=120)
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}", args.version):
        parser.error("version must be a valid image tag")
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha):
        parser.error("source-sha must be the exact 40-character Git commit SHA")
    if not 0 < args.readiness_timeout <= 600:
        parser.error("readiness-timeout must be between 0 and 600 seconds")
    docker = Docker()
    images = verify_images(
        docker, args.repository, args.version, args.source_sha,
        target=args.target, public_repository=args.public_repository,
    )
    started = []
    for name in ("public", "public_alias"):
        for platform, reference in images.get(name, {}).items():
            smoke_public(docker, reference, platform, readiness_timeout=args.readiness_timeout)
            started.append({"target": name, "platform": platform, "image": reference})
    print(json.dumps({"version": args.version, "source_sha": args.source_sha,
                      "verified_images": images, "started_public_images": started}))
    return 0


if __name__ == "__main__":
    def interrupted(_signal, _frame):
        raise KeyboardInterrupt("verification interrupted")

    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(main())
    except VerificationError as error:
        print(f"release image verification failed: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("release image verification interrupted", file=sys.stderr)
        sys.exit(130)
