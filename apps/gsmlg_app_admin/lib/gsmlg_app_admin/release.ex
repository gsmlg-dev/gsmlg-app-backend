defmodule GsmlgAppAdmin.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix installed.

  ## Usage

  Run migrations:
      bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.migrate"

  Create database:
      bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.create"

  Run seeds:
      bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.seed"

  Setup (create + migrate + seed):
      bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.setup"

  Rollback:
      bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.rollback(GsmlgAppAdmin.Repo, 20240101000000)"
  """

  @app :gsmlg_app_admin

  @doc """
  Runs all pending migrations.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Rolls back to a specific migration version.
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Creates the database if it doesn't exist.
  """
  def create do
    load_app()

    for repo <- repos() do
      case repo.__adapter__().storage_up(repo.config()) do
        :ok ->
          IO.puts("Database #{inspect(repo)} created successfully.")

        {:error, :already_up} ->
          IO.puts("Database #{inspect(repo)} already exists.")

        {:error, reason} ->
          IO.puts("Failed to create database #{inspect(repo)}: #{inspect(reason)}")
      end
    end
  end

  @doc """
  Runs the seed file to populate initial data.
  """
  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seed_path = seed_path(repo)

          if File.exists?(seed_path) do
            IO.puts("Running seeds for #{inspect(repo)}...")
            Code.eval_file(seed_path)
            IO.puts("Seeds completed.")
          else
            IO.puts("No seed file found at #{seed_path}")
          end
        end)
    end
  end

  @doc """
  Full database setup: create, migrate, and seed.
  """
  def setup do
    create()
    migrate()
    seed()
  end

  @doc """
  Returns the current migration status.
  """
  def migration_status do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          IO.puts("\nMigration status for #{inspect(repo)}:")

          migrations = Ecto.Migrator.migrations(repo)

          for {status, version, name} <- migrations do
            status_str = if status == :up, do: "[✓]", else: "[ ]"
            IO.puts("  #{status_str} #{version} - #{name}")
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end

  defp seed_path(repo) do
    priv_dir = :code.priv_dir(@app) |> to_string()
    repo_underscore = repo |> Module.split() |> List.last() |> Macro.underscore()
    Path.join([priv_dir, repo_underscore, "seeds.exs"])
  end
end
