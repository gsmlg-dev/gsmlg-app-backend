defmodule GsmlgAppAdmin.AI.Memory do
  @moduledoc """
  Persistent facts stored with scope for injection into AI requests.

  Scopes: `:global` (all users), `:user` (specific user), `:api_key` (specific key),
  `:agent` (specific agent).
  Categories: `:fact`, `:instruction`, `:preference`, `:context`.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_memories")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :content, :string do
      allow_nil?(false)
      description("Memory content text")
    end

    attribute :category, :atom do
      allow_nil?(false)
      constraints(one_of: [:fact, :instruction, :preference, :context])
      description("Memory category")
    end

    attribute :scope, :atom do
      allow_nil?(false)
      constraints(one_of: [:global, :user, :api_key, :agent])
      description("Memory scope")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this memory is active")
    end

    attribute :priority, :integer do
      allow_nil?(false)
      default(0)
      description("Ordering priority (higher = first)")
    end

    attribute :user_id, :uuid do
      description("Required when scope = :user")
    end

    attribute :api_key_id, :uuid do
      description("Required when scope = :api_key")
    end

    attribute :agent_id, :uuid do
      description("Required when scope = :agent")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :content,
        :category,
        :scope,
        :is_active,
        :priority,
        :user_id,
        :api_key_id,
        :agent_id
      ])

      validate(fn changeset, _context ->
        scope = Ash.Changeset.get_attribute(changeset, :scope)

        case scope do
          :user ->
            if Ash.Changeset.get_attribute(changeset, :user_id),
              do: :ok,
              else: {:error, field: :user_id, message: "is required when scope is :user"}

          :api_key ->
            if Ash.Changeset.get_attribute(changeset, :api_key_id),
              do: :ok,
              else: {:error, field: :api_key_id, message: "is required when scope is :api_key"}

          :agent ->
            if Ash.Changeset.get_attribute(changeset, :agent_id),
              do: :ok,
              else: {:error, field: :agent_id, message: "is required when scope is :agent"}

          _ ->
            :ok
        end
      end)
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      accept([
        :content,
        :category,
        :scope,
        :is_active,
        :priority,
        :user_id,
        :api_key_id,
        :agent_id
      ])

      validate(fn changeset, _context ->
        scope = Ash.Changeset.get_attribute(changeset, :scope)

        case scope do
          :user ->
            if Ash.Changeset.get_attribute(changeset, :user_id),
              do: :ok,
              else: {:error, field: :user_id, message: "is required when scope is :user"}

          :api_key ->
            if Ash.Changeset.get_attribute(changeset, :api_key_id),
              do: :ok,
              else: {:error, field: :api_key_id, message: "is required when scope is :api_key"}

          :agent ->
            if Ash.Changeset.get_attribute(changeset, :agent_id),
              do: :ok,
              else: {:error, field: :agent_id, message: "is required when scope is :agent"}

          _ ->
            :ok
        end
      end)
    end

    read :for_request do
      description("Fetch memories for a gateway request (global + user + key + agent scoped)")
      argument(:user_id, :uuid)
      argument(:api_key_id, :uuid)
      argument(:agent_id, :uuid)

      prepare(fn query, _context ->
        require Ash.Query

        user_id = Ash.Query.get_argument(query, :user_id)
        api_key_id = Ash.Query.get_argument(query, :api_key_id)
        agent_id = Ash.Query.get_argument(query, :agent_id)

        conditions = [expr(is_active == true and scope == :global)]

        conditions =
          if user_id do
            [expr(is_active == true and scope == :user and user_id == ^user_id) | conditions]
          else
            conditions
          end

        conditions =
          if api_key_id do
            [
              expr(is_active == true and scope == :api_key and api_key_id == ^api_key_id)
              | conditions
            ]
          else
            conditions
          end

        conditions =
          if agent_id do
            [expr(is_active == true and scope == :agent and agent_id == ^agent_id) | conditions]
          else
            conditions
          end

        combined = Enum.reduce(conditions, fn cond_expr, acc -> expr(^acc or ^cond_expr) end)

        query
        |> Ash.Query.filter(^combined)
        |> Ash.Query.sort(priority: :desc)
      end)
    end

    read :active do
      filter(expr(is_active == true))
      prepare(build(sort: [priority: :desc]))
    end
  end

  code_interface do
    define(:create)
    define(:update)
    define(:destroy)
    define(:for_request, args: [:user_id, :api_key_id, :agent_id])
    define(:active, action: :active)
  end
end
