defmodule GsmlgAppAdminWeb.Layouts do
  use GsmlgAppAdminWeb, :html

  embed_templates "layouts/*"

  slot :inner_block, required: true

  attr :flash, :map, required: true
  attr :current_user, :any, default: nil

  def app(assigns) do
    ~H"""
    <.dm_simple_appbar
      title="GSMLG APP Admin"
      class="bg-primary text-primary-content sticky top-0 z-100"
    >
      <:user_profile>
        <%= if @current_user do %>
          <div tabindex="0" role="button" class="btn btn-ghost">
            <div class="w-20 flex justify-center items-center">
              {@current_user.email}
            </div>
          </div>
          <ul
            tabindex="0"
            class="mt-3 z-[1] p-2 menu menu-sm dropdown-content bg-primary text-primary-content rounded-box w-52"
          >
            <li>
              <.link href="/sign-out">Sign Out</.link>
            </li>
          </ul>
        <% else %>
          <a
            href="/sign-in"
            class="btn btn-ghost"
          >
            Sign In
          </a>
        <% end %>
      </:user_profile>
    </.dm_simple_appbar>
    <.dm_flash_group flash={@flash} />
    <main class="flex w-full min-h-screen">
      <div class="container mx-auto px-4">
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end
end
