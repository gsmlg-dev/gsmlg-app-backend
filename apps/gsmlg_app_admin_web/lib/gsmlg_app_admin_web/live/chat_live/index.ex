defmodule GsmlgAppAdminWeb.ChatLive.Index do
  @moduledoc """
  LiveView for AI chat interface with streaming support.
  """

  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.Client

  @impl true
  def mount(_params, _session, socket) do
    models = load_backplane_models()

    # current_user is already loaded by AshAuthentication.Phoenix.LiveSession on_mount
    current_user = socket.assigns[:current_user]

    selected_model = first_model_id(models)

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "AI Chat")
      |> assign(:models, models)
      |> assign(:selected_model, selected_model)
      |> assign(:conversations, [])
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])
      |> assign(:input, "")
      |> assign(:streaming, false)
      |> assign(:streaming_content, "")
      |> assign(:streaming_thinking, "")
      |> assign(:streaming_start_time, nil)
      |> assign(:streaming_token_count, 0)
      |> assign(:loading, false)
      |> assign(:editing_conversation, nil)
      |> assign(:edit_title, "")

    {:ok, load_conversations(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "AI Chat")
  end

  defp apply_action(socket, :conversation, %{"id" => id}) do
    case AI.get_conversation_with_messages(id) do
      {:ok, conversation} ->
        socket
        |> assign(:current_conversation, conversation)
        |> assign(:messages, conversation.messages || [])
        |> assign(:page_title, conversation.title)

      {:error, _} ->
        # Conversation was deleted or doesn't exist, redirect to chat index
        socket
        |> assign(:current_conversation, nil)
        |> assign(:messages, [])
        |> put_flash(:error, "Conversation not found")
        |> push_navigate(to: ~p"/chat")
    end
  end

  @impl true
  def handle_event("select_provider", %{"provider_model" => provider_model}, socket) do
    model = parse_model_selection(provider_model)

    socket =
      socket
      |> assign(:selected_model, model)
      |> push_event("save_provider_selection", %{provider_model: model})

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_provider_selection", %{"provider_model" => provider_model}, socket) do
    {:noreply, assign(socket, :selected_model, parse_model_selection(provider_model))}
  end

  # Legacy handler for old format
  @impl true
  def handle_event("restore_provider_selection", %{"provider_id" => provider_id}, socket) do
    {:noreply, assign(socket, :selected_model, provider_id)}
  end

  @impl true
  def handle_event("update_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input, message)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    cond do
      String.trim(message) == "" ->
        {:noreply, socket}

      is_nil(socket.assigns.current_user) ->
        {:noreply, put_flash(socket, :error, "Please log in to send messages")}

      true ->
        socket = ensure_conversation(socket)
        send_user_message(socket, message)
    end
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    socket =
      socket
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])
      |> assign(:input, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_conversation", %{"id" => id}, socket) do
    conversation = AI.get_conversation_with_messages!(id)
    {:ok, _} = Ash.destroy(conversation)

    socket =
      socket
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])
      |> load_conversations()
      |> put_flash(:info, "Conversation deleted")
      |> push_patch(to: ~p"/chat")

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_conversation_title", %{"id" => id}, socket) do
    conversation = Enum.find(socket.assigns.conversations, &(to_string(&1.id) == id))

    socket =
      socket
      |> assign(:editing_conversation, conversation)
      |> assign(:edit_title, (conversation && conversation.title) || "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_edit_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :edit_title, title)}
  end

  @impl true
  def handle_event("save_conversation_title", _params, socket) do
    conversation = socket.assigns.editing_conversation
    new_title = String.trim(socket.assigns.edit_title)

    socket =
      if conversation && new_title != "" do
        case AI.update_conversation(conversation, %{title: new_title}) do
          {:ok, updated_conversation} ->
            # Update current_conversation if it's the one being edited
            socket =
              if socket.assigns.current_conversation &&
                   socket.assigns.current_conversation.id == updated_conversation.id do
                assign(socket, :current_conversation, updated_conversation)
              else
                socket
              end

            socket
            |> assign(:editing_conversation, nil)
            |> assign(:edit_title, "")
            |> load_conversations()
            |> put_flash(:info, "Conversation title updated")

          {:error, _} ->
            socket
            |> put_flash(:error, "Failed to update conversation title")
        end
      else
        socket
        |> assign(:editing_conversation, nil)
        |> assign(:edit_title, "")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_edit_title", _params, socket) do
    socket =
      socket
      |> assign(:editing_conversation, nil)
      |> assign(:edit_title, "")

    {:noreply, socket}
  end

  # Private helper functions

  defp ensure_conversation(socket) do
    case socket.assigns.current_conversation do
      nil -> create_conversation(socket)
      _conversation -> socket
    end
  end

  defp create_conversation(socket) do
    user = socket.assigns.current_user

    {:ok, conversation} =
      AI.create_conversation(%{
        title: "New Chat",
        user_id: user.id,
        model_params: %{}
      })

    assign(socket, :current_conversation, conversation)
  end

  defp send_user_message(socket, content) do
    conversation = socket.assigns.current_conversation

    user_message_params = %{
      conversation_id: conversation.id,
      role: :user,
      content: content
    }

    {:ok, user_message} = AI.add_message(conversation.id, user_message_params)

    socket =
      socket
      |> assign(:input, "")
      |> assign(:loading, true)
      |> assign(:streaming, true)
      |> assign(:streaming_content, "")
      |> assign(:streaming_thinking, "")
      |> assign(:streaming_start_time, System.monotonic_time(:millisecond))
      |> assign(:streaming_token_count, 0)
      |> update(:messages, fn messages -> messages ++ [user_message] end)
      |> push_event("clear_input", %{})
      |> push_event("stream_start", %{})

    # Send to AI in background
    send(self(), {:request_ai_response, conversation.id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:request_ai_response, _conversation_id}, socket) do
    selected_model = socket.assigns.selected_model
    messages = Enum.map(socket.assigns.messages, &format_message_for_api/1)

    parent = self()

    Task.async(fn ->
      request = %{
        model: selected_model,
        system: nil,
        messages: messages,
        stream: true,
        params: %{}
      }

      result =
        if selected_model do
          Client.stream_with_callback(
            request,
            fn chunk ->
              send(parent, {:stream_chunk, chunk})
              chunk
            end,
            api_format: :openai
          )
        else
          {:error, "No Backplane model selected"}
        end

      send(parent, {:stream_complete, result})
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_chunk, {:thinking, chunk}}, socket) do
    # Handle thinking/reasoning content separately
    updated_thinking = socket.assigns.streaming_thinking <> chunk
    # Estimate tokens: roughly 4 characters per token
    chunk_tokens = max(1, div(String.length(chunk), 4))
    new_token_count = socket.assigns.streaming_token_count + chunk_tokens

    socket =
      socket
      |> assign(:streaming_thinking, updated_thinking)
      |> assign(:streaming_token_count, new_token_count)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_chunk, {:content, chunk}}, socket) do
    # Handle regular content
    updated_content = socket.assigns.streaming_content <> chunk
    # Estimate tokens: roughly 4 characters per token
    chunk_tokens = max(1, div(String.length(chunk), 4))
    new_token_count = socket.assigns.streaming_token_count + chunk_tokens

    socket =
      socket
      |> assign(:streaming_content, updated_content)
      |> assign(:streaming_token_count, new_token_count)
      |> push_event("stream_chunk", %{content: updated_content})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_complete, result}, socket) do
    socket = handle_stream_complete_result(socket, result)
    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, _result}, socket) when is_reference(ref) do
    # Ignore async task completion messages
    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Ignore task down messages
    {:noreply, socket}
  end

  defp handle_stream_complete_result(socket, {:error, error_message}) do
    socket
    |> reset_streaming_state()
    |> put_flash(:error, error_message)
  end

  defp handle_stream_complete_result(socket, {:ok, _}) do
    content = socket.assigns.streaming_content
    streaming_thinking = socket.assigns.streaming_thinking
    has_content = String.trim(content) != "" || String.trim(streaming_thinking) != ""

    if has_content do
      save_assistant_response(socket)
    else
      socket
      |> reset_streaming_state()
      |> put_flash(:error, "No response received from AI provider")
    end
  end

  defp save_assistant_response(socket) do
    conversation = socket.assigns.current_conversation
    content = socket.assigns.streaming_content
    streaming_thinking = socket.assigns.streaming_thinking
    selected_model = socket.assigns.selected_model
    start_time = socket.assigns.streaming_start_time
    token_count = socket.assigns.streaming_token_count

    # Calculate response speed
    end_time = System.monotonic_time(:millisecond)
    duration_seconds = max(1, end_time - (start_time || end_time)) / 1000
    tokens_per_second = Float.round(token_count / duration_seconds, 1)

    # Use streaming_thinking if available (from API reasoning_content field)
    # Otherwise, try to parse <think>...</think> tags from content
    {thinking, answer} =
      if streaming_thinking != "" do
        {streaming_thinking, content}
      else
        parse_thinking_content(content)
      end

    # For full content storage, combine thinking + answer
    full_content =
      if thinking && thinking != "" do
        "<think>#{thinking}</think>\n\n#{answer}"
      else
        content
      end

    # Build assistant message params
    model_name = selected_model || "Assistant"

    assistant_message_params = %{
      conversation_id: conversation.id,
      role: :assistant,
      content: full_content,
      metadata: %{
        model: model_name,
        provider: "Backplane",
        thinking: thinking,
        answer: answer,
        tokens: token_count,
        duration_seconds: Float.round(duration_seconds, 2),
        tokens_per_second: tokens_per_second
      }
    }

    case AI.add_message(conversation.id, assistant_message_params) do
      {:ok, assistant_message} ->
        socket
        |> reset_streaming_state()
        |> update(:messages, fn messages -> messages ++ [assistant_message] end)
        |> push_event("stream_end", %{content: answer})
        |> load_conversations()

      {:error, _error} ->
        socket
        |> reset_streaming_state()
        |> put_flash(:error, "Failed to save assistant response")
    end
  end

  defp load_conversations(socket) do
    case socket.assigns.current_user do
      nil ->
        socket

      user ->
        {:ok, conversations} = AI.list_conversations(user.id)
        assign(socket, :conversations, conversations)
    end
  end

  defp format_message_for_api(message) do
    %{
      role: message.role,
      content: message.content
    }
  end

  # Parse thinking content from AI response
  # Supports <think>...</think> tags used by models like DeepSeek
  defp parse_thinking_content(content) when is_binary(content) do
    # Try to match <think>...</think> pattern (case insensitive)
    case Regex.run(~r/<think>(.*?)<\/think>/is, content) do
      [full_match, thinking] ->
        # Remove the thinking block from content to get the answer
        answer = String.replace(content, full_match, "") |> String.trim()
        {String.trim(thinking), answer}

      nil ->
        # No thinking tags found, return empty thinking and full content as answer
        {nil, content}
    end
  end

  defp parse_thinking_content(nil), do: {nil, nil}

  # Get thinking and answer from message metadata or parse from content
  # Handles both atom keys (newly created) and string keys (loaded from DB)
  defp get_message_thinking(message) do
    metadata = message.metadata || %{}
    thinking = metadata[:thinking] || metadata["thinking"]

    if is_binary(thinking) and thinking != "", do: thinking, else: nil
  end

  defp get_message_answer(message) do
    metadata = message.metadata || %{}
    answer = metadata[:answer] || metadata["answer"]

    if is_binary(answer) and answer != "", do: answer, else: message.content
  end

  # Get response stats from message metadata
  # Handles both atom keys (newly created) and string keys (loaded from DB)
  defp get_message_stats(message) do
    metadata = message.metadata || %{}

    # Try both atom and string keys for tokens_per_second
    tps = metadata[:tokens_per_second] || metadata["tokens_per_second"]

    if is_number(tps) do
      tokens = metadata[:tokens] || metadata["tokens"] || 0
      duration = metadata[:duration_seconds] || metadata["duration_seconds"] || 0
      %{tokens_per_second: tps, tokens: tokens, duration: duration}
    else
      nil
    end
  end

  # Get the sender name for a message (user's name or model name)
  # Handles both atom keys (newly created) and string keys (loaded from DB)
  defp get_message_sender(message) do
    case message.role do
      :user ->
        "You"

      :assistant ->
        # Try to get model name from metadata, fallback to "Assistant"
        metadata = message.metadata || %{}
        model = metadata[:model] || metadata["model"]

        if is_binary(model) and model != "", do: model, else: "Assistant"

      :system ->
        "System"
    end
  end

  # Calculate streaming speed (tokens per second)
  defp get_streaming_speed(token_count, start_time)
       when is_integer(start_time) and token_count > 0 do
    elapsed_ms = System.monotonic_time(:millisecond) - start_time
    elapsed_seconds = max(elapsed_ms, 100) / 1000

    Float.round(token_count / elapsed_seconds, 1)
  end

  defp get_streaming_speed(_token_count, _start_time), do: nil

  defp get_current_model_name(selected_model)
       when is_binary(selected_model) and selected_model != "" do
    selected_model
  end

  defp get_current_model_name(_selected_model), do: "Assistant"

  # Reset streaming-related socket assigns to their default values
  defp reset_streaming_state(socket) do
    socket
    |> assign(:loading, false)
    |> assign(:streaming, false)
    |> assign(:streaming_content, "")
    |> assign(:streaming_thinking, "")
    |> assign(:streaming_start_time, nil)
    |> assign(:streaming_token_count, 0)
  end

  defp load_backplane_models do
    case Client.list_models() do
      {:ok, %{"data" => models}} when is_list(models) ->
        Enum.flat_map(models, &normalize_model/1)

      {:ok, %{data: models}} when is_list(models) ->
        Enum.flat_map(models, &normalize_model/1)

      _ ->
        []
    end
  end

  defp normalize_model(model) do
    case model["id"] || model[:id] do
      id when is_binary(id) and id != "" ->
        [%{id: id, owned_by: model["owned_by"] || model[:owned_by]}]

      _ ->
        []
    end
  end

  defp first_model_id([model | _]), do: model.id
  defp first_model_id([]), do: nil

  defp parse_model_selection(selection) when is_binary(selection) do
    case String.split(selection, ":", parts: 2) do
      [_legacy_provider_id, model] -> model
      [model] -> model
    end
  end

  defp parse_model_selection(_selection), do: nil
end
