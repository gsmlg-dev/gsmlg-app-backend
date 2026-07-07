import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gsmlg_app_web, GsmlgAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "44hJYIOlBkvm6kHQPGS6SFTzelbpKSdQVLbJ/TtVHwlUKDboO12CSXi3cBLbNjxJ",
  server: false

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
# DATABASE_URL_TEST, PGHOST, and PGPORT are exported by devenv (see devenv.nix)
# MIX_TEST_PARTITION is appended for CI test partitioning
config :gsmlg_app_admin,
       GsmlgAppAdmin.Repo,
       [
         url:
           System.get_env(
             "DATABASE_URL_TEST",
             "ecto://gsmlg_app:gsmlg_app@localhost/gsmlg_app_admin_test#{System.get_env("MIX_TEST_PARTITION")}"
           ),
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: 10,
         queue_target: 5000,
         queue_interval: 1000
       ] ++ postgres_socket_opts

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

config :gsmlg_app_admin, async_usage_logging: false

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
