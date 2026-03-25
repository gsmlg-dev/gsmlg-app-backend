defmodule GsmlgAppAdminWeb.AiProviderLive.Memory.Index do
  @moduledoc "LiveView for managing AI memory entries."
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, memories} = AI.list_memories()
    {:ok, assign(socket, memories: memories)}
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New Memory", memory: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket, page_title: "Edit Memory", memory: AI.get_memory!(id))
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Memories", memory: nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    memory = AI.get_memory!(id)

    case AI.delete_memory(memory) do
      :ok ->
        {:ok, memories} = AI.list_memories()
        {:noreply, assign(socket, memories: memories) |> put_flash(:info, "Memory deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete memory.")}
    end
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.AiProviderLive.Memory.FormComponent, {:saved, _}}, socket) do
    {:ok, memories} = AI.list_memories()
    {:noreply, assign(socket, memories: memories)}
  end
end
