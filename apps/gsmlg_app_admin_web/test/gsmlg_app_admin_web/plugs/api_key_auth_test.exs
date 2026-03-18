defmodule GsmlgAppAdminWeb.Plugs.ApiKeyAuthTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  describe "has_scope?/2" do
    test "returns true when scope is present" do
      api_key = %{scopes: [:chat_completions, :messages]}
      assert ApiKeyAuth.has_scope?(api_key, :chat_completions)
      assert ApiKeyAuth.has_scope?(api_key, :messages)
    end

    test "returns false when scope is missing" do
      api_key = %{scopes: [:chat_completions]}
      refute ApiKeyAuth.has_scope?(api_key, :images)
    end

    test "handles nil scopes" do
      api_key = %{scopes: nil}
      refute ApiKeyAuth.has_scope?(api_key, :chat_completions)
    end
  end

  describe "call/2 - key extraction" do
    test "returns 401 when no API key header is present" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.status == 401
      assert conn.halted

      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "authentication_error"
      assert body["error"]["message"] =~ "Missing API key"
    end

    test "returns 401 for short API keys" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> put_req_header("authorization", "Bearer short")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.status == 401
      assert conn.halted

      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "Invalid API key"
    end

    test "returns 401 for invalid API key via x-api-key header" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> put_req_header("x-api-key", "gsk_not_a_real_key_at_all_1234567890abcdef")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.status == 401
      assert conn.halted
    end
  end
end
