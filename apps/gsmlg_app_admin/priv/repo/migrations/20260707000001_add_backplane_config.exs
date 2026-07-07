defmodule GsmlgAppAdmin.Repo.Migrations.AddBackplaneConfig do
  @moduledoc """
  Adds singleton Backplane connection configuration.
  """

  use Ecto.Migration

  def change do
    create table(:ai_backplane_configs, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :key, :text, null: false, default: "default"
      add :server_url, :text, null: false, default: "http://localhost:4220"
      add :auth_token, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:ai_backplane_configs, [:key],
             name: "ai_backplane_configs_unique_key_index"
           )
  end
end
