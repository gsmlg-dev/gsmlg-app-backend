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

config :duskmoon_bundler, :gsmlg_app_web,
  entry: "apps/gsmlg_app_web/assets/js/app.js",
  root: "apps/gsmlg_app_web/assets",
  outdir: "priv/static/assets",
  target: :es2020,
  format: :esm,
  tailwind: [
    css: "apps/gsmlg_app_web/assets/css/app.css",
    sources: [
      %{base: "apps/gsmlg_app_web/lib/", pattern: "**/*.{ex,heex,eex}"},
      %{base: "apps/gsmlg_app_web/assets/", pattern: "**/*.{js,ts,jsx,tsx}"},
      %{base: "apps/gsmlg_app_component/lib/", pattern: "**/*.{ex,heex,eex}"},
      %{base: "deps/phoenix_duskmoon/lib/", pattern: "**/*.{ex,heex,eex}"}
    ]
  ],
  server: [
    prefix: "/assets",
    watch_dirs: [
      "apps/gsmlg_app_web/lib/",
      "apps/gsmlg_app_web/assets/",
      "apps/gsmlg_app_component/lib/"
    ]
  ]

config :duskmoon_bundler, :gsmlg_app_admin_web,
  entry: "apps/gsmlg_app_admin_web/assets/js/app.js",
  root: "apps/gsmlg_app_admin_web/assets",
  outdir: "priv/static/assets",
  target: :es2020,
  format: :esm,
  tailwind: [
    css: "apps/gsmlg_app_admin_web/assets/css/app.css",
    sources: [
      %{base: "apps/gsmlg_app_admin_web/lib/", pattern: "**/*.{ex,heex,eex}"},
      %{base: "apps/gsmlg_app_admin_web/assets/", pattern: "**/*.{js,ts,jsx,tsx}"},
      %{base: "apps/gsmlg_app_component/lib/", pattern: "**/*.{ex,heex,eex}"},
      %{base: "deps/phoenix_duskmoon/lib/", pattern: "**/*.{ex,heex,eex}"}
    ]
  ],
  server: [
    prefix: "/assets",
    watch_dirs: [
      "apps/gsmlg_app_admin_web/lib/",
      "apps/gsmlg_app_admin_web/assets/",
      "apps/gsmlg_app_component/lib/"
    ]
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
