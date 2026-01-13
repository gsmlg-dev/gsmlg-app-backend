defmodule GsmlgAppAdminWeb.Api.AppsController do
  @moduledoc """
  API controller for exposing apps data.

  Provides a public endpoint for fetching all active apps with their store links.
  This endpoint is used by the public website (app_web) to cache apps data.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.Apps

  @doc """
  Returns all active apps with their store links.

  ## Response Format

  ```json
  {
    "data": [
      {
        "name": "GeoIP Lookup",
        "label": "geoip_lookup",
        "short_description": "Find geography location of IP Address",
        "long_description": "Detailed description...",
        "icon_path": "/images/icons/geoip_lookup.png",
        "platforms": ["ios", "android"],
        "category": "network",
        "display_order": 1,
        "store_links": [
          {"store_type": "appstore", "url": "https://apps.apple.com/..."},
          {"store_type": "playstore", "url": "https://play.google.com/..."}
        ]
      }
    ]
  }
  ```
  """
  def index(conn, _params) do
    case Apps.list_active_with_store_links() do
      {:ok, apps} ->
        data = Enum.map(apps, &serialize_app/1)
        json(conn, %{data: data})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch apps"})
    end
  end

  defp serialize_app(app) do
    %{
      name: app.name,
      label: app.label,
      short_description: app.short_description,
      long_description: app.long_description,
      icon_path: app.icon_path,
      platforms: Enum.map(app.platforms, &to_string/1),
      category: to_string(app.category),
      display_order: app.display_order,
      store_links: Enum.map(app.store_links, &serialize_store_link/1)
    }
  end

  defp serialize_store_link(link) do
    %{
      store_type: to_string(link.store_type),
      url: link.url
    }
  end
end
