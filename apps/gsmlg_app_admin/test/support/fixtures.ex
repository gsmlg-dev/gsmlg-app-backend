defmodule GsmlgAppAdmin.TestFixtures do
  @moduledoc """
  Test fixtures for user system tests.
  """

  alias GsmlgAppAdmin.Accounts

  @doc """
  Insert a user with the given attributes.
  """
  def insert_user(attrs \\ %{}) do
    # Generate a short unique identifier
    unique_id = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

    default_attrs = %{
      email: "test#{unique_id}@example.com",
      password: "StrongPass123!",
      first_name: "Test",
      last_name: "User",
      username: "testuser#{unique_id}",
      display_name: "Test User",
      role: :user,
      status: :active,
      email_verified: false,
      timezone: "UTC",
      language: "en"
    }

    merged_attrs = Map.merge(default_attrs, attrs)
    # Use the admin_create action which accepts password as argument
    {:ok, user} = Accounts.create_user(merged_attrs)
    user
  end

  @doc """
  Insert an admin user.
  """
  def insert_admin(attrs \\ %{}) do
    # Generate a short unique identifier
    unique_id = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

    admin_attrs =
      Map.merge(
        %{
          email: "admin#{unique_id}@example.com",
          role: :admin,
          is_admin: true,
          first_name: "Admin",
          last_name: "User",
          username: "admin#{unique_id}",
          display_name: "Administrator"
        },
        attrs
      )

    insert_user(admin_attrs)
  end

  @doc """
  Insert a moderator user.
  """
  def insert_moderator(attrs \\ %{}) do
    # Generate a short unique identifier
    unique_id = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

    moderator_attrs =
      Map.merge(
        %{
          email: "mod#{unique_id}@example.com",
          role: :moderator,
          first_name: "Moderator",
          last_name: "User",
          username: "mod#{unique_id}",
          display_name: "Moderator"
        },
        attrs
      )

    insert_user(moderator_attrs)
  end

  @doc """
  Insert multiple users with different roles for testing.
  """
  def insert_test_users do
    admin = insert_admin()
    moderator = insert_moderator()
    user1 = insert_user(%{first_name: "John", last_name: "Doe", username: "johndoe"})
    user2 = insert_user(%{first_name: "Jane", last_name: "Smith", username: "janesmith"})
    inactive_user = insert_user(%{status: :inactive, first_name: "Bob", last_name: "Wilson"})

    %{
      admin: admin,
      moderator: moderator,
      users: [user1, user2, inactive_user]
    }
  end
end
