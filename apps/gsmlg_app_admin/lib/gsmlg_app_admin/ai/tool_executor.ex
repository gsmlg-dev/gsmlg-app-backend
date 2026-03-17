defmodule GsmlgAppAdmin.AI.ToolExecutor do
  @moduledoc """
  Executes tools based on their execution type.

  Supports: webhook, builtin, code, mcp, passthrough.
  """

  require Logger

  @doc """
  Executes a tool with the given arguments.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def execute(tool, arguments, opts \\ []) do
    timeout = tool.timeout_ms || 30_000

    task = Task.async(fn -> do_execute(tool, arguments, opts) end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, "Tool execution timed out after #{timeout}ms"}
    end
  end

  defp do_execute(%{execution_type: :webhook} = tool, arguments, _opts) do
    url = tool.webhook_url
    method = tool.webhook_method || :post
    headers = build_headers(tool.webhook_headers)

    case method do
      :post ->
        case Req.post(url, json: arguments, headers: headers, receive_timeout: tool.timeout_ms) do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            {:ok, format_result(body)}

          {:ok, %{status: status, body: body}} ->
            {:error, "Webhook returned HTTP #{status}: #{inspect(body)}"}

          {:error, error} ->
            {:error, "Webhook request failed: #{inspect(error)}"}
        end

      :get ->
        query_params = URI.encode_query(arguments)
        full_url = "#{url}?#{query_params}"

        case Req.get(full_url, headers: headers, receive_timeout: tool.timeout_ms) do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            {:ok, format_result(body)}

          {:ok, %{status: status, body: body}} ->
            {:error, "Webhook returned HTTP #{status}: #{inspect(body)}"}

          {:error, error} ->
            {:error, "Webhook request failed: #{inspect(error)}"}
        end

      _ ->
        {:error, "Unsupported webhook method: #{method}"}
    end
  end

  defp do_execute(%{execution_type: :builtin} = tool, arguments, _opts) do
    handler = tool.builtin_handler

    case resolve_builtin_handler(handler) do
      {:ok, {module, function}} ->
        try do
          result = apply(module, function, [arguments])
          {:ok, format_result(result)}
        rescue
          e -> {:error, "Builtin handler error: #{inspect(e)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_execute(%{execution_type: :passthrough}, _arguments, _opts) do
    {:ok, :passthrough}
  end

  defp do_execute(%{execution_type: :mcp}, _arguments, _opts) do
    # MCP tool execution will be handled by McpConnectionManager
    {:error, "MCP tool execution not yet implemented"}
  end

  defp do_execute(%{execution_type: :code}, _arguments, _opts) do
    # Code execution disabled by default for safety
    if gateway_config(:code_tool_enabled, false) do
      {:error, "Code tool execution not yet implemented"}
    else
      {:error, "Code tool execution is disabled"}
    end
  end

  defp do_execute(tool, _arguments, _opts) do
    {:error, "Unknown execution type: #{inspect(tool.execution_type)}"}
  end

  defp build_headers(nil), do: []

  defp build_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} ->
      {key, interpolate_secrets(value)}
    end)
  end

  defp interpolate_secrets(value) when is_binary(value) do
    # Replace {{secret:key}} patterns with environment variables
    Regex.replace(~r/\{\{secret:(\w+)\}\}/, value, fn _, key ->
      System.get_env(key) || ""
    end)
  end

  defp interpolate_secrets(value), do: value

  defp resolve_builtin_handler(handler) when is_binary(handler) do
    case String.split(handler, ".") do
      parts when length(parts) >= 2 ->
        function = List.last(parts) |> String.to_atom()
        module_parts = Enum.drop(parts, -1)
        module = Module.concat(module_parts)
        {:ok, {module, function}}

      _ ->
        {:error, "Invalid builtin handler format: #{handler}"}
    end
  end

  defp resolve_builtin_handler(_), do: {:error, "Invalid builtin handler"}

  defp format_result(result) when is_binary(result), do: result
  defp format_result(result) when is_map(result), do: Jason.encode!(result)
  defp format_result(result), do: inspect(result)

  defp gateway_config(key, default) do
    Application.get_env(:gsmlg_app_admin, GsmlgAppAdmin.AI.Gateway, [])
    |> Keyword.get(key, default)
  end
end
