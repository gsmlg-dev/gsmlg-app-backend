defmodule GsmlgAppAdminWeb.AiProviderLive.Agent.FormComponent do
  use GsmlgAppAdminWeb, :live_component

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
    attrs = %{
      name: params["name"],
      slug: params["slug"],
      description: blank_to_nil(params["description"]),
      model: blank_to_nil(params["model"]),
      provider_id: blank_to_nil(params["provider_id"]),
      max_iterations: String.to_integer(params["max_iterations"] || "10"),
      tool_choice: params["tool_choice"] || "auto",
      is_active: params["is_active"] == "true"
    }

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

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save agent.")}
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(val), do: val
end
