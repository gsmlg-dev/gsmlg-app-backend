defmodule GsmlgAppAdmin.AI.Client do
  @moduledoc """
  AI client module using ReqLLM for standardized LLM API access.

  Supports multiple providers via ReqLLM's unified interface.
  """

  @doc """
  Sends a chat completion request to the specified provider.

  ## Parameters
    - provider: The AI provider configuration (Ash resource with api_base_url, api_key, model, etc.)
    - messages: List of message maps with :role and :content
    - opts: Optional parameters (temperature, max_tokens, model override, tools, etc.)

  ## Returns
    - {:ok, response_map} on success (with :content, :model, :usage, :tool_calls keys)
    - {:error, reason} on failure
  """
  def chat_completion(provider, messages, opts \\ []) do
    model_spec = build_model_spec(provider, opts)
    req_opts = build_req_opts(provider, opts)

    case ReqLLM.generate_text(model_spec, format_messages(messages), req_opts) do
      {:ok, response} ->
        {:ok, normalize_response(response, provider, opts)}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  @doc """
  Streams chat completion with a callback function for each chunk.

  The callback receives `{:content, text}` or `{:thinking, text}` tuples.
  """
  def stream_with_callback(provider, messages, callback, opts \\ []) do
    model_spec = build_model_spec(provider, opts)
    req_opts = build_req_opts(provider, opts)

    case ReqLLM.stream_text(model_spec, format_messages(messages), req_opts) do
      {:ok, stream_response} ->
        case ReqLLM.StreamResponse.process_stream(stream_response,
               on_result: fn text -> callback.({:content, text}) end,
               on_thinking: fn text -> callback.({:thinking, text}) end
             ) do
          {:error, reason} ->
            {:error, format_error(reason)}

          _response ->
            {:ok, :streaming_complete}
        end

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  rescue
    e ->
      {:error, "Streaming failed: #{Exception.message(e)}"}
  end

  @doc """
  Sends an image generation request to an OpenAI-compatible images endpoint.

  ## Parameters
    - provider: The AI provider configuration
    - params: Map with prompt, model, n, size, quality, response_format, style

  ## Returns
    - {:ok, response_body} on success
    - {:error, reason} on failure
  """
  def image_generation(provider, params, req_opts \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{provider.api_key}"}
    ]

    url = "#{provider.api_base_url}/images/generations"

    body =
      %{model: params["model"] || provider.model, prompt: params["prompt"]}
      |> maybe_put(:n, params["n"])
      |> maybe_put(:size, params["size"])
      |> maybe_put(:quality, params["quality"])
      |> maybe_put(:response_format, params["response_format"])
      |> maybe_put(:style, params["style"])

    req_options =
      Keyword.merge([headers: headers, json: body, receive_timeout: 120_000], req_opts)

    case Req.post(url, req_options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, extract_error_message(body, status)}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  # -- Private: Model Spec --

  defp build_model_spec(provider, opts) do
    model = Keyword.get(opts, :model, provider.model)

    %{
      provider: map_provider(provider.slug),
      id: model,
      base_url: provider.api_base_url
    }
  end

  # Map our provider slugs to ReqLLM provider atoms.
  defp map_provider("anthropic"), do: :anthropic
  defp map_provider("google"), do: :google
  defp map_provider("groq"), do: :groq
  defp map_provider("xai"), do: :xai
  defp map_provider("amazon_bedrock"), do: :amazon_bedrock
  defp map_provider("azure"), do: :azure
  defp map_provider("cerebras"), do: :cerebras
  defp map_provider("openrouter"), do: :openrouter
  defp map_provider(_), do: :openai

  # -- Private: Messages --

  defp format_messages(messages) do
    Enum.map(messages, fn msg ->
      base = %{
        "role" => to_string(msg[:role] || msg["role"]),
        "content" => msg[:content] || msg["content"]
      }

      # Preserve tool-related fields for multi-turn tool use
      base
      |> maybe_put("tool_call_id", msg[:tool_call_id] || msg["tool_call_id"])
      |> maybe_put("tool_calls", msg[:tool_calls] || msg["tool_calls"])
      |> maybe_put("name", msg[:name] || msg["name"])
    end)
  end

  # -- Private: Options --

  defp build_req_opts(provider, opts) do
    base_params = provider.default_params || %{}

    []
    |> Keyword.put(:api_key, provider.api_key)
    |> Keyword.put(:base_url, provider.api_base_url)
    |> maybe_put_opt(:temperature, Keyword.get(opts, :temperature) || base_params["temperature"])
    |> maybe_put_opt(:max_tokens, Keyword.get(opts, :max_tokens) || base_params["max_tokens"])
    |> maybe_put_opt(:top_p, Keyword.get(opts, :top_p) || base_params["top_p"])
    |> maybe_put_opt(:tools, Keyword.get(opts, :tools))
    |> maybe_put_opt(:tool_choice, Keyword.get(opts, :tool_choice))
  end

  # -- Private: Response Normalization --

  defp normalize_response(response, provider, opts) do
    text = ReqLLM.Response.text(response)
    usage = ReqLLM.Response.usage(response)
    tool_calls = ReqLLM.Response.tool_calls(response)

    %{
      content: text,
      model: Keyword.get(opts, :model, provider.model),
      usage: normalize_usage(usage),
      tool_calls: tool_calls
    }
  end

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

  # -- Private: Error Formatting --

  defp format_error(%{message: message}), do: message
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  # -- Private: Image Generation Helpers --

  defp extract_error_message(body, status) when is_map(body) do
    case get_in(body, ["error", "message"]) do
      nil ->
        case body["message"] do
          nil -> "HTTP #{status}: #{inspect(body)}"
          msg -> "HTTP #{status}: #{msg}"
        end

      msg ->
        "HTTP #{status}: #{msg}"
    end
  end

  defp extract_error_message(body, status) when is_binary(body) and body != "" do
    case Jason.decode(body) do
      {:ok, decoded} -> extract_error_message(decoded, status)
      {:error, _} -> "HTTP #{status}: #{body}"
    end
  end

  defp extract_error_message(_body, status), do: "HTTP #{status}: Unknown error"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
