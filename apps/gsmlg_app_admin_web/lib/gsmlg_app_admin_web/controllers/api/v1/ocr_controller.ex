defmodule GsmlgAppAdminWeb.Api.V1.OcrController do
  @moduledoc """
  OCR endpoint for extracting text from images.

  Handles `POST /api/v1/ocr`.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :ocr) do
      case Gateway.extract_text(api_key, params, request_ip: RequestHelpers.client_ip(conn)) do
        {:ok, result} ->
          json(conn, result)

        {:error, "No OCR model" <> _ = reason} ->
          conn
          |> put_status(400)
          |> json(%{error: %{message: reason, type: "invalid_request_error"}})

        {:error, "No provider found" <> _ = reason} ->
          conn
          |> put_status(422)
          |> json(%{error: %{message: reason, type: "invalid_request_error"}})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: %{message: to_string(reason), type: "server_error"}})
      end
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'ocr' scope.", type: "permission_error"}})
      |> halt()
    end
  end
end
