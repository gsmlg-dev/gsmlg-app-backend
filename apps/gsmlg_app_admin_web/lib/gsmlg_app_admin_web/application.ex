defmodule GsmlgAppAdminWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Create rate limiter ETS table at startup (owned by application process)
    :ets.new(:api_gateway_rate_limits, [:named_table, :public, :duplicate_bag])

    children = [
      GsmlgAppAdminWeb.Telemetry,
      # ETS-based session store - must start before Endpoint
      GsmlgAppAdminWeb.Session.Store,
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
