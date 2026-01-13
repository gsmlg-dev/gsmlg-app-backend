# Research: Apps Management Module

**Date**: 2026-01-08
**Feature Branch**: `003-apps-management`

## Overview

This document captures research findings and decisions made during the planning phase for the Apps Management Module feature.

---

## 1. Ash Resource Patterns for Apps Domain

### Decision
Follow the existing AI domain pattern: create an `Apps` domain with `App` and `StoreLink` resources using AshPostgres.

### Rationale
- Consistent with existing codebase (AI domain with Provider, Conversation, Message)
- Ash Framework provides automatic CRUD actions, validations, and code interface
- AshPostgres handles migrations and database interactions

### Alternatives Considered
- **Raw Ecto schemas**: Rejected - would require manual CRUD, less consistent with codebase
- **Embedded resources**: Rejected - StoreLinks need independent querying for admin UI

### Implementation Reference
```elixir
# Pattern from apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/ai.ex
use Ash.Domain
resources do
  resource(App)
  resource(StoreLink)
end
```

---

## 2. Soft Delete Implementation

### Decision
Use an `is_active` boolean attribute with a custom `destroy` action that sets `is_active: false` instead of deleting the record.

### Rationale
- Matches existing pattern in AI.Provider resource (`is_active` boolean)
- Simple, no additional dependencies
- Easy to filter in queries using `Ash.Query.filter(is_active == true)`

### Alternatives Considered
- **Ash.Archival extension**: More powerful but adds dependency, overkill for simple use case
- **deleted_at timestamp**: Adds complexity without benefit for this use case

### Implementation Reference
```elixir
# From AI.Provider - soft delete pattern
attribute :is_active, :boolean do
  allow_nil?(false)
  default(true)
end

read :active do
  filter(expr(is_active == true))
end
```

---

## 3. Manual Ordering with display_order

### Decision
Use an integer `display_order` attribute. Admin UI will use drag-drop with position swap/reorder on save.

### Rationale
- Simple integer column, efficient ordering with `ORDER BY display_order ASC`
- No need for complex tree structures or gaps-based systems
- Batch update positions on reorder is acceptable for ~50 apps

### Alternatives Considered
- **Fractional indexing**: Overkill for small dataset, adds complexity
- **Linked list (prev/next)**: More complex queries, harder to maintain

### Implementation Pattern
```elixir
attribute :display_order, :integer do
  allow_nil?(false)
  default(0)
end

update :reorder do
  argument :new_order, :integer, allow_nil?: false
  change set_attribute(:display_order, arg(:new_order))
end
```

---

## 4. Store Links as Embedded vs Related Resource

### Decision
Use a separate `StoreLink` resource with `belongs_to :app` relationship.

### Rationale
- Each app can have 0-N store links (variable count)
- Separate table allows easy querying and management
- JSON API serialization is straightforward with relationship loading

### Alternatives Considered
- **Embedded fragment**: Can't easily query store links independently, harder to validate

### Implementation Pattern
```elixir
# In StoreLink resource
relationships do
  belongs_to :app, GsmlgAppAdmin.Apps.App do
    allow_nil?(false)
  end
end

# In App resource
relationships do
  has_many :store_links, GsmlgAppAdmin.Apps.StoreLink
end
```

---

## 5. Public API Endpoint Design

### Decision
Create a simple JSON controller at `/api/apps` returning all active apps with store links.

### Rationale
- Phoenix controller is simpler than AshJsonApi for single endpoint
- No authentication required (public endpoint for caching)
- Returns minimal JSON structure optimized for cache storage

### Alternatives Considered
- **AshJsonApi**: Adds complexity/dependencies for a single read-only endpoint
- **GraphQL**: Overkill for single list query

### Implementation Pattern
```elixir
# Simple controller pattern
def index(conn, _params) do
  {:ok, apps} = GsmlgAppAdmin.Apps.list_active_with_store_links()
  json(conn, %{data: Enum.map(apps, &serialize_app/1)})
end
```

---

## 6. Cache File Format and Location

### Decision
Use Erlang term format (`:erlang.term_to_binary/1`) stored at `priv/apps_cache.bin`.

### Rationale
- Native Elixir loading with `:erlang.binary_to_term/1`
- Compact binary format
- No JSON parsing overhead at runtime
- Standard priv directory for static assets

### Alternatives Considered
- **JSON file**: Requires Jason parsing, larger file size
- **ETS table**: Lost on restart, requires initialization logic

### Implementation Pattern
```elixir
# Cache write
:ok = File.write!(cache_path(), :erlang.term_to_binary(apps))

# Cache read
{:ok, binary} = File.read(cache_path())
apps = :erlang.binary_to_term(binary)
```

---

## 7. Release Command for Cache Update

### Decision
Add `sync_apps_cache/0` function to `GsmlgAppWeb.Release` module, callable via `bin/gsmlg_app eval "GsmlgAppWeb.Release.sync_apps_cache"`.

### Rationale
- Follows existing release task pattern in `GsmlgAppAdmin.Release`
- Can be called during deployment scripts
- Uses ADMIN_API_URL environment variable for flexibility

### Implementation Pattern
```elixir
# In GsmlgAppWeb.Release
def sync_apps_cache do
  Application.ensure_all_started(:req)

  admin_url = System.get_env("ADMIN_API_URL") || raise "ADMIN_API_URL not set"

  case Req.get("#{admin_url}/api/apps") do
    {:ok, %{status: 200, body: body}} ->
      apps = body["data"]
      cache_path = Path.join(:code.priv_dir(:gsmlg_app_web), "apps_cache.bin")
      File.write!(cache_path, :erlang.term_to_binary(apps))
      IO.puts("Apps cache updated: #{length(apps)} apps")
    {:error, reason} ->
      IO.puts("Failed to sync apps cache: #{inspect(reason)}")
      {:error, reason}
  end
end
```

---

## 8. LiveView Admin Interface Pattern

### Decision
Use Phoenix LiveView with form components following existing `ProviderSettingsLive` and `UserManagementLive` patterns.

### Rationale
- Consistent UX with existing admin pages
- LiveView enables real-time reordering via drag-drop
- Uses phoenix_duskmoon component library already in project

### Implementation Reference
- `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/`
- Index page with list, form page for create/edit

---

## Summary of Technical Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Data Layer | Ash Resources + AshPostgres | Consistent with codebase |
| Soft Delete | `is_active` boolean | Simple, proven pattern |
| Ordering | Integer `display_order` | Sufficient for ~50 items |
| Store Links | Separate resource with relationship | Flexible, queryable |
| Public API | Simple Phoenix controller | Minimal for single endpoint |
| Cache Format | Erlang binary term | Fast loading, compact |
| Cache Location | `priv/apps_cache.bin` | Standard asset location |
| Release Task | Module function + eval | Existing pattern |
| Admin UI | LiveView + duskmoon | Consistent with admin app |
