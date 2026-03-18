defmodule GsmlgAppAdminWeb.AiProviderLive.ApiKey.Index do
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    case AI.list_api_keys() do
      {:ok, api_keys} ->
        {:ok, assign(socket, api_keys: api_keys, raw_key: nil)}

      {:error, _} ->
        {:ok, assign(socket, api_keys: [], raw_key: nil)}
    end
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket,
      page_title: "New API Key",
      api_key: nil
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket,
      page_title: "Edit API Key",
      api_key: AI.get_api_key!(id)
    )
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      page_title: "API Keys",
      api_key: nil
    )
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_key = AI.get_api_key!(id)

    case AI.delete_api_key(api_key) do
      :ok ->
        {:ok, api_keys} = AI.list_api_keys()
        {:noreply, assign(socket, api_keys: api_keys) |> put_flash(:info, "API key deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete API key.")}
    end
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    api_key = AI.get_api_key!(id)

    case AI.revoke_api_key(api_key) do
      {:ok, _} ->
        {:ok, api_keys} = AI.list_api_keys()
        {:noreply, assign(socket, api_keys: api_keys) |> put_flash(:info, "API key revoked.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke API key.")}
    end
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.AiProviderLive.ApiKey.FormComponent, {:saved, api_key}}, socket) do
    raw_key = Map.get(api_key, :__raw_key__)
    {:ok, api_keys} = AI.list_api_keys()
    {:noreply, assign(socket, api_keys: api_keys, raw_key: raw_key)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.ai_provider_layout current_path={@current_uri}>
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-2xl font-bold">API Keys</h1>
        <.link patch={~p"/ai-provider/api-keys/new"} class="btn btn-primary">
          New API Key
        </.link>
      </div>

      <.dm_modal
        :if={@live_action in [:new, :edit]}
        id="api-key-modal"
        size="lg"
      >
        <:body>
          <.live_component
            module={GsmlgAppAdminWeb.AiProviderLive.ApiKey.FormComponent}
            id={(@api_key && @api_key.id) || :new}
            action={@live_action}
            api_key={@api_key}
            current_user={@current_user}
            patch={~p"/ai-provider/api-keys"}
          />
        </:body>
      </.dm_modal>

      <%= if @raw_key do %>
        <div class="alert alert-warning mb-6">
          <div>
            <p class="font-bold">Your API key (shown only once):</p>
            <code class="block mt-2 p-2 bg-base-200 rounded select-all text-sm break-all">
              {@raw_key}
            </code>
            <p class="text-sm mt-2">Copy this key now. You won't be able to see it again.</p>
          </div>
        </div>
      <% end %>

      <div class="overflow-x-auto">
        <table class="table w-full">
          <thead>
            <tr>
              <th>Name</th>
              <th>Prefix</th>
              <th>Status</th>
              <th>Requests</th>
              <th>Tokens</th>
              <th>Last Used</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={key <- @api_keys} id={"key-#{key.id}"}>
              <td>{key.name}</td>
              <td><code>{key.key_prefix}...</code></td>
              <td>
                <span class={[
                  "badge",
                  if(key.is_active, do: "badge-success", else: "badge-error")
                ]}>
                  {if key.is_active, do: "Active", else: "Revoked"}
                </span>
              </td>
              <td>{key.total_requests}</td>
              <td>{key.total_tokens}</td>
              <td>{format_datetime(key.last_used_at)}</td>
              <td class="flex gap-2">
                <.link patch={~p"/ai-provider/api-keys/#{key.id}/edit"} class="btn btn-sm btn-ghost">
                  Edit
                </.link>
                <%= if key.is_active do %>
                  <button
                    phx-click="revoke"
                    phx-value-id={key.id}
                    data-confirm="Revoke this API key?"
                    class="btn btn-sm btn-warning"
                  >
                    Revoke
                  </button>
                <% end %>
                <button
                  phx-click="delete"
                  phx-value-id={key.id}
                  data-confirm="Delete this API key permanently?"
                  class="btn btn-sm btn-error"
                >
                  Delete
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        </div>
      </div>
    </.ai_provider_layout>
    """
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end
