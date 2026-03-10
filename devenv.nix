{ pkgs, lib, config, inputs, ... }:

let
  pkgs-stable = import inputs.nixpkgs-stable { system = pkgs.stdenv.system; };
in
{
  env.GREET = "GSMLG APP Backend";

  packages = with pkgs-stable; [
    git
    figlet
    lolcat
    watchman
    tailwindcss_4
  ] ++ lib.optionals stdenv.isLinux [
    inotify-tools
  ];

  languages.elixir.enable = true;
  languages.elixir.package = pkgs-stable.beam27Packages.elixir;

  languages.javascript.enable = true;
  languages.javascript.pnpm.enable = true;
  languages.javascript.bun.enable = true;
  languages.javascript.bun.package = pkgs-stable.bun;

  scripts.hello.exec = ''
    figlet -w 120 $GREET | lolcat
  '';

  enterShell = ''
    hello
    export DATABASE_URL="ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_dev"
    export DATABASE_URL_TEST="ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_test"
  '';

  # services
  services.postgres = {
    enable = true;
    package = pkgs-stable.postgresql_14;
    initialDatabases = [
      { name = "gsmlg_app_admin_dev"; }
      { name = "gsmlg_app_admin_test"; }
    ];
    listen_addresses = "";  # Unix socket only, no TCP — avoids port conflicts
    settings = {
      max_connections = 200;
      shared_buffers = "512MB";
      log_min_duration_statement = 500;
    };
    initialScript = ''
      CREATE USER gsmlg_app WITH SUPERUSER CREATEDB PASSWORD 'gsmlg_app';
      CREATE DATABASE gsmlg_app OWNER gsmlg_app;
      ALTER DATABASE gsmlg_app_admin_dev OWNER TO gsmlg_app;
      ALTER DATABASE gsmlg_app_admin_test OWNER TO gsmlg_app;
    '';
  };

}

