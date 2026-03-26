defmodule GsmlgAppAdminWeb.AiProviderLive.Agent.FormComponent do
  @moduledoc false
  use GsmlgAppAdminWeb, :live_component

  require Logger

  alias GsmlgAppAdmin.AI

  @impl true
  def update(%{agent: agent, action: action} = assigns, socket) do
    {:ok, providers} = AI.list_providers()

    form =
      case action do
        :new ->
          %{
            "name" => "",
            "slug" => "",
            "description" => "",
            "system_prompt" => "",
            "model" => "",
            "provider_id" => "",
            "max_iterations" => "10",
            "tool_choice" => "auto",
            "is_active" => true
          }

        :edit ->
          %{
            "name" => agent.name,
            "slug" => agent.slug,
            "description" => agent.description || "",
            "system_prompt" => agent.system_prompt || "",
            "model" => agent.model || "",
            "provider_id" => agent.provider_id || "",
            "max_iterations" => to_string(agent.max_iterations),
            "tool_choice" => agent.tool_choice || "auto",
            "is_active" => agent.is_active
          }
      end
      |> to_form()

    {:ok, socket |> assign(assigns) |> assign(form: form, providers: providers)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    base_attrs = %{
      name: params["name"],
      description: blank_to_nil(params["description"]),
      system_prompt: blank_to_nil(params["system_prompt"]),
      model: blank_to_nil(params["model"]),
      provider_id: blank_to_nil(params["provider_id"]),
      max_iterations: String.to_integer(params["max_iterations"] || "10"),
      tool_choice: params["tool_choice"] || "auto",
      is_active: params["is_active"] == "true"
    }

    attrs =
      case socket.assigns.action do
        :new -> Map.put(base_attrs, :slug, params["slug"])
        :edit -> base_attrs
      end

    result =
      case socket.assigns.action do
        :new -> AI.create_agent(attrs)
        :edit -> AI.update_agent(socket.assigns.agent, attrs)
      end

    case result do
      {:ok, agent} ->
        send(self(), {__MODULE__, {:saved, agent}})

        {:noreply,
         socket |> put_flash(:info, "Agent saved.") |> push_patch(to: socket.assigns.patch)}

      {:error, error} ->
        Logger.error("Failed to save agent: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to save agent.")}
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(val), do: val
end
