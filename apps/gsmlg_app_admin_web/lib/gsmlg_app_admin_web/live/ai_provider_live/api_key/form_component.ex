defmodule GsmlgAppAdminWeb.AiProviderLive.ApiKey.FormComponent do
  @moduledoc false
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

  @all_scopes ~w(chat_completions messages images ocr agents models_list)

  @impl true
  def update(%{api_key: api_key, action: action} = assigns, socket) do
    {:ok, providers} = AI.list_providers()

    form =
      case action do
        :new ->
          %{
            "name" => "",
            "description" => "",
            "scopes" => default_scopes(),
            "allowed_models" => "",
            "allowed_providers" => []
          }
          |> to_form()

        :edit ->
          %{
            "name" => api_key.name,
            "description" => api_key.description || "",
            "scopes" => Enum.map(api_key.scopes || [], &to_string/1),
            "rate_limit_rpm" => api_key.rate_limit_rpm,
            "rate_limit_rpd" => api_key.rate_limit_rpd,
            "allowed_models" => Enum.join(api_key.allowed_models || [], ", "),
            "allowed_providers" => Enum.map(api_key.allowed_providers || [], &to_string/1)
          }
          |> to_form()
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:all_scopes, @all_scopes)
     |> assign(:providers, providers)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    save(socket, socket.assigns.action, params)
  end

  defp save(socket, :new, params) do
    scopes =
      (params["scopes"] || [])
      |> Enum.map(&String.to_existing_atom/1)

    attrs = %{
      name: params["name"],
      description: params["description"],
      scopes: scopes,
      rate_limit_rpm: parse_int(params["rate_limit_rpm"]),
      rate_limit_rpd: parse_int(params["rate_limit_rpd"]),
      allowed_models: parse_comma_list(params["allowed_models"]),
      allowed_providers: params["allowed_providers"] || [],
      user_id: socket.assigns.current_user.id
    }

    case AI.create_api_key(attrs) do
      {:ok, api_key} ->
        notify_parent({:saved, api_key})

        {:noreply,
         socket
         |> put_flash(:info, "API key created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create API key.")}
    end
  end

  defp save(socket, :edit, params) do
    scopes =
      (params["scopes"] || [])
      |> Enum.map(&String.to_existing_atom/1)

    attrs = %{
      name: params["name"],
      description: params["description"],
      scopes: scopes,
      rate_limit_rpm: parse_int(params["rate_limit_rpm"]),
      rate_limit_rpd: parse_int(params["rate_limit_rpd"]),
      allowed_models: parse_comma_list(params["allowed_models"]),
      allowed_providers: params["allowed_providers"] || []
    }

    case AI.update_api_key(socket.assigns.api_key, attrs) do
      {:ok, api_key} ->
        notify_parent({:saved, api_key})

        {:noreply,
         socket
         |> put_flash(:info, "API key updated.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update API key.")}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val

  defp parse_comma_list(nil), do: []
  defp parse_comma_list(""), do: []

  defp parse_comma_list(str) when is_binary(str) do
    str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp default_scopes do
    ~w(chat_completions messages images ocr agents models_list)
  end
end
