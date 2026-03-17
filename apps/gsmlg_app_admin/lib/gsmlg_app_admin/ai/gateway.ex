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
      # Inject system prompts and memories
      request = inject_system_context(api_key, request)
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

  @doc """
  Runs a named agent with the tool execution loop.
  """
  def run_agent(api_key, agent, messages, opts \\ []) do
    model = Keyword.get(opts, :model, agent.model)
    _max_iterations = Keyword.get(opts, :max_iterations, agent.max_iterations)

    with {:ok, provider} <- resolve_provider(api_key, model),
         :ok <- check_scope(api_key, :agents) do
      # Build agent request
      request = %{
        model: model,
        system: nil,
        messages: messages,
        stream: false,
        params: agent.model_params || %{}
      }

      # Inject agent system context
      request = inject_system_context(api_key, request)

      all_messages = build_messages(request)
      call_opts = build_call_opts(request, opts)

      # Simple non-streaming agent execution
      case Client.chat_completion(provider, all_messages, call_opts) do
        {:ok, response} ->
          tokens = get_in(response, [:usage, "total_tokens"]) || 0
          log_usage(api_key, provider, request, :agent, :success, tokens: tokens)

          {:ok,
           %{
             id: "agent_run_#{generate_id()}",
             agent: agent.slug,
             model: model,
             content: response.content,
             iterations: 1,
             usage: response[:usage] || %{}
           }}

        {:error, reason} ->
          log_usage(api_key, provider, request, :agent, :error)
          {:error, reason}
      end
    end
  end

  @doc """
  Generates an image via the gateway.
  """
  def generate_image(api_key, _params) do
    with :ok <- check_scope(api_key, :images) do
      # Image generation is a stub — will be implemented with ImageClient
      {:error, "Image generation not yet configured. Add image providers in admin settings."}
    end
  end

  @doc """
  Extracts text from an image via OCR.
  """
  def extract_text(api_key, params) do
    with :ok <- check_scope(api_key, :ocr) do
      model = params["model"]

      if model do
        # Use vision LLM for OCR
        output_format = params["output_format"] || "text"

        format_instruction =
          case output_format do
            "markdown" -> "Output as well-structured markdown with tables where applicable."
            "json" -> "Output as a JSON object with key-value pairs for extracted fields."
            _ -> "Output as plain text."
          end

        system_prompt =
          "Extract all text from the provided image. Preserve formatting, tables, and structure. #{format_instruction}"

        custom_prompt = params["prompt"]

        system_prompt =
          if custom_prompt, do: "#{system_prompt}\n\n#{custom_prompt}", else: system_prompt

        _image = params["image"]

        # Build a chat request with the image
        messages = [
          %{role: :user, content: "Please extract the text from this image."}
        ]

        request = %{
          model: model,
          system: system_prompt,
          messages: messages,
          stream: false,
          params: %{max_tokens: 4096}
        }

        case chat(api_key, request) do
          {:ok, response} ->
            {:ok,
             %{
               id: "ocr_#{generate_id()}",
               model: model,
               content: response.content,
               output_format: output_format,
               usage: response[:usage] || %{}
             }}

          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error,
         "No OCR model specified. Provide a 'model' parameter or configure a default OCR provider."}
      end
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
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

  @doc false
  def inject_system_context(api_key, request) do
    # 1. Fetch default templates + key-specific templates
    templates = fetch_templates(api_key)

    # 2. Fetch memories (global + user + key scoped)
    memories = fetch_memories(api_key)

    # 3. Render templates with variables
    memory_text = format_memories(memories)

    variables = %{
      "memory" => memory_text,
      "date" => Date.utc_today() |> Date.to_iso8601(),
      "datetime" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    rendered_templates =
      templates
      |> Enum.map(fn template -> render_template(template.content, variables) end)
      |> Enum.join("\n\n")

    # 4. Merge admin system prompt with caller's system prompt
    admin_system =
      case rendered_templates do
        "" -> nil
        text -> text
      end

    # If no template uses {{memory}} and we have memories, add them as separate context
    admin_system =
      if admin_system && String.contains?(rendered_templates, memory_text) do
        admin_system
      else
        case {admin_system, memory_text} do
          {nil, ""} -> nil
          {nil, mem} -> "Context:\n#{mem}"
          {sys, ""} -> sys
          {sys, mem} -> "#{sys}\n\nContext:\n#{mem}"
        end
      end

    # Prepend admin system to caller's system
    combined_system =
      case {admin_system, request[:system]} do
        {nil, caller} -> caller
        {admin, nil} -> admin
        {admin, caller} -> "#{admin}\n\n#{caller}"
      end

    Map.put(request, :system, combined_system)
  end

  defp fetch_templates(_api_key) do
    # Get default templates
    case AI.list_default_templates() do
      {:ok, templates} -> templates
      _ -> []
    end
  end

  defp fetch_memories(api_key) do
    case AI.get_memories_for_request(
           user_id: api_key.user_id,
           api_key_id: api_key.id
         ) do
      {:ok, memories} -> memories
      _ -> []
    end
  end

  defp format_memories([]), do: ""

  defp format_memories(memories) do
    memories
    |> Enum.map(fn m -> "- [#{m.category}] #{m.content}" end)
    |> Enum.join("\n")
  end

  defp render_template(content, variables) do
    Enum.reduce(variables, content, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value || "")
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
