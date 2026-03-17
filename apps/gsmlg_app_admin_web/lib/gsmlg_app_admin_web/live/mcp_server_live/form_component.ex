defmodule GsmlgAppAdminWeb.McpServerLive.FormComponent do
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

  @impl true
  def update(%{server: server, action: action} = assigns, socket) do
    form =
      case action do
        :new ->
          %{
            "name" => "",
            "slug" => "",
            "description" => "",
            "transport_type" => "stdio",
            "connection_config_json" => "{}",
            "is_active" => true,
            "auto_sync_tools" => true
          }

        :edit ->
          %{
            "name" => server.name,
            "slug" => server.slug,
            "description" => server.description || "",
            "transport_type" => to_string(server.transport_type),
            "connection_config_json" =>
              Jason.encode!(server.connection_config || %{}, pretty: true),
            "is_active" => server.is_active,
            "auto_sync_tools" => server.auto_sync_tools
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
    connection_config =
      case Jason.decode(params["connection_config_json"] || "{}") do
        {:ok, map} -> map
        {:error, _} -> %{}
      end

    attrs = %{
      name: params["name"],
      slug: params["slug"],
      description: blank_to_nil(params["description"]),
      transport_type: String.to_atom(params["transport_type"]),
      connection_config: connection_config,
      is_active: params["is_active"] == "true",
      auto_sync_tools: params["auto_sync_tools"] == "true"
    }

    result =
      case socket.assigns.action do
        :new -> AI.create_mcp_server(attrs)
        :edit -> AI.update_mcp_server(socket.assigns.server, attrs)
      end

    case result do
      {:ok, server} ->
        send(self(), {__MODULE__, {:saved, server}})

        {:noreply,
         socket |> put_flash(:info, "MCP server saved.") |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save MCP server.")}
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
        {if @action == :new, do: "New MCP Server", else: "Edit MCP Server"}
      </h2>

      <.form
        for={@form}
        id="mcp-server-form"
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

          <div class="form-control">
            <label class="label"><span class="label-text">Transport Type</span></label>
            <select name="form[transport_type]" class="select select-bordered w-full">
              <option value="stdio" selected={@form[:transport_type].value == "stdio"}>
                Stdio
              </option>
              <option value="sse" selected={@form[:transport_type].value == "sse"}>SSE</option>
              <option
                value="streamable_http"
                selected={@form[:transport_type].value == "streamable_http"}
              >
                Streamable HTTP
              </option>
            </select>
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Connection Config (JSON)</span></label>
            <textarea
              name="form[connection_config_json]"
              class="textarea textarea-bordered w-full h-32 font-mono text-sm"
              required
            ><%= @form[:connection_config_json].value %></textarea>
            <p class="text-xs opacity-70 mt-1">
              Stdio: command, args, env | SSE/HTTP: url, headers
            </p>
          </div>

          <div class="flex gap-4">
            <label class="label cursor-pointer gap-2">
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
            <label class="label cursor-pointer gap-2">
              <input type="hidden" name="form[auto_sync_tools]" value="false" />
              <input
                type="checkbox"
                name="form[auto_sync_tools]"
                value="true"
                checked={
                  @form[:auto_sync_tools].value != "false" and
                    @form[:auto_sync_tools].value != false
                }
                class="checkbox"
              />
              <span class="label-text">Auto-sync tools</span>
            </label>
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
