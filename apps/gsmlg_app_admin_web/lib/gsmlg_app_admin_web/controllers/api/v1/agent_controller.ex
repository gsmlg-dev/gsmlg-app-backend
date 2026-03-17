defmodule GsmlgAppAdminWeb.Api.V1.AgentController do
  @moduledoc """
  Agent API endpoints.

  Handles agent discovery, detail, tools listing, and chat invocation.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def index(conn, _params) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :agents) do
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
    else
      case AI.list_active_agents() do
        {:ok, agents} ->
          data =
            Enum.map(agents, fn agent ->
              %{
                slug: agent.slug,
                name: agent.name,
                description: agent.description,
                model: agent.model,
                max_iterations: agent.max_iterations
              }
            end)

          json(conn, %{data: data})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: %{message: to_string(reason), type: "server_error"}})
      end
    end
  end

  def show(conn, %{"agent_slug" => slug}) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :agents) do
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
    else
      case AI.get_agent_by_slug(slug) do
        {:ok, agent} ->
          json(conn, %{
            slug: agent.slug,
            name: agent.name,
            description: agent.description,
            model: agent.model,
            max_iterations: agent.max_iterations,
            tool_choice: agent.tool_choice,
            model_params: agent.model_params
          })

        {:error, _} ->
          conn
          |> put_status(404)
          |> json(%{error: %{message: "Agent not found.", type: "not_found_error"}})
      end
    end
  end

  def tools(conn, %{"agent_slug" => slug}) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :agents) do
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
    else
      case AI.get_agent_by_slug(slug) do
        {:ok, agent} ->
          case AI.list_tools_for_agent(agent.id) do
            {:ok, tools} ->
              data =
                Enum.map(tools, fn tool ->
                  %{
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.parameters_schema
                  }
                end)

              json(conn, %{data: data})

            {:error, _} ->
              json(conn, %{data: []})
          end

        {:error, _} ->
          conn
          |> put_status(404)
          |> json(%{error: %{message: "Agent not found.", type: "not_found_error"}})
      end
    end
  end

  def chat(conn, %{"agent_slug" => slug} = params) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :agents) do
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
    else
      case AI.get_agent_by_slug(slug) do
        {:ok, agent} ->
          messages =
            (params["messages"] || [])
            |> Enum.map(fn msg ->
              %{role: String.to_atom(msg["role"]), content: msg["content"]}
            end)

          stream = params["stream"] == true
          model = params["model"] || agent.model
          max_iter = min(params["max_iterations"] || agent.max_iterations, agent.max_iterations)

          opts = [
            stream: stream,
            model: model,
            max_iterations: max_iter,
            request_ip: get_client_ip(conn)
          ]

          case Gateway.run_agent(api_key, agent, messages, opts) do
            {:ok, result} ->
              json(conn, result)

            {:error, reason} ->
              conn
              |> put_status(500)
              |> json(%{error: %{message: to_string(reason), type: "server_error"}})
          end

        {:error, _} ->
          conn
          |> put_status(404)
          |> json(%{error: %{message: "Agent not found.", type: "not_found_error"}})
      end
    end
  end

  defp get_client_ip(conn) do
    conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
  end
end
