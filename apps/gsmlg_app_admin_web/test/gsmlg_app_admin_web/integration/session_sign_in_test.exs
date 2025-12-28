defmodule GsmlgAppAdminWeb.Integration.SessionSignInTest do
  use GsmlgAppAdminWeb.ConnCase, async: false

  alias GsmlgAppAdminWeb.Session.Store

  @moduletag :integration

  @password "Password123!"

  setup do
    # Clean up sessions before each test
    :ets.delete_all_objects(Store.table_name())

    # Create a test user with admin_create action
    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "test@example.com",
        password: @password
      })
      |> Ash.create(authorize?: false)

    {:ok, user: user}
  end

  describe "sign-in flow" do
    test "successful sign-in stores session in ETS", %{conn: conn, user: user} do
      # Get initial session count
      initial_count = Store.count()

      # Simulate successful authentication by going through the auth callback
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => @password
          }
        })

      # Should redirect to home page
      assert redirected_to(conn) == "/"

      # Verify session was created in ETS (count increased)
      assert Store.count() > initial_count
    end

    test "session persists across requests after sign-in", %{conn: conn, user: user} do
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

      # Verify sign-in was successful
      assert redirected_to(conn) == "/"

      # Get the session user from the first request
      first_session_user = get_session(conn, "user")
      assert first_session_user != nil

      # Follow the redirect and make another request
      recycled_conn = recycle(conn)
      conn2 = get(recycled_conn, "/")

      # Verify session is maintained
      second_session_user = get_session(conn2, "user")
      assert second_session_user != nil
      assert second_session_user == first_session_user

      # The current_user is loaded by SessionUser plug based on session
      # This verifies the session was properly persisted via the ETS store
    end

    test "session contains user subject after sign-in", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => @password
          }
        })

      # Get the session from the connection
      session_user = get_session(conn, "user")

      # Verify user subject is stored
      assert session_user != nil
      assert is_binary(session_user)
      assert String.contains?(session_user, user.id)
    end

    test "failed sign-in does not create authenticated session", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{})
        |> post("/auth/user/default/sign_in", %{
          "user" => %{
            "email" => to_string(user.email),
            "password" => "WrongPassword123!"
          }
        })

      # Should return 401
      assert conn.status == 401

      # Session should not contain user data
      assert get_session(conn, "user") == nil
    end
  end

  describe "protected pages" do
    test "authenticated user can access protected pages", %{conn: conn, user: user} do
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

      # Access home page following the redirect
      conn2 = get(recycle(conn), "/")

      assert conn2.status == 200

      # Verify session is maintained
      session_user = get_session(conn2, "user")
      assert session_user != nil
      assert String.contains?(session_user, user.id)
    end
  end
end
