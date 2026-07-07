defmodule GsmlgAppAdminWeb.AuthController do
  use GsmlgAppAdminWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> renew_session()
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_status(401)
    |> put_layout(false)
    |> render("failure.html")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/sign-in"

    conn
    |> clear_session(:gsmlg_app_admin)
    |> renew_session()
    |> redirect(to: return_to)
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> Plug.Conn.clear_session()
  end
end
