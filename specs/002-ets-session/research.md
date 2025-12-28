# Research: ETS-Based Admin Session Management

**Feature**: 002-ets-session
**Date**: 2025-12-28
**Status**: Complete

## Research Topics

### 1. Phoenix ETS Session Store

**Decision**: Use `Plug.Session.ETS` built-in store with custom session table

**Rationale**:
- Plug.Session already supports `:ets` as a session store out of the box
- Phoenix wraps Plug.Session, making integration straightforward
- ETS provides O(1) lookups, meeting the < 1ms performance goal
- Built-in solution means less custom code to maintain

**Alternatives Considered**:
- **Custom GenServer-based store**: More control but unnecessary complexity for this use case
- **Redis/Memcached**: Overkill for single-node, adds external dependency
- **Database-backed sessions**: Too slow for session lookup, adds database load

**Implementation Notes**:
- Change `store: :cookie` to `store: :ets` in endpoint.ex
- Create named ETS table owned by a GenServer/Agent for durability across process crashes
- Table type: `:set` with `:public` access for concurrent reads

### 2. Session Expiration Strategy

**Decision**: Implement periodic cleanup with configurable TTL (8 hours)

**Rationale**:
- ETS doesn't have built-in TTL support
- Periodic cleanup (every 5 minutes) is efficient and simple
- Store timestamp with each session, check on read and via sweep

**Alternatives Considered**:
- **Check expiration only on read**: Leaves stale sessions in memory
- **Process per session with timeout**: Too many processes for simple use case
- **:ets.insert with TTL (via :ets2)**: External dependency

**Implementation Notes**:
- Store `{session_id, %{data: session_data, expires_at: timestamp}}` in ETS
- Cleanup process runs every 5 minutes using `:timer.send_interval/2`
- Session considered expired if `expires_at < now`

### 3. LiveView Session Integration

**Decision**: Pass session ID via connect_info, lookup user in on_mount

**Rationale**:
- Phoenix LiveView supports `connect_info: [session: @session_options]` in socket config
- Session data is passed to LiveView mount via the `session` parameter
- Consistent with current `live_user_auth.ex` pattern

**Alternatives Considered**:
- **Custom token in URL**: Security risk, breaks bookmarking
- **Separate LiveView auth mechanism**: Inconsistent with HTTP requests

**Implementation Notes**:
- Endpoint already has: `socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]`
- LiveUserAuth reads from session map passed to `on_mount`
- No changes needed to LiveView socket configuration

### 4. AshAuthentication Integration

**Decision**: Keep AshAuthentication for auth, store user ID in custom session

**Rationale**:
- AshAuthentication handles password verification, token generation
- Current `store_in_session/2` from AshAuthentication.Phoenix.Controller stores user subject
- We store the user subject string, then load full user on each request

**Alternatives Considered**:
- **Store full user struct in session**: Stale data risk, memory overhead
- **Replace AshAuthentication entirely**: Major rework, unnecessary

**Implementation Notes**:
- `AuthController.success/4` calls `store_in_session(user)` which stores subject string
- `LiveUserAuth` and new session plug load user from subject via `Ash.get/2`
- User is loaded fresh on each request, ensuring up-to-date data

### 5. ETS Table Ownership Pattern

**Decision**: Use a dedicated GenServer as ETS table owner

**Rationale**:
- ETS tables are tied to their owner process; if owner dies, table is deleted
- GenServer with `handle_continue` creates table on init
- Supervisor ensures table owner restarts if it crashes

**Alternatives Considered**:
- **Endpoint process owns table**: Endpoint restarts would clear sessions unexpectedly during hot code reloads
- **Application supervisor owns table**: Harder to manage lifecycle
- **Named table without owner**: Table lost on owner process crash

**Implementation Notes**:
- Create `GsmlgAppAdminWeb.Session.Store` GenServer
- Create ETS table with name `:gsmlg_admin_sessions` in `init/1`
- Add to `GsmlgAppAdminWeb.Application` supervision tree
- Table options: `[:set, :public, :named_table, read_concurrency: true]`

### 6. Session Cookie Configuration

**Decision**: Keep signed cookie with session ID only, add secure flags

**Rationale**:
- Cookie contains only session ID (not user data) - secure by design
- Signing prevents tampering with session ID
- Same-site and secure flags prevent CSRF and interception

**Alternatives Considered**:
- **Encrypted cookie**: Unnecessary since only storing opaque ID
- **HTTP-only disabled**: No reason to access session cookie from JS

**Implementation Notes**:
```elixir
@session_options [
  store: :ets,
  table: :gsmlg_admin_sessions,
  key: "_gsmlg_app_admin_web_key",
  signing_salt: "Zq8+Jo4s",
  same_site: "Lax",
  http_only: true,
  secure: Mix.env() == :prod,
  max_age: 8 * 60 * 60  # 8 hours
]
```

## Summary

All research items resolved. The implementation will:

1. Replace `store: :cookie` with `store: :ets` in endpoint configuration
2. Create `GsmlgAppAdminWeb.Session.Store` GenServer to own ETS table
3. Add session expiration cleanup using `:timer.send_interval/2`
4. Keep existing AshAuthentication and LiveUserAuth patterns
5. Add secure cookie flags for production

No external dependencies required. All patterns use standard Elixir/Phoenix/OTP mechanisms.
