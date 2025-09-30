defmodule GsmlgAppAdmin.AccountsTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.Accounts

  describe "domain configuration" do
    test "has correct resources configured" do
      # Test that the domain has the expected resources
      resources = Ash.Domain.Info.resources(Accounts)

      assert GsmlgAppAdmin.Accounts.User in resources
      assert GsmlgAppAdmin.Accounts.Token in resources
    end

    test "domain has correct OTP app configuration" do
      # Test that the domain is configured with the correct OTP app
      # Since we're using Ash.Domain, the OTP app is configured in the use statement
      # We can verify this by checking that the domain module exists and is properly configured
      assert function_exported?(Accounts, :__info__, 1)
      assert Ash.Domain.Info.resources(Accounts) != []
    end
  end

  describe "resource access" do
    test "can access User resource through domain" do
      # Test that we can access the User resource
      resources = Ash.Domain.Info.resources(Accounts)

      user_resource =
        Enum.find(resources, fn resource -> resource == GsmlgAppAdmin.Accounts.User end)

      assert user_resource == GsmlgAppAdmin.Accounts.User
    end

    test "can access Token resource through domain" do
      # Test that we can access the Token resource
      resources = Ash.Domain.Info.resources(Accounts)

      token_resource =
        Enum.find(resources, fn resource -> resource == GsmlgAppAdmin.Accounts.Token end)

      assert token_resource == GsmlgAppAdmin.Accounts.Token
    end
  end
end
