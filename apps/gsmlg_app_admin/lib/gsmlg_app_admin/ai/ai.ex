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

  alias GsmlgAppAdmin.AI.{Conversation, Message, Provider}

  resources do
    resource(Conversation)
    resource(Message)
    resource(Provider)
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
  Creates a new conversation.
  """
  def create_conversation(attrs) do
    Conversation
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
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
end
