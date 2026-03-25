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

  @doc """
  Extracts the client IP address from a connection, handling both IPv4 and IPv6.
  """
  def client_ip(%Plug.Conn{remote_ip: ip}) do
    :inet.ntoa(ip) |> to_string()
  end

  @doc """
  Detects whether a request targets an Anthropic-format endpoint based on the path.
  Returns `:anthropic` for `/api/v1/messages`, `:openai` otherwise.
  """
  def api_format(%Plug.Conn{request_path: path}) do
    if String.contains?(path, "/messages") do
      :anthropic
    else
      :openai
    end
  end

  @doc """
  Builds a format-aware JSON error body.

  Anthropic format wraps errors in `%{type: "error", error: %{type: ..., message: ...}}`.
  OpenAI format uses `%{error: %{message: ..., type: ...}}`.
  """
  def error_body(:anthropic, type, message) do
    %{type: "error", error: %{type: type, message: message}}
  end

  def error_body(:openai, type, message) do
    %{error: %{message: message, type: type}}
  end
end
