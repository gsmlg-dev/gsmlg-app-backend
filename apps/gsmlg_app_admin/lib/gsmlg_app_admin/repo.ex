defmodule GsmlgAppAdmin.Repo do
  use AshPostgres.Repo, otp_app: :gsmlg_app_admin

  # Installs Postgres extensions that ash commonly uses
  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end
