import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
config :gsmlg_app_web, GsmlgAppWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4152],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE_WEB") ||
      "++y7z5YOMi8AqMVyn3x941rXNBaD81/CtGtj+EY/4H37gKkVPbAJbrasc0sq94hW",
  watchers: [
    duskmoon_bundler:
      {Mix.Tasks.DuskmoonBundler.Dev, :run,
       [~w(gsmlg_app_web --tailwind --tailwind-outdir apps/gsmlg_app_web/priv/static/assets/css)]}
  ]

# Watch static and templates for browser reloading.
config :gsmlg_app_web, GsmlgAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/gsmlg_app_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"lib/gsmlg_app_component/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :gsmlg_app_web, dev_routes: true

### Admin Part

postgres_socket_port = fn socket_dir ->
  with dir when dir not in [nil, ""] <- socket_dir,
       {:ok, entries} <- File.ls(dir),
       socket_name when is_binary(socket_name) <-
         Enum.find(Enum.sort(entries), &Regex.match?(~r/^\.s\.PGSQL\.\d+$/, &1)) do
    String.replace_prefix(socket_name, ".s.PGSQL.", "")
  else
    _ -> nil
  end
end

postgres_socket_dir = System.get_env("PGHOST")
postgres_env_port = System.get_env("PGPORT")
postgres_live_port = postgres_socket_port.(postgres_socket_dir)
postgres_port = postgres_live_port || postgres_env_port

postgres_socket_opts =
  case {postgres_socket_dir, postgres_port} do
    {socket_dir, port} when socket_dir not in [nil, ""] and port not in [nil, ""] ->
      [socket_dir: socket_dir, port: String.to_integer(port)]

    {socket_dir, _port} when socket_dir not in [nil, ""] ->
      [socket_dir: socket_dir]

    _other ->
      []
  end

# Configure your database
# DATABASE_URL, PGHOST, and PGPORT are exported by devenv (see devenv.nix).
# PGHOST points to the Unix socket directory; PGPORT selects the socket file.
config :gsmlg_app_admin,
       GsmlgAppAdmin.Repo,
       [
         url:
           System.get_env(
             "DATABASE_URL",
             "ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_dev"
           ),
         stacktrace: true,
         show_sensitive_data_on_connection_error: true,
         pool_size: 10
       ] ++ postgres_socket_opts

# For development, we disable any cache and enable
# debugging and code reloading.
#
config :gsmlg_app_admin_web, GsmlgAppAdminWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4153],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE_ADMIN") ||
      "1gdA/MEjjg9APn1rwyUsdBQ5FVA6iUIeIlUclRMFBT2i1cx3ONPx3DqxWXSDqi1w",
  watchers: [
    duskmoon_bundler:
      {Mix.Tasks.DuskmoonBundler.Dev, :run,
       [
         ~w(gsmlg_app_admin_web --tailwind --tailwind-outdir apps/gsmlg_app_admin_web/priv/static/assets/css)
       ]}
  ]

# Watch static and templates for browser reloading.
config :gsmlg_app_admin_web, GsmlgAppAdminWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/gsmlg_app_admin_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"lib/gsmlg_app_component/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :gsmlg_app_admin_web,
  dev_routes: true

config :gsmlg_app_admin,
  token_signing_secret:
    System.get_env("TOKEN_SIGNING_SECRET") ||
      "1gdA/MEjjg9APn1rwyUsdBQ5FVA6iUIeIlUclRMFBT2i1cx3ONPx3DqxWXSDqi1w"

config :ash_authentication,
  token_signing_secret:
    System.get_env("TOKEN_SIGNING_SECRET") ||
      "1gdA/MEjjg9APn1rwyUsdBQ5FVA6iUIeIlUclRMFBT2i1cx3ONPx3DqxWXSDqi1w"

config :ash_authentication, :jwt,
  signing_secret:
    System.get_env("TOKEN_SIGNING_SECRET") ||
      "1gdA/MEjjg9APn1rwyUsdBQ5FVA6iUIeIlUclRMFBT2i1cx3ONPx3DqxWXSDqi1w"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20
