defmodule GsmlgAppAdmin.AI.Client do
  @moduledoc """
  AI client module for interacting with OpenAI-compatible APIs using Instructor.

  Supports multiple providers:
  - DeepSeek
  - Zhipu AI (ChatGLM)
  - Moonshot AI (Kimi)
  - OpenAI
  """

  alias GsmlgAppAdmin.AI.Provider

  @doc """
  Sends a chat completion request to the specified provider.

  ## Parameters
    - provider: The AI provider configuration
    - messages: List of message maps with :role and :content
    - opts: Optional parameters (temperature, max_tokens, stream, etc.)

  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def chat_completion(provider, messages, opts \\ []) do
    stream? = Keyword.get(opts, :stream, false)

    params = build_params(provider, messages, opts)
    headers = build_headers(provider)

    url = "#{provider.api_base_url}/chat/completions"

    if stream? do
      stream_chat_completion(url, headers, params)
    else
      request_chat_completion(url, headers, params)
    end
  end

  @doc """
  Streams a chat completion response from the provider.
  """
  def stream_chat_completion(url, headers, params) do
    params = Map.put(params, :stream, true)

    case Req.post(url,
           headers: headers,
           json: params,
           into: :self,
           receive_timeout: 60_000
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :streaming}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @doc """
  Makes a non-streaming chat completion request.
  """
  def request_chat_completion(url, headers, params) do
    case Req.post(url,
           headers: headers,
           json: params,
           receive_timeout: 60_000
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_response(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @doc """
  Streams chat completion with a callback function for each chunk.

  The callback receives each delta content as it arrives.
  """
  def stream_with_callback(provider, messages, callback, opts \\ []) do
    params = build_params(provider, messages, opts) |> Map.put(:stream, true)
    headers = build_headers(provider)
    url = "#{provider.api_base_url}/chat/completions"

    Req.post(url,
      headers: headers,
      json: params,
      into: fn {:data, data}, {req, resp} ->
        # Parse SSE format: "data: {...}\n\n"
        data
        |> String.split("\n\n", trim: true)
        |> Enum.each(fn line ->
          case String.trim_leading(line, "data: ") do
            "[DONE]" ->
              :ok

            json_str ->
              case Jason.decode(json_str) do
                {:ok, chunk} ->
                  if content = get_in(chunk, ["choices", Access.at(0), "delta", "content"]) do
                    callback.(content)
                  end

                {:error, _} ->
                  :ok
              end
          end
        end)

        {:cont, {req, resp}}
      end
    )
  end

  # Private functions

  defp build_params(provider, messages, opts) do
    base_params = provider.default_params || %{}

    params = %{
      model: Keyword.get(opts, :model, provider.model),
      messages: format_messages(messages)
    }

    # Merge provider defaults with custom opts
    params
    |> Map.merge(base_params)
    |> maybe_put(:temperature, Keyword.get(opts, :temperature))
    |> maybe_put(:max_tokens, Keyword.get(opts, :max_tokens))
    |> maybe_put(:top_p, Keyword.get(opts, :top_p))
  end

  defp build_headers(provider) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{provider.api_key}"}
    ]
  end

  defp format_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        "role" => to_string(msg.role || msg["role"]),
        "content" => msg.content || msg["content"]
      }
    end)
  end

  defp parse_response(body) when is_map(body) do
    case get_in(body, ["choices", Access.at(0), "message", "content"]) do
      nil ->
        {:error, "Invalid response format: #{inspect(body)}"}

      content ->
        {:ok,
         %{
           content: content,
           model: body["model"],
           usage: body["usage"]
         }}
    end
  end

  defp parse_response(body) do
    {:error, "Invalid response body: #{inspect(body)}"}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
