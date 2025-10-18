defmodule GsmlgAppWeb.AppsHTML do
  use GsmlgAppWeb, :html
  use Gettext, backend: GsmlgAppWeb.Gettext

  embed_templates "apps_html/*"
end
