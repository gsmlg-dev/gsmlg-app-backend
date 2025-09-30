[
  import_deps: [
    :phoenix,
    :ash,
    :ash_phoenix,
    :ash_postgres,
    :ash_authentication,
    :ash_authentication_phoenix
  ],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["mix.exs", "config/*.exs"],
  subdirectories: ["apps/*"]
]
