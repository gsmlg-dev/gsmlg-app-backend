defmodule GsmlgAppAdmin.AI.UsageSummaryTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdmin.AI

  defp make_log(attrs) do
    defaults = %{
      endpoint_type: :chat,
      model: "gpt-4o",
      prompt_tokens: 10,
      completion_tokens: 20,
      total_tokens: 30,
      duration_ms: 100,
      status: :success
    }

    Map.merge(defaults, attrs)
  end

  describe "usage_summary/1" do
    test "returns zeroed stats for empty logs" do
      summary = AI.usage_summary([])

      assert summary.total_requests == 0
      assert summary.total_tokens == 0
      assert summary.total_prompt_tokens == 0
      assert summary.total_completion_tokens == 0
      assert summary.error_count == 0
      assert summary.success_count == 0
      assert summary.by_endpoint == %{}
      assert summary.by_model == %{}
    end

    test "computes correct totals" do
      logs = [
        make_log(%{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30}),
        make_log(%{prompt_tokens: 50, completion_tokens: 100, total_tokens: 150})
      ]

      summary = AI.usage_summary(logs)

      assert summary.total_requests == 2
      assert summary.total_tokens == 180
      assert summary.total_prompt_tokens == 60
      assert summary.total_completion_tokens == 120
    end

    test "counts successes and errors" do
      logs = [
        make_log(%{status: :success}),
        make_log(%{status: :success}),
        make_log(%{status: :error})
      ]

      summary = AI.usage_summary(logs)

      assert summary.success_count == 2
      assert summary.error_count == 1
    end

    test "groups by endpoint type" do
      logs = [
        make_log(%{endpoint_type: :chat}),
        make_log(%{endpoint_type: :chat}),
        make_log(%{endpoint_type: :image})
      ]

      summary = AI.usage_summary(logs)

      assert summary.by_endpoint == %{chat: 2, image: 1}
    end

    test "groups by model and excludes nil models" do
      logs = [
        make_log(%{model: "gpt-4o"}),
        make_log(%{model: "gpt-4o"}),
        make_log(%{model: "claude-sonnet-4-20250514"}),
        make_log(%{model: nil})
      ]

      summary = AI.usage_summary(logs)

      assert summary.by_model == %{"gpt-4o" => 2, "claude-sonnet-4-20250514" => 1}
    end

    test "handles nil token values" do
      logs = [
        make_log(%{prompt_tokens: nil, completion_tokens: nil, total_tokens: nil}),
        make_log(%{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30})
      ]

      summary = AI.usage_summary(logs)

      assert summary.total_tokens == 30
      assert summary.total_prompt_tokens == 10
      assert summary.total_completion_tokens == 20
    end
  end
end
