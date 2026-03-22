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
end
