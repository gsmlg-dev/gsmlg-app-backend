defmodule GsmlgAppAdminWeb.Api.V1.RequestHelpersTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers

  describe "safe_role/1" do
    test "converts valid role strings to atoms" do
      assert RequestHelpers.safe_role("user") == :user
      assert RequestHelpers.safe_role("assistant") == :assistant
      assert RequestHelpers.safe_role("tool") == :tool
      assert RequestHelpers.safe_role("function") == :function
    end

    test "defaults to :user for nil" do
      assert RequestHelpers.safe_role(nil) == :user
    end

    test "defaults to :user for empty string" do
      assert RequestHelpers.safe_role("") == :user
    end

    test "defaults to :user for unknown role strings" do
      assert RequestHelpers.safe_role("system") == :user
      assert RequestHelpers.safe_role("admin") == :user
      assert RequestHelpers.safe_role("ASSISTANT") == :user
    end

    test "prevents atom injection via known-dangerous strings" do
      # These strings could be used to inject atoms if not guarded
      assert RequestHelpers.safe_role("__struct__") == :user
      assert RequestHelpers.safe_role("__info__") == :user
      assert RequestHelpers.safe_role("Elixir.Kernel") == :user
    end
  end

  describe "client_ip/1" do
    test "formats IPv4 address" do
      conn = %{Plug.Test.conn(:post, "/") | remote_ip: {127, 0, 0, 1}}
      assert RequestHelpers.client_ip(conn) == "127.0.0.1"
    end

    test "formats IPv6 address" do
      conn = %{Plug.Test.conn(:post, "/") | remote_ip: {0, 0, 0, 0, 0, 0, 0, 1}}
      assert RequestHelpers.client_ip(conn) == "::1"
    end
  end

  describe "api_format/1" do
    test "returns :anthropic for /messages path" do
      conn = Plug.Test.conn(:post, "/api/v1/messages")
      assert RequestHelpers.api_format(conn) == :anthropic
    end

    test "returns :openai for /chat/completions path" do
      conn = Plug.Test.conn(:post, "/api/v1/chat/completions")
      assert RequestHelpers.api_format(conn) == :openai
    end

    test "returns :openai for /images/generations path" do
      conn = Plug.Test.conn(:post, "/api/v1/images/generations")
      assert RequestHelpers.api_format(conn) == :openai
    end
  end

  describe "error_body/3" do
    test "returns OpenAI error format" do
      body = RequestHelpers.error_body(:openai, "auth_error", "Invalid key")
      assert body == %{error: %{message: "Invalid key", type: "auth_error"}}
    end

    test "returns Anthropic error format" do
      body = RequestHelpers.error_body(:anthropic, "auth_error", "Invalid key")
      assert body == %{type: "error", error: %{type: "auth_error", message: "Invalid key"}}
    end
  end
end
