defmodule GsmlgAppAdminWeb.AiProviderLive.Tool.FormComponent do
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

  @impl true
  def update(%{tool: tool, action: action} = assigns, socket) do
    form =
      case action do
        :new ->
          %{
            "name" => "",
            "slug" => "",
            "description" => "",
            "execution_type" => "webhook",
            "webhook_url" => "",
            "webhook_method" => "post",
            "builtin_handler" => "",
            "timeout_ms" => "30000",
            "is_active" => true
          }

        :edit ->
          %{
            "name" => tool.name,
            "slug" => tool.slug,
            "description" => tool.description || "",
            "execution_type" => to_string(tool.execution_type),
            "webhook_url" => tool.webhook_url || "",
            "webhook_method" => to_string(tool.webhook_method || :post),
            "builtin_handler" => tool.builtin_handler || "",
            "timeout_ms" => to_string(tool.timeout_ms || 30_000),
            "is_active" => tool.is_active
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
      name: params["name"],
      slug: params["slug"],
      description: params["description"],
      execution_type: String.to_atom(params["execution_type"]),
      webhook_url: blank_to_nil(params["webhook_url"]),
      webhook_method: String.to_atom(params["webhook_method"] || "post"),
      builtin_handler: blank_to_nil(params["builtin_handler"]),
      timeout_ms: String.to_integer(params["timeout_ms"] || "30000"),
      is_active: params["is_active"] == "true"
    }

    result =
      case socket.assigns.action do
        :new -> AI.create_tool(attrs)
        :edit -> AI.update_tool(socket.assigns.tool, attrs)
      end

    case result do
      {:ok, tool} ->
        send(self(), {__MODULE__, {:saved, tool}})

        {:noreply,
         socket |> put_flash(:info, "Tool saved.") |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save tool.")}
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
        {if @action == :new, do: "New Tool", else: "Edit Tool"}
      </h2>

      <.form for={@form} id="tool-form" phx-target={@myself} phx-change="validate" phx-submit="save">
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
              <label class="label"><span class="label-text">Execution Type</span></label>
              <select name="form[execution_type]" class="select select-bordered w-full">
                <option value="webhook" selected={@form[:execution_type].value == "webhook"}>
                  Webhook
                </option>
                <option value="builtin" selected={@form[:execution_type].value == "builtin"}>
                  Builtin
                </option>
                <option value="code" selected={@form[:execution_type].value == "code"}>Code</option>
                <option value="mcp" selected={@form[:execution_type].value == "mcp"}>MCP</option>
                <option
                  value="passthrough"
                  selected={@form[:execution_type].value == "passthrough"}
                >
                  Passthrough
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label"><span class="label-text">Webhook Method</span></label>
              <select name="form[webhook_method]" class="select select-bordered w-full">
                <option value="post" selected={@form[:webhook_method].value == "post"}>POST</option>
                <option value="get" selected={@form[:webhook_method].value == "get"}>GET</option>
                <option value="put" selected={@form[:webhook_method].value == "put"}>PUT</option>
                <option value="delete" selected={@form[:webhook_method].value == "delete"}>
                  DELETE
                </option>
              </select>
            </div>
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Webhook URL</span></label>
            <input
              type="url"
              name="form[webhook_url]"
              value={@form[:webhook_url].value}
              class="input input-bordered w-full"
              placeholder="https://..."
            />
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Builtin Handler</span></label>
            <input
              type="text"
              name="form[builtin_handler]"
              value={@form[:builtin_handler].value}
              class="input input-bordered w-full"
              placeholder="Module.function"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Timeout (ms)</span></label>
              <input
                type="number"
                name="form[timeout_ms]"
                value={@form[:timeout_ms].value}
                class="input input-bordered w-full"
              />
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
