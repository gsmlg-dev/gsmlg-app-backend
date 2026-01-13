defmodule GsmlgAppAdmin.Apps.App do
  @moduledoc """
  Represents a mobile or desktop application listing.

  Apps have metadata (name, description, platforms, category) and can have
  multiple store links. Supports soft delete via is_active flag and manual
  ordering via display_order.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.Apps,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("apps")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100)
      description("Display name of the app")
    end

    attribute :label, :string do
      allow_nil?(false)
      constraints(max_length: 50)
      description("URL-friendly unique identifier (e.g., 'geoip_lookup')")
    end

    attribute :short_description, :string do
      allow_nil?(false)
      constraints(max_length: 200)
      description("Brief tagline for the app")
    end

    attribute :long_description, :string do
      description("Detailed description of the app")
    end

    attribute :icon_path, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("Path to icon image (e.g., '/images/icons/app.png')")
    end

    attribute :platforms, {:array, :atom} do
      allow_nil?(false)
      constraints(items: [one_of: [:ios, :android, :macos, :windows, :linux]])
      description("Supported platforms")
    end

    attribute :category, :atom do
      allow_nil?(false)
      constraints(one_of: [:network, :utility, :development])
      description("App category")
    end

    attribute :display_order, :integer do
      allow_nil?(false)
      default(0)
      description("Position for manual sorting (lower = first)")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether the app is active (false = soft deleted)")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :store_links, GsmlgAppAdmin.Apps.StoreLink do
      destination_attribute(:app_id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :name,
        :label,
        :short_description,
        :long_description,
        :icon_path,
        :platforms,
        :category,
        :display_order,
        :is_active
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :label,
        :short_description,
        :long_description,
        :icon_path,
        :platforms,
        :category,
        :display_order,
        :is_active
      ])
    end

    update :soft_delete do
      description("Soft delete by setting is_active to false")
      change(set_attribute(:is_active, false))
    end

    update :restore do
      description("Restore a soft-deleted app")
      change(set_attribute(:is_active, true))
    end

    update :reorder do
      description("Update display order")
      argument(:new_order, :integer, allow_nil?: false)
      change(set_attribute(:display_order, arg(:new_order)))
    end

    read :active do
      description("List only active apps")
      filter(expr(is_active == true))
      prepare(build(sort: [display_order: :asc]))
    end

    read :inactive do
      description("List only inactive (deleted) apps")
      filter(expr(is_active == false))
      prepare(build(sort: [display_order: :asc]))
    end

    read :by_label do
      description("Get app by label")
      argument(:label, :string, allow_nil?: false)
      filter(expr(label == ^arg(:label)))
    end

    destroy :destroy do
      primary?(true)
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:soft_delete)
    define(:restore)
    define(:reorder, args: [:new_order])
    define(:active, action: :active)
    define(:inactive, action: :inactive)
    define(:by_label, args: [:label])
  end

  identities do
    identity(:unique_label, [:label])
  end

  validations do
    validate(match(:label, ~r/^[a-z0-9_]+$/),
      message: "Label must contain only lowercase letters, numbers, and underscores"
    )

    validate(present(:platforms), message: "At least one platform must be selected")
  end
end
