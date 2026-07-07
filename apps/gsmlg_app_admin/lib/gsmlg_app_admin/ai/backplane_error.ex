defmodule GsmlgAppAdmin.AI.BackplaneError do
  @moduledoc """
  Error returned by the configured Backplane API server.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          status: non_neg_integer() | nil,
          type: String.t() | nil,
          body: term()
        }

  @enforce_keys [:message]
  defstruct [:message, :status, :type, :body]
end
