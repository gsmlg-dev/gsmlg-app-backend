defmodule GsmlgAppAdminWeb.Api.V1.ControllerTest do
  @moduledoc """
  Integration tests for API v1 controllers verifying scope checking and halt behaviour.

  Creates real users and API keys in the database, then hits the full HTTP stack
  (including ApiKeyAuth) to verify controllers enforce scope requirements and halt on 403.
  """

  use GsmlgAppAdminWeb.ConnCase

  alias GsmlgAppAdmin.AI.ApiKey

  defp create_user do
    uid = :erlang.unique_integer([:positive])

    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "apitest#{uid}@example.com",
        password: "StrongPass123!"
      })
      |> Ash.create(authorize?: false)

    user
  end

  defp create_api_key(scopes) do
    user = create_user()

    {:ok, api_key} =
      ApiKey
      |> Ash.Changeset.for_create(:create, %{
        name: "test-key-#{:erlang.unique_integer([:positive])}",
        scopes: scopes,
        is_active: true,
        user_id: user.id
      })
      |> Ash.create(authorize?: false)

    {api_key.__raw_key__, api_key}
  end

  # ── ChatCompletionsController ──────────────────────────────────────────────

  describe "POST /api/v1/chat/completions" do
    test "returns 403 and halts when api_key lacks chat_completions scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:images])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{"messages" => []})

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "permission_error"
      assert body["error"]["message"] =~ "chat_completions"
    end

    test "returns 400 when model is missing", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "messages" => [%{"role" => "user", "content" => "hi"}]
        })

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "model"
    end

    test "returns 400 when messages array is empty", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "model" => "gpt-4o",
          "messages" => []
        })

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "messages"
    end

    test "proceeds past scope check when chat_completions scope present", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "model" => "gpt-4o",
          "messages" => [%{"role" => "user", "content" => "hi"}]
        })

      refute conn.status == 403
    end

    test "returns 422 when no provider found for model", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "model" => "nonexistent-model-xyz",
          "messages" => [%{"role" => "user", "content" => "hi"}],
          "stream" => false
        })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "provider"
    end
  end

  # ── MessagesController ─────────────────────────────────────────────────────

  describe "POST /api/v1/messages" do
    test "returns 400 when model is missing", %{conn: conn} do
      {raw_key, _} = create_api_key([:messages])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{
          "messages" => [%{"role" => "user", "content" => "hi"}]
        })

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "model"
    end

    test "returns 400 when messages array is empty", %{conn: conn} do
      {raw_key, _} = create_api_key([:messages])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{
          "model" => "claude-sonnet-4-20250514",
          "messages" => []
        })

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "messages"
    end

    test "returns 403 and halts when api_key lacks messages scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{"messages" => []})

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "permission_error"
      assert body["error"]["message"] =~ "messages"
    end

    test "proceeds past scope check when messages scope present", %{conn: conn} do
      {raw_key, _} = create_api_key([:messages])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{
          "model" => "claude-sonnet-4-20250514",
          "messages" => [%{"role" => "user", "content" => "hi"}]
        })

      refute conn.status == 403
    end

    test "returns 422 when no provider found for model", %{conn: conn} do
      {raw_key, _} = create_api_key([:messages])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{
          "model" => "nonexistent-model-xyz",
          "messages" => [%{"role" => "user", "content" => "hi"}],
          "stream" => false
        })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "provider"
    end

    test "does not crash when content block is missing 'text' key", %{conn: conn} do
      # Tests extract_text_from_blocks/1 nil-safety: block["text"] || "" fallback
      {raw_key, _} = create_api_key([:messages])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{
          "model" => "claude-sonnet-4-20250514",
          "messages" => [
            %{
              "role" => "user",
              "content" => [%{"type" => "text"}, %{"type" => "text", "text" => "hello"}]
            }
          ]
        })

      refute conn.status == 403
    end
  end

  # ── ImagesController ───────────────────────────────────────────────────────

  describe "POST /api/v1/images/generations" do
    test "returns 403 and halts when api_key lacks images scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/images/generations", %{"prompt" => "a cat"})

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "permission_error"
      assert body["error"]["message"] =~ "images"
    end

    test "returns 400 when model is missing", %{conn: conn} do
      {raw_key, _} = create_api_key([:images])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/images/generations", %{"prompt" => "a cat"})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "model"
      assert body["error"]["type"] == "invalid_request_error"
    end

    test "returns 422 when no provider found for model", %{conn: conn} do
      {raw_key, _} = create_api_key([:images])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/images/generations", %{
          "model" => "dall-e-3",
          "prompt" => "a cat"
        })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "provider" or body["error"]["message"] =~ "model"
      assert body["error"]["type"] == "invalid_request_error"
    end
  end

  # ── OcrController ─────────────────────────────────────────────────────────

  describe "POST /api/v1/ocr" do
    test "returns 403 and halts when api_key lacks ocr scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/ocr", %{"model" => "gpt-4o"})

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "permission_error"
      assert body["error"]["message"] =~ "ocr"
    end
  end

  # ── ModelsController ──────────────────────────────────────────────────────

  describe "GET /api/v1/models" do
    test "returns 403 and halts when api_key lacks models_list scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/models")

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "permission_error"
      assert body["error"]["message"] =~ "models_list"
    end

    test "returns model list when scope is present", %{conn: conn} do
      {raw_key, _} = create_api_key([:models_list])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/models")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["object"] == "list"
      assert is_list(body["data"])
    end
  end

  # ── AgentController ────────────────────────────────────────────────────────

  describe "GET /api/v1/agents" do
    test "returns 403 and halts when api_key lacks agents scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/agents")

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "permission_error"
      assert body["error"]["message"] =~ "agents"
    end

    test "proceeds past scope check when agents scope present", %{conn: conn} do
      {raw_key, _} = create_api_key([:agents])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/agents")

      refute conn.status == 403
    end
  end

  describe "GET /api/v1/agents/:agent_slug" do
    test "returns 403 and halts when api_key lacks agents scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/agents/my-agent")

      assert conn.status == 403
      assert conn.halted
    end

    test "returns 404 when agent slug does not exist", %{conn: conn} do
      {raw_key, _} = create_api_key([:agents])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/agents/nonexistent-agent")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "not_found_error"
    end
  end

  describe "GET /api/v1/agents/:agent_slug/tools" do
    test "returns 403 when api_key lacks agents scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/agents/my-agent/tools")

      assert conn.status == 403
      assert conn.halted
    end

    test "returns 404 when agent does not exist", %{conn: conn} do
      {raw_key, _} = create_api_key([:agents])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/agents/nonexistent-agent/tools")

      assert conn.status == 404
    end
  end

  describe "POST /api/v1/agents/:agent_slug/chat" do
    test "returns 403 when api_key lacks agents scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/agents/my-agent/chat", %{
          "messages" => [%{"role" => "user", "content" => "hello"}]
        })

      assert conn.status == 403
      assert conn.halted
    end

    test "returns 400 when messages array is empty", %{conn: conn} do
      {raw_key, _} = create_api_key([:agents])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/agents/my-agent/chat", %{"messages" => []})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "messages"
    end

    test "returns 404 when agent does not exist", %{conn: conn} do
      {raw_key, _} = create_api_key([:agents])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/agents/nonexistent-agent/chat", %{
          "messages" => [%{"role" => "user", "content" => "hello"}]
        })

      assert conn.status == 404
    end
  end

  # ── OCR additional tests ─────────────────────────────────────────────────

  describe "POST /api/v1/ocr - additional" do
    test "returns 400 when model is missing but has ocr scope", %{conn: conn} do
      {raw_key, _} = create_api_key([:ocr])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/ocr", %{})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "model" or body["error"]["message"] =~ "OCR"
    end

    test "returns 422 when model has no matching provider", %{conn: conn} do
      {raw_key, _} = create_api_key([:ocr])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/ocr", %{"model" => "nonexistent-vision-model"})

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "invalid_request_error"
      assert body["error"]["message"] =~ "provider"
    end
  end

  # ── Authentication tests ─────────────────────────────────────────────────

  describe "API authentication" do
    test "returns 401 when no auth header is provided", %{conn: conn} do
      conn = get(conn, "/api/v1/models")

      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "authentication_error"
    end

    test "returns 401 for invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer gsk_invalid_key_that_does_not_exist_1234")
        |> get("/api/v1/models")

      assert conn.status == 401
    end

    test "x-api-key header works for authentication", %{conn: conn} do
      {raw_key, _} = create_api_key([:models_list])

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> get("/api/v1/models")

      assert conn.status == 200
    end
  end

  # ── Tool passthrough ─────────────────────────────────────────────────

  describe "tool passthrough" do
    test "chat/completions accepts tools array without crashing", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      tools = [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_weather",
            "description" => "Get weather for a location",
            "parameters" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{"type" => "string"}
              },
              "required" => ["location"]
            }
          }
        }
      ]

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "model" => "gpt-4o",
          "messages" => [%{"role" => "user", "content" => "What's the weather?"}],
          "tools" => tools,
          "tool_choice" => "auto"
        })

      # Should not crash — may fail on provider, not on tool parsing
      refute conn.status == 500
    end

    test "messages accepts tools array without crashing", %{conn: conn} do
      {raw_key, _} = create_api_key([:messages])

      tools = [
        %{
          "name" => "get_weather",
          "description" => "Get weather for a location",
          "input_schema" => %{
            "type" => "object",
            "properties" => %{
              "location" => %{"type" => "string"}
            },
            "required" => ["location"]
          }
        }
      ]

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/messages", %{
          "model" => "claude-sonnet-4-20250514",
          "messages" => [%{"role" => "user", "content" => "What's the weather?"}],
          "tools" => tools
        })

      # Should not crash — may fail on provider, not on tool parsing
      refute conn.status == 500
    end
  end

  # ── Nil content safety ─────────────────────────────────────────────────

  describe "nil content safety" do
    test "chat/completions does not crash when message content is nil", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "model" => "gpt-4o",
          "messages" => [%{"role" => "user"}]
        })

      # Should not crash — may fail on provider resolution, not on nil content
      refute conn.status == 500
    end

    test "chat/completions does not crash when system message content is nil", %{conn: conn} do
      {raw_key, _} = create_api_key([:chat_completions])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/chat/completions", %{
          "model" => "gpt-4o",
          "messages" => [
            %{"role" => "system"},
            %{"role" => "user", "content" => "hi"}
          ]
        })

      # Should not crash with ArgumentError on nil string concatenation
      refute conn.status == 500
    end

    test "agent chat does not crash when message content is nil", %{conn: conn} do
      {raw_key, _} = create_api_key([:agents])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/agents/some-agent/chat", %{
          "messages" => [%{"role" => "user"}]
        })

      # Should return 404 (agent not found), not 500 (crash)
      assert conn.status == 404
    end
  end
end
