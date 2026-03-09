defmodule GsmlgAppWeb.AppComponents do
  @moduledoc """
  Provides APP UI components using phoenix_duskmoon v9 design system.
  """
  use Phoenix.Component
  use PhoenixDuskmoon.Component

  use Gettext, backend: GsmlgAppWeb.Gettext

  use GsmlgAppWeb, :verified_routes

  def app_footer(assigns) do
    ~H"""
    <.dm_page_footer class="bg-slate-900 text-slate-500">
      <:section title={dgettext("navigation", "Site Map")} title_class="py-2 px-4 text-slate-600">
        <.link class="py-2 px-4" href="/">{dgettext("navigation", "Home")}</.link>
        <.link class="py-2 px-4" href="/apps">{dgettext("navigation", "Apps")}</.link>
        <.link class="py-2 px-4" href="/support">{dgettext("navigation", "Support")}</.link>
        <.link class="py-2 px-4" href="/about-us">{dgettext("navigation", "About Us")}</.link>
      </:section>
      <:copyright>
        <div class="flex gap-x-4">
          <.dm_mdi name="youtube" class="w-8 h-8 text-slate-600" />
          <.dm_mdi name="twitter" class="w-8 h-8 text-slate-600" />
          <.dm_mdi name="facebook" class="w-8 h-8 text-slate-600" />
        </div>
        <p class="my-4 text-md">
          {dgettext("common", "Copyright © 2025 GSMLG All rights reserved.")}
        </p>
      </:copyright>
    </.dm_page_footer>
    """
  end

  @doc """
  Enhanced app card component using dm_card with dm_dropdown for actions.
  """
  attr(:id, :any, default: false)
  attr(:class, :string, default: "")
  attr(:icon_path, :string, required: true)
  attr(:name, :string, required: true)
  attr(:app_label, :string, default: "")
  attr(:platforms, :list, default: [])
  attr(:category, :string, default: "utility")

  slot(:description, required: true)

  slot(:store_link, required: false) do
    attr(:link, :string)
  end

  def enhanced_app_section(assigns) do
    ~H"""
    <.dm_card
      id={@id}
      class={[
        "bg-base-100 shadow-2xl hover:shadow-3xl transition-all duration-300",
        "border border-base-300 hover:border-primary",
        "group cursor-pointer card-hover-lift",
        @class
      ]}
    >
      <:title class="flex items-center gap-4">
        <div class="avatar">
          <div class="w-16 h-16 rounded-2xl ring-4 ring-primary ring-offset-2 group-hover:scale-110 transition-transform duration-300">
            <img src={@icon_path} alt={@name} />
          </div>
        </div>
        <div>
          <h2 class="text-2xl font-bold text-primary">{@name}</h2>
          <div class="flex gap-2 mt-1">
            <.dm_badge variant="tertiary" class="badge-xs capitalize">{@category}</.dm_badge>
            <.platform_chips platforms={@platforms} />
          </div>
        </div>
      </:title>

      <:action>
        <.dm_dropdown position="bottom">
          <:trigger class="btn btn-circle btn-ghost btn-sm">
            <.dm_mdi name="dots-vertical" class="w-4 h-4" />
          </:trigger>
          <:content>
            <.link navigate={~p"/apps-support/app/#{@app_label}"} class="popover-menu-item">
              <.dm_mdi name="headset" class="w-4 h-4" /> {dgettext("navigation", "Support")}
            </.link>
            <.link navigate={~p"/apps-privacy/app/#{@app_label}"} class="popover-menu-item">
              <.dm_mdi name="shield-lock-outline" class="w-4 h-4" /> {dgettext(
                "navigation",
                "Privacy"
              )}
            </.link>
          </:content>
        </.dm_dropdown>
      </:action>

      <div class="card-body">
        <div class="space-y-3">
          <p :for={d <- @description} class="text-base-content/80 leading-relaxed">
            {render_slot(d)}
          </p>
        </div>

        <.dm_divider />

        <div class="card-actions justify-between items-center">
          <div class="flex items-center gap-2">
            <span class="text-sm font-semibold text-base-content/60">
              {dgettext("user", "Available on:")}:
            </span>
            <div class="flex gap-2">
              <.link
                :for={store <- @store_link}
                class="btn btn-circle btn-ghost btn-sm hover:scale-110 transition-transform duration-200"
                target="_blank"
                href={Map.get(store, :link, "javascript:void(0)")}
              >
                {render_slot(store)}
              </.link>
            </div>
          </div>

          <div class="flex gap-2">
            <.dm_btn variant="outline" size="sm" class="hover:bg-primary hover:text-primary-content">
              <.link navigate={~p"/apps-support/app/#{@app_label}"} class="flex items-center gap-1">
                <.dm_mdi name="headset" class="w-4 h-4" /> {dgettext("navigation", "Support")}
              </.link>
            </.dm_btn>
            <.dm_btn
              variant="outline"
              size="sm"
              class="hover:bg-secondary hover:text-secondary-content"
            >
              <.link navigate={~p"/apps-privacy/app/#{@app_label}"} class="flex items-center gap-1">
                <.dm_mdi name="shield-lock-outline" class="w-4 h-4" /> {dgettext(
                  "navigation",
                  "Privacy"
                )}
              </.link>
            </.dm_btn>
          </div>
        </div>
      </div>
    </.dm_card>
    """
  end

  @doc """
  App card component that renders from cached data (maps instead of slots).
  Uses dm_card with dm_dropdown and dm_badge components.
  """
  attr(:app, :map, required: true, doc: "App map from cache")
  attr(:class, :string, default: nil)
  attr(:id, :string, default: nil)

  def cached_app_card(assigns) do
    assigns = assign_new(assigns, :id, fn -> "app-#{assigns.app.label}" end)

    ~H"""
    <div
      id={@id}
      class={[
        "glass-card gradient-border rounded-2xl p-6 sm:p-8",
        "feature-card group",
        @class
      ]}
    >
      <div class="flex flex-col sm:flex-row gap-6">
        <!-- App Icon & Identity -->
        <div class="flex items-start gap-5 flex-1 min-w-0">
          <div class="shrink-0">
            <div class="w-18 h-18 sm:w-20 sm:h-20 rounded-2xl overflow-hidden ring-2 ring-white/10 group-hover:ring-primary/50 transition-all duration-300 group-hover:scale-105">
              <img src={@app.icon_path} alt={@app.name} class="w-full h-full object-cover" />
            </div>
          </div>
          <div class="min-w-0 flex-1 space-y-2">
            <div class="flex items-center gap-3 flex-wrap">
              <h2 class="text-xl sm:text-2xl font-bold text-white group-hover:text-primary transition-colors duration-300">
                {@app.name}
              </h2>
              <.dm_badge variant="tertiary" class="badge-xs capitalize">{@app.category}</.dm_badge>
            </div>
            <p class="text-gray-400 leading-relaxed text-sm sm:text-base">{@app.short_description}</p>
            <%= if @app.long_description do %>
              <p class="text-gray-500 leading-relaxed text-sm">{@app.long_description}</p>
            <% end %>
          </div>
        </div>
        
    <!-- Actions Column -->
        <div class="flex sm:flex-col items-center sm:items-end justify-between sm:justify-start gap-3 sm:gap-4 shrink-0">
          <div class="flex items-center gap-2">
            <.platform_chips platforms={@app.platforms} />
          </div>
          <.dm_dropdown position="bottom">
            <:trigger class="btn btn-circle btn-ghost btn-sm text-gray-400 hover:text-white">
              <.dm_mdi name="dots-vertical" class="w-5 h-5" />
            </:trigger>
            <:content>
              <.link navigate={~p"/apps-support/app/#{@app.label}"} class="popover-menu-item">
                <.dm_mdi name="headset" class="w-4 h-4" /> {dgettext("navigation", "Support")}
              </.link>
              <.link navigate={~p"/apps-privacy/app/#{@app.label}"} class="popover-menu-item">
                <.dm_mdi name="shield-lock-outline" class="w-4 h-4" /> {dgettext(
                  "navigation",
                  "Privacy"
                )}
              </.link>
            </:content>
          </.dm_dropdown>
        </div>
      </div>
      
    <!-- Store Links & Quick Actions -->
      <div class="mt-5 pt-5 border-t border-white/5 flex flex-wrap items-center justify-between gap-4">
        <div class="flex items-center gap-3">
          <span class="text-xs font-medium text-gray-500 uppercase tracking-wider">
            {dgettext("user", "Available on")}
          </span>
          <div class="flex gap-1">
            <.link
              :for={store <- @app.store_links}
              class="w-9 h-9 rounded-lg bg-white/5 hover:bg-white/15 flex items-center justify-center transition-all duration-200 hover:scale-110"
              target="_blank"
              href={store.url}
            >
              <.store_icon type={store.store_type} class="w-5 h-5 text-gray-300" />
            </.link>
          </div>
        </div>
        <div class="flex gap-2">
          <.link
            navigate={~p"/apps-support/app/#{@app.label}"}
            class="text-xs text-gray-400 hover:text-primary flex items-center gap-1 transition-colors"
          >
            <.dm_mdi name="headset" class="w-3.5 h-3.5" /> {dgettext("navigation", "Support")}
          </.link>
          <span class="text-gray-600">|</span>
          <.link
            navigate={~p"/apps-privacy/app/#{@app.label}"}
            class="text-xs text-gray-400 hover:text-primary flex items-center gap-1 transition-colors"
          >
            <.dm_mdi name="shield-lock-outline" class="w-3.5 h-3.5" /> {dgettext(
              "navigation",
              "Privacy"
            )}
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Store icon component based on store type.
  """
  attr(:type, :string, required: true)
  attr(:class, :string, default: "w-6 h-6")

  def store_icon(assigns) do
    ~H"""
    <%= case @type do %>
      <% "appstore" -> %>
        <.appstore_icon class={@class} />
      <% "playstore" -> %>
        <.playstore_icon class={@class} />
      <% "fdroid" -> %>
        <.fdroid_icon class={@class} />
      <% _ -> %>
        <.dm_mdi name="link" class={@class} />
    <% end %>
    """
  end

  @doc """
  Platform badge component for header using dm_badge.
  """
  attr(:name, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:color, :string, default: "primary")

  def platform_badge(assigns) do
    ~H"""
    <div class={[
      "badge badge-lg gap-2 platform-badge",
      "bg-white/90 text-gray-800 border-2 border-white/50 shadow-xl",
      "hover:scale-105 transition-transform duration-200 font-semibold"
    ]}>
      <.dm_mdi name={@icon} class="w-4 h-4" />
      {@name}
    </div>
    """
  end

  @doc """
  Platform chips for app cards using dm_chip.
  """
  attr(:platforms, :list, default: [])

  def platform_chips(assigns) do
    ~H"""
    <div class="flex gap-1">
      <.dm_chip
        :for={platform <- @platforms}
        size="sm"
        class={platform_chip_color(platform)}
      >
        {platform_icon(platform)} {String.upcase(platform)}
      </.dm_chip>
    </div>
    """
  end

  defp platform_chip_color("ios"), do: "bg-info text-info-content"
  defp platform_chip_color("android"), do: "bg-success text-success-content"
  defp platform_chip_color("macos"), do: "bg-warning text-warning-content"
  defp platform_chip_color("windows"), do: "bg-error text-error-content"
  defp platform_chip_color("linux"), do: "bg-neutral text-neutral-content"
  defp platform_chip_color(_), do: "bg-base-200 text-base-content"

  defp platform_icon("ios"), do: "🍎"
  defp platform_icon("android"), do: "🤖"
  defp platform_icon("macos"), do: "🍎"
  defp platform_icon("windows"), do: "🪟"
  defp platform_icon("linux"), do: "🐧"
  defp platform_icon(_), do: "📱"

  @doc """
  Hero section component for page headers.
  """
  @doc type: :component
  attr(:id, :any, default: false)
  attr(:class, :string, default: "")
  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)
  attr(:description, :string, default: nil)
  attr(:type, :string, default: "image", values: ["image", "gradient"])
  attr(:background, :string, default: nil)
  attr(:gradient_colors, :string, default: "from-black/50 to-black/80")
  attr(:min_height, :string, default: "min-h-screen")
  attr(:icon, :string, default: nil)
  attr(:cta, :string, default: nil)
  attr(:cta_link, :string, default: nil)

  slot(:inner_block, doc: "Custom content for the hero section")

  def hero_section(assigns) do
    ~H"""
    <div class={[
      "hero relative overflow-hidden",
      @min_height,
      hero_background_style(@type, @background, @gradient_colors),
      @class
    ]}>
      <div class={["hero-overlay bg-gradient-to-b", @gradient_colors]}></div>
      <div class="hero-content text-center text-neutral-content relative z-10">
        <div class="max-w-5xl px-4 sm:px-6 lg:px-8">
          <div class="animate-fade-in-down">
            <div :if={@icon} class="flex items-center justify-center mb-6">
              <div class="w-16 h-16 lg:w-20 lg:h-20 rounded-2xl bg-white/10 backdrop-blur-sm flex items-center justify-center border border-white/20">
                <.dm_mdi
                  name={@icon}
                  class="w-10 h-10 lg:w-12 lg:h-12 text-white drop-shadow-lg"
                />
              </div>
            </div>
            <h1 class={[
              "text-3xl sm:text-4xl md:text-5xl lg:text-7xl font-extrabold",
              "bg-gradient-to-r from-white via-amber-200 to-orange-300 bg-clip-text text-transparent text-shimmer",
              "leading-tight tracking-tight"
            ]}>
              {@title}
            </h1>
          </div>

          <div :if={@subtitle} class="animate-fade-in-up animation-delay-200 mt-6">
            <h2 class={[
              "mb-8 text-xl sm:text-2xl md:text-3xl lg:text-4xl font-semibold",
              "text-gray-200/90",
              "leading-relaxed"
            ]}>
              {@subtitle}
            </h2>
          </div>

          <div :if={@description} class="animate-fade-in animation-delay-400">
            <p class="mb-10 text-base sm:text-lg lg:text-xl text-gray-300/80 max-w-2xl mx-auto leading-relaxed">
              {@description}
            </p>
          </div>

          <div :if={@cta && @cta_link} class="animate-fade-in-scale animation-delay-500">
            <.dm_btn
              variant="primary"
              size="lg"
              class="btn-wide shadow-2xl hover:shadow-primary/25 hover:scale-105 transition-all duration-300"
            >
              <.link href={@cta_link} class="flex items-center gap-2">
                {@cta} <.dm_mdi name="arrow-right" class="w-5 h-5" />
              </.link>
            </.dm_btn>
          </div>

          {render_slot(@inner_block)}
        </div>
      </div>

      <div class="absolute bottom-8 left-1/2 animate-bounce-chevron">
        <a href="#page" class="block">
          <.dm_mdi
            name="chevron-double-down"
            class="w-8 h-8 text-white/50 hover:text-white/80 transition-colors"
          />
        </a>
      </div>
    </div>
    """
  end

  defp hero_background_style("image", background, _gradient),
    do: "style=\"background-image: url(#{background});\""

  defp hero_background_style("gradient", _background, gradient_colors),
    do: "bg-gradient-to-br #{gradient_colors}"

  @doc """
  Generates playstore_icon
  """
  @doc type: :component
  attr(:id, :any, default: false)
  attr(:class, :string, default: "")

  def playstore_icon(assigns) do
    ~H"""
    <svg
      id={@id}
      class={@class}
      fill="currentcolor"
      viewBox="0 0 256 256"
      id="Flat"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M223.63476,114.18213l-167.7832-96.04a15.98949,15.98949,0,0,0-16.123.0459,15.66312,15.66312,0,0,0-7.915,13.66846v192.2871a15.66312,15.66312,0,0,0,7.915,13.66846,15.98874,15.98874,0,0,0,16.12305.0459l167.7832-96.04a15.76194,15.76194,0,0,0,0-27.63574ZM144,139.31348l18.85644,18.85644L74.666,208.64746ZM74.65478,47.34082,162.85742,97.8291,144,116.68652ZM177.24707,149.93359,155.31348,128l21.93457-21.93408L215.56738,128Z" />
    </svg>
    """
  end

  @doc """
  Generates appstore_icon
  """
  @doc type: :component
  attr(:id, :any, default: false)
  attr(:class, :string, default: "")

  def appstore_icon(assigns) do
    ~H"""
    <svg
      id={@id}
      class={@class}
      fill="currentcolor"
      viewBox="0 0 512 512"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M256,32C132.26,32,32,132.26,32,256S132.26,480,256,480,480,379.74,480,256,379.74,32,256,32ZM171,353.89a15.48,15.48,0,0,1-13.46,7.65,14.91,14.91,0,0,1-7.86-2.16,15.48,15.48,0,0,1-5.6-21.21l15.29-25.42a8.73,8.73,0,0,1,7.54-4.3h2.26c11.09,0,18.85,6.67,21.11,13.13Zm129.45-50L200.32,304H133.77a15.46,15.46,0,0,1-15.51-16.15c.32-8.4,7.65-14.76,16-14.76h48.24l57.19-97.35h0l-18.52-31.55C217,137,218.85,127.52,226,123a15.57,15.57,0,0,1,21.87,5.17l9.9,16.91h.11l9.91-16.91A15.58,15.58,0,0,1,289.6,123c7.11,4.52,8.94,14,4.74,21.22l-18.52,31.55-18,30.69-39.09,66.66v.11h57.61c7.22,0,16.27,3.88,19.93,10.12l.32.65c3.23,5.49,5.06,9.26,5.06,14.75A13.82,13.82,0,0,1,300.48,303.92Zm77.75.11H351.09v.11l19.82,33.71a15.8,15.8,0,0,1-5.17,21.53,15.53,15.53,0,0,1-8.08,2.27A15.71,15.71,0,0,1,344.2,354l-29.29-49.86-18.2-31L273.23,233a38.35,38.35,0,0,1-.65-38c4.64-8.19,8.19-10.34,8.19-10.34L333,273h44.91c8.4,0,15.61,6.46,16,14.75A15.65,15.65,0,0,1,378.23,304Z" />
    </svg>
    """
  end

  @doc """
  Generates fdroid_icon
  """
  @doc type: :component
  attr(:id, :any, default: false)
  attr(:class, :string, default: "")

  def fdroid_icon(assigns) do
    ~H"""
    <svg
      id={@id}
      class={@class}
      fill="currentcolor"
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M20.472 10.081H3.528a1.59 1.59 0 0 0-1.589 1.589v10.59a1.59 1.59 0 0 0 1.589 1.589h16.944a1.59 1.59 0 0 0 1.589-1.589V11.67a1.59 1.59 0 0 0-1.589-1.589zM12 22.525c-3.066 0-5.56-2.494-5.56-5.56s2.494-5.56 5.56-5.56c3.066 0 5.56 2.494 5.56 5.56s-2.494 5.56-5.56 5.56zm0-10.114c-2.511 0-4.554 2.043-4.554 4.554S9.489 21.519 12 21.519s4.554-2.043 4.554-4.554-2.043-4.554-4.554-4.554zm0 7.863a3.322 3.322 0 0 1-3.221-2.568h1.67c.275.581.859.979 1.551.979.96 0 1.721-.761 1.721-1.721 0-.96-.761-1.721-1.721-1.721a1.7 1.7 0 0 0-1.493.874H8.805A3.322 3.322 0 0 1 12 13.655a3.321 3.321 0 0 1 3.309 3.309A3.321 3.321 0 0 1 12 20.274zM23.849.396l-.002.003-.006-.005.004-.004a.668.668 0 0 0-.519-.238.654.654 0 0 0-.512.259l-1.818 2.353a1.564 1.564 0 0 0-.523-.095H3.528c-.184 0-.358.038-.523.095L1.187.41A.657.657 0 0 0 .156.389L.16.393.153.399.151.396a.662.662 0 0 0-.012.824l1.909 2.471a1.587 1.587 0 0 0-.108.566v3.707a1.59 1.59 0 0 0 1.589 1.589h16.944a1.59 1.59 0 0 0 1.589-1.589V4.257c0-.2-.041-.39-.109-.566l1.909-2.471a.663.663 0 0 0-.013-.824zM6.904 8.228a1.787 1.787 0 1 1 0-3.574 1.787 1.787 0 0 1 0 3.574zm10.325 0a1.787 1.787 0 1 1 0-3.574 1.787 1.787 0 0 1 0 3.574z" />
    </svg>
    """
  end
end
