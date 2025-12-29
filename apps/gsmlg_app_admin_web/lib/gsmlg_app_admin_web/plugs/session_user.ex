defmodule GsmlgAppAdminWeb.Plugs.SessionUser do
  @moduledoc """
  Plug to load current_user from session and assign to conn.

  This plug reads the user subject from the session (stored by AshAuthentication)
  and loads the full user record from the database, assigning it to `conn.assigns.current_user`.

  ## Usage

  Add to your browser pipeline in router.ex:

      plug GsmlgAppAdminWeb.Plugs.SessionUser
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # If :load_from_session already assigned current_user, don't overwrite it
    if conn.assigns[:current_user] do
      conn
    else
      case get_session(conn, "user") do
        nil ->
          assign(conn, :current_user, nil)

        subject when is_binary(subject) ->
          user = load_user_from_subject(subject)
          assign(conn, :current_user, user)

        _ ->
          assign(conn, :current_user, nil)
      end
    end
  end

  defp load_user_from_subject(subject) do
    cond do
      String.contains?(subject, "id=") ->
        case Regex.run(~r/id=([a-f0-9-]+)/i, subject) do
          [_, user_id] -> load_user(user_id)
          _ -> nil
        end

      Regex.match?(~r/^[a-f0-9-]{36}$/i, subject) ->
        load_user(subject)

      true ->
        nil
    end
  end

  defp load_user(user_id) do
    case Ash.get(GsmlgAppAdmin.Accounts.User, user_id) do
      {:ok, user} -> user
      _ -> nil
    end
  end
end
