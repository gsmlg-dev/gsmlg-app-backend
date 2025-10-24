defmodule GsmlgAppAdmin.Accounts do
  @moduledoc """
  The Accounts domain manages user accounts and authentication.

  This domain provides functions for user management including:
  - Creating, reading, updating, and deleting users
  - Searching and filtering users by various criteria
  - Managing user authentication and authorization
  """
  use Ash.Domain, otp_app: :gsmlg_app_admin

  alias GsmlgAppAdmin.Accounts.User

  resources do
    resource(GsmlgAppAdmin.Accounts.User)
    resource(GsmlgAppAdmin.Accounts.Token)
  end

  # User management functions
  def list_users do
    User
    |> Ash.read!(authorize?: false)
  end

  def get_user!(id) do
    require Ash.Query

    User
    |> Ash.Query.filter(id == ^id)
    |> Ash.read!(authorize?: false)
    |> List.first()
    |> case do
      nil ->
        raise "No User found"

      user ->
        user
    end
  end

  def search_users(filters) do
    User
    |> build_query(filters)
    |> Ash.read!(authorize?: false)
  end

  def change_user(%User{} = user, attrs \\ %{}) do
    user
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false)
  end

  def create_user(attrs, opts \\ []) do
    action = Keyword.get(opts, :action, :admin_create)

    User
    |> Ash.Changeset.for_create(action, attrs, authorize?: false)
    |> Ash.create()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> Ash.Changeset.for_update(:admin_update, attrs, authorize?: false)
    |> Ash.update()
  end

  def delete_user(%User{} = user) do
    user
    |> Ash.destroy(authorize?: false)
  end

  # Build query with filters
  defp build_query(query, %{query: "", role: "all", status: "all"}), do: query

  defp build_query(query, filters) do
    query
    |> apply_search_filter(filters.query)
    |> apply_role_filter(filters.role)
    |> apply_status_filter(filters.status)
  end

  defp apply_search_filter(query, ""), do: query

  defp apply_search_filter(query, search_term) do
    require Ash.Query

    Ash.Query.filter(
      query,
      ilike(first_name, ^"%#{search_term}%") or
        ilike(last_name, ^"%#{search_term}%") or
        ilike(username, ^"%#{search_term}%") or
        ilike(email, ^"%#{search_term}%") or
        ilike(display_name, ^"%#{search_term}%")
    )
  end

  defp apply_role_filter(query, "all"), do: query

  defp apply_role_filter(query, role) do
    require Ash.Query
    Ash.Query.filter(query, role == ^String.to_atom(role))
  end

  defp apply_status_filter(query, "all"), do: query

  defp apply_status_filter(query, status) do
    require Ash.Query
    Ash.Query.filter(query, status == ^String.to_atom(status))
  end
end
