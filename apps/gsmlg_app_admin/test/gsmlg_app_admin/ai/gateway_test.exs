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

    test "preserves agent system_prompt as the system field" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "You are an agent.",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "You are an agent."
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

    test "returns {:ok, response} on happy path when provider resolves and upstream returns 200" do
      stub = :"gw_image_ok_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        Req.Test.json(conn, %{
          "created" => 1_000_000,
          "data" => [%{"url" => "https://example.com/img.png"}]
        })
      end)

      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Provider #{System.unique_integer([:positive])}",
          slug: "test-provider-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-api-key",
          model: "dall-e-3",
          available_models: ["dall-e-3"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:images],
        allowed_providers: [],
        allowed_models: []
      }

      assert {:ok, body} =
               Gateway.generate_image(
                 api_key,
                 %{"model" => "dall-e-3", "prompt" => "a cat"},
                 client_opts: [plug: {Req.Test, stub}]
               )

      assert is_map(body)
    end

    test "returns {:error, reason} when provider resolves but Client.image_generation fails" do
      stub = :"gw_image_err_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Provider #{System.unique_integer([:positive])}",
          slug: "test-provider-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-api-key",
          model: "dall-e-3",
          available_models: ["dall-e-3"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:images],
        allowed_providers: [],
        allowed_models: []
      }

      assert {:error, reason} =
               Gateway.generate_image(
                 api_key,
                 %{"model" => "dall-e-3", "prompt" => "a cat"},
                 client_opts: [plug: {Req.Test, stub}]
               )

      assert reason =~ "429"
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
        model_params: %{},
        system_prompt: nil
      }

      messages = [%{role: :user, content: "Hello"}]

      assert {:error, reason} = Gateway.run_agent(api_key, agent, messages)
      assert reason =~ "No provider found"
    end

    test "returns error when api_key lacks agents scope and provider exists" do
      # Create a provider so provider resolution succeeds
      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Agent Test Provider #{System.unique_integer([:positive])}",
          slug: "agent-test-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "agent-test-model",
          available_models: ["agent-test-model"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:chat_completions],
        allowed_providers: [],
        allowed_models: []
      }

      agent = %{
        id: "test-agent-id",
        slug: "test-agent",
        model: "agent-test-model",
        max_iterations: 5,
        model_params: %{},
        system_prompt: nil
      }

      messages = [%{role: :user, content: "Hello"}]

      assert {:error, reason} = Gateway.run_agent(api_key, agent, messages)
      assert reason =~ "agents"
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

  describe "inject_system_context/2 with real DB templates" do
    test "injects default template content into system prompt" do
      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Default Template",
          slug: "test-default-#{System.unique_integer([:positive])}",
          content: "You are a helpful assistant. Today is {{date}}.",
          is_default: true,
          is_active: true,
          priority: 10
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Be concise.",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)

      assert result.system =~ "You are a helpful assistant."
      assert result.system =~ Date.utc_today() |> Date.to_iso8601()
      assert result.system =~ "Be concise."
    end

    test "injects global memory into system prompt" do
      {:ok, _memory} =
        GsmlgAppAdmin.AI.Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "The user prefers dark mode",
          category: :preference,
          scope: :global,
          is_active: true,
          priority: 5
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: Ash.UUID.generate(),
        user_id: nil,
        scopes: [:chat_completions]
      }

      request = %{
        model: "gpt-4o",
        system: nil,
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "dark mode"
      assert result.system =~ "[preference]"
    end

    test "template {{memory}} variable is replaced with memory content" do
      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Memory Template",
          slug: "memory-tmpl-#{System.unique_integer([:positive])}",
          content: "Known facts:\n{{memory}}",
          is_default: true,
          is_active: true,
          priority: 10
        })
        |> Ash.create(authorize?: false)

      {:ok, _memory} =
        GsmlgAppAdmin.AI.Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Company name is Acme Corp",
          category: :fact,
          scope: :global,
          is_active: true,
          priority: 5
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: Ash.UUID.generate(),
        user_id: nil,
        scopes: [:chat_completions]
      }

      request = %{
        model: "gpt-4o",
        system: nil,
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "Known facts:"
      assert result.system =~ "Acme Corp"
    end

    test "inactive templates are not injected" do
      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Inactive Template",
          slug: "inactive-tmpl-#{System.unique_integer([:positive])}",
          content: "SECRET_INACTIVE_CONTENT",
          is_default: true,
          is_active: false,
          priority: 10
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Base prompt",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      refute result.system =~ "SECRET_INACTIVE_CONTENT"
    end

    test "non-default templates are not auto-injected" do
      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Non-default Template",
          slug: "nondefault-#{System.unique_integer([:positive])}",
          content: "NON_DEFAULT_CONTENT",
          is_default: false,
          is_active: true,
          priority: 10
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Base prompt",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      refute result.system =~ "NON_DEFAULT_CONTENT"
    end

    test "inactive memories are not injected" do
      {:ok, _memory} =
        GsmlgAppAdmin.AI.Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "INACTIVE_MEMORY_CONTENT",
          category: :fact,
          scope: :global,
          is_active: false,
          priority: 5
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Base prompt",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      refute result.system =~ "INACTIVE_MEMORY_CONTENT"
    end
  end

  describe "list_models/1 with DB providers" do
    test "returns models from active providers" do
      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Models Test #{System.unique_integer([:positive])}",
          slug: "models-test-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "test-model-alpha",
          available_models: ["test-model-alpha", "test-model-beta"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:models_list],
        allowed_providers: [],
        allowed_models: []
      }

      assert {:ok, models} = Gateway.list_models(api_key)
      model_ids = Enum.map(models, & &1.id)
      assert "test-model-alpha" in model_ids
      assert "test-model-beta" in model_ids
    end

    test "filters models by allowed_models restriction" do
      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Restricted Test #{System.unique_integer([:positive])}",
          slug: "restricted-test-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "restricted-model-a",
          available_models: ["restricted-model-a", "restricted-model-b"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:models_list],
        allowed_providers: [],
        allowed_models: ["restricted-model-a"]
      }

      assert {:ok, models} = Gateway.list_models(api_key)
      model_ids = Enum.map(models, & &1.id)
      assert "restricted-model-a" in model_ids
      refute "restricted-model-b" in model_ids
    end
  end
end
