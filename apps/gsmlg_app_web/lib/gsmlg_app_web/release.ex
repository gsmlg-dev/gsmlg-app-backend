defmodule GsmlgAppWeb.Release do
  @moduledoc """
  Release tasks for the public website.

  ## Usage

  Sync apps cache from admin API:
      bin/gsmlg_app_backend eval "GsmlgAppWeb.Release.sync_apps_cache"

  The admin API URL must be set via the ADMIN_API_URL environment variable.
  """

  alias GsmlgAppWeb.AppsCache

  @doc """
  Syncs the apps cache from the admin API.

  Reads the ADMIN_API_URL environment variable to determine where to fetch
  the apps data from. If the API is unreachable, preserves the existing cache
  and reports an error.

  ## Examples

      # In a release:
      bin/gsmlg_app_backend eval "GsmlgAppWeb.Release.sync_apps_cache"

      # With custom URL:
      ADMIN_API_URL=https://admin.example.com bin/gsmlg_app_backend eval "GsmlgAppWeb.Release.sync_apps_cache"
  """
  def sync_apps_cache do
    load_app()

    admin_url = System.get_env("ADMIN_API_URL")

    if is_nil(admin_url) do
      IO.puts("Error: ADMIN_API_URL environment variable is not set.")
      IO.puts("Set it to the admin backend URL (e.g., http://localhost:4153)")
      {:error, :admin_api_url_not_set}
    else
      IO.puts("Syncing apps cache from #{admin_url}...")

      case AppsCache.sync_from_api(admin_url) do
        {:ok, count} ->
          IO.puts("Success! Cached #{count} apps to #{AppsCache.cache_path()}")
          :ok

        {:error, reason} ->
          IO.puts("Error syncing apps cache: #{inspect(reason)}")

          if AppsCache.exists?() do
            IO.puts("Existing cache preserved at #{AppsCache.cache_path()}")
            IO.puts("  Last modified: #{inspect(AppsCache.last_modified())}")
            IO.puts("  Apps count: #{AppsCache.count()}")
          else
            IO.puts("No existing cache found.")
          end

          {:error, reason}
      end
    end
  end

  @doc """
  Shows the current cache status.
  """
  def cache_status do
    load_app()

    IO.puts("\nApps Cache Status")
    IO.puts("=================")
    IO.puts("Cache path: #{AppsCache.cache_path()}")
    IO.puts("Exists: #{AppsCache.exists?()}")

    if AppsCache.exists?() do
      IO.puts("Last modified: #{inspect(AppsCache.last_modified())}")
      IO.puts("Apps count: #{AppsCache.count()}")

      apps = AppsCache.load()
      IO.puts("\nCached apps:")

      for app <- apps do
        IO.puts("  - #{app.name} (#{app.label})")
      end
    end

    :ok
  end

  defp load_app do
    # Ensure required applications are started
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:req)
    Application.ensure_loaded(:gsmlg_app_web)
  end
end
