# Data Model: ETS-Based Admin Session Management

**Feature**: 002-ets-session
**Date**: 2025-12-28

## Entities

### Session (ETS Record)

Represents an authenticated admin session stored in ETS.

**Storage**: ETS table `:gsmlg_admin_sessions`

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `String.t()` | Primary key, unique identifier (UUID or random string) |
| `data` | `map()` | Session data map (contains `"user"` key with subject string) |
| `created_at` | `DateTime.t()` | When session was created |
| `expires_at` | `DateTime.t()` | When session expires (created_at + 8 hours) |
| `last_accessed_at` | `DateTime.t()` | Last access time (for sliding expiration if needed) |

**ETS Record Format**:
```elixir
{session_id, %{
  data: %{"user" => "user?id=uuid-here", ...},
  created_at: ~U[2025-12-28 10:00:00Z],
  expires_at: ~U[2025-12-28 18:00:00Z],
  last_accessed_at: ~U[2025-12-28 12:30:00Z]
}}
```

**Validation Rules**:
- `session_id` must be unique (enforced by ETS `:set` type)
- `expires_at` must be in the future when session is created
- `data["user"]` must be present for authenticated sessions

**State Transitions**:
```
[Not Exists] --create--> [Active] --expire/delete--> [Not Exists]
                           |
                           +--access--> [Active] (updates last_accessed_at)
```

### User (Existing - Reference Only)

The admin user entity from `GsmlgAppAdmin.Accounts.User`. Not modified by this feature.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Primary key |
| `email` | `String.t()` | User's email address |
| `hashed_password` | `String.t()` | Bcrypt-hashed password |
| ... | ... | Other user fields (unchanged) |

**Relationship to Session**:
- Session stores user subject string (e.g., `"user?id=<uuid>"`)
- User is loaded from database on each request using subject
- No foreign key in ETS; user existence validated on load

## Session Cookie

**Not stored in ETS** - transmitted to/from client browser.

| Field | Type | Description |
|-------|------|-------------|
| `_gsmlg_app_admin_web_key` | `String.t()` | Signed cookie containing session ID |

**Cookie Properties**:
- `http_only: true` - Not accessible via JavaScript
- `secure: true` (production only) - HTTPS only
- `same_site: "Lax"` - CSRF protection
- `max_age: 28800` (8 hours) - Browser expiration hint

## ETS Table Configuration

**Table Name**: `:gsmlg_admin_sessions`

**Options**:
```elixir
[:set, :public, :named_table, read_concurrency: true]
```

| Option | Purpose |
|--------|---------|
| `:set` | Key-value store, one entry per session_id |
| `:public` | Any process can read/write (needed for concurrent requests) |
| `:named_table` | Access by atom name instead of table reference |
| `read_concurrency: true` | Optimized for concurrent reads |

**Memory Estimate**:
- Per session: ~500 bytes (session ID + metadata + data map)
- 100 sessions: ~50 KB
- Negligible memory footprint for target scale

## Operations

### Create Session
```
Input: user_subject (String)
Output: session_id (String)
Side Effects: Insert record into ETS
```

### Read Session
```
Input: session_id (String)
Output: {:ok, session_data} | {:error, :not_found} | {:error, :expired}
Side Effects: Update last_accessed_at (optional)
```

### Delete Session
```
Input: session_id (String)
Output: :ok
Side Effects: Remove record from ETS
```

### Cleanup Expired
```
Input: None
Output: count of deleted sessions
Side Effects: Remove all expired records from ETS
Trigger: Every 5 minutes via timer
```
