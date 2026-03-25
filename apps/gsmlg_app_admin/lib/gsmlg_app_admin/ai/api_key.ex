defmodule GsmlgAppAdmin.AI.ApiKey do
  @moduledoc """
  API key for external access to the AI Gateway.

  Keys are formatted as `gsk_` + 48 random base64 chars. Only the SHA-256 hash
  is stored; the full key is shown once at creation.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_api_keys")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100)
      description("Human-readable name for this API key")
    end

    attribute :description, :string do
      description("Optional description of this key's purpose")
    end

    attribute :key_prefix, :string do
      allow_nil?(false)
      constraints(max_length: 8)
      description("First 8 chars of the key for lookup")
    end

    attribute :key_hash, :string do
      allow_nil?(false)
      sensitive?(true)
      description("SHA-256 hash of the full API key")
    end

    attribute :scopes, {:array, :atom} do
      default([:chat_completions, :messages, :images, :ocr, :agents, :models_list])
      description("Allowed API scopes for this key")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this key is active")
    end

    attribute :expires_at, :utc_datetime_usec do
      description("Optional expiry timestamp")
    end

    attribute :last_used_at, :utc_datetime_usec do
      description("Timestamp of last usage")
    end

    attribute :rate_limit_rpm, :integer do
      description("Per-key requests per minute override (nil = system default)")
    end

    attribute :rate_limit_rpd, :integer do
      description("Per-key requests per day override (nil = system default)")
    end

    attribute :allowed_providers, {:array, :uuid} do
      default([])
      description("Restrict to specific provider IDs (empty = all)")
    end

    attribute :allowed_models, {:array, :string} do
      default([])
      description("Restrict to specific model names (empty = all)")
    end

    attribute :total_requests, :integer do
      default(0)
      allow_nil?(false)
      description("Total number of requests made with this key")
    end

    attribute :total_tokens, :integer do
      default(0)
      allow_nil?(false)
      description("Total tokens consumed through this key")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, GsmlgAppAdmin.Accounts.User do
      allow_nil?(false)
      description("The user who owns this API key")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :description,
        :scopes,
        :is_active,
        :expires_at,
        :rate_limit_rpm,
        :rate_limit_rpd,
        :allowed_providers,
        :allowed_models,
        :user_id
      ])

      change(fn changeset, _context ->
        raw_key = generate_raw_key()
        prefix = String.slice(raw_key, 0, 8)
        hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)

        changeset
        |> Ash.Changeset.change_attribute(:key_prefix, prefix)
        |> Ash.Changeset.change_attribute(:key_hash, hash)
        |> Ash.Changeset.after_action(fn _changeset, record ->
          {:ok, Map.put(record, :__raw_key__, raw_key)}
        end)
      end)
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :description,
        :scopes,
        :is_active,
        :expires_at,
        :rate_limit_rpm,
        :rate_limit_rpd,
        :allowed_providers,
        :allowed_models
      ])
    end

    update :revoke do
      description("Revoke this API key")
      require_atomic?(false)

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :is_active, false)
      end)
    end

    update :increment_usage do
      description("Increment usage counters after a request")
      require_atomic?(false)
      argument(:requests, :integer, default: 1)
      argument(:tokens, :integer, default: 0)

      change(fn changeset, _context ->
        requests = Ash.Changeset.get_argument(changeset, :requests) || 1
        tokens = Ash.Changeset.get_argument(changeset, :tokens) || 0

        changeset
        |> Ash.Changeset.atomic_update(:total_requests, expr(total_requests + ^requests))
        |> Ash.Changeset.atomic_update(:total_tokens, expr(total_tokens + ^tokens))
        |> Ash.Changeset.change_attribute(:last_used_at, DateTime.utc_now())
      end)
    end

    read :by_prefix do
      argument(:prefix, :string, allow_nil?: false)
      filter(expr(key_prefix == ^arg(:prefix)))
    end

    read :active_for_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id) and is_active == true))
      prepare(build(sort: [created_at: :desc]))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:revoke)
    define(:increment_usage, args: [:requests, :tokens])
    define(:by_prefix, args: [:prefix])
    define(:active_for_user, args: [:user_id])
  end

  identities do
    identity(:unique_key_prefix, [:key_prefix])
  end

  @doc false
  def generate_raw_key do
    random_bytes = :crypto.strong_rand_bytes(36)
    "gsk_" <> Base.url_encode64(random_bytes, padding: false)
  end

  @doc """
  Verifies a raw API key against a stored hash.
  """
  def verify_key(raw_key, key_hash) do
    computed_hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
    Plug.Crypto.secure_compare(computed_hash, key_hash)
  end
end
