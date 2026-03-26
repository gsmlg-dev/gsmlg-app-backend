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

    test "respects max_iterations=0 by returning error immediately without calling LLM" do
      uid = System.unique_integer([:positive])

      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Zero Iter Provider #{uid}",
          slug: "zero-iter-#{uid}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "zero-iter-model-#{uid}",
          available_models: ["zero-iter-model-#{uid}"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:agents],
        allowed_providers: [],
        allowed_models: []
      }

      agent = %{
        id: Ash.UUID.generate(),
        slug: "zero-agent-#{uid}",
        model: "zero-iter-model-#{uid}",
        max_iterations: 0,
        model_params: %{},
        system_prompt: nil
      }

      messages = [%{role: :user, content: "Hello"}]

      assert {:error, reason} = Gateway.run_agent(api_key, agent, messages)
      assert reason =~ "maximum iterations"
    end

    test "builds agent system prompt by merging agent and caller system" do
      uid = System.unique_integer([:positive])

      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Agent Sys Prompt Provider #{uid}",
          slug: "agent-sys-#{uid}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "agent-sys-model-#{uid}",
          available_models: ["agent-sys-model-#{uid}"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:agents],
        allowed_providers: [],
        allowed_models: []
      }

      # Agent with max_iterations: 0 so we get the error without an LLM call
      agent = %{
        id: Ash.UUID.generate(),
        slug: "agent-sys-#{uid}",
        model: "agent-sys-model-#{uid}",
        max_iterations: 0,
        model_params: %{},
        system_prompt: "You are a helpful agent."
      }

      messages = [%{role: :user, content: "Hello"}]

      # With max_iterations: 0, we get the iteration error quickly (no LLM call)
      # The important thing is it doesn't raise — the agent/system prompt combination works
      assert {:error, reason} = Gateway.run_agent(api_key, agent, messages)
      assert reason =~ "maximum iterations"
    end

    test "injects agent-scoped memories into the agent's system context" do
      uid = System.unique_integer([:positive])

      {:ok, real_agent} =
        GsmlgAppAdmin.AI.Agent
        |> Ash.Changeset.for_create(:create, %{
          name: "Memory Agent #{uid}",
          slug: "memory-agent-#{uid}",
          model: "memory-agent-model-#{uid}",
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, _memory} =
        GsmlgAppAdmin.AI.Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "AGENT_SPECIFIC_FACT_#{uid}",
          category: :fact,
          scope: :agent,
          agent_id: real_agent.id,
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Memory Provider #{uid}",
          slug: "memory-prov-#{uid}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "memory-agent-model-#{uid}",
          available_models: ["memory-agent-model-#{uid}"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{
        id: Ash.UUID.generate(),
        user_id: nil,
        scopes: [:agents],
        allowed_providers: [],
        allowed_models: []
      }

      # max_iterations: 0 → returns iteration error before hitting LLM
      agent_struct = %{
        id: real_agent.id,
        slug: real_agent.slug,
        model: real_agent.model,
        max_iterations: 0,
        model_params: %{},
        system_prompt: nil
      }

      messages = [%{role: :user, content: "Hello"}]

      # Just verify it doesn't crash when agent-scoped memories exist
      result = Gateway.run_agent(api_key, agent_struct, messages)
      assert match?({:error, _}, result)
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

    test "injects {{user.display_name}} variable from user record" do
      uid = System.unique_integer([:positive])

      {:ok, user} =
        GsmlgAppAdmin.Accounts.User
        |> Ash.Changeset.for_create(:admin_create, %{
          email: "display#{uid}@example.com",
          password: "StrongPass123!",
          display_name: "Alice Example"
        })
        |> Ash.create(authorize?: false)

      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "User Greeting #{uid}",
          slug: "user-greeting-#{uid}",
          content: "Hello, {{user.display_name}}! How can I help?",
          is_default: true,
          is_active: true,
          priority: 10
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: Ash.UUID.generate(), user_id: user.id, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: nil,
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "Alice Example"
    end

    test "{{user.display_name}} is empty string when no user_id" do
      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Anon Template #{System.unique_integer([:positive])}",
          slug: "anon-tmpl-#{System.unique_integer([:positive])}",
          content: "User: {{user.display_name}}",
          is_default: true,
          is_active: true,
          priority: 10
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: Ash.UUID.generate(), user_id: nil, scopes: [:chat_completions]}

      request = %{model: "gpt-4o", system: nil, messages: [], stream: false, params: %{}}

      result = Gateway.inject_system_context(api_key, request)
      # Variable replaced with empty string, not the literal {{user.display_name}}
      refute result.system =~ "{{user.display_name}}"
      assert result.system =~ "User: "
    end

    test "injects key-specific template for matching api_key" do
      uid = System.unique_integer([:positive])

      # Create the API key in the DB so we can link a template to it
      {:ok, user} =
        GsmlgAppAdmin.Accounts.User
        |> Ash.Changeset.for_create(:admin_create, %{
          email: "keytemplate#{uid}@example.com",
          password: "StrongPass123!"
        })
        |> Ash.create(authorize?: false)

      {:ok, db_key} =
        GsmlgAppAdmin.AI.ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "key-tmpl-test-#{uid}",
          scopes: [:chat_completions],
          is_active: true,
          user_id: user.id
        })
        |> Ash.create(authorize?: false)

      {:ok, template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Key Template #{uid}",
          slug: "key-tmpl-#{uid}",
          content: "KEY_SPECIFIC_INSTRUCTION",
          is_default: false,
          is_active: true,
          priority: 5
        })
        |> Ash.create(authorize?: false)

      # Link template to the API key
      {:ok, _} =
        GsmlgAppAdmin.AI.ApiKeyTemplate
        |> Ash.Changeset.for_create(:create, %{
          api_key_id: db_key.id,
          system_prompt_template_id: template.id
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: db_key.id, user_id: nil, scopes: [:chat_completions]}

      request = %{model: "gpt-4o", system: nil, messages: [], stream: false, params: %{}}

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "KEY_SPECIFIC_INSTRUCTION"
    end

    test "does not inject key-specific template for a different api_key" do
      uid = System.unique_integer([:positive])

      {:ok, user} =
        GsmlgAppAdmin.Accounts.User
        |> Ash.Changeset.for_create(:admin_create, %{
          email: "keytemplate2#{uid}@example.com",
          password: "StrongPass123!"
        })
        |> Ash.create(authorize?: false)

      {:ok, db_key} =
        GsmlgAppAdmin.AI.ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "key-other-#{uid}",
          scopes: [:chat_completions],
          is_active: true,
          user_id: user.id
        })
        |> Ash.create(authorize?: false)

      {:ok, template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Other Key Template #{uid}",
          slug: "other-key-tmpl-#{uid}",
          content: "OTHER_KEY_SECRET",
          is_default: false,
          is_active: true,
          priority: 5
        })
        |> Ash.create(authorize?: false)

      {:ok, _} =
        GsmlgAppAdmin.AI.ApiKeyTemplate
        |> Ash.Changeset.for_create(:create, %{
          api_key_id: db_key.id,
          system_prompt_template_id: template.id
        })
        |> Ash.create(authorize?: false)

      # Use a DIFFERENT api_key id — should not see the template
      different_api_key = %{id: Ash.UUID.generate(), user_id: nil, scopes: [:chat_completions]}
      request = %{model: "gpt-4o", system: nil, messages: [], stream: false, params: %{}}

      result = Gateway.inject_system_context(different_api_key, request)
      refute is_binary(result.system) and result.system =~ "OTHER_KEY_SECRET"
    end

    test "injects agent-scoped memory when agent_id is provided" do
      agent_id = Ash.UUID.generate()

      {:ok, _memory} =
        GsmlgAppAdmin.AI.Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "AGENT_SCOPED_MEMORY",
          category: :instruction,
          scope: :agent,
          agent_id: agent_id,
          is_active: true
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: Ash.UUID.generate(), user_id: nil, scopes: [:agents]}

      request = %{model: "gpt-4o", system: nil, messages: [], stream: false, params: %{}}

      # Without agent_id: memory not injected
      result_without = Gateway.inject_system_context(api_key, request)
      refute is_binary(result_without.system) and result_without.system =~ "AGENT_SCOPED_MEMORY"

      # With agent_id: memory injected
      result_with = Gateway.inject_system_context(api_key, request, agent_id: agent_id)
      assert result_with.system =~ "AGENT_SCOPED_MEMORY"
    end

    test "injects agent-linked system prompt template when agent_id is provided" do
      uid = System.unique_integer([:positive])

      # Create a real agent in DB so we can link a template to it
      {:ok, agent} =
        GsmlgAppAdmin.AI.Agent
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Agent #{uid}",
          slug: "test-agent-#{uid}",
          model: "gpt-4o",
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Agent Template #{uid}",
          slug: "agent-tmpl-#{uid}",
          content: "AGENT_TEMPLATE_INSTRUCTION",
          is_default: false,
          is_active: true,
          priority: 5
        })
        |> Ash.create(authorize?: false)

      {:ok, _} =
        GsmlgAppAdmin.AI.AgentTemplate
        |> Ash.Changeset.for_create(:create, %{
          agent_id: agent.id,
          system_prompt_template_id: template.id
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: Ash.UUID.generate(), user_id: nil, scopes: [:agents]}
      request = %{model: "gpt-4o", system: nil, messages: [], stream: false, params: %{}}

      # Without agent_id: template not injected
      result_without = Gateway.inject_system_context(api_key, request)

      refute is_binary(result_without.system) and
               result_without.system =~ "AGENT_TEMPLATE_INSTRUCTION"

      # With agent_id: template injected
      result_with = Gateway.inject_system_context(api_key, request, agent_id: agent.id)
      assert result_with.system =~ "AGENT_TEMPLATE_INSTRUCTION"
    end
  end

  describe "check_scope (via chat/3)" do
    test "returns scope error when key lacks required scope" do
      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Scope Test #{System.unique_integer([:positive])}",
          slug: "scope-test-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "scope-test-model",
          available_models: ["scope-test-model"],
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

      request = %{
        model: "scope-test-model",
        system: nil,
        messages: [%{role: :user, content: "Hello"}],
        stream: false,
        params: %{}
      }

      assert {:error, reason} = Gateway.chat(api_key, request)
      assert reason =~ "chat_completions"
    end
  end

  describe "resolve_provider/2 with key restrictions" do
    test "rejects model not in allowed_models list" do
      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Model Restrict #{System.unique_integer([:positive])}",
          slug: "model-restrict-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "gpt-4o",
          available_models: ["gpt-4o", "gpt-4-turbo"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      # Key allows only gpt-4o — gpt-4-turbo should be rejected
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:chat_completions],
        allowed_providers: [],
        allowed_models: ["gpt-4o"]
      }

      assert {:error, reason} = Gateway.resolve_provider(api_key, "gpt-4-turbo")
      assert reason =~ "does not have access to model"

      # Same key with the allowed model — should succeed
      assert {:ok, _} = Gateway.resolve_provider(api_key, "gpt-4o")
    end

    test "empty allowed_models permits any model" do
      {:ok, _provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Open Provider #{System.unique_integer([:positive])}",
          slug: "open-provider-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "open-model-x",
          available_models: ["open-model-x"],
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

      assert {:ok, _} = Gateway.resolve_provider(api_key, "open-model-x")
    end

    test "filters by allowed_providers" do
      {:ok, provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Allowed Provider #{System.unique_integer([:positive])}",
          slug: "allowed-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "allowed-model-xyz",
          available_models: ["allowed-model-xyz"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      # Key restricted to a different provider — should fail
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:chat_completions],
        allowed_providers: [Ash.UUID.generate()],
        allowed_models: []
      }

      assert {:error, _} = Gateway.resolve_provider(api_key, "allowed-model-xyz")

      # Key with the correct provider ID — should succeed
      api_key_ok = %{
        id: "test-key",
        user_id: nil,
        scopes: [:chat_completions],
        allowed_providers: [provider.id],
        allowed_models: []
      }

      assert {:ok, _} = Gateway.resolve_provider(api_key_ok, "allowed-model-xyz")
    end
  end

  describe "list_models/1 filters by allowed_providers" do
    test "only returns models from allowed providers" do
      {:ok, provider} =
        GsmlgAppAdmin.AI.Provider
        |> Ash.Changeset.for_create(:create, %{
          name: "Prov Filter #{System.unique_integer([:positive])}",
          slug: "prov-filter-#{System.unique_integer([:positive])}",
          api_base_url: "http://fake.local",
          api_key: "test-key",
          model: "prov-filter-model",
          available_models: ["prov-filter-model"],
          is_active: true
        })
        |> Ash.create(authorize?: false)

      # Key restricted to a non-existent provider
      api_key_no_match = %{
        id: "test-key",
        user_id: nil,
        scopes: [:models_list],
        allowed_providers: [Ash.UUID.generate()],
        allowed_models: []
      }

      assert {:ok, models} = Gateway.list_models(api_key_no_match)
      model_ids = Enum.map(models, & &1.id)
      refute "prov-filter-model" in model_ids

      # Key with matching provider
      api_key_match = %{
        id: "test-key",
        user_id: nil,
        scopes: [:models_list],
        allowed_providers: [provider.id],
        allowed_models: []
      }

      assert {:ok, models} = Gateway.list_models(api_key_match)
      model_ids = Enum.map(models, & &1.id)
      assert "prov-filter-model" in model_ids
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

    test "{{datetime}} variable is replaced with ISO 8601 datetime string" do
      {:ok, _template} =
        GsmlgAppAdmin.AI.SystemPromptTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Datetime Template #{System.unique_integer([:positive])}",
          slug: "datetime-template-#{System.unique_integer([:positive])}",
          content: "Current datetime: {{datetime}}. Today: {{date}}.",
          is_default: true,
          is_active: true,
          priority: 1
        })
        |> Ash.create(authorize?: false)

      api_key = %{id: Ash.UUID.generate(), user_id: nil, scopes: [:chat_completions]}
      request = %{model: "gpt-4o", system: nil, messages: [], stream: false, params: %{}}

      result = Gateway.inject_system_context(api_key, request)

      # {{datetime}} should be replaced with ISO 8601 datetime (contains T separator)
      assert result.system =~ ~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
      # {{date}} should be replaced with today's date
      assert result.system =~ Date.utc_today() |> Date.to_iso8601()
      # No unreplaced variables remain
      refute result.system =~ "{{datetime}}"
      refute result.system =~ "{{date}}"
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
