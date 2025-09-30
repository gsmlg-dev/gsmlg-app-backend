defmodule GsmlgAppAdmin.Accounts.Token do
  use Ash.Resource,
    domain: GsmlgAppAdmin.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :user, GsmlgAppAdmin.Accounts.User
  end

  policies do
    policy always() do
      description("""
      There are currently no usages of user tokens resource that should be publicly accessible.
      """)

      forbid_if(always())
    end
  end

  postgres do
    table("tokens")
    repo(GsmlgAppAdmin.Repo)

    references do
      reference(:user, on_delete: :delete, on_update: :update)
    end
  end

  resource do
    description("""
    Represents a token allowing a user to log in, reset their password, or confirm their email.
    """)
  end
end
