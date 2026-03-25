defmodule GsmlgAppAdminWeb.AiProviderCrudTest do
  @moduledoc """
  LiveView CRUD interaction tests for AI Provider admin pages.

  Tests create, edit, and delete operations through the LiveView UI
  for system prompts, memories, and tools.
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
        email: "crud_test_#{System.unique_integer([:positive])}@example.com",
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

  # ── System Prompt Template CRUD ─────────────────────────────────────────

  describe "system prompt template CRUD" do
    test "creates a new template via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/system-prompts/new")

      assert render(view) =~ "New Template"

      view
      |> form("#template-form", %{
        "form" => %{
          "name" => "Test Prompt",
          "slug" => "test-prompt",
          "content" => "You are a helpful assistant.",
          "is_default" => "false",
          "is_active" => "true",
          "priority" => "5"
        }
      })
      |> render_submit()

      # Verify in database (form patches back to index)
      {:ok, templates} = AI.list_system_prompt_templates()
      template = Enum.find(templates, &(&1.slug == "test-prompt"))
      assert template
      assert template.name == "Test Prompt"
      assert template.priority == 5
    end

    test "edits an existing template", %{conn: conn, user: user} do
      {:ok, template} =
        AI.create_system_prompt_template(%{
          name: "Original Name",
          slug: "edit-test",
          content: "Original content",
          is_default: false,
          is_active: true,
          priority: 0
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/system-prompts/#{template.id}/edit")

      assert render(view) =~ "Edit Template"

      view
      |> form("#template-form", %{
        "form" => %{
          "name" => "Updated Name",
          "content" => "Updated content",
          "is_default" => "true",
          "is_active" => "true",
          "priority" => "10"
        }
      })
      |> render_submit()

      # Verify in database
      updated = AI.get_system_prompt_template!(template.id)
      assert updated.name == "Updated Name"
      assert updated.content == "Updated content"
      assert updated.is_default == true
      assert updated.priority == 10
    end

    test "deletes a template", %{conn: conn, user: user} do
      {:ok, template} =
        AI.create_system_prompt_template(%{
          name: "To Delete",
          slug: "delete-me",
          content: "Will be deleted",
          is_default: false,
          is_active: true,
          priority: 0
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/system-prompts")

      assert html =~ "To Delete"

      view
      |> element("#template-#{template.id} button[phx-click=delete]")
      |> render_click()

      # Verify deleted from database
      {:ok, templates} = AI.list_system_prompt_templates()
      refute Enum.any?(templates, &(&1.id == template.id))
    end

    test "shows template details on index page", %{conn: conn, user: user} do
      {:ok, _template} =
        AI.create_system_prompt_template(%{
          name: "Detailed Template",
          slug: "detailed",
          content: "System prompt with details",
          is_default: true,
          is_active: true,
          priority: 3
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/system-prompts")

      assert html =~ "Detailed Template"
      assert html =~ "detailed"
      assert html =~ "Default"
      assert html =~ "Active"
      assert html =~ "System prompt with details"
    end
  end

  # ── Memory CRUD ─────────────────────────────────────────────────────────

  describe "memory CRUD" do
    test "creates a new global memory via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/memories/new")

      assert render(view) =~ "New Memory"

      view
      |> form("#memory-form", %{
        "form" => %{
          "content" => "The user prefers concise answers.",
          "category" => "preference",
          "scope" => "global",
          "priority" => "5"
        }
      })
      |> render_submit()

      # Verify in database
      {:ok, memories} = AI.list_memories()
      memory = Enum.find(memories, &(&1.content == "The user prefers concise answers."))
      assert memory
      assert memory.category == :preference
      assert memory.scope == :global
      assert memory.priority == 5
    end

    test "edits an existing memory", %{conn: conn, user: user} do
      {:ok, memory} =
        AI.create_memory(%{
          content: "Original memory content",
          category: :fact,
          scope: :global,
          priority: 0
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/memories/#{memory.id}/edit")

      assert render(view) =~ "Edit Memory"

      view
      |> form("#memory-form", %{
        "form" => %{
          "content" => "Updated memory content",
          "category" => "instruction",
          "scope" => "global",
          "priority" => "10"
        }
      })
      |> render_submit()

      updated = AI.get_memory!(memory.id)
      assert updated.content == "Updated memory content"
      assert updated.category == :instruction
      assert updated.priority == 10
    end

    test "deletes a memory", %{conn: conn, user: user} do
      {:ok, memory} =
        AI.create_memory(%{
          content: "Memory to delete",
          category: :fact,
          scope: :global,
          priority: 0
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/memories")

      assert html =~ "Memory to delete"

      view
      |> element("#memory-#{memory.id} button[phx-click=delete]")
      |> render_click()

      html = render(view)
      refute html =~ "Memory to delete"
    end

    test "displays scope and category badges", %{conn: conn, user: user} do
      {:ok, _memory} =
        AI.create_memory(%{
          content: "A global fact for display test",
          category: :fact,
          scope: :global,
          priority: 3
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/memories")

      assert html =~ "global"
      assert html =~ "fact"
      assert html =~ "A global fact for display test"
    end
  end

  # ── Tool CRUD ───────────────────────────────────────────────────────────

  describe "tool CRUD" do
    test "creates a new webhook tool via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/tools/new")

      assert render(view) =~ "New Tool"

      view
      |> form("#tool-form", %{
        "form" => %{
          "name" => "Weather API",
          "slug" => "weather-api",
          "description" => "Fetches weather data",
          "execution_type" => "webhook",
          "webhook_url" => "https://api.weather.example.com/current",
          "webhook_method" => "get",
          "timeout_ms" => "15000",
          "is_active" => "true"
        }
      })
      |> render_submit()

      {:ok, tools} = AI.list_tools()
      tool = Enum.find(tools, &(&1.slug == "weather-api"))
      assert tool
      assert tool.execution_type == :webhook
      assert tool.webhook_url == "https://api.weather.example.com/current"
      assert tool.timeout_ms == 15_000
    end

    test "creates a builtin tool", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/tools/new")

      view
      |> form("#tool-form", %{
        "form" => %{
          "name" => "Calculator",
          "slug" => "calculator",
          "description" => "Performs calculations",
          "execution_type" => "builtin",
          "builtin_handler" => "MyApp.Tools.Calculator.run",
          "timeout_ms" => "5000",
          "is_active" => "true"
        }
      })
      |> render_submit()

      {:ok, tools} = AI.list_tools()
      tool = Enum.find(tools, &(&1.slug == "calculator"))
      assert tool
      assert tool.execution_type == :builtin
      assert tool.builtin_handler == "MyApp.Tools.Calculator.run"
    end

    test "edits an existing tool", %{conn: conn, user: user} do
      {:ok, tool} =
        AI.create_tool(%{
          name: "Original Tool",
          slug: "edit-tool-test",
          description: "Original description",
          execution_type: :webhook,
          webhook_url: "https://old.example.com",
          webhook_method: :post,
          timeout_ms: 30_000,
          is_active: true
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/tools/#{tool.id}/edit")

      assert render(view) =~ "Edit Tool"

      view
      |> form("#tool-form", %{
        "form" => %{
          "name" => "Updated Tool",
          "description" => "Updated description",
          "execution_type" => "webhook",
          "webhook_url" => "https://new.example.com/api",
          "webhook_method" => "put",
          "timeout_ms" => "10000",
          "is_active" => "true"
        }
      })
      |> render_submit()

      updated = AI.get_tool!(tool.id)
      assert updated.name == "Updated Tool"
      assert updated.description == "Updated description"
      assert updated.webhook_url == "https://new.example.com/api"
      assert updated.webhook_method == :put
      assert updated.timeout_ms == 10_000
    end

    test "deletes a tool", %{conn: conn, user: user} do
      {:ok, tool} =
        AI.create_tool(%{
          name: "Tool to Delete",
          slug: "delete-tool-test",
          description: "A tool that will be deleted",
          execution_type: :webhook,
          webhook_url: "https://example.com",
          webhook_method: :post,
          timeout_ms: 30_000,
          is_active: true
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/tools")

      assert html =~ "Tool to Delete"

      view
      |> element("#tool-#{tool.id} button[phx-click=delete]")
      |> render_click()

      html = render(view)
      refute html =~ "Tool to Delete"
    end

    test "displays tool details on index page", %{conn: conn, user: user} do
      {:ok, _tool} =
        AI.create_tool(%{
          name: "Visible Tool",
          slug: "visible-tool",
          description: "This tool should be visible",
          execution_type: :webhook,
          webhook_url: "https://example.com",
          webhook_method: :post,
          timeout_ms: 30_000,
          is_active: true
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/tools")

      assert html =~ "Visible Tool"
      assert html =~ "visible-tool"
      assert html =~ "webhook"
      assert html =~ "Active"
      assert html =~ "This tool should be visible"
    end
  end
end
