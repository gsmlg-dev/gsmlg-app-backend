defmodule GsmlgAppWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :gsmlg_app_web,
      version: "1.0.0",
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
      mod: {GsmlgAppWeb.Application, []},
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
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_duskmoon, "~> 9.0"},
      {:duskmoon_bundler, "~> 9.6"},
      {:floki, "~> 0.38"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~>0.26 or ~> 1.0"},
      {:gsmlg_app, in_umbrella: true},
      {:gsmlg_whois, "~> 0.2"},
      {:jason, "~> 1.2"},
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
      "assets.setup": ["cmd --cd ../.. mix npm.install"],
      "assets.build": [
        "cmd --cd ../.. mix duskmoon_bundler.build gsmlg_app_web --tailwind --no-hash --outdir apps/gsmlg_app_web/priv/static/assets"
      ],
      "assets.deploy": [
        "cmd --cd ../.. mix duskmoon_bundler.build gsmlg_app_web --tailwind --outdir apps/gsmlg_app_web/priv/static/assets",
        "phx.digest"
      ],
      lint: ["credo --strict", "dialyzer"]
    ]
  end
end
