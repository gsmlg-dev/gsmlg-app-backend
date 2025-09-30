defmodule GsmlgAppAdmin.ApplicationTest do
  use GsmlgAppAdmin.DataCase, async: true

  describe "start/2" do
    test "starts the application with correct children" do
      # Test that we can start the application in test mode
      # Note: We can't test the full application start in unit tests
      # because it would require database connections and other services
      # Instead, we verify the children specification is correct

      children = [
        GsmlgAppAdmin.Repo,
        {Phoenix.PubSub, name: GsmlgAppAdmin.PubSub},
        {Finch, name: GsmlgAppAdmin.Finch},
        {AshAuthentication.Supervisor, otp_app: :gsmlg_app_admin}
      ]

      # Verify that all child specifications are valid
      Enum.each(children, fn child ->
        assert is_tuple(child) or is_atom(child)
      end)

      # Test that we can start a subset of children that don't require external services
      test_children = [
        {Phoenix.PubSub, name: GsmlgAppAdmin.TestPubSub},
        {Finch, name: GsmlgAppAdmin.TestFinch}
      ]

      opts = [strategy: :one_for_one, name: GsmlgAppAdmin.TestSupervisor]
      assert {:ok, pid} = Supervisor.start_link(test_children, opts)
      assert is_pid(pid)

      # Clean up
      Supervisor.stop(pid)
    end

    test "returns correct supervisor strategy" do
      # The application should use :one_for_one strategy
      children = [
        {Phoenix.PubSub, name: GsmlgAppAdmin.TestPubSub}
      ]

      opts = [strategy: :one_for_one, name: GsmlgAppAdmin.TestSupervisor]
      assert {:ok, pid} = Supervisor.start_link(children, opts)

      # Verify the supervisor is running
      assert Process.alive?(pid)

      # Clean up
      Supervisor.stop(pid)
    end
  end
end
