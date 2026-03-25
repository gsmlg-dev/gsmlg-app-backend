defmodule GsmlgAppAdminWeb.AiProviderCrudExtendedTest do
  @moduledoc """
  LiveView CRUD interaction tests for API Keys, Agents, and MCP Servers.

  Extends the base CRUD test suite to cover the remaining admin pages
  that were not previously tested with create, edit, and delete operations.
  """

  use GsmlgAppAdminWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdminWeb.Session.Store

  @password "TestPassword123!"

  setup do
    :ets.delete_all_objects(Store.table_name())

    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "crud_ext_#{System.unique_integer([:positive])}@example.com",
        password: @password
      })
      |> Ash.create(authorize?: false)

    {:ok, user: user}
  end

  defp sign_in(conn, user) do
    conn
    |> init_test_session(%{})
    |> post("/auth/user/default/sign_in", %{
      "user" => %{
        "email" => to_string(user.email),
        "password" => @password
      }
    })
    |> recycle()
  end

  # ── API Key CRUD ───────────────────────────────────────────────────────

  describe "API key CRUD" do
    test "creates a new API key via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/api-keys/new")

      assert render(view) =~ "New API Key"

      view
      |> form("#api-key-form", %{
        "form" => %{
          "name" => "Test Gateway Key",
          "description" => "Key for testing",
          "scopes" => ["chat_completions", "messages"]
        }
      })
      |> render_submit()

      {:ok, api_keys} = AI.list_api_keys()
      key = Enum.find(api_keys, &(&1.name == "Test Gateway Key"))
      assert key
      assert :chat_completions in key.scopes
      assert :messages in key.scopes
    end

    test "edits an existing API key", %{conn: conn, user: user} do
      {:ok, api_key} =
        AI.create_api_key(%{
          name: "Original Key",
          scopes: [:chat_completions],
          user_id: user.id
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/api-keys/#{api_key.id}/edit")

      assert render(view) =~ "Edit API Key"

      view
      |> form("#api-key-form", %{
        "form" => %{
          "name" => "Updated Key Name",
          "description" => "Updated description",
          "scopes" => ["chat_completions", "images", "models_list"]
        }
      })
      |> render_submit()

      updated = AI.get_api_key!(api_key.id)
      assert updated.name == "Updated Key Name"
      assert updated.description == "Updated description"
      assert :images in updated.scopes
    end

    test "revokes an API key", %{conn: conn, user: user} do
      {:ok, api_key} =
        AI.create_api_key(%{
          name: "Key to Revoke",
          scopes: [:chat_completions],
          user_id: user.id
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/api-keys")

      assert html =~ "Key to Revoke"
      assert html =~ "Active"

      view
      |> element("#key-#{api_key.id} button[phx-click=revoke]")
      |> render_click()

      revoked = AI.get_api_key!(api_key.id)
      refute revoked.is_active
    end

    test "deletes an API key", %{conn: conn, user: user} do
      {:ok, api_key} =
        AI.create_api_key(%{
          name: "Key to Delete",
          scopes: [:chat_completions],
          user_id: user.id
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/api-keys")

      assert html =~ "Key to Delete"

      view
      |> element("#key-#{api_key.id} button[phx-click=delete]")
      |> render_click()

      {:ok, api_keys} = AI.list_api_keys()
      refute Enum.any?(api_keys, &(&1.id == api_key.id))
    end

    test "displays key details on index page", %{conn: conn, user: user} do
      {:ok, _api_key} =
        AI.create_api_key(%{
          name: "Visible Key",
          scopes: [:chat_completions, :images],
          user_id: user.id
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/api-keys")

      assert html =~ "Visible Key"
      assert html =~ "Active"
      assert html =~ "gsk_"
    end
  end

  # ── Agent CRUD ─────────────────────────────────────────────────────────

  describe "agent CRUD" do
    test "creates a new agent via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/agents/new")

      assert render(view) =~ "New Agent"

      view
      |> form("#agent-form", %{
        "form" => %{
          "name" => "Test Agent",
          "slug" => "test-agent",
          "description" => "An agent for testing",
          "system_prompt" => "You are a test agent.",
          "max_iterations" => "5",
          "tool_choice" => "auto",
          "is_active" => "true"
        }
      })
      |> render_submit()

      {:ok, agents} = AI.list_agents()
      agent = Enum.find(agents, &(&1.slug == "test-agent"))
      assert agent
      assert agent.name == "Test Agent"
      assert agent.max_iterations == 5
      assert agent.tool_choice == "auto"
    end

    test "edits an existing agent", %{conn: conn, user: user} do
      {:ok, agent} =
        AI.create_agent(%{
          name: "Original Agent",
          slug: "edit-agent-test",
          description: "Original description",
          max_iterations: 10,
          tool_choice: "auto",
          is_active: true
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/agents/#{agent.id}/edit")

      assert render(view) =~ "Edit Agent"

      view
      |> form("#agent-form", %{
        "form" => %{
          "name" => "Updated Agent",
          "description" => "Updated description",
          "max_iterations" => "20",
          "tool_choice" => "required",
          "is_active" => "true"
        }
      })
      |> render_submit()

      updated = AI.get_agent!(agent.id)
      assert updated.name == "Updated Agent"
      assert updated.description == "Updated description"
      assert updated.max_iterations == 20
      assert updated.tool_choice == "required"
    end

    test "deletes an agent", %{conn: conn, user: user} do
      {:ok, agent} =
        AI.create_agent(%{
          name: "Agent to Delete",
          slug: "delete-agent-test",
          max_iterations: 10,
          tool_choice: "auto",
          is_active: true
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/agents")

      assert html =~ "Agent to Delete"

      view
      |> element("#agent-#{agent.id} button[phx-click=delete]")
      |> render_click()

      html = render(view)
      refute html =~ "Agent to Delete"
    end

    test "displays agent details on index page", %{conn: conn, user: user} do
      {:ok, _agent} =
        AI.create_agent(%{
          name: "Visible Agent",
          slug: "visible-agent",
          description: "This agent should be visible",
          model: "gpt-4o",
          max_iterations: 15,
          tool_choice: "required",
          is_active: true
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/agents")

      assert html =~ "Visible Agent"
      assert html =~ "visible-agent"
      assert html =~ "gpt-4o"
      assert html =~ "Active"
      assert html =~ "tool_choice: required"
      assert html =~ "This agent should be visible"
    end
  end

  # ── MCP Server CRUD ───────────────────────────────────────────────────

  describe "MCP server CRUD" do
    test "creates a new MCP server via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/mcp-servers/new")

      assert render(view) =~ "New MCP Server"

      view
      |> form("#mcp-server-form", %{
        "form" => %{
          "name" => "Test MCP",
          "slug" => "test-mcp",
          "description" => "A test MCP server",
          "transport_type" => "stdio",
          "connection_config_json" => ~s({"command": "npx", "args": ["-y", "test-server"]}),
          "is_active" => "true",
          "auto_sync_tools" => "true"
        }
      })
      |> render_submit()

      {:ok, servers} = AI.list_mcp_servers()
      server = Enum.find(servers, &(&1.slug == "test-mcp"))
      assert server
      assert server.name == "Test MCP"
      assert server.transport_type == :stdio
      assert server.auto_sync_tools == true
      assert server.connection_config["command"] == "npx"
    end

    test "edits an existing MCP server", %{conn: conn, user: user} do
      {:ok, server} =
        AI.create_mcp_server(%{
          name: "Original MCP",
          slug: "edit-mcp-test",
          transport_type: :stdio,
          connection_config: %{"command" => "old-cmd"},
          is_active: true,
          auto_sync_tools: true
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/mcp-servers/#{server.id}/edit")

      assert render(view) =~ "Edit MCP Server"

      view
      |> form("#mcp-server-form", %{
        "form" => %{
          "name" => "Updated MCP",
          "description" => "Updated description",
          "transport_type" => "sse",
          "connection_config_json" => ~s({"url": "https://mcp.example.com/sse"}),
          "is_active" => "true",
          "auto_sync_tools" => "false"
        }
      })
      |> render_submit()

      updated = AI.get_mcp_server!(server.id)
      assert updated.name == "Updated MCP"
      assert updated.transport_type == :sse
      assert updated.auto_sync_tools == false
      assert updated.connection_config["url"] == "https://mcp.example.com/sse"
    end

    test "deletes an MCP server", %{conn: conn, user: user} do
      {:ok, server} =
        AI.create_mcp_server(%{
          name: "MCP to Delete",
          slug: "delete-mcp-test",
          transport_type: :stdio,
          connection_config: %{"command" => "test"},
          is_active: true,
          auto_sync_tools: false
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/mcp-servers")

      assert html =~ "MCP to Delete"

      view
      |> element("#mcp-server-#{server.id} button[phx-click=delete]")
      |> render_click()

      html = render(view)
      refute html =~ "MCP to Delete"
    end

    test "displays MCP server details on index page", %{conn: conn, user: user} do
      {:ok, _server} =
        AI.create_mcp_server(%{
          name: "Visible MCP",
          slug: "visible-mcp",
          description: "This MCP server should be visible",
          transport_type: :sse,
          connection_config: %{"url" => "https://example.com"},
          is_active: true,
          auto_sync_tools: true
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/mcp-servers")

      assert html =~ "Visible MCP"
      assert html =~ "visible-mcp"
      assert html =~ "sse"
      assert html =~ "Auto-sync"
      assert html =~ "This MCP server should be visible"
    end
  end
end
