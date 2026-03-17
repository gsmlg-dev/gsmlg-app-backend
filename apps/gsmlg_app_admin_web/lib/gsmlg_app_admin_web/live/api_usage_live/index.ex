defmodule GsmlgAppAdminWeb.ApiUsageLive.Index do
  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, logs} = AI.list_recent_usage_logs()
    {:ok, assign(socket, logs: logs, page_title: "API Usage")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">API Usage Logs</h1>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-sm w-full">
          <thead>
            <tr>
              <th>Time</th>
              <th>Endpoint</th>
              <th>Model</th>
              <th>Tokens</th>
              <th>Duration</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={log <- @logs} id={"log-#{log.id}"}>
              <td class="text-xs">{Calendar.strftime(log.created_at, "%Y-%m-%d %H:%M:%S")}</td>
              <td><span class="badge badge-sm badge-outline">{log.endpoint_type}</span></td>
              <td class="text-sm">{log.model}</td>
              <td class="text-sm">
                <span class="opacity-70">{log.prompt_tokens}+{log.completion_tokens}=</span>{log.total_tokens}
              </td>
              <td class="text-sm">
                {if log.duration_ms, do: "#{log.duration_ms}ms", else: "-"}
              </td>
              <td>
                <span class={[
                  "badge badge-sm",
                  case log.status do
                    :success -> "badge-success"
                    :error -> "badge-error"
                    :rate_limited -> "badge-warning"
                    _ -> ""
                  end
                ]}>
                  {log.status}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@logs == []} class="text-center py-8 opacity-50">
        No usage logs yet.
      </div>
    </div>
    """
  end
end
