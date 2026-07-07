defmodule GsmlgAppAdmin.AI.Gateway do
  @moduledoc """
  Core orchestration module for the AI API Gateway.

  Works with a normalized internal format — controllers handle format translation.
  Provides entry points for chat completions, embeddings, image generation, OCR,
  and agent execution. Backplane owns downstream provider/model routing.
  """

  alias GsmlgAppAdmin.Accounts
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
    scope = Keyword.get(opts, :scope, :chat_completions)

    with :ok <- validate_model_access(api_key, request.model),
         :ok <- check_scope(api_key, scope) do
      request = inject_system_context(api_key, request)
      call_opts = client_call_opts(request, opts, scope)
      request_ip = Keyword.get(opts, :request_ip)

      if request[:stream] do
        stream_callback = Keyword.get(opts, :stream_callback)
        result = Client.stream_with_callback(request, stream_callback, call_opts)

        case result do
          {:ok, :streaming_complete} ->
            log_usage(api_key, request, :chat, :success, request_ip: request_ip)
            {:ok, :streaming_complete}

          {:error, reason} ->
            log_usage(api_key, request, :chat, :error, request_ip: request_ip)
            {:error, reason}
        end
      else
        case Client.chat_completion(request, call_opts) do
          {:ok, response} ->
            log_usage(api_key, request, :chat, :success,
              tokens: get_in(response, [:usage, :total_tokens]) || 0,
              prompt_tokens: get_in(response, [:usage, :prompt_tokens]) || 0,
              completion_tokens: get_in(response, [:usage, :completion_tokens]) || 0,
              request_ip: request_ip
            )

            {:ok, response}

          {:error, reason} ->
            log_usage(api_key, request, :chat, :error, request_ip: request_ip)
            {:error, reason}
        end
      end
    end
  end

  @doc """
  Validates local model restrictions before a request is sent to Backplane.
  """
  def resolve_provider(api_key, model) do
    with :ok <- validate_model_access(api_key, model), do: {:ok, :backplane}
  end

  @doc """
  Lists available models for the given API key.
  """
  def list_models(api_key, opts \\ []) do
    case Client.list_models(Keyword.get(opts, :client_opts, [])) do
      {:ok, %{"data" => models}} when is_list(models) ->
        {:ok, filter_models_by_key(models, api_key)}

      {:ok, %{data: models}} when is_list(models) ->
        {:ok, filter_models_by_key(models, api_key)}

      {:ok, _body} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Runs a named agent through Backplane.

  Backplane owns MCP/tool access and downstream model routing. The local agent
  layer validates scope/model access, injects system context, and proxies one
  request to Backplane.
  """
  def run_agent(api_key, agent, messages, opts \\ []) do
    model = Keyword.get(opts, :model, agent.model)
    max_iterations = Keyword.get(opts, :max_iterations, agent.max_iterations)

    with :ok <- validate_model_access(api_key, model),
         :ok <- check_scope(api_key, :agents) do
      if max_iterations <= 0 do
        {:error, "Agent reached maximum iterations (#{max_iterations}) without a final response."}
      else
        run_backplane_agent(api_key, agent, messages, model, opts)
      end
    end
  end

  defp run_backplane_agent(api_key, agent, messages, model, opts) do
    caller_system = Keyword.get(opts, :caller_system)

    agent_system =
      case {agent[:system_prompt], caller_system} do
        {nil, nil} -> nil
        {nil, cs} -> cs
        {as, nil} -> as
        {as, cs} -> "#{as}\n\n#{cs}"
      end

    request = %{
      model: model,
      system: agent_system,
      messages: messages,
      stream: false,
      params: agent.model_params || %{}
    }

    request = inject_system_context(api_key, request, agent_id: agent.id)
    call_opts = client_call_opts(request, opts, :chat_completions)
    request_ip = Keyword.get(opts, :request_ip)

    case Client.chat_completion(request, call_opts) do
      {:ok, response} ->
        total_tokens = get_in(response, [:usage, :total_tokens]) || 0

        log_usage(api_key, request, :agent, :success,
          tokens: total_tokens,
          agent_id: agent.id,
          request_ip: request_ip
        )

        {:ok,
         %{
           id: "agent_run_#{generate_id()}",
           agent: agent.slug,
           model: model,
           content: response[:content] || "",
           tool_calls_made: [],
           iterations: 1,
           usage: response[:usage] || %{total_tokens: total_tokens}
         }}

      {:error, reason} ->
        log_usage(api_key, request, :agent, :error, agent_id: agent.id, request_ip: request_ip)
        {:error, reason}
    end
  end

  @doc """
  Generates an image via the gateway.

  Proxies the request to Backplane's OpenAI-compatible images endpoint.
  """
  def generate_image(api_key, params, opts \\ []) do
    with :ok <- check_scope(api_key, :images) do
      model = params["model"]
      client_opts = Keyword.get(opts, :client_opts, [])
      request_ip = Keyword.get(opts, :request_ip)

      cond do
        is_nil(model) or model == "" ->
          {:error, "Missing required parameter 'model'. Specify an image generation model."}

        true ->
          with :ok <- validate_model_access(api_key, model) do
            case Client.image_generation(params, client_opts) do
              {:ok, response} ->
                log_usage(api_key, %{model: model}, :image, :success, request_ip: request_ip)
                {:ok, response}

              {:error, reason} ->
                log_usage(api_key, %{model: model}, :image, :error, request_ip: request_ip)
                {:error, reason}
            end
          end
      end
    end
  end

  @doc """
  Generates embeddings through Backplane.
  """
  def create_embedding(api_key, params, opts \\ []) do
    with :ok <- check_scope(api_key, :embeddings) do
      model = params["model"]
      client_opts = Keyword.get(opts, :client_opts, [])
      request_ip = Keyword.get(opts, :request_ip)

      cond do
        is_nil(model) or model == "" ->
          {:error, "Missing required parameter 'model'. Specify an embedding model."}

        true ->
          with :ok <- validate_model_access(api_key, model) do
            case Client.embeddings(params, client_opts) do
              {:ok, response} ->
                usage = response["usage"] || response[:usage] || %{}

                log_usage(api_key, %{model: model}, :embedding, :success,
                  tokens: usage["total_tokens"] || usage[:total_tokens] || 0,
                  prompt_tokens: usage["prompt_tokens"] || usage[:prompt_tokens] || 0,
                  request_ip: request_ip
                )

                {:ok, response}

              {:error, reason} ->
                log_usage(api_key, %{model: model}, :embedding, :error, request_ip: request_ip)
                {:error, reason}
            end
          end
      end
    end
  end

  @doc """
  Extracts text from an image via OCR.
  """
  def extract_text(api_key, params, opts \\ []) do
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

        image = params["image"]

        # Build a chat request with the image as a content block
        user_content =
          if image do
            [
              %{type: "image_url", image_url: %{url: image}},
              %{type: "text", text: "Please extract the text from this image."}
            ]
          else
            "Please extract the text from this image."
          end

        messages = [
          %{role: :user, content: user_content}
        ]

        request = %{
          model: model,
          system: system_prompt,
          messages: messages,
          stream: false,
          params: %{max_tokens: 4096}
        }

        case chat(api_key, request, Keyword.put(opts, :scope, :ocr)) do
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

  @doc false
  def inject_system_context(api_key, request, opts \\ []) do
    agent_id = Keyword.get(opts, :agent_id)

    # 1. Fetch default templates + key-specific + agent-specific templates
    templates = fetch_templates(api_key, agent_id: agent_id)

    # 2. Fetch memories (global + user + key + agent scoped)
    memories = fetch_memories(api_key, agent_id: agent_id)

    # 3. Render templates with variables
    memory_text = format_memories(memories)
    user_vars = fetch_user_variables(api_key)

    variables =
      Map.merge(user_vars, %{
        "memory" => memory_text,
        "date" => Date.utc_today() |> Date.to_iso8601(),
        "datetime" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    rendered_templates =
      Enum.map_join(templates, "\n\n", fn template ->
        render_template(template.content, variables)
      end)

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

  defp fetch_templates(api_key, opts) do
    agent_id = Keyword.get(opts, :agent_id)

    # Default templates (auto-injected for all requests)
    defaults =
      case AI.list_default_templates() do
        {:ok, templates} -> templates
        _ -> []
      end

    # Key-specific templates appended after defaults
    key_specific =
      case AI.list_templates_for_key(api_key.id) do
        {:ok, templates} -> templates
        _ -> []
      end

    # Agent-specific templates appended last (highest precedence)
    agent_specific =
      case AI.list_templates_for_agent(agent_id) do
        {:ok, templates} -> templates
        _ -> []
      end

    (defaults ++ key_specific ++ agent_specific)
    |> Enum.uniq_by(& &1.id)
  end

  defp fetch_memories(api_key, opts) do
    agent_id = Keyword.get(opts, :agent_id)

    request_opts =
      [user_id: api_key.user_id, api_key_id: api_key.id]
      |> then(fn o -> if agent_id, do: Keyword.put(o, :agent_id, agent_id), else: o end)

    case AI.get_memories_for_request(request_opts) do
      {:ok, memories} -> memories
      _ -> []
    end
  end

  defp fetch_user_variables(api_key) do
    user_id = Map.get(api_key, :user_id)

    if user_id do
      try do
        user = Accounts.get_user!(user_id)

        %{
          "user.display_name" => user.display_name || user.username || "",
          "user.email" => to_string(user.email),
          "user.username" => user.username || ""
        }
      rescue
        _ -> %{"user.display_name" => "", "user.email" => "", "user.username" => ""}
      end
    else
      %{"user.display_name" => "", "user.email" => "", "user.username" => ""}
    end
  end

  defp format_memories([]), do: ""

  defp format_memories(memories) do
    Enum.map_join(memories, "\n", fn m -> "- [#{m.category}] #{m.content}" end)
  end

  defp render_template(content, variables) do
    Enum.reduce(variables, content, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value || "")
    end)
  end

  defp build_call_opts(request, _opts) do
    params = request[:params] || %{}

    []
    |> Keyword.put(:model, request.model)
    |> maybe_put_opt(:temperature, params[:temperature] || params["temperature"])
    |> maybe_put_opt(:max_tokens, params[:max_tokens] || params["max_tokens"])
    |> maybe_put_opt(:top_p, params[:top_p] || params["top_p"])
    |> maybe_put_opt(:tools, request[:tools])
    |> maybe_put_opt(:tool_choice, request[:tool_choice])
  end

  defp client_call_opts(request, opts, scope) do
    request
    |> build_call_opts(opts)
    |> Keyword.put(:api_format, api_format_for_scope(scope))
    |> Keyword.merge(Keyword.get(opts, :client_opts, []))
  end

  defp api_format_for_scope(:messages), do: :anthropic
  defp api_format_for_scope(_scope), do: :openai

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp check_scope(api_key, scope) do
    if scope in (api_key.scopes || []) do
      :ok
    else
      {:error, "API key does not have the '#{scope}' scope."}
    end
  end

  defp validate_model_access(api_key, model) do
    allowed_models = Map.get(api_key, :allowed_models, []) || []

    if allowed_models != [] and model not in allowed_models do
      {:error, "API key does not have access to model '#{model}'."}
    else
      :ok
    end
  end

  defp filter_models_by_key(models, api_key) do
    allowed_models = Map.get(api_key, :allowed_models, []) || []

    if allowed_models == [] do
      models
    else
      Enum.filter(models, fn model ->
        model_id = model["id"] || model[:id]
        model_id in allowed_models
      end)
    end
  end

  defp log_usage(api_key, request, endpoint_type, status, opts) do
    tokens = Keyword.get(opts, :tokens, 0)
    prompt_tokens = Keyword.get(opts, :prompt_tokens, 0)
    completion_tokens = Keyword.get(opts, :completion_tokens, 0)
    agent_id = Keyword.get(opts, :agent_id)
    request_ip = Keyword.get(opts, :request_ip)

    log_fun = fn ->
      do_log_usage(api_key, request, endpoint_type, status,
        tokens: tokens,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        agent_id: agent_id,
        request_ip: request_ip
      )
    end

    if async_usage_logging?() do
      Task.Supervisor.start_child(GsmlgAppAdmin.TaskSupervisor, log_fun)
    else
      log_fun.()
    end
  end

  defp async_usage_logging? do
    Application.get_env(:gsmlg_app_admin, :async_usage_logging, true)
  end

  defp do_log_usage(api_key, request, endpoint_type, status, opts) do
    try do
      tokens = Keyword.fetch!(opts, :tokens)
      prompt_tokens = Keyword.fetch!(opts, :prompt_tokens)
      completion_tokens = Keyword.fetch!(opts, :completion_tokens)
      agent_id = Keyword.get(opts, :agent_id)
      request_ip = Keyword.get(opts, :request_ip)

      AI.ApiKey.increment_usage(api_key, 1, tokens)

      log_attrs = %{
        endpoint_type: endpoint_type,
        model: request[:model] || to_string(request.model),
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        total_tokens: tokens,
        status: status,
        api_key_id: api_key.id
      }

      log_attrs =
        if request_ip, do: Map.put(log_attrs, :request_ip, request_ip), else: log_attrs

      log_attrs =
        if agent_id, do: Map.put(log_attrs, :agent_id, agent_id), else: log_attrs

      AI.ApiUsageLog.create(log_attrs)
    rescue
      e ->
        Logger.warning(
          "Failed to log usage for key #{api_key.id} (#{endpoint_type}/#{status}): #{inspect(e)}"
        )
    end
  end
end
