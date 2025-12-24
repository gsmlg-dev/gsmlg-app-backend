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

    socket
    |> assign(:page_title, "Add Provider")
    |> assign(:provider, nil)
    |> assign(:form, to_form(form))
    |> assign(:preset_options, ProviderPresets.options())
    |> assign(:selected_preset, "generic")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    provider = AI.get_provider!(id)
    form = AshPhoenix.Form.for_update(provider, :update, as: "provider")

    socket
    |> assign(:page_title, "Edit Provider")
    |> assign(:provider, provider)
    |> assign(:form, to_form(form))
    |> assign(:preset_options, nil)
    |> assign(:selected_preset, nil)
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
    preset_params = ProviderPresets.to_form_params(preset_id)

    form =
      AshPhoenix.Form.for_create(Provider, :create, as: "provider")
      |> AshPhoenix.Form.validate(preset_params)
      |> to_form()

    {:noreply,
     socket
     |> assign(:selected_preset, preset_id)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
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
