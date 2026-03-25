defmodule GsmlgAppAdminWeb.Api.V1.ImagesController do
  @moduledoc """
  OpenAI-compatible image generation endpoint.

  Handles `POST /api/v1/images/generations`.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :images) do
      case Gateway.generate_image(api_key, params, request_ip: RequestHelpers.client_ip(conn)) do
        {:ok, result} ->
          json(conn, result)

        {:error, reason} ->
          {status, type} = classify_error(reason)

          conn
          |> put_status(status)
          |> json(%{error: %{message: to_string(reason), type: type}})
      end
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'images' scope.", type: "permission_error"}})
      |> halt()
    end
  end

  defp classify_error(reason) do
    reason_str = to_string(reason)

    cond do
      String.contains?(reason_str, "Missing required parameter") ->
        {400, "invalid_request_error"}

      String.contains?(reason_str, "No provider found") ->
        {422, "invalid_request_error"}

      true ->
        {500, "server_error"}
    end
  end
end
