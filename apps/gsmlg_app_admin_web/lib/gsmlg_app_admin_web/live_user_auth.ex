defmodule GsmlgAppAdminWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  import Phoenix.Component
  use GsmlgAppAdminWeb, :verified_routes

  def on_mount(:live_user_optional, _params, session, socket) do
    # Debug: log session keys and socket assigns
    IO.inspect(Map.keys(session), label: "Session keys")
    IO.inspect(session, label: "Full session")
    IO.inspect(socket.assigns[:current_user], label: "Socket current_user before load")

    current_user = socket.assigns[:current_user] || load_current_user_from_session(session)

    IO.inspect(current_user, label: "Loaded current_user")

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
    # AshAuthentication stores the user subject in the session
    # Try to find user from any session key that looks like a user subject
    user_subject = session["user"]

    IO.inspect(user_subject, label: "User subject from session")

    case user_subject do
      nil ->
        # Try to get user from AshAuthentication's subject format
        nil

      subject when is_binary(subject) ->
        load_user_from_subject(subject)

      _ ->
        nil
    end
  end

  defp load_user_from_subject(subject) do
    IO.inspect(subject, label: "Parsing subject")

    # Try different subject formats:
    # 1. "user?id=UUID" - direct subject
    # 2. "jti:user?id=UUID" - with JTI prefix
    # 3. Just a UUID

    cond do
      # Format: "user?id=UUID"
      String.contains?(subject, "id=") ->
        case Regex.run(~r/id=([a-f0-9-]+)/i, subject) do
          [_, user_id] ->
            IO.inspect(user_id, label: "Extracted user_id")
            case Ash.get(GsmlgAppAdmin.Accounts.User, user_id) do
              {:ok, user} -> user
              error ->
                IO.inspect(error, label: "Error loading user")
                nil
            end
          _ -> nil
        end

      # Format: Just UUID
      Regex.match?(~r/^[a-f0-9-]{36}$/i, subject) ->
        case Ash.get(GsmlgAppAdmin.Accounts.User, subject) do
          {:ok, user} -> user
          _ -> nil
        end

      true ->
        # Try to use AshAuthentication's subject_to_user
        try do
          case AshAuthentication.subject_to_user(subject, :gsmlg_app_admin) do
            {:ok, user} -> user
            _ -> nil
          end
        rescue
          _ -> nil
        end
    end
  end
end
