defmodule GsmlgAppAdminWeb.ServerIntegrationTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdminWeb.Endpoint

  @max_body_bytes 10_485_760

  setup do
    http_options = Endpoint.config(:http) |> Keyword.merge(ip: {127, 0, 0, 1}, port: 0)

    config =
      Application.fetch_env!(:gsmlg_app_admin_web, Endpoint)
      |> Keyword.put(:server, true)
      |> Keyword.put(:http, http_options)
      |> Keyword.put(:https, false)

    adapter = Endpoint.config(:adapter)
    Enum.each(adapter.child_specs(Endpoint, config), &start_supervised!/1)
    assert {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.PhoenixAdapter.server_info(Endpoint, :http)
    {:ok, port: port}
  end

  test "serves the application router over HTTP", %{port: port} do
    socket = connect(port)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    {response, headers} = response_headers(socket)
    :ok = :inet.setopts(socket, packet: :raw)
    body = response_body(socket)

    assert {:http_response, _, 302, _} = response
    assert {"location", "/sign-in" <> _} = List.keyfind(headers, "location", 0)
    assert body =~ "redirected"
  end

  test "upgrades the LiveView socket and answers a Phoenix heartbeat", %{port: port} do
    socket = connect(port)
    :ok = :gen_tcp.send(socket, websocket_request("http://localhost"))
    {response, headers} = response_headers(socket)

    assert {:http_response, _, 101, _} = response

    assert {"sec-websocket-accept", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="} =
             List.keyfind(headers, "sec-websocket-accept", 0)

    :ok = :inet.setopts(socket, packet: :raw)

    :ok =
      :gen_tcp.send(socket, masked_text(Jason.encode!([nil, "1", "phoenix", "heartbeat", %{}])))

    assert {:ok, <<1::1, 0::3, 1::4, 0::1, length::7>>} = :gen_tcp.recv(socket, 2, 5000)
    assert {:ok, payload} = :gen_tcp.recv(socket, length, 5000)

    assert [nil, "1", "phoenix", "phx_reply", %{"status" => "ok", "response" => %{}}] =
             Jason.decode!(payload)
  end

  @tag capture_log: true
  test "retains Phoenix origin rejection on the LiveView socket", %{port: port} do
    socket = connect(port)
    :ok = :gen_tcp.send(socket, websocket_request("https://untrusted.example"))
    {response, _headers} = response_headers(socket)
    assert {:http_response, _, 403, _} = response
  end

  @tag capture_log: true
  test "reads the existing 10 MiB JSON limit before application routing", %{port: port} do
    socket = connect(port)
    prefix = "{\"payload\":\""
    suffix = "\"}"

    body = [
      prefix,
      :binary.copy("a", @max_body_bytes - byte_size(prefix) - byte_size(suffix)),
      suffix
    ]

    :ok =
      :gen_tcp.send(socket, [
        json_request_headers("/api/v1/chat/completions", @max_body_bytes),
        body
      ])

    assert {:ok, {:http_response, _, 401, _}} = :gen_tcp.recv(socket, 0, 5000)
  end

  test "rejects a declared JSON body above 10 MiB", %{port: port} do
    socket = connect(port)

    :ok =
      :gen_tcp.send(socket, json_request_headers("/api/v1/chat/completions", @max_body_bytes + 1))

    {response, _headers} = response_headers(socket)
    assert {:http_response, _, 413, _} = response
  end

  defp connect(port) do
    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, packet: :http_bin], 5000)

    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp response_headers(socket) do
    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    {response, read_headers(socket, [])}
  end

  defp read_headers(socket, headers) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, :http_eoh} ->
        Enum.reverse(headers)

      {:ok, {:http_header, _, name, _, value}} ->
        read_headers(socket, [{String.downcase(to_string(name)), value} | headers])
    end
  end

  defp response_body(socket, chunks \\ []) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, chunk} -> response_body(socket, [chunk | chunks])
      {:error, :closed} -> chunks |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end

  defp json_request_headers(path, content_length) do
    [
      "POST ",
      path,
      " HTTP/1.1\r\n",
      "Host: localhost\r\n",
      "Content-Type: application/json\r\n",
      "Content-Length: ",
      Integer.to_string(content_length),
      "\r\n",
      "Connection: close\r\n\r\n"
    ]
  end

  defp websocket_request(origin) do
    [
      "GET /live/websocket?vsn=2.0.0 HTTP/1.1\r\n",
      "Host: localhost\r\n",
      "Origin: ",
      origin,
      "\r\n",
      "Connection: Upgrade\r\n",
      "Upgrade: websocket\r\n",
      "Sec-WebSocket-Version: 13\r\n",
      "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
    ]
  end

  defp masked_text(payload) do
    mask = <<1, 2, 3, 4>>

    masked =
      for {byte, index} <- Enum.with_index(:binary.bin_to_list(payload)), into: <<>> do
        <<Bitwise.bxor(byte, :binary.at(mask, rem(index, 4)))>>
      end

    <<0x81, Bitwise.bor(0x80, byte_size(payload)), mask::binary, masked::binary>>
  end
end
