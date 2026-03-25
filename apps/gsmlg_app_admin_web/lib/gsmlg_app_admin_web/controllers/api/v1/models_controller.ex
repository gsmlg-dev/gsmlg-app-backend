defmodule GsmlgAppAdminWeb.Api.V1.ModelsController do
  @moduledoc """
  OpenAI-compatible models listing endpoint.

  Handles `GET /api/v1/models` to return available models for the authenticated key.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def index(conn, _params) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :models_list) do
      case Gateway.list_models(api_key) do
        {:ok, models} ->
          json(conn, %{object: "list", data: models})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: %{message: to_string(reason), type: "server_error"}})
      end
    else
      conn
      |> put_status(403)
      |> json(%{
        error: %{message: "API key lacks 'models_list' scope.", type: "permission_error"}
      })
      |> halt()
    end
  end
end
