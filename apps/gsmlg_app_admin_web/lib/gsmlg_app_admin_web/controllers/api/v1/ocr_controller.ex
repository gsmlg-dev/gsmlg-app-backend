defmodule GsmlgAppAdminWeb.Api.V1.OcrController do
  @moduledoc """
  OCR endpoint for extracting text from images.

  Handles `POST /api/v1/ocr`.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :ocr) do
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'ocr' scope.", type: "permission_error"}})
      |> halt()
    else
      case Gateway.extract_text(api_key, params) do
        {:ok, result} ->
          json(conn, result)

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: %{message: to_string(reason), type: "server_error"}})
      end
    end
  end
end
