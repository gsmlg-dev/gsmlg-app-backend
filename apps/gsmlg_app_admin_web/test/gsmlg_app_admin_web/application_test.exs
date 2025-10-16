defmodule GsmlgAppAdminWeb.ApplicationTest do
  use GsmlgAppAdminWeb.ConnCase, async: true

  describe "start/2" do
    test "application can be started with correct configuration" do
      # Test that the application module exists and has the expected structure
      assert function_exported?(GsmlgAppAdminWeb.Application, :start, 2)
    end

    test "application has correct OTP application configuration" do
      # Verify the application has the correct OTP configuration
      application_config = Application.spec(:gsmlg_app_admin_web, :mod)
      assert {GsmlgAppAdminWeb.Application, []} = application_config

      # Check extra applications
      extra_applications = Application.spec(:gsmlg_app_admin_web, :applications)
      assert :logger in extra_applications
      assert :runtime_tools in extra_applications
    end
  end
end
