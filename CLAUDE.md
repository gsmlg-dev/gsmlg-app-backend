# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elixir umbrella project for the GSMLG platform backend. Phoenix 1.8 + LiveView 1.1 + Ash Framework 3.x. See `AGENTS.md` for full command reference and code style guidelines.

## Applications

- **`gsmlg_app`** - Core shared services (pubsub, mailer) - port 4152
- **`gsmlg_app_web`** - Public web interface (apps listing, WHOIS API, static pages)
- **`gsmlg_app_admin`** - Admin backend: Ash domains, resources, business logic
- **`gsmlg_app_admin_web`** - Admin web interface with auth (port 4153)
- **`gsmlg_app_component`** - Shared Phoenix components (phoenix_duskmoon)

## Essential Commands

```bash
mix setup                    # Dependencies + database for all apps
mix phx.server               # Start all (public:4152, admin:4153)
mix format                   # Format all code including HEEx
mix test                     # Run all tests
mix test apps/gsmlg_app_admin/test/path_test.exs:25  # Single test line
mix lint                     # Credo + Dialyzer across all apps
mix compile --warnings-as-errors  # CI enforces this — fix all warnings
```

## Technology Stack

- Elixir 1.18+ / Erlang/OTP 28 + Phoenix 1.8 + LiveView 1.1
- Ash Framework 3.x with AshPostgres + AshAuthentication
- PostgreSQL (UUID primary keys), Bandit HTTP server
- Tailwind CSS 4.1.11 + @duskmoon-dev/core (CSS framework) + Bun 1.2.5 for frontend
- ETS for sessions, PostgreSQL for persistent data

## Ash Framework Domains

Four domains in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/`:

1. **`Accounts`** - Users + Tokens. AshAuthentication with password strategy + JWT. Roles: `:admin`, `:user`, `:moderator`. Custom actions: `:admin_create`, `:seed_admin`.
2. **`AI`** - Providers + Conversations + Messages. 15+ preconfigured LLM providers (OpenAI-compatible API). Streaming via SSE. Thinking content separation (`<think>` tags + `reasoning_content` field).
3. **`Apps`** - App + StoreLink. Soft delete pattern (`is_active` flag). Manual ordering via `display_order`. Platforms: ios/android/macos/windows/linux.
4. **`Blog`** - Post resource.

Domain functions wrap Ash queries with `authorize?: false`. Use `!` bang variants in controllers/LiveViews (e.g., `get_app!/1`).

## Authentication Architecture

**Admin app three-tier auth:**
1. **Browser pipeline**: Session + `AshAuthentication.Plug.load_from_session` + custom `SessionUser` plug
2. **Controller routes**: `[:browser, :require_auth]` pipeline → redirects to `/sign-in?return_to=<path>`
3. **LiveView routes**: `live_session :authenticated` with `on_mount: :live_user_required`

Session management uses ETS (not database-backed). Token strategy uses `:unsafe` session identifier.

**Sign-in flow**: Protected route → `RequireAuth` redirects → `StoreReturnTo` captures return path in session → user signs in → `AuthController.success/4` redirects back.

## LiveView Modal CRUD Pattern

Standard pattern used across apps management, user management, provider settings:

```
Router:  live "/things",         ThingLive.Index, :index
         live "/things/new",     ThingLive.Index, :new
         live "/things/:id/edit", ThingLive.Index, :edit
```

- **Index LiveView**: Loads data in `mount`, routes actions via `handle_params` → `apply_action`
- **Form LiveComponent**: Receives `action` + `patch` path. On save, sends `{__MODULE__, {:saved, record}}` to parent
- **Modal display**: `<.dm_modal :if={@live_action in [:new, :edit]}>`
- **CRITICAL**: Links to modal routes MUST use `patch=` not `navigate=`. `navigate` remounts the LiveView and breaks the modal pattern.

## UI Library

This project uses the DuskMoon UI system:

- **`phoenix_duskmoon`** — Phoenix LiveView UI component library (primary web UI)
- **`@duskmoon-dev/core`** — Core Tailwind CSS plugin and utilities
- **`@duskmoon-dev/css-art`** — CSS art utilities
- **`@duskmoon-dev/elements`** — Base web components
- **`@duskmoon-dev/art-elements`** — Art/decorative web components

Do NOT use DaisyUI or other CSS component libraries. Do NOT use `core_components.ex` — use `phoenix_duskmoon` components instead.
Use `@duskmoon-dev/core/plugin` as the Tailwind CSS plugin.

**CSS setup** (in each app's `assets/css/app.css`):
```css
@plugin "@duskmoon-dev/core/plugin";       /* Registers color tokens as Tailwind utilities */
@import "@duskmoon-dev/core/themes/sunshine"; /* Light theme */
@import "@duskmoon-dev/core/themes/moonlight"; /* Dark theme */
@import "@duskmoon-dev/core/components";      /* All component styles */
```

**Component conventions:**
- Phoenix components prefixed with `.dm_` (e.g., `.dm_modal`, `.dm_mdi`)
- Icons: `.dm_mdi name="icon-name"` (Material Design Icons), `.dm_bsi name="icon-name"` (Bootstrap Icons)
- CSS classes follow daisyui-like conventions (`btn-primary`, `badge-success`, `card`, `tabs-boxed`)
- Custom web components: `<el-dm-markdown>` (markdown rendering), `<thinking-box>` (collapsible reasoning)

### Reporting issues or feature requests

If you encounter missing features, bugs, or need functionality not yet available in any DuskMoon package, open a GitHub issue in the appropriate repository with the label `internal request`:

- **`phoenix_duskmoon`** — https://github.com/gsmlg-dev/phoenix_duskmoon/issues
- **`@duskmoon-dev/core`** — https://github.com/gsmlg-dev/duskmoon-dev/issues
- **`@duskmoon-dev/css-art`** — https://github.com/gsmlg-dev/duskmoon-dev/issues
- **`@duskmoon-dev/elements`** — https://github.com/gsmlg-dev/duskmoon-dev/issues
- **`@duskmoon-dev/art-elements`** — https://github.com/gsmlg-dev/duskmoon-dev/issues

Do NOT silently work around library bugs with local hacks. File the issue first, then add a temporary workaround in `app.css` with a comment referencing the issue URL.

## Apps Management: Dual-Layer Cache

Admin CRUD → Public API → Public Web binary cache:
1. Admin manages apps via Ash resources (LiveView CRUD)
2. Public API at `/api/apps` (unauthenticated) returns active apps as JSON
3. `GsmlgAppWeb.AppsCache` syncs from admin API → writes `priv/apps_cache.bin` (Erlang binary term file)
4. Public web reads cache file to render apps listing

## Chat/AI Streaming Architecture

1. Provider selection persisted via JavaScript `localStorage` hook
2. User message saved → triggers `Task.async` for OpenAI-compatible streaming
3. SSE chunks received → `send(parent, {:stream_chunk, chunk})` → `push_event` to JS
4. Thinking content: primary from API `reasoning_content` field, fallback parses `<think>...</think>` tags
5. On completion: assistant message saved with metadata (model, tokens, duration, tokens/sec)

## Development Environment (Nix)

`devenv.nix` provides PostgreSQL 14 via **Unix socket** (no TCP, avoids port conflicts). Databases `gsmlg_app_admin_dev` and `gsmlg_app_admin_test` pre-created. User: `gsmlg_app`/`gsmlg_app`.

devenv exports these env vars (used by all Mix environments):
- `DATABASE_URL` — dev database connection URL
- `DATABASE_URL_TEST` — test database connection URL
- `PGHOST` — Unix socket directory (Postgrex `socket_dir`)

## Docker Multi-Stage Builds

Three targets matching the three releases:
```bash
docker build --target backend -t gsmlg-app-backend:1.0.0 .    # Full (4152+4153)
docker build --target admin -t gsmlg-app-backend:1.0.0-admin . # Admin only (4153)
docker build --target public -t gsmlg-app-backend:1.0.0-public . # Public only (4152)
```

## Environment Variables (Production)

`DATABASE_URL`, `SECRET_KEY_BASE_WEB`, `SECRET_KEY_BASE_ADMIN`, `TOKEN_SIGNING_SECRET`, `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_NAME`

## Router Organization

**Admin routes** (`apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`):
- Public: `/sign-in`, `/register`, `/reset`, `/api/apps`
- Protected (controller): under `[:browser, :require_auth]`
- Protected (LiveView): under `live_session :authenticated` with `on_mount` guards
- Route ordering matters: specific paths like `/chat/settings` must come before parameterized `/chat/:id`

**Public routes** (`apps/gsmlg_app_web/lib/gsmlg_app_web/router.ex`):
- No authentication. Static pages, `/apps`, `/lookup/*` WHOIS API
