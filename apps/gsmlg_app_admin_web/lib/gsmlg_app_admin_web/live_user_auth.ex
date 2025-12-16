defmodule GsmlgAppAdminWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  import Phoenix.Component
  use GsmlgAppAdminWeb, :verified_routes

  def on_mount(:live_user_optional, _params, session, socket) do
    current_user = socket.assigns[:current_user] || load_current_user_from_session(session)

    if current_user do
      {:cont, assign(socket, :current_user, current_user)}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, session, socket) do
    current_user = socket.assigns[:current_user] || load_current_user_from_session(session)

    if current_user do
      {:cont, assign(socket, :current_user, current_user)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, session, socket) do
    current_user = socket.assigns[:current_user] || load_current_user_from_session(session)

    if current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp load_current_user_from_session(session) do
    # AshAuthentication stores the user in the session with key "user"
    # Format: "jti:user?id=UUID"
    case session["user"] do
      nil ->
        nil

      user_subject when is_binary(user_subject) ->
        # Extract UUID from subject string like "jti:user?id=UUID"
        case Regex.run(~r/id=([a-f0-9-]+)/, user_subject) do
          [_, user_id] ->
            case Ash.get(GsmlgAppAdmin.Accounts.User, user_id) do
              {:ok, user} -> user
              _ -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
