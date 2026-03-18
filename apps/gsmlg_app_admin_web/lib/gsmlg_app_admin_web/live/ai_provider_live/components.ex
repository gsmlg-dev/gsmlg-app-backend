defmodule GsmlgAppAdminWeb.AiProviderLive.Components do
  @moduledoc """
  Shared components for the AI Provider module.

  Provides a sidebar navigation layout used by all AI Provider sub-module pages.
  """

  use Phoenix.Component
  use PhoenixDuskmoon.Component
  use GsmlgAppAdminWeb, :verified_routes

  @menu_items [
    %{path: "/ai-provider/providers", label: "Providers", icon: "chip"},
    %{path: "/ai-provider/api-keys", label: "API Keys", icon: "key-variant"},
    %{path: "/ai-provider/system-prompts", label: "System Prompts", icon: "text-box-outline"},
    %{path: "/ai-provider/memories", label: "Memories", icon: "brain"},
    %{path: "/ai-provider/tools", label: "Tools", icon: "wrench-outline"},
    %{path: "/ai-provider/agents", label: "Agents", icon: "robot-outline"},
    %{path: "/ai-provider/mcp-servers", label: "MCP Servers", icon: "server-outline"},
    %{path: "/ai-provider/usage", label: "API Usage", icon: "chart-bar"}
  ]

  attr :current_path, :string, required: true
  slot :inner_block, required: true

  def ai_provider_layout(assigns) do
    assigns = assign(assigns, :menu_items, @menu_items)

    ~H"""
    <div class="flex w-full min-h-[calc(100vh-3.5rem)]">
      <nav class="w-56 shrink-0 bg-base-200 border-r border-base-300 py-4 px-2">
        <.link navigate="/" class="flex items-center gap-2 px-3 py-2 mb-2 text-sm text-base-content/60 hover:text-base-content">
          <.dm_mdi name="arrow-left" class="w-4 h-4" /> Back to Home
        </.link>
        <h2 class="px-3 py-2 text-lg font-semibold">AI Provider</h2>
        <ul class="menu menu-sm gap-1">
          <li :for={item <- @menu_items}>
            <.link
              navigate={item.path}
              class={menu_item_class(item.path, @current_path)}
            >
              <.dm_mdi name={item.icon} class="w-4 h-4" />
              {item.label}
            </.link>
          </li>
        </ul>
      </nav>
      <div class="flex-1 overflow-auto">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp menu_item_class(item_path, current_path) do
    if String.starts_with?(current_path, item_path) do
      "active font-medium"
    else
      ""
    end
  end
end
