defmodule GsmlgAppAdmin.AI.Builtins.DateTime do
  @moduledoc """
  Built-in tool handlers for date/time queries.

  Agents can use these handlers to get the current date, time, or full datetime.
  Configure a tool with:
    execution_type: :builtin
    builtin_handler: "GsmlgAppAdmin.AI.Builtins.DateTime.now"
  """

  @doc """
  Returns the current UTC datetime as an ISO 8601 string.

  Accepts any arguments map (ignored). Returns a JSON-encodable string.
  """
  def now(_arguments) do
    Elixir.DateTime.utc_now() |> Elixir.DateTime.to_iso8601()
  end

  @doc """
  Returns the current UTC date as an ISO 8601 string (YYYY-MM-DD).
  """
  def today(_arguments) do
    Date.utc_today() |> Date.to_iso8601()
  end

  @doc """
  Returns the current UTC time as an HH:MM:SS string.
  """
  def time_now(_arguments) do
    Time.utc_now() |> Time.to_iso8601()
  end
end
