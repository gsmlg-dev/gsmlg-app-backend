defmodule GsmlgAppAdminWeb.Plugs.StoreReturnTo do
  @moduledoc """
  Plug that captures `return_to` query parameter and stores it in session.

  This enables redirect-back functionality after authentication:
  1. Protected routes redirect to /sign-in?return_to=/original/path
  2. This plug captures the return_to param and stores in session
  3. After successful login, AuthController.success reads from session and redirects back
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.query_params["return_to"] do
      nil ->
        conn

      return_to when is_binary(return_to) ->
        # Only store valid internal paths (prevent open redirect)
        if valid_return_path?(return_to) do
          put_session(conn, :return_to, return_to)
        else
          conn
        end
    end
  end

  defp valid_return_path?(path) do
    # Must start with "/" and not contain protocol markers
    String.starts_with?(path, "/") and
      not String.contains?(path, "://") and
      not String.starts_with?(path, "//")
  end
end
