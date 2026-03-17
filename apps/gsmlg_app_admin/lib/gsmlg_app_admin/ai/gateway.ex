defmodule GsmlgAppAdmin.AI.Gateway do
  @moduledoc """
  Core orchestration module for the AI API Gateway.

  Works with a normalized internal format — controllers handle format translation.
  Provides entry points for chat completions, image generation, OCR, and agent execution.
  """

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.Client

  require Logger

  @doc """
  Processes a chat completion request through the gateway.

  ## Parameters
    - api_key: The authenticated API key
    - request: Normalized internal request map
    - opts: Options (streaming callbacks, etc.)

  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def chat(api_key, request, opts \\ []) do
    with {:ok, provider} <- resolve_provider(api_key, request.model),
         :ok <- check_scope(api_key, :chat_completions) do
      messages = build_messages(request)
      call_opts = build_call_opts(request, opts)

      if request[:stream] do
        stream_callback = Keyword.get(opts, :stream_callback)
        result = Client.stream_with_callback(provider, messages, stream_callback, call_opts)

        case result do
          {:ok, :streaming_complete} ->
            log_usage(api_key, provider, request, :chat, :success)
            {:ok, :streaming_complete}

          {:error, reason} ->
            log_usage(api_key, provider, request, :chat, :error)
            {:error, reason}
        end
      else
        case Client.chat_completion(provider, messages, call_opts) do
          {:ok, response} ->
            tokens = get_in(response, [:usage, "total_tokens"]) || 0
            log_usage(api_key, provider, request, :chat, :success, tokens: tokens)
            {:ok, response}

          {:error, reason} ->
            log_usage(api_key, provider, request, :chat, :error)
            {:error, reason}
        end
      end
    end
  end

  @doc """
  Resolves a provider for the given model, filtered by key restrictions.
  """
  def resolve_provider(api_key, model) do
    require Ash.Query

    case AI.list_active_providers() do
      {:ok, providers} ->
        providers =
          providers
          |> filter_by_key_restrictions(api_key)
          |> find_provider_for_model(model)

        case providers do
          nil -> {:error, "No provider found for model '#{model}'."}
          provider -> {:ok, provider}
        end

      {:error, _} ->
        {:error, "Failed to load providers."}
    end
  end

  @doc """
  Lists available models for the given API key.
  """
  def list_models(api_key) do
    case AI.list_active_providers() do
      {:ok, providers} ->
        providers = filter_by_key_restrictions(providers, api_key)

        models =
          providers
          |> Enum.flat_map(fn provider ->
            all_models = [provider.model | provider.available_models || []]

            all_models
            |> Enum.uniq()
            |> Enum.filter(fn model ->
              api_key.allowed_models == [] or model in api_key.allowed_models
            end)
            |> Enum.map(fn model ->
              %{
                id: model,
                object: "model",
                created: DateTime.to_unix(provider.created_at),
                owned_by: provider.slug
              }
            end)
          end)
          |> Enum.uniq_by(& &1.id)

        {:ok, models}

      {:error, _} ->
        {:error, "Failed to load models."}
    end
  end

  defp filter_by_key_restrictions(providers, api_key) do
    providers
    |> Enum.filter(fn provider ->
      api_key.allowed_providers == [] or provider.id in api_key.allowed_providers
    end)
  end

  defp find_provider_for_model(providers, model) do
    Enum.find(providers, fn provider ->
      all_models = [provider.model | provider.available_models || []]
      model in all_models
    end)
  end

  defp build_messages(request) do
    system_messages =
      case request[:system] do
        nil -> []
        system -> [%{role: "system", content: system}]
      end

    user_messages =
      Enum.map(request.messages, fn msg ->
        %{role: to_string(msg.role), content: msg.content}
      end)

    system_messages ++ user_messages
  end

  defp build_call_opts(request, _opts) do
    params = request[:params] || %{}

    []
    |> Keyword.put(:model, request.model)
    |> maybe_put_opt(:temperature, params[:temperature] || params["temperature"])
    |> maybe_put_opt(:max_tokens, params[:max_tokens] || params["max_tokens"])
    |> maybe_put_opt(:top_p, params[:top_p] || params["top_p"])
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp check_scope(api_key, scope) do
    if scope in (api_key.scopes || []) do
      :ok
    else
      {:error, "API key does not have the '#{scope}' scope."}
    end
  end

  defp log_usage(api_key, _provider, _request, _endpoint_type, _status, opts \\ []) do
    # Increment aggregate counters on the API key
    tokens = Keyword.get(opts, :tokens, 0)

    Task.start(fn ->
      try do
        AI.ApiKey.increment_usage(api_key, 1, tokens)
      rescue
        _ -> :ok
      end
    end)
  end
end
