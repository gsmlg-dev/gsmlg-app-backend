defmodule GsmlgAppAdminWeb.ProviderSettingsLive.Show do
  @moduledoc """
  LiveView for showing AI provider details and usage statistics.
  """

  use GsmlgAppAdminWeb, :live_view

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
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center gap-4 mb-6">
        <.link navigate={~p"/chat/settings"} class="btn btn-ghost btn-sm">
          <.dm_mdi name="arrow-left" class="w-4 h-4" /> Back to Settings
        </.link>
        <h1 class="text-2xl font-bold">{@provider.name}</h1>
        <span class={"badge #{if @provider.is_active, do: "badge-success", else: "badge-neutral"}"}>
          {if @provider.is_active, do: "Active", else: "Inactive"}
        </span>
      </div>

      <div class="grid md:grid-cols-2 gap-6">
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2 class="card-title">Configuration</h2>
            <div class="space-y-3 mt-4">
              <div>
                <span class="text-sm text-base-content/70">Slug</span>
                <p class="font-mono">{@provider.slug}</p>
              </div>
              <div>
                <span class="text-sm text-base-content/70">API Base URL</span>
                <p class="font-mono text-sm break-all">{@provider.api_base_url}</p>
              </div>
              <div>
                <span class="text-sm text-base-content/70">Default Model</span>
                <p class="font-mono">{@provider.model}</p>
              </div>
              <%= if @provider.available_models && length(@provider.available_models) > 0 do %>
                <div>
                  <span class="text-sm text-base-content/70">Available Models</span>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for model <- @provider.available_models do %>
                      <span class="badge badge-outline badge-sm">{model}</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <div>
                <span class="text-sm text-base-content/70">API Key</span>
                <p class="font-mono">
                  <%= if @provider.api_key do %>
                    ****{String.slice(@provider.api_key || "", -4..-1//1)}
                  <% else %>
                    <span class="text-base-content/50">Not configured</span>
                  <% end %>
                </p>
              </div>
              <%= if @provider.description do %>
                <div>
                  <span class="text-sm text-base-content/70">Description</span>
                  <p>{@provider.description}</p>
                </div>
              <% end %>
            </div>
            <div class="card-actions justify-end mt-4">
              <.link navigate={~p"/chat/settings/#{@provider.id}/edit"} class="btn btn-primary btn-sm">
                <.dm_mdi name="pencil" class="w-4 h-4 mr-1" /> Edit
              </.link>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Usage Statistics</h2>
              <button phx-click="refresh_usage" class="btn btn-ghost btn-xs" disabled={@refreshing}>
                <%= if @refreshing do %>
                  <span class="loading loading-spinner loading-xs"></span>
                <% else %>
                  <.dm_mdi name="refresh" class="w-4 h-4" />
                <% end %>
              </button>
            </div>

            <%= if @provider.total_messages == 0 && @provider.total_tokens == 0 do %>
              <div class="flex flex-col items-center py-8 text-base-content/50">
                <.dm_mdi name="chart-bar" class="w-12 h-12 mb-2" />
                <p>No usage yet</p>
              </div>
            <% else %>
              <div class="stats stats-vertical shadow mt-4">
                <div class="stat">
                  <div class="stat-figure text-primary">
                    <.dm_mdi name="message-text" class="w-8 h-8" />
                  </div>
                  <div class="stat-title">Total Messages</div>
                  <div class="stat-value text-primary">{format_number(@provider.total_messages)}</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-secondary">
                    <.dm_mdi name="shimmer" class="w-8 h-8" />
                  </div>
                  <div class="stat-title">Total Tokens</div>
                  <div class="stat-value text-secondary">{format_number(@provider.total_tokens)}</div>
                </div>

                <div class="stat">
                  <div class="stat-figure text-accent">
                    <.dm_mdi name="clock" class="w-8 h-8" />
                  </div>
                  <div class="stat-title">Last Used</div>
                  <div class="stat-value text-sm">{format_datetime(@provider.last_used_at)}</div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2 class="card-title text-base-content/70">Timestamps</h2>
            <div class="grid md:grid-cols-2 gap-4 mt-2 text-sm">
              <div>
                <span class="text-base-content/50">Created</span>
                <p>{format_datetime(@provider.created_at)}</p>
              </div>
              <div>
                <span class="text-base-content/50">Last Updated</span>
                <p>{format_datetime(@provider.updated_at)}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
