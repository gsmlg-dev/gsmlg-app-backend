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
    ApiKey,
    ApiKeyTemplate,
    Conversation,
    Memory,
    Message,
    Provider,
    SystemPromptTemplate
  }

  resources do
    resource(ApiKey)
    resource(ApiKeyTemplate)
    resource(Conversation)
    resource(Memory)
    resource(Message)
    resource(Provider)
    resource(SystemPromptTemplate)
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
end
