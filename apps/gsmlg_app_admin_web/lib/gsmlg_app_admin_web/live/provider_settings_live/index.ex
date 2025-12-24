defmodule GsmlgAppAdminWeb.ProviderSettingsLive.Index do
  @moduledoc """
  LiveView for listing and managing AI providers.
  """

  use GsmlgAppAdminWeb, :live_view

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
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/chat"} class="btn btn-ghost btn-sm">
            <.dm_mdi name="arrow-left" class="w-4 h-4" /> Back to Chat
          </.link>
          <h1 class="text-2xl font-bold">AI Provider Settings</h1>
        </div>
        <.link navigate={~p"/chat/settings/new"} class="btn btn-primary">
          <.dm_mdi name="plus" class="w-4 h-4 mr-2" /> Add Provider
        </.link>
      </div>

      <div class="grid gap-4">
        <%= if Enum.empty?(@providers) do %>
          <div class="card bg-base-200 p-8 text-center">
            <div class="flex flex-col items-center gap-4">
              <.dm_mdi name="chip" class="w-16 h-16 text-base-content/50" />
              <p class="text-lg">No AI providers configured yet.</p>
              <.link navigate={~p"/chat/settings/new"} class="btn btn-primary">
                Add Your First Provider
              </.link>
            </div>
          </div>
        <% else %>
          <%= for provider <- @providers do %>
            <div class="card bg-base-100 shadow-md">
              <div class="card-body">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center gap-3">
                      <.link
                        navigate={~p"/chat/settings/#{provider.id}"}
                        class="text-lg font-semibold hover:text-primary"
                      >
                        {provider.name}
                      </.link>
                      <span class={"badge #{if provider.is_active, do: "badge-success", else: "badge-neutral"}"}>
                        {if provider.is_active, do: "Active", else: "Inactive"}
                      </span>
                    </div>
                    <p class="text-sm text-base-content/70 mt-1">
                      <span class="font-mono">{provider.slug}</span> &bull;
                      Model: {provider.model}
                    </p>
                    <p class="text-sm text-base-content/50 mt-2">
                      API: {provider.api_base_url}
                      <%= if provider.masked_api_key do %>
                        &bull; Key: {provider.masked_api_key}
                      <% end %>
                    </p>
                  </div>
                  <div class="flex items-center gap-2">
                    <button
                      phx-click="toggle_active"
                      phx-value-id={provider.id}
                      class="btn btn-ghost btn-sm"
                      title={if provider.is_active, do: "Deactivate", else: "Activate"}
                      disabled={@loading}
                    >
                      <%= if @loading do %>
                        <span class="loading loading-spinner loading-xs"></span>
                      <% else %>
                        <.dm_mdi
                          name={if provider.is_active, do: "pause", else: "play"}
                          class="w-4 h-4"
                        />
                      <% end %>
                    </button>
                    <.link navigate={~p"/chat/settings/#{provider.id}/edit"} class="btn btn-ghost btn-sm">
                      <.dm_mdi name="pencil" class="w-4 h-4" />
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={provider.id}
                      class="btn btn-ghost btn-sm text-error"
                      data-confirm={"Are you sure you want to delete #{provider.name}?"}
                      disabled={@loading}
                    >
                      <%= if @loading do %>
                        <span class="loading loading-spinner loading-xs"></span>
                      <% else %>
                        <.dm_mdi name="delete" class="w-4 h-4" />
                      <% end %>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
