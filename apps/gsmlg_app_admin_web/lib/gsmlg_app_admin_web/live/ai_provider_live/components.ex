defmodule GsmlgAppAdminWeb.AiProviderLive.Components do
  @moduledoc """
  Shared components for the AI gateway module.

  Provides a sidebar navigation layout used by AI gateway sub-module pages.
  """

  use Phoenix.Component
  use PhoenixDuskmoon.Component
  use GsmlgAppAdminWeb, :verified_routes

  @menu_sections [
    %{
      label: nil,
      items: [
        %{path: "/chat", label: "AI Chat", icon: "chat-outline"},
        %{path: "/ai-provider/agents", label: "Agents", icon: "robot-outline"},
        %{path: "/ai-provider/config", label: "Config", icon: "cog-outline"}
      ]
    }
  ]

  attr :current_path, :string, required: true
  slot :inner_block, required: true

  def ai_provider_layout(assigns) do
    assigns = assign(assigns, :menu_sections, @menu_sections)

    ~H"""
    <div class="flex min-h-[calc(100vh-3.5rem)] w-full flex-col bg-surface text-on-surface md:flex-row">
      <nav class="w-full shrink-0 border-b border-outline-variant bg-secondary px-2 py-3 text-secondary-content md:w-56 md:border-b-0 md:border-r md:py-4">
        <.link
          navigate="/"
          class="mb-2 flex items-center gap-2 rounded-md px-3 py-2 text-sm text-secondary-content opacity-80 hover:bg-primary-container hover:text-on-primary-container hover:opacity-100"
        >
          <.dm_mdi name="arrow-left" class="w-4 h-4" /> Back to Home
        </.link>
        <h2 class="px-3 py-2 text-lg font-semibold text-secondary-content">AI Gateway</h2>
        <div :for={section <- @menu_sections} class="mb-2">
          <h3
            :if={section.label}
            class="px-3 py-1 text-xs font-semibold uppercase tracking-wider text-secondary-content opacity-70"
          >
            {section.label}
          </h3>
          <ul class="menu menu-sm gap-1">
            <li :for={item <- section.items}>
              <.link
                navigate={item.path}
                class={menu_item_class(item.path, @current_path)}
              >
                <.dm_mdi name={item.icon} class="w-4 h-4" />
                {item.label}
              </.link>
            </li>
          </ul>
        </div>
      </nav>
      <div class="min-w-0 flex-1 overflow-auto">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp menu_item_class(item_path, current_path) do
    if String.starts_with?(current_path, item_path) do
      "rounded-md bg-primary text-primary-content font-medium"
    else
      "rounded-md text-secondary-content hover:bg-primary-container hover:text-on-primary-container"
    end
  end
end
