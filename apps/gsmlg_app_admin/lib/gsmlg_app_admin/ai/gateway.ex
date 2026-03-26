defmodule GsmlgAppAdmin.AI.Gateway do
  @moduledoc """
  Core orchestration module for the AI API Gateway.

  Works with a normalized internal format — controllers handle format translation.
  Provides entry points for chat completions, image generation, OCR, and agent execution.
  """

  alias GsmlgAppAdmin.Accounts
  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.Client
  alias GsmlgAppAdmin.AI.ToolExecutor

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

    with {:ok, provider} <- resolve_provider(api_key, request.model),
         :ok <- check_scope(api_key, scope) do
      # Inject system prompts and memories
      request = inject_system_context(api_key, request)
      messages = build_messages(request)
      call_opts = build_call_opts(request, opts)
      request_ip = Keyword.get(opts, :request_ip)

      if request[:stream] do
        stream_callback = Keyword.get(opts, :stream_callback)
        result = Client.stream_with_callback(provider, messages, stream_callback, call_opts)

        case result do
          {:ok, :streaming_complete} ->
            log_usage(api_key, provider, request, :chat, :success, request_ip: request_ip)
            {:ok, :streaming_complete}

          {:error, reason} ->
            log_usage(api_key, provider, request, :chat, :error, request_ip: request_ip)
            {:error, reason}
        end
      else
        case Client.chat_completion(provider, messages, call_opts) do
          {:ok, response} ->
            log_usage(api_key, provider, request, :chat, :success,
              tokens: get_in(response, [:usage, :total_tokens]) || 0,
              prompt_tokens: get_in(response, [:usage, :prompt_tokens]) || 0,
              completion_tokens: get_in(response, [:usage, :completion_tokens]) || 0,
              request_ip: request_ip
            )

            {:ok, response}

          {:error, reason} ->
            log_usage(api_key, provider, request, :chat, :error, request_ip: request_ip)
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

    allowed_models = Map.get(api_key, :allowed_models, []) || []

    if allowed_models != [] and model not in allowed_models do
      {:error, "API key does not have access to model '#{model}'."}
    else
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
              allowed_models = Map.get(api_key, :allowed_models, []) || []
              allowed_models == [] or model in allowed_models
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

  The agent iterates: call LLM → if tool_calls in response, execute tools,
  append results, call LLM again. Stops when LLM returns content without
  tool_calls or max_iterations is reached.
  """
  def run_agent(api_key, agent, messages, opts \\ []) do
    model = Keyword.get(opts, :model, agent.model)
    max_iterations = Keyword.get(opts, :max_iterations, agent.max_iterations)

    with {:ok, provider} <- resolve_provider(api_key, model),
         :ok <- check_scope(api_key, :agents) do
      # Load agent's tools (empty list on error — agent can still run without tools)
      tools =
        case AI.list_tools_for_agent(agent.id) do
          {:ok, t} ->
            t

          {:error, reason} ->
            Logger.warning("Agent #{agent.slug}: failed to load tools — #{inspect(reason)}")
            []
        end

      # Build agent request with agent's own system prompt + caller system prompt
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

      # Inject agent system context (including agent-scoped memories)
      request = inject_system_context(api_key, request, agent_id: agent.id)

      all_messages = build_messages(request)
      call_opts = build_call_opts(request, opts)

      # Add tool definitions if agent has tools
      call_opts =
        if tools != [] do
          tool_defs = Enum.map(tools, &tool_to_function_def/1)
          Keyword.put(call_opts, :tools, tool_defs)
        else
          call_opts
        end

      # Run the agent loop
      request_ip = Keyword.get(opts, :request_ip)

      case agent_loop(provider, all_messages, call_opts, tools, max_iterations, 0, []) do
        {:ok, content, iterations, total_tokens, tool_calls_made} ->
          log_usage(api_key, provider, request, :agent, :success,
            tokens: total_tokens,
            agent_id: agent.id,
            request_ip: request_ip
          )

          {:ok,
           %{
             id: "agent_run_#{generate_id()}",
             agent: agent.slug,
             model: model,
             content: content,
             tool_calls_made: tool_calls_made,
             iterations: iterations,
             usage: %{total_tokens: total_tokens}
           }}

        {:error, reason} ->
          log_usage(api_key, provider, request, :agent, :error, request_ip: request_ip)
          {:error, reason}
      end
    end
  end

  defp agent_loop(_provider, _messages, _call_opts, _tools, max_iter, iteration, _acc)
       when iteration >= max_iter do
    {:error, "Agent reached maximum iterations (#{max_iter}) without a final response."}
  end

  defp agent_loop(provider, messages, call_opts, tools, max_iter, iteration, tool_calls_acc) do
    case Client.chat_completion(provider, messages, call_opts) do
      {:ok, response} ->
        tokens = get_in(response, [:usage, :total_tokens]) || 0
        tool_calls = response[:tool_calls] || []

        if tool_calls == [] do
          # No tool calls — final response
          {:ok, response[:content] || "", iteration + 1, tokens, tool_calls_acc}
        else
          # Execute each tool call with timing, build tool result messages
          {tool_messages, new_metadata} = execute_tool_calls_with_timing(tool_calls, tools)

          # Append assistant message (with tool_calls) and tool results
          updated_messages =
            messages ++
              [%{role: "assistant", content: response.content, tool_calls: tool_calls}] ++
              tool_messages

          agent_loop(
            provider,
            updated_messages,
            call_opts,
            tools,
            max_iter,
            iteration + 1,
            tool_calls_acc ++ new_metadata
          )
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_tool_calls_with_timing(tool_calls, tools) do
    tools_by_name = Map.new(tools, fn t -> {t.name, t} end)

    {messages, metadata} =
      Enum.map(tool_calls, fn tc ->
        tool_name = tc["function"]["name"] || tc[:function][:name]
        arguments = parse_tool_arguments(tc["function"]["arguments"] || tc[:function][:arguments])
        call_id = tc["id"] || tc[:id] || generate_id()

        start = System.monotonic_time(:millisecond)
        result = run_tool(tools_by_name, tool_name, arguments)
        duration_ms = System.monotonic_time(:millisecond) - start

        message = %{role: "tool", tool_call_id: call_id, content: result}

        meta = %{
          tool: tool_name,
          arguments: arguments,
          duration_ms: duration_ms
        }

        {message, meta}
      end)
      |> Enum.unzip()

    {messages, metadata}
  end

  defp parse_tool_arguments(args) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, parsed} -> parsed
      _ -> %{"raw" => args}
    end
  end

  defp parse_tool_arguments(args) when is_map(args), do: args
  defp parse_tool_arguments(_), do: %{}

  defp run_tool(tools_by_name, tool_name, arguments) do
    case Map.get(tools_by_name, tool_name) do
      nil ->
        "Error: unknown tool '#{tool_name}'"

      tool ->
        case ToolExecutor.execute(tool, arguments) do
          {:ok, :passthrough} ->
            "Tool '#{tool_name}' is passthrough — result delegated to caller."

          {:ok, result} ->
            result

          {:error, reason} ->
            "Error executing tool '#{tool_name}': #{reason}"
        end
    end
  end

  defp tool_to_function_def(tool) do
    %{
      type: "function",
      function: %{
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters_schema || %{"type" => "object", "properties" => %{}}
      }
    }
  end

  @doc """
  Generates an image via the gateway.

  Proxies the request to an upstream provider's OpenAI-compatible images endpoint.
  The model in `params["model"]` is resolved against active providers.
  """
  def generate_image(api_key, params, opts \\ []) do
    with :ok <- check_scope(api_key, :images) do
      model = params["model"]
      client_opts = Keyword.get(opts, :client_opts, [])
      request_ip = Keyword.get(opts, :request_ip)

      if model do
        case resolve_provider(api_key, model) do
          {:ok, provider} ->
            case Client.image_generation(provider, params, client_opts) do
              {:ok, response} ->
                log_usage(api_key, provider, %{model: model}, :image, :success,
                  request_ip: request_ip
                )

                {:ok, response}

              {:error, reason} ->
                log_usage(api_key, provider, %{model: model}, :image, :error,
                  request_ip: request_ip
                )

                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error, "Missing required parameter 'model'. Specify an image generation model."}
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

  defp filter_by_key_restrictions(providers, api_key) do
    allowed = Map.get(api_key, :allowed_providers, []) || []

    providers
    |> Enum.filter(fn provider ->
      allowed == [] or provider.id in allowed
    end)
  end

  defp find_provider_for_model(providers, model) do
    Enum.find(providers, fn provider ->
      all_models = [provider.model | provider.available_models || []]
      model in all_models
    end)
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

  defp build_messages(request) do
    system_messages =
      case request[:system] do
        nil -> []
        system -> [%{role: "system", content: system}]
      end

    user_messages =
      Enum.map(request.messages, fn msg ->
        base = %{role: to_string(msg.role), content: msg.content}

        # Preserve tool-related fields for multi-turn tool use
        base
        |> maybe_put_if_present(msg, :tool_call_id)
        |> maybe_put_if_present(msg, :tool_calls)
        |> maybe_put_if_present(msg, :name)
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
    |> maybe_put_opt(:tools, request[:tools])
    |> maybe_put_opt(:tool_choice, request[:tool_choice])
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_put_if_present(map, source, key) do
    case Map.get(source, key) do
      nil -> map
      value -> Map.put(map, key, value)
    end
  end

  defp check_scope(api_key, scope) do
    if scope in (api_key.scopes || []) do
      :ok
    else
      {:error, "API key does not have the '#{scope}' scope."}
    end
  end

  defp log_usage(api_key, provider, request, endpoint_type, status, opts) do
    tokens = Keyword.get(opts, :tokens, 0)
    prompt_tokens = Keyword.get(opts, :prompt_tokens, 0)
    completion_tokens = Keyword.get(opts, :completion_tokens, 0)
    agent_id = Keyword.get(opts, :agent_id)
    request_ip = Keyword.get(opts, :request_ip)

    Task.Supervisor.start_child(GsmlgAppAdmin.TaskSupervisor, fn ->
      try do
        AI.ApiKey.increment_usage(api_key, 1, tokens)

        log_attrs = %{
          endpoint_type: endpoint_type,
          model: request[:model] || to_string(request.model),
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          total_tokens: tokens,
          status: status,
          api_key_id: api_key.id,
          provider_id: provider.id
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
    end)
  end
end
