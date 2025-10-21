# Test user registration through AshAuthentication
alias GsmlgAppAdmin.Accounts.User

# Try to create a user through the registration action
attrs = %{
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123"
}

IO.puts("Attempting to create user through registration...")

case User |> Ash.Changeset.for_create(:register_with_default, attrs) |> Ash.create() do
  {:ok, user} ->
    IO.puts("✅ Successfully created user: #{user.email}")
    IO.puts("User ID: #{user.id}")
    IO.puts("User status: #{user.status}")
    IO.puts("User role: #{user.role}")
    IO.puts("Email verified: #{user.email_verified}")

  {:error, changeset} ->
    IO.puts("❌ Failed to create user:")
    IO.puts("Errors: #{inspect(Ash.Error.errors(changeset))}")

    # Try to see available actions
    IO.puts("\nAvailable actions on User:")
    User |> Ash.Resource.Info.actions() |> Enum.each(fn action ->
      IO.puts("- #{action.name}")
    end)
end