defmodule GsmlgAppAdmin.Accounts.Token do
  @moduledoc """
  The Token resource represents authentication tokens in the system.

  Tokens are used by AshAuthentication for:
  - User session management (login tokens)
  - Password reset functionality
  - Email verification

  Each token has a purpose, expiration time, and is associated with
  a user via the subject field.
  """
  use Ash.Resource,
    domain: GsmlgAppAdmin.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    defaults([:read, :create, :update, :destroy])
  end

  attributes do
    attribute(:jti, :string, allow_nil?: false, primary_key?: true, writable?: true)
    attribute(:subject, :string, allow_nil?: false)
    attribute(:purpose, :string, allow_nil?: false)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false)
    attribute(:extra_data, :map)
    attribute(:created_at, :utc_datetime_usec, allow_nil?: false, default: &DateTime.utc_now/0)
    attribute(:updated_at, :utc_datetime_usec, allow_nil?: false, default: &DateTime.utc_now/0)
  end

  policies do
    policy always() do
      description("""
      Allow Ash Authentication to manage tokens for user sessions.
      """)

      authorize_if(AshAuthentication.Checks.AshAuthenticationInteraction)
    end
  end

  postgres do
    table("tokens")
    repo(GsmlgAppAdmin.Repo)
  end

  resource do
    description("""
    Represents a token allowing a user to log in, reset their password, or confirm their email.
    """)
  end
end
