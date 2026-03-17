defmodule GsmlgAppAdminWeb.MemoryLive.FormComponent do
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

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
    attrs = %{
      content: params["content"],
      category: String.to_atom(params["category"]),
      scope: String.to_atom(params["scope"]),
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

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save memory.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold mb-4">
        {if @action == :new, do: "New Memory", else: "Edit Memory"}
      </h2>

      <.form for={@form} id="memory-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-4">
          <div class="form-control">
            <label class="label"><span class="label-text">Content</span></label>
            <textarea name="form[content]" class="textarea textarea-bordered w-full h-24" required><%= @form[:content].value %></textarea>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Category</span></label>
              <select name="form[category]" class="select select-bordered w-full">
                <option value="fact" selected={@form[:category].value == "fact"}>Fact</option>
                <option value="instruction" selected={@form[:category].value == "instruction"}>
                  Instruction
                </option>
                <option value="preference" selected={@form[:category].value == "preference"}>
                  Preference
                </option>
                <option value="context" selected={@form[:category].value == "context"}>
                  Context
                </option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Scope</span></label>
              <select name="form[scope]" class="select select-bordered w-full">
                <option value="global" selected={@form[:scope].value == "global"}>Global</option>
                <option value="user" selected={@form[:scope].value == "user"}>User</option>
                <option value="api_key" selected={@form[:scope].value == "api_key"}>API Key</option>
                <option value="agent" selected={@form[:scope].value == "agent"}>Agent</option>
              </select>
            </div>
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Priority</span></label>
            <input
              type="number"
              name="form[priority]"
              value={@form[:priority].value}
              class="input input-bordered w-24"
            />
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
