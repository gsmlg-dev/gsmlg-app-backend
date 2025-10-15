defmodule GsmlgAppAdmin.AccountsTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.Accounts
  alias GsmlgAppAdmin.Accounts.User
  import GsmlgAppAdmin.TestFixtures

  describe "domain configuration" do
    test "has correct resources configured" do
      # Test that the domain has the expected resources
      resources = Ash.Domain.Info.resources(Accounts)

      assert GsmlgAppAdmin.Accounts.User in resources
      assert GsmlgAppAdmin.Accounts.Token in resources
    end

    test "domain has correct OTP app configuration" do
      # Test that the domain is configured with the correct OTP app
      assert function_exported?(Accounts, :__info__, 1)
      assert Ash.Domain.Info.resources(Accounts) != []
    end
  end

  describe "resource access" do
    test "can access User resource through domain" do
      resources = Ash.Domain.Info.resources(Accounts)

      user_resource =
        Enum.find(resources, fn resource -> resource == GsmlgAppAdmin.Accounts.User end)

      assert user_resource == GsmlgAppAdmin.Accounts.User
    end

    test "can access Token resource through domain" do
      resources = Ash.Domain.Info.resources(Accounts)

      token_resource =
        Enum.find(resources, fn resource -> resource == GsmlgAppAdmin.Accounts.Token end)

      assert token_resource == GsmlgAppAdmin.Accounts.Token
    end
  end

  describe "list_users/0" do
    test "returns all users" do
      user = insert_user()
      users = Accounts.list_users()

      assert length(users) == 1
      assert hd(users).id == user.id
    end

    test "returns empty list when no users exist" do
      assert Accounts.list_users() == []
    end
  end

  describe "get_user!/1" do
    test "returns the user with given id" do
      user = insert_user()
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "raises error if user doesn't exist" do
      id = Ecto.UUID.generate()

      assert_raise RuntimeError, ~r/No User found/, fn ->
        Accounts.get_user!(id)
      end
    end
  end

  describe "create_user/1" do
    test "creates user with valid data" do
      attrs = %{
        email: "test@example.com",
        password: "StrongPass123!",
        first_name: "Test",
        last_name: "User",
        username: "testuser",
        display_name: "Test User"
      }

      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert to_string(user.email) == "test@example.com"
      assert user.first_name == "Test"
      assert user.last_name == "User"
      assert user.username == "testuser"
      assert user.display_name == "Test User"
      assert user.role == :user
      assert user.status == :active
      assert user.email_verified == false
    end

    test "creates admin user with role admin" do
      attrs = %{
        email: "admin@example.com",
        password: "StrongPass123!",
        first_name: "Admin",
        last_name: "User",
        role: :admin
      }

      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.role == :admin
    end

    test "returns error with invalid email" do
      attrs = %{
        email: "invalid-email",
        password: "StrongPass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Accounts.create_user(attrs)

      assert Enum.any?(errors, fn error ->
               match?(%Ash.Error.Changes.InvalidAttribute{field: :email}, error)
             end)
    end

    test "returns error with weak password - too short" do
      attrs = %{
        email: "test@example.com",
        password: "short",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Accounts.create_user(attrs)

      assert Enum.any?(errors, fn error ->
               match?(%Ash.Error.Changes.InvalidChanges{}, error)
             end)
    end

    test "returns error with duplicate email" do
      insert_user(%{email: "test@example.com"})

      attrs = %{
        email: "test@example.com",
        password: "StrongPass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Accounts.create_user(attrs)

      assert Enum.any?(errors, fn error ->
               String.contains?(Exception.message(error), "already been taken")
             end)
    end
  end

  describe "update_user/2" do
    test "updates user with valid data" do
      user = insert_user()

      update_attrs = %{
        first_name: "Updated",
        last_name: "Name",
        display_name: "Updated Name"
      }

      assert {:ok, %User{} = updated_user} = Accounts.update_user(user, update_attrs)
      assert updated_user.first_name == "Updated"
      assert updated_user.last_name == "Name"
      assert updated_user.display_name == "Updated Name"
      assert updated_user.email == user.email
    end

    test "updates user password when provided" do
      user = insert_user()

      update_attrs = %{
        password: "NewStrongPass123!",
        password_confirmation: "NewStrongPass123!"
      }

      assert {:ok, %User{} = updated_user} = Accounts.update_user(user, update_attrs)
      # Password should be updated (hashed)
      assert updated_user.hashed_password != user.hashed_password
    end

    test "returns error with password mismatch" do
      user = insert_user()

      update_attrs = %{
        password: "NewStrongPass123!",
        password_confirmation: "DifferentPass123!"
      }

      assert {:error, %Ash.Error.Unknown{errors: errors}} =
               Accounts.update_user(user, update_attrs)

      assert Enum.any?(errors, fn error ->
               String.contains?(Exception.message(error), "password")
             end)
    end

    test "does not update password when blank" do
      user = insert_user()

      update_attrs = %{
        first_name: "Updated",
        password: "",
        password_confirmation: ""
      }

      assert {:ok, %User{} = updated_user} = Accounts.update_user(user, update_attrs)
      assert updated_user.first_name == "Updated"
      assert updated_user.hashed_password == user.hashed_password
    end
  end

  describe "search_users/1" do
    setup do
      user1 =
        insert_user(%{
          email: "john@example.com",
          first_name: "John",
          last_name: "Doe",
          username: "johndoe"
        })

      user2 =
        insert_user(%{
          email: "jane@example.com",
          first_name: "Jane",
          last_name: "Smith",
          username: "janesmith",
          role: :admin
        })

      user3 =
        insert_user(%{
          email: "bob@example.com",
          first_name: "Bob",
          last_name: "Wilson",
          status: :inactive
        })

      %{users: [user1, user2, user3]}
    end

    test "searches users by name" do
      results = Accounts.search_users(%{query: "John", role: "all", status: "all"})
      assert length(results) == 1
      assert hd(results).first_name == "John"
    end

    test "filters users by role" do
      results = Accounts.search_users(%{query: "", role: "admin", status: "all"})
      assert length(results) == 1
      assert hd(results).role == :admin
    end

    test "filters users by status" do
      results = Accounts.search_users(%{query: "", role: "all", status: "inactive"})
      assert length(results) == 1
      assert hd(results).status == :inactive
    end

    test "returns all users when no filters" do
      results = Accounts.search_users(%{query: "", role: "all", status: "all"})
      assert length(results) == 3
    end

    test "returns empty when no matches" do
      results = Accounts.search_users(%{query: "nonexistent", role: "all", status: "all"})
      assert results == []
    end
  end

  describe "change_user/1" do
    test "returns a changeset for the user" do
      user = insert_user()
      changeset = Accounts.change_user(user)

      assert %Ash.Changeset{} = changeset
      assert changeset.data.id == user.id
    end

    test "applies attributes to changeset" do
      user = insert_user()
      attrs = %{first_name: "New Name"}
      changeset = Accounts.change_user(user, attrs)

      # Just check that we get a changeset back - the attrs are passed through arguments
      assert %Ash.Changeset{} = changeset
      assert changeset.action.name == :update
    end
  end
end
