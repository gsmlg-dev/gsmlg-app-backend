defmodule GsmlgAppAdmin.AI.ToolExecutorTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdmin.AI.ToolExecutor

  describe "execute/3 - passthrough" do
    test "returns {:ok, :passthrough} for passthrough tools" do
      tool = %{execution_type: :passthrough, timeout_ms: 5000}
      assert {:ok, :passthrough} = ToolExecutor.execute(tool, %{})
    end
  end

  describe "execute/3 - code" do
    test "returns error when code execution is disabled" do
      tool = %{execution_type: :code, timeout_ms: 5000, code_body: "1 + 1"}
      assert {:error, msg} = ToolExecutor.execute(tool, %{})
      assert msg =~ "disabled"
    end
  end

  describe "execute/3 - mcp" do
    test "returns error for unimplemented MCP execution" do
      tool = %{execution_type: :mcp, timeout_ms: 5000}
      assert {:error, msg} = ToolExecutor.execute(tool, %{})
      assert msg =~ "not yet implemented"
    end
  end

  describe "execute/3 - unknown" do
    test "returns error for unknown execution type" do
      tool = %{execution_type: :unknown, timeout_ms: 5000}
      assert {:error, msg} = ToolExecutor.execute(tool, %{})
      assert msg =~ "Unknown execution type"
    end
  end

  describe "execute/3 - timeout" do
    test "returns timeout error when tool exceeds timeout" do
      tool = %{
        execution_type: :builtin,
        timeout_ms: 100,
        builtin_handler: "GsmlgAppAdmin.Test.SleepyHandler.sleep_forever"
      }

      assert {:error, msg} = ToolExecutor.execute(tool, %{}, [])
      assert msg == "Tool execution timed out after 100ms"
    end
  end

  describe "execute/3 - builtin" do
    test "returns error for invalid handler format" do
      tool = %{execution_type: :builtin, timeout_ms: 5000, builtin_handler: "no_dots"}
      assert {:error, msg} = ToolExecutor.execute(tool, %{})
      assert msg =~ "Invalid builtin handler"
    end
  end

  describe "execute/3 - webhook GET with nested arguments" do
    test "does not crash when arguments contain nested maps" do
      Req.Test.stub(:webhook_get_nested, fn conn ->
        Req.Test.json(conn, %{"result" => "ok"})
      end)

      tool = %{
        execution_type: :webhook,
        timeout_ms: 5000,
        webhook_url: "https://api.example.com/webhook",
        webhook_method: :get,
        webhook_headers: nil
      }

      # Nested maps would crash URI.encode_query/1 without our fix
      arguments = %{
        "query" => "hello",
        "options" => %{"limit" => 5, "nested" => true}
      }

      # This should not raise — nested values get JSON-encoded
      result = ToolExecutor.execute(tool, arguments)
      # Will fail on SSRF or DNS (test URL), but should not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "validate_webhook_url/1" do
    test "allows https URLs" do
      assert :ok = ToolExecutor.validate_webhook_url("https://api.example.com/webhook")
    end

    test "allows http URLs" do
      assert :ok = ToolExecutor.validate_webhook_url("http://api.example.com/webhook")
    end

    test "rejects non-http schemes" do
      assert {:error, msg} = ToolExecutor.validate_webhook_url("file:///etc/passwd")
      assert msg =~ "http or https"

      assert {:error, _} = ToolExecutor.validate_webhook_url("ftp://server.com/data")
      assert {:error, _} = ToolExecutor.validate_webhook_url("gopher://server.com/")
    end

    test "rejects URLs without host" do
      assert {:error, msg} = ToolExecutor.validate_webhook_url("http://")
      assert msg =~ "valid host"
    end

    test "blocks localhost" do
      assert {:error, msg} = ToolExecutor.validate_webhook_url("http://127.0.0.1/internal")
      assert msg =~ "blocked"
    end

    test "blocks private IP ranges" do
      assert {:error, _} = ToolExecutor.validate_webhook_url("http://10.0.0.1/internal")
      assert {:error, _} = ToolExecutor.validate_webhook_url("http://172.16.0.1/internal")
      assert {:error, _} = ToolExecutor.validate_webhook_url("http://192.168.1.1/internal")
    end

    test "blocks link-local addresses (cloud metadata)" do
      assert {:error, _} = ToolExecutor.validate_webhook_url("http://169.254.169.254/metadata")
    end

    test "rejects nil" do
      assert {:error, _} = ToolExecutor.validate_webhook_url(nil)
    end
  end
end
