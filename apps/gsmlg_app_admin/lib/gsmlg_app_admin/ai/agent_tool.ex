defmodule GsmlgAppAdmin.AI.AgentTool do
  @moduledoc """
  Join table linking agents to tools with ordering.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_agent_tools")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :agent_id, :uuid do
      allow_nil?(false)
    end

    attribute :tool_id, :uuid do
      allow_nil?(false)
    end

    attribute :position, :integer do
      default(0)
      description("Ordering of tools for this agent")
    end

    attribute :tool_choice_override, :string do
      description("Per-agent override for this tool's choice strategy")
    end

    create_timestamp(:created_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:agent_id, :tool_id, :position, :tool_choice_override])
    end
  end

  identities do
    identity(:unique_agent_tool, [:agent_id, :tool_id])
  end
end
