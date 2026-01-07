defmodule GsmlgAppAdminWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that requires authentication for controller routes.

  If no current_user is found, redirects to sign-in with return_to parameter.
  """

  import Plug.Conn
  import Phoenix.Controller
  use GsmlgAppAdminWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      return_to = build_return_path(conn)

      conn
      |> put_session(:return_to, return_to)
      |> redirect(to: ~p"/sign-in?return_to=#{URI.encode_www_form(return_to)}")
      |> halt()
    end
  end

  defp build_return_path(conn) do
    path = conn.request_path

    case conn.query_string do
      "" -> path
      qs -> "#{path}?#{qs}"
    end
  end
end
