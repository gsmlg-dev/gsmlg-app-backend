defmodule GsmlgAppAdminWeb.Plugs.RequireAuthTest do
  use GsmlgAppAdminWeb.ConnCase, async: true

  alias GsmlgAppAdminWeb.Plugs.RequireAuth

  describe "call/2" do
    test "passes through when current_user is assigned", %{conn: conn} do
      conn =
        conn
        |> assign(:current_user, %{id: "test"})
        |> RequireAuth.call([])

      refute conn.halted
    end

    test "redirects to sign-in when no current_user", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:request_path, "/dashboard")
        |> Map.put(:query_string, "")
        |> RequireAuth.call([])

      assert conn.halted
      assert redirected_to(conn) =~ "/sign-in"
      assert redirected_to(conn) =~ "return_to="
    end

    test "includes query string in return_to", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:request_path, "/settings")
        |> Map.put(:query_string, "tab=api")
        |> RequireAuth.call([])

      assert conn.halted
      location = redirected_to(conn)
      assert location =~ "settings"
      assert location =~ "tab"
    end

    test "stores return_to in session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:request_path, "/chat")
        |> Map.put(:query_string, "")
        |> RequireAuth.call([])

      assert get_session(conn, :return_to) == "/chat"
    end
  end
end
