defmodule GsmlgAppAdminWeb.Plugs.CORS do
  @moduledoc """
  CORS plug for API gateway endpoints.
  Handles preflight OPTIONS requests and sets appropriate headers.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "OPTIONS"} = conn, _opts) do
    conn
    |> put_cors_headers()
    |> send_resp(204, "")
    |> halt()
  end

  def call(conn, _opts) do
    put_cors_headers(conn)
  end

  defp put_cors_headers(conn) do
    allowed_origins = gateway_config(:cors_allowed_origins, ["*"])

    origin = get_req_header(conn, "origin") |> List.first() || "*"

    allowed_origin =
      cond do
        "*" in allowed_origins -> "*"
        origin in allowed_origins -> origin
        true -> ""
      end

    conn
    |> put_resp_header("access-control-allow-origin", allowed_origin)
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header(
      "access-control-allow-headers",
      "authorization, x-api-key, content-type, anthropic-version"
    )
    |> put_resp_header(
      "access-control-expose-headers",
      "x-ratelimit-limit, x-ratelimit-remaining, x-ratelimit-reset, retry-after"
    )
    |> put_resp_header("access-control-max-age", "86400")
  end

  defp gateway_config(key, default) do
    Application.get_env(:gsmlg_app_admin, GsmlgAppAdmin.AI.Gateway, [])
    |> Keyword.get(key, default)
  end
end
