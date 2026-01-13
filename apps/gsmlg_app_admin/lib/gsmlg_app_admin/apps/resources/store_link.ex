defmodule GsmlgAppAdmin.Apps.StoreLink do
  @moduledoc """
  Represents a link to an app store for downloading an app.

  Each app can have multiple store links (App Store, Play Store, F-Droid, etc.)
  with configurable display order.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.Apps,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("store_links")
    repo(GsmlgAppAdmin.Repo)

    references do
      reference(:app, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:appstore, :playstore, :fdroid, :other])
      description("Type of app store")
    end

    attribute :url, :string do
      allow_nil?(false)
      description("URL to the app store page")
    end

    attribute :display_order, :integer do
      allow_nil?(false)
      default(0)
      description("Order within the app's store links")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :app, GsmlgAppAdmin.Apps.App do
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :app_id,
        :store_type,
        :url,
        :display_order
      ])
    end

    update :update do
      primary?(true)

      accept([
        :store_type,
        :url,
        :display_order
      ])
    end

    destroy :destroy do
      primary?(true)
    end

    read :for_app do
      description("Get store links for a specific app")
      argument(:app_id, :uuid, allow_nil?: false)
      filter(expr(app_id == ^arg(:app_id)))
      prepare(build(sort: [display_order: :asc]))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:for_app, args: [:app_id])
  end

  validations do
    validate(match(:url, ~r/^https?:\/\/.+/),
      message: "URL must start with http:// or https://"
    )
  end
end
