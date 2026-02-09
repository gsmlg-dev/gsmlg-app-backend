defmodule GsmlgAppAdminWeb.ChatLive.Index do
  @moduledoc """
  LiveView for AI chat interface with streaming support.
  """

  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.{Client, MockClient}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, providers} = AI.list_active_providers()

    # current_user is already loaded by AshAuthentication.Phoenix.LiveSession on_mount
    current_user = socket.assigns[:current_user]

    # Load saved provider selection (T012)
    selected_provider = List.first(providers)
    selected_model = if selected_provider, do: selected_provider.model, else: nil

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "AI Chat")
      |> assign(:providers, providers)
      |> assign(:selected_provider, selected_provider)
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
    # Parse provider_id:model format
    case String.split(provider_model, ":", parts: 2) do
      [provider_id, model] ->
        provider = Enum.find(socket.assigns.providers, &(to_string(&1.id) == provider_id))

        # T011: Persist provider selection via JavaScript localStorage
        socket =
          socket
          |> assign(:selected_provider, provider)
          |> assign(:selected_model, model)
          |> push_event("save_provider_selection", %{provider_model: provider_model})

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  # T012: Handle restoring provider selection from localStorage
  @impl true
  def handle_event("restore_provider_selection", %{"provider_model" => provider_model}, socket) do
    # Parse provider_id:model format
    case String.split(provider_model, ":", parts: 2) do
      [provider_id, model] ->
        provider = Enum.find(socket.assigns.providers, &(to_string(&1.id) == provider_id))

        if provider do
          socket =
            socket
            |> assign(:selected_provider, provider)
            |> assign(:selected_model, model)

          {:noreply, socket}
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  # Legacy handler for old format
  @impl true
  def handle_event("restore_provider_selection", %{"provider_id" => provider_id}, socket) do
    provider = Enum.find(socket.assigns.providers, &(to_string(&1.id) == provider_id))

    if provider do
      socket =
        socket
        |> assign(:selected_provider, provider)
        |> assign(:selected_model, provider.model)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
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
    provider = socket.assigns.selected_provider

    {:ok, conversation} =
      AI.create_conversation(%{
        title: "New Chat",
        user_id: user.id,
        provider_id: provider && provider.id,
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
      |> push_event("stream_start", %{})

    # Send to AI in background
    send(self(), {:request_ai_response, conversation.id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:request_ai_response, _conversation_id}, socket) do
    provider = socket.assigns.selected_provider
    selected_model = socket.assigns.selected_model
    messages = Enum.map(socket.assigns.messages, &format_message_for_api/1)

    # Determine which client to use
    use_mock? =
      is_nil(provider) ||
        provider.api_key == "sk-placeholder-configure-via-env" ||
        is_nil(provider.api_key)

    client_module = if use_mock?, do: MockClient, else: Client

    # Stream response
    parent = self()

    # Pass the selected model to override provider's default model
    opts = if selected_model, do: [model: selected_model], else: []

    Task.async(fn ->
      result =
        client_module.stream_with_callback(
          provider,
          messages,
          fn chunk ->
            send(parent, {:stream_chunk, chunk})
            chunk
          end,
          opts
        )

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
    provider = socket.assigns.selected_provider
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
    model_name = selected_model || (provider && provider.model) || "Assistant"
    provider_name = if provider, do: provider.name, else: nil

    assistant_message_params = %{
      conversation_id: conversation.id,
      role: :assistant,
      content: full_content,
      metadata: %{
        model: model_name,
        provider: provider_name,
        thinking: thinking,
        answer: answer,
        tokens: token_count,
        duration_seconds: Float.round(duration_seconds, 2),
        tokens_per_second: tokens_per_second
      }
    }

    case AI.add_message(conversation.id, assistant_message_params) do
      {:ok, assistant_message} ->
        track_provider_usage(provider, full_content, {:ok, nil})

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

  defp track_provider_usage(nil, _content, _result), do: :ok

  defp track_provider_usage(provider, content, result) do
    estimated_tokens = estimate_tokens(content, result)
    AI.increment_provider_usage(provider, 2, estimated_tokens)
  end

  # T029: Estimate token count from response
  defp estimate_tokens(content, result) do
    # If result contains usage info from the API, use that
    case result do
      {:ok, %{usage: %{total_tokens: tokens}}} when is_integer(tokens) ->
        tokens

      _ ->
        # Fallback: rough estimate based on content length (~4 chars per token)
        div(String.length(content), 4)
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

  # Get the current model name for streaming display
  defp get_current_model_name(nil, _selected_model), do: "Assistant"

  defp get_current_model_name(_provider, selected_model)
       when is_binary(selected_model) and selected_model != "" do
    selected_model
  end

  defp get_current_model_name(provider, _selected_model) do
    provider.model || "Assistant"
  end

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

  # Get all models for a provider (only from available_models, no duplicates)
  defp get_provider_models(provider) do
    case provider.available_models do
      models when is_list(models) and length(models) > 0 ->
        # Only show models from available_models, remove duplicates
        Enum.uniq(models)

      _ ->
        # Fallback to default model only if no available_models configured
        if provider.model && provider.model != "", do: [provider.model], else: []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-3.5rem)] bg-base-200" id="chat-page" phx-hook="ProviderSelection">
      <!-- Sidebar -->
      <div class="w-64 bg-base-100 border-r border-base-300 flex flex-col">
        <div class="p-4 border-b border-base-300">
          <button
            phx-click="new_conversation"
            class="btn btn-primary btn-block"
          >
            <.dm_mdi name="plus" class="w-5 h-5" /> New Chat
          </button>
        </div>
        
    <!-- Provider Selection -->
        <div class="p-4 border-b border-base-300">
          <label class="label">
            <span class="label-text font-semibold">AI Provider</span>
          </label>
          <form phx-change="select_provider">
            <select
              class="select select-bordered w-full"
              name="provider_model"
            >
              <%= for provider <- @providers do %>
                <optgroup label={provider.name}>
                  <%= for model <- get_provider_models(provider) do %>
                    <option
                      value={"#{provider.id}:#{model}"}
                      selected={
                        @selected_provider && @selected_provider.id == provider.id &&
                          @selected_model == model
                      }
                    >
                      {model}
                    </option>
                  <% end %>
                </optgroup>
              <% end %>
            </select>
          </form>
        </div>
        
    <!-- Conversations List -->
        <div class="flex-1 overflow-y-auto">
          <%= for conversation <- @conversations do %>
            <div class="p-3 hover:bg-base-200 cursor-pointer border-b border-base-300 group">
              <div class="flex items-center justify-between">
                <div
                  phx-click={JS.patch(~p"/chat/#{conversation.id}")}
                  class="flex-1"
                >
                  <p class="text-sm font-medium truncate">{conversation.title}</p>
                  <p class="text-xs text-base-content/60">
                    {Calendar.strftime(conversation.updated_at, "%b %d, %Y")}
                  </p>
                </div>
                <div class="flex gap-1 opacity-0 group-hover:opacity-100">
                  <button
                    phx-click="edit_conversation_title"
                    phx-value-id={conversation.id}
                    class="btn btn-ghost btn-xs"
                    title="Edit title"
                  >
                    <.dm_mdi name="pencil" class="w-4 h-4" />
                  </button>
                  <button
                    phx-click="delete_conversation"
                    phx-value-id={conversation.id}
                    class="btn btn-ghost btn-xs"
                    data-confirm="Delete this conversation?"
                    title="Delete conversation"
                  >
                    <.dm_mdi name="delete" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Settings Link -->
        <div class="p-4 border-t border-base-300">
          <.link navigate={~p"/chat/settings"} class="btn btn-ghost btn-block justify-start">
            <.dm_mdi name="cog" class="w-5 h-5" /> Settings
          </.link>
        </div>
      </div>
      
    <!-- Main Chat Area -->
      <div class="flex-1 flex flex-col">
        <%= if Enum.empty?(@providers) do %>
          <!-- No Provider Configured -->
          <div class="flex-1 flex items-center justify-center">
            <div class="text-center p-8 max-w-md">
              <.dm_mdi name="robot" class="w-20 h-20 mx-auto mb-4 text-base-content/30" />
              <h2 class="text-2xl font-bold mb-2">No AI Provider Configured</h2>
              <p class="text-base-content/60 mb-6">
                To start chatting, you need to configure at least one AI provider.
              </p>
              <.link navigate={~p"/chat/settings"} class="btn btn-primary">
                <.dm_mdi name="cog" class="w-5 h-5 mr-2" /> Configure Providers
              </.link>
            </div>
          </div>
        <% else %>
          <!-- Chat Header -->
          <div class="p-4 bg-base-100 border-b border-base-300">
            <div class="flex items-center justify-between">
              <h1 class="text-2xl font-bold">
                {(@current_conversation && @current_conversation.title) || "AI Chat"}
              </h1>
              <!-- Model Selector in Header -->
              <form phx-change="select_provider" class="flex items-center gap-2">
                <span class="text-sm text-base-content/60">Model:</span>
                <select
                  class="select select-bordered select-sm"
                  name="provider_model"
                >
                  <%= for provider <- @providers do %>
                    <optgroup label={provider.name}>
                      <%= for model <- get_provider_models(provider) do %>
                        <option
                          value={"#{provider.id}:#{model}"}
                          selected={
                            @selected_provider && @selected_provider.id == provider.id &&
                              @selected_model == model
                          }
                        >
                          {model}
                        </option>
                      <% end %>
                    </optgroup>
                  <% end %>
                </select>
              </form>
            </div>
          </div>
          
    <!-- Messages -->
          <div class="flex-1 overflow-y-auto p-4 space-y-4" id="messages-container">
            <%= for message <- @messages do %>
              <div class={[
                "chat",
                (message.role == :user && "chat-end") || "chat-start"
              ]}>
                <div class="chat-header flex items-center gap-2">
                  {get_message_sender(message)}
                  <time class="text-xs opacity-50">
                    {Calendar.strftime(message.created_at, "%H:%M")}
                  </time>
                  <%= if message.role == :assistant do %>
                    <% stats = get_message_stats(message) %>
                    <%= if stats do %>
                      <span class="text-xs opacity-50">
                        {stats.tokens}tokens({stats.tokens_per_second}t/s)
                      </span>
                    <% end %>
                  <% end %>
                  <!-- Copy button -->
                  <button
                    phx-hook="CopyContent"
                    id={"copy-#{message.id}"}
                    data-content={message.content}
                    class="btn btn-ghost btn-xs opacity-50 hover:opacity-100"
                    title="Copy to clipboard"
                  >
                    <.dm_mdi name="content-copy" class="w-4 h-4" />
                  </button>
                </div>
                <div class={[
                  "chat-bubble max-w-[80%] overflow-x-auto",
                  (message.role == :user && "chat-bubble-primary") || "chat-bubble-secondary"
                ]}>
                  <%= if message.role == :assistant do %>
                    <% thinking = get_message_thinking(message) %>
                    <%= if thinking do %>
                      <!-- Thinking collapsible box using web component -->
                      <thinking-box>
                        <el-dm-markdown theme="auto">{thinking}</el-dm-markdown>
                      </thinking-box>
                      <!-- Answer content -->
                      <el-dm-markdown theme="auto">{get_message_answer(message)}</el-dm-markdown>
                    <% else %>
                      <el-dm-markdown theme="auto">{message.content}</el-dm-markdown>
                    <% end %>
                  <% else %>
                    <el-dm-markdown theme="auto">{message.content}</el-dm-markdown>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @streaming do %>
              <div
                class="chat chat-start"
                id="streaming-message"
                phx-hook="StreamingMarkdown"
              >
                <div class="chat-header flex items-center gap-2">
                  {get_current_model_name(@selected_provider, @selected_model)}
                  <span class="text-xs opacity-50">
                    <%= if @streaming_token_count > 0 do %>
                      <% speed = get_streaming_speed(@streaming_token_count, @streaming_start_time) %> ~{@streaming_token_count}tokens<%= if speed do %>
                        ({speed}t/s)
                      <% end %>
                    <% end %>
                  </span>
                  <%!-- Show "Thinking..." only when thinking is active and content hasn't started --%>
                  <%= if @streaming_thinking != "" and @streaming_content == "" do %>
                    <span class="badge badge-ghost badge-sm">
                      <.dm_mdi name="brain" class="w-3 h-3 mr-1" /> Thinking...
                    </span>
                  <% end %>
                </div>
                <div class="chat-bubble chat-bubble-secondary max-w-[80%] overflow-x-auto">
                  <%= if @streaming_thinking != "" do %>
                    <%!-- streaming attribute only when thinking is still active (content not started) --%>
                    <thinking-box {if @streaming_content == "", do: [streaming: true], else: []}>
                      <el-dm-markdown
                        theme="auto"
                        {if @streaming_content == "", do: [streaming: true], else: []}
                      >
                        {@streaming_thinking}
                      </el-dm-markdown>
                    </thinking-box>
                  <% end %>
                  <!-- Answer content -->
                  <el-dm-markdown theme="auto" streaming>{@streaming_content}</el-dm-markdown>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Input Area -->
          <div class="p-4 bg-base-100 border-t border-base-300">
            <%= if @current_user do %>
              <form phx-submit="send_message" class="flex gap-2 items-end">
                <textarea
                  id="message-input"
                  name="message"
                  phx-change="update_input"
                  phx-hook="AutoResizeTextarea"
                  placeholder="Type your message... (Cmd+Enter or Ctrl+Enter to send)"
                  class="textarea textarea-bordered flex-1 min-h-[2.5rem] max-h-[12rem] resize-none overflow-y-auto"
                  disabled={@loading}
                  rows="1"
                  autofocus
                ><%= @input %></textarea>
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={@loading || String.trim(@input) == ""}
                >
                  <%= if @loading do %>
                    <span class="loading loading-spinner loading-sm"></span>
                  <% else %>
                    <.dm_mdi name="send" class="w-5 h-5" />
                  <% end %>
                </button>
              </form>
            <% else %>
              <div class="alert alert-warning">
                <.dm_mdi name="alert" class="w-5 h-5" />
                <span>
                  Please <.link navigate={~p"/sign-in"} class="link link-primary">log in</.link>
                  to start chatting.
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
    <!-- Edit Title Modal -->
      <%= if @editing_conversation do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Edit Conversation Title</h3>
            <form phx-submit="save_conversation_title" class="mt-4">
              <input
                type="text"
                name="title"
                value={@edit_title}
                phx-change="update_edit_title"
                class="input input-bordered w-full"
                placeholder="Enter conversation title"
                autofocus
              />
              <div class="modal-action">
                <button type="button" phx-click="cancel_edit_title" class="btn">
                  Cancel
                </button>
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={String.trim(@edit_title) == ""}
                >
                  Save
                </button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop" phx-click="cancel_edit_title"></div>
        </div>
      <% end %>
    </div>
    """
  end
end
