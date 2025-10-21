# Test authentication setup
alias GsmlgAppAdmin.Accounts.User

# Check if users exist
try do
  users = User |> Ash.read!()
  IO.puts("Found #{length(users)} users in database:")

  if length(users) == 0 do
    IO.puts("No users found. Creating a test user...")

    # Create a test user
    attrs = %{
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    }

    case User |> Ash.Changeset.for_create(:register_with_default, attrs) |> Ash.create() do
      {:ok, user} ->
        IO.puts("Created test user: #{user.email}")

        # Activate the user
        case User |> Ash.Changeset.for_update(:confirm, %{}, actor: user) |> Ash.update() do
          {:ok, _user} ->
            IO.puts("User activated successfully")
          {:error, reason} ->
            IO.puts("Failed to activate user: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("Failed to create user: #{inspect(reason)}")
    end
  else
    Enum.each(users, fn user ->
      IO.puts("- #{user.email} (active: #{user.status})")
    end)
  end

rescue
  error ->
    IO.puts("Error accessing users: #{inspect(error)}")
end