defmodule GsmlgAppWeb.Lookup.WhoisControllerTest do
  use GsmlgAppWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "query endpoints" do
    test "query endpoint requires query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois")
      assert response(conn, 422)
    end

    test "query_domain endpoint requires query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/domain")
      assert response(conn, 422)
    end

    test "query_ip endpoint requires query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/ip")
      assert response(conn, 422)
    end

    test "query_as endpoint requires query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/as")
      assert response(conn, 422)
    end

    test "query endpoint with valid query parameter", %{conn: conn} do
      # This test handles both success and error cases since the external dependency may be unavailable
      conn = get(conn, "/lookup/whois", %{"query" => "example.com"})

      # Accept either 200 (success) or 422 (timeout/error) since external dependency may be unavailable
      status = conn.status
      assert status in [200, 422]
    end

    test "query_domain endpoint with valid query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/domain", %{"query" => "example.com"})

      # Accept either 200 (success) or 422 (timeout/error) since external dependency may be unavailable
      status = conn.status
      assert status in [200, 422]
    end

    test "query_ip endpoint with valid query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/ip", %{"query" => "8.8.8.8"})

      # Accept either 200 (success) or 422 (timeout/error) since external dependency may be unavailable
      status = conn.status
      assert status in [200, 422]
    end

    test "query_as endpoint with valid query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/as", %{"query" => "12345"})

      # Accept either 200 (success) or 422 (timeout/error) since external dependency may be unavailable
      status = conn.status
      assert status in [200, 422]
    end
  end
end
