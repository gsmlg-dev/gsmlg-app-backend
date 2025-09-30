defmodule GsmlgAppAdmin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GsmlgAppAdmin.Repo,
      {Phoenix.PubSub, name: GsmlgAppAdmin.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: GsmlgAppAdmin.Finch},
      {AshAuthentication.Supervisor, otp_app: :gsmlg_app_admin}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: GsmlgAppAdmin.Supervisor)
  end
end
