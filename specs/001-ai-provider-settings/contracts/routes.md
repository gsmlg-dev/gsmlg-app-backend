# Routes Contract: AI Provider Settings

**Feature**: 001-ai-provider-settings
**Date**: 2025-12-21

## LiveView Routes

All routes require authentication via `AshAuthentication.Phoenix.LiveSession`.

### Provider Settings Routes

| Route | LiveView Module | Action | Description |
|-------|-----------------|--------|-------------|
| `/chat/settings` | `ProviderSettingsLive.Index` | `:index` | List all providers |
| `/chat/settings/new` | `ProviderSettingsLive.Index` | `:new` | Add new provider (modal) |
| `/chat/settings/:id` | `ProviderSettingsLive.Show` | `:show` | Provider details & usage |
| `/chat/settings/:id/edit` | `ProviderSettingsLive.Index` | `:edit` | Edit provider (modal) |

### Existing Chat Routes (Modified)

| Route | LiveView Module | Action | Changes |
|-------|-----------------|--------|---------|
| `/chat` | `ChatLive.Index` | `:index` | Add settings link in sidebar, no-provider prompt |
| `/chat/:id` | `ChatLive.Index` | `:conversation` | No changes |

## Router Configuration

```elixir
# In router.ex, within authenticated live_session

live_session :authenticated,
  on_mount: [{AshAuthentication.Phoenix.LiveSession, {:load_from_session, otp_app: :gsmlg_app_admin}}] do

  # User management routes
  live "/users", UserManagementLive.Index, :index
  live "/users/new", UserManagementLive.Index, :new
  live "/users/:id/edit", UserManagementLive.Index, :edit

  # AI Chat routes
  live "/chat", ChatLive.Index, :index
  live "/chat/:id", ChatLive.Index, :conversation

  # NEW: Provider Settings routes
  live "/chat/settings", ProviderSettingsLive.Index, :index
  live "/chat/settings/new", ProviderSettingsLive.Index, :new
  live "/chat/settings/:id", ProviderSettingsLive.Show, :show
  live "/chat/settings/:id/edit", ProviderSettingsLive.Index, :edit
end
```

## Navigation Flow

```
┌─────────────────┐
│    /chat        │
│  (Chat Page)    │
├─────────────────┤
│ [Settings] link │
│ at bottom of    │
│ sidebar         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ /chat/settings  │
│ (Provider List) │
├─────────────────┤
│ [+ Add Provider]│
│ Provider cards  │
│ with actions    │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────────────┐
│ /new   │ │ /settings/:id  │
│ (Modal)│ │ (Details page) │
└────────┘ └────────────────┘
```

## LiveView Events

### ProviderSettingsLive.Index

| Event | Parameters | Action |
|-------|------------|--------|
| `delete` | `%{"id" => provider_id}` | Delete provider with confirmation |
| `toggle_active` | `%{"id" => provider_id}` | Toggle provider active status |

### ProviderSettingsLive.Show

| Event | Parameters | Action |
|-------|------------|--------|
| `refresh_usage` | none | Reload usage statistics |

### FormComponent

| Event | Parameters | Action |
|-------|------------|--------|
| `validate` | form params | Validate form on change |
| `save` | form params | Create or update provider |

### ChatLive.Index (Modified)

| Event | Parameters | Action |
|-------|------------|--------|
| `select_provider` | `%{"provider_id" => id}` | Existing - select provider |
| NEW: none | - | Settings link navigates to `/chat/settings` |

## Session Storage

### Provider Selection

Store in Phoenix session:
- Key: `"selected_provider_id"`
- Value: Provider UUID string
- Persistence: Browser session

### Implementation

```elixir
# On provider selection in ChatLive
def handle_event("select_provider", %{"provider_id" => id}, socket) do
  socket = put_session(socket, :selected_provider_id, id)
  provider = Enum.find(socket.assigns.providers, &(&1.id == id))
  {:noreply, assign(socket, :selected_provider, provider)}
end

# On mount, load from session
def mount(_params, session, socket) do
  selected_id = session["selected_provider_id"]
  # ... load and select provider
end
```
