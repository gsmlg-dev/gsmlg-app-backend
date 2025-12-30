defmodule GsmlgAppAdminWeb.ProviderSettingsLive.Form do
  @moduledoc """
  LiveView for creating and editing AI providers.
  """

  use GsmlgAppAdminWeb, :live_view

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

    # Try to find the preset for this provider to get all supported models
    preset = find_preset_for_provider(provider)

    supported_models =
      if preset, do: preset.available_models, else: provider.available_models || []

    socket
    |> assign(:page_title, "Edit Provider")
    |> assign(:provider, provider)
    |> assign(:form, to_form(form))
    |> assign(:preset_options, nil)
    |> assign(:selected_preset, nil)
    |> assign(:supported_models, supported_models)
    |> assign(:selected_models, provider.available_models || [])
    |> assign(:new_model_input, "")
  end

  # Find a matching preset for an existing provider based on slug or API URL
  defp find_preset_for_provider(provider) do
    ProviderPresets.all()
    |> Enum.find(fn preset ->
      preset.slug == provider.slug ||
        String.contains?(provider.api_base_url || "", preset.api_base_url)
    end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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

  defp add_models_to_list(socket, input) do
    # Parse input - split by newlines and filter empty/duplicate
    new_models =
      (input || "")
      |> String.split(~r/[\r\n]+/)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.uniq()
      |> Enum.reject(&(&1 in socket.assigns.supported_models))

    if length(new_models) > 0 do
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
         |> push_navigate(to: ~p"/chat/settings")}

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
         |> push_navigate(to: ~p"/chat/settings")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 max-w-2xl">
      <div class="flex items-center gap-4 mb-6">
        <.link navigate={~p"/chat/settings"} class="btn btn-ghost btn-sm">
          <.dm_mdi name="arrow-left" class="w-4 h-4" /> Back to Settings
        </.link>
        <h1 class="text-2xl font-bold">{@page_title}</h1>
      </div>

      <%= if @preset_options do %>
        <div class="card bg-base-100 shadow-md mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg">Select Provider Type</h2>
            <p class="text-sm text-base-content/70 mb-4">
              Choose a preset to auto-fill configuration, or select "Generic" for custom setup.
            </p>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2">
              <%= for {name, id} <- @preset_options do %>
                <button
                  type="button"
                  phx-click="select_preset"
                  phx-value-preset={id}
                  class={"btn btn-sm #{if @selected_preset == id, do: "btn-primary", else: "btn-outline"}"}
                >
                  {name}
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <div class="card bg-base-100 shadow-md">
        <div class="card-body">
          <.form
            for={@form}
            id="provider-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Name *</span>
              </label>
              <input
                type="text"
                name={@form[:name].name}
                value={@form[:name].value}
                placeholder="My AI Provider"
                class={"input input-bordered w-full #{if @form[:name].errors != [], do: "input-error"}"}
                required
              />
              <%= if @form[:name].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    {Enum.map(@form[:name].errors, fn {msg, _} -> msg end) |> Enum.join(", ")}
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Slug *</span>
              </label>
              <input
                type="text"
                name={@form[:slug].name}
                value={@form[:slug].value}
                placeholder="my-provider"
                class={"input input-bordered w-full #{if @form[:slug].errors != [], do: "input-error"}"}
                disabled={@live_action == :edit}
                required
              />
              <label class="label">
                <span class="label-text-alt">
                  URL-friendly identifier (cannot be changed after creation)
                </span>
              </label>
              <%= if @form[:slug].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    {Enum.map(@form[:slug].errors, fn {msg, _} -> msg end) |> Enum.join(", ")}
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">API Base URL *</span>
              </label>
              <input
                type="text"
                name={@form[:api_base_url].name}
                value={@form[:api_base_url].value}
                placeholder="https://api.example.com/v1"
                class={"input input-bordered w-full #{if @form[:api_base_url].errors != [], do: "input-error"}"}
                required
              />
              <%= if @form[:api_base_url].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    {Enum.map(@form[:api_base_url].errors, fn {msg, _} -> msg end) |> Enum.join(", ")}
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">API Key</span>
              </label>
              <input
                type="password"
                name={@form[:api_key].name}
                value={@form[:api_key].value}
                placeholder={
                  if @live_action == :edit, do: "Leave blank to keep current", else: "sk-..."
                }
                class={"input input-bordered w-full #{if @form[:api_key].errors != [], do: "input-error"}"}
                autocomplete="off"
              />
              <%= if @live_action == :edit && @provider && @provider.api_key do %>
                <label class="label">
                  <span class="label-text-alt">
                    Current key: ****{String.slice(@provider.api_key || "", -4..-1//1)}
                  </span>
                </label>
              <% end %>
              <%= if @form[:api_key].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    {Enum.map(@form[:api_key].errors, fn {msg, _} -> msg end) |> Enum.join(", ")}
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Default Model *</span>
              </label>
              <input
                type="text"
                name={@form[:model].name}
                value={@form[:model].value}
                placeholder="gpt-4"
                class={"input input-bordered w-full #{if @form[:model].errors != [], do: "input-error"}"}
                required
              />
              <%= if @form[:model].errors != [] do %>
                <label class="label">
                  <span class="label-text-alt text-error">
                    {Enum.map(@form[:model].errors, fn {msg, _} -> msg end) |> Enum.join(", ")}
                  </span>
                </label>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Available Models</span>
              </label>
              <p class="text-sm text-base-content/70 mb-2">
                Manage models for this provider. Check models to make them available in conversations.
              </p>
              
    <!-- Add new models (batch input supported) -->
              <div class="mb-3">
                <textarea
                  name="new_model"
                  placeholder="Enter model names (one per line)"
                  class="textarea textarea-bordered w-full text-sm"
                  rows="3"
                  phx-change="update_new_model"
                  phx-debounce="100"
                >{@new_model_input}</textarea>
                <div class="flex justify-end mt-2">
                  <button
                    type="button"
                    class="btn btn-sm btn-primary"
                    phx-click="add_models"
                    disabled={@new_model_input == nil or String.trim(@new_model_input) == ""}
                  >
                    <.dm_mdi name="plus" class="w-4 h-4" /> Add Models
                  </button>
                </div>
              </div>

              <%= if length(@supported_models) > 0 do %>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-2 p-4 bg-base-200 rounded-lg">
                  <%= for model <- @supported_models do %>
                    <div class="flex items-center justify-between hover:bg-base-300 rounded px-2 py-1">
                      <label class="label cursor-pointer justify-start gap-3 flex-1">
                        <input
                          type="checkbox"
                          checked={model in @selected_models}
                          phx-click="toggle_model"
                          phx-value-model={model}
                          class="checkbox checkbox-sm checkbox-primary"
                        />
                        <span class="label-text text-sm">{model}</span>
                      </label>
                      <button
                        type="button"
                        phx-click="remove_model"
                        phx-value-model={model}
                        class="btn btn-ghost btn-xs text-error"
                        title="Remove model"
                      >
                        <.dm_mdi name="close" class="w-4 h-4" />
                      </button>
                    </div>
                  <% end %>
                </div>
                <label class="label">
                  <span class="label-text-alt">
                    {length(@selected_models)} of {length(@supported_models)} models enabled
                  </span>
                </label>
              <% else %>
                <div class="p-4 bg-base-200 rounded-lg text-center text-base-content/60">
                  No models added yet. Add models using the input above.
                </div>
              <% end %>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Description</span>
              </label>
              <textarea
                name={@form[:description].name}
                placeholder="Optional description of this provider"
                class="textarea textarea-bordered w-full"
                rows="3"
              >{@form[:description].value}</textarea>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-3">
                <input
                  type="checkbox"
                  name={@form[:is_active].name}
                  value="true"
                  checked={@form[:is_active].value == true || @form[:is_active].value == "true"}
                  class="checkbox checkbox-primary"
                />
                <span class="label-text font-semibold">Active</span>
              </label>
              <label class="label">
                <span class="label-text-alt">Only active providers can be used for chat</span>
              </label>
            </div>

            <div class="flex justify-end gap-3 pt-4">
              <.link navigate={~p"/chat/settings"} class="btn btn-ghost">
                Cancel
              </.link>
              <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
                <.dm_mdi name="content-save" class="w-4 h-4 mr-2" />
                {if @live_action == :new, do: "Create Provider", else: "Update Provider"}
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
