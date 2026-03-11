{
  description = "GSMLG App Backend — Elixir Phoenix umbrella (public:4152 + admin:4153)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        lib = pkgs.lib;

        # Match devenv: Erlang/OTP 27 + Elixir 1.18
        beamPackages = pkgs.beam.packages.erlang_27;
        elixir = beamPackages.elixir_1_18;

        version = "1.0.0";
        tailwindVersion = "4.1.11";

        # ---------------------------------------------------------------------------
        # Tailwind CSS v4 standalone binary (fetched from GitHub releases as FOD)
        #
        # Fill hashes with:
        #   nix-prefetch-url --type sha256 \
        #     https://github.com/tailwindlabs/tailwindcss/releases/download/v4.1.11/tailwindcss-linux-x64
        # ---------------------------------------------------------------------------
        tailwindcssBin =
          let
            platforms = {
              "x86_64-linux"  = { suffix = "linux-x64";    hash = lib.fakeHash; };
              "aarch64-linux" = { suffix = "linux-arm64";   hash = lib.fakeHash; };
              "x86_64-darwin" = { suffix = "macos-x64";     hash = lib.fakeHash; };
              "aarch64-darwin"= { suffix = "macos-arm64";   hash = lib.fakeHash; };
            };
            p = platforms.${system} or (throw "Tailwind CSS unsupported on ${system}");
          in
          pkgs.stdenvNoCC.mkDerivation {
            name = "tailwindcss-${tailwindVersion}";
            src = pkgs.fetchurl {
              url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${tailwindVersion}/tailwindcss-${p.suffix}";
              hash = p.hash;
              executable = true;
            };
            dontUnpack = true;
            installPhase = ''
              install -Dm755 $src $out/bin/tailwindcss
            '';
          };

        # ---------------------------------------------------------------------------
        # Hex / Mix dependencies (fetched once as a fixed-output derivation)
        #
        # Fill the hash after the first failed build:
        #   nix build .#packages.x86_64-linux.gsmlg-app-backend 2>&1 | grep -E "got:|expected:"
        # ---------------------------------------------------------------------------
        mixFodDeps = beamPackages.fetchMixDeps {
          pname = "gsmlg-app-backend-mix-deps";
          src = ./.;
          inherit version;
          sha256 = lib.fakeHash;
        };

        # ---------------------------------------------------------------------------
        # JavaScript / Bun workspace dependencies (fetched once as a fixed-output derivation)
        #
        # Covers root workspace + apps/gsmlg_app_web + apps/gsmlg_app_admin_web.
        # Fill the hash after the first failed build:
        #   nix build .#packages.x86_64-linux.gsmlg-app-backend 2>&1 | grep -E "got:|expected:"
        # ---------------------------------------------------------------------------
        bunFodDeps = pkgs.stdenv.mkDerivation {
          name = "gsmlg-app-backend-bun-deps";
          src = ./.;
          nativeBuildInputs = [ pkgs.bun ];

          buildPhase = ''
            export HOME=$TMPDIR
            bun install --frozen-lockfile
          '';

          installPhase = ''
            mkdir -p $out
            # Root node_modules (shared workspace hoisted deps)
            cp -r node_modules $out/
            # Per-workspace node_modules (if bun splits them)
            for app in apps/gsmlg_app_web apps/gsmlg_app_admin_web; do
              if [ -d "$app/node_modules" ]; then
                mkdir -p "$out/$app"
                cp -r "$app/node_modules" "$out/$app/"
              fi
            done
          '';

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = lib.fakeHash;
        };

        # ---------------------------------------------------------------------------
        # Helper: build one Mix release
        #
        # webApps: list of app directory names whose assets need to be compiled
        # ---------------------------------------------------------------------------
        mkRelease = { releaseName, webApps ? [ "gsmlg_app_web" "gsmlg_app_admin_web" ] }:
          beamPackages.mixRelease {
            pname = releaseName;
            inherit version;
            src = ./.;
            inherit mixFodDeps;

            nativeBuildInputs = [ pkgs.bun tailwindcssBin ];

            # Runs at the start of buildPhase, after configurePhase has linked deps/.
            preBuild = ''
              export HOME=$TMPDIR

              # ── Tailwind binary ──────────────────────────────────────────────────
              # The `tailwind` hex mix task stores the binary at:
              #   Mix.Project.build_path() <> "/tailwind-<version>"
              # Place the nixpkgs binary there so it skips the download.
              mkdir -p _build/prod
              cp ${tailwindcssBin}/bin/tailwindcss _build/prod/tailwind-${tailwindVersion}
              chmod +x _build/prod/tailwind-${tailwindVersion}

              # ── Bun node_modules ────────────────────────────────────────────────
              ln -sf ${bunFodDeps}/node_modules node_modules

              for app in ${lib.concatStringsSep " " webApps}; do
                src_nm="${bunFodDeps}/apps/$app/node_modules"
                if [ -d "$src_nm" ]; then
                  mkdir -p "apps/$app"
                  ln -sf "$src_nm" "apps/$app/node_modules"
                fi
              done

              # ── Admin web vendor JS (copied from Mix deps) ───────────────────────
              # The gsmlg_app_admin_web build script copies Phoenix JS bundles from
              # ../../deps/ into assets/vendor/js/ before running bun build.
              if printf '%s\n' ${lib.concatStringsSep " " webApps} | grep -qx gsmlg_app_admin_web; then
                mkdir -p apps/gsmlg_app_admin_web/assets/vendor/js
                cp deps/phoenix/priv/static/phoenix.mjs \
                   apps/gsmlg_app_admin_web/assets/vendor/js/phoenix.js
                cp deps/phoenix_html/priv/static/phoenix_html.js \
                   apps/gsmlg_app_admin_web/assets/vendor/js/
                cp deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js \
                   apps/gsmlg_app_admin_web/assets/vendor/js/phoenix_live_view.js
              fi

              # ── Build JS assets ───────────────────────────────────────────────────
              for app in ${lib.concatStringsSep " " webApps}; do
                if [ -d "apps/$app/assets" ]; then
                  (cd apps/$app && bun run build:deploy)
                fi
              done

              # ── Build CSS with Tailwind ───────────────────────────────────────────
              for app in ${lib.concatStringsSep " " webApps}; do
                mix tailwind $app --minify
              done

              # ── Digest static assets ──────────────────────────────────────────────
              mix phx.digest
            '';

            # Override buildPhase to name the specific Mix release.
            # Default mixRelease runs `mix release --overwrite` (first release only).
            buildPhase = ''
              runHook preBuild
              mix compile --no-deps-check
              mix release ${releaseName} --overwrite
              runHook postBuild
            '';
          };

      in
      {
        # ──────────────────────────────────────────────────────────────────────────
        # Exported packages
        # ──────────────────────────────────────────────────────────────────────────
        packages = {
          # Full backend: public web (port 4152) + admin web (port 4153)
          gsmlg-app-backend = mkRelease {
            releaseName = "gsmlg_app_backend";
          };

          # Admin release only (port 4153)
          gsmlg-app-admin = mkRelease {
            releaseName = "gsmlg_app_admin";
            webApps = [ "gsmlg_app_admin_web" ];
          };

          # Public release only (port 4152)
          gsmlg-app-public = mkRelease {
            releaseName = "gsmlg_app";
            webApps = [ "gsmlg_app_web" ];
          };

          default = self.packages.${system}.gsmlg-app-backend;
        };

        # ──────────────────────────────────────────────────────────────────────────
        # Dev shell (matches devenv toolchain)
        # ──────────────────────────────────────────────────────────────────────────
        devShells.default = pkgs.mkShell {
          packages = [
            elixir
            beamPackages.erlang
            pkgs.bun
            tailwindcssBin
            pkgs.git
          ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.inotify-tools ];

          shellHook = ''
            export DATABASE_URL="ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_dev"
            export DATABASE_URL_TEST="ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_test"
          '';
        };
      }
    );
}
