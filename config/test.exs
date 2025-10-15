import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gsmlg_app_web, GsmlgAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "44hJYIOlBkvm6kHQPGS6SFTzelbpKSdQVLbJ/TtVHwlUKDboO12CSXi3cBLbNjxJ",
  server: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :gsmlg_app_admin, GsmlgAppAdmin.Repo,
  username: System.get_env("POSTGRES_USER", "gsmlg_app"),
  password: System.get_env("POSTGRES_PASSWORD", "gsmlg_app"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "gsmlg_app_admin_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 5000,
  queue_interval: 1000

# In test we don't send emails.
config :gsmlg_app, GsmlgApp.Mailer, adapter: Swoosh.Adapters.Test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gsmlg_app_admin_web, GsmlgAppAdminWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "j0PFq+qH5kgRrx7dVDZxSKdN7nQRg36aebjCMZckJ7Awd5P88LL3qHomxB+vNCYJ",
  server: false

# In test we don't send emails.
config :gsmlg_app_admin, GsmlgAppAdmin.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
