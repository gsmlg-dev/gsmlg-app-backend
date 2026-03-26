defmodule GsmlgAppAdminWeb.AiProviderLive.Tool.FormComponent do
  @moduledoc false
  use GsmlgAppAdminWeb, :live_component

  require Logger

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers

  @valid_webhook_methods ~w(post get put delete)
  @valid_execution_types ~w(webhook builtin code mcp passthrough)

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
    webhook_method =
      RequestHelpers.safe_enum(params["webhook_method"] || "post", @valid_webhook_methods, "post")

    base_attrs = %{
      name: params["name"],
      description: params["description"],
      webhook_url: blank_to_nil(params["webhook_url"]),
      webhook_method: String.to_existing_atom(webhook_method),
      builtin_handler: blank_to_nil(params["builtin_handler"]),
      timeout_ms: String.to_integer(params["timeout_ms"] || "30000"),
      is_active: params["is_active"] == "true"
    }

    attrs =
      case socket.assigns.action do
        :new ->
          exec_type =
            RequestHelpers.safe_enum(params["execution_type"], @valid_execution_types, "webhook")

          base_attrs
          |> Map.put(:slug, params["slug"])
          |> Map.put(:execution_type, String.to_existing_atom(exec_type))

        :edit ->
          base_attrs
      end

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

      {:error, error} ->
        Logger.error("Failed to save tool: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to save tool.")}
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(val), do: val
end
