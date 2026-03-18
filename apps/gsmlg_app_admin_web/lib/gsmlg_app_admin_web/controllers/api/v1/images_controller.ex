defmodule GsmlgAppAdminWeb.Api.V1.ImagesController do
  @moduledoc """
  OpenAI-compatible image generation endpoint.

  Handles `POST /api/v1/images/generations`.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :images) do
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'images' scope.", type: "permission_error"}})
      |> halt()
    else
      case Gateway.generate_image(api_key, params) do
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
