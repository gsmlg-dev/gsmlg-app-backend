defmodule GsmlgAppAdminWeb.AiProviderLive.McpServer.Index do
  @moduledoc "LiveView for managing AI gateway MCP servers."
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, servers} = AI.list_mcp_servers()
    {:ok, assign(socket, servers: servers)}
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
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
  def handle_info({GsmlgAppAdminWeb.AiProviderLive.McpServer.FormComponent, {:saved, _}}, socket) do
    {:ok, servers} = AI.list_mcp_servers()
    {:noreply, assign(socket, servers: servers)}
  end
end
