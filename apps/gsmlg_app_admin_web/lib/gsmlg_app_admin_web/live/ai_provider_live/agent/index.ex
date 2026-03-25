defmodule GsmlgAppAdminWeb.AiProviderLive.Agent.Index do
  @moduledoc "LiveView for managing AI agents."
  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, agents} = AI.list_agents()
    {:ok, assign(socket, agents: agents)}
  end

  @impl true
  def handle_params(params, url, socket) do
    socket = assign(socket, :current_uri, URI.parse(url).path)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New Agent", agent: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    assign(socket, page_title: "Edit Agent", agent: AI.get_agent!(id))
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Agents", agent: nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    agent = AI.get_agent!(id)

    case AI.delete_agent(agent) do
      :ok ->
        {:ok, agents} = AI.list_agents()
        {:noreply, assign(socket, agents: agents) |> put_flash(:info, "Agent deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete agent.")}
    end
  end

  @impl true
  def handle_info({GsmlgAppAdminWeb.AiProviderLive.Agent.FormComponent, {:saved, _}}, socket) do
    {:ok, agents} = AI.list_agents()
    {:noreply, assign(socket, agents: agents)}
  end
end
