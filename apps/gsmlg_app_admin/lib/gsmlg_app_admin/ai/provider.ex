defmodule GsmlgAppAdmin.AI.Provider do
  @moduledoc """
  Represents an AI provider configuration.

  Supports multiple OpenAI-compatible API providers like DeepSeek, Zhipu AI, and Moonshot.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ai_providers"
    repo GsmlgAppAdmin.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
      description "Display name of the provider"
    end

    attribute :slug, :string do
      allow_nil? false
      constraints max_length: 50
      description "URL-friendly identifier"
    end

    attribute :api_base_url, :string do
      allow_nil? false
      description "Base URL for the API endpoint"
    end

    attribute :api_key, :string do
      sensitive? true
      description "API key for authentication"
    end

    attribute :model, :string do
      allow_nil? false
      description "Default model identifier"
    end

    attribute :available_models, {:array, :string} do
      default []
      description "List of available models for this provider"
    end

    attribute :default_params, :map do
      description "Default parameters for API calls (temperature, max_tokens, etc.)"
    end

    attribute :is_active, :boolean do
      allow_nil? false
      default true
      description "Whether this provider is active"
    end

    attribute :description, :string do
      description "Provider description"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :slug,
        :api_base_url,
        :api_key,
        :model,
        :available_models,
        :default_params,
        :is_active,
        :description
      ]
    end

    update :update do
      primary? true

      accept [
        :name,
        :api_base_url,
        :api_key,
        :model,
        :available_models,
        :default_params,
        :is_active,
        :description
      ]
    end

    read :active do
      filter expr(is_active == true)
      prepare build(sort: [name: :asc])
    end

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug))
    end
  end

  code_interface do
    define :create
    define :update
    define :destroy
    define :active, action: :active
    define :by_slug, args: [:slug]
  end

  identities do
    identity :unique_slug, [:slug]
  end

  validations do
    validate present(:api_key),
      where: [attribute_does_not_equal(:slug, "local")],
      message: "API key is required for non-local providers"
  end
end
