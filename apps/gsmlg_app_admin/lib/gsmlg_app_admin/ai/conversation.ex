defmodule GsmlgAppAdmin.AI.Conversation do
  @moduledoc """
  Represents a chat conversation between a user and an AI assistant.

  Each conversation has a title, tracks the user who created it,
  and the AI provider being used.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "conversations"
    repo GsmlgAppAdmin.Repo

    references do
      reference :user, on_delete: :delete
      reference :provider, on_delete: :nilify
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints max_length: 255
    end

    attribute :system_prompt, :string do
      description "Custom system prompt for this conversation"
    end

    attribute :model_params, :map do
      description "Model-specific parameters (temperature, max_tokens, etc.)"
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, GsmlgAppAdmin.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :provider, GsmlgAppAdmin.AI.Provider do
      allow_nil? true
      attribute_writable? true
    end

    has_many :messages, GsmlgAppAdmin.AI.Message do
      destination_attribute :conversation_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :system_prompt, :model_params, :user_id, :provider_id]

      change fn changeset, _context ->
        # Auto-generate title from first message if not provided
        case Ash.Changeset.get_attribute(changeset, :title) do
          nil -> Ash.Changeset.force_change_attribute(changeset, :title, "New Chat")
          _ -> changeset
        end
      end
    end

    update :update do
      primary? true
      accept [:title, :system_prompt, :model_params, :provider_id]
    end
  end

  code_interface do
    define :create
    define :update
    define :destroy
  end

  identities do
    identity :id, [:id]
  end
end
