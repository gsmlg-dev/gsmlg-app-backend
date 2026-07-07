defmodule GsmlgAppAdmin.AI.BackplaneClient do
  @moduledoc """
  HTTP client for the Backplane public API surface.

  `:server_url` points at the Backplane API origin, which exposes `/v1/*` for
  model traffic and `/mcp` for MCP clients.
  """

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.BackplaneError

  @default_server_url "http://localhost:4220"
  @default_timeout 120_000
  @internal_opts [
    :api_format,
    :auth_token,
    :max_tokens,
    :model,
    :req_opts,
    :server_url,
    :temperature,
    :tool_choice,
    :tools,
    :top_p
  ]

  @doc "Sends a JSON GET request to Backplane."
  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, BackplaneError.t()}
  def get(path, opts \\ []) do
    request(:get, path, nil, opts)
  end

  @doc "Sends a JSON POST request to Backplane."
  @spec post(String.t(), map(), keyword()) :: {:ok, term()} | {:error, BackplaneError.t()}
  def post(path, body, opts \\ []) do
    request(:post, path, body, opts)
  end

  @doc "Builds the Backplane URL for a path."
  @spec url(String.t(), keyword()) :: String.t()
  def url(path, opts \\ []) do
    base = opts |> server_url() |> String.trim_trailing("/")
    base <> "/" <> String.trim_leading(path, "/")
  end

  defp request(method, path, body, opts) do
    request_opts =
      [
        method: method,
        url: url(path, opts),
        headers: headers(opts),
        retry: false,
        receive_timeout: Keyword.get(opts, :receive_timeout, @default_timeout)
      ]
      |> maybe_put_json(body)
      |> Keyword.merge(config_value(:req_opts) || [])
      |> Keyword.merge(Keyword.drop(opts, @internal_opts))
      |> Keyword.merge(Keyword.get(opts, :req_opts, []))

    case Req.request(request_opts) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, response_error(status, response_body)}

      {:error, reason} ->
        {:error,
         %BackplaneError{
           status: nil,
           type: "transport_error",
           message: "Backplane request failed: #{inspect(reason)}",
           body: reason
         }}
    end
  end

  defp maybe_put_json(opts, nil), do: opts
  defp maybe_put_json(opts, body), do: Keyword.put(opts, :json, body)

  defp headers(opts) do
    base = [{"accept", "application/json"}, {"content-type", "application/json"}]

    case auth_token(opts) do
      nil -> base
      "" -> base
      token -> [{"authorization", "Bearer #{token}"} | base]
    end
  end

  defp server_url(opts) do
    Keyword.get(opts, :server_url) ||
      case persisted_config() do
        %{server_url: server_url} when server_url not in [nil, ""] ->
          server_url

        nil ->
          config_value(:server_url) || @default_server_url

        _config ->
          @default_server_url
      end
  end

  defp auth_token(opts) do
    case Keyword.fetch(opts, :auth_token) do
      {:ok, token} ->
        token

      :error ->
        case persisted_config() do
          %{auth_token: token} -> token
          nil -> config_value(:auth_token)
        end
    end
  end

  defp persisted_config do
    case AI.get_backplane_config() do
      {:ok, config} -> config
      _error -> nil
    end
  rescue
    _ -> nil
  end

  defp config_value(key) do
    :gsmlg_app_admin
    |> Application.get_env(:backplane, [])
    |> Keyword.get(key)
  end

  defp response_error(status, body) do
    %BackplaneError{
      status: status,
      type: error_type(body),
      message: error_message(body, status),
      body: body
    }
  end

  defp error_type(%{"error" => %{"type" => type}}), do: type
  defp error_type(%{error: %{type: type}}), do: type
  defp error_type(%{"type" => type}) when is_binary(type), do: type
  defp error_type(_body), do: nil

  defp error_message(%{"error" => %{"message" => message}}, _status), do: message
  defp error_message(%{error: %{message: message}}, _status), do: message
  defp error_message(%{"message" => message}, _status), do: message
  defp error_message(%{message: message}, _status), do: message

  defp error_message(body, status) when is_binary(body) and body != "",
    do: "HTTP #{status}: #{body}"

  defp error_message(_body, status), do: "HTTP #{status}: Backplane request failed"
end
