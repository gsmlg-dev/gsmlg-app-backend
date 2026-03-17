defmodule GsmlgAppAdminWeb.AgentLive.FormComponent do
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold mb-4">
        {if @action == :new, do: "New Agent", else: "Edit Agent"}
      </h2>

      <.form
        for={@form}
        id="agent-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <div class="form-control">
            <label class="label"><span class="label-text">Name</span></label>
            <input
              type="text"
              name="form[name]"
              value={@form[:name].value}
              class="input input-bordered w-full"
              required
            />
          </div>

          <%= if @action == :new do %>
            <div class="form-control">
              <label class="label"><span class="label-text">Slug</span></label>
              <input
                type="text"
                name="form[slug]"
                value={@form[:slug].value}
                class="input input-bordered w-full"
                required
              />
            </div>
          <% end %>

          <div class="form-control">
            <label class="label"><span class="label-text">Description</span></label>
            <textarea name="form[description]" class="textarea textarea-bordered w-full"><%= @form[:description].value %></textarea>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Model</span></label>
              <input
                type="text"
                name="form[model]"
                value={@form[:model].value}
                class="input input-bordered w-full"
                placeholder="e.g. gpt-4o (blank = auto)"
              />
            </div>

            <div class="form-control">
              <label class="label"><span class="label-text">Provider</span></label>
              <select name="form[provider_id]" class="select select-bordered w-full">
                <option value="">Auto-resolve</option>
                <%= for p <- @providers do %>
                  <option value={p.id} selected={@form[:provider_id].value == to_string(p.id)}>
                    {p.name}
                  </option>
                <% end %>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-3 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Max Iterations</span></label>
              <input
                type="number"
                name="form[max_iterations]"
                value={@form[:max_iterations].value}
                class="input input-bordered w-full"
              />
            </div>

            <div class="form-control">
              <label class="label"><span class="label-text">Tool Choice</span></label>
              <select name="form[tool_choice]" class="select select-bordered w-full">
                <option value="auto" selected={@form[:tool_choice].value == "auto"}>Auto</option>
                <option value="required" selected={@form[:tool_choice].value == "required"}>
                  Required
                </option>
                <option value="none" selected={@form[:tool_choice].value == "none"}>None</option>
              </select>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer gap-2 mt-8">
                <input type="hidden" name="form[is_active]" value="false" />
                <input
                  type="checkbox"
                  name="form[is_active]"
                  value="true"
                  checked={@form[:is_active].value != "false" and @form[:is_active].value != false}
                  class="checkbox"
                />
                <span class="label-text">Active</span>
              </label>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <.link patch={@patch} class="btn btn-ghost">Cancel</.link>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
