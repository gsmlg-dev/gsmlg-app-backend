defmodule GsmlgAppAdminWeb.Plugs.SessionUserTest do
  use GsmlgAppAdminWeb.ConnCase, async: true

  alias GsmlgAppAdminWeb.Plugs.SessionUser

  describe "call/2" do
    test "preserves existing current_user assignment", %{conn: conn} do
      existing_user = %{id: "already-assigned"}

      conn =
        conn
        |> assign(:current_user, existing_user)
        |> init_test_session(%{})
        |> SessionUser.call([])

      assert conn.assigns.current_user == existing_user
    end

    test "assigns nil when no user session exists", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> SessionUser.call([])

      assert conn.assigns.current_user == nil
    end

    test "assigns nil for non-string session value", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"user" => 12345})
        |> SessionUser.call([])

      assert conn.assigns.current_user == nil
    end

    test "assigns nil for invalid UUID format", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"user" => "not-a-uuid"})
        |> SessionUser.call([])

      assert conn.assigns.current_user == nil
    end

    test "assigns nil for non-existent user UUID", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"user" => "00000000-0000-0000-0000-000000000000"})
        |> SessionUser.call([])

      assert conn.assigns.current_user == nil
    end

    test "assigns nil for subject with non-existent id", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"user" => "user?id=00000000-0000-0000-0000-000000000000"})
        |> SessionUser.call([])

      assert conn.assigns.current_user == nil
    end
  end
end
