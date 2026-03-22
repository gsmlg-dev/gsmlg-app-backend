defmodule GsmlgAppAdminWeb.AiProviderLive.ProviderSettings.Index do
  @moduledoc """
  LiveView for listing and managing AI providers.
  """

  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, providers} = AI.list_providers_with_usage()

    {:ok,
     socket
     |> assign(:page_title, "AI Provider Settings")
     |> assign(:providers, providers)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_uri, URI.parse(url).path)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    provider = AI.get_provider!(id)

    case AI.delete_provider(provider) do
      :ok ->
        {:ok, providers} = AI.list_providers_with_usage()

        {:noreply,
         socket
         |> put_flash(:info, "Provider deleted successfully")
         |> assign(:providers, providers)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete provider")}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    provider = AI.get_provider!(id)

    case AI.toggle_provider_active(provider) do
      {:ok, _updated} ->
        {:ok, providers} = AI.list_providers_with_usage()

        {:noreply,
         socket
         |> put_flash(:info, "Provider status updated")
         |> assign(:providers, providers)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update provider status")}
    end
  end
end
