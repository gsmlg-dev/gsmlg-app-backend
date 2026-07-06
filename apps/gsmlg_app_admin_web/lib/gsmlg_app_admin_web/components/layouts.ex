defmodule GsmlgAppAdminWeb.Layouts do
  @moduledoc """
  Layout components for the admin web interface.

  Provides:
  - `root/1` - The root HTML layout (embedded from root.html.heex)
  - `app/1` - The app layout with header and navigation (embedded from app.html.heex)
  """
  use GsmlgAppAdminWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true

  def accessible_flash_group(assigns) do
    ~H"""
    <div class="toast-container toast-container-top-right">
      <.dm_flash id="flash-info" kind={:info} title="Success!" flash={@flash} />
      <.dm_flash id="flash-error" kind={:error} title="Error!" flash={@flash} />
      <.dm_flash
        id="disconnected"
        kind={:error}
        title="We can't find the internet"
        close={false}
        autoshow={false}
        aria-hidden="true"
        phx-disconnected={
          JS.remove_attribute("aria-hidden", to: "#disconnected")
          |> JS.add_class("toast-open", to: "#disconnected")
        }
        phx-connected={
          JS.remove_class("toast-open", to: "#disconnected")
          |> JS.set_attribute({"aria-hidden", "true"}, to: "#disconnected")
        }
      >
        Attempting to reconnect
        <.dm_bsi
          name="arrow-repeat"
          class="inline ml-1 w-3 h-3 animate-spin"
          aria-hidden="true"
        />
      </.dm_flash>
    </div>
    """
  end
end
