defmodule GsmlgAppAdmin.AI.McpServer do
  @moduledoc """
  Represents a connected MCP (Model Context Protocol) server.

  MCP servers expose tools, resources, and prompts over JSON-RPC.
  Supports stdio, SSE, and Streamable HTTP transports.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_mcp_servers")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100)
      description("Human-readable name")
    end

    attribute :slug, :string do
      allow_nil?(false)
      constraints(max_length: 50)
      description("URL-friendly identifier")
    end

    attribute :description, :string do
      description("Server description")
    end

    attribute :transport_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:stdio, :sse, :streamable_http])
      description("How to connect: stdio, SSE, or Streamable HTTP")
    end

    attribute :connection_config, :map do
      allow_nil?(false)
      sensitive?(true)
      description("Transport-specific config: command/args/env or url/headers")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this server is enabled")
    end

    attribute :auto_sync_tools, :boolean do
      allow_nil?(false)
      default(true)
      description("Auto-sync tools from tools/list")
    end

    attribute :health_status, :atom do
      default(:disconnected)
      constraints(one_of: [:connected, :disconnected, :error])
      description("Current connection health")
    end

    attribute :last_connected_at, :utc_datetime_usec do
      description("Last successful connection")
    end

    attribute :last_error, :string do
      description("Last connection/execution error")
    end

    attribute :server_info, :map do
      description("MCP server info from initialize response")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :slug,
        :description,
        :transport_type,
        :connection_config,
        :is_active,
        :auto_sync_tools
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :description,
        :transport_type,
        :connection_config,
        :is_active,
        :auto_sync_tools
      ])
    end

    update :update_health do
      description("Update connection health status")
      require_atomic?(false)
      accept([:health_status, :last_error, :last_connected_at, :server_info])
    end

    read :active do
      filter(expr(is_active == true))
      prepare(build(sort: [name: :asc]))
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
    define(:update_health)
    define(:active, action: :active)
    define(:by_slug, args: [:slug])
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
