# Data Model: AI Provider Settings

**Feature**: 001-ai-provider-settings
**Date**: 2025-12-21

## Entity: AI Provider (Extended)

Extends existing `GsmlgAppAdmin.AI.Provider` resource.

### Attributes

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| id | UUID | PK, auto-generated | Unique identifier |
| name | string | required, max 100 | Display name |
| slug | string | required, max 50, unique | URL-friendly identifier |
| api_base_url | string | required | Base URL for API endpoint |
| api_key | string | sensitive, required for non-local | API authentication key |
| model | string | required | Default model identifier |
| available_models | array[string] | default [] | List of available models |
| default_params | map | optional | Default API parameters |
| is_active | boolean | required, default true | Active status |
| description | string | optional | Provider description |
| **total_messages** | integer | default 0 | **NEW**: Aggregated message count |
| **total_tokens** | integer | default 0 | **NEW**: Aggregated token consumption |
| **last_used_at** | utc_datetime_usec | nullable | **NEW**: Last usage timestamp |
| created_at | utc_datetime_usec | auto | Creation timestamp |
| updated_at | utc_datetime_usec | auto | Last update timestamp |

### Computed Attributes

| Attribute | Type | Computation |
|-----------|------|-------------|
| masked_api_key | string | If api_key present: `"****#{String.slice(api_key, -4..-1)}"`, else nil |

### Actions

| Action | Type | Parameters | Description |
|--------|------|------------|-------------|
| create | create | all attributes | Create new provider |
| update | update | all except slug | Update existing provider |
| destroy | destroy | - | Delete provider |
| read | read | - | Default read |
| active | read | - | Filter: is_active == true |
| by_slug | read | slug: string | Lookup by slug |
| **increment_usage** | update | messages: integer, tokens: integer | **NEW**: Increment usage counters |
| **list_with_usage** | read | - | **NEW**: List all with usage stats |

### Validations

- `api_key` required when `slug != "local"`
- `name` and `slug` must be present
- `api_base_url` must be valid URL format

### Identities

- `unique_slug`: [:slug]

## Entity: User Provider Selection

Tracks per-user provider selection for chat sessions.

### Option A: Session-based (Recommended)

Store selection in LiveView socket assigns and browser session. No database entity needed.

**Implementation**:
- Store `selected_provider_id` in session on selection
- Load from session on mount
- Default to first active provider if no selection

### Option B: Database Entity (Future Enhancement)

If persistence across devices is required:

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| id | UUID | PK | Unique identifier |
| user_id | UUID | FK to users, required | User reference |
| provider_id | UUID | FK to ai_providers, required | Selected provider |
| created_at | utc_datetime_usec | auto | Selection timestamp |
| updated_at | utc_datetime_usec | auto | Last update |

**Decision**: Use session-based approach for MVP. Provider selection stored in browser session, not database.

## Database Migration

### Migration: Add Usage Tracking to Providers

```elixir
defmodule GsmlgAppAdmin.Repo.Migrations.AddProviderUsageTracking do
  use Ecto.Migration

  def change do
    alter table(:ai_providers) do
      add :total_messages, :integer, default: 0, null: false
      add :total_tokens, :integer, default: 0, null: false
      add :last_used_at, :utc_datetime_usec
    end
  end
end
```

## Relationships

```
┌─────────────────┐
│   AI Provider   │
├─────────────────┤
│ id (PK)         │
│ name            │
│ slug (unique)   │
│ api_base_url    │
│ api_key         │
│ model           │
│ is_active       │
│ total_messages  │
│ total_tokens    │
│ last_used_at    │
└─────────────────┘
        │
        │ provider_id (FK)
        ▼
┌─────────────────┐
│  Conversation   │
├─────────────────┤
│ id (PK)         │
│ user_id (FK)    │
│ provider_id (FK)│
│ title           │
└─────────────────┘
```

## State Transitions

### Provider Status

```
[Created] ──is_active:true──> [Active] <──toggle──> [Inactive]
    │                              │
    └──────────────────────────────┴────> [Deleted]
```

### User Selection State

```
[No Selection] ──select provider──> [Provider Selected]
       ▲                                    │
       └────provider deleted/deactivated────┘
```
