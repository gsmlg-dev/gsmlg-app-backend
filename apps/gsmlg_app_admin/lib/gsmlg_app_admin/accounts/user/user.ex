defmodule GsmlgAppAdmin.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication],
    domain: GsmlgAppAdmin.Accounts,
    data_layer: AshPostgres.DataLayer,
    fragments: [GsmlgAppAdmin.Accounts.User.Policies]

  require Ash.Query

  actions do
    # Add a set of default actions for full CRUD operations
    defaults([:read, :create, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:hashed_password, :string, sensitive?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  authentication do
    strategies do
      password :default do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        sign_in_tokens_enabled?(true)
      end
    end

    tokens do
      enabled?(true)
      token_resource(GsmlgAppAdmin.Accounts.Token)
      require_token_presence_for_authentication?(true)
    end

    session_identifier(:jti)
    subject_name(:email)
  end

  relationships do
    has_one :token, GsmlgAppAdmin.Accounts.Token do
      destination_attribute(:user_id)
    end
  end

  postgres do
    table("users")
    repo(GsmlgAppAdmin.Repo)
  end

  identities do
    identity(:unique_email, [:email])
  end

  validations do
    validate(match(:email, ~r/^[^\s]+@[^\s]+$/), message: "must have the @ sign and no spaces")
  end

  # If using policies, add the folowing bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
