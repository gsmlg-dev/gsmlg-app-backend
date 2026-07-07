defmodule GsmlgAppAdminWeb.Api.V1.EmbeddingsController do
  @moduledoc """
  OpenAI-compatible embeddings endpoint.

  Handles `POST /api/v1/embeddings` by proxying through Backplane.
  """

  use GsmlgAppAdminWeb, :controller

  require Logger

  alias GsmlgAppAdmin.AI.BackplaneError
  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :embeddings) do
      handle_embedding(conn, api_key, params)
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'embeddings' scope.", type: "permission_error"}})
      |> halt()
    end
  end

  defp handle_embedding(conn, api_key, params) do
    case Gateway.create_embedding(api_key, params, request_ip: RequestHelpers.client_ip(conn)) do
      {:ok, result} ->
        json(conn, result)

      {:error, %BackplaneError{} = error} ->
        conn
        |> put_status(RequestHelpers.backplane_error_status(error))
        |> json(RequestHelpers.backplane_error_body(:openai, error))

      {:error, "Missing required parameter" <> _ = reason} ->
        conn
        |> put_status(400)
        |> json(%{error: %{message: reason, type: "invalid_request_error"}})

      {:error, "API key does not have" <> _ = reason} ->
        conn
        |> put_status(403)
        |> json(%{error: %{message: reason, type: "permission_error"}})

      {:error, reason} ->
        Logger.error("Embeddings API error: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{error: %{message: "An internal error occurred.", type: "server_error"}})
    end
  end
end
