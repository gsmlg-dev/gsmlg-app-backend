defmodule GsmlgAppAdminWeb.McpServerLive.Index do
  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, servers} = AI.list_mcp_servers()
    {:ok, assign(socket, servers: servers)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New MCP Server", server: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket, page_title: "Edit MCP Server", server: AI.get_mcp_server!(id))
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "MCP Servers", server: nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    server = AI.get_mcp_server!(id)

    case AI.delete_mcp_server(server) do
      :ok ->
        {:ok, servers} = AI.list_mcp_servers()
        {:noreply, assign(socket, servers: servers) |> put_flash(:info, "MCP server deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete MCP server.")}
    end
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.McpServerLive.FormComponent, {:saved, _}}, socket) do
    {:ok, servers} = AI.list_mcp_servers()
    {:noreply, assign(socket, servers: servers)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">MCP Servers</h1>
        <.link patch={~p"/mcp-servers/new"} class="btn btn-primary">New MCP Server</.link>
      </div>

      <.dm_modal
        :if={@live_action in [:new, :edit]}
        id="mcp-server-modal"
        size="lg"
      >
        <:body>
          <.live_component
            module={GsmlgAppAdminWeb.McpServerLive.FormComponent}
            id={(@server && @server.id) || :new}
            action={@live_action}
            server={@server}
            patch={~p"/mcp-servers"}
          />
        </:body>
      </.dm_modal>

      <div class="space-y-3">
        <div :for={s <- @servers} id={"mcp-server-#{s.id}"} class="card bg-base-100 shadow-sm p-4">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <h3 class="font-bold">{s.name}</h3>
              <p class="text-sm opacity-70">Slug: {s.slug}</p>
              <div class="flex gap-2 mt-1">
                <span class="badge badge-sm badge-outline">{s.transport_type}</span>
                <span class={[
                  "badge badge-sm",
                  case s.health_status do
                    :connected -> "badge-success"
                    :disconnected -> "badge-warning"
                    :error -> "badge-error"
                    _ -> "badge-warning"
                  end
                ]}>
                  {s.health_status}
                </span>
                <span :if={s.auto_sync_tools} class="badge badge-sm badge-info">Auto-sync</span>
              </div>
              <p :if={s.description} class="text-sm mt-1">{s.description}</p>
              <p :if={s.last_error} class="text-xs text-error mt-1">{s.last_error}</p>
            </div>
            <div class="flex gap-2 ml-4">
              <.link patch={~p"/mcp-servers/#{s.id}/edit"} class="btn btn-sm btn-ghost">
                Edit
              </.link>
              <button
                phx-click="delete"
                phx-value-id={s.id}
                data-confirm="Delete this MCP server?"
                class="btn btn-sm btn-error"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
