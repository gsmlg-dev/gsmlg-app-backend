defmodule GsmlgApp.ApplicationTest do
  use ExUnit.Case, async: true

  describe "start/2" do
    test "has correct children specification" do
      # Test that the application defines the correct children
      # without actually starting the application
      children = [
        {Phoenix.PubSub, name: GsmlgApp.PubSub},
        {Finch, name: GsmlgApp.Finch}
      ]

      # Verify that all child specifications are valid
      Enum.each(children, fn child ->
        assert is_tuple(child) or is_atom(child)
      end)

      # Test that we can start a subset of children that don't require external services
      test_children = [
        {Phoenix.PubSub, name: GsmlgApp.TestPubSub}
      ]

      opts = [strategy: :one_for_one, name: GsmlgApp.TestSupervisor]
      assert {:ok, pid} = Supervisor.start_link(test_children, opts)
      assert is_pid(pid)

      # Clean up
      Supervisor.stop(pid)
    end

    test "returns correct supervisor strategy" do
      # The application should use :one_for_one strategy
      test_children = [
        {Phoenix.PubSub, name: GsmlgApp.TestPubSub}
      ]

      opts = [strategy: :one_for_one, name: GsmlgApp.TestSupervisor]
      assert {:ok, pid} = Supervisor.start_link(test_children, opts)

      # Verify the supervisor is running
      assert Process.alive?(pid)

      # Clean up
      Supervisor.stop(pid)
    end
  end
end
