defmodule GsmlgAppAdmin.AI.GatewayTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.AI.Gateway

  describe "inject_system_context/2" do
    test "returns request unchanged when no templates or memories" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "You are helpful.",
        messages: [%{role: :user, content: "Hello"}],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      # System prompt should be preserved (may have date context appended)
      assert result.system =~ "You are helpful."
    end

    test "preserves caller system prompt when no admin context" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Custom system prompt",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "Custom system prompt"
    end

    test "does not raise when user_id is non-nil but no DB records exist" do
      api_key = %{id: "test-key", user_id: "nonexistent-user-id", scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Base prompt",
        messages: [],
        stream: false,
        params: %{}
      }

      # Should not raise — gracefully handles missing DB records
      result = Gateway.inject_system_context(api_key, request)
      assert is_map(result)
      assert Map.has_key?(result, :system)
    end
  end

  describe "list_models/1" do
    test "returns a tuple (not a crash) when no providers are in DB" do
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:models_list],
        allowed_providers: [],
        allowed_models: []
      }

      result = Gateway.list_models(api_key)
      # Must return a tagged tuple — not raise — even with empty DB
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "generate_image/2" do
    test "returns permission error when api_key lacks images scope" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      assert {:error, reason} =
               Gateway.generate_image(api_key, %{"model" => "dall-e-3", "prompt" => "a cat"})

      assert reason =~ "images"
    end

    test "returns error when model is missing" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:images]}

      assert {:error, reason} = Gateway.generate_image(api_key, %{"prompt" => "a cat"})
      assert reason =~ "model"
    end

    test "returns provider error when no matching provider exists" do
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:images],
        allowed_providers: [],
        allowed_models: []
      }

      assert {:error, reason} =
               Gateway.generate_image(api_key, %{"model" => "dall-e-3", "prompt" => "a cat"})

      assert reason =~ "provider" or reason =~ "model"
    end
  end

  describe "resolve_provider/2" do
    test "returns error when no providers exist for a model" do
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:chat_completions],
        allowed_providers: [],
        allowed_models: []
      }

      assert {:error, reason} = Gateway.resolve_provider(api_key, "nonexistent-model")
      assert reason =~ "No provider found"
    end
  end

  describe "chat/3" do
    test "returns error when no matching provider exists" do
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:chat_completions],
        allowed_providers: [],
        allowed_models: []
      }

      request = %{
        model: "nonexistent-model",
        system: nil,
        messages: [%{role: :user, content: "Hello"}],
        stream: false,
        params: %{}
      }

      assert {:error, reason} = Gateway.chat(api_key, request)
      assert reason =~ "No provider found"
    end
  end

  describe "run_agent/4" do
    test "returns error when no matching provider exists" do
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:agents],
        allowed_providers: [],
        allowed_models: []
      }

      agent = %{
        id: "test-agent-id",
        slug: "test-agent",
        model: "nonexistent-model",
        max_iterations: 5,
        model_params: %{}
      }

      messages = [%{role: :user, content: "Hello"}]

      assert {:error, reason} = Gateway.run_agent(api_key, agent, messages)
      assert reason =~ "No provider found"
    end
  end

  describe "extract_text/2" do
    test "returns permission error when api_key lacks ocr scope" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      assert {:error, reason} = Gateway.extract_text(api_key, %{"model" => "gpt-4o"})
      assert reason =~ "ocr"
    end

    test "returns error when no model is specified" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:ocr]}

      # No model param → no provider to call → error
      assert match?({:error, _}, Gateway.extract_text(api_key, %{}))
    end

    test "does not crash with text-only content path (no image param)" do
      # Scope passes, no image param → plain string user_content.
      # With no valid provider in test DB, expect provider error, not content error.
      api_key = %{id: "test-key", user_id: nil, scopes: [:ocr]}

      result = Gateway.extract_text(api_key, %{"model" => "gpt-4o"})
      assert match?({:error, _}, result)
    end

    test "does not crash with multipart content path (image param present)" do
      # Scope passes, image param present → list [image_url, text] user_content.
      # With no valid provider in test DB, expect provider error, not a
      # content-building or nil-safety crash.
      api_key = %{id: "test-key", user_id: nil, scopes: [:ocr]}

      params = %{
        "model" => "gpt-4o",
        "image" => "data:image/png;base64,abc123"
      }

      result = Gateway.extract_text(api_key, params)
      assert match?({:error, _}, result)
    end

    test "accepts all supported output_format values without raising" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:ocr]}

      for fmt <- ["markdown", "json", "text"] do
        result = Gateway.extract_text(api_key, %{"model" => "gpt-4o", "output_format" => fmt})

        assert match?({:error, _}, result),
               "Expected {:error, _} for format=#{fmt}, got: #{inspect(result)}"
      end
    end
  end
end
