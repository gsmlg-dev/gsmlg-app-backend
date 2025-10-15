defmodule GsmlgAppAdmin.Accounts.UserTest do
  use GsmlgAppAdmin.DataCase

  alias GsmlgAppAdmin.Accounts.User

  import GsmlgAppAdmin.AccountsFixtures

  @invalid_attrs %{
    email: nil,
    hashed_password: nil,
    first_name: nil,
    last_name: nil,
    username: nil,
    display_name: nil
  }

  test "admin_create/2 with valid data creates a user" do
    valid_attrs = %{
      email: "test@example.com",
      password: "validpassword123",
      first_name: "John",
      last_name: "Doe",
      username: "johndoe",
      display_name: "John Doe"
    }

    admin_actor = %{is_admin: true}
    assert {:ok, %User{} = user} = User |> Ash.Changeset.for_create(:admin_create, valid_attrs) |> Ash.create(actor: admin_actor)
    assert to_string(user.email) == "test@example.com"
    assert user.first_name == "John"
    assert user.last_name == "Doe"
    assert user.username == "johndoe"
    assert user.display_name == "John Doe"
    assert user.hashed_password != nil
  end

  test "admin_create/2 with invalid data returns error" do
    admin_actor = %{is_admin: true}
    assert {:error, %Ash.Error.Invalid{}} = User |> Ash.Changeset.for_create(:admin_create, @invalid_attrs) |> Ash.create(actor: admin_actor)
  end

  test "admin_create/2 requires email to be valid format" do
    invalid_attrs = %{
      email: "invalid-email",
      password: "validpassword123",
      first_name: "John",
      last_name: "Doe"
    }

    admin_actor = %{is_admin: true}
    assert {:error, %Ash.Error.Invalid{}} = User |> Ash.Changeset.for_create(:admin_create, invalid_attrs) |> Ash.create(actor: admin_actor)
  end

  test "admin_create/2 requires password to be at least 8 characters" do
    invalid_attrs = %{
      email: "test@example.com",
      password: "short",
      first_name: "John",
      last_name: "Doe"
    }

    admin_actor = %{is_admin: true}
    assert {:error, %Ash.Error.Invalid{}} = User |> Ash.Changeset.for_create(:admin_create, invalid_attrs) |> Ash.create(actor: admin_actor)
  end

  test "admin_create/2 requires unique email" do
    existing_user = user_fixture()

    duplicate_attrs = %{
      email: existing_user.email,
      password: "validpassword123",
      first_name: "Jane",
      last_name: "Smith"
    }

    admin_actor = %{is_admin: true}
    assert {:error, %Ash.Error.Invalid{}} = User |> Ash.Changeset.for_create(:admin_create, duplicate_attrs) |> Ash.create(actor: admin_actor)
  end

  test "admin_create/2 requires unique username" do
    existing_user = user_fixture()

    duplicate_attrs = %{
      email: "different@example.com",
      password: "validpassword123",
      username: existing_user.username,
      first_name: "Jane",
      last_name: "Smith"
    }

    admin_actor = %{is_admin: true}
    assert {:error, %Ash.Error.Invalid{}} = User |> Ash.Changeset.for_create(:admin_create, duplicate_attrs) |> Ash.create(actor: admin_actor)
  end
end