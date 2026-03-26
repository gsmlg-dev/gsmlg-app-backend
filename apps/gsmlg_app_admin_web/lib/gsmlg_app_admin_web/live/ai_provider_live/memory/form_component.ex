defmodule GsmlgAppAdminWeb.AiProviderLive.Memory.FormComponent do
  @moduledoc false
  use GsmlgAppAdminWeb, :live_component

  require Logger

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers

  @valid_categories ~w(fact instruction preference context)
  @valid_scopes ~w(global user api_key agent)

  @impl true
  def update(%{memory: memory, action: action} = assigns, socket) do
    form =
      case action do
        :new ->
          %{"content" => "", "category" => "fact", "scope" => "global", "priority" => 0}

        :edit ->
          %{
            "content" => memory.content,
            "category" => to_string(memory.category),
            "scope" => to_string(memory.scope),
            "priority" => memory.priority
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
    category = RequestHelpers.safe_enum(params["category"], @valid_categories, "fact")
    scope = RequestHelpers.safe_enum(params["scope"], @valid_scopes, "global")

    attrs = %{
      content: params["content"],
      category: String.to_existing_atom(category),
      scope: String.to_existing_atom(scope),
      priority: String.to_integer(params["priority"] || "0")
    }

    result =
      case socket.assigns.action do
        :new -> AI.create_memory(attrs)
        :edit -> AI.update_memory(socket.assigns.memory, attrs)
      end

    case result do
      {:ok, memory} ->
        send(self(), {__MODULE__, {:saved, memory}})

        {:noreply,
         socket |> put_flash(:info, "Memory saved.") |> push_patch(to: socket.assigns.patch)}

      {:error, error} ->
        Logger.error("Failed to save memory: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to save memory.")}
    end
  end
end
