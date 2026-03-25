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

      cond do
        is_nil(params["model"]) or params["model"] == "" ->
          conn
          |> put_status(400)
          |> json(%{
            error: %{
              message: "model is required.",
              type: "invalid_request_error"
            }
          })

        normalized.messages == [] ->
          conn
          |> put_status(400)
          |> json(%{
            error: %{
              message: "messages is required and must be non-empty.",
              type: "invalid_request_error"
            }
          })

        normalized.stream ->
          stream_response(conn, api_key, normalized)

        true ->
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

      {:error, "No provider found" <> _ = reason} ->
        conn
        |> put_status(422)
        |> json(%{error: %{message: reason, type: "invalid_request_error"}})

      {:error, "API key does not have" <> _ = reason} ->
        conn
        |> put_status(403)
        |> json(%{error: %{message: reason, type: "permission_error"}})

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

    task =
      Task.async(fn ->
        Gateway.chat(api_key, request, opts)
      end)

    stream_loop(conn, task, id, created, request.model)
  end

  # Dialyzer warns about Task.ref() being opaque — this is a known limitation
  @dialyzer {:nowarn_function, stream_loop: 5}
  defp stream_loop(conn, %Task{ref: ref} = task, id, created, model) do
    receive do
      {:sse_chunk, chunk} ->
        case Plug.Conn.chunk(conn, "data: #{Jason.encode!(chunk)}\n\n") do
          {:ok, conn} -> stream_loop(conn, task, id, created, model)
          {:error, _} -> shutdown_task(task, conn)
        end

      {^ref, _result} ->
        Process.demonitor(ref, [:flush])
        send_finish_chunk(conn, id, created, model)

      {:DOWN, ^ref, :process, _pid, _reason} ->
        send_finish_chunk(conn, id, created, model)
    after
      120_000 ->
        shutdown_task(task, conn)
    end
  end

  defp send_finish_chunk(conn, id, created, model) do
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
  end

  defp shutdown_task(task, conn) do
    Task.shutdown(task, :brutal_kill)
    conn
  end

  defp normalize_openai_request(params) do
    messages = params["messages"] || []

    {system, user_messages} =
      Enum.reduce(messages, {nil, []}, fn msg, {sys, msgs} ->
        case msg["role"] do
          "system" ->
            content = msg["content"] || ""
            combined = if sys, do: sys <> "\n" <> content, else: content
            {combined, msgs}

          _ ->
            {sys,
             msgs ++
               [%{role: RequestHelpers.safe_role(msg["role"]), content: msg["content"] || ""}]}
        end
      end)

    request = %{
      model: params["model"],
      system: system,
      messages: user_messages,
      stream: params["stream"] == true,
      params: %{
        temperature: params["temperature"],
        max_tokens: params["max_tokens"],
        top_p: params["top_p"]
      }
    }

    # Pass through client-provided tools for function calling
    request =
      case params["tools"] do
        tools when is_list(tools) and tools != [] -> Map.put(request, :tools, tools)
        _ -> request
      end

    case params["tool_choice"] do
      nil -> request
      choice -> Map.put(request, :tool_choice, choice)
    end
  end

  defp format_openai_response(response, model) do
    tool_calls = response[:tool_calls] || []

    message =
      %{role: "assistant", content: response.content}
      |> then(fn msg ->
        if tool_calls != [], do: Map.put(msg, :tool_calls, tool_calls), else: msg
      end)

    finish_reason = if tool_calls != [], do: "tool_calls", else: "stop"

    %{
      id: "chatcmpl-#{generate_id()}",
      object: "chat.completion",
      created: System.system_time(:second),
      model: model,
      choices: [
        %{
          index: 0,
          message: message,
          finish_reason: finish_reason
        }
      ],
      usage: response[:usage] || %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end
end
