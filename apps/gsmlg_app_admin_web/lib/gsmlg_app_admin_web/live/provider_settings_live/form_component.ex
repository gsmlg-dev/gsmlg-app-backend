defmodule GsmlgAppAdminWeb.ProviderSettingsLive.FormComponent do
  @moduledoc """
  LiveComponent for creating and editing AI providers.
  """

  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI.Provider

  @impl true
  def update(%{provider: provider} = assigns, socket) do
    form =
      if provider do
        AshPhoenix.Form.for_update(provider, :update, as: "provider")
      else
        AshPhoenix.Form.for_create(Provider, :create, as: "provider")
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"provider" => provider_params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(provider_params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
    save_provider(socket, socket.assigns.action, provider_params)
  end

  defp save_provider(socket, :new, provider_params) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: provider_params) do
      {:ok, provider} ->
        notify_parent({:saved, provider})

        {:noreply,
         socket
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp save_provider(socket, :edit, provider_params) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: provider_params) do
      {:ok, provider} ->
        notify_parent({:saved, provider})

        {:noreply,
         socket
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.dm_card>
        <:title>{@title}</:title>
        <.dm_form
          :let={f}
          for={@form}
          id="provider-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.dm_input
            field={f[:name]}
            type="text"
            label="Name"
            placeholder="My AI Provider"
            required
          />

          <.dm_input
            field={f[:slug]}
            type="text"
            label="Slug"
            placeholder="my-provider"
            disabled={@action == :edit}
            required
          />

          <.dm_input
            field={f[:api_base_url]}
            type="text"
            label="API Base URL"
            placeholder="https://api.example.com/v1"
            required
          />

          <.dm_input
            field={f[:api_key]}
            type="password"
            label="API Key"
            placeholder={if @action == :edit, do: "Leave blank to keep current", else: "sk-..."}
            autocomplete="off"
          />

          <.dm_input
            field={f[:model]}
            type="text"
            label="Default Model"
            placeholder="gpt-4"
            required
          />

          <.dm_input
            field={f[:description]}
            type="textarea"
            label="Description"
            placeholder="Optional description of this provider"
          />

          <.dm_input
            field={f[:is_active]}
            type="checkbox"
            label="Active"
          />

          <:actions>
            <.dm_btn phx-disable-with="Saving...">Save Provider</.dm_btn>
          </:actions>
        </.dm_form>
      </.dm_card>
    </div>
    """
  end
end
