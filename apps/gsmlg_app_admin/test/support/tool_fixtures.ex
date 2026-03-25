defmodule GsmlgAppAdmin.AI.Builtins.TestSleepyHandler do
  @moduledoc """
  A test-only module providing a handler function that sleeps indefinitely,
  used to exercise the ToolExecutor timeout path.

  Must be under the `GsmlgAppAdmin.AI.Builtins` namespace to pass the
  builtin handler allowlist check.
  """

  @doc """
  Accepts any arguments map and sleeps indefinitely. Used for timeout tests.
  """
  def sleep_forever(_arguments) do
    Process.sleep(:infinity)
  end
end
