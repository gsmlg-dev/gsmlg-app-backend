defmodule GsmlgAppAdminWeb.PageControllerTest do
  use GsmlgAppAdminWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, nil)
      |> get(~p"/")

    assert html_response(conn, 200) =~ "Best in the World!"
  end
end
