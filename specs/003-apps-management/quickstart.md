# Quickstart: Apps Management Module

**Date**: 2026-01-08
**Feature Branch**: `003-apps-management`

## Prerequisites

- Elixir 1.18+ installed
- PostgreSQL running with `gsmlg_app_admin_dev` database
- Development environment set up (`mix setup` completed)

## Quick Setup

### 1. Create the database migration

```bash
cd apps/gsmlg_app_admin
mix ash_postgres.generate_migrations --name add_apps_management
mix ecto.migrate
```

### 2. Start the development servers

```bash
# From umbrella root
mix phx.server
```

- Admin interface: http://localhost:4153
- Public website: http://localhost:4152

### 3. Access Apps Management

Navigate to http://localhost:4153/apps in the admin interface (after logging in).

## Key Files

### Admin App (gsmlg_app_admin)

| File | Purpose |
|------|---------|
| `lib/gsmlg_app_admin/apps/apps.ex` | Ash domain definition |
| `lib/gsmlg_app_admin/apps/resources/app.ex` | App resource |
| `lib/gsmlg_app_admin/apps/resources/store_link.ex` | StoreLink resource |

### Admin Web (gsmlg_app_admin_web)

| File | Purpose |
|------|---------|
| `lib/gsmlg_app_admin_web/live/apps_management_live/index.ex` | Apps list LiveView |
| `lib/gsmlg_app_admin_web/live/apps_management_live/form.ex` | App create/edit form |
| `lib/gsmlg_app_admin_web/controllers/api/apps_controller.ex` | Public API endpoint |

### Public Web (gsmlg_app_web)

| File | Purpose |
|------|---------|
| `lib/gsmlg_app_web/apps_cache.ex` | Cache loading module |
| `lib/gsmlg_app_web/release.ex` | Release tasks including cache sync |

## Common Tasks

### Create a new app via IEx

```elixir
iex -S mix

alias GsmlgAppAdmin.Apps

{:ok, app} = Apps.create_app(%{
  name: "My New App",
  label: "my_new_app",
  short_description: "A great app",
  long_description: "This is a detailed description of my app.",
  icon_path: "/images/icons/my_new_app.png",
  platforms: ["ios", "android"],
  category: "utility"
})

# Add a store link
{:ok, link} = Apps.create_store_link(%{
  app_id: app.id,
  store_type: "playstore",
  url: "https://play.google.com/store/apps/details?id=com.example.myapp"
})
```

### Fetch apps from API

```bash
curl http://localhost:4153/api/apps | jq
```

### Sync cache manually (development)

```elixir
iex -S mix

GsmlgAppWeb.AppsCache.sync_from_api("http://localhost:4153")
```

### Sync cache in production release

```bash
# Set environment variable
export ADMIN_API_URL=https://admin.example.com

# Run sync command
bin/gsmlg_app_backend eval "GsmlgAppWeb.Release.sync_apps_cache"
```

## Testing

### Run all tests

```bash
mix test
```

### Run specific tests

```bash
# Admin app tests
cd apps/gsmlg_app_admin
mix test test/gsmlg_app_admin/apps

# Admin web tests
cd apps/gsmlg_app_admin_web
mix test test/gsmlg_app_admin_web/live/apps_management_live_test.exs
```

## API Reference

### GET /api/apps

Returns all active apps with store links.

**Response:**
```json
{
  "data": [
    {
      "name": "GeoIP Lookup",
      "label": "geoip_lookup",
      "short_description": "Find geography location...",
      "long_description": "See data source location...",
      "icon_path": "/images/icons/geoip_lookup.png",
      "platforms": ["ios", "android"],
      "category": "network",
      "display_order": 1,
      "store_links": [
        {"store_type": "appstore", "url": "https://..."},
        {"store_type": "playstore", "url": "https://..."}
      ]
    }
  ]
}
```

## Troubleshooting

### Cache file not found

If `priv/apps_cache.bin` doesn't exist:

```bash
# In development
ADMIN_API_URL=http://localhost:4153 mix run -e "GsmlgAppWeb.Release.sync_apps_cache()"

# In production
bin/gsmlg_app_backend eval "GsmlgAppWeb.Release.sync_apps_cache"
```

### Migration issues

If migrations fail:

```bash
cd apps/gsmlg_app_admin
mix ecto.reset
```

### LiveView not updating

Clear browser cache or hard refresh (Ctrl+Shift+R).
