defmodule GsmlgAppAdminWeb.PageController do
  use GsmlgAppAdminWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
