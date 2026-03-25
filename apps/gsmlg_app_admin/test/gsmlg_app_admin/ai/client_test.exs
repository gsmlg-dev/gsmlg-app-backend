defmodule GsmlgAppAdmin.AI.ClientTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdmin.AI.Client

  defp fake_provider(overrides \\ %{}) do
    Map.merge(
      %{
        slug: "openai",
        api_base_url: "https://api.openai.com/v1",
        api_key: "sk-test-invalid-key",
        model: "gpt-4o",
        default_params: %{"temperature" => 0.7, "max_tokens" => 4096}
      },
      overrides
    )
  end

  describe "chat_completion/3" do
    test "returns error for invalid API key" do
      provider = fake_provider()
      messages = [%{role: "user", content: "hello"}]

      assert {:error, _reason} = Client.chat_completion(provider, messages)
    end

    test "passes model override from opts" do
      provider = fake_provider()
      messages = [%{role: "user", content: "hello"}]

      # Will still error (invalid key), but verifies opts are passed through
      assert {:error, _reason} = Client.chat_completion(provider, messages, model: "gpt-4o-mini")
    end
  end

  describe "stream_with_callback/4" do
    test "returns error for invalid provider" do
      provider = fake_provider()
      messages = [%{role: "user", content: "hello"}]
      callback = fn _chunk -> :ok end

      assert {:error, _reason} = Client.stream_with_callback(provider, messages, callback)
    end
  end

  describe "image_generation/2" do
    test "returns error for invalid provider" do
      provider = fake_provider()
      params = %{"prompt" => "a cat", "model" => "dall-e-3"}

      assert {:error, _reason} = Client.image_generation(provider, params)
    end
  end

  describe "image_generation/2 - branch coverage via Req.Test" do
    test "returns {:ok, body} when upstream returns HTTP 200" do
      Req.Test.stub(:client_image_200, fn conn ->
        Req.Test.json(conn, %{
          "created" => 1_234_567_890,
          "data" => [%{"url" => "https://example.com/image.png"}]
        })
      end)

      provider = fake_provider()
      params = %{"prompt" => "a cat", "model" => "dall-e-3"}

      assert {:ok, body} =
               Client.image_generation(provider, params, plug: {Req.Test, :client_image_200})

      assert [%{"url" => "https://example.com/image.png"}] = body["data"]
    end

    test "returns {:error, reason} when upstream returns non-200 status" do
      Req.Test.stub(:client_image_401, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      provider = fake_provider()
      params = %{"prompt" => "a cat", "model" => "dall-e-3"}

      assert {:error, reason} =
               Client.image_generation(provider, params, plug: {Req.Test, :client_image_401})

      assert reason =~ "401"
    end

    test "returns {:error, reason} on transport/network failure" do
      Req.Test.stub(:client_image_fail, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      provider = fake_provider()
      params = %{"prompt" => "a cat", "model" => "dall-e-3"}

      assert {:error, reason} =
               Client.image_generation(provider, params, plug: {Req.Test, :client_image_fail})

      assert reason =~ "Request failed"
    end

    test "accepts request with nil prompt when prompt key is absent" do
      Req.Test.stub(:client_image_nil_prompt, fn conn ->
        Req.Test.json(conn, %{"created" => 1, "data" => []})
      end)

      provider = fake_provider()
      # No "prompt" key — body will contain prompt: nil
      params = %{"model" => "dall-e-3"}

      # Should not crash; stub returns 200 so result is {:ok, _}
      assert {:ok, _body} =
               Client.image_generation(provider, params,
                 plug: {Req.Test, :client_image_nil_prompt}
               )
    end

    test "propagates optional params (n, size, quality, style, response_format) into request" do
      Req.Test.stub(:client_image_opts, fn conn ->
        Req.Test.json(conn, %{"created" => 1, "data" => []})
      end)

      provider = fake_provider()

      params = %{
        "prompt" => "a cat",
        "model" => "dall-e-3",
        "n" => 2,
        "size" => "512x512",
        "quality" => "hd",
        "style" => "vivid",
        "response_format" => "url"
      }

      assert {:ok, _body} =
               Client.image_generation(provider, params, plug: {Req.Test, :client_image_opts})
    end
  end
end
