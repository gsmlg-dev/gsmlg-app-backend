defmodule GsmlgAppAdmin.AI.BackplaneConfig do
  @moduledoc """
  Singleton configuration for the Backplane API server.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  @default_key "default"
  @default_server_url "http://localhost:4220"

  postgres do
    table("ai_backplane_configs")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :key, :string do
      allow_nil?(false)
      default(@default_key)
      public?(false)
    end

    attribute :server_url, :string do
      allow_nil?(false)
      default(@default_server_url)
      constraints(max_length: 500)
    end

    attribute :auth_token, :string do
      sensitive?(true)
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  calculations do
    calculate :masked_auth_token, :string do
      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.auth_token do
            nil -> nil
            "" -> nil
            token when byte_size(token) <= 4 -> "****"
            token -> "****#{String.slice(token, -4..-1//1)}"
          end
        end)
      end)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:server_url, :auth_token])
    end

    update :update do
      primary?(true)
      accept([:server_url, :auth_token])
    end

    read :default do
      filter(expr(key == @default_key))
      prepare(build(load: [:masked_auth_token]))
    end
  end

  code_interface do
    define(:default, action: :default)
    define(:create)
    define(:update)
  end

  identities do
    identity(:unique_key, [:key])
  end
end
