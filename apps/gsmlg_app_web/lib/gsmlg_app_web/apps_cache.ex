defmodule GsmlgAppWeb.AppsCache do
  @moduledoc """
  Manages the apps cache for the public website.

  This module provides functionality to:
  - Sync apps data from the admin API and cache to a static file
  - Load cached apps data for rendering
  - Handle missing or corrupted cache files gracefully

  The cache file is stored in Erlang binary term format for fast loading.
  """

  require Logger

  @cache_filename "apps_cache.bin"

  @doc """
  Returns the path to the cache file.
  """
  def cache_path do
    Path.join(:code.priv_dir(:gsmlg_app_web), @cache_filename)
  end

  @doc """
  Loads the cached apps data.

  Returns a list of app maps. If the cache file doesn't exist or is corrupted,
  returns an empty list and logs a warning.

  ## Examples

      iex> GsmlgAppWeb.AppsCache.load()
      [%{name: "GeoIP Lookup", label: "geoip_lookup", ...}, ...]
  """
  def load do
    case File.read(cache_path()) do
      {:ok, binary} ->
        try do
          :erlang.binary_to_term(binary)
        rescue
          ArgumentError ->
            Logger.warning("Apps cache file is corrupted, returning empty list")
            []
        end

      {:error, :enoent} ->
        Logger.info("Apps cache file not found, returning empty list")
        []

      {:error, reason} ->
        Logger.warning("Failed to read apps cache: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Syncs apps data from the admin API and writes to the cache file.

  Takes the admin API base URL as an argument. Uses the ADMIN_API_URL
  environment variable if not provided.

  ## Options

  - `:timeout` - HTTP request timeout in milliseconds (default: 30000)

  ## Examples

      iex> GsmlgAppWeb.AppsCache.sync_from_api("http://localhost:4153")
      {:ok, 5}

      iex> GsmlgAppWeb.AppsCache.sync_from_api()
      {:ok, 5}
  """
  def sync_from_api(admin_api_url \\ nil, opts \\ []) do
    url = admin_api_url || System.get_env("ADMIN_API_URL")
    timeout = Keyword.get(opts, :timeout, 30_000)

    if is_nil(url) do
      {:error, "ADMIN_API_URL not configured"}
    else
      do_sync(url, timeout)
    end
  end

  defp do_sync(admin_api_url, timeout) do
    api_url = String.trim_trailing(admin_api_url, "/") <> "/api/apps"

    case Req.get(api_url, receive_timeout: timeout) do
      {:ok, %Req.Response{status: 200, body: %{"data" => apps}}} ->
        # Convert string keys to atoms for consistency
        apps = Enum.map(apps, &normalize_app/1)
        write_cache(apps)

      {:ok, %Req.Response{status: status}} ->
        {:error, "API returned status #{status}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "Connection failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp normalize_app(app) when is_map(app) do
    %{
      name: app["name"],
      label: app["label"],
      short_description: app["short_description"],
      long_description: app["long_description"],
      icon_path: app["icon_path"],
      platforms: app["platforms"] || [],
      category: app["category"],
      display_order: app["display_order"],
      store_links: Enum.map(app["store_links"] || [], &normalize_store_link/1)
    }
  end

  defp normalize_store_link(link) when is_map(link) do
    %{
      store_type: link["store_type"],
      url: link["url"]
    }
  end

  defp write_cache(apps) do
    binary = :erlang.term_to_binary(apps)

    case File.write(cache_path(), binary) do
      :ok ->
        Logger.info("Apps cache updated: #{length(apps)} apps written to #{cache_path()}")
        {:ok, length(apps)}

      {:error, reason} ->
        Logger.error("Failed to write apps cache: #{inspect(reason)}")
        {:error, "Failed to write cache: #{inspect(reason)}"}
    end
  end

  @doc """
  Returns the count of cached apps.

  Returns 0 if the cache doesn't exist or is corrupted.
  """
  def count do
    load() |> length()
  end

  @doc """
  Checks if the cache file exists.
  """
  def exists? do
    File.exists?(cache_path())
  end

  @doc """
  Returns the last modified time of the cache file.

  Returns nil if the file doesn't exist.
  """
  def last_modified do
    case File.stat(cache_path()) do
      {:ok, %File.Stat{mtime: mtime}} ->
        mtime
        |> :calendar.datetime_to_gregorian_seconds()
        |> Kernel.-(62_167_219_200)
        |> DateTime.from_unix!()

      {:error, _} ->
        nil
    end
  end
end
