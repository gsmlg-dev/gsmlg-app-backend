defmodule GsmlgAppAdminWeb.UserManagementLive.Index do
  @moduledoc """
  LiveView for managing users in the admin interface.

  This module provides functionality for:
  - Listing users with search and filtering
  - Creating new users
  - Editing existing users
  - Deleting users with proper error handling
  - Real-time updates using LiveView streams
  """
  use GsmlgAppAdminWeb, :live_view
  require Logger

  alias GsmlgAppAdmin.Accounts
  alias GsmlgAppAdmin.Accounts.User

  on_mount {GsmlgAppAdminWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    with {:ok, users} <- fetch_users_with_error_handling() do
      {:ok,
       socket
       |> assign(:page_title, "User Management")
       |> assign(:users, users)
       |> assign(:search_query, "")
       |> assign(:selected_role, "all")
       |> assign(:selected_status, "all")
       |> assign(:error, nil)}
    else
      {:error, error} ->
        {:ok,
         socket
         |> assign(:page_title, "User Management")
         |> assign(:users, [])
         |> assign(:search_query, "")
         |> assign(:selected_role, "all")
         |> assign(:selected_status, "all")
         |> assign(:error, "Failed to load users: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "User Management")
    |> assign(:user, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    try do
      user = Accounts.get_user!(id)

      socket
      |> assign(:page_title, "Edit User")
      |> assign(:user, user)
      |> assign(:error, nil)
    rescue
      Ash.Error.Query.NotFound ->
        socket
        |> assign(:page_title, "Edit User")
        |> assign(:user, nil)
        |> assign(:error, "User not found")
        |> put_flash(:error, "User not found")

      error ->
        socket
        |> assign(:page_title, "Edit User")
        |> assign(:user, nil)
        |> assign(:error, "Failed to load user: #{inspect(error)}")
        |> put_flash(:error, "Failed to load user")
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    users = search_users(query, socket.assigns.selected_role, socket.assigns.selected_status)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:users, users)}
  end

  def handle_event("filter_role", %{"role" => role}, socket) do
    users = search_users(socket.assigns.search_query, role, socket.assigns.selected_status)

    {:noreply,
     socket
     |> assign(:selected_role, role)
     |> assign(:users, users)}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    users = search_users(socket.assigns.search_query, socket.assigns.selected_role, status)

    {:noreply,
     socket
     |> assign(:selected_status, status)
     |> assign(:users, users)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    try do
      user = Ash.get!(User, id)
      Ash.destroy!(user)

      {:noreply,
       socket
       |> put_flash(:info, "User deleted successfully")
       |> assign(:users, list_users())}
    rescue
      Ash.Error.Query.NotFound ->
        {:noreply,
         socket
         |> put_flash(:error, "User not found")}

      error ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete user: #{inspect(error)}")}
    end
  end

  defp list_users do
    Accounts.list_users()
  end

  defp search_users(query, role, status) do
    Accounts.search_users(%{
      query: query,
      role: role,
      status: status
    })
  end

  def format_datetime(nil), do: "Never"

  def format_datetime(datetime) do
    DateTime.to_string(datetime)
  end

  def status_badge_class(:active), do: "bg-green-100 text-green-800"
  def status_badge_class(:inactive), do: "bg-gray-100 text-gray-800"
  def status_badge_class(:suspended), do: "bg-red-100 text-red-800"
  def status_badge_class(:pending), do: "bg-yellow-100 text-yellow-800"

  def role_badge_class(:admin), do: "bg-purple-100 text-purple-800"
  def role_badge_class(:moderator), do: "bg-blue-100 text-blue-800"
  def role_badge_class(:user), do: "bg-gray-100 text-gray-800"

  # Error handling functions
  defp fetch_users_with_error_handling do
    try do
      users = Accounts.list_users()
      {:ok, users}
    rescue
      error ->
        Logger.error("Failed to fetch users: #{inspect(error)}")
        {:error, error}
    catch
      :exit, reason ->
        Logger.error("Process exited while fetching users: #{inspect(reason)}")
        {:error, reason}

      :throw, value ->
        Logger.error("Thrown value while fetching users: #{inspect(value)}")
        {:error, value}
    end
  end
end
