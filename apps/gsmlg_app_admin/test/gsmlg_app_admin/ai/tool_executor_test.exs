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
end
