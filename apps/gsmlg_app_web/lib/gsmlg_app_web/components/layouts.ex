defmodule GsmlgAppWeb.Layouts do
  use GsmlgAppWeb, :html

  embed_templates "layouts/*"

  slot :header_slot
  slot :inner_block, required: true

  attr :flash, :map, required: true

  def app(assigns) do
    ~H"""
    <.dm_page_header
      class={[
        "bg-gradient-to-br from-slate-700 to-neutral-700",
        "text-slate-400",
        "h-fit"
      ]}
      nav_class={[
        "bg-black text-slate-400"
      ]}
    >
      <:menu to="/">
        Home
      </:menu>
      <:menu class="border-b-2 text-slate-200 border-slate-200" to="/apps">
        Apps
      </:menu>
      <:user_profile></:user_profile>
      {render_slot(@header_slot)}
    </.dm_page_header>
    <main class={[
      "flex flex-col",
      "min-h-[calc(100vh-50%)] w-full"
    ]}>
      <div class={[
        "w-full min-w-full min-h-full",
        "mx-auto max-w-2xl",
        "flex flex-col items-center"
      ]}>
        <.flash_group flash={@flash} />
        <a name="page"></a>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.app_footer />
    """
  end

  slot :header_slot
  slot :inner_block, required: true

  attr :flash, :map, required: true

  def home(assigns) do
    ~H"""
    <.dm_page_header
      class={[
        "bg-gradient-to-br from-slate-700 to-neutral-700",
        "text-slate-400",
        "bg-[url(/images/sky-commet.jpg)] bg-no-repeat bg-cover",
        "h-screen"
      ]}
      nav_class={[
        "bg-black text-slate-400"
      ]}
    >
      <:menu class="border-b-2 text-slate-200 border-slate-200" to="/">
        Home
      </:menu>
      <:menu to="/apps">
        Apps
      </:menu>
      <:user_profile></:user_profile>
      {render_slot(@header_slot)}
    </.dm_page_header>
    <main class={[
      "flex flex-col",
      "min-h-[calc(100vh-50%)] w-full"
    ]}>
      <div class={[
        "w-full min-w-full min-h-full",
        "mx-auto max-w-2xl",
        "flex flex-col items-center"
      ]}>
        <.flash_group flash={@flash} />
        <a name="page"></a>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.app_footer />
    """
  end

  slot :inner_block, required: true

  attr :flash, :map, required: true

  def support(assigns) do
    ~H"""
    <.dm_page_header
      class={[
        "bg-gradient-to-br from-slate-700 to-neutral-700",
        "text-slate-400",
        "h-fit"
      ]}
      nav_class={[
        "bg-black text-slate-400"
      ]}
    >
      <:menu to="/">
        Home
      </:menu>
      <:menu class="border-b-2 text-slate-200 border-slate-200" to="/apps">
        Apps
      </:menu>
      <:user_profile></:user_profile>
      <div class={[
        "container select-none py-32",
        "flex flex-col justify-center items-center gap-12"
      ]}>
        <div
          class={[
            "my-4",
            "flex flex-row items-center justify-center",
            "text-4xl lg:text-6xl xl:text-8xl text-teal-300 drop-shadow-md font-bold text-center"
          ]}
          style="text-shadow: 0px 0px 8px #000"
        >
          <.dm_mdi
            name="headset"
            class="w-12 h-12 lg:w-16 lg:h-16 xl:w-24 xl:h-24 mr-2 lg:mr-4 xl:mr-6"
          /> Support
        </div>
      </div>
    </.dm_page_header>
    <main class={[
      "flex flex-col",
      "min-h-[20vh] w-full"
    ]}>
      <div class={[
        "w-full min-w-full min-h-full",
        "mx-auto max-w-2xl",
        "flex flex-col items-center"
      ]}>
        <.flash_group flash={@flash} />
        <a name="page"></a>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.app_footer />
    """
  end

  slot :inner_block, required: true

  attr :flash, :map, required: true

  def privacy(assigns) do
    ~H"""
    <.dm_page_header
      class={[
        "bg-gradient-to-br from-slate-700 to-neutral-700",
        "text-slate-400",
        "h-fit"
      ]}
      nav_class={[
        "bg-black text-slate-400"
      ]}
    >
      <:menu to="/">
        Home
      </:menu>
      <:menu class="border-b-2 text-slate-200 border-slate-200" to="/apps">
        Apps
      </:menu>
      <:user_profile></:user_profile>
      <div class={[
        "container select-none py-32",
        "flex flex-col justify-center items-center gap-12"
      ]}>
        <div
          class={[
            "my-4",
            "flex flex-row items-center justify-center",
            "text-4xl lg:text-6xl xl:text-8xl text-teal-300 drop-shadow-md font-bold text-center"
          ]}
          style="text-shadow: 0px 0px 8px #000"
        >
          <.dm_mdi
            name="shield-lock-outline"
            class="w-12 h-12 lg:w-16 lg:h-16 xl:w-24 xl:h-24 mr-2 lg:mr-4 xl:mr-6"
          /> Privacy Policy
        </div>
      </div>
    </.dm_page_header>
    <main class={[
      "flex flex-col",
      "min-h-[20vh] w-full"
    ]}>
      <div class={[
        "w-full min-w-full min-h-full",
        "mx-auto max-w-2xl",
        "flex flex-col items-center"
      ]}>
        <.flash_group flash={@flash} />
        <a name="page"></a>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.app_footer />
    """
  end
end
