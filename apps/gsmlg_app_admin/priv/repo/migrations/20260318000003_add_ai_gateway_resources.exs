defmodule GsmlgAppAdmin.Repo.Migrations.AddAiGatewayResources do
  @moduledoc """
  Creates tables for API usage logs, tools, MCP servers, agents, and join tables.
  """

  use Ecto.Migration

  def up do
    # API Usage Logs
    create table(:ai_api_usage_logs, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :endpoint_type, :text, null: false
      add :model, :text, null: false
      add :prompt_tokens, :integer, default: 0
      add :completion_tokens, :integer, default: 0
      add :total_tokens, :integer, default: 0
      add :images_generated, :integer, default: 0
      add :duration_ms, :integer
      add :status, :text, null: false
      add :error_message, :text
      add :request_ip, :text
      add :api_key_id, :uuid, null: false
      add :provider_id, :uuid
      add :agent_id, :uuid

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:ai_api_usage_logs, [:api_key_id, :created_at],
             name: "ai_api_usage_logs_key_created_index"
           )

    create index(:ai_api_usage_logs, [:created_at], name: "ai_api_usage_logs_created_index")

    create index(:ai_api_usage_logs, [:agent_id, :created_at],
             name: "ai_api_usage_logs_agent_index"
           )

    # MCP Servers
    create table(:ai_mcp_servers, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :slug, :text, null: false
      add :description, :text
      add :transport_type, :text, null: false
      add :connection_config, :map, null: false
      add :is_active, :boolean, null: false, default: true
      add :auto_sync_tools, :boolean, null: false, default: true
      add :health_status, :text, default: "disconnected"
      add :last_connected_at, :utc_datetime_usec
      add :last_error, :text
      add :server_info, :map

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_mcp_servers, [:slug], name: "ai_mcp_servers_unique_slug_index")

    # Tools
    create table(:ai_tools, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :slug, :text, null: false
      add :description, :text, null: false
      add :execution_type, :text, null: false
      add :parameters_schema, :map
      add :webhook_url, :text
      add :webhook_method, :text, default: "post"
      add :webhook_headers, :map
      add :builtin_handler, :text
      add :code_body, :text
      add :mcp_server_id, :uuid
      add :mcp_tool_name, :text
      add :is_mcp_synced, :boolean, default: false
      add :timeout_ms, :integer, default: 30_000
      add :rate_limit_per_minute, :integer
      add :is_active, :boolean, null: false, default: true
      add :metadata, :map

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_tools, [:slug], name: "ai_tools_unique_slug_index")
    create index(:ai_tools, [:mcp_server_id], name: "ai_tools_mcp_server_id_index")

    # Agents
    create table(:ai_agents, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :slug, :text, null: false
      add :description, :text
      add :model, :text
      add :provider_id, :uuid
      add :max_iterations, :integer, default: 10
      add :tool_choice, :text, default: "auto"
      add :model_params, :map, default: %{}
      add :is_active, :boolean, null: false, default: true

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_agents, [:slug], name: "ai_agents_unique_slug_index")

    # Agent-Tool join table
    create table(:ai_agent_tools, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :agent_id,
          references(:ai_agents,
            column: :id,
            name: "ai_agent_tools_agent_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :tool_id,
          references(:ai_tools,
            column: :id,
            name: "ai_agent_tools_tool_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :position, :integer, default: 0
      add :tool_choice_override, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_agent_tools, [:agent_id, :tool_id],
             name: "ai_agent_tools_unique_index"
           )

    # Agent-Template join table
    create table(:ai_agent_templates, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :agent_id,
          references(:ai_agents,
            column: :id,
            name: "ai_agent_templates_agent_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :system_prompt_template_id,
          references(:ai_system_prompt_templates,
            column: :id,
            name: "ai_agent_templates_template_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_agent_templates, [:agent_id, :system_prompt_template_id],
             name: "ai_agent_templates_unique_index"
           )
  end

  def down do
    drop_if_exists table(:ai_agent_templates)
    drop_if_exists table(:ai_agent_tools)
    drop_if_exists table(:ai_agents)
    drop_if_exists table(:ai_tools)
    drop_if_exists table(:ai_mcp_servers)
    drop_if_exists table(:ai_api_usage_logs)
  end
end
