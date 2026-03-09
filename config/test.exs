import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gsmlg_app_web, GsmlgAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "44hJYIOlBkvm6kHQPGS6SFTzelbpKSdQVLbJ/TtVHwlUKDboO12CSXi3cBLbNjxJ",
  server: false

# Configure your database
# DATABASE_URL_TEST and PGHOST are exported by devenv (see devenv.nix)
# MIX_TEST_PARTITION is appended for CI test partitioning
config :gsmlg_app_admin, GsmlgAppAdmin.Repo,
  url:
    System.get_env(
      "DATABASE_URL_TEST",
      "ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_test#{System.get_env("MIX_TEST_PARTITION")}"
    ),
  socket_dir: System.get_env("PGHOST"),
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

# Configure Ash Authentication for tests
config :ash_authentication,
  token_signing_secret: "test_jwt_signing_secret_for_testing_only"

config :ash_authentication, :jwt, signing_secret: "test_jwt_signing_secret_for_testing_only"
