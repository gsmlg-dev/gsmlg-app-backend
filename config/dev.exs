import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with Bun to bundle .js and .css sources.
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
    bun: {Bun, :install_and_run, [:gsmlg_app_web, ~w(--watch)]},
    tailwind: {Tailwind, :install_and_run, [:gsmlg_app_web, ~w(--watch)]}
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

# Configure your database
config :gsmlg_app_admin, GsmlgAppAdmin.Repo,
  username: System.get_env("DB_USERNAME") || "gsmlg_app",
  password: System.get_env("DB_PASSWORD") || "gsmlg_app",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5433"),
  database: System.get_env("DB_NAME") || "gsmlg_app_admin_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with Bun to bundle .js and .css sources.
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
    bun: {Bun, :install_and_run, [:gsmlg_app_admin_web, ~w(--watch)]},
    tailwind: {Tailwind, :install_and_run, [:gsmlg_app_admin_web, ~w(--watch)]}
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
