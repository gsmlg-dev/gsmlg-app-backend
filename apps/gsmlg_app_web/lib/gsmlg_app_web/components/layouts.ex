defmodule GsmlgAppWeb.Layouts do
  use GsmlgAppWeb, :html
  use Gettext, backend: GsmlgAppWeb.Gettext

  embed_templates "layouts/*"

  @doc """
  Base layout component that provides common structure for all layouts.
  Uses dm_page_header for scroll-based navigation with hero content support.
  """
  slot :header_slot
  slot :inner_block, required: true
  attr :flash, :map, required: true
  attr :current_page, :string, required: true
  attr :header_class, :string, default: nil
  attr :main_class, :string, default: nil
  attr :extra_header_class, :string, default: nil

  def base_layout(assigns) do
    ~H"""
    <.dm_page_header
      class={[
        "bg-gradient-to-br from-slate-700 to-neutral-700",
        "text-slate-400",
        "h-fit",
        @header_class,
        @extra_header_class
      ]}
      nav_class="bg-black text-slate-400 z-50"
    >
      <:menu class={menu_active_class("home", @current_page)} to="/">
        {dgettext("navigation", "Home")}
      </:menu>
      <:menu class={menu_active_class("apps", @current_page)} to="/apps">
        {dgettext("navigation", "Apps")}
      </:menu>
      <:menu class={menu_active_class("support", @current_page)} to="/support">
        {dgettext("navigation", "Support")}
      </:menu>
      <:menu class={menu_active_class("about-us", @current_page)} to="/about-us">
        {dgettext("navigation", "About Us")}
      </:menu>
      <:user_profile></:user_profile>
      {render_slot(@header_slot)}
    </.dm_page_header>
    <main class={["flex flex-col min-h-[calc(100vh-50%)] w-full", @main_class]}>
      <div class="w-full min-w-full min-h-full mx-auto flex flex-col items-center">
        <.dm_flash_group flash={@flash} />
        <a name="page"></a>
        {render_slot(@inner_block)}
      </div>
    </main>
    <.app_footer />
    """
  end

  defp menu_active_class(page, current_page) when page == current_page,
    do: "border-b-2 text-slate-200 border-slate-200 uppercase"

  defp menu_active_class(_page, _current_page),
    do: "uppercase"

  slot :header_slot
  slot :inner_block, required: true
  attr :flash, :map, required: true

  def app(assigns) do
    ~H"""
    <.base_layout flash={@flash} current_page="apps">
      <:header_slot>{render_slot(@header_slot)}</:header_slot>
      {render_slot(@inner_block)}
    </.base_layout>
    """
  end

  slot :header_slot
  slot :inner_block, required: true
  attr :flash, :map, required: true

  def home(assigns) do
    ~H"""
    <.base_layout
      flash={@flash}
      current_page="home"
      extra_header_class="bg-[url(/images/sky-commet.jpg)] bg-no-repeat bg-cover h-screen"
    >
      <:header_slot>{render_slot(@header_slot)}</:header_slot>
      {render_slot(@inner_block)}
    </.base_layout>
    """
  end

  slot :header_slot
  slot :inner_block, required: true
  attr :flash, :map, required: true

  def support(assigns) do
    ~H"""
    <.base_layout flash={@flash} current_page="support" main_class="min-h-[20vh] w-full">
      <:header_slot>{render_slot(@header_slot)}</:header_slot>
      {render_slot(@inner_block)}
    </.base_layout>
    """
  end

  slot :header_slot
  slot :inner_block, required: true
  attr :flash, :map, required: true

  def privacy(assigns) do
    ~H"""
    <.base_layout flash={@flash} current_page="privacy" main_class="min-h-[20vh] w-full">
      <:header_slot>{render_slot(@header_slot)}</:header_slot>
      {render_slot(@inner_block)}
    </.base_layout>
    """
  end

  slot :header_slot
  slot :inner_block, required: true
  attr :flash, :map, required: true

  def about(assigns) do
    ~H"""
    <.base_layout flash={@flash} current_page="about-us">
      <:header_slot>{render_slot(@header_slot)}</:header_slot>
      {render_slot(@inner_block)}
    </.base_layout>
    """
  end
end
