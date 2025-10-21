# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     GsmlgAppAdmin.Repo.insert!(%GsmlgAppAdmin.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias GsmlgAppAdmin.Accounts
alias GsmlgAppAdmin.Accounts.User

# Create admin user if it doesn't exist
admin_email = "admin@gsmlg.dev"
admin_password = "Qwer1234"

IO.puts("Creating admin user...")

# Check if admin user already exists
require Ash.Query

case User |> Ash.Query.filter(email == ^admin_email) |> Ash.read_one(authorize?: false) do
  {:ok, nil} ->
    IO.puts("Admin user not found, creating new one...")

    # Hash the password using bcrypt
    hashed_password = Bcrypt.hash_pwd_salt(admin_password)

    admin_user = %{
      email: admin_email,
      hashed_password: hashed_password,
      first_name: "Admin",
      last_name: "User",
      username: "admin",
      display_name: "Administrator",
      status: :active,
      email_verified: true,
      email_verified_at: DateTime.utc_now(),
      role: :admin,
      is_admin: true,
      timezone: "UTC",
      language: "en"
    }

    user = Ash.create!(User, admin_user, action: :seed_admin, authorize?: false)
    IO.puts("✅ Admin user created successfully!")
    IO.puts("   Email: #{user.email}")
    IO.puts("   Username: #{user.username}")
    IO.puts("   Role: #{user.role}")
    IO.puts("   Password: #{admin_password}")

  {:ok, user} ->
    IO.puts("✅ Admin user already exists:")
    IO.puts("   Email: #{user.email}")
    IO.puts("   Username: #{user.username}")
    IO.puts("   Role: #{user.role}")

  {:error, error} ->
    IO.puts("❌ Error checking for existing admin user:")
    IO.inspect(error)
end

IO.puts("Seed completed!")
