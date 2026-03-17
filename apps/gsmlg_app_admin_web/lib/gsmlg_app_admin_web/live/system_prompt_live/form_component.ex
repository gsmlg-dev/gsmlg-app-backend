defmodule GsmlgAppAdminWeb.SystemPromptLive.FormComponent do
  use GsmlgAppAdminWeb, :live_component

  alias GsmlgAppAdmin.AI

  @impl true
  def update(%{template: template, action: action} = assigns, socket) do
    form =
      case action do
        :new ->
          %{
            "name" => "",
            "slug" => "",
            "content" => "",
            "is_default" => false,
            "is_active" => true,
            "priority" => 0
          }

        :edit ->
          %{
            "name" => template.name,
            "slug" => template.slug,
            "content" => template.content,
            "is_default" => template.is_default,
            "is_active" => template.is_active,
            "priority" => template.priority
          }
      end
      |> to_form()

    {:ok, socket |> assign(assigns) |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    attrs = %{
      name: params["name"],
      slug: params["slug"],
      content: params["content"],
      is_default: params["is_default"] == "true",
      is_active: params["is_active"] == "true",
      priority: String.to_integer(params["priority"] || "0")
    }

    result =
      case socket.assigns.action do
        :new -> AI.create_system_prompt_template(attrs)
        :edit -> AI.update_system_prompt_template(socket.assigns.template, attrs)
      end

    case result do
      {:ok, template} ->
        send(self(), {__MODULE__, {:saved, template}})

        {:noreply,
         socket |> put_flash(:info, "Template saved.") |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save template.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-bold mb-4">
        {if @action == :new, do: "New Template", else: "Edit Template"}
      </h2>

      <.form
        for={@form}
        id="template-form"
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
            />
          </div>

          <%= if @action == :new do %>
            <div class="form-control">
              <label class="label"><span class="label-text">Slug</span></label>
              <input
                type="text"
                name="form[slug]"
                value={@form[:slug].value}
                class="input input-bordered w-full"
                required
              />
            </div>
          <% end %>

          <div class="form-control">
            <label class="label"><span class="label-text">Content</span></label>
            <textarea name="form[content]" class="textarea textarea-bordered w-full h-40" required><%= @form[:content].value %></textarea>
            <p class="text-xs opacity-70 mt-1">
              Variables: {"{{memory}}"}, {"{{date}}"}, {"{{datetime}}"}
            </p>
          </div>

          <div class="flex gap-4">
            <label class="label cursor-pointer gap-2">
              <input type="hidden" name="form[is_default]" value="false" />
              <input
                type="checkbox"
                name="form[is_default]"
                value="true"
                checked={@form[:is_default].value == "true" or @form[:is_default].value == true}
                class="checkbox"
              />
              <span class="label-text">Default (auto-inject)</span>
            </label>
            <label class="label cursor-pointer gap-2">
              <input type="hidden" name="form[is_active]" value="false" />
              <input
                type="checkbox"
                name="form[is_active]"
                value="true"
                checked={@form[:is_active].value != "false" and @form[:is_active].value != false}
                class="checkbox"
              />
              <span class="label-text">Active</span>
            </label>
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Priority</span></label>
            <input
              type="number"
              name="form[priority]"
              value={@form[:priority].value}
              class="input input-bordered w-24"
            />
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <.link patch={@patch} class="btn btn-ghost">Cancel</.link>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
