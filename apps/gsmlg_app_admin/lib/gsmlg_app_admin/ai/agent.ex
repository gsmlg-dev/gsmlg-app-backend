defmodule GsmlgAppAdmin.AI.Agent do
  @moduledoc """
  An admin-configured AI persona that combines a model, system prompt,
  tools, and behavioral settings into a reusable unit.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_agents")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100)
      description("Human-readable agent name")
    end

    attribute :slug, :string do
      allow_nil?(false)
      constraints(max_length: 50)
      description("URL-friendly identifier for API reference")
    end

    attribute :description, :string do
      description("Agent description")
    end

    attribute :model, :string do
      description("Default model (overridable per request)")
    end

    attribute :provider_id, :uuid do
      description("Preferred provider (nullable, falls back to auto-resolution)")
    end

    attribute :max_iterations, :integer do
      default(10)
      description("Maximum tool call cycles before forcing final response")
    end

    attribute :tool_choice, :string do
      default("auto")
      description("Default tool selection strategy: auto, required, none, or tool name")
    end

    attribute :model_params, :map do
      default(%{})
      description("Default temperature, max_tokens, top_p")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this agent is enabled")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :slug,
        :description,
        :model,
        :provider_id,
        :max_iterations,
        :tool_choice,
        :model_params,
        :is_active
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :description,
        :model,
        :provider_id,
        :max_iterations,
        :tool_choice,
        :model_params,
        :is_active
      ])
    end

    read :active do
      filter(expr(is_active == true))
      prepare(build(sort: [name: :asc]))
    end

    read :by_slug do
      argument(:slug, :string, allow_nil?: false)
      filter(expr(slug == ^arg(:slug)))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:active, action: :active)
    define(:by_slug, args: [:slug])
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
