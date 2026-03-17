defmodule GsmlgAppAdmin.Repo.Migrations.AddAiSystemPromptsAndMemories do
  @moduledoc """
  Creates tables for system prompt templates, memories, and API key template associations.
  """

  use Ecto.Migration

  def up do
    create table(:ai_system_prompt_templates, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :slug, :text, null: false
      add :content, :text, null: false
      add :is_default, :boolean, null: false, default: false
      add :is_active, :boolean, null: false, default: true
      add :priority, :integer, null: false, default: 0

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_system_prompt_templates, [:slug],
             name: "ai_system_prompt_templates_unique_slug_index"
           )

    create table(:ai_memories, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :content, :text, null: false
      add :category, :text, null: false
      add :scope, :text, null: false
      add :is_active, :boolean, null: false, default: true
      add :priority, :integer, null: false, default: 0
      add :user_id, :uuid
      add :api_key_id, :uuid
      add :agent_id, :uuid

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:ai_memories, [:scope, :is_active], name: "ai_memories_scope_active_index")
    create index(:ai_memories, [:user_id], name: "ai_memories_user_id_index")
    create index(:ai_memories, [:api_key_id], name: "ai_memories_api_key_id_index")
    create index(:ai_memories, [:agent_id], name: "ai_memories_agent_id_index")

    create table(:ai_api_key_templates, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :api_key_id,
          references(:ai_api_keys,
            column: :id,
            name: "ai_api_key_templates_api_key_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :system_prompt_template_id,
          references(:ai_system_prompt_templates,
            column: :id,
            name: "ai_api_key_templates_template_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_api_key_templates, [:api_key_id, :system_prompt_template_id],
             name: "ai_api_key_templates_unique_index"
           )
  end

  def down do
    drop_if_exists unique_index(:ai_api_key_templates, [:api_key_id, :system_prompt_template_id],
                     name: "ai_api_key_templates_unique_index"
                   )

    drop table(:ai_api_key_templates)

    drop_if_exists index(:ai_memories, [:agent_id], name: "ai_memories_agent_id_index")
    drop_if_exists index(:ai_memories, [:api_key_id], name: "ai_memories_api_key_id_index")
    drop_if_exists index(:ai_memories, [:user_id], name: "ai_memories_user_id_index")

    drop_if_exists index(:ai_memories, [:scope, :is_active],
                     name: "ai_memories_scope_active_index"
                   )

    drop table(:ai_memories)

    drop_if_exists unique_index(:ai_system_prompt_templates, [:slug],
                     name: "ai_system_prompt_templates_unique_slug_index"
                   )

    drop table(:ai_system_prompt_templates)
  end
end
