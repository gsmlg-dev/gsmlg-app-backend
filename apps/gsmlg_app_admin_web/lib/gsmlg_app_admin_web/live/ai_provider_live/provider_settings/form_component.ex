defmodule GsmlgAppAdminWeb.AiProviderLive.ProviderSettings.FormComponent do
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

end
