defmodule GsmlgAppWeb.AppsController do
  use GsmlgAppWeb, :app_controller

  alias GsmlgAppWeb.AppsCache

  def list(conn, _params) do
    apps = AppsCache.load()

    conn
    |> assign(:apps, apps)
    |> render(:list)
  end
end
