defmodule GsmlgApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the PubSub system
      {Phoenix.PubSub, name: GsmlgApp.PubSub},
      # Start Finch
      {Finch, name: GsmlgApp.Finch}
      # Start a worker by calling: GsmlgApp.Worker.start_link(arg)
      # {GsmlgApp.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: GsmlgApp.Supervisor)
  end
end
