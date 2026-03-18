defmodule GsmlgAppAdminWeb.AiProviderLive.Tool.Index do
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

  @impl true
  def render(assigns) do
    ~H"""
    <.ai_provider_layout current_path={@current_uri}>
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-2xl font-bold">Tools</h1>
        <.link patch={~p"/ai-provider/tools/new"} class="btn btn-primary">New Tool</.link>
      </div>

      <.dm_modal
        :if={@live_action in [:new, :edit]}
        id="tool-modal"
        size="lg"
      >
        <:body>
          <.live_component
            module={GsmlgAppAdminWeb.AiProviderLive.Tool.FormComponent}
            id={(@tool && @tool.id) || :new}
            action={@live_action}
            tool={@tool}
            patch={~p"/ai-provider/tools"}
          />
        </:body>
      </.dm_modal>

      <div class="space-y-3">
        <div :for={t <- @tools} id={"tool-#{t.id}"} class="card bg-base-100 shadow-sm p-4">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <h3 class="font-bold">{t.name}</h3>
              <p class="text-sm opacity-70">Slug: {t.slug}</p>
              <div class="flex gap-2 mt-1">
                <span class="badge badge-sm badge-outline">{t.execution_type}</span>
                <span class={[
                  "badge badge-sm",
                  if(t.is_active, do: "badge-success", else: "badge-error")
                ]}>
                  {if t.is_active, do: "Active", else: "Inactive"}
                </span>
              </div>
              <p :if={t.description} class="text-sm mt-1">{t.description}</p>
            </div>
            <div class="flex gap-2 ml-4">
              <.link patch={~p"/ai-provider/tools/#{t.id}/edit"} class="btn btn-sm btn-ghost">Edit</.link>
              <button
                phx-click="delete"
                phx-value-id={t.id}
                data-confirm="Delete this tool?"
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
