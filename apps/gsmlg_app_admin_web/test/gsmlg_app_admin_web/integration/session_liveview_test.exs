defmodule GsmlgAppAdminWeb.Integration.SessionLiveViewTest do
  use GsmlgAppAdminWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GsmlgAppAdminWeb.Session.Store

  @moduletag :integration

  @password "Password123!"

  setup do
    # Clean up sessions before each test
    :ets.delete_all_objects(Store.table_name())

    # Create a test user
    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "liveview_test@example.com",
        password: @password
      })
      |> Ash.create(authorize?: false)

    {:ok, user: user}
  end

  describe "LiveView session integration" do
    test "authenticated user can access LiveView pages", %{conn: conn, user: user} do
      # Sign in first
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => @password
          }
        })

      # Verify sign-in was successful
      assert redirected_to(conn) == "/"

      # Access a LiveView page (users management)
      {:ok, _view, html} =
        conn
        |> recycle()
        |> live("/users")

      # Verify the page loads successfully
      assert html =~ "User Management" or html =~ "Users"
    end

    test "unauthenticated user accessing LiveView gets redirected to sign-in", %{conn: conn} do
      # Access LiveView without signing in
      conn = init_test_session(conn, %{})

      # Should redirect to sign-in with return_to parameter
      {:error, {:redirect, %{to: redirect_url}}} = live(conn, "/users")

      assert redirect_url =~ "/sign-in"
      assert redirect_url =~ "return_to"
    end

    test "session user is available in LiveView socket assigns", %{conn: conn, user: user} do
      # Sign in
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => @password
          }
        })

      # Verify session was stored
      session_user = get_session(conn, "user")
      assert session_user != nil
      assert String.contains?(session_user, user.id)

      # Access LiveView page
      {:ok, view, _html} =
        conn
        |> recycle()
        |> live("/users")

      # The LiveView should have access to the session
      # We can't directly check socket.assigns in tests, but we verified:
      # 1. Session contains user subject
      # 2. LiveView page loads successfully
      # 3. LiveUserAuth reads from session to assign current_user

      # Verify view is still connected (session maintained)
      assert render(view) =~ "User"
    end

    test "session persists across LiveView navigation", %{conn: conn, user: user} do
      # Sign in
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => @password
          }
        })

      # Access first LiveView page
      {:ok, _view, html1} =
        conn
        |> recycle()
        |> live("/users")

      # Verify the first page loads with user content
      assert html1 =~ "User"

      # Access another LiveView page (new connection but same session)
      {:ok, _view2, html2} =
        conn
        |> recycle()
        |> live("/chat")

      # Verify second page loads - session is maintained
      assert html2 =~ "Chat" or html2 =~ "AI" or html2 =~ "Conversation"
    end
  end

  describe "session count after LiveView access" do
    test "session count reflects active sessions", %{conn: conn, user: user} do
      initial_count = Store.count()

      # Sign in
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => @password
          }
        })

      # Session count should have increased
      assert Store.count() > initial_count

      # Access LiveView
      {:ok, _view, _html} =
        conn
        |> recycle()
        |> live("/users")

      # Session should still be maintained
      assert Store.count() > initial_count
    end
  end
end
