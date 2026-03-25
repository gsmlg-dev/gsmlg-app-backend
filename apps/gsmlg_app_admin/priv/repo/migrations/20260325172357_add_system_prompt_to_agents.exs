defmodule GsmlgAppAdmin.Repo.Migrations.AddSystemPromptToAgents do
  use Ecto.Migration

  def change do
    alter table(:ai_agents) do
      add :system_prompt, :text
    end
  end
end
