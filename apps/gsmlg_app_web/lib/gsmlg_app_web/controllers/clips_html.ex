defmodule GsmlgAppWeb.ClipsHTML do
  use GsmlgAppWeb, :html
  use Gettext, backend: GsmlgAppWeb.Gettext

  embed_templates("clips_html/*")
end
