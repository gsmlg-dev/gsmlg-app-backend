defmodule GsmlgAppAdmin.Accounts.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        GsmlgAppAdmin.Accounts.User,
        _opts,
        _context
      ) do
    case Application.fetch_env(:gsmlg_app_admin, :token_signing_secret) do
      {:ok, secret} ->
        {:ok, secret}

      :error ->
        case Application.fetch_env(:gsmlg_app_admin_web, GsmlgAppAdminWeb.Endpoint) do
          {:ok, endpoint_config} ->
            Keyword.fetch(endpoint_config, :secret_key_base)

          :error ->
            :error
        end
    end
  end
end
