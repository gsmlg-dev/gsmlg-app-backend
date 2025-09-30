defmodule GsmlgAppAdmin.Accounts do
  use Ash.Domain, otp_app: :gsmlg_app_admin

  resources do
    resource(GsmlgAppAdmin.Accounts.User)
    resource(GsmlgAppAdmin.Accounts.Token)
  end
end
