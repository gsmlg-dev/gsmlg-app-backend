defmodule GsmlgAppAdminWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GsmlgAppAdminWeb.Telemetry,
      # Start a worker by calling: GsmlgAppAdminWeb.Worker.start_link(arg)
      # {GsmlgAppAdminWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      GsmlgAppAdminWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GsmlgAppAdminWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GsmlgAppAdminWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
