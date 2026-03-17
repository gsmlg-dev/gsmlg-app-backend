defmodule GsmlgAppAdminWeb.ApiKeyLive.FormComponent do
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

  @impl true
  def update(%{api_key: api_key, action: action} = assigns, socket) do
    form =
      case action do
        :new ->
          %{"name" => "", "description" => "", "scopes" => default_scopes()}
          |> to_form()

        :edit ->
          %{
            "name" => api_key.name,
            "description" => api_key.description || "",
            "scopes" => Enum.map(api_key.scopes || [], &to_string/1),
            "rate_limit_rpm" => api_key.rate_limit_rpm,
            "rate_limit_rpd" => api_key.rate_limit_rpd
          }
          |> to_form()
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    save(socket, socket.assigns.action, params)
  end

  defp save(socket, :new, params) do
    scopes =
      (params["scopes"] || [])
      |> Enum.map(&String.to_atom/1)

    attrs = %{
      name: params["name"],
      description: params["description"],
      scopes: scopes,
      rate_limit_rpm: parse_int(params["rate_limit_rpm"]),
      rate_limit_rpd: parse_int(params["rate_limit_rpd"]),
      user_id: socket.assigns.current_user.id
    }

    case AI.create_api_key(attrs) do
      {:ok, api_key} ->
        notify_parent({:saved, api_key})

        {:noreply,
         socket
         |> put_flash(:info, "API key created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create API key.")}
    end
  end

  defp save(socket, :edit, params) do
    scopes =
      (params["scopes"] || [])
      |> Enum.map(&String.to_atom/1)

    attrs = %{
      name: params["name"],
      description: params["description"],
      scopes: scopes,
      rate_limit_rpm: parse_int(params["rate_limit_rpm"]),
      rate_limit_rpd: parse_int(params["rate_limit_rpd"])
    }

    case AI.update_api_key(socket.assigns.api_key, attrs) do
      {:ok, api_key} ->
        notify_parent({:saved, api_key})

        {:noreply,
         socket
         |> put_flash(:info, "API key updated.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update API key.")}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val

  defp default_scopes do
    ~w(chat_completions messages images ocr agents models_list)
  end

  @all_scopes ~w(chat_completions messages images ocr agents models_list)

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :all_scopes, @all_scopes)

    ~H"""
    <div>
      <h2 class="text-xl font-bold mb-4">
        {if @action == :new, do: "New API Key", else: "Edit API Key"}
      </h2>

      <.form
        for={@form}
        id="api-key-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <div class="form-control">
            <label class="label"><span class="label-text">Name</span></label>
            <input
              type="text"
              name="form[name]"
              value={@form[:name].value}
              class="input input-bordered w-full"
              required
              placeholder="My API Key"
            />
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Description</span></label>
            <textarea
              name="form[description]"
              class="textarea textarea-bordered w-full"
              placeholder="Optional description"
            ><%= @form[:description].value %></textarea>
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Scopes</span></label>
            <div class="flex flex-wrap gap-2">
              <%= for scope <- @all_scopes do %>
                <label class="label cursor-pointer gap-2">
                  <input
                    type="checkbox"
                    name="form[scopes][]"
                    value={scope}
                    checked={scope in (@form[:scopes].value || [])}
                    class="checkbox checkbox-sm"
                  />
                  <span class="label-text">{scope}</span>
                </label>
              <% end %>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Rate Limit (RPM)</span></label>
              <input
                type="number"
                name="form[rate_limit_rpm]"
                value={@form[:rate_limit_rpm].value}
                class="input input-bordered w-full"
                placeholder="Default: 60"
              />
            </div>

            <div class="form-control">
              <label class="label"><span class="label-text">Rate Limit (RPD)</span></label>
              <input
                type="number"
                name="form[rate_limit_rpd]"
                value={@form[:rate_limit_rpd].value}
                class="input input-bordered w-full"
                placeholder="Default: 1000"
              />
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <.link patch={@patch} class="btn btn-ghost">Cancel</.link>
            <button type="submit" class="btn btn-primary">
              {if @action == :new, do: "Create Key", else: "Save Changes"}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
