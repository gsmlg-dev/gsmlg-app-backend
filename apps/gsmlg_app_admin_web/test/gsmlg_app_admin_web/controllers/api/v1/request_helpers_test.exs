defmodule GsmlgAppAdminWeb.Api.V1.RequestHelpersTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdminWeb.Api.V1.RequestHelpers

  describe "safe_role/1" do
    test "converts valid role strings to atoms" do
      assert RequestHelpers.safe_role("user") == :user
      assert RequestHelpers.safe_role("assistant") == :assistant
      assert RequestHelpers.safe_role("tool") == :tool
      assert RequestHelpers.safe_role("function") == :function
    end

    test "defaults to :user for nil" do
      assert RequestHelpers.safe_role(nil) == :user
    end

    test "defaults to :user for empty string" do
      assert RequestHelpers.safe_role("") == :user
    end

    test "defaults to :user for unknown role strings" do
      assert RequestHelpers.safe_role("system") == :user
      assert RequestHelpers.safe_role("admin") == :user
      assert RequestHelpers.safe_role("ASSISTANT") == :user
    end

    test "prevents atom injection via known-dangerous strings" do
      # These strings could be used to inject atoms if not guarded
      assert RequestHelpers.safe_role("__struct__") == :user
      assert RequestHelpers.safe_role("__info__") == :user
      assert RequestHelpers.safe_role("Elixir.Kernel") == :user
    end
  end
end
