defmodule GsmlgAppAdmin.AI.ClientTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdmin.AI.BackplaneError
  alias GsmlgAppAdmin.AI.Client

  defp request(overrides \\ %{}) do
    Map.merge(
      %{
        model: "gpt-4o",
        system: "You are helpful.",
        messages: [%{role: :user, content: "hello"}],
        stream: false,
        params: %{temperature: 0.2, max_tokens: 64}
      },
      overrides
    )
  end

  defp json_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(body), conn}
  end

  describe "chat_completion/2" do
    test "posts OpenAI-compatible requests to Backplane" do
      stub = :"client_chat_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"
        {body, conn} = json_body(conn)
        assert body["model"] == "gpt-4o"

        assert [%{"role" => "system"}, %{"role" => "user", "content" => "hello"}] =
                 body["messages"]

        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [%{"message" => %{"content" => "hi"}}],
          "usage" => %{
            "prompt_tokens" => 3,
            "completion_tokens" => 2,
            "total_tokens" => 5
          }
        })
      end)

      assert {:ok, response} = Client.chat_completion(request(), plug: {Req.Test, stub})
      assert response.content == "hi"
      assert response.model == "gpt-4o"
      assert response.usage.total_tokens == 5
    end

    test "posts Anthropic-compatible requests to Backplane" do
      stub = :"client_messages_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/messages"
        {body, conn} = json_body(conn)
        assert body["model"] == "claude-sonnet-4-20250514"
        assert body["system"] == "You are helpful."

        Req.Test.json(conn, %{
          "model" => "claude-sonnet-4-20250514",
          "content" => [%{"type" => "text", "text" => "hello from claude"}],
          "usage" => %{"input_tokens" => 4, "output_tokens" => 3}
        })
      end)

      assert {:ok, response} =
               Client.chat_completion(
                 request(%{model: "claude-sonnet-4-20250514"}),
                 api_format: :anthropic,
                 plug: {Req.Test, stub}
               )

      assert response.content == "hello from claude"
      assert response.usage.total_tokens == 7
    end

    test "returns BackplaneError when upstream returns non-success status" do
      stub = :"client_chat_error_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, %BackplaneError{} = error} =
               Client.chat_completion(request(), plug: {Req.Test, stub})

      assert error.status == 429
      assert error.message == "Rate limit exceeded"
    end
  end

  describe "stream_with_callback/3" do
    test "parses OpenAI SSE content chunks" do
      stub = :"client_stream_#{System.unique_integer([:positive])}"
      test_pid = self()

      Req.Test.stub(stub, fn conn ->
        Req.Test.text(conn, """
        data: {"choices":[{"delta":{"content":"hel"}}]}

        data: {"choices":[{"delta":{"content":"lo"}}]}

        data: [DONE]

        """)
      end)

      callback = fn chunk -> send(test_pid, chunk) end

      assert {:ok, :streaming_complete} =
               Client.stream_with_callback(request(), callback, plug: {Req.Test, stub})

      assert_receive {:content, "hel"}
      assert_receive {:content, "lo"}
    end
  end

  describe "image_generation/2" do
    test "proxies image generation params to Backplane" do
      stub = :"client_image_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/images/generations"
        {body, conn} = json_body(conn)
        assert body["prompt"] == "a cat"
        assert body["model"] == "dall-e-3"

        Req.Test.json(conn, %{
          "created" => 1_234_567_890,
          "data" => [%{"url" => "https://example.com/image.png"}]
        })
      end)

      params = %{"prompt" => "a cat", "model" => "dall-e-3"}

      assert {:ok, body} = Client.image_generation(params, plug: {Req.Test, stub})
      assert [%{"url" => "https://example.com/image.png"}] = body["data"]
    end
  end

  describe "embeddings/2" do
    test "proxies embeddings params to Backplane" do
      stub = :"client_embeddings_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        assert conn.request_path == "/v1/embeddings"
        {body, conn} = json_body(conn)
        assert body["model"] == "text-embedding-3-small"
        assert body["input"] == "hello"

        Req.Test.json(conn, %{
          "object" => "list",
          "data" => [%{"embedding" => [0.1, 0.2], "index" => 0}]
        })
      end)

      params = %{"model" => "text-embedding-3-small", "input" => "hello"}
      assert {:ok, body} = Client.embeddings(params, plug: {Req.Test, stub})
      assert [%{"embedding" => [0.1, 0.2]}] = body["data"]
    end
  end

  describe "list_models/1" do
    test "loads models from Backplane" do
      stub = :"client_models_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/models"

        Req.Test.json(conn, %{
          "object" => "list",
          "data" => [%{"id" => "gpt-4o", "object" => "model"}]
        })
      end)

      assert {:ok, %{"data" => [%{"id" => "gpt-4o"}]}} =
               Client.list_models(plug: {Req.Test, stub})
    end
  end
end
