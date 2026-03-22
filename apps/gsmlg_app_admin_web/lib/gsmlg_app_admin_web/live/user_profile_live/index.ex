defmodule GsmlgAppAdminWeb.UserProfileLive.Index do
  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    form =
      current_user
      |> AshPhoenix.Form.for_update(:update, as: "user")
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "My Profile")
     |> assign(:form, form)
     |> assign(:password_form, to_form(%{}))}
  end

  @impl true
  def handle_event("update_profile", %{"user" => user_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: user_params) do
      {:ok, updated_user} ->
        form =
          updated_user
          |> AshPhoenix.Form.for_update(:update, as: "user")
          |> to_form()

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:form, form)
         |> put_flash(:info, "Profile updated successfully")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, "Failed to update profile")}
    end
  end

  def handle_event("change_password", %{"password" => password_params}, socket) do
    current_user = socket.assigns.current_user

    case validate_and_change_password(current_user, password_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:password_form, to_form(%{}))
         |> put_flash(:info, "Password changed successfully")}

      {:error, error_messages} ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(%{errors: error_messages}))
         |> put_flash(:error, "Failed to change password")}
    end
  end

  defp validate_and_change_password(user, %{
         "current_password" => current,
         "new_password" => new,
         "new_password_confirmation" => confirmation
       }) do
    errors = []

    # Validate current password
    errors =
      if Bcrypt.verify_pass(current, user.hashed_password) do
        errors
      else
        [{"current_password", "Current password is incorrect"} | errors]
      end

    # Validate new password
    errors =
      cond do
        new == "" ->
          [{"new_password", "New password is required"} | errors]

        new != confirmation ->
          [{"new_password_confirmation", "Passwords do not match"} | errors]

        String.length(new) < 8 ->
          [{"new_password", "Password must be at least 8 characters long"} | errors]

        not strong_password?(new) ->
          [
            {"new_password",
             "Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character"}
            | errors
          ]

        true ->
          errors
      end

    if errors == [] do
      Accounts.update_user(user, %{
        password: new,
        password_confirmation: confirmation
      })
    else
      {:error, errors}
    end
  end

  defp strong_password?(password) do
    has_upper = String.match?(password, ~r/[A-Z]/)
    has_lower = String.match?(password, ~r/[a-z]/)
    has_number = String.match?(password, ~r/[0-9]/)
    has_special = String.match?(password, ~r/[!@#$%^&*(),.?":{}|<>]/)

    has_upper && has_lower && has_number && has_special
  end

  def format_datetime(nil), do: "Never"

  def format_datetime(datetime) do
    DateTime.to_string(datetime)
  end

  defp role_badge_class(role) do
    case role do
      :admin -> "bg-red-100 text-red-800"
      :user -> "bg-gray-100 text-gray-800"
      :moderator -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp status_badge_class(status) do
    case status do
      :active -> "bg-green-100 text-green-800"
      :inactive -> "bg-gray-100 text-gray-800"
      :suspended -> "bg-red-100 text-red-800"
      :pending -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
