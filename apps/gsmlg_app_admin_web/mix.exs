defmodule GsmlgAppAdminWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :gsmlg_app_admin_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {GsmlgAppAdminWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_duskmoon, "~> 9.0"},
      {:duskmoon_bundler, "~> 9.6"},
      {:floki, "~> 0.38"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~>0.26 or ~> 1.0"},
      {:ash, "~> 3.0"},
      {:ash_authentication_phoenix, "~> 2.4"},
      {:ash_phoenix, "~> 2.0"},
      {:gsmlg_app_admin, in_umbrella: true},
      {:gsmlg_app_component, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:earmark, "~> 1.4"},
      {:bandit, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["cmd --cd ../.. mix npm.install"],
      "assets.vendor": [
        "cmd mkdir -p priv/static/assets/vendor/duskmoon",
        "cmd mkdir -p priv/static/assets/vendor/phoenix",
        "cmd cp ../../node_modules/@duskmoon-dev/el-markdown/dist/esm/register.js priv/static/assets/vendor/duskmoon/el-markdown-register.js",
        "cmd cp ../../node_modules/@duskmoon-dev/el-markdown/dist/esm/register.js.map priv/static/assets/vendor/duskmoon/el-markdown-register.js.map",
        "cmd cp ../../node_modules/@duskmoon-dev/el-base/dist/esm/index.js priv/static/assets/vendor/duskmoon/el-base.js",
        "cmd cp ../../node_modules/@duskmoon-dev/el-base/dist/esm/index.js.map priv/static/assets/vendor/duskmoon/el-base.js.map",
        "cmd cp ../../node_modules/@duskmoon-dev/core/dist/esm/components/markdown-body.js priv/static/assets/vendor/duskmoon/markdown-body.js",
        "cmd cp ../../deps/phoenix/priv/static/phoenix.mjs priv/static/assets/vendor/phoenix/phoenix.mjs",
        "cmd cp ../../deps/phoenix_html/priv/static/phoenix_html.js priv/static/assets/vendor/phoenix/phoenix_html.js",
        "cmd cp ../../deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js priv/static/assets/vendor/phoenix/phoenix_live_view.esm.js"
      ],
      "assets.build": [
        "assets.vendor",
        "cmd --cd ../.. mix duskmoon_bundler.build gsmlg_app_admin_web --tailwind --no-hash --outdir apps/gsmlg_app_admin_web/priv/static/assets"
      ],
      "assets.deploy": [
        "assets.vendor",
        "cmd --cd ../.. mix duskmoon_bundler.build gsmlg_app_admin_web --tailwind --outdir apps/gsmlg_app_admin_web/priv/static/assets",
        "phx.digest"
      ],
      lint: ["credo --strict", "dialyzer"]
    ]
  end
end
