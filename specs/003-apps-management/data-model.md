# Data Model: Apps Management Module

**Date**: 2026-01-08
**Feature Branch**: `003-apps-management`

## Overview

This document defines the data model for the Apps Management Module, including entities, relationships, and validation rules.

---

## Entities

### App

Represents a mobile or desktop application listing.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| id | UUID | Primary key, auto-generated | Unique identifier |
| name | string | Required, max 100 chars | Display name of the app |
| label | string | Required, max 50 chars, unique | URL-friendly identifier (e.g., "geoip_lookup") |
| short_description | string | Required, max 200 chars | Brief tagline for the app |
| long_description | text | Optional | Detailed description |
| icon_path | string | Required, max 255 chars | Path to icon image (e.g., "/images/icons/app.png") |
| platforms | array of string | Required, non-empty | Supported platforms: ios, android, macos, windows, linux |
| category | string | Required | Category: network, utility, development |
| display_order | integer | Required, default 0 | Position for manual sorting |
| is_active | boolean | Required, default true | Soft delete flag |
| created_at | datetime | Auto-generated | Creation timestamp |
| updated_at | datetime | Auto-updated | Last update timestamp |

**Relationships**:
- `has_many :store_links` → StoreLink

**Identities**:
- `unique_label` on `[:label]`

**Validations**:
- `label` must match pattern `^[a-z0-9_]+$` (lowercase alphanumeric with underscores)
- `platforms` must contain only valid values from enum
- `category` must be one of: network, utility, development

---

### StoreLink

Represents a link to an app store for downloading an app.

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| id | UUID | Primary key, auto-generated | Unique identifier |
| app_id | UUID | Required, foreign key | Reference to parent App |
| store_type | string | Required | Store type: appstore, playstore, fdroid, other |
| url | string | Required, valid URL | Store page URL |
| display_order | integer | Required, default 0 | Order within the app's store links |
| created_at | datetime | Auto-generated | Creation timestamp |
| updated_at | datetime | Auto-updated | Last update timestamp |

**Relationships**:
- `belongs_to :app` → App

**Validations**:
- `url` must be a valid URL (starts with http:// or https://)
- `store_type` must be one of: appstore, playstore, fdroid, other

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                            App                               │
├─────────────────────────────────────────────────────────────┤
│ id: UUID (PK)                                               │
│ name: string                                                │
│ label: string (unique)                                      │
│ short_description: string                                   │
│ long_description: text                                      │
│ icon_path: string                                           │
│ platforms: string[]                                         │
│ category: string                                            │
│ display_order: integer                                      │
│ is_active: boolean                                          │
│ created_at: datetime                                        │
│ updated_at: datetime                                        │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │ 1:N
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                        StoreLink                             │
├─────────────────────────────────────────────────────────────┤
│ id: UUID (PK)                                               │
│ app_id: UUID (FK → App)                                     │
│ store_type: string                                          │
│ url: string                                                 │
│ display_order: integer                                      │
│ created_at: datetime                                        │
│ updated_at: datetime                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## State Transitions

### App Lifecycle

```
┌─────────────┐
│   Created   │
│ is_active=T │
└──────┬──────┘
       │
       │ edit
       ▼
┌─────────────┐      delete       ┌─────────────┐
│   Active    │ ───────────────▶  │   Deleted   │
│ is_active=T │                   │ is_active=F │
└──────┬──────┘                   └──────┬──────┘
       │                                 │
       │ edit                            │ restore
       ▼                                 ▼
┌─────────────┐      delete       ┌─────────────┐
│   Active    │ ◀───────────────  │   Active    │
│ is_active=T │    restore        │ is_active=T │
└─────────────┘                   └─────────────┘
```

---

## Database Tables

### Table: apps

```sql
CREATE TABLE apps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  label VARCHAR(50) NOT NULL UNIQUE,
  short_description VARCHAR(200) NOT NULL,
  long_description TEXT,
  icon_path VARCHAR(255) NOT NULL,
  platforms VARCHAR(20)[] NOT NULL,
  category VARCHAR(50) NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_apps_is_active ON apps(is_active);
CREATE INDEX idx_apps_display_order ON apps(display_order);
CREATE INDEX idx_apps_category ON apps(category);
```

### Table: store_links

```sql
CREATE TABLE store_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  store_type VARCHAR(20) NOT NULL,
  url TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_store_links_app_id ON store_links(app_id);
```

---

## Enums / Allowed Values

### platforms
- `ios` - Apple iOS
- `android` - Google Android
- `macos` - Apple macOS
- `windows` - Microsoft Windows
- `linux` - Linux distributions

### category
- `network` - Network tools (GeoIP, Whois, DNS)
- `utility` - Utility apps (Mirror)
- `development` - Development tools (Semaphore)

### store_type
- `appstore` - Apple App Store
- `playstore` - Google Play Store
- `fdroid` - F-Droid
- `other` - Other distribution channels

---

## Cache Data Structure

The apps cache file (`priv/apps_cache.bin`) contains an Erlang binary term encoding of:

```elixir
[
  %{
    name: "GeoIP Lookup",
    label: "geoip_lookup",
    short_description: "Find geography location of IP Address...",
    long_description: "See data source location of web requests...",
    icon_path: "/images/icons/geoip_lookup.png",
    platforms: ["ios", "android"],
    category: "network",
    display_order: 1,
    store_links: [
      %{store_type: "appstore", url: "https://apps.apple.com/..."},
      %{store_type: "playstore", url: "https://play.google.com/..."}
    ]
  },
  # ... more apps
]
```

This structure matches the API response format for easy serialization/deserialization.
