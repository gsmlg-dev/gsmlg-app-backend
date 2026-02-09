defmodule GsmlgAppAdminWeb.AppsManagementLive.Index do
  @moduledoc """
  LiveView for listing and managing apps.

  Provides functionality for:
  - Listing all apps with active/deleted filter
  - Creating new apps
  - Editing existing apps
  - Soft deleting and restoring apps
  - Manual reordering via position input
  """

  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.Apps
  alias GsmlgAppAdmin.Apps.App

  @impl true
  def mount(_params, _session, socket) do
    {:ok, apps} = Apps.list_apps_with_store_links(false)

    {:ok,
     socket
     |> assign(:page_title, "Apps Management")
     |> assign(:apps, apps)
     |> assign(:show_deleted, false)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Apps Management")
    |> assign(:app, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New App")
    |> assign(:app, %App{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    app = Apps.get_app_with_store_links!(id)

    socket
    |> assign(:page_title, "Edit App")
    |> assign(:app, app)
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.AppsManagementLive.Form, {:saved, _app}}, socket) do
    {:ok, apps} = Apps.list_apps_with_store_links(socket.assigns.show_deleted)
    {:noreply, assign(socket, :apps, apps)}
  end

  @impl true
  def handle_event("toggle_deleted", _params, socket) do
    show_deleted = !socket.assigns.show_deleted
    {:ok, apps} = Apps.list_apps_with_store_links(show_deleted)

    {:noreply,
     socket
     |> assign(:show_deleted, show_deleted)
     |> assign(:apps, apps)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    app = Apps.get_app!(id)

    case Apps.soft_delete_app(app) do
      {:ok, _app} ->
        {:ok, apps} = Apps.list_apps_with_store_links(socket.assigns.show_deleted)

        {:noreply,
         socket
         |> put_flash(:info, "App \"#{app.name}\" deleted successfully")
         |> assign(:apps, apps)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete app")}
    end
  end

  @impl true
  def handle_event("restore", %{"id" => id}, socket) do
    app = Apps.get_app!(id)

    case Apps.restore_app(app) do
      {:ok, _app} ->
        {:ok, apps} = Apps.list_apps_with_store_links(socket.assigns.show_deleted)

        {:noreply,
         socket
         |> put_flash(:info, "App \"#{app.name}\" restored successfully")
         |> assign(:apps, apps)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to restore app")}
    end
  end

  @impl true
  def handle_event("update_order", %{"id" => id, "order" => order_str}, socket) do
    with {order, ""} <- Integer.parse(order_str),
         app <- Apps.get_app!(id),
         {:ok, _updated} <- Apps.update_app_order(app, order) do
      {:ok, apps} = Apps.list_apps_with_store_links(socket.assigns.show_deleted)

      {:noreply,
       socket
       |> put_flash(:info, "Display order updated")
       |> assign(:apps, apps)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid order value")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <h1 class="text-2xl font-bold">Apps Management</h1>
        </div>
        <div class="flex items-center gap-3">
          <label class="label cursor-pointer gap-2">
            <input
              type="checkbox"
              class="toggle toggle-sm"
              checked={@show_deleted}
              phx-click="toggle_deleted"
            />
            <span class="label-text text-sm">Show deleted</span>
          </label>
          <.link patch={~p"/apps/new"} class="btn btn-primary">
            <.dm_mdi name="plus" class="w-4 h-4 mr-2" /> Add App
          </.link>
        </div>
      </div>

      <div class="grid gap-4">
        <%= if Enum.empty?(@apps) do %>
          <div class="card bg-base-200 p-8 text-center">
            <div class="flex flex-col items-center gap-4">
              <.dm_mdi name="apps" class="w-16 h-16 text-base-content/50" />
              <p class="text-lg">
                <%= if @show_deleted do %>
                  No deleted apps found.
                <% else %>
                  No apps configured yet.
                <% end %>
              </p>
              <%= unless @show_deleted do %>
                <.link patch={~p"/apps/new"} class="btn btn-primary">
                  Add Your First App
                </.link>
              <% end %>
            </div>
          </div>
        <% else %>
          <%= for app <- @apps do %>
            <div class={"card bg-base-100 shadow-md #{unless app.is_active, do: "opacity-60"}"}>
              <div class="card-body">
                <div class="flex items-start justify-between">
                  <div class="flex gap-4">
                    <div class="flex-shrink-0 w-16 h-16 bg-base-200 rounded-lg flex items-center justify-center">
                      <%= if app.icon_path && app.icon_path != "" do %>
                        <img src={app.icon_path} alt={app.name} class="w-12 h-12 object-contain" />
                      <% else %>
                        <.dm_mdi name="application" class="w-8 h-8 text-base-content/50" />
                      <% end %>
                    </div>
                    <div class="flex-1">
                      <div class="flex items-center gap-3">
                        <h2 class="text-lg font-semibold">{app.name}</h2>
                        <span class={"badge #{if app.is_active, do: "badge-success", else: "badge-neutral"}"}>
                          {if app.is_active, do: "Active", else: "Deleted"}
                        </span>
                        <span class="badge badge-outline">{app.category}</span>
                      </div>
                      <p class="text-sm text-base-content/70 mt-1">
                        <span class="font-mono">{app.label}</span>
                      </p>
                      <p class="text-sm text-base-content/80 mt-2">{app.short_description}</p>
                      <div class="flex flex-wrap gap-2 mt-2">
                        <%= for platform <- app.platforms do %>
                          <span class="badge badge-sm badge-outline">{platform_label(platform)}</span>
                        <% end %>
                      </div>
                      <%= if length(app.store_links) > 0 do %>
                        <div class="flex flex-wrap gap-2 mt-2">
                          <%= for link <- app.store_links do %>
                            <a
                              href={link.url}
                              target="_blank"
                              class="badge badge-sm badge-primary gap-1"
                            >
                              <.dm_mdi name={store_icon(link.store_type)} class="w-3 h-3" />
                              {store_label(link.store_type)}
                            </a>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="flex items-center gap-1">
                      <span class="text-sm text-base-content/60">Order:</span>
                      <input
                        type="number"
                        value={app.display_order}
                        phx-blur="update_order"
                        phx-value-id={app.id}
                        phx-value-order={app.display_order}
                        class="input input-bordered input-sm w-16 text-center"
                        min="0"
                        onchange="this.dispatchEvent(new Event('blur', {bubbles: true})); this.setAttribute('phx-value-order', this.value)"
                      />
                    </div>
                    <.link patch={~p"/apps/#{app.id}/edit"} class="btn btn-ghost btn-sm">
                      <.dm_mdi name="pencil" class="w-4 h-4" />
                    </.link>
                    <%= if app.is_active do %>
                      <button
                        phx-click="delete"
                        phx-value-id={app.id}
                        class="btn btn-ghost btn-sm text-error"
                        data-confirm={"Are you sure you want to delete #{app.name}?"}
                      >
                        <.dm_mdi name="delete" class="w-4 h-4" />
                      </button>
                    <% else %>
                      <button
                        phx-click="restore"
                        phx-value-id={app.id}
                        class="btn btn-ghost btn-sm text-success"
                      >
                        <.dm_mdi name="restore" class="w-4 h-4" />
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>

    <.dm_modal :if={@live_action in [:new, :edit]} id="app-modal">
      <:title>{@page_title}</:title>
      <:body>
        <.live_component
          module={GsmlgAppAdminWeb.AppsManagementLive.Form}
          id={@app.id || :new}
          title={@page_title}
          action={@live_action}
          app={@app}
          patch={~p"/apps"}
        />
      </:body>
    </.dm_modal>
    """
  end

  defp platform_label(:ios), do: "iOS"
  defp platform_label(:android), do: "Android"
  defp platform_label(:macos), do: "macOS"
  defp platform_label(:windows), do: "Windows"
  defp platform_label(:linux), do: "Linux"
  defp platform_label(other), do: to_string(other)

  defp store_label(:appstore), do: "App Store"
  defp store_label(:playstore), do: "Play Store"
  defp store_label(:fdroid), do: "F-Droid"
  defp store_label(:other), do: "Other"
  defp store_label(other), do: to_string(other)

  defp store_icon(:appstore), do: "apple"
  defp store_icon(:playstore), do: "google-play"
  defp store_icon(:fdroid), do: "android"
  defp store_icon(_), do: "link"
end
