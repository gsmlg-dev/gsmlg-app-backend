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

    # Custom action for seeding admin users
    create :seed_admin do
      accept([
        :email,
        :hashed_password,
        :first_name,
        :last_name,
        :username,
        :display_name,
        :status,
        :email_verified,
        :email_verified_at,
        :last_login_at,
        :failed_login_attempts,
        :locked_until,
        :role,
        :is_admin,
        :timezone,
        :language
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:hashed_password, :string, sensitive?: true)

    # Basic profile fields
    attribute(:first_name, :string, public?: true)
    attribute(:last_name, :string, public?: true)
    attribute(:username, :string, public?: true)
    attribute(:display_name, :string, public?: true)

    # User status and verification
    attribute(:status, :atom, default: :active, allow_nil?: false, public?: true)
    attribute(:email_verified, :boolean, default: false, allow_nil?: false, public?: true)
    attribute(:email_verified_at, :utc_datetime_usec, public?: true)

    # Security and audit fields
    attribute(:last_login_at, :utc_datetime_usec, public?: true)
    attribute(:failed_login_attempts, :integer, default: 0, allow_nil?: false, public?: true)
    attribute(:locked_until, :utc_datetime_usec, public?: true)

    # Role and permissions
    attribute(:role, :atom, default: :user, allow_nil?: false, public?: true)
    attribute(:is_admin, :boolean, default: false, allow_nil?: false, public?: true)

    # User preferences
    attribute(:timezone, :string, default: "UTC", allow_nil?: false, public?: true)
    attribute(:language, :string, default: "en", allow_nil?: false, public?: true)

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
    identity(:unique_username, [:username])
  end

  validations do
    validate(match(:email, ~r/^[^\s]+@[^\s]+$/), message: "must have the @ sign and no spaces")

    validate(match(:username, ~r/^[a-zA-Z0-9_]{3,20}$/),
      message: "must be 3-20 characters, letters, numbers, and underscores only"
    )

    validate(string_length(:first_name, min: 1, max: 50),
      message: "must be between 1 and 50 characters"
    )

    validate(string_length(:last_name, min: 1, max: 50),
      message: "must be between 1 and 50 characters"
    )

    validate(string_length(:display_name, min: 1, max: 100),
      message: "must be between 1 and 100 characters"
    )

    validate(one_of(:status, [:active, :inactive, :suspended, :pending]),
      message: "must be one of: active, inactive, suspended, pending"
    )

    validate(one_of(:role, [:admin, :user, :moderator]),
      message: "must be one of: admin, user, moderator"
    )
  end

  # If using policies, add the folowing bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
