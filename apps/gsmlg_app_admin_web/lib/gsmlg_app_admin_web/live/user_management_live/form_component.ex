defmodule GsmlgAppAdminWeb.UserManagementLive.FormComponent do
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.Accounts
  alias GsmlgAppAdmin.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.dm_card>
        <:title>{@title}</:title>
        <:subtitle>Use this form to manage user records in your database.</:subtitle>
        <:body>
          <.dm_form
            :let={f}
            for={@form}
            id="user-form"
            phx-target={@myself}
            phx-change="validate"
            phx-submit="save"
          >
            <.dm_input field={f[:email]} type="email" label="Email" required />
            <.dm_input field={f[:first_name]} type="text" label="First name" />
            <.dm_input field={f[:last_name]} type="text" label="Last name" />
            <.dm_input field={f[:username]} type="text" label="Username" />
            <.dm_input field={f[:display_name]} type="text" label="Display name" />

            <.dm_input
              field={f[:password]}
              type="password"
              label={
                if @action == :edit,
                  do: "New password (leave blank to keep current)",
                  else: "Password"
              }
              value={@form[:password].value || ""}
            />

            <.dm_input
              field={f[:password_confirmation]}
              type="password"
              label="Confirm password"
              value={@form[:password_confirmation].value || ""}
            />

            <.dm_input
              field={f[:role]}
              type="select"
              label="Role"
              options={[
                {"User", :user},
                {"Moderator", :moderator},
                {"Admin", :admin}
              ]}
            />

            <.dm_input
              field={f[:status]}
              type="select"
              label="Status"
              options={[
                {"Active", :active},
                {"Inactive", :inactive},
                {"Suspended", :suspended},
                {"Pending", :pending}
              ]}
            />

            <.dm_input
              field={f[:email_verified]}
              type="checkbox"
              label="Email verified"
            />

            <.dm_input
              field={f[:timezone]}
              type="text"
              label="Timezone"
            />

            <.dm_input
              field={f[:language]}
              type="text"
              label="Language"
            />

            <:actions>
              <.dm_btn phx-disable-with="Saving...">Save User</.dm_btn>
            </:actions>
          </.dm_form>
        </:body>
      </.dm_card>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)

    socket
    |> assign(assigns)
    |> assign_form(changeset)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    socket
    |> assign_form(changeset)
    |> noreply()
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        socket
        |> put_flash(:info, "User updated successfully")
        |> push_patch(to: socket.assigns.patch)
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign_form(changeset)
        |> noreply()
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        socket
        |> put_flash(:info, "User created successfully")
        |> push_patch(to: socket.assigns.patch)
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign_form(changeset)
        |> noreply()
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp ok(socket), do: {:ok, socket}
  defp noreply(socket), do: {:noreply, socket}
end
