defmodule GsmlgAppAdmin.AccountsTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.Accounts

  describe "domain configuration" do
    test "has correct resources configured" do
      # Test that the domain has the expected resources
      resources = Accounts.__info__(:resources)

      assert GsmlgAppAdmin.Accounts.User in resources
      assert GsmlgAppAdmin.Accounts.Token in resources
    end

    test "domain has correct OTP app configuration" do
      # Test that the domain is configured with the correct OTP app
      otp_app = Accounts.__info__(:otp_app)
      assert otp_app == :gsmlg_app_admin
    end
  end

  describe "resource access" do
    test "can access User resource through domain" do
      # Test that we can access the User resource
      assert function_exported?(Accounts, :User, 0)
      user_resource = Accounts.User
      assert user_resource == GsmlgAppAdmin.Accounts.User
    end

    test "can access Token resource through domain" do
      # Test that we can access the Token resource
      assert function_exported?(Accounts, :Token, 0)
      token_resource = Accounts.Token
      assert token_resource == GsmlgAppAdmin.Accounts.Token
    end
  end
end
