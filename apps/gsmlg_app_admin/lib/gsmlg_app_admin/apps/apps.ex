defmodule GsmlgAppAdmin.Apps do
  @moduledoc """
  The Apps domain for managing mobile and desktop application listings.

  This domain provides functionality for:
  - Managing app entries with metadata (name, description, icon, platforms)
  - Managing store links for each app (App Store, Play Store, F-Droid)
  - Soft delete and restore functionality
  - Manual display ordering
  """

  use Ash.Domain

  alias GsmlgAppAdmin.Apps.{App, StoreLink}

  resources do
    resource(App)
    resource(StoreLink)
  end

  @doc """
  Lists all active apps ordered by display_order.
  """
  def list_active_apps do
    require Ash.Query

    App
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.sort(display_order: :asc)
    |> Ash.read()
  end

  @doc """
  Lists all apps (including inactive) ordered by display_order.
  """
  def list_all_apps do
    require Ash.Query

    App
    |> Ash.Query.sort(display_order: :asc)
    |> Ash.read()
  end

  @doc """
  Lists apps with store links loaded, optionally filtering by active status.
  """
  def list_apps_with_store_links(include_inactive \\ false) do
    require Ash.Query

    query =
      App
      |> Ash.Query.load(:store_links)
      |> Ash.Query.sort(display_order: :asc)

    query =
      if include_inactive do
        query
      else
        Ash.Query.filter(query, is_active == true)
      end

    Ash.read(query)
  end

  @doc """
  Lists all active apps with store links for the public API.
  Returns apps ordered by display_order with nested store_links ordered by display_order.
  """
  def list_active_with_store_links do
    require Ash.Query

    App
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.load(store_links: Ash.Query.sort(StoreLink, display_order: :asc))
    |> Ash.Query.sort(display_order: :asc)
    |> Ash.read()
  end

  @doc """
  Gets an app by ID.
  """
  def get_app!(id) do
    require Ash.Query

    App
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Gets an app by ID with store links loaded.
  """
  def get_app_with_store_links!(id) do
    require Ash.Query

    App
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(:store_links)
    |> Ash.read_one!()
  end

  @doc """
  Gets an app by ID, returning {:ok, app} or {:error, reason}.
  """
  def get_app(id) do
    require Ash.Query

    App
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(:store_links)
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, app} -> {:ok, app}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets an app by label.
  """
  def get_app_by_label(label) do
    require Ash.Query

    App
    |> Ash.Query.filter(label == ^label)
    |> Ash.Query.load(:store_links)
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, app} -> {:ok, app}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new app.
  """
  def create_app(attrs) do
    App
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates an existing app.
  """
  def update_app(app, attrs) do
    app
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Soft deletes an app by setting is_active to false.
  """
  def soft_delete_app(app) do
    app
    |> Ash.Changeset.for_update(:soft_delete, %{})
    |> Ash.update()
  end

  @doc """
  Restores a soft-deleted app by setting is_active to true.
  """
  def restore_app(app) do
    app
    |> Ash.Changeset.for_update(:restore, %{})
    |> Ash.update()
  end

  @doc """
  Updates the display order of an app.
  """
  def update_app_order(app, new_order) do
    app
    |> Ash.Changeset.for_update(:reorder, %{new_order: new_order})
    |> Ash.update()
  end

  @doc """
  Creates a store link for an app.
  """
  def create_store_link(attrs) do
    StoreLink
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  @doc """
  Updates a store link.
  """
  def update_store_link(store_link, attrs) do
    store_link
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes a store link.
  """
  def delete_store_link(store_link) do
    store_link
    |> Ash.Changeset.for_destroy(:destroy, %{})
    |> Ash.destroy()
  end

  @doc """
  Gets a store link by ID.
  """
  def get_store_link!(id) do
    require Ash.Query

    StoreLink
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  @doc """
  Gets the next display order value for a new app.
  """
  def next_display_order do
    require Ash.Query

    case App |> Ash.Query.sort(display_order: :desc) |> Ash.Query.limit(1) |> Ash.read() do
      {:ok, [app | _]} -> app.display_order + 1
      _ -> 0
    end
  end
end
