defmodule GsmlgAppAdminWeb.Api.V1.AgentController do
  @moduledoc """
  Agent API endpoints.

  Handles agent discovery, detail, tools listing, and chat invocation.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def index(conn, _params) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :agents) do
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
          require Logger
          Logger.error("Agent list error: #{inspect(reason)}")

          conn
          |> put_status(500)
          |> json(%{error: %{message: "An internal error occurred.", type: "server_error"}})
      end
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
      |> halt()
    end
  end

  def show(conn, %{"agent_slug" => slug}) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :agents) do
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
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
      |> halt()
    end
  end

  def tools(conn, %{"agent_slug" => slug}) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :agents) do
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
    else
      conn
      |> put_status(403)
      |> json(%{error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}})
      |> halt()
    end
  end

  def chat(conn, %{"agent_slug" => slug} = params) do
    api_key = conn.assigns.api_key
    raw_messages = params["messages"] || []

    cond do
      not ApiKeyAuth.has_scope?(api_key, :agents) ->
        conn
        |> put_status(403)
        |> json(%{
          error: %{message: "API key lacks 'agents' scope.", type: "permission_error"}
        })
        |> halt()

      raw_messages == [] ->
        conn
        |> put_status(400)
        |> json(%{
          error: %{
            message: "messages is required and must be non-empty.",
            type: "invalid_request_error"
          }
        })

      true ->
        run_agent_chat(conn, api_key, slug, params, raw_messages)
    end
  end

  defp run_agent_chat(conn, api_key, slug, params, raw_messages) do
    case AI.get_agent_by_slug(slug) do
      {:ok, agent} ->
        {messages, caller_system} = normalize_agent_messages(raw_messages)

        opts = [
          stream: params["stream"] == true,
          model: params["model"] || agent.model,
          max_iterations:
            min(params["max_iterations"] || agent.max_iterations, agent.max_iterations),
          caller_system: caller_system,
          request_ip: RequestHelpers.client_ip(conn)
        ]

        case Gateway.run_agent(api_key, agent, messages, opts) do
          {:ok, result} ->
            json(conn, result)

          {:error, "No provider found" <> _ = reason} ->
            conn
            |> put_status(422)
            |> json(%{error: %{message: reason, type: "invalid_request_error"}})

          {:error, "Agent reached maximum" <> _ = reason} ->
            conn
            |> put_status(422)
            |> json(%{error: %{message: reason, type: "invalid_request_error"}})

          {:error, "API key does not have" <> _ = reason} ->
            conn
            |> put_status(403)
            |> json(%{error: %{message: reason, type: "permission_error"}})

          {:error, reason} ->
            require Logger
            Logger.error("Agent chat error: #{inspect(reason)}")

            conn
            |> put_status(500)
            |> json(%{error: %{message: "An internal error occurred.", type: "server_error"}})
        end

      {:error, _} ->
        conn
        |> put_status(404)
        |> json(%{error: %{message: "Agent not found.", type: "not_found_error"}})
    end
  end

  defp normalize_agent_messages(raw_messages) do
    {system_parts, user_msgs} =
      Enum.reduce(raw_messages, {[], []}, fn msg, {sys, msgs} ->
        case msg["role"] do
          "system" ->
            {[msg["content"] || "" | sys], msgs}

          _ ->
            normalized = %{
              role: RequestHelpers.safe_role(msg["role"]),
              content: msg["content"] || ""
            }

            {sys, [normalized | msgs]}
        end
      end)

    caller_system =
      case Enum.reverse(system_parts) do
        [] -> nil
        parts -> Enum.join(parts, "\n")
      end

    {Enum.reverse(user_msgs), caller_system}
  end
end
