defmodule GsmlgAppAdmin.Repo.Migrations.AddAiApiKeys do
  @moduledoc """
  Creates the ai_api_keys table for API gateway key management.
  """

  use Ecto.Migration

  def up do
    create table(:ai_api_keys, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :description, :text
      add :key_prefix, :text, null: false
      add :key_hash, :text, null: false
      add :scopes, {:array, :text}, default: []
      add :is_active, :boolean, null: false, default: true
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :rate_limit_rpm, :integer
      add :rate_limit_rpd, :integer
      add :allowed_providers, {:array, :uuid}, default: []
      add :allowed_models, {:array, :text}, default: []
      add :total_requests, :integer, null: false, default: 0
      add :total_tokens, :integer, null: false, default: 0

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "ai_api_keys_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create unique_index(:ai_api_keys, [:key_prefix], name: "ai_api_keys_unique_key_prefix_index")
    create index(:ai_api_keys, [:user_id], name: "ai_api_keys_user_id_index")
    create index(:ai_api_keys, [:is_active], name: "ai_api_keys_is_active_index")
  end

  def down do
    drop_if_exists index(:ai_api_keys, [:is_active], name: "ai_api_keys_is_active_index")
    drop_if_exists index(:ai_api_keys, [:user_id], name: "ai_api_keys_user_id_index")

    drop_if_exists unique_index(:ai_api_keys, [:key_prefix],
                     name: "ai_api_keys_unique_key_prefix_index"
                   )

    drop table(:ai_api_keys)
  end
end
