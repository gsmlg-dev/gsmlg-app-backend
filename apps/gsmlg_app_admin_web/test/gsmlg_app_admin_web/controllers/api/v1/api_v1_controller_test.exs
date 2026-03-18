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
  end

  # ── MessagesController ─────────────────────────────────────────────────────

  describe "POST /api/v1/messages" do
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

    test "returns error when model is missing", %{conn: conn} do
      {raw_key, _} = create_api_key([:images])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/images/generations", %{"prompt" => "a cat"})

      assert conn.status == 500
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "model"
    end

    test "returns provider error when model not found", %{conn: conn} do
      {raw_key, _} = create_api_key([:images])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/images/generations", %{
          "model" => "dall-e-3",
          "prompt" => "a cat"
        })

      assert conn.status == 500
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "provider" or body["error"]["message"] =~ "model"
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
  end
end
