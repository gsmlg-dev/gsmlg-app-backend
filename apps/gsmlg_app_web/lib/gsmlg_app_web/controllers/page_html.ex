defmodule GsmlgAppWeb.PageHTML do
  use GsmlgAppWeb, :html
  use Gettext, backend: GsmlgAppWeb.Gettext

  embed_templates "page_html/*"
end
