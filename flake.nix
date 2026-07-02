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
        # JavaScript workspace dependencies (fetched once as a fixed-output derivation)
        #
        # Covers root workspace + apps/gsmlg_app_web + apps/gsmlg_app_admin_web.
        # Fill the hash after the first failed build:
        #   nix build .#packages.x86_64-linux.gsmlg-app-backend 2>&1 | grep -E "got:|expected:"
        # ---------------------------------------------------------------------------
        npmFodDeps = pkgs.stdenv.mkDerivation {
          name = "gsmlg-app-backend-npm-deps";
          src = ./.;
          nativeBuildInputs = [ elixir beamPackages.erlang ];

          buildPhase = ''
            export HOME=$TMPDIR
            export MIX_ENV=prod
            mix local.hex --force
            mix local.rebar --force
            mix deps.get
            mix npm.install --frozen
          '';

          installPhase = ''
            mkdir -p $out
            cp -r node_modules $out/
            cp npm.lock $out/npm.lock
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

            # Runs at the start of buildPhase, after configurePhase has linked deps/.
            preBuild = ''
              export HOME=$TMPDIR

              # ── npm workspace dependencies ──────────────────────────────────────
              ln -sf ${npmFodDeps}/node_modules node_modules
              ln -sf ${npmFodDeps}/npm.lock npm.lock

              for app in ${lib.concatStringsSep " " webApps}; do
                src_nm="${npmFodDeps}/apps/$app/node_modules"
                if [ -d "$src_nm" ]; then
                  mkdir -p "apps/$app"
                  ln -sf "$src_nm" "apps/$app/node_modules"
                fi
              done

              # ── Build frontend assets with DuskmoonBundler ──────────────────────
              for app in ${lib.concatStringsSep " " webApps}; do
                if [ -d "apps/$app/assets" ]; then
                  (cd apps/$app && mix assets.deploy)
                fi
              done
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
