defmodule GsmlgAppComponent.App do
  @moduledoc """
  Documentation for `GsmlgAppComponent`.
  """
  use Phoenix.Component

  @doc """
  Renders app bar.

  ## Examples

  """
  attr(:id, :any, default: false)
  attr(:class, :any, default: false)
  attr(:title, :string, default: "GSMLG APP")

  slot(:user_block, doc: "the user block at right")

  def app_topbar(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> false end)
      |> assign_new(:active, fn -> false end)

    ~H"""
    <header id={@id} class={["navbar bg-primary text-primary-content", @class]}>
      <div class="drawer w-fit xl:hidden">
        <input id="app-drawer" type="checkbox" class="drawer-toggle" />
        <div class="drawer-content">
          <!-- Page content here -->
          <label for="app-drawer" class="btn btn-primary drawer-button">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 5.25h16.5m-16.5 4.5h16.5m-16.5 4.5h16.5m-16.5 4.5h16.5" />
          </svg>
          </label>
        </div>
        <div class="drawer-side">
          <label for="app-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
          <.app_menus class="bg-base-300 text-base-content h-full" />
        </div>
      </div>
      <div class="flex-1">
        <a class="btn btn-ghost text-xl"><%= @title %></a>
      </div>
      <div class="flex-none gap-2">
        <div class="dropdown dropdown-end">
          <%= render_slot(@user_block) %>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Generates app menus
  """
  attr(:id, :any, default: nil)
  attr(:class, :any, default: nil)
  attr(:active_id, :string, default: "")

  attr(:menus, :any,
    default: [],
    doc: """
    menus = [
      %{
        title: "Title",
        items: [
          %{
            id: "1",
            title: "Home",
            navigate: "/",
          }
        ]
      }
    ]
    """
  )

  def app_menus(assigns) do
    ~H"""
    <ul id={@id} class={["menu rounded-box mb-4", @class]}>
      <li :for={menu_group <- @menus}>
        <h2 class="menu-title">
          <%= Map.get(menu_group, :title) %>
        </h2>
        <ul>
          <li :for={menu <- Map.get(menu_group, :items, [])}>
            <.link
              class={if(@active_id == Map.get(menu, :id, nil), do: "active")}
              navigate={Map.get(menu, :navigate)}
            >
              <%= Map.get(menu, :title) %>
            </.link>
          </li>
        </ul>
      </li>
    </ul>
    """
  end
end
