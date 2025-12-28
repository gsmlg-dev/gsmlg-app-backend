# Implementation Plan: ETS-Based Admin Session Management

**Branch**: `002-ets-session` | **Date**: 2025-12-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-ets-session/spec.md`

## Summary

Replace the current cookie-based session storage in `gsmlg_app_admin_web` with ETS-based server-side session storage. This change improves session reliability by storing session data in server memory (ETS) while only keeping a session identifier in the client cookie. Sessions will work consistently across HTTP requests and LiveView WebSocket connections, automatically populating `current_user` on all protected pages.

## Technical Context

**Language/Version**: Elixir 1.18+ / Erlang/OTP 28
**Primary Dependencies**: Phoenix 1.8, Phoenix LiveView 1.1, AshAuthentication, Plug.Session
**Storage**: ETS (Erlang Term Storage) for sessions, PostgreSQL for user data (via AshPostgres)
**Testing**: ExUnit with ConnTest and LiveViewTest
**Target Platform**: Linux server (single node)
**Project Type**: Elixir umbrella application
**Performance Goals**: Session lookup < 1ms, 100 concurrent sessions without degradation
**Constraints**: Single node (no distributed ETS), 8-hour session expiration, sessions lost on restart
**Scale/Scope**: 100 concurrent admin sessions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution is a template without specific rules defined. Proceeding with standard Elixir/Phoenix best practices:

- [x] **Test-First**: Tests will be written for session store, plugs, and LiveView auth
- [x] **Simplicity**: Using built-in Plug.Session with `:ets` store, minimal custom code
- [x] **Observability**: Session operations logged via Logger
- [x] **No violations**: Standard Phoenix session pattern, no complexity justification needed

## Project Structure

### Documentation (this feature)

```text
specs/002-ets-session/
├── plan.md              # This file
├── research.md          # Phase 0 output - ETS session patterns
├── data-model.md        # Phase 1 output - Session entity model
├── quickstart.md        # Phase 1 output - Implementation guide
├── contracts/           # Phase 1 output - N/A (no external APIs)
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
apps/gsmlg_app_admin_web/
├── lib/gsmlg_app_admin_web/
│   ├── endpoint.ex              # MODIFY: Change session store to :ets
│   ├── session/                 # NEW: Session management module
│   │   ├── store.ex             # ETS-based session store with expiration
│   │   └── supervisor.ex        # Supervisor for ETS table ownership
│   ├── plugs/
│   │   └── session_user.ex      # NEW: Plug to load current_user from session
│   ├── live_user_auth.ex        # MODIFY: Integrate with new session store
│   ├── controllers/
│   │   └── auth_controller.ex   # MODIFY: Update session handling
│   └── router.ex                # MODIFY: Add session_user plug to pipeline
└── test/gsmlg_app_admin_web/
    ├── session/
    │   └── store_test.exs       # NEW: Session store unit tests
    └── integration/
        └── session_test.exs     # NEW: Full session flow integration tests
```

**Structure Decision**: Modifications within the existing `gsmlg_app_admin_web` umbrella app. New session module under `lib/gsmlg_app_admin_web/session/` for ETS store logic. No new umbrella apps needed.

## Complexity Tracking

> No constitution violations - no complexity justification required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
