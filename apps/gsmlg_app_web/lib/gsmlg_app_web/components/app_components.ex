defmodule GsmlgAppWeb.AppComponents do
  @moduledoc """
  Provides APP UI components.

  """
  use Phoenix.Component
  use PhoenixDuskmoon.Component

  alias Phoenix.LiveView.JS
  import GsmlgAppWeb.Gettext

  use GsmlgAppWeb, :verified_routes

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

  @doc """
  Generates app section
  ## Example
      <.app_section name="appname" icon_path="app-icon-url">
        <:description>
          ...description
        </:description>
        <:store_link link={play_store_link}>
          <.playstore_icon name="android" class="w-8 h-8" />
        </:store_link>
      </.app_section>
  """
  @doc type: :component
  attr(:id, :any,
    default: false,
    doc: """
    html attribute id
    """
  )

  attr(:class, :string,
    default: "",
    doc: """
    html attribute class
    """
  )

  attr(:icon_path, :string,
    doc: """
    App Icon image path
    """
  )

  attr(:name, :string,
    doc: """
    App name
    """
  )

  attr(:app_label, :string,
    default: "",
    doc: """
    App label for url
    """
  )

  slot(:description,
    required: true,
    doc: """
    App description
    """
  )

  slot(:store_link,
    required: false,
    doc: """
    App Store link
    """
  ) do
    attr(:link, :string,
      doc: """
      App Store link
      """
    )
  end

  def app_section(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "w-full py-12",
        "bg-black text-neutral-400",
        "flex justify-center",
        @class
      ]}
    >
      <div class="container">
        <div class={[
          "w-full p-8",
          "flex flex-col justify-center items-center gap-4"
        ]}>
          <div class="w-full flex flex-col md:flex-row items-center justify-center gap-4 md:gap-24">
            <div class="w-1/4 flex flex-col grow-0 shrink-0">
              <img class="aspect-square rounded-[25%] w-[clamp(5rem,25vw,20rem)]" src={@icon_path} />
            </div>
            <div class="w-3/4 flex flex-col gap-4 text-neutral-400">
              <h3 class="text-4xl font-bold mb-4 text-[goldenrod]">
                {@name}
              </h3>
              <p :for={d <- @description} class="text-2xl animated-text-gradient">
                {render_slot(d)}
              </p>
              <div class="flex items-center gap-8">
                <span class="flex text-xl after:content-[':']">
                  App Store Link
                </span>
                <.link
                  :for={store <- @store_link}
                  class="inline-flex color-carousel hover:animate-bounce"
                  target="_blank"
                  href={Map.get(store, :link, "javascript:void(0)")}
                  disabled={!Map.has_key?(%{}, :link)}
                >
                  {render_slot(store)}
                </.link>
              </div>
              <div class="flex items-center gap-8">
                <.link
                  class="inline-flex items-center gap-2 hover:scale-125 transition-transform text-blue-400"
                  navigate={~p"/apps-support/app/#{@app_label}"}
                >
                  <.dm_mdi name="headset" class="w-4 h-4" /> Support
                </.link>
                <.link
                  class="inline-flex items-center gap-2 hover:scale-125 transition-transform text-blue-400"
                  navigate={~p"/apps-privacy/app/#{@app_label}"}
                >
                  <.dm_mdi name="shield-lock-outline" class="w-4 h-4" /> Privacy Policy
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Generates playstore_icon
  ## Example
      <.playstore_icon class="w-6 h-6" />
  """
  @doc type: :component
  attr(:id, :any,
    default: false,
    doc: """
    html attribute id
    """
  )

  attr(:class, :string,
    default: "",
    doc: """
    html attribute class
    """
  )

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
  ## Example
      <.appstore_icon class="w-6 h-6" />
  """
  @doc type: :component
  attr(:id, :any,
    default: false,
    doc: """
    html attribute id
    """
  )

  attr(:class, :string,
    default: "",
    doc: """
    html attribute class
    """
  )

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
  ## Example
      <.fdroid_icon class="w-6 h-6" />
  """
  @doc type: :component
  attr(:id, :any,
    default: false,
    doc: """
    html attribute id
    """
  )

  attr(:class, :string,
    default: "",
    doc: """
    html attribute class
    """
  )

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
