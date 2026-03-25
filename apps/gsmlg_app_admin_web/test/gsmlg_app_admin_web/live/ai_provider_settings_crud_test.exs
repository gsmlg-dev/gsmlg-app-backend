defmodule GsmlgAppAdminWeb.AiProviderSettingsCrudTest do
  @moduledoc """
  LiveView CRUD tests for the Provider Settings admin pages.

  Tests create, edit, delete, and toggle active for AI providers,
  which use AshPhoenix.Form on separate pages (not modals).
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
        email: "provider_crud_#{System.unique_integer([:positive])}@example.com",
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

  describe "provider settings CRUD" do
    test "creates a new provider via form", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/providers/new")

      assert render(view) =~ "Add Provider"

      view
      |> form("#provider-form", %{
        "provider" => %{
          "name" => "Test Provider",
          "slug" => "test-provider",
          "api_base_url" => "https://api.test.example.com/v1",
          "api_key" => "sk-test-key-123",
          "model" => "gpt-4o"
        }
      })
      |> render_submit()

      {:ok, providers} = AI.list_providers()
      provider = Enum.find(providers, &(&1.slug == "test-provider"))
      assert provider
      assert provider.name == "Test Provider"
      assert provider.api_base_url == "https://api.test.example.com/v1"
      assert provider.model == "gpt-4o"
    end

    test "edits an existing provider", %{conn: conn, user: user} do
      {:ok, provider} =
        AI.create_provider(%{
          name: "Original Provider",
          slug: "edit-provider-test",
          api_base_url: "https://api.old.example.com/v1",
          api_key: "sk-old-key",
          model: "gpt-3.5-turbo"
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/providers/#{provider.id}/edit")

      assert render(view) =~ "Edit Provider"

      view
      |> form("#provider-form", %{
        "provider" => %{
          "name" => "Updated Provider",
          "api_base_url" => "https://api.new.example.com/v1",
          "model" => "gpt-4o-mini"
        }
      })
      |> render_submit()

      updated = AI.get_provider!(provider.id)
      assert updated.name == "Updated Provider"
      assert updated.api_base_url == "https://api.new.example.com/v1"
      assert updated.model == "gpt-4o-mini"
    end

    test "deletes a provider from index", %{conn: conn, user: user} do
      {:ok, provider} =
        AI.create_provider(%{
          name: "Provider to Delete",
          slug: "delete-provider-test",
          api_base_url: "https://api.delete.example.com/v1",
          api_key: "sk-delete-key",
          model: "gpt-4o"
        })

      {:ok, view, html} =
        conn |> sign_in(user) |> live("/ai-provider/providers")

      assert html =~ "Provider to Delete"

      view
      |> element("#provider-#{provider.id} button[phx-click=delete]")
      |> render_click()

      {:ok, providers} = AI.list_providers()
      refute Enum.any?(providers, &(&1.id == provider.id))
    end

    test "toggles provider active status", %{conn: conn, user: user} do
      {:ok, provider} =
        AI.create_provider(%{
          name: "Toggle Provider",
          slug: "toggle-provider-test",
          api_base_url: "https://api.toggle.example.com/v1",
          api_key: "sk-toggle-key",
          model: "gpt-4o",
          is_active: true
        })

      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/providers")

      # Toggle to inactive
      view
      |> element("#provider-#{provider.id} button[phx-click=toggle_active]")
      |> render_click()

      toggled = AI.get_provider!(provider.id)
      refute toggled.is_active

      # Toggle back to active
      view
      |> element("#provider-#{provider.id} button[phx-click=toggle_active]")
      |> render_click()

      re_toggled = AI.get_provider!(provider.id)
      assert re_toggled.is_active
    end

    test "displays provider details on index page", %{conn: conn, user: user} do
      {:ok, _provider} =
        AI.create_provider(%{
          name: "Visible Provider",
          slug: "visible-provider",
          api_base_url: "https://api.visible.example.com/v1",
          api_key: "sk-visible-key",
          model: "claude-sonnet-4-20250514",
          is_active: true
        })

      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/providers")

      assert html =~ "Visible Provider"
      assert html =~ "visible-provider"
      assert html =~ "claude-sonnet-4-20250514"
      assert html =~ "Active"
      assert html =~ "api.visible.example.com"
    end

    test "preset selection populates form fields", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn |> sign_in(user) |> live("/ai-provider/providers/new")

      # Select OpenAI preset
      view
      |> element("button[phx-click=select_preset][phx-value-preset=openai]")
      |> render_click()

      html = render(view)
      assert html =~ "api.openai.com"
    end

    test "shows empty state when no providers exist", %{conn: conn, user: user} do
      {:ok, _view, html} =
        conn |> sign_in(user) |> live("/ai-provider/providers")

      assert html =~ "No AI providers configured yet"
      assert html =~ "Add Your First Provider"
    end
  end
end
