# Quickstart: ETS-Based Admin Session Management

**Feature**: 002-ets-session
**Date**: 2025-12-28

## Overview

This guide provides step-by-step instructions for implementing ETS-based session storage in the admin web application.

## Prerequisites

- Elixir 1.18+ installed
- Project compiles successfully (`mix compile`)
- Existing tests pass (`mix test`)

## Implementation Steps

### Step 1: Create Session Store GenServer

Create the ETS table owner process:

**File**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/session/store.ex`

```elixir
defmodule GsmlgAppAdminWeb.Session.Store do
  @moduledoc """
  ETS-based session store with automatic expiration cleanup.
  """
  use GenServer
  require Logger

  @table_name :gsmlg_admin_sessions
  @cleanup_interval :timer.minutes(5)
  @session_ttl :timer.hours(8)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(session_id) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, session}] ->
        if expired?(session), do: {:error, :expired}, else: {:ok, session.data}
      [] ->
        {:error, :not_found}
    end
  end

  def put(session_id, data) do
    now = DateTime.utc_now()
    session = %{
      data: data,
      created_at: now,
      expires_at: DateTime.add(now, @session_ttl, :millisecond),
      last_accessed_at: now
    }
    :ets.insert(@table_name, {session_id, session})
    :ok
  end

  def delete(session_id) do
    :ets.delete(@table_name, session_id)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    count = cleanup_expired()
    if count > 0, do: Logger.info("Cleaned up #{count} expired sessions")
    schedule_cleanup()
    {:noreply, state}
  end

  # Private

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    now = DateTime.utc_now()
    expired = :ets.foldl(fn {id, session}, acc ->
      if expired?(session), do: [id | acc], else: acc
    end, [], @table_name)

    Enum.each(expired, &:ets.delete(@table_name, &1))
    length(expired)
  end
end
```

### Step 2: Add Store to Supervision Tree

**File**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/application.ex`

Add the session store to children:

```elixir
def start(_type, _args) do
  children = [
    GsmlgAppAdminWeb.Session.Store,  # Add this line
    GsmlgAppAdminWeb.Telemetry,
    GsmlgAppAdminWeb.Endpoint
  ]
  # ...
end
```

### Step 3: Update Endpoint Session Configuration

**File**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/endpoint.ex`

Change session options:

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

### Step 4: Create Session User Plug (Optional Enhancement)

**File**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/plugs/session_user.ex`

```elixir
defmodule GsmlgAppAdminWeb.Plugs.SessionUser do
  @moduledoc """
  Plug to load current_user from session and assign to conn.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, "user") do
      nil ->
        assign(conn, :current_user, nil)
      subject when is_binary(subject) ->
        user = load_user_from_subject(subject)
        assign(conn, :current_user, user)
      _ ->
        assign(conn, :current_user, nil)
    end
  end

  defp load_user_from_subject(subject) do
    cond do
      String.contains?(subject, "id=") ->
        case Regex.run(~r/id=([a-f0-9-]+)/i, subject) do
          [_, user_id] -> load_user(user_id)
          _ -> nil
        end
      Regex.match?(~r/^[a-f0-9-]{36}$/i, subject) ->
        load_user(subject)
      true ->
        nil
    end
  end

  defp load_user(user_id) do
    case Ash.get(GsmlgAppAdmin.Accounts.User, user_id) do
      {:ok, user} -> user
      _ -> nil
    end
  end
end
```

### Step 5: Add Plug to Router Pipeline

**File**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`

```elixir
pipeline :browser do
  plug(:accepts, ["html"])
  plug(:fetch_session)
  plug(:fetch_live_flash)
  plug(:put_root_layout, html: {GsmlgAppAdminWeb.Layouts, :root})
  plug(:protect_from_forgery)
  plug(:put_secure_browser_headers)
  plug(:load_from_session, otp_app: :gsmlg_app_admin)
  plug(GsmlgAppAdminWeb.Plugs.SessionUser)  # Add this line
end
```

## Verification

### Manual Testing

1. Start the server: `mix phx.server`
2. Navigate to `/sign-in`
3. Sign in with valid admin credentials
4. Verify redirect to dashboard
5. Navigate to LiveView pages (`/chat`, `/users`)
6. Verify `current_user` displays correctly
7. Refresh pages - session should persist
8. Sign out and verify redirect to sign-in

### Automated Tests

Run tests:
```bash
cd apps/gsmlg_app_admin_web
mix test
```

Key test scenarios:
- Session created on successful login
- Session lookup returns correct user data
- Expired sessions return error
- Sign-out clears session
- LiveView receives current_user

## Rollback

If issues occur:

1. Revert endpoint.ex session options to `store: :cookie`
2. Remove `GsmlgAppAdminWeb.Session.Store` from application.ex
3. Remove session_user plug from router.ex
4. Delete new files in `lib/gsmlg_app_admin_web/session/`

## Configuration

Environment-specific settings in `config/`:

```elixir
# config/dev.exs
config :gsmlg_app_admin_web, :session,
  ttl_hours: 8,
  cleanup_interval_minutes: 5

# config/prod.exs
config :gsmlg_app_admin_web, :session,
  ttl_hours: 8,
  cleanup_interval_minutes: 5
```
