defmodule GsmlgAppAdminWeb.AiProviderLive.ApiKey.Index do
  @moduledoc "LiveView for managing AI gateway API keys."
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    case AI.list_api_keys() do
      {:ok, api_keys} ->
        {:ok, assign(socket, api_keys: api_keys, raw_key: nil)}

      {:error, _} ->
        {:ok, assign(socket, api_keys: [], raw_key: nil)}
    end
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket,
      page_title: "New API Key",
      api_key: nil
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket,
      page_title: "Edit API Key",
      api_key: AI.get_api_key!(id)
    )
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      page_title: "API Keys",
      api_key: nil
    )
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_key = AI.get_api_key!(id)

    case AI.delete_api_key(api_key) do
      :ok ->
        {:ok, api_keys} = AI.list_api_keys()
        {:noreply, assign(socket, api_keys: api_keys) |> put_flash(:info, "API key deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete API key.")}
    end
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    api_key = AI.get_api_key!(id)

    case AI.revoke_api_key(api_key) do
      {:ok, _} ->
        {:ok, api_keys} = AI.list_api_keys()
        {:noreply, assign(socket, api_keys: api_keys) |> put_flash(:info, "API key revoked.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke API key.")}
    end
  end

  @impl true
  def handle_info(
        {GsmlgAppAdminWeb.AiProviderLive.ApiKey.FormComponent, {:saved, api_key}},
        socket
      ) do
    raw_key = Map.get(api_key, :__raw_key__)
    {:ok, api_keys} = AI.list_api_keys()
    {:noreply, assign(socket, api_keys: api_keys, raw_key: raw_key)}
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end
