defmodule GsmlgAppAdmin.UserTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.Accounts.User

  describe "admin user" do
    test "admin user exists with correct attributes" do
      # Query for the admin user
      admin_user =
        User
        |> Ash.Query.filter(email == "admin@example.com")
        |> Ash.read_one!(authorize?: false)

      assert admin_user != nil
      assert admin_user.email == "admin@example.com"
      assert admin_user.username == "admin"
      assert admin_user.first_name == "Admin"
      assert admin_user.last_name == "User"
      assert admin_user.display_name == "Administrator"
      assert admin_user.role == :admin
      assert admin_user.is_admin == true
      assert admin_user.status == :active
      assert admin_user.email_verified == true
      assert admin_user.timezone == "UTC"
      assert admin_user.language == "en"
    end

    test "password is properly hashed" do
      admin_user =
        User
        |> Ash.Query.filter(email == "admin@example.com")
        |> Ash.read_one!(authorize?: false)

      # Password should be hashed with bcrypt
      assert String.starts_with?(admin_user.hashed_password, "$2b$")
      assert String.length(admin_user.hashed_password) == 60
    end
  end
end
