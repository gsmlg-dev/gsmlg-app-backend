defmodule GsmlgAppAdmin.Blog do
  use Ash.Domain, otp_app: :gsmlg_app_admin

  resources do
    resource(GsmlgAppAdmin.Blog.Post)
  end
end
