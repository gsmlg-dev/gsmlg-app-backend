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

  describe "generate_id/0" do
    test "returns a URL-safe string" do
      id = RequestHelpers.generate_id()
      assert is_binary(id)
      assert String.length(id) == 16
      assert id =~ ~r/^[A-Za-z0-9_-]+$/
    end

    test "returns unique values" do
      ids = for _ <- 1..100, do: RequestHelpers.generate_id()
      assert length(Enum.uniq(ids)) == 100
    end
  end

  describe "clamp_float/3" do
    test "returns nil for nil input" do
      assert RequestHelpers.clamp_float(nil, 0.0, 2.0) == nil
    end

    test "clamps value within range" do
      assert RequestHelpers.clamp_float(1.5, 0.0, 2.0) == 1.5
      assert RequestHelpers.clamp_float(-1.0, 0.0, 2.0) == 0.0
      assert RequestHelpers.clamp_float(5.0, 0.0, 2.0) == 2.0
    end

    test "returns nil for non-numeric input" do
      assert RequestHelpers.clamp_float("1.5", 0.0, 2.0) == nil
      assert RequestHelpers.clamp_float(true, 0.0, 2.0) == nil
    end

    test "handles integer input as number" do
      assert RequestHelpers.clamp_float(1, 0.0, 2.0) == 1
    end
  end

  describe "clamp_int/3" do
    test "returns nil for nil input" do
      assert RequestHelpers.clamp_int(nil, 1, 100_000) == nil
    end

    test "clamps value within range" do
      assert RequestHelpers.clamp_int(500, 1, 100_000) == 500
      assert RequestHelpers.clamp_int(0, 1, 100_000) == 1
      assert RequestHelpers.clamp_int(999_999, 1, 100_000) == 100_000
    end

    test "returns nil for non-integer input" do
      assert RequestHelpers.clamp_int(1.5, 1, 100_000) == nil
      assert RequestHelpers.clamp_int("500", 1, 100_000) == nil
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

  describe "validate_model/1" do
    test "rejects nil and empty string" do
      assert {:error, "model is required."} = RequestHelpers.validate_model(nil)
      assert {:error, "model is required."} = RequestHelpers.validate_model("")
    end

    test "accepts valid model strings" do
      assert {:ok, "gpt-4o"} = RequestHelpers.validate_model("gpt-4o")

      assert {:ok, "claude-sonnet-4-20250514"} =
               RequestHelpers.validate_model("claude-sonnet-4-20250514")
    end

    test "rejects model strings exceeding max length" do
      long_model = String.duplicate("a", 257)
      assert {:error, _} = RequestHelpers.validate_model(long_model)
    end

    test "accepts model strings at exactly max length" do
      model = String.duplicate("a", 256)
      assert {:ok, ^model} = RequestHelpers.validate_model(model)
    end

    test "rejects non-string values" do
      assert {:error, "model must be a string."} = RequestHelpers.validate_model(123)
      assert {:error, "model must be a string."} = RequestHelpers.validate_model(true)
    end
  end

  describe "validate_tools/1" do
    test "returns nil for non-list input" do
      assert RequestHelpers.validate_tools(nil) == nil
      assert RequestHelpers.validate_tools("not a list") == nil
      assert RequestHelpers.validate_tools([]) == nil
    end

    test "passes through small lists unchanged" do
      tools = [%{"type" => "function", "function" => %{"name" => "test"}}]
      assert RequestHelpers.validate_tools(tools) == tools
    end

    test "caps lists at 128 items" do
      tools = for i <- 1..200, do: %{"name" => "tool_#{i}"}
      result = RequestHelpers.validate_tools(tools)
      assert length(result) == 128
    end
  end

  describe "validate_image_url/1" do
    test "allows nil and empty string" do
      assert :ok = RequestHelpers.validate_image_url(nil)
      assert :ok = RequestHelpers.validate_image_url("")
    end

    test "allows valid public URLs" do
      assert :ok = RequestHelpers.validate_image_url("https://example.com/image.png")
      assert :ok = RequestHelpers.validate_image_url("http://example.com/image.jpg")
    end

    test "rejects non-http schemes" do
      assert {:error, _} = RequestHelpers.validate_image_url("ftp://example.com/image.png")
      assert {:error, _} = RequestHelpers.validate_image_url("file:///etc/passwd")
    end

    test "rejects localhost URLs" do
      assert {:error, _} = RequestHelpers.validate_image_url("http://localhost/image.png")
      assert {:error, _} = RequestHelpers.validate_image_url("http://127.0.0.1/image.png")
    end

    test "rejects private network URLs" do
      assert {:error, _} = RequestHelpers.validate_image_url("http://10.0.0.1/image.png")
      assert {:error, _} = RequestHelpers.validate_image_url("http://192.168.1.1/image.png")
      assert {:error, _} = RequestHelpers.validate_image_url("http://172.16.0.1/image.png")
    end

    test "rejects link-local addresses" do
      assert {:error, _} =
               RequestHelpers.validate_image_url("http://169.254.169.254/latest/meta-data/")
    end

    test "rejects non-string values" do
      assert {:error, _} = RequestHelpers.validate_image_url(123)
    end
  end

  describe "validate_image_count/1" do
    test "returns nil for nil" do
      assert RequestHelpers.validate_image_count(nil) == nil
    end

    test "caps at 4" do
      assert RequestHelpers.validate_image_count(10) == 4
    end

    test "floors at 1" do
      assert RequestHelpers.validate_image_count(0) == 1
      assert RequestHelpers.validate_image_count(-5) == 1
    end

    test "passes through valid counts" do
      assert RequestHelpers.validate_image_count(2) == 2
      assert RequestHelpers.validate_image_count(3) == 3
    end

    test "returns nil for non-integer" do
      assert RequestHelpers.validate_image_count("2") == nil
      assert RequestHelpers.validate_image_count(1.5) == nil
    end
  end
end
