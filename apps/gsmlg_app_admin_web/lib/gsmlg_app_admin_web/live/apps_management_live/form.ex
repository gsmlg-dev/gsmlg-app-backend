defmodule GsmlgAppAdminWeb.AppsManagementLive.Form do
  @moduledoc """
  LiveComponent for creating and editing apps.

  Provides a form with:
  - Basic app details (name, label, descriptions)
  - Platform selection (multi-select)
  - Category selection
  - Store links management (add/remove)
  """

  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.Apps
  alias GsmlgAppAdmin.Apps.App

  @platforms [
    {"iOS", :ios},
    {"Android", :android},
    {"macOS", :macos},
    {"Windows", :windows},
    {"Linux", :linux}
  ]

  @categories [
    {"Network", :network},
    {"Utility", :utility},
    {"Development", :development}
  ]

  @store_types [
    {"App Store", :appstore},
    {"Play Store", :playstore},
    {"F-Droid", :fdroid},
    {"Other", :other}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold mb-4">{@title}</h2>

      <.form for={@form} id="app-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Name *</span>
            </label>
            <input
              type="text"
              name={@form[:name].name}
              value={@form[:name].value}
              placeholder="My App"
              class={"input input-bordered w-full #{if @form[:name].errors != [], do: "input-error"}"}
              required
              maxlength="100"
            />
            <%= if @form[:name].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {format_errors(@form[:name].errors)}
                </span>
              </label>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Label *</span>
            </label>
            <input
              type="text"
              name={@form[:label].name}
              value={@form[:label].value}
              placeholder="my_app"
              class={"input input-bordered w-full #{if @form[:label].errors != [], do: "input-error"}"}
              required
              maxlength="50"
              pattern="[a-z0-9_]+"
            />
            <label class="label">
              <span class="label-text-alt">
                URL-friendly identifier (lowercase letters, numbers, underscores only)
              </span>
            </label>
            <%= if @form[:label].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {format_errors(@form[:label].errors)}
                </span>
              </label>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Short Description *</span>
            </label>
            <input
              type="text"
              name={@form[:short_description].name}
              value={@form[:short_description].value}
              placeholder="Brief tagline for the app"
              class={"input input-bordered w-full #{if @form[:short_description].errors != [], do: "input-error"}"}
              required
              maxlength="200"
            />
            <%= if @form[:short_description].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {format_errors(@form[:short_description].errors)}
                </span>
              </label>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Long Description</span>
            </label>
            <textarea
              name={@form[:long_description].name}
              placeholder="Detailed description of the app"
              class="textarea textarea-bordered w-full"
              rows="3"
            >{@form[:long_description].value}</textarea>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Icon Path *</span>
            </label>
            <input
              type="text"
              name={@form[:icon_path].name}
              value={@form[:icon_path].value}
              placeholder="/images/icons/app.png"
              class={"input input-bordered w-full #{if @form[:icon_path].errors != [], do: "input-error"}"}
              required
            />
            <label class="label">
              <span class="label-text-alt">Path to the icon image file</span>
            </label>
            <%= if @form[:icon_path].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {format_errors(@form[:icon_path].errors)}
                </span>
              </label>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Platforms *</span>
            </label>
            <div class="flex flex-wrap gap-3">
              <%= for {label, value} <- @platforms do %>
                <label class="label cursor-pointer gap-2">
                  <input
                    type="checkbox"
                    name="app[platforms][]"
                    value={value}
                    checked={value in @selected_platforms}
                    class="checkbox checkbox-sm checkbox-primary"
                  />
                  <span class="label-text">{label}</span>
                </label>
              <% end %>
            </div>
            <%= if @form[:platforms].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {format_errors(@form[:platforms].errors)}
                </span>
              </label>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Category *</span>
            </label>
            <select
              name={@form[:category].name}
              class={"select select-bordered w-full #{if @form[:category].errors != [], do: "select-error"}"}
              required
            >
              <option value="" disabled selected={is_nil(@form[:category].value)}>
                Select a category
              </option>
              <%= for {label, value} <- @categories do %>
                <option value={value} selected={@form[:category].value == value}>
                  {label}
                </option>
              <% end %>
            </select>
            <%= if @form[:category].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {format_errors(@form[:category].errors)}
                </span>
              </label>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Display Order</span>
            </label>
            <input
              type="number"
              name={@form[:display_order].name}
              value={@form[:display_order].value || 0}
              class="input input-bordered w-full"
              min="0"
            />
            <label class="label">
              <span class="label-text-alt">Lower numbers appear first</span>
            </label>
          </div>

          <div class="divider">Store Links</div>

          <div class="space-y-3">
            <%= for {link, index} <- Enum.with_index(@store_links) do %>
              <div class="flex gap-2 items-start">
                <select
                  name={"store_links[#{index}][store_type]"}
                  class="select select-bordered select-sm flex-shrink-0 w-32"
                >
                  <%= for {label, value} <- @store_types do %>
                    <option value={value} selected={link.store_type == value}>
                      {label}
                    </option>
                  <% end %>
                </select>
                <input
                  type="url"
                  name={"store_links[#{index}][url]"}
                  value={link.url}
                  placeholder="https://..."
                  class="input input-bordered input-sm flex-1"
                  required
                />
                <button
                  type="button"
                  phx-click="remove_store_link"
                  phx-value-index={index}
                  phx-target={@myself}
                  class="btn btn-ghost btn-sm text-error"
                >
                  <.dm_mdi name="close" class="w-4 h-4" />
                </button>
              </div>
            <% end %>
            <button
              type="button"
              phx-click="add_store_link"
              phx-target={@myself}
              class="btn btn-outline btn-sm"
            >
              <.dm_mdi name="plus" class="w-4 h-4 mr-1" /> Add Store Link
            </button>
          </div>
        </div>

        <div class="flex justify-end gap-3 mt-6 pt-4 border-t">
          <.link patch={@patch} class="btn btn-ghost">Cancel</.link>
          <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
            {if @action == :new, do: "Create App", else: "Update App"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{app: app} = assigns, socket) do
    form =
      if assigns.action == :new do
        AshPhoenix.Form.for_create(App, :create, as: "app")
      else
        AshPhoenix.Form.for_update(app, :update, as: "app")
      end

    selected_platforms =
      if app.platforms, do: app.platforms, else: []

    store_links =
      if is_list(app.store_links) && length(app.store_links) > 0 do
        Enum.map(app.store_links, fn link ->
          %{
            id: link.id,
            store_type: link.store_type,
            url: link.url,
            display_order: link.display_order
          }
        end)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(form))
     |> assign(:platforms, @platforms)
     |> assign(:categories, @categories)
     |> assign(:store_types, @store_types)
     |> assign(:selected_platforms, selected_platforms)
     |> assign(:store_links, store_links)}
  end

  @impl true
  def handle_event("validate", %{"app" => app_params} = params, socket) do
    # Update selected platforms from the checkbox params
    platforms = get_platforms_from_params(params)

    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(Map.put(app_params, "platforms", platforms))
      |> to_form()

    # Update store links from params
    store_links = get_store_links_from_params(params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_platforms, platforms)
     |> assign(:store_links, store_links)}
  end

  @impl true
  def handle_event("add_store_link", _params, socket) do
    new_link = %{
      id: nil,
      store_type: :appstore,
      url: "",
      display_order: length(socket.assigns.store_links)
    }

    {:noreply, assign(socket, :store_links, socket.assigns.store_links ++ [new_link])}
  end

  @impl true
  def handle_event("remove_store_link", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    store_links = List.delete_at(socket.assigns.store_links, index)
    {:noreply, assign(socket, :store_links, store_links)}
  end

  @impl true
  def handle_event("save", %{"app" => app_params} = params, socket) do
    platforms = get_platforms_from_params(params)
    store_links = get_store_links_from_params(params)

    app_params =
      app_params
      |> Map.put("platforms", platforms)
      |> maybe_set_display_order(socket)

    save_app(socket, socket.assigns.action, app_params, store_links)
  end

  defp save_app(socket, :new, app_params, store_links) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: app_params) do
      {:ok, app} ->
        # Create store links for the new app
        Enum.each(store_links, fn link ->
          if link.url && link.url != "" do
            Apps.create_store_link(%{
              app_id: app.id,
              store_type: link.store_type,
              url: link.url,
              display_order: link[:display_order] || 0
            })
          end
        end)

        notify_parent({:saved, app})

        {:noreply,
         socket
         |> put_flash(:info, "App created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp save_app(socket, :edit, app_params, store_links) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: app_params) do
      {:ok, app} ->
        # Update store links - delete existing and recreate
        existing_links = Apps.get_app_with_store_links!(app.id).store_links

        # Delete old links
        Enum.each(existing_links, fn link ->
          Apps.delete_store_link(link)
        end)

        # Create new links
        Enum.with_index(store_links, fn link, index ->
          if link.url && link.url != "" do
            Apps.create_store_link(%{
              app_id: app.id,
              store_type: link.store_type,
              url: link.url,
              display_order: index
            })
          end
        end)

        notify_parent({:saved, app})

        {:noreply,
         socket
         |> put_flash(:info, "App updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp get_platforms_from_params(params) do
    case params do
      %{"app" => %{"platforms" => platforms}} when is_list(platforms) ->
        Enum.map(platforms, &String.to_existing_atom/1)

      _ ->
        []
    end
  end

  defp get_store_links_from_params(params) do
    case params do
      %{"store_links" => links} when is_map(links) ->
        links
        |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
        |> Enum.map(fn {_k, v} ->
          %{
            id: nil,
            store_type: String.to_existing_atom(v["store_type"] || "other"),
            url: v["url"] || "",
            display_order: 0
          }
        end)

      _ ->
        []
    end
  end

  defp maybe_set_display_order(params, socket) do
    if socket.assigns.action == :new &&
         (is_nil(params["display_order"]) || params["display_order"] == "") do
      Map.put(params, "display_order", Apps.next_display_order())
    else
      params
    end
  end

  defp format_errors(errors) do
    Enum.map(errors, fn {msg, _} -> msg end) |> Enum.join(", ")
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
