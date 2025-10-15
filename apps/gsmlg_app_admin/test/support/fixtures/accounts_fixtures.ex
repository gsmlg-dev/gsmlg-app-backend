defmodule GsmlgAppAdmin.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GsmlgAppAdmin.Accounts` context.
  """

  alias GsmlgAppAdmin.Accounts.User

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    # Create an admin actor first
    admin_actor = %{
      is_admin: true
    }

    user =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        password: "validpassword123",
        first_name: "John",
        last_name: "Doe",
        username: unique_user_name(),
        display_name: "John Doe",
        status: :active,
        role: :user,
        email_verified: true
      })
      |> then(
        &(User
          |> Ash.Changeset.for_create(:admin_create, &1)
          |> Ash.create!(actor: admin_actor))
      )

    user
  end

  def admin_user_fixture(attrs \\ %{}) do
    user_fixture(Enum.into(attrs, %{role: :admin, is_admin: true}))
  end

  defp unique_user_email do
    "user#{System.unique_integer([:positive])}@example.com"
  end

  defp unique_user_name do
    "user#{System.unique_integer([:positive])}"
  end
end
