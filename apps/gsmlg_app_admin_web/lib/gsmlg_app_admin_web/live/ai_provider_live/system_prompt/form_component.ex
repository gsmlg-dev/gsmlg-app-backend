defmodule GsmlgAppAdminWeb.AiProviderLive.SystemPrompt.FormComponent do
  @moduledoc false
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

  @impl true
  def update(%{template: template, action: action} = assigns, socket) do
    form =
      case action do
        :new ->
          %{
            "name" => "",
            "slug" => "",
            "content" => "",
            "is_default" => false,
            "is_active" => true,
            "priority" => 0
          }

        :edit ->
          %{
            "name" => template.name,
            "slug" => template.slug,
            "content" => template.content,
            "is_default" => template.is_default,
            "is_active" => template.is_active,
            "priority" => template.priority
          }
      end
      |> to_form()

    {:ok, socket |> assign(assigns) |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    base_attrs = %{
      name: params["name"],
      content: params["content"],
      is_default: params["is_default"] == "true",
      is_active: params["is_active"] == "true",
      priority: String.to_integer(params["priority"] || "0")
    }

    attrs =
      case socket.assigns.action do
        :new -> Map.put(base_attrs, :slug, params["slug"])
        :edit -> base_attrs
      end

    result =
      case socket.assigns.action do
        :new -> AI.create_system_prompt_template(attrs)
        :edit -> AI.update_system_prompt_template(socket.assigns.template, attrs)
      end

    case result do
      {:ok, template} ->
        send(self(), {__MODULE__, {:saved, template}})

        {:noreply,
         socket |> put_flash(:info, "Template saved.") |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save template.")}
    end
  end
end
