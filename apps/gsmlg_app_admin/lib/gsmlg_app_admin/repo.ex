defmodule GsmlgAppAdmin.Repo do
  use AshPostgres.Repo, otp_app: :gsmlg_app_admin

  # Installs Postgres extensions that ash commonly uses
  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
