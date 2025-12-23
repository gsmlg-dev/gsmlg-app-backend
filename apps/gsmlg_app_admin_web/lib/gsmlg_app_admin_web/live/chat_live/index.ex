defmodule GsmlgAppAdminWeb.ChatLive.Index do
  @moduledoc """
  LiveView for AI chat interface with streaming support.
  """

  use GsmlgAppAdminWeb, :live_view

  alias GsmlgAppAdmin.AI
  alias GsmlgAppAdmin.AI.{Client, MockClient}

  @impl true
  def mount(_params, session, socket) do
    {:ok, providers} = AI.list_active_providers()

    # Load user from session
    current_user = load_user_from_session(session)

    # Load saved provider selection from session (T012)
    selected_provider = load_selected_provider(session, providers)

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "AI Chat")
      |> assign(:providers, providers)
      |> assign(:selected_provider, selected_provider)
      |> assign(:conversations, [])
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])
      |> assign(:input, "")
      |> assign(:streaming, false)
      |> assign(:streaming_content, "")
      |> assign(:loading, false)

    {:ok, load_conversations(socket)}
  end

  # T012: Load saved provider selection - will be updated from localStorage via JS hook
  defp load_selected_provider(_session, providers) do
    # Initial load uses first provider; JS hook will restore from localStorage
    List.first(providers)
  end

  defp load_user_from_session(session) do
    case session["user"] do
      nil ->
        nil

      user_subject when is_binary(user_subject) ->
        case Regex.run(~r/id=([a-f0-9-]+)/, user_subject) do
          [_, user_id] ->
            case Ash.get(GsmlgAppAdmin.Accounts.User, user_id) do
              {:ok, user} -> user
              _ -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
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
    conversation = AI.get_conversation_with_messages!(id)

    socket
    |> assign(:current_conversation, conversation)
    |> assign(:messages, conversation.messages || [])
    |> assign(:page_title, conversation.title)
  end

  @impl true
  def handle_event("select_provider", %{"provider_id" => provider_id}, socket) do
    provider = Enum.find(socket.assigns.providers, &(&1.id == provider_id))

    # T011: Persist provider selection via JavaScript localStorage
    socket =
      socket
      |> assign(:selected_provider, provider)
      |> push_event("save_provider_selection", %{provider_id: provider_id})

    {:noreply, socket}
  end

  # T012: Handle restoring provider selection from localStorage
  @impl true
  def handle_event("restore_provider_selection", %{"provider_id" => provider_id}, socket) do
    provider = Enum.find(socket.assigns.providers, &(&1.id == provider_id))

    if provider do
      {:noreply, assign(socket, :selected_provider, provider)}
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
      |> update(:messages, fn messages -> messages ++ [user_message] end)

    # Send to AI in background
    send(self(), {:request_ai_response, conversation.id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:request_ai_response, _conversation_id}, socket) do
    provider = socket.assigns.selected_provider
    messages = Enum.map(socket.assigns.messages, &format_message_for_api/1)

    # Determine which client to use
    use_mock? =
      is_nil(provider) ||
        provider.api_key == "sk-placeholder-configure-via-env" ||
        is_nil(provider.api_key)

    client_module = if use_mock?, do: MockClient, else: Client

    # Stream response
    parent = self()

    Task.async(fn ->
      result =
        client_module.stream_with_callback(
          provider,
          messages,
          fn chunk ->
            send(parent, {:stream_chunk, chunk})
            chunk
          end
        )

      send(parent, {:stream_complete, result})
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_chunk, chunk}, socket) do
    updated_content = socket.assigns.streaming_content <> chunk

    {:noreply, assign(socket, :streaming_content, updated_content)}
  end

  @impl true
  def handle_info({:stream_complete, result}, socket) do
    conversation = socket.assigns.current_conversation
    content = socket.assigns.streaming_content
    provider = socket.assigns.selected_provider

    # Save assistant message
    assistant_message_params = %{
      conversation_id: conversation.id,
      role: :assistant,
      content: content
    }

    {:ok, assistant_message} = AI.add_message(conversation.id, assistant_message_params)

    # T029: Increment usage tracking after AI response
    if provider do
      # Count messages (1 user + 1 assistant = 2 messages for this exchange)
      # Estimate tokens from content length (rough approximation: ~4 chars per token)
      estimated_tokens = estimate_tokens(content, result)
      AI.increment_provider_usage(provider, 2, estimated_tokens)
    end

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:streaming, false)
      |> assign(:streaming_content, "")
      |> update(:messages, fn messages -> messages ++ [assistant_message] end)
      |> load_conversations()

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-base-200" id="chat-page" phx-hook="ProviderSelection">
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
          <select
            class="select select-bordered w-full"
            phx-change="select_provider"
            name="provider_id"
          >
            <%= for provider <- @providers do %>
              <option
                value={provider.id}
                selected={@selected_provider && @selected_provider.id == provider.id}
              >
                {provider.name}
              </option>
            <% end %>
          </select>
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
                <button
                  phx-click="delete_conversation"
                  phx-value-id={conversation.id}
                  class="btn btn-ghost btn-xs opacity-0 group-hover:opacity-100"
                  data-confirm="Delete this conversation?"
                >
                  <.dm_mdi name="delete" class="w-4 h-4" />
                </button>
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
            <h1 class="text-2xl font-bold">
              {(@current_conversation && @current_conversation.title) || "AI Chat"}
            </h1>
            <%= if @selected_provider do %>
              <p class="text-sm text-base-content/60">
                Using {@selected_provider.name} · {@selected_provider.model}
              </p>
            <% end %>
          </div>
          
    <!-- Messages -->
          <div class="flex-1 overflow-y-auto p-4 space-y-4" id="messages-container">
            <%= for message <- @messages do %>
              <div class={[
                "chat",
                (message.role == :user && "chat-end") || "chat-start"
              ]}>
                <div class="chat-header">
                  {if message.role == :user, do: "You", else: "Assistant"}
                  <time class="text-xs opacity-50">
                    {Calendar.strftime(message.created_at, "%H:%M")}
                  </time>
                </div>
                <div class={[
                  "chat-bubble",
                  (message.role == :user && "chat-bubble-primary") || "chat-bubble-secondary"
                ]}>
                  {message.content}
                </div>
              </div>
            <% end %>

            <%= if @streaming do %>
              <div class="chat chat-start">
                <div class="chat-header">
                  Assistant
                </div>
                <div class="chat-bubble chat-bubble-secondary">
                  {@streaming_content}
                  <span class="inline-block w-2 h-4 ml-1 bg-current animate-pulse"></span>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Input Area -->
          <div class="p-4 bg-base-100 border-t border-base-300">
            <%= if @current_user do %>
              <form phx-submit="send_message" class="flex gap-2">
                <input
                  type="text"
                  name="message"
                  value={@input}
                  phx-change="update_input"
                  placeholder="Type your message..."
                  class="input input-bordered flex-1"
                  disabled={@loading}
                  autofocus
                />
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
                <span>Please <.link navigate={~p"/sign-in"} class="link link-primary">log in</.link> to start chatting.</span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
