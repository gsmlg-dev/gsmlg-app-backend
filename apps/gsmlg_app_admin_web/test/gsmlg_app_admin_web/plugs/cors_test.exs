defmodule GsmlgAppAdminWeb.Plugs.CORSTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias GsmlgAppAdminWeb.Plugs.CORS

  describe "call/2" do
    test "OPTIONS preflight returns 204 with CORS headers" do
      conn =
        conn(:options, "/api/v1/chat/completions")
        |> put_req_header("origin", "https://example.com")
        |> CORS.call(CORS.init([]))

      assert conn.status == 204
      assert conn.halted
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") != []
    end

    test "non-OPTIONS request passes through with CORS headers" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> put_req_header("origin", "https://example.com")
        |> CORS.call(CORS.init([]))

      refute conn.halted
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end
  end
end
