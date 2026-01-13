# Implementation Plan: Apps Management Module

**Branch**: `003-apps-management` | **Date**: 2026-01-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-apps-management/spec.md`

## Summary

Implement an apps management module in admin_web that allows administrators to create, edit, delete (soft), and reorder mobile/desktop app listings. The admin backend exposes a public API that the public website (app_web) fetches and caches to a static file, eliminating database dependencies in app_web. A release command enables cache updates during deployment.

## Technical Context

**Language/Version**: Elixir 1.18+ / Erlang/OTP 28
**Primary Dependencies**: Phoenix 1.8, Phoenix LiveView 1.1, Ash Framework 3.x, AshPostgres
**Storage**: PostgreSQL (via AshPostgres for admin), static Elixir term file (for app_web cache)
**Testing**: ExUnit with Ash test helpers
**Target Platform**: Linux server (Docker deployment)
**Project Type**: Umbrella application with multiple apps
**Performance Goals**: Apps page loads < 500ms, cache update < 10 seconds
**Constraints**: app_web must remain database-free, use ADMIN_API_URL env var for API discovery
**Scale/Scope**: ~10-50 apps, single admin instance, multiple app_web instances possible

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution file contains template placeholders and no specific project principles defined. Proceeding with standard Elixir/Phoenix best practices:

- ✅ **Test-First**: Will write tests before implementation
- ✅ **Simplicity**: Using existing Ash patterns, no new abstractions
- ✅ **Observability**: Standard Phoenix logging, Ash audit trails

No gate violations detected.

## Project Structure

### Documentation (this feature)

```text
specs/003-apps-management/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── apps-api.json    # OpenAPI spec for apps endpoint
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/
├── gsmlg_app_admin/
│   └── lib/gsmlg_app_admin/
│       ├── apps/                    # New domain
│       │   ├── apps.ex              # Ash domain
│       │   └── resources/
│       │       ├── app.ex           # App resource
│       │       └── store_link.ex    # StoreLink resource
│       └── release.ex               # Add cache update task
│
├── gsmlg_app_admin_web/
│   └── lib/gsmlg_app_admin_web/
│       ├── live/
│       │   └── apps_management_live/ # New LiveView module
│       │       ├── index.ex
│       │       └── form.ex
│       ├── controllers/
│       │   └── api/
│       │       └── apps_controller.ex # Public API endpoint
│       └── router.ex                 # Add routes
│
└── gsmlg_app_web/
    └── lib/gsmlg_app_web/
        ├── apps_cache.ex            # Cache loader module
        ├── controllers/
        │   └── apps_controller.ex   # Update to use cache
        └── release.ex               # Add cache update task
```

**Structure Decision**: Extends existing umbrella structure. New Ash domain `Apps` in admin app, new LiveView in admin_web, cache module in app_web. Follows established patterns from AI and Accounts domains.

## Complexity Tracking

No violations requiring justification. Implementation follows existing patterns.
