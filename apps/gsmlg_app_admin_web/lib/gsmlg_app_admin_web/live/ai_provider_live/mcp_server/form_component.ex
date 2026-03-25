defmodule GsmlgAppAdminWeb.AiProviderLive.McpServer.FormComponent do
  @moduledoc false
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
end
