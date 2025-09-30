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
      # This test will fail if the gsmlg_whois dependency is not available
      # but it shows the endpoint structure is correct
      conn = get(conn, "/lookup/whois", %{"query" => "example.com"})

      # The response should be 200 (success) with valid whois data
      assert response(conn, 200)
    end

    test "query_domain endpoint with valid query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/domain", %{"query" => "example.com"})

      # The response should be 200 (success) with valid whois data
      assert response(conn, 200)
    end

    test "query_ip endpoint with valid query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/ip", %{"query" => "8.8.8.8"})

      # The response should be 200 (success) with valid whois data
      assert response(conn, 200)
    end

    test "query_as endpoint with valid query parameter", %{conn: conn} do
      conn = get(conn, "/lookup/whois/as", %{"query" => "12345"})

      # The response should be 200 (success) with valid whois data
      assert response(conn, 200)
    end
  end
end
