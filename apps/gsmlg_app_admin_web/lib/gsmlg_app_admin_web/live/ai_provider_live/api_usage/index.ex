defmodule GsmlgAppAdminWeb.AiProviderLive.ApiUsage.Index do
  @moduledoc "LiveView for viewing AI gateway API usage logs."
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, logs} = AI.list_recent_usage_logs()
    summary = AI.usage_summary(logs)
    {:ok, assign(socket, logs: logs, summary: summary, page_title: "API Usage")}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_uri, URI.parse(url).path)}
  end
end
