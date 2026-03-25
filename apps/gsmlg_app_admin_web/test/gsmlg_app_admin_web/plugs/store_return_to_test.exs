defmodule GsmlgAppAdminWeb.Plugs.StoreReturnToTest do
  use GsmlgAppAdminWeb.ConnCase, async: true

  alias GsmlgAppAdminWeb.Plugs.StoreReturnTo

  describe "call/2" do
    test "stores valid return_to path in session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:query_params, %{"return_to" => "/dashboard"})
        |> StoreReturnTo.call([])

      assert get_session(conn, :return_to) == "/dashboard"
    end

    test "does nothing when no return_to param", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:query_params, %{})
        |> StoreReturnTo.call([])

      assert get_session(conn, :return_to) == nil
    end

    test "rejects paths with protocol markers (open redirect)", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:query_params, %{"return_to" => "https://evil.com"})
        |> StoreReturnTo.call([])

      assert get_session(conn, :return_to) == nil
    end

    test "rejects protocol-relative URLs", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:query_params, %{"return_to" => "//evil.com/path"})
        |> StoreReturnTo.call([])

      assert get_session(conn, :return_to) == nil
    end

    test "rejects paths not starting with /", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:query_params, %{"return_to" => "evil.com/path"})
        |> StoreReturnTo.call([])

      assert get_session(conn, :return_to) == nil
    end

    test "accepts paths with query strings", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:query_params, %{"return_to" => "/settings?tab=api"})
        |> StoreReturnTo.call([])

      assert get_session(conn, :return_to) == "/settings?tab=api"
    end
  end
end
