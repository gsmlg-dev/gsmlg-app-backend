defmodule GsmlgAppWeb.Lookup.WhoisControllerTest do
  use GsmlgAppWeb.ConnCase

  import GsmlgApp.LookupFixtures

  alias GsmlgApp.Lookup.Whois

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all whois", %{conn: conn} do
      conn = get(conn, ~p"/api/lookup/whois")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create whois" do
    test "renders whois when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/lookup/whois", whois: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/lookup/whois/#{id}")

      assert %{
               "id" => ^id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/lookup/whois", whois: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update whois" do
    setup [:create_whois]

    test "renders whois when data is valid", %{conn: conn, whois: %Whois{id: id} = whois} do
      conn = put(conn, ~p"/api/lookup/whois/#{whois}", whois: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/lookup/whois/#{id}")

      assert %{
               "id" => ^id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, whois: whois} do
      conn = put(conn, ~p"/api/lookup/whois/#{whois}", whois: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete whois" do
    setup [:create_whois]

    test "deletes chosen whois", %{conn: conn, whois: whois} do
      conn = delete(conn, ~p"/api/lookup/whois/#{whois}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/lookup/whois/#{whois}")
      end
    end
  end

  defp create_whois(_) do
    whois = whois_fixture()
    %{whois: whois}
  end
end
