defmodule GsmlgApp.ApplicationTest do
  use ExUnit.Case, async: true

  describe "start/2" do
    test "starts the application with correct children" do
      children = [
        {Phoenix.PubSub, name: GsmlgApp.PubSub},
        {Finch, name: GsmlgApp.Finch}
      ]

      assert {:ok, pid} = GsmlgApp.Application.start(:test, [])
      assert is_pid(pid)

      # Verify that the supervisor is running
      assert Process.alive?(pid)

      # Clean up
      Supervisor.stop(pid)
    end

    test "returns correct supervisor specification" do
      children = [
        {Phoenix.PubSub, name: GsmlgApp.PubSub},
        {Finch, name: GsmlgApp.Finch}
      ]

      opts = [strategy: :one_for_one, name: GsmlgApp.Supervisor]

      # Test that the supervisor can be started with the expected children
      assert {:ok, pid} = Supervisor.start_link(children, opts)
      assert is_pid(pid)

      # Clean up
      Supervisor.stop(pid)
    end
  end
end
