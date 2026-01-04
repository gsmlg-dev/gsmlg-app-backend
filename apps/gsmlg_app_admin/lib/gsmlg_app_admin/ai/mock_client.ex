defmodule GsmlgAppAdmin.AI.MockClient do
  @moduledoc """
  Mock AI client for testing the chat interface without a real API key.

  Simulates streaming responses with realistic delays.
  """

  @sample_responses [
    "Hello! I'm a mock AI assistant. I can help you test the chat interface without needing a real API key. What would you like to know?",
    "That's an interesting question! In a real scenario, I would provide a detailed response based on the AI model's knowledge. For now, I'm just simulating a response to help you test the chat interface.",
    "I understand you're testing the chat functionality. The streaming you see is working correctly - in production, this would be a real AI response being generated token by token.",
    "Here are some features you can test:\n\n1. Creating new conversations\n2. Switching between providers\n3. Viewing message history\n4. Real-time streaming (like this!)\n5. Deleting conversations\n\nFeel free to explore the interface!",
    "Great question! Once you configure a real API key (like DeepSeek, Zhipu AI, or Moonshot), you'll get actual AI-powered responses. For now, I'm here to help you verify everything is working correctly.",
    "The chat interface supports multiple AI providers. You can switch between them using the dropdown in the sidebar. Each provider has different models and capabilities.",
    "Fun fact: This mock response is being streamed character by character, just like a real AI would respond. This helps you see how the streaming animation works!",
    "I notice you're testing the system. That's smart! It's always good to verify functionality before connecting to production APIs. Is there anything specific you'd like to test?"
  ]

  @doc """
  Simulates a streaming chat completion with a callback function.

  Unlike the real client which uses Req streaming, this mock streams
  synchronously within the calling process (typically a Task), so the
  Task can properly signal completion to the LiveView.
  """
  def stream_with_callback(_provider, messages, callback, _opts \\ []) do
    # Get the last user message
    last_message = List.last(messages)

    # Select a response based on message content or randomly
    response = select_response(last_message)

    # Stream the response character by character with realistic delays
    # Note: We do this synchronously so the Task calling this function
    # knows when streaming is complete and can send {:stream_complete, result}
    # Uses {:content, char} tuple format to match real client
    response
    |> String.graphemes()
    |> Enum.each(fn char ->
      callback.({:content, char})
      # Random delay between 20-50ms to simulate real streaming
      Process.sleep(Enum.random(20..50))
    end)

    {:ok, :streaming_complete}
  end

  @doc """
  Non-streaming chat completion (not used in the current implementation but available).
  """
  def chat_completion(_provider, messages, _opts \\ []) do
    last_message = List.last(messages)
    response = select_response(last_message)

    {:ok,
     %{
       content: response,
       model: "mock-model-v1",
       usage: %{
         "prompt_tokens" => 50,
         "completion_tokens" => String.length(response),
         "total_tokens" => 50 + String.length(response)
       }
     }}
  end

  # Private functions

  defp select_response(%{content: content}) when is_binary(content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["hello", "hi", "hey"]) ->
        "Hello! I'm a mock AI assistant. I can help you test the chat interface. What would you like to explore?"

      String.contains?(content_lower, ["test", "testing"]) ->
        "Great! You're testing the chat functionality. Everything is working correctly. The streaming, message history, and UI are all functional."

      String.contains?(content_lower, ["help", "how"]) ->
        "I'm here to help you test the interface! Try:\n\n• Creating multiple conversations\n• Switching providers\n• Sending different messages\n• Testing the streaming animation\n\nOnce you add a real API key, you'll get actual AI responses!"

      String.contains?(content_lower, ["api", "key"]) ->
        "To use real AI providers, you'll need to configure an API key:\n\n1. DeepSeek: https://platform.deepseek.com/\n2. Zhipu AI: https://open.bigmodel.cn/\n3. Moonshot: https://platform.moonshot.cn/\n\nFor now, I'm simulating responses so you can test the interface!"

      String.contains?(content_lower, ["feature", "what can"]) ->
        "This chat interface includes:\n\n✓ Real-time streaming responses\n✓ Multiple AI providers\n✓ Conversation history\n✓ Provider switching\n✓ Message persistence\n✓ Clean, responsive UI\n\nAll features are working - you're seeing them in action right now!"

      String.length(content) > 100 ->
        "I see you've sent a longer message! In production, the AI would analyze your full message and provide a comprehensive response. For testing, I'm just simulating streaming to show how the interface handles longer conversations."

      true ->
        # Random response for variety
        Enum.random(@sample_responses)
    end
  end

  defp select_response(_), do: Enum.random(@sample_responses)
end
