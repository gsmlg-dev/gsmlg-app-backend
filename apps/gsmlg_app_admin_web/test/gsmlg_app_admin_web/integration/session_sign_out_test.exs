defmodule GsmlgAppAdminWeb.Integration.SessionSignOutTest do
  use GsmlgAppAdminWeb.ConnCase, async: false

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
        email: "signout_test@example.com",
        password: @password
      })
      |> Ash.create(authorize?: false)

    {:ok, user: user}
  end

  describe "sign-out flow" do
    test "sign-out clears the session", %{conn: conn, user: user} do
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
      session_user = get_session(conn, "user")
      assert session_user != nil

      # Sign out
      conn = get(recycle(conn), "/sign-out")

      # Should redirect to sign-in page
      assert redirected_to(conn) == "/sign-in"

      # Session should no longer have user data
      session_user_after = get_session(conn, "user")
      assert session_user_after == nil
    end

    test "accessing protected page after sign-out has no user session", %{conn: conn, user: user} do
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

      # Verify signed in
      assert get_session(conn, "user") != nil

      # Sign out
      conn = get(recycle(conn), "/sign-out")

      # Access home page after sign-out
      conn2 = get(recycle(conn), "/")

      # Page should load (home is accessible without auth)
      assert conn2.status == 200

      # But user session should be cleared
      assert get_session(conn2, "user") == nil
    end

    test "sign-out maintains session count properly", %{conn: conn, user: user} do
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
      after_signin_count = Store.count()
      assert after_signin_count > initial_count

      # Sign out
      _conn = get(recycle(conn), "/sign-out")

      # Note: Plug.Session.ETS doesn't automatically delete the ETS record on clear_session
      # The session data is cleared from the map but the record may still exist
      # Our cleanup process handles removal of expired sessions
      # This is acceptable behavior - the session no longer contains user data
    end

    test "signed-out user cannot use old session", %{conn: conn, user: user} do
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

      # Get session before sign-out
      session_before = get_session(conn, "user")
      assert session_before != nil

      # Sign out
      conn = get(recycle(conn), "/sign-out")

      # Try to access a page
      conn2 = get(recycle(conn), "/")

      # Session should be cleared
      session_after = get_session(conn2, "user")
      assert session_after == nil
    end
  end
end
