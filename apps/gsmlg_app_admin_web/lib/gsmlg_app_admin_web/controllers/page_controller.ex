defmodule GsmlgAppAdminWeb.PageController do
  use GsmlgAppAdminWeb, :controller

  def home(conn, _params) do
    conn
    |> put_layout(html: {GsmlgAppAdminWeb.Layouts, :app})
    |> assign(:current_user, conn.assigns[:current_user])
    |> render(:home)
  end
end
