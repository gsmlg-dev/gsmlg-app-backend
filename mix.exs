defmodule GsmlgApp.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "1.0.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        gsmlg_app_admin: [
          applications: [
            gsmlg_app_admin: :permanent,
            gsmlg_app_admin_web: :permanent
          ]
        ],
        gsmlg_app: [
          applications: [
            gsmlg_app: :permanent,
            gsmlg_app_web: :permanent
          ]
        ]
      ]
    ]
  end

  defp deps do
    [
      # Required to run "mix format" on ~H/.heex files from the umbrella root
      {:phoenix_live_view, ">= 1.0.0"}
    ]
  end

  defp aliases do
    [
      # run `mix setup` in all child apps
      setup: ["cmd mix setup"]
    ]
  end
end
