defmodule GsmlgAppAdminWeb.Layouts do
  @moduledoc """
  Layout components for the admin web interface.

  Provides:
  - `root/1` - The root HTML layout (embedded from root.html.heex)
  - `app/1` - The app layout with header and navigation (embedded from app.html.heex)
  """
  use GsmlgAppAdminWeb, :html

  embed_templates "layouts/*"
end
