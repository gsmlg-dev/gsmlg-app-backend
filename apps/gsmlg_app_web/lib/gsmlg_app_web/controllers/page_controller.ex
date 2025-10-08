defmodule GsmlgAppWeb.PageController do
  use GsmlgAppWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home)
  end

  def about_us(conn, _params) do
    render(conn, :about_us)
  end
end
