defmodule GsmlgAppAdmin.AI.BackplaneClientTest do
  use GsmlgAppAdmin.DataCase, async: false

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.BackplaneClient

  test "uses persisted Backplane server URL" do
    assert {:ok, _config} =
             AI.upsert_backplane_config(%{
               server_url: "https://backplane.example.com",
               auth_token: "secret-token"
             })

    assert BackplaneClient.url("/v1/models") == "https://backplane.example.com/v1/models"
  end

  test "sends persisted auth token" do
    stub = :"backplane_config_auth_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub, fn conn ->
      assert ["Bearer secret-token"] = Plug.Conn.get_req_header(conn, "authorization")
      Req.Test.json(conn, %{"data" => []})
    end)

    assert {:ok, _config} =
             AI.upsert_backplane_config(%{
               server_url: "https://backplane.example.com",
               auth_token: "secret-token"
             })

    assert {:ok, %{"data" => []}} = BackplaneClient.get("/v1/models", plug: {Req.Test, stub})
  end
end
