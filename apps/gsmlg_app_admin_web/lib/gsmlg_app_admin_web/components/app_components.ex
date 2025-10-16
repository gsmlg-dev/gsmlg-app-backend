defmodule GsmlgAppAdminWeb.AppComponents do
  @moduledoc """
  Provides APP UI components.

  """
  use Phoenix.Component
  use PhoenixDuskmoon.Component

    use Gettext, backend: GsmlgAppAdminWeb.Gettext

  use GsmlgAppAdminWeb, :verified_routes

  def app_footer(assigns) do
    ~H"""
    <.dm_page_footer class={[
      "bg-slate-900",
      "text-slate-500"
    ]}>
      <:section title="About" title_class="py-2 px-4 text-slate-600">
        <.link
          class={[
            "py-2 px-4"
          ]}
          href="/products"
        >
          Products
        </.link>
        <.link class="py-2 px-4" href="/license">
          License
        </.link>
        <.link class="py-2 px-4" href="/assistant">
          A.I. Assistant
        </.link>
        <.link class="py-2 px-4" href="/about">
          About US
        </.link>
      </:section>
      <:copyright>
        <div class="flex gap-x-4">
          <.dm_mdi name="youtube" class="w-8 h-8 text-slate-600" />
          <.dm_mdi name="twitter" class="w-8 h-8 text-slate-600" />
          <.dm_mdi name="facebook" class="w-8 h-8 text-slate-600" />
        </div>
        <p class="my-4 text-md">
          Copyright © 2023 G.S.M.L.G. All rights reserved.
        </p>
      </:copyright>
    </.dm_page_footer>
    """
  end
end
