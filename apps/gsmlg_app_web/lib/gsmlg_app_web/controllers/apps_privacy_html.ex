defmodule GsmlgAppWeb.AppsPrivacyHTML do
  use GsmlgAppWeb, :html
  use Gettext, backend: GsmlgAppWeb.Gettext

  embed_templates("apps_privacy_html/*")
end
