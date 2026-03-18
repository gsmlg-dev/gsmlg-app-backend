defmodule GsmlgAppAdminWeb.AiProviderLive.Memory.Index do
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

  @impl true
  def render(assigns) do
    ~H"""
    <.ai_provider_layout current_path={@current_uri}>
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-2xl font-bold">Memories</h1>
        <.link patch={~p"/ai-provider/memories/new"} class="btn btn-primary">New Memory</.link>
      </div>

      <.dm_modal
        :if={@live_action in [:new, :edit]}
        id="memory-modal"
        size="lg"
      >
        <:body>
          <.live_component
            module={GsmlgAppAdminWeb.AiProviderLive.Memory.FormComponent}
            id={(@memory && @memory.id) || :new}
            action={@live_action}
            memory={@memory}
            patch={~p"/ai-provider/memories"}
          />
        </:body>
      </.dm_modal>

      <div class="space-y-3">
        <div :for={m <- @memories} id={"memory-#{m.id}"} class="card bg-base-100 shadow-sm p-4">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <div class="flex gap-2 mb-1">
                <span class="badge badge-sm badge-outline">{m.scope}</span>
                <span class="badge badge-sm badge-outline">{m.category}</span>
                <span :if={m.priority > 0} class="badge badge-sm">P{m.priority}</span>
              </div>
              <p class="text-sm">{m.content}</p>
            </div>
            <div class="flex gap-2 ml-4">
              <.link patch={~p"/ai-provider/memories/#{m.id}/edit"} class="btn btn-sm btn-ghost">Edit</.link>
              <button
                phx-click="delete"
                phx-value-id={m.id}
                data-confirm="Delete?"
                class="btn btn-sm btn-error"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
        </div>
      </div>
    </.ai_provider_layout>
    """
  end
end
