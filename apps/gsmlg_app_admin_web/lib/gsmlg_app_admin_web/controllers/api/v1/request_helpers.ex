defmodule GsmlgAppAdminWeb.Api.V1.RequestHelpers do
  @moduledoc """
  Shared helpers for API v1 controllers.
  """

  @doc """
  Converts a role string to an existing atom.

  Accepts "user", "assistant", "tool", and "function".
  Any other value (including nil, empty string, or potential atom injection attacks)
  defaults to :user.

  ## Examples

      iex> safe_role("user")
      :user

      iex> safe_role("assistant")
      :assistant

      iex> safe_role("__struct__")
      :user

      iex> safe_role(nil)
      :user

      iex> safe_role("")
      :user
  """
  def safe_role(role) when role in ~w(user assistant tool function),
    do: String.to_existing_atom(role)

  def safe_role(_), do: :user
end
