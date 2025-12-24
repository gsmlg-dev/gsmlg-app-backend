defmodule GsmlgAppAdmin.Repo.Migrations.AddProviderUsageTracking do
  @moduledoc """
  Adds usage tracking columns to ai_providers table.

  Tracks total messages, total tokens, and last usage timestamp for each provider.
  """

  use Ecto.Migration

  def change do
    alter table(:ai_providers) do
      add :total_messages, :integer, default: 0, null: false
      add :total_tokens, :integer, default: 0, null: false
      add :last_used_at, :utc_datetime_usec
    end
  end
end
