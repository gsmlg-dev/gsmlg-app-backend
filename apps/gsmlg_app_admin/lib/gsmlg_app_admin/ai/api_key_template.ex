defmodule GsmlgAppAdmin.AI.ApiKeyTemplate do
  @moduledoc """
  Join table linking API keys to specific system prompt templates.
  Allows per-key template overrides.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_api_key_templates")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :api_key_id, :uuid do
      allow_nil?(false)
    end

    attribute :system_prompt_template_id, :uuid do
      allow_nil?(false)
    end

    create_timestamp(:created_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:api_key_id, :system_prompt_template_id])
    end
  end

  identities do
    identity(:unique_key_template, [:api_key_id, :system_prompt_template_id])
  end
end
