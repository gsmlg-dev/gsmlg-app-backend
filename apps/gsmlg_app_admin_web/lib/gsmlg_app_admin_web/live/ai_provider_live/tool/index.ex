defmodule GsmlgAppAdminWeb.AiProviderLive.Tool.Index do
  @moduledoc "LiveView for managing AI agent tools."
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, tools} = AI.list_tools()
    {:ok, assign(socket, tools: tools)}
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New Tool", tool: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket, page_title: "Edit Tool", tool: AI.get_tool!(id))
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Tools", tool: nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tool = AI.get_tool!(id)

    case AI.delete_tool(tool) do
      :ok ->
        {:ok, tools} = AI.list_tools()
        {:noreply, assign(socket, tools: tools) |> put_flash(:info, "Tool deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete tool.")}
    end
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.AiProviderLive.Tool.FormComponent, {:saved, _}}, socket) do
    {:ok, tools} = AI.list_tools()
    {:noreply, assign(socket, tools: tools)}
  end
end
