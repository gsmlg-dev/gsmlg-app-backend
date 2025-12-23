# Implementation Plan: AI Provider Settings

**Branch**: `001-ai-provider-settings` | **Date**: 2025-12-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ai-provider-settings/spec.md`

## Summary

Add an AI Provider Settings page accessible from the chat interface, enabling administrators to configure, manage, and monitor AI providers. The implementation extends the existing Provider resource with usage tracking and adds new LiveView pages for CRUD operations and settings management. When no provider is selected, the chat page displays a centered prompt directing users to configure providers.

## Technical Context

**Language/Version**: Elixir 1.18+ / Erlang/OTP 28
**Primary Dependencies**: Phoenix 1.8, Phoenix LiveView 1.1, Ash Framework 3.x, AshPostgres
**Storage**: PostgreSQL (via AshPostgres)
**Testing**: ExUnit with `mix test`
**Target Platform**: Linux server (Docker-compatible)
**Project Type**: Umbrella - Web application (apps/gsmlg_app_admin, apps/gsmlg_app_admin_web)
**Performance Goals**: CRUD operations < 3 seconds, page load < 1 second
**Constraints**: Shared providers model (all users see same providers), API keys masked after entry
**Scale/Scope**: Admin panel for internal use, moderate concurrent users

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution is templated (not configured). Proceeding with standard best practices:
- ✅ Feature integrates into existing Ash domain structure
- ✅ Uses established patterns (LiveView, Ash Resources)
- ✅ No new external dependencies required
- ✅ Tests will be required for new functionality

## Project Structure

### Documentation (this feature)

```text
specs/001-ai-provider-settings/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (LiveView routes)
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
apps/gsmlg_app_admin/
├── lib/gsmlg_app_admin/
│   └── ai/
│       ├── ai.ex                  # Domain (extend with provider CRUD functions)
│       └── provider.ex            # Resource (extend with usage tracking attributes)
└── priv/repo/migrations/
    └── YYYYMMDDHHMMSS_add_provider_usage_tracking.exs  # NEW: Migration

apps/gsmlg_app_admin_web/
├── lib/gsmlg_app_admin_web/
│   ├── live/
│   │   ├── chat_live/
│   │   │   └── index.ex           # MODIFY: Add settings link, no-provider prompt
│   │   └── provider_settings_live/
│   │       ├── index.ex           # NEW: Provider list with CRUD
│   │       ├── form_component.ex  # NEW: Add/Edit provider form
│   │       └── show.ex            # NEW: Provider details with usage stats
│   └── router.ex                  # MODIFY: Add /chat/settings routes
└── test/
    └── gsmlg_app_admin_web/live/
        └── provider_settings_live_test.exs  # NEW: LiveView tests
```

**Structure Decision**: Umbrella application pattern following existing conventions. New LiveView pages under `provider_settings_live/`, extending existing AI domain with usage tracking.

## Complexity Tracking

No constitution violations to justify. Implementation follows established patterns.
