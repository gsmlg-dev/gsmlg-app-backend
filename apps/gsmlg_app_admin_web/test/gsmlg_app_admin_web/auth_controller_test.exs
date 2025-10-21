defmodule GsmlgAppAdminWeb.AuthControllerTest do
  use GsmlgAppAdminWeb.ConnCase

  describe "Authentication endpoints" do
    test "authentication module is available" do
      # Test that authentication is properly configured
      assert Code.ensure_loaded?(AshAuthentication.Phoenix.Router)
    end
  end

  describe "JWT Token Configuration" do
    test "JWT configuration is available in web environment" do
      jwt_config = Application.get_env(:ash_authentication, :jwt)
      assert jwt_config != nil
      assert Keyword.has_key?(jwt_config, :signing_secret)

      signing_secret = Keyword.get(jwt_config, :signing_secret)
      assert is_binary(signing_secret)
      assert String.length(signing_secret) > 0
    end
  end
end
