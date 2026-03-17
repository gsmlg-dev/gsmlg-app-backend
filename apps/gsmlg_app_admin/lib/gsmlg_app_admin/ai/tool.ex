defmodule GsmlgAppAdmin.AI.Tool do
  @moduledoc """
  A reusable function definition that the LLM can invoke.

  Supports multiple execution types: webhook, builtin, code, mcp, passthrough.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_tools")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100)
      description("Tool name (used in LLM function calling)")
    end

    attribute :slug, :string do
      allow_nil?(false)
      constraints(max_length: 50)
      description("URL-friendly identifier")
    end

    attribute :description, :string do
      allow_nil?(false)
      description("Tool description (used in LLM tool description)")
    end

    attribute :execution_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:webhook, :builtin, :code, :mcp, :passthrough])
      description("How the tool executes when invoked")
    end

    attribute :parameters_schema, :map do
      description("JSON Schema for tool parameters")
    end

    attribute :webhook_url, :string do
      description("URL to call for webhook execution")
    end

    attribute :webhook_method, :atom do
      default(:post)
      constraints(one_of: [:post, :get, :put, :delete])
      description("HTTP method for webhook")
    end

    attribute :webhook_headers, :map do
      sensitive?(true)
      description("Headers for webhook requests (supports {{secret:key}} interpolation)")
    end

    attribute :builtin_handler, :string do
      description("Module/function name for builtin execution")
    end

    attribute :code_body, :string do
      description("Elixir code string for code execution")
    end

    attribute :mcp_server_id, :uuid do
      description("MCP server for MCP execution")
    end

    attribute :mcp_tool_name, :string do
      description("Tool name on the MCP server")
    end

    attribute :is_mcp_synced, :boolean do
      default(false)
      description("True if auto-created from MCP tools/list")
    end

    attribute :timeout_ms, :integer do
      default(30_000)
      description("Execution timeout in milliseconds")
    end

    attribute :rate_limit_per_minute, :integer do
      description("Per-tool invocation limit per minute")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this tool is active")
    end

    attribute :metadata, :map do
      description("Arbitrary configuration (retry policy, response transform, etc.)")
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
        :execution_type,
        :parameters_schema,
        :webhook_url,
        :webhook_method,
        :webhook_headers,
        :builtin_handler,
        :code_body,
        :mcp_server_id,
        :mcp_tool_name,
        :is_mcp_synced,
        :timeout_ms,
        :rate_limit_per_minute,
        :is_active,
        :metadata
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :description,
        :parameters_schema,
        :webhook_url,
        :webhook_method,
        :webhook_headers,
        :builtin_handler,
        :code_body,
        :timeout_ms,
        :rate_limit_per_minute,
        :is_active,
        :metadata
      ])
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
    define(:active, action: :active)
    define(:by_slug, args: [:slug])
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
