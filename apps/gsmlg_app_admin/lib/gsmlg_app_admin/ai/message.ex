defmodule GsmlgAppAdmin.AI.Message do
  @moduledoc """
  Represents a single message in a chat conversation.

  Messages can be from either the user or the AI assistant.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("messages")
    repo(GsmlgAppAdmin.Repo)

    references do
      reference(:conversation, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      allow_nil?(false)
      constraints(one_of: [:user, :assistant, :system])
      description("The role of the message sender")
    end

    attribute :content, :string do
      allow_nil?(false)
      description("The message content")
    end

    attribute :tokens, :integer do
      description("Number of tokens in this message")
    end

    attribute :metadata, :map do
      description("Additional metadata (model used, latency, etc.)")
      default(%{})
    end

    create_timestamp(:created_at)
  end

  relationships do
    belongs_to :conversation, GsmlgAppAdmin.AI.Conversation do
      allow_nil?(false)
      attribute_writable?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:conversation_id, :role, :content, :tokens, :metadata])
    end

    update :update do
      primary?(true)
      accept([:content, :tokens, :metadata])
    end

    read :for_conversation do
      argument(:conversation_id, :uuid, allow_nil?: false)
      filter(expr(conversation_id == ^arg(:conversation_id)))
      prepare(build(sort: [created_at: :asc]))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:for_conversation, args: [:conversation_id])
  end

  identities do
    identity(:id, [:id])
  end
end
