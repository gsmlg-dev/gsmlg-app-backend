import Config

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :gsmlg_app, GsmlgApp.Mailer, adapter: Swoosh.Adapters.Local

config :gsmlg_app_web,
  generators: [context_app: :gsmlg_app]

# Configures the endpoint
config :gsmlg_app_web, GsmlgAppWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: GsmlgAppWeb.ErrorHTML, json: GsmlgAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GsmlgApp.PubSub,
  live_view: [signing_salt: "eNwXe6VH"]

# Configure bun (the version is required)
# Use system bun from Nix when available (avoids glibc issues with downloaded binary)
config :bun,
  version: "1.2.13",
  path: System.find_executable("bun"),
  gsmlg_app_web: [
    args:
      ~w(build assets/js/app.js --bundle --format=esm --target=browser --outdir=priv/static/assets --loader:.js=jsx --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/gsmlg_app_web", __DIR__)
  ],
  gsmlg_app_admin_web: [
    args:
      ~w(build assets/js/app.js --bundle --format=esm --target=browser --outdir=priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/gsmlg_app_admin_web", __DIR__)
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.11",
  gsmlg_app_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/gsmlg_app_web", __DIR__)
  ],
  gsmlg_app_admin_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/gsmlg_app_admin_web", __DIR__)
  ]

### Admin Part

# Configure Mix tasks and generators
config :gsmlg_app_admin,
  ecto_repos: [GsmlgAppAdmin.Repo]

config :gsmlg_app_admin,
  ash_domains: [GsmlgAppAdmin.Accounts, GsmlgAppAdmin.Blog, GsmlgAppAdmin.AI, GsmlgAppAdmin.Apps]

config :gsmlg_app_admin, GsmlgAppAdmin.Mailer, adapter: Swoosh.Adapters.Local

config :gsmlg_app_admin_web,
  ecto_repos: [GsmlgAppAdmin.Repo],
  generators: [context_app: :gsmlg_app_admin]

# Configures the endpoint
config :gsmlg_app_admin_web, GsmlgAppAdminWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: GsmlgAppAdminWeb.ErrorHTML, json: GsmlgAppAdminWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GsmlgAppAdmin.PubSub,
  live_view: [signing_salt: "U/9Kvdik"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
