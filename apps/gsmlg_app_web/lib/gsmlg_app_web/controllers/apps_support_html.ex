defmodule GsmlgAppWeb.AppsSupportHTML do
  use GsmlgAppWeb, :html
  use Gettext, backend: GsmlgAppWeb.Gettext

  embed_templates("apps_support_html/*")
end
