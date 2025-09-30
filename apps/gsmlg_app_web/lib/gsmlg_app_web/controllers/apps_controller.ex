defmodule GsmlgAppWeb.AppsController do
  use GsmlgAppWeb, :app_controller

  def list(conn, _params) do
    render(conn, :list)
  end
end
