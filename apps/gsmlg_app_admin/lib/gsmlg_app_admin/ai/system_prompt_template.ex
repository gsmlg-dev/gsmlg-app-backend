defmodule GsmlgAppAdmin.AI.SystemPromptTemplate do
  @moduledoc """
  Admin-defined reusable prompt blocks with variable interpolation.

  Supported variables:
  - `{{memory}}` — injects all applicable memories for the request
  - `{{date}}` — current UTC date (ISO 8601)
  - `{{datetime}}` — current UTC datetime (ISO 8601)
  - `{{user.display_name}}` — user's display name (falls back to username)
  - `{{user.email}}` — user's email address
  - `{{user.username}}` — user's username

  Templates marked as `is_default` are auto-injected into all gateway requests.
  Key-specific templates can be linked via `ApiKeyTemplate` and are injected
  after default templates for requests using that key.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_system_prompt_templates")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100)
      description("Display name of the template")
    end

    attribute :slug, :string do
      allow_nil?(false)
      constraints(max_length: 50)
      description("URL-friendly identifier")
    end

    attribute :content, :string do
      allow_nil?(false)
      description("Template content with {{variable}} placeholders")
    end

    attribute :is_default, :boolean do
      allow_nil?(false)
      default(false)
      description("Auto-inject into all gateway requests")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this template is active")
    end

    attribute :priority, :integer do
      allow_nil?(false)
      default(0)
      description("Ordering when multiple templates apply (higher = first)")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :slug, :content, :is_default, :is_active, :priority])
    end

    update :update do
      primary?(true)
      accept([:name, :content, :is_default, :is_active, :priority])
    end

    read :active_defaults do
      description("List active default templates ordered by priority")
      filter(expr(is_active == true and is_default == true))
      prepare(build(sort: [priority: :desc]))
    end

    read :active do
      filter(expr(is_active == true))
      prepare(build(sort: [priority: :desc]))
    end

    read :by_slug do
      argument(:slug, :string, allow_nil?: false)
      filter(expr(slug == ^arg(:slug)))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:active_defaults, action: :active_defaults)
    define(:active, action: :active)
    define(:by_slug, args: [:slug])
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
