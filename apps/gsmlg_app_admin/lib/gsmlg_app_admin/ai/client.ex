defmodule GsmlgAppAdmin.AI.Client do
  @moduledoc """
  AI client module backed by the configured Backplane API server.

  Backplane owns provider routing, credential injection, embeddings, and MCP
  tool access. This client only adapts the app's normalized request shape to
  Backplane's OpenAI-compatible and Anthropic-compatible `/v1/*` endpoints.
  """

  alias GsmlgAppAdmin.AI.BackplaneClient

  @doc """
  Sends a chat completion request through Backplane.

  ## Parameters
    - request: Normalized gateway request map.
    - opts: Optional parameters and Req options.

  ## Returns
    - {:ok, response_map} on success (with :content, :model, :usage, :tool_calls keys)
    - {:error, reason} on failure
  """
  def chat_completion(request, opts \\ []) do
    api_format = Keyword.get(opts, :api_format, :openai)

    case BackplaneClient.post(request_path(api_format), request_body(api_format, request), opts) do
      {:ok, body} -> {:ok, normalize_response(api_format, body, request.model)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Streams chat completion with a callback function for each chunk.

  The callback receives `{:content, text}` or `{:thinking, text}` tuples.
  """
  def stream_with_callback(request, callback, opts \\ []) do
    api_format = Keyword.get(opts, :api_format, :openai)
    body = request_body(api_format, Map.put(request, :stream, true))

    into = fn {:data, data}, {req, resp} ->
      {events, buffer} = split_sse_events(to_string(resp.body || "") <> data)
      Enum.each(events, &handle_sse_event(&1, api_format, callback))
      {:cont, {req, %{resp | body: buffer}}}
    end

    case BackplaneClient.post(request_path(api_format), body, Keyword.put(opts, :into, into)) do
      {:ok, _body} -> {:ok, :streaming_complete}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e ->
      {:error, "Streaming failed: #{Exception.message(e)}"}
  end

  @doc """
  Sends an image generation request through Backplane.

  ## Parameters
    - params: Map with prompt, model, n, size, quality, response_format, style

  ## Returns
    - {:ok, response_body} on success
    - {:error, reason} on failure
  """
  def image_generation(params, req_opts \\ []) do
    BackplaneClient.post("/v1/images/generations", params, req_opts)
  end

  @doc "Sends an embeddings request through Backplane."
  def embeddings(params, req_opts \\ []) do
    BackplaneClient.post("/v1/embeddings", params, req_opts)
  end

  @doc "Lists models exposed by Backplane."
  def list_models(req_opts \\ []) do
    BackplaneClient.get("/v1/models", req_opts)
  end

  # -- Private: Request Building --

  defp request_path(:anthropic), do: "/v1/messages"
  defp request_path(_), do: "/v1/chat/completions"

  defp request_body(:anthropic, request) do
    params = request[:params] || %{}

    %{
      "model" => request.model,
      "messages" => Enum.map(request.messages || [], &message_for_anthropic/1),
      "max_tokens" => param(params, :max_tokens) || 4096,
      "stream" => request[:stream] == true
    }
    |> maybe_put("system", request[:system])
    |> maybe_put("temperature", param(params, :temperature))
    |> maybe_put("top_p", param(params, :top_p))
    |> maybe_put("tools", request[:tools])
  end

  defp request_body(_openai, request) do
    params = request[:params] || %{}

    %{
      "model" => request.model,
      "messages" => openai_messages(request),
      "stream" => request[:stream] == true
    }
    |> maybe_put("temperature", param(params, :temperature))
    |> maybe_put("max_tokens", param(params, :max_tokens))
    |> maybe_put("top_p", param(params, :top_p))
    |> maybe_put("tools", request[:tools])
    |> maybe_put("tool_choice", request[:tool_choice])
  end

  defp openai_messages(request) do
    system_messages =
      case request[:system] do
        nil -> []
        "" -> []
        system -> [%{"role" => "system", "content" => system}]
      end

    system_messages ++ Enum.map(request.messages || [], &message_for_openai/1)
  end

  defp message_for_openai(message) do
    %{
      "role" => to_string(message[:role] || message["role"]),
      "content" => message[:content] || message["content"] || ""
    }
    |> maybe_put("tool_call_id", message[:tool_call_id] || message["tool_call_id"])
    |> maybe_put("tool_calls", message[:tool_calls] || message["tool_calls"])
    |> maybe_put("name", message[:name] || message["name"])
  end

  defp message_for_anthropic(message) do
    %{
      "role" => to_string(message[:role] || message["role"]),
      "content" => message[:content] || message["content"] || ""
    }
  end

  defp param(params, key), do: params[key] || params[to_string(key)]

  # -- Private: Response Normalization --

  defp normalize_response(:anthropic, body, fallback_model) when is_map(body) do
    %{
      content: anthropic_text(body["content"] || body[:content]),
      model: body["model"] || body[:model] || fallback_model,
      usage: normalize_anthropic_usage(body["usage"] || body[:usage]),
      tool_calls: []
    }
  end

  defp normalize_response(_openai, body, fallback_model) when is_map(body) do
    choice = first_choice(body)
    message = choice["message"] || choice[:message] || %{}

    %{
      content: message["content"] || message[:content] || body["output_text"] || "",
      model: body["model"] || body[:model] || fallback_model,
      usage: normalize_usage(body["usage"] || body[:usage]),
      tool_calls: message["tool_calls"] || message[:tool_calls] || []
    }
  end

  defp normalize_response(_format, body, fallback_model) do
    %{content: to_string(body), model: fallback_model, usage: %{}, tool_calls: []}
  end

  defp first_choice(%{"choices" => [choice | _]}), do: choice
  defp first_choice(%{choices: [choice | _]}), do: choice
  defp first_choice(_body), do: %{}

  defp anthropic_text(content) when is_binary(content), do: content

  defp anthropic_text(content) when is_list(content) do
    Enum.map_join(content, "", fn
      %{"type" => "text", "text" => text} -> text
      %{type: "text", text: text} -> text
      _ -> ""
    end)
  end

  defp anthropic_text(_content), do: ""

  defp normalize_usage(nil), do: %{}

  defp normalize_usage(usage) when is_map(usage) do
    prompt =
      usage[:input_tokens] || usage["input_tokens"] || usage[:prompt_tokens] ||
        usage["prompt_tokens"] || 0

    completion =
      usage[:output_tokens] || usage["output_tokens"] || usage[:completion_tokens] ||
        usage["completion_tokens"] || 0

    total = usage[:total_tokens] || usage["total_tokens"] || prompt + completion

    %{
      prompt_tokens: prompt,
      completion_tokens: completion,
      total_tokens: total
    }
  end

  defp normalize_anthropic_usage(nil), do: %{}

  defp normalize_anthropic_usage(usage) when is_map(usage) do
    prompt = usage["input_tokens"] || usage[:input_tokens] || 0
    completion = usage["output_tokens"] || usage[:output_tokens] || 0

    %{
      prompt_tokens: prompt,
      completion_tokens: completion,
      total_tokens: usage["total_tokens"] || usage[:total_tokens] || prompt + completion
    }
  end

  # -- Private: SSE Parsing --

  defp split_sse_events(buffer) do
    parts = Regex.split(~r/\r?\n\r?\n/, buffer)

    if Regex.match?(~r/\r?\n\r?\n$/, buffer) do
      {Enum.reject(parts, &(&1 == "")), ""}
    else
      {parts |> Enum.drop(-1) |> Enum.reject(&(&1 == "")), List.last(parts) || ""}
    end
  end

  defp handle_sse_event(event, api_format, callback) do
    event
    |> event_data()
    |> dispatch_sse_data(api_format, callback)
  end

  defp event_data(event) do
    event
    |> String.split(~r/\r?\n/)
    |> Enum.filter(&String.starts_with?(&1, "data:"))
    |> Enum.map(fn line ->
      line |> String.replace_prefix("data:", "") |> String.trim_leading()
    end)
    |> Enum.join("\n")
  end

  defp dispatch_sse_data("", _api_format, _callback), do: :ok
  defp dispatch_sse_data("[DONE]", _api_format, _callback), do: :ok

  defp dispatch_sse_data(data, api_format, callback) do
    case Jason.decode(data) do
      {:ok, decoded} -> dispatch_decoded_sse(decoded, api_format, callback)
      {:error, _} -> :ok
    end
  end

  defp dispatch_decoded_sse(decoded, :anthropic, callback) do
    delta = decoded["delta"] || %{}

    cond do
      is_binary(delta["text"]) -> callback.({:content, delta["text"]})
      is_binary(delta["thinking"]) -> callback.({:thinking, delta["thinking"]})
      true -> :ok
    end
  end

  defp dispatch_decoded_sse(decoded, _openai, callback) do
    delta =
      decoded
      |> first_choice()
      |> then(&(&1["delta"] || &1[:delta] || %{}))

    cond do
      is_binary(delta["content"]) -> callback.({:content, delta["content"]})
      is_binary(delta[:content]) -> callback.({:content, delta[:content]})
      is_binary(delta["reasoning_content"]) -> callback.({:thinking, delta["reasoning_content"]})
      is_binary(delta[:reasoning_content]) -> callback.({:thinking, delta[:reasoning_content]})
      true -> :ok
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
