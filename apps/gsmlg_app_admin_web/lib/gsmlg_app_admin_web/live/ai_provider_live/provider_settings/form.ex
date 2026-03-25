defmodule GsmlgAppAdminWeb.AiProviderLive.ProviderSettings.Form do
  @moduledoc """
  LiveView for creating and editing AI providers.
  """

  use GsmlgAppAdminWeb, :live_view

  import GsmlgAppAdminWeb.AiProviderLive.Components

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.Provider
  alias GsmlgAppAdmin.AI.ProviderPresets

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form = AshPhoenix.Form.for_create(Provider, :create, as: "provider")
    preset = ProviderPresets.get("generic")

    socket
    |> assign(:page_title, "Add Provider")
    |> assign(:provider, nil)
    |> assign(:form, to_form(form))
    |> assign(:preset_options, ProviderPresets.options())
    |> assign(:selected_preset, "generic")
    |> assign(:supported_models, preset.available_models)
    |> assign(:selected_models, [])
    |> assign(:new_model_input, "")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    provider = AI.get_provider!(id)
    form = AshPhoenix.Form.for_update(provider, :update, as: "provider")

    # Use only the provider's available_models (no preset merging to avoid non-existent models)
    # Remove duplicates
    available = provider.available_models || []
    supported_models = Enum.uniq(available)
    selected_models = Enum.uniq(available)

    socket
    |> assign(:page_title, "Edit Provider")
    |> assign(:provider, provider)
    |> assign(:form, to_form(form))
    |> assign(:preset_options, nil)
    |> assign(:selected_preset, nil)
    |> assign(:supported_models, supported_models)
    |> assign(:selected_models, selected_models)
    |> assign(:new_model_input, "")
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_uri, URI.parse(url).path)}
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
  def handle_event("select_preset", %{"preset" => preset_id}, socket) do
    preset = ProviderPresets.get(preset_id)
    preset_params = ProviderPresets.to_form_params(preset_id)

    form =
      AshPhoenix.Form.for_create(Provider, :create, as: "provider")
      |> AshPhoenix.Form.validate(preset_params)
      |> to_form()

    supported_models = if preset, do: preset.available_models, else: []
    # By default, select all models from the preset
    selected_models = supported_models

    {:noreply,
     socket
     |> assign(:selected_preset, preset_id)
     |> assign(:form, form)
     |> assign(:supported_models, supported_models)
     |> assign(:selected_models, selected_models)}
  end

  @impl true
  def handle_event("toggle_model", %{"model" => model}, socket) do
    selected = socket.assigns.selected_models

    selected =
      if model in selected do
        List.delete(selected, model)
      else
        [model | selected]
      end

    {:noreply, assign(socket, :selected_models, selected)}
  end

  @impl true
  def handle_event("add_models", %{"new_model" => input}, socket) do
    add_models_to_list(socket, input)
  end

  @impl true
  def handle_event("add_models", _params, socket) do
    add_models_to_list(socket, socket.assigns.new_model_input)
  end

  @impl true
  def handle_event("remove_model", %{"model" => model}, socket) do
    supported = List.delete(socket.assigns.supported_models, model)
    selected = List.delete(socket.assigns.selected_models, model)

    {:noreply,
     socket
     |> assign(:supported_models, supported)
     |> assign(:selected_models, selected)}
  end

  @impl true
  def handle_event("update_new_model", %{"new_model" => value}, socket) do
    {:noreply, assign(socket, :new_model_input, value)}
  end

  @impl true
  def handle_event("update_new_model", %{"value" => value}, socket) do
    {:noreply, assign(socket, :new_model_input, value)}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
    # Add selected models to the params
    provider_params = Map.put(provider_params, "available_models", socket.assigns.selected_models)
    save_provider(socket, socket.assigns.live_action, provider_params)
  end

  defp save_provider(socket, :new, provider_params) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: provider_params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provider created successfully")
         |> push_navigate(to: ~p"/ai-provider/providers")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp save_provider(socket, :edit, provider_params) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: provider_params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provider updated successfully")
         |> push_navigate(to: ~p"/ai-provider/providers")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp add_models_to_list(socket, input) do
    # Parse input - split by newlines and filter empty/duplicate
    new_models =
      (input || "")
      |> String.split(~r/[\r\n]+/)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.uniq()
      |> Enum.reject(&(&1 in socket.assigns.supported_models))

    if new_models != [] do
      supported = socket.assigns.supported_models ++ new_models
      selected = socket.assigns.selected_models ++ new_models

      {:noreply,
       socket
       |> assign(:supported_models, supported)
       |> assign(:selected_models, selected)
       |> assign(:new_model_input, "")}
    else
      {:noreply, assign(socket, :new_model_input, "")}
    end
  end
end
