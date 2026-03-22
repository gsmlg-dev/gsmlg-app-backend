defmodule GsmlgAppAdminWeb.AiProviderLive.ProviderSettings.Show do
  @moduledoc """
  LiveView for showing AI provider details and usage statistics.
  """

  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    provider = AI.get_provider!(id)

    {:ok,
     socket
     |> assign(:page_title, provider.name)
     |> assign(:provider, provider)
     |> assign(:refreshing, false)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_uri, URI.parse(url).path)}
  end

  @impl true
  def handle_event("refresh_usage", _params, socket) do
    socket = assign(socket, :refreshing, true)
    provider = AI.get_provider!(socket.assigns.provider.id)

    {:noreply,
     socket
     |> assign(:provider, provider)
     |> assign(:refreshing, false)}
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_number(nil), do: "0"
  defp format_number(num), do: Integer.to_string(num)
end
