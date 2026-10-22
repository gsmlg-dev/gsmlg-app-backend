defmodule GsmlgAppAdminWeb.SseServerIntegrationTest do
  use GsmlgAppAdmin.DataCase, async: false

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.ApiKey
  alias GsmlgAppAdminWeb.Endpoint

  @moduletag capture_log: true
  @request_timeout 500
  @event_interval 200
  @event_count 9

  defmodule Backplane do
    @behaviour Plug

    def init(options), do: options

    def call(conn, options) do
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      request = Jason.decode!(body)
      send(options[:observer], {:backplane_request, conn.request_path, request["stream"]})

      if request["stream"] do
        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.send_chunked(200)

        Enum.reduce_while(1..options[:event_count], conn, fn index, conn ->
          Process.sleep(options[:event_interval])
          token = "token-#{index}"

          event =
            case conn.request_path do
              "/v1/chat/completions" ->
                "data: #{Jason.encode!(%{choices: [%{delta: %{content: token}}]})}\n\n"

              "/v1/messages" ->
                "event: content_block_delta\ndata: #{Jason.encode!(%{type: "content_block_delta", index: 0, delta: %{type: "text_delta", text: token}})}\n\n"
            end

          case Plug.Conn.chunk(conn, event) do
            {:ok, conn} -> {:cont, conn}
            {:error, _reason} -> {:halt, conn}
          end
        end)
      else
        Process.sleep(options[:event_count] * options[:event_interval])

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{choices: [%{message: %{content: "late response"}}]})
        )
      end
    end
  end

  setup do
    upstream =
      start_supervised!(
        {Gaoxy.HTTP,
         plug:
           {Backplane,
            observer: self(), event_count: @event_count, event_interval: @event_interval},
         ip: {127, 0, 0, 1},
         port: 0}
      )

    assert %{local: {:ok, {{127, 0, 0, 1}, upstream_port}}} = Gaoxy.info(upstream, :http)

    {:ok, _config} =
      AI.upsert_backplane_config(%{
        server_url: "http://127.0.0.1:#{upstream_port}",
        auth_token: nil
      })

    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "sse-#{System.unique_integer([:positive])}@example.com",
        password: "StrongPass123!"
      })
      |> Ash.create(authorize?: false)

    {:ok, api_key} =
      ApiKey
      |> Ash.Changeset.for_create(:create, %{
        name: "SSE network regression",
        scopes: [:chat_completions, :messages],
        user_id: user.id
      })
      |> Ash.create(authorize?: false)

    http_options =
      Endpoint.config(:http)
      |> Keyword.merge(ip: {127, 0, 0, 1}, port: 0)
      |> Keyword.update!(:http_limits, &Map.put(&1, :request_timeout, @request_timeout))

    config =
      Application.fetch_env!(:gsmlg_app_admin_web, Endpoint)
      |> Keyword.put(:server, true)
      |> Keyword.put(:http, http_options)
      |> Keyword.put(:https, false)

    adapter = Endpoint.config(:adapter)
    Enum.each(adapter.child_specs(Endpoint, config), &start_supervised!/1)
    assert {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.PhoenixAdapter.server_info(Endpoint, :http)

    {:ok, port: port, raw_key: api_key.__raw_key__}
  end

  test "OpenAI SSE completes across multiple ordinary request deadlines", context do
    socket = request(context, "/api/v1/chat/completions", true)
    started = System.monotonic_time(:millisecond)
    assert {:ok, {:http_response, _, 200, _}} = :gen_tcp.recv(socket, 0, 5000)
    headers = read_headers(socket, [])
    assert {"content-type", "text/event-stream" <> _} = List.keyfind(headers, "content-type", 0)
    body = chunked_body(socket)

    assert System.monotonic_time(:millisecond) - started >= 3 * @request_timeout
    assert_tokens(body)
    assert body =~ "data: [DONE]"
    assert_receive {:backplane_request, "/v1/chat/completions", true}
  end

  test "Anthropic SSE completes across multiple ordinary request deadlines", context do
    socket = request(context, "/api/v1/messages", true)
    started = System.monotonic_time(:millisecond)
    assert {:ok, {:http_response, _, 200, _}} = :gen_tcp.recv(socket, 0, 5000)
    headers = read_headers(socket, [])
    assert {"content-type", "text/event-stream" <> _} = List.keyfind(headers, "content-type", 0)
    body = chunked_body(socket)

    assert System.monotonic_time(:millisecond) - started >= 3 * @request_timeout
    assert_tokens(body)
    assert body =~ "event: message_stop"
    assert_receive {:backplane_request, "/v1/messages", true}
  end

  test "ordinary JSON response still expires before a slow Backplane reply", context do
    started = System.monotonic_time(:millisecond)
    socket = request(context, "/api/v1/chat/completions", false)

    assert_receive {:backplane_request, "/v1/chat/completions", false}, 1000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 2 * @request_timeout)
    elapsed = System.monotonic_time(:millisecond) - started
    assert elapsed >= div(@request_timeout, 2)
    assert elapsed < 3 * @request_timeout
  end

  defp request(%{port: port, raw_key: raw_key}, path, stream?) do
    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, packet: :http_bin], 5000)

    on_exit(fn -> :gen_tcp.close(socket) end)

    body =
      Jason.encode!(%{
        model: "network-stream-model",
        messages: [%{role: "user", content: "hello"}],
        stream: stream?
      })

    :ok =
      :gen_tcp.send(socket, [
        "POST ",
        path,
        " HTTP/1.1\r\nHost: localhost\r\n",
        "Authorization: Bearer ",
        raw_key,
        "\r\n",
        "Content-Type: application/json\r\nContent-Length: ",
        Integer.to_string(byte_size(body)),
        "\r\nConnection: close\r\n\r\n",
        body
      ])

    socket
  end

  defp read_headers(socket, headers) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, :http_eoh} ->
        Enum.reverse(headers)

      {:ok, {:http_header, _, name, _, value}} ->
        read_headers(socket, [{String.downcase(to_string(name)), value} | headers])
    end
  end

  defp chunked_body(socket, chunks \\ []) do
    :ok = :inet.setopts(socket, packet: :line)
    assert {:ok, size_line} = :gen_tcp.recv(socket, 0, 5000)
    size = size_line |> String.trim() |> String.to_integer(16)

    if size == 0 do
      assert {:ok, "\r\n"} = :gen_tcp.recv(socket, 0, 5000)
      chunks |> Enum.reverse() |> IO.iodata_to_binary()
    else
      :ok = :inet.setopts(socket, packet: :raw)
      assert {:ok, chunk} = :gen_tcp.recv(socket, size, 5000)
      assert {:ok, "\r\n"} = :gen_tcp.recv(socket, 2, 5000)
      chunked_body(socket, [chunk | chunks])
    end
  end

  defp assert_tokens(body) do
    tokens =
      ~r/^data: (.+)$/m
      |> Regex.scan(body, capture: :all_but_first)
      |> Enum.reject(&(&1 == ["[DONE]"]))
      |> Enum.map(fn [json] -> Jason.decode!(json) end)
      |> Enum.flat_map(fn
        %{"choices" => [%{"delta" => %{"content" => token}}]} -> [token]
        %{"delta" => %{"text" => token}} -> [token]
        _event -> []
      end)

    assert tokens == Enum.map(1..@event_count, &"token-#{&1}")
  end
end
