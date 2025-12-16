# Create admin user for testing using AshAuthentication's register action
alias GsmlgAppAdmin.Accounts.User

# First register the user using AshAuthentication's strategy
{:ok, user} =
  User
  |> Ash.Changeset.for_create(:register_with_default, %{
    email: "admin@example.com",
    password: "admin123456",
    password_confirmation: "admin123456"
  })
  |> Ash.create()

# Then update with admin privileges using seed_admin action
{:ok, admin} =
  user
  |> Ash.Changeset.for_update(:update, %{
    first_name: "Admin",
    last_name: "User",
    username: "admin",
    display_name: "Admin",
    is_admin: true,
    role: :admin,
    status: :active,
    email_verified: true
  }, authorize?: false)
  |> Ash.update()

IO.puts("\n✓ Admin user created successfully!")
IO.puts("\nLogin credentials:")
IO.puts("  Email: admin@example.com")
IO.puts("  Password: admin123456")
IO.puts("\nAccess the admin panel at: http://localhost:4153")
