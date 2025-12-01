# Create admin user for testing
alias GsmlgAppAdmin.Accounts

{:ok, admin} =
  Accounts.create_user(
    %{
      email: "admin@example.com",
      first_name: "Admin",
      last_name: "User",
      username: "admin",
      display_name: "Admin",
      is_admin: true,
      role: :admin,
      status: :active,
      email_verified: true,
      timezone: "UTC",
      language: "en",
      password: "admin123456"
    },
    action: :admin_create
  )

IO.puts("\n✓ Admin user created successfully!")
IO.puts("\nLogin credentials:")
IO.puts("  Email: admin@example.com")
IO.puts("  Password: admin123456")
IO.puts("\nAccess the admin panel at: http://localhost:4153")
