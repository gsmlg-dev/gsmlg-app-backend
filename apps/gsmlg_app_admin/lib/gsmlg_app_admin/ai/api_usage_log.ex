defmodule GsmlgAppAdmin.AI.ApiUsageLog do
  @moduledoc """
  Logs every API gateway request for usage tracking and analytics.

  Records endpoint type, model, token counts, duration, and status.
  """

  use Ash.Resource,
    domain: GsmlgAppAdmin.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_api_usage_logs")
    repo(GsmlgAppAdmin.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :endpoint_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:chat, :image, :ocr, :agent])
      description("Type of API endpoint used")
    end

    attribute :model, :string do
      allow_nil?(false)
      description("Model used for the request")
    end

    attribute :prompt_tokens, :integer do
      default(0)
      description("Number of prompt/input tokens")
    end

    attribute :completion_tokens, :integer do
      default(0)
      description("Number of completion/output tokens")
    end

    attribute :total_tokens, :integer do
      default(0)
      description("Total tokens consumed")
    end

    attribute :images_generated, :integer do
      default(0)
      description("Number of images generated (for image requests)")
    end

    attribute :duration_ms, :integer do
      description("Request duration in milliseconds")
    end

    attribute :status, :atom do
      allow_nil?(false)
      constraints(one_of: [:success, :error, :rate_limited])
      description("Request outcome")
    end

    attribute :error_message, :string do
      description("Error details if status is :error")
    end

    attribute :request_ip, :string do
      description("Client IP address")
    end

    attribute :api_key_id, :uuid do
      allow_nil?(false)
    end

    attribute :provider_id, :uuid do
      description("Provider used for the request")
    end

    attribute :agent_id, :uuid do
      description("Agent used (if agent endpoint)")
    end

    create_timestamp(:created_at)
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :endpoint_type,
        :model,
        :prompt_tokens,
        :completion_tokens,
        :total_tokens,
        :images_generated,
        :duration_ms,
        :status,
        :error_message,
        :request_ip,
        :api_key_id,
        :provider_id,
        :agent_id
      ])
    end

    read :for_api_key do
      argument(:api_key_id, :uuid, allow_nil?: false)
      filter(expr(api_key_id == ^arg(:api_key_id)))
      prepare(build(sort: [created_at: :desc]))
    end

    read :recent do
      prepare(build(sort: [created_at: :desc], limit: 100))
    end
  end

  code_interface do
    define(:create)
    define(:for_api_key, args: [:api_key_id])
    define(:recent, action: :recent)
  end
end
