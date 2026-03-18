defmodule GsmlgAppAdmin.Test.SleepyHandler do
  @moduledoc """
  A test-only module providing a handler function that sleeps indefinitely,
  used to exercise the ToolExecutor timeout path.
  """

  @doc """
  Accepts any arguments map and sleeps indefinitely. Used for timeout tests.
  """
  def sleep_forever(_arguments) do
    Process.sleep(:infinity)
  end
end
