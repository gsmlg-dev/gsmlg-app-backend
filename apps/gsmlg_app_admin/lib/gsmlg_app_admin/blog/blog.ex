defmodule GsmlgAppAdmin.Blog do
  @moduledoc """
  The Blog domain manages blog posts and related content.

  This domain provides resources and functionality for creating,
  reading, updating, and deleting blog posts.
  """
  use Ash.Domain, otp_app: :gsmlg_app_admin

  resources do
    resource(GsmlgAppAdmin.Blog.Post)
  end
end
