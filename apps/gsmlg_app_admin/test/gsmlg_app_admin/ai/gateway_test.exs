defmodule GsmlgAppAdmin.AI.GatewayTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdmin.AI.Gateway

  describe "inject_system_context/2" do
    test "returns request unchanged when no templates or memories" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "You are helpful.",
        messages: [%{role: :user, content: "Hello"}],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      # System prompt should be preserved (may have date context appended)
      assert result.system =~ "You are helpful."
    end

    test "preserves caller system prompt when no admin context" do
      api_key = %{id: "test-key", user_id: nil, scopes: [:chat_completions]}

      request = %{
        model: "gpt-4o",
        system: "Custom system prompt",
        messages: [],
        stream: false,
        params: %{}
      }

      result = Gateway.inject_system_context(api_key, request)
      assert result.system =~ "Custom system prompt"
    end
  end

  describe "list_models/1" do
    test "returns error when no providers available" do
      api_key = %{
        id: "test-key",
        user_id: nil,
        scopes: [:models_list],
        allowed_providers: [],
        allowed_models: []
      }

      # Without DB, list_active_providers will fail
      assert {:error, _} = Gateway.list_models(api_key)
    end
  end
end
