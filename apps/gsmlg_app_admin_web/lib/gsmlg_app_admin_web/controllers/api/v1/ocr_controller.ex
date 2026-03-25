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
      case RequestHelpers.validate_image_url(params["image"]) do
        {:error, message} ->
          conn
          |> put_status(400)
          |> json(%{error: %{message: message, type: "invalid_request_error"}})

        :ok ->
          handle_ocr(conn, api_key, params)
      end
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'ocr' scope.", type: "permission_error"}})
      |> halt()
    end
  end

  defp handle_ocr(conn, api_key, params) do
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

      {:error, "API key does not have" <> _ = reason} ->
        conn
        |> put_status(403)
        |> json(%{error: %{message: reason, type: "permission_error"}})

      {:error, reason} ->
        require Logger
        Logger.error("OCR API error: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{error: %{message: "An internal error occurred.", type: "server_error"}})
    end
  end
end
