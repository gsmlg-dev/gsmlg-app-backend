defmodule GsmlgAppAdmin.AI do
  @moduledoc """
  The AI domain for managing chat conversations and LLM interactions.

  This domain provides functionality for:
  - Managing chat conversations
  - Storing and retrieving chat messages
  - Configuring AI provider settings
  - Interacting with multiple LLM providers (DeepSeek, Zhipu AI, Moonshot)
  """

  use Ash.Domain

  alias GsmlgAppAdmin.AI.{
    Agent,
    AgentTemplate,
    AgentTool,
    ApiKey,
    ApiKeyTemplate,
    ApiUsageLog,
    Conversation,
    McpServer,
    Memory,
    Message,
    Provider,
    SystemPromptTemplate,
    Tool
  }

  resources do
    resource(Agent)
    resource(AgentTemplate)
    resource(AgentTool)
    resource(ApiKey)
    resource(ApiKeyTemplate)
    resource(ApiUsageLog)
    resource(Conversation)
    resource(McpServer)
    resource(Memory)
    resource(Message)
    resource(Provider)
    resource(SystemPromptTemplate)
    resource(Tool)
  end

  @doc """
  Lists all conversations for a user, ordered by most recent.
  """
  def list_conversations(user_id) do
    require Ash.Query

    Conversation
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.read()
  end

  @doc """
  Gets a conversation by ID with its messages loaded.
  """
  def get_conversation_with_messages!(id) do
    require Ash.Query

    Conversation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(:messages)
    |> Ash.read_one!()
  end

  @doc """
  Gets a conversation by ID with its messages loaded.
  Returns {:ok, conversation} or {:error, reason}.
  """
  def get_conversation_with_messages(id) do
    require Ash.Query

    Conversation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(:messages)
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, conversation} -> {:ok, conversation}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new conversation.
  """
  def create_conversation(attrs) do
    Conversation
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates a conversation.
  """
  def update_conversation(conversation, attrs) do
    conversation
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Adds a message to a conversation.
  """
  def add_message(conversation_id, attrs) do
    attrs = Map.put(attrs, :conversation_id, conversation_id)

    Message
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Lists all active AI providers.
  """
  def list_active_providers do
    require Ash.Query

    Provider
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read()
  end

  @doc """
  Gets a provider by ID.
  """
  def get_provider!(id) do
    require Ash.Query

    Provider
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Gets a provider by ID, returning {:ok, provider} or {:error, reason}.
  """
  def get_provider(id) do
    require Ash.Query

    Provider
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  @doc """
  Lists all providers with usage statistics.
  """
  def list_providers_with_usage do
    require Ash.Query

    Provider
    |> Ash.Query.sort(name: :asc)
    |> Ash.Query.load([:masked_api_key])
    |> Ash.read()
  end

  @doc """
  Lists all providers.
  """
  def list_providers do
    require Ash.Query

    Provider
    |> Ash.Query.sort(name: :asc)
    |> Ash.read()
  end

  @doc """
  Creates a new AI provider.
  """
  def create_provider(attrs) do
    Provider
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates an existing AI provider.
  """
  def update_provider(provider, attrs) do
    provider
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes an AI provider.
  """
  def delete_provider(provider) do
    provider
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  @doc """
  Toggles the active status of a provider.
  """
  def toggle_provider_active(provider) do
    provider
    |> Ash.Changeset.for_update(:toggle_active, %{})
    |> Ash.update()
  end

  @doc """
  Increments usage statistics for a provider.
  """
  def increment_provider_usage(provider, messages \\ 1, tokens \\ 0) do
    provider
    |> Ash.Changeset.for_update(:increment_usage, %{messages: messages, tokens: tokens})
    |> Ash.update()
  end

  # --- API Key Management ---

  @doc """
  Creates a new API key. Returns the record with `__raw_key__` set (shown once).
  """
  def create_api_key(attrs) do
    ApiKey
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Lists all API keys for a user.
  """
  def list_api_keys_for_user(user_id) do
    require Ash.Query

    ApiKey
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read()
  end

  @doc """
  Lists all API keys.
  """
  def list_api_keys do
    require Ash.Query

    ApiKey
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read()
  end

  @doc """
  Gets an API key by ID.
  """
  def get_api_key!(id) do
    require Ash.Query

    ApiKey
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Revokes an API key.
  """
  def revoke_api_key(api_key) do
    api_key
    |> Ash.Changeset.for_update(:revoke, %{})
    |> Ash.update()
  end

  @doc """
  Updates an API key.
  """
  def update_api_key(api_key, attrs) do
    api_key
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes an API key.
  """
  def delete_api_key(api_key) do
    api_key
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  # --- System Prompt Templates ---

  @doc """
  Lists all system prompt templates.
  """
  def list_system_prompt_templates do
    require Ash.Query

    SystemPromptTemplate
    |> Ash.Query.sort(priority: :desc)
    |> Ash.read()
  end

  @doc """
  Gets active default templates.
  """
  def list_default_templates do
    SystemPromptTemplate.active_defaults()
  end

  @doc """
  Creates a system prompt template.
  """
  def create_system_prompt_template(attrs) do
    SystemPromptTemplate
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates a system prompt template.
  """
  def update_system_prompt_template(template, attrs) do
    template
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes a system prompt template.
  """
  def delete_system_prompt_template(template) do
    template
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  @doc """
  Gets a system prompt template by ID.
  """
  def get_system_prompt_template!(id) do
    require Ash.Query

    SystemPromptTemplate
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  # --- Memories ---

  @doc """
  Lists all memories.
  """
  def list_memories do
    require Ash.Query

    Memory
    |> Ash.Query.sort(priority: :desc)
    |> Ash.read()
  end

  @doc """
  Fetches memories for a gateway request.
  """
  def get_memories_for_request(opts \\ []) do
    Memory.for_request(
      Keyword.get(opts, :user_id),
      Keyword.get(opts, :api_key_id),
      Keyword.get(opts, :agent_id)
    )
  end

  @doc """
  Creates a memory.
  """
  def create_memory(attrs) do
    Memory
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates a memory.
  """
  def update_memory(memory, attrs) do
    memory
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes a memory.
  """
  def delete_memory(memory) do
    memory
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  @doc """
  Gets a memory by ID.
  """
  def get_memory!(id) do
    require Ash.Query

    Memory
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  # --- Agents ---

  @doc """
  Lists all active agents.
  """
  def list_active_agents do
    Agent.active()
  end

  @doc """
  Lists all agents.
  """
  def list_agents do
    require Ash.Query

    Agent
    |> Ash.Query.sort(name: :asc)
    |> Ash.read()
  end

  @doc """
  Gets an agent by slug.
  """
  def get_agent_by_slug(slug) do
    case Agent.by_slug(slug) do
      {:ok, [agent]} -> {:ok, agent}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Gets an agent by ID.
  """
  def get_agent!(id) do
    require Ash.Query

    Agent
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Creates an agent.
  """
  def create_agent(attrs) do
    Agent
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates an agent.
  """
  def update_agent(agent, attrs) do
    agent
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes an agent.
  """
  def delete_agent(agent) do
    agent
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  # --- Tools ---

  @doc """
  Lists all active tools.
  """
  def list_active_tools do
    Tool.active()
  end

  @doc """
  Lists all tools.
  """
  def list_tools do
    require Ash.Query

    Tool
    |> Ash.Query.sort(name: :asc)
    |> Ash.read()
  end

  @doc """
  Lists tools for an agent via join table.
  """
  def list_tools_for_agent(agent_id) do
    require Ash.Query

    AgentTool
    |> Ash.Query.filter(agent_id == ^agent_id)
    |> Ash.Query.sort(position: :asc)
    |> Ash.read()
    |> case do
      {:ok, agent_tools} ->
        tool_ids = Enum.map(agent_tools, & &1.tool_id)

        case Tool
             |> Ash.Query.filter(id in ^tool_ids and is_active == true)
             |> Ash.read() do
          {:ok, tools} ->
            # Preserve the position ordering from agent_tools
            tools_by_id = Map.new(tools, fn t -> {t.id, t} end)

            ordered =
              Enum.flat_map(agent_tools, fn at ->
                case Map.get(tools_by_id, at.tool_id) do
                  nil -> []
                  tool -> [tool]
                end
              end)

            {:ok, ordered}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Gets a tool by ID.
  """
  def get_tool!(id) do
    require Ash.Query

    Tool
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Creates a tool.
  """
  def create_tool(attrs) do
    Tool
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates a tool.
  """
  def update_tool(tool, attrs) do
    tool
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes a tool.
  """
  def delete_tool(tool) do
    tool
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  # --- MCP Servers ---

  @doc """
  Lists all MCP servers.
  """
  def list_mcp_servers do
    require Ash.Query

    McpServer
    |> Ash.Query.sort(name: :asc)
    |> Ash.read()
  end

  @doc """
  Gets an MCP server by ID.
  """
  def get_mcp_server!(id) do
    require Ash.Query

    McpServer
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Creates an MCP server.
  """
  def create_mcp_server(attrs) do
    McpServer
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates an MCP server.
  """
  def update_mcp_server(server, attrs) do
    server
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes an MCP server.
  """
  def delete_mcp_server(server) do
    server
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  # --- API Usage Logs ---

  @doc """
  Logs an API usage entry.
  """
  def log_api_usage(attrs) do
    ApiUsageLog
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Lists recent API usage logs.
  """
  def list_recent_usage_logs do
    ApiUsageLog.recent()
  end

  @doc """
  Lists usage logs for a specific API key.
  """
  def list_usage_logs_for_key(api_key_id) do
    ApiUsageLog.for_api_key(api_key_id)
  end

  @doc """
  Computes summary statistics from usage logs for the dashboard.
  Returns a map with total_requests, total_tokens, error_count, and endpoint breakdown.
  """
  def usage_summary(logs) do
    acc = %{
      total_requests: 0,
      total_tokens: 0,
      total_prompt_tokens: 0,
      total_completion_tokens: 0,
      error_count: 0,
      success_count: 0,
      by_endpoint: %{},
      by_model: %{}
    }

    Enum.reduce(logs, acc, fn log, acc ->
      %{
        acc
        | total_requests: acc.total_requests + 1,
          total_tokens: acc.total_tokens + (log.total_tokens || 0),
          total_prompt_tokens: acc.total_prompt_tokens + (log.prompt_tokens || 0),
          total_completion_tokens: acc.total_completion_tokens + (log.completion_tokens || 0),
          error_count: acc.error_count + if(log.status == :error, do: 1, else: 0),
          success_count: acc.success_count + if(log.status == :success, do: 1, else: 0),
          by_endpoint: Map.update(acc.by_endpoint, log.endpoint_type, 1, &(&1 + 1)),
          by_model:
            if(log.model,
              do: Map.update(acc.by_model, log.model, 1, &(&1 + 1)),
              else: acc.by_model
            )
      }
    end)
  end
end
