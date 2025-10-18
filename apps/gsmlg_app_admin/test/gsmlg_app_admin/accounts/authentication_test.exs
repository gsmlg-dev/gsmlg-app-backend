defmodule GsmlgAppAdmin.Accounts.AuthenticationTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.Accounts.User

  describe "JWT Configuration" do
    test "JWT configuration is loaded correctly" do
      # Test that JWT configuration is available
      jwt_config = Application.get_env(:ash_authentication, :jwt)
      assert jwt_config != nil
      assert Keyword.has_key?(jwt_config, :signing_secret)
    end

    test "token signing secret is configured" do
      # Test that token signing secret is configured
      jwt_config = Application.get_env(:ash_authentication, :jwt)
      assert jwt_config != nil
      signing_secret = Keyword.get(jwt_config, :signing_secret)
      assert signing_secret != nil
      assert is_binary(signing_secret)
      assert String.length(signing_secret) > 0
    end

    test "Ash authentication token signing secret is configured" do
      # Test that general Ash authentication token signing secret is configured
      token_config = Application.get_env(:ash_authentication, :token_signing_secret)
      assert token_config != nil
      assert is_binary(token_config)
      assert String.length(token_config) > 0
    end

    test "JWT configuration is consistent across environments" do
      # Test that JWT and token configs are consistent
      jwt_config = Application.get_env(:ash_authentication, :jwt)
      token_config = Application.get_env(:ash_authentication, :token_signing_secret)

      jwt_secret = Keyword.get(jwt_config, :signing_secret)
      assert jwt_secret == token_config
    end
  end

  describe "User Authentication Setup" do
    test "user can be created with admin_create action" do
      # Create a test user using the admin_create action
      admin_actor = %{is_admin: true}

      user_attrs = %{
        email: "test@example.com",
        password: "validpassword123",
        first_name: "Test",
        last_name: "User",
        username: "testuser",
        display_name: "Test User"
      }

      {:ok, user} = User |> Ash.Changeset.for_create(:admin_create, user_attrs) |> Ash.create(actor: admin_actor)

      assert to_string(user.email) == "test@example.com"
      assert user.username == "testuser"
      assert user.first_name == "Test"
      assert user.last_name == "User"
      assert user.display_name == "Test User"
      assert user.hashed_password != nil
      assert user.hashed_password != "validpassword123"  # Should be hashed
    end

    test "user password is properly hashed" do
      # Test that passwords are properly hashed
      admin_actor = %{is_admin: true}

      user_attrs = %{
        email: "hashed@example.com",
        password: "validpassword123",
        first_name: "Hashed",
        last_name: "User",
        username: "hasheduser",
        display_name: "Hashed User"
      }

      {:ok, user} = User |> Ash.Changeset.for_create(:admin_create, user_attrs) |> Ash.create(actor: admin_actor)

      # Password should be hashed and not equal to the plaintext password
      assert user.hashed_password != nil
      assert user.hashed_password != "validpassword123"
      assert String.starts_with?(user.hashed_password, "$2b$")  # Bcrypt hash format
    end

    test "user authentication setup is working" do
      # Test that users can be created and have proper authentication setup
      admin_actor = %{is_admin: true}

      user_attrs = %{
        email: "auth@example.com",
        password: "validpassword123",
        first_name: "Auth",
        last_name: "User",
        username: "authuser",
        display_name: "Auth User"
      }

      {:ok, user} = User |> Ash.Changeset.for_create(:admin_create, user_attrs) |> Ash.create(actor: admin_actor)

      # Verify user is created with authentication properties
      assert to_string(user.email) == "auth@example.com"
      assert user.hashed_password != nil
      assert user.hashed_password != "validpassword123"  # Should be hashed

      # Test that Bcrypt is working correctly
      assert Bcrypt.verify_pass("validpassword123", user.hashed_password)
    end
  end

  describe "Authentication Configuration" do
    test "authentication resource is properly configured" do
      # Test that the User resource has authentication enabled by checking it can be created
      admin_actor = %{is_admin: true}
      user_attrs = %{
        email: "config@example.com",
        password: "validpassword123",
        first_name: "Config",
        last_name: "User",
        username: "configuser",
        display_name: "Config User"
      }

      {:ok, user} = User |> Ash.Changeset.for_create(:admin_create, user_attrs) |> Ash.create(actor: admin_actor)
      assert user != nil
      assert user.email != nil
    end

    test "user resource has password hashing" do
      # Test that password hashing works correctly
      admin_actor = %{is_admin: true}
      user_attrs = %{
        email: "hash@example.com",
        password: "validpassword123",
        first_name: "Hash",
        last_name: "User",
        username: "hashuser",
        display_name: "Hash User"
      }

      {:ok, user} = User |> Ash.Changeset.for_create(:admin_create, user_attrs) |> Ash.create(actor: admin_actor)

      # Verify password is hashed with Bcrypt
      assert user.hashed_password != nil
      assert String.starts_with?(user.hashed_password, "$2b$")
      assert String.length(user.hashed_password) > 50  # Bcrypt hashes are typically 60 chars
    end
  end
end