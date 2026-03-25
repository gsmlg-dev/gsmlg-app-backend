defmodule GsmlgAppAdmin.AI.ToolExecutor do
  @moduledoc """
  Executes tools based on their execution type.

  Supports: webhook, builtin, code, mcp, passthrough.
  """

  require Logger
  import Bitwise

  # Private/internal IP ranges to block for SSRF protection
  @blocked_ip_ranges [
    # Loopback
    {127, 0, 0, 0, 8},
    # Private Class A
    {10, 0, 0, 0, 8},
    # Private Class B
    {172, 16, 0, 0, 12},
    # Private Class C
    {192, 168, 0, 0, 16},
    # Link-local
    {169, 254, 0, 0, 16},
    # IPv6 mapped IPv4 loopback
    {0, 0, 0, 0, 8}
  ]

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

    with :ok <- validate_webhook_url(url) do
      execute_webhook(method, url, arguments, headers, tool.timeout_ms)
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

  defp execute_webhook(:post, url, arguments, headers, timeout) do
    case Req.post(url, json: arguments, headers: headers, receive_timeout: timeout) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, format_result(body)}

      {:ok, %{status: status}} ->
        {:error, "Webhook returned HTTP #{status}"}

      {:error, _error} ->
        {:error, "Webhook request failed"}
    end
  end

  defp execute_webhook(:get, url, arguments, headers, timeout) do
    # Flatten nested values to strings for query encoding
    flat_args =
      Enum.map(arguments, fn {key, value} ->
        {to_string(key), if(is_binary(value), do: value, else: Jason.encode!(value))}
      end)

    query_params = URI.encode_query(flat_args)
    full_url = "#{url}?#{query_params}"

    case Req.get(full_url, headers: headers, receive_timeout: timeout) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, format_result(body)}

      {:ok, %{status: status}} ->
        {:error, "Webhook returned HTTP #{status}"}

      {:error, _error} ->
        {:error, "Webhook request failed"}
    end
  end

  defp execute_webhook(method, _url, _arguments, _headers, _timeout) do
    {:error, "Unsupported webhook method: #{method}"}
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

  # Only modules under this namespace are allowed for builtin tool execution
  @allowed_builtin_namespace GsmlgAppAdmin.AI.Builtins

  defp resolve_builtin_handler(handler) when is_binary(handler) do
    case String.split(handler, ".") do
      parts when length(parts) >= 2 ->
        function = List.last(parts) |> String.to_existing_atom()
        module_parts = Enum.drop(parts, -1)
        module = Module.concat(module_parts)

        if allowed_builtin_module?(module) do
          {:ok, {module, function}}
        else
          {:error, "Builtin handler module #{inspect(module)} is not in the allowed namespace"}
        end

      _ ->
        {:error, "Invalid builtin handler format: #{handler}"}
    end
  rescue
    ArgumentError -> {:error, "Invalid builtin handler: unknown function atom"}
  end

  defp resolve_builtin_handler(_), do: {:error, "Invalid builtin handler"}

  defp allowed_builtin_module?(module) do
    module_str = Atom.to_string(module)
    allowed_str = Atom.to_string(@allowed_builtin_namespace)
    String.starts_with?(module_str, allowed_str)
  end

  # -- SSRF Protection --

  @doc false
  def validate_webhook_url(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, "Webhook URL must use http or https scheme"}

      is_nil(uri.host) or uri.host == "" ->
        {:error, "Webhook URL must have a valid host"}

      blocked_host?(uri.host) ->
        {:error, "Webhook URL targets a blocked address"}

      true ->
        :ok
    end
  end

  def validate_webhook_url(_), do: {:error, "Invalid webhook URL"}

  defp blocked_host?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ip_tuple} -> ip_in_blocked_range?(ip_tuple)
      {:error, _} -> dns_resolves_to_blocked?(host)
    end
  end

  defp dns_resolves_to_blocked?(host) do
    case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, ip_tuple} -> ip_in_blocked_range?(ip_tuple)
      {:error, _} -> false
    end
  end

  defp ip_in_blocked_range?(ip_tuple) when tuple_size(ip_tuple) == 4 do
    Enum.any?(@blocked_ip_ranges, fn {net_a, net_b, net_c, net_d, prefix_len} ->
      ip_int = ip_to_integer(ip_tuple)
      net_int = ip_to_integer({net_a, net_b, net_c, net_d})
      mask = bsl(0xFFFFFFFF, 32 - prefix_len) &&& 0xFFFFFFFF
      (ip_int &&& mask) == (net_int &&& mask)
    end)
  end

  defp ip_in_blocked_range?(_), do: false

  defp ip_to_integer({a, b, c, d}) do
    bsl(a, 24) + bsl(b, 16) + bsl(c, 8) + d
  end

  defp format_result(result) when is_binary(result), do: result
  defp format_result(result) when is_map(result), do: Jason.encode!(result)
  defp format_result(result), do: inspect(result)

  defp gateway_config(key, default) do
    Application.get_env(:gsmlg_app_admin, GsmlgAppAdmin.AI.Gateway, [])
    |> Keyword.get(key, default)
  end
end
