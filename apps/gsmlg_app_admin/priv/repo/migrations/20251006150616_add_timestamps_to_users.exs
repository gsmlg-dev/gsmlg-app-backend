defmodule GsmlgAppAdmin.Repo.Migrations.AddTimestampsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:created_at, :utc_datetime_usec, null: false, default: fragment("now()"))
      add(:updated_at, :utc_datetime_usec, null: false, default: fragment("now()"))
    end
  end
end
