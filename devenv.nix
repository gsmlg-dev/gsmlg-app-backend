{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  pkgs-stable = import inputs.nixpkgs-stable {system = pkgs.stdenv.system;};
in {
  devenv.warnOnNewVersion = false;

  env.GREET = "GSMLG APP Backend";

  packages = with pkgs-stable;
    [
      git
      figlet
      lolcat
      watchman
      beam28Packages.elixir-ls
    ]
    ++ lib.optionals stdenv.isLinux [
      inotify-tools
    ];

  languages.elixir.enable = true;
  languages.elixir.package = pkgs-stable.beam28Packages.elixir;

  scripts.hello.exec = ''
    figlet -w 120 $GREET | lolcat
  '';

  enterShell = ''
    hello
    export DATABASE_URL="ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_dev"
    export DATABASE_URL_TEST="ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_test"
  '';

  processes.gsmlg-app-backend = {
    exec = "mix phx.server";
  };

  # services
  services.postgres = {
    enable = true;
    package = pkgs-stable.postgresql_14;
    initialDatabases = [
      {name = "gsmlg_app_admin_dev";}
      {name = "gsmlg_app_admin_test";}
    ];
    listen_addresses = ""; # Unix socket only, no TCP — avoids port conflicts
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
