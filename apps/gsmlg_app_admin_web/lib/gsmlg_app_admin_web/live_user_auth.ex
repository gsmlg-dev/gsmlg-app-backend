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
      redirect_url = build_sign_in_url(socket)
      {:halt, Phoenix.LiveView.redirect(socket, to: redirect_url)}
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

  defp build_sign_in_url(socket) do
    case get_current_path(socket) do
      nil -> ~p"/sign-in"
      "/" -> ~p"/sign-in"
      path -> ~p"/sign-in?return_to=#{URI.encode_www_form(path)}"
    end
  end

  defp get_current_path(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :uri) do
      %URI{path: path, query: query} when is_binary(path) ->
        if query, do: "#{path}?#{query}", else: path

      _ ->
        nil
    end
  end

  defp load_current_user_from_session(session) do
    case session["user"] do
      nil -> nil
      subject when is_binary(subject) -> load_user_from_subject(subject)
      _ -> nil
    end
  end

  defp load_user_from_subject(subject) do
    cond do
      String.contains?(subject, "id=") ->
        load_user_by_id_from_subject(subject)

      Regex.match?(~r/^[a-f0-9-]{36}$/i, subject) ->
        load_user_by_uuid(subject)

      true ->
        load_user_via_ash_authentication(subject)
    end
  end

  defp load_user_by_id_from_subject(subject) do
    case Regex.run(~r/id=([a-f0-9-]+)/i, subject) do
      [_, user_id] -> load_user_by_uuid(user_id)
      _ -> nil
    end
  end

  defp load_user_by_uuid(user_id) do
    case Ash.get(GsmlgAppAdmin.Accounts.User, user_id) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load_user_via_ash_authentication(subject) do
    case AshAuthentication.subject_to_user(subject, :gsmlg_app_admin) do
      {:ok, user} -> user
      _ -> nil
    end
  rescue
    _ -> nil
  end
end
