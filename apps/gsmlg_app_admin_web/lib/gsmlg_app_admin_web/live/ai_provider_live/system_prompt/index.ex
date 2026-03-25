defmodule GsmlgAppAdminWeb.AiProviderLive.SystemPrompt.Index do
  @moduledoc "LiveView for managing AI system prompt templates."
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
  def handle_info(
        {GsmlgAppAdminWeb.AiProviderLive.SystemPrompt.FormComponent, {:saved, _}},
        socket
      ) do
    {:ok, templates} = AI.list_system_prompt_templates()
    {:noreply, assign(socket, templates: templates)}
  end
end
