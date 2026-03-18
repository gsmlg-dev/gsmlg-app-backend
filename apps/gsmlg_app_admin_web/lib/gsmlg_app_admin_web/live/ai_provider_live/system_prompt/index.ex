defmodule GsmlgAppAdminWeb.AiProviderLive.SystemPrompt.Index do
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, templates} = AI.list_system_prompt_templates()
    {:ok, assign(socket, templates: templates)}
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New System Prompt Template", template: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket, page_title: "Edit Template", template: AI.get_system_prompt_template!(id))
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "System Prompt Templates", template: nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = AI.get_system_prompt_template!(id)

    case AI.delete_system_prompt_template(template) do
      :ok ->
        {:ok, templates} = AI.list_system_prompt_templates()
        {:noreply, assign(socket, templates: templates) |> put_flash(:info, "Template deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete template.")}
    end
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.AiProviderLive.SystemPrompt.FormComponent, {:saved, _}}, socket) do
    {:ok, templates} = AI.list_system_prompt_templates()
    {:noreply, assign(socket, templates: templates)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.ai_provider_layout current_path={@current_uri}>
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-2xl font-bold">System Prompt Templates</h1>
        <.link patch={~p"/ai-provider/system-prompts/new"} class="btn btn-primary">New Template</.link>
      </div>

      <.dm_modal
        :if={@live_action in [:new, :edit]}
        id="template-modal"
        size="lg"
      >
        <:body>
          <.live_component
            module={GsmlgAppAdminWeb.AiProviderLive.SystemPrompt.FormComponent}
            id={(@template && @template.id) || :new}
            action={@live_action}
            template={@template}
            patch={~p"/ai-provider/system-prompts"}
          />
        </:body>
      </.dm_modal>

      <div class="space-y-4">
        <div :for={t <- @templates} id={"template-#{t.id}"} class="card bg-base-100 shadow-sm p-4">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="font-bold">{t.name}</h3>
              <p class="text-sm opacity-70">Slug: {t.slug} | Priority: {t.priority}</p>
              <div class="flex gap-2 mt-1">
                <span :if={t.is_default} class="badge badge-info badge-sm">Default</span>
                <span class={[
                  "badge badge-sm",
                  if(t.is_active, do: "badge-success", else: "badge-error")
                ]}>
                  {if t.is_active, do: "Active", else: "Inactive"}
                </span>
              </div>
              <pre class="mt-2 text-sm bg-base-200 p-2 rounded max-h-32 overflow-auto whitespace-pre-wrap">{t.content}</pre>
            </div>
            <div class="flex gap-2">
              <.link patch={~p"/ai-provider/system-prompts/#{t.id}/edit"} class="btn btn-sm btn-ghost">
                Edit
              </.link>
              <button
                phx-click="delete"
                phx-value-id={t.id}
                data-confirm="Delete this template?"
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
