defmodule GsmlgAppAdminWeb.Api.V1.MessagesController do
  @moduledoc """
  Anthropic-compatible Messages API endpoint.

  Handles `POST /api/v1/messages` with Anthropic Messages API request/response format.
  Supports both streaming (SSE with Anthropic event types) and non-streaming modes.
  """

  use GsmlgAppAdminWeb, :controller

  alias GsmlgAppAdmin.AI.Gateway
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  def create(conn, params) do
    api_key = conn.assigns.api_key

    unless ApiKeyAuth.has_scope?(api_key, :messages) do
      conn
      |> put_status(403)
      |> json(%{
        type: "error",
        error: %{type: "permission_error", message: "API key lacks 'messages' scope."}
      })
      |> halt()
    else
      normalized = normalize_anthropic_request(params)

      if normalized.stream do
        stream_response(conn, api_key, normalized)
      else
        non_stream_response(conn, api_key, normalized)
      end
    end
  end

  defp non_stream_response(conn, api_key, request) do
    case Gateway.chat(api_key, request) do
      {:ok, response} ->
        json(conn, format_anthropic_response(response, request.model))

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{
          type: "error",
          error: %{type: "api_error", message: to_string(reason)}
        })
    end
  end

  defp stream_response(conn, api_key, request) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    msg_id = "msg_#{generate_id()}"
    parent = self()

    # Send message_start
    message_start = %{
      type: "message_start",
      message: %{
        id: msg_id,
        type: "message",
        role: "assistant",
        content: [],
        model: request.model,
        stop_reason: nil,
        usage: %{input_tokens: 0, output_tokens: 0}
      }
    }

    conn =
      case send_sse(conn, "message_start", message_start) do
        {:ok, conn} -> conn
        {:error, _} -> conn
      end

    # Send content_block_start
    block_start = %{
      type: "content_block_start",
      index: 0,
      content_block: %{type: "text", text: ""}
    }

    conn =
      case send_sse(conn, "content_block_start", block_start) do
        {:ok, conn} -> conn
        {:error, _} -> conn
      end

    callback = fn
      {:content, content} ->
        delta = %{
          type: "content_block_delta",
          index: 0,
          delta: %{type: "text_delta", text: content}
        }

        send(parent, {:sse_event, "content_block_delta", delta})

      {:thinking, content} ->
        delta = %{
          type: "content_block_delta",
          index: 0,
          delta: %{type: "thinking_delta", thinking: content}
        }

        send(parent, {:sse_event, "content_block_delta", delta})
    end

    opts = [stream_callback: callback]

    Task.start(fn ->
      result = Gateway.chat(api_key, request, opts)
      send(parent, {:stream_done, result})
    end)

    anthropic_stream_loop(conn, msg_id, request.model)
  end

  defp anthropic_stream_loop(conn, msg_id, model) do
    receive do
      {:sse_event, event_type, data} ->
        case send_sse(conn, event_type, data) do
          {:ok, conn} -> anthropic_stream_loop(conn, msg_id, model)
          {:error, _} -> conn
        end

      {:stream_done, _result} ->
        # Send content_block_stop
        conn =
          case send_sse(conn, "content_block_stop", %{type: "content_block_stop", index: 0}) do
            {:ok, conn} -> conn
            {:error, _} -> conn
          end

        # Send message_delta with stop_reason
        message_delta = %{
          type: "message_delta",
          delta: %{stop_reason: "end_turn"},
          usage: %{output_tokens: 0}
        }

        conn =
          case send_sse(conn, "message_delta", message_delta) do
            {:ok, conn} -> conn
            {:error, _} -> conn
          end

        # Send message_stop
        case send_sse(conn, "message_stop", %{type: "message_stop"}) do
          {:ok, conn} -> conn
          {:error, _} -> conn
        end
    after
      120_000 ->
        conn
    end
  end

  defp send_sse(conn, event_type, data) do
    chunk_data = "event: #{event_type}\ndata: #{Jason.encode!(data)}\n\n"
    Plug.Conn.chunk(conn, chunk_data)
  end

  defp normalize_anthropic_request(params) do
    system = params["system"]

    messages =
      (params["messages"] || [])
      |> Enum.map(fn msg ->
        content =
          case msg["content"] do
            text when is_binary(text) -> text
            blocks when is_list(blocks) -> extract_text_from_blocks(blocks)
            _ -> ""
          end

        %{role: safe_role(msg["role"]), content: content}
      end)

    %{
      model: params["model"] || "claude-sonnet-4-20250514",
      system: system,
      messages: messages,
      stream: params["stream"] == true,
      params: %{
        temperature: params["temperature"],
        max_tokens: params["max_tokens"] || 4096,
        top_p: params["top_p"]
      }
    }
  end

  defp safe_role(role) when role in ~w(user assistant tool), do: String.to_existing_atom(role)
  defp safe_role(_), do: :user

  defp extract_text_from_blocks(blocks) do
    blocks
    |> Enum.filter(fn block -> block["type"] == "text" end)
    |> Enum.map_join("\n", fn block -> block["text"] || "" end)
  end

  defp format_anthropic_response(response, model) do
    %{
      id: "msg_#{generate_id()}",
      type: "message",
      role: "assistant",
      content: [
        %{type: "text", text: response.content}
      ],
      model: model,
      stop_reason: "end_turn",
      usage: format_anthropic_usage(response[:usage])
    }
  end

  defp format_anthropic_usage(nil), do: %{input_tokens: 0, output_tokens: 0}

  defp format_anthropic_usage(usage) do
    %{
      input_tokens: usage["prompt_tokens"] || usage[:prompt_tokens] || 0,
      output_tokens: usage["completion_tokens"] || usage[:completion_tokens] || 0
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end
end
