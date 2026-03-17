defmodule GsmlgAppAdmin.AI.AgentTemplate do
  @moduledoc """
  Join table linking agents to system prompt templates.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_agent_templates")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :agent_id, :uuid do
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
      accept([:agent_id, :system_prompt_template_id])
    end
  end

  identities do
    identity(:unique_agent_template, [:agent_id, :system_prompt_template_id])
  end
end
