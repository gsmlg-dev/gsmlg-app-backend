defmodule GsmlgAppAdminWeb.AuthControllerTest do
  use GsmlgAppAdminWeb.ConnCase

  describe "POST /auth/email/default/sign_in" do
    test "user can sign in with valid credentials", %{conn: conn} do
      # Create a test user
      admin_actor = %{is_admin: true}

      user_attrs = %{
        email: "login@example.com",
        password: "validpassword123",
        first_name: "Login",
        last_name: "User",
        username: "loginuser",
        display_name: "Login User"
      }

      {:ok, _user} = GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, user_attrs)
      |> Ash.create(actor: admin_actor)

      # Test login
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/auth/email/default/sign_in", %{
          "email" => "login@example.com",
          "password" => "validpassword123"
        })

      # Should redirect or return success
      assert conn.status == 302 or conn.status == 200
    end

    test "login fails with invalid credentials", %{conn: conn} do
      # Test login with invalid credentials
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/auth/email/default/sign_in", %{
          "email" => "nonexistent@example.com",
          "password" => "wrongpassword"
        })

      # Should return error
      assert conn.status in [401, 422]
    end
  end

  describe "JWT Token Configuration" do
    test "JWT configuration is available in web environment" do
      jwt_config = Application.get_env(:ash_authentication, :jwt)
      assert jwt_config != nil
      assert Keyword.has_key?(jwt_config, :signing_secret)

      signing_secret = Keyword.get(jwt_config, :signing_secret)
      assert is_binary(signing_secret)
      assert String.length(signing_secret) > 0
    end
  end
end