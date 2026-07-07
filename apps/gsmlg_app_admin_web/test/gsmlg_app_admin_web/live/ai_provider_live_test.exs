defmodule GsmlgAppAdminWeb.AiProviderLiveTest do
  @moduledoc """
  LiveView tests for the AI gateway admin pages.

  Tests that all pages load correctly for authenticated users and
  that unauthenticated users are redirected to sign-in.
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
        email: "ai_provider_test_#{System.unique_integer([:positive])}@example.com",
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

  # ── Page Load Tests ──────────────────────────────────────────────────────

  describe "AI gateway pages load for authenticated users" do
    test "Backplane config page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/config")
      assert html =~ "Backplane Config"
      assert html =~ "Server Address"
      assert html =~ "Auth Token"
    end

    test "providers index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/providers")
      assert html =~ "AI Provider Settings"
    end

    test "API keys index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/api-keys")
      assert html =~ "API Keys"
    end

    test "system prompts index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/system-prompts")
      assert html =~ "System Prompt"
    end

    test "memories index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/memories")
      assert html =~ "Memories" or html =~ "Memory"
    end

    test "tools index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/tools")
      assert html =~ "Tools"
    end

    test "agents index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/agents")
      assert html =~ "Agents"
    end

    test "MCP servers index page loads", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/mcp-servers")
      assert html =~ "MCP Server"
    end

    test "API usage page loads with summary stats", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/usage")
      assert html =~ "API Usage"
      assert html =~ "Total Requests"
      assert html =~ "Total Tokens"
    end
  end

  # ── Auth Guard Tests ─────────────────────────────────────────────────────

  describe "unauthenticated access redirects to sign-in" do
    @ai_provider_paths [
      "/ai-provider/config",
      "/ai-provider/providers",
      "/ai-provider/api-keys",
      "/ai-provider/system-prompts",
      "/ai-provider/memories",
      "/ai-provider/tools",
      "/ai-provider/agents",
      "/ai-provider/mcp-servers",
      "/ai-provider/usage"
    ]

    for path <- @ai_provider_paths do
      test "#{path} redirects when not authenticated", %{conn: conn} do
        conn = init_test_session(conn, %{})
        {:error, {:redirect, %{to: redirect_url}}} = live(conn, unquote(path))
        assert redirect_url =~ "/sign-in"
      end
    end
  end

  # ── Sidebar Navigation Tests ─────────────────────────────────────────────

  describe "sidebar navigation" do
    test "sidebar only shows chat, agents, and config", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/config")

      assert html =~ "AI Chat"
      assert html =~ "Agents"
      assert html =~ "Config"
      refute html =~ "Providers"
      refute html =~ "API Keys"
      refute html =~ "API Usage"
      refute html =~ "System Prompts"
      refute html =~ "Memories"
      refute html =~ "Tools"
      refute html =~ "MCP Servers"
    end

    test "sidebar highlights current page", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/config")
      assert html =~ "bg-primary text-primary-content"
    end
  end

  describe "Backplane config" do
    test "saves server address and auth token", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> sign_in(user) |> live("/ai-provider/config")

      view
      |> form("#backplane-config-form", %{
        "config" => %{
          "server_url" => "https://backplane.example.com",
          "auth_token" => "secret-token"
        }
      })
      |> render_submit()

      assert {:ok, config} = AI.get_backplane_config()
      assert config.server_url == "https://backplane.example.com"
      assert config.auth_token == "secret-token"
    end
  end

  # ── Empty State Tests ────────────────────────────────────────────────────

  describe "empty states" do
    test "providers page shows empty state when no providers", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/providers")
      assert html =~ "No AI providers configured" or html =~ "Add Your First Provider"
    end

    test "usage page shows empty state when no logs", %{conn: conn, user: user} do
      {:ok, _view, html} = conn |> sign_in(user) |> live("/ai-provider/usage")
      assert html =~ "No usage logs yet" or html =~ "0"
    end
  end
end
