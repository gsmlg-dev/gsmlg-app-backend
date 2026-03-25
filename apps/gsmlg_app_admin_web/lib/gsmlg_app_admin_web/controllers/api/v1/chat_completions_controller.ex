defmodule GsmlgAppAdminWeb.Api.V1.ChatCompletionsController do
  @moduledoc """
  OpenAI-compatible chat completions endpoint.

  Handles `POST /api/v1/chat/completions` with standard OpenAI request/response format.
  Supports both streaming (SSE) and non-streaming modes.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    if ApiKeyAuth.has_scope?(api_key, :chat_completions) do
      normalized = normalize_openai_request(params)

      if normalized.stream do
        stream_response(conn, api_key, normalized)
      else
        non_stream_response(conn, api_key, normalized)
      end
    else
      conn
      |> put_status(403)
      |> json(%{
        error: %{message: "API key lacks 'chat_completions' scope.", type: "permission_error"}
      })
      |> halt()
    end
  end

  defp non_stream_response(conn, api_key, request) do
    case Gateway.chat(api_key, request) do
      {:ok, response} ->
        json(conn, format_openai_response(response, request.model))

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: %{message: to_string(reason), type: "server_error"}})
    end
  end

  defp stream_response(conn, api_key, request) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    id = "chatcmpl-#{generate_id()}"
    created = System.system_time(:second)

    parent = self()

    callback = fn
      {:content, content} ->
        chunk = %{
          id: id,
          object: "chat.completion.chunk",
          created: created,
          model: request.model,
          choices: [
            %{
              index: 0,
              delta: %{content: content},
              finish_reason: nil
            }
          ]
        }

        send(parent, {:sse_chunk, chunk})

      {:thinking, content} ->
        chunk = %{
          id: id,
          object: "chat.completion.chunk",
          created: created,
          model: request.model,
          choices: [
            %{
              index: 0,
              delta: %{reasoning_content: content},
              finish_reason: nil
            }
          ]
        }

        send(parent, {:sse_chunk, chunk})
    end

    opts = [stream_callback: callback]

    Task.start(fn ->
      result = Gateway.chat(api_key, request, opts)
      send(parent, {:stream_done, result})
    end)

    stream_loop(conn, id, created, request.model)
  end

  defp stream_loop(conn, id, created, model) do
    receive do
      {:sse_chunk, chunk} ->
        case Plug.Conn.chunk(conn, "data: #{Jason.encode!(chunk)}\n\n") do
          {:ok, conn} -> stream_loop(conn, id, created, model)
          {:error, _} -> conn
        end

      {:stream_done, _result} ->
        # Send finish chunk
        finish_chunk = %{
          id: id,
          object: "chat.completion.chunk",
          created: created,
          model: model,
          choices: [
            %{
              index: 0,
              delta: %{},
              finish_reason: "stop"
            }
          ]
        }

        case Plug.Conn.chunk(conn, "data: #{Jason.encode!(finish_chunk)}\n\n") do
          {:ok, conn} ->
            Plug.Conn.chunk(conn, "data: [DONE]\n\n")
            conn

          {:error, _} ->
            conn
        end
    after
      120_000 ->
        conn
    end
  end

  defp normalize_openai_request(params) do
    messages = params["messages"] || []

    {system, user_messages} =
      Enum.reduce(messages, {nil, []}, fn msg, {sys, msgs} ->
        case msg["role"] do
          "system" ->
            content = msg["content"]
            combined = if sys, do: sys <> "\n" <> content, else: content
            {combined, msgs}

          _ ->
            {sys,
             msgs ++ [%{role: RequestHelpers.safe_role(msg["role"]), content: msg["content"]}]}
        end
      end)

    %{
      model: params["model"] || "gpt-4o",
      system: system,
      messages: user_messages,
      stream: params["stream"] == true,
      params: %{
        temperature: params["temperature"],
        max_tokens: params["max_tokens"],
        top_p: params["top_p"]
      }
    }
  end

  defp format_openai_response(response, model) do
    %{
      id: "chatcmpl-#{generate_id()}",
      object: "chat.completion",
      created: System.system_time(:second),
      model: model,
      choices: [
        %{
          index: 0,
          message: %{
            role: "assistant",
            content: response.content
          },
          finish_reason: "stop"
        }
      ],
      usage: response[:usage] || %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end
end
