# Quickstart: AI Provider Settings

**Feature**: 001-ai-provider-settings
**Date**: 2025-12-21

## Prerequisites

- Elixir 1.18+ installed
- PostgreSQL running
- Project dependencies installed (`mix deps.get`)
- Database created and migrated (`mix ecto.setup`)

## Quick Setup

```bash
# 1. Checkout feature branch
git checkout 001-ai-provider-settings

# 2. Install dependencies (if new ones added)
mix deps.get

# 3. Run migrations (for usage tracking columns)
mix ecto.migrate

# 4. Start the server
mix phx.server
```

## Verify Implementation

### 1. Check Provider Settings Page

Navigate to: `http://localhost:4153/chat/settings`

Expected:
- List of existing providers (from seed data)
- "Add Provider" button
- Each provider shows: name, model, status, actions

### 2. Add New Provider

1. Click "Add Provider"
2. Fill in form:
   - Name: "Test Provider"
   - Slug: "test-provider"
   - API Base URL: "https://api.example.com/v1"
   - API Key: "sk-test-key-12345"
   - Model: "gpt-4"
3. Click "Save"
4. Verify provider appears in list

### 3. View Provider Usage

1. Click on a provider name
2. Expected on details page:
   - Provider configuration (API key masked)
   - Usage stats: Messages, Tokens, Last Used
   - Edit and Delete buttons

### 4. Check Chat Page No-Provider State

1. Delete all providers OR ensure none are active
2. Navigate to: `http://localhost:4153/chat`
3. Expected: Centered message prompting to configure provider

### 5. Verify Settings Link

1. Navigate to: `http://localhost:4153/chat`
2. Look at bottom of left sidebar
3. Expected: "Settings" link that navigates to `/chat/settings`

## Test Commands

```bash
# Run all tests
mix test

# Run only provider settings tests
mix test apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/live/provider_settings_live_test.exs

# Run with coverage
mix test --cover
```

## Key Files

| File | Purpose |
|------|---------|
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider.ex` | Provider resource with usage attributes |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex` | Settings list page |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/show.ex` | Provider details page |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex` | Add/Edit form |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex` | Modified chat page |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex` | Routes configuration |

## Troubleshooting

### "No provider selected" message not appearing

1. Check if any providers are active: `GsmlgAppAdmin.AI.list_active_providers()`
2. Ensure the condition in ChatLive.Index checks for empty providers list

### API key not saving

1. Ensure `api_key` field accepts input
2. Check validation: non-local providers require API key
3. Verify `sensitive?` attribute is handled correctly in form

### Usage stats not updating

1. Verify migration ran: `mix ecto.migrations`
2. Check `increment_usage` action is called after chat responses
3. Confirm `total_messages`, `total_tokens` columns exist

### Settings link not visible

1. Check ChatLive.Index render function for settings link
2. Verify link uses correct path: `~p"/chat/settings"`
3. Ensure link is at bottom of sidebar div

## Database Queries

```elixir
# List all providers with usage
GsmlgAppAdmin.AI.Provider |> Ash.read!()

# Get provider by ID
GsmlgAppAdmin.AI.get_provider!("uuid-here")

# Increment usage manually (for testing)
provider
|> Ash.Changeset.for_update(:increment_usage, %{messages: 1, tokens: 100})
|> Ash.update!()
```
