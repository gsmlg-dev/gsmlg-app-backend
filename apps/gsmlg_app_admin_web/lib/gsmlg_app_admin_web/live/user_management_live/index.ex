defmodule GsmlgAppAdminWeb.UserManagementLive.Index do
  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.Accounts
  alias GsmlgAppAdmin.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "User Management")
     |> assign(:users, list_users())
     |> assign(:search_query, "")
     |> assign(:selected_role, "all")
     |> assign(:selected_status, "all")}
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
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Accounts.get_user!(id))
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
end
