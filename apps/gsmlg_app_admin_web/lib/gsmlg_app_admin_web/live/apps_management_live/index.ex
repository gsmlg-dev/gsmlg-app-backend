defmodule GsmlgAppAdminWeb.AppsManagementLive.Index do
  @moduledoc """
  LiveView for listing and managing apps.

  Provides functionality for:
  - Listing all apps with active/deleted filter
  - Soft deleting and restoring apps
  - Manual reordering via position input
  """

  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.Apps

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
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Apps Management")}
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
    <div class="w-full bg-surface px-4 py-6 text-on-surface sm:px-6 lg:px-8">
      <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <h1 class="text-3xl font-semibold leading-8 text-on-surface">Apps Management</h1>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <label class="label cursor-pointer gap-2">
            <input
              type="checkbox"
              class="toggle toggle-primary toggle-sm"
              checked={@show_deleted}
              phx-click="toggle_deleted"
            />
            <span class="text-sm text-on-surface">Show deleted</span>
          </label>
          <.link navigate={~p"/apps/new"} class="btn btn-primary">
            <.dm_mdi name="plus" class="w-4 h-4 mr-2" /> Add App
          </.link>
        </div>
      </div>

      <div class="grid gap-4">
        <%= if Enum.empty?(@apps) do %>
          <div class="rounded-lg border border-outline-variant bg-surface-container p-8 text-center shadow-sm">
            <div class="flex flex-col items-center gap-4">
              <.dm_mdi name="apps" class="w-16 h-16 text-on-surface-variant" />
              <p class="text-lg">
                <%= if @show_deleted do %>
                  No deleted apps found.
                <% else %>
                  No apps configured yet.
                <% end %>
              </p>
              <%= unless @show_deleted do %>
                <.link navigate={~p"/apps/new"} class="btn btn-primary">
                  Add Your First App
                </.link>
              <% end %>
            </div>
          </div>
        <% else %>
          <%= for app <- @apps do %>
            <div class={[
              "rounded-lg border border-outline-variant bg-surface-container p-4 shadow-sm",
              unless(app.is_active, do: "opacity-60")
            ]}>
              <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div class="flex min-w-0 gap-4">
                  <div class="flex h-16 w-16 flex-shrink-0 items-center justify-center rounded-lg bg-surface-container-high">
                    <%= if app.icon_path && app.icon_path != "" do %>
                      <img src={app.icon_path} alt={app.name} class="h-12 w-12 object-contain" />
                    <% else %>
                      <.dm_mdi name="application" class="h-8 w-8 text-on-surface-variant" />
                    <% end %>
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-3">
                      <h2 class="text-lg font-semibold text-on-surface">{app.name}</h2>
                      <span class={[
                        "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                        if(app.is_active,
                          do: "bg-success text-success-content",
                          else: "bg-surface-container-high text-on-surface"
                        )
                      ]}>
                        {if app.is_active, do: "Active", else: "Deleted"}
                      </span>
                      <span class="inline-flex rounded-full border border-outline px-2 text-xs font-semibold leading-5 text-on-surface-variant">
                        {app.category}
                      </span>
                    </div>
                    <p class="mt-1 text-sm text-on-surface-variant">
                      <span class="font-mono">{app.label}</span>
                    </p>
                    <p class="mt-2 text-sm text-on-surface">{app.short_description}</p>
                    <div class="mt-2 flex flex-wrap gap-2">
                      <%= for platform <- app.platforms do %>
                        <span class="inline-flex rounded-full border border-outline px-2 text-xs font-medium text-on-surface-variant">
                          {platform_label(platform)}
                        </span>
                      <% end %>
                    </div>
                    <%= if length(app.store_links) > 0 do %>
                      <div class="mt-2 flex flex-wrap gap-2">
                        <%= for link <- app.store_links do %>
                          <a
                            href={link.url}
                            target="_blank"
                            class="inline-flex items-center gap-1 rounded-full bg-primary px-2 py-0.5 text-xs font-semibold text-primary-content"
                          >
                            <.dm_mdi name={store_icon(link.store_type)} class="h-3 w-3" />
                            {store_label(link.store_type)}
                          </a>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
                <div class="flex flex-wrap items-center gap-2 lg:flex-nowrap">
                  <div class="flex items-center gap-1">
                    <span class="text-sm text-on-surface-variant">Order:</span>
                    <input
                      type="number"
                      value={app.display_order}
                      phx-blur="update_order"
                      phx-value-id={app.id}
                      phx-value-order={app.display_order}
                      class="input input-bordered input-sm w-16 text-center"
                      min="0"
                      aria-label={"Display order for #{app.name}"}
                      onchange="this.dispatchEvent(new Event('blur', {bubbles: true})); this.setAttribute('phx-value-order', this.value)"
                    />
                  </div>
                  <.link
                    navigate={~p"/apps/#{app.id}/edit"}
                    class="btn btn-ghost btn-sm text-primary hover:text-secondary"
                    aria-label={"Edit #{app.name}"}
                  >
                    <.dm_mdi name="pencil" class="h-4 w-4" />
                  </.link>
                  <%= if app.is_active do %>
                    <button
                      phx-click="delete"
                      phx-value-id={app.id}
                      class="btn btn-ghost btn-sm text-error"
                      data-confirm={"Are you sure you want to delete #{app.name}?"}
                      aria-label={"Delete #{app.name}"}
                    >
                      <.dm_mdi name="delete" class="h-4 w-4" />
                    </button>
                  <% else %>
                    <button
                      phx-click="restore"
                      phx-value-id={app.id}
                      class="btn btn-ghost btn-sm text-success"
                      aria-label={"Restore #{app.name}"}
                    >
                      <.dm_mdi name="restore" class="h-4 w-4" />
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
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
