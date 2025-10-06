defmodule GsmlgAppAdminWeb.PageController do
  use GsmlgAppAdminWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:current_user, conn.assigns[:current_user])
    |> render(:home)
  end
end
