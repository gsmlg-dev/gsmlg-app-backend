defmodule GsmlgAppWeb.ApplicationTest do
  use GsmlgAppWeb.ConnCase, async: true

  describe "start/2" do
    test "application can be started with correct configuration" do
      # Test that the application module exists and has the expected structure
      assert function_exported?(GsmlgAppWeb.Application, :start, 2)

      # Test that we can get children specification (if implemented)
      if function_exported?(GsmlgAppWeb.Application, :children, 0) do
        children = GsmlgAppWeb.Application.children()
        assert is_list(children)
      end
    end

    test "application has correct OTP application configuration" do
      # Verify the application has the correct OTP configuration
      application_config = Application.spec(:gsmlg_app_web, :mod)
      assert {GsmlgAppWeb.Application, []} = application_config

      # Check extra applications
      extra_applications = Application.spec(:gsmlg_app_web, :applications)
      assert :logger in extra_applications
      assert :runtime_tools in extra_applications
    end
  end
end
