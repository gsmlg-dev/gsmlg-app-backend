defmodule GsmlgAppAdminWeb.AiProviderLive.Config.Index do
  @moduledoc "LiveView for Backplane connection configuration."

  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @default_server_url "http://localhost:4220"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_config(socket)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply,
     socket
     |> assign(:current_uri, URI.parse(url).path)
     |> assign(:page_title, "Backplane Config")}
  end

  @impl true
  def handle_event("validate", %{"config" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :config))}
  end

  @impl true
  def handle_event("save", %{"config" => params}, socket) do
    case config_attrs(params, socket.assigns.effective_auth_token) do
      {:ok, attrs} ->
        save_config(socket, attrs)

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp save_config(socket, attrs) do
    case AI.upsert_backplane_config(attrs) do
      {:ok, _config} ->
        {:noreply,
         socket
         |> assign_config()
         |> put_flash(:info, "Backplane config saved.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save Backplane config.")}
    end
  end

  defp assign_config(socket) do
    persisted = persisted_config()
    env_config = Application.get_env(:gsmlg_app_admin, :backplane, [])

    server_url =
      persisted_url(persisted) || Keyword.get(env_config, :server_url) || @default_server_url

    auth_token = persisted_token(persisted) || Keyword.get(env_config, :auth_token)

    form =
      %{
        "server_url" => server_url,
        "auth_token" => "",
        "clear_auth_token" => "false"
      }
      |> to_form(as: :config)

    assign(socket,
      form: form,
      effective_auth_token: auth_token,
      auth_token_present: auth_token not in [nil, ""]
    )
  end

  defp persisted_config do
    case AI.get_backplane_config() do
      {:ok, config} -> config
      _error -> nil
    end
  end

  defp persisted_url(%{server_url: server_url}) when server_url not in [nil, ""], do: server_url
  defp persisted_url(_config), do: nil

  defp persisted_token(%{auth_token: auth_token}), do: auth_token
  defp persisted_token(_config), do: nil

  defp config_attrs(params, current_auth_token) do
    server_url = params |> Map.get("server_url", "") |> String.trim()
    auth_token = params |> Map.get("auth_token", "") |> String.trim()
    clear_auth_token? = params["clear_auth_token"] == "true"

    cond do
      server_url == "" ->
        {:error, "Backplane server address is required."}

      not valid_url?(server_url) ->
        {:error, "Backplane server address must start with http:// or https://."}

      true ->
        attrs = %{
          server_url: server_url,
          auth_token: resolved_auth_token(auth_token, current_auth_token, clear_auth_token?)
        }

        {:ok, attrs}
    end
  end

  defp resolved_auth_token(_auth_token, _current_auth_token, true), do: nil
  defp resolved_auth_token("", current_auth_token, false), do: current_auth_token
  defp resolved_auth_token(auth_token, _current_auth_token, false), do: auth_token

  defp valid_url?(server_url) do
    uri = URI.parse(server_url)
    uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != ""
  end
end
