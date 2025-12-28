# Tasks: ETS-Based Admin Session Management

**Input**: Design documents from `/specs/002-ets-session/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Tests are included as the plan.md indicates Test-First approach for session store, plugs, and LiveView auth.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella app**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/` for source
- **Tests**: `apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/`

---

## Phase 1: Setup (Shared Infrastructure) ✅

**Purpose**: Create the ETS session store infrastructure that all user stories depend on

- [x] T001 Create session directory structure at `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/session/`
- [x] T002 Create Session.Store GenServer in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/session/store.ex` with ETS table initialization, get/put/delete operations, and expiration cleanup
- [x] T003 Add Session.Store to supervision tree in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/application.ex`

---

## Phase 2: Foundational (Blocking Prerequisites) ✅

**Purpose**: Core configuration changes that MUST be complete before ANY user story can be implemented

- [x] T004 Update session options in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/endpoint.ex` to use `:ets` store with table `:gsmlg_admin_sessions`
- [x] T005 [P] Create SessionUser plug in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/plugs/session_user.ex` to load current_user from session
- [x] T006 [P] Create test directory structure at `apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/session/`
- [x] T007 Add SessionUser plug to browser pipeline in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`
- [x] T008 Verify application starts successfully with `mix phx.server` (manual check)

**Checkpoint**: Foundation ready - ETS session store operational, user story implementation can now begin

---

## Phase 3: User Story 1 - Admin Sign In with Persistent Session (Priority: P1) ✅ MVP

**Goal**: Admin can sign in and have their session stored server-side in ETS, remaining authenticated across page navigations

**Independent Test**: Sign in as admin, navigate to multiple pages, verify session persists

### Tests for User Story 1

- [x] T009 [P] [US1] Unit test for Session.Store in `apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/session/store_test.exs`
- [x] T010 [P] [US1] Integration test for sign-in flow in `apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/integration/session_sign_in_test.exs`

### Implementation for User Story 1

- [x] T011 [US1] Session stored in ETS via Plug.Session.ETS (works with existing AuthController)
- [x] T012 [US1] Verified current_user is assigned on protected HTTP pages
- [x] T013 [US1] Logging added for session creation in Session.Store
- [x] T014 [US1] All US1 tests pass (9 unit tests + 5 integration tests)

**Checkpoint**: Admin sign-in creates ETS session, current_user available on protected pages

---

## Phase 4: User Story 2 - Session Availability in LiveView Pages (Priority: P1) ✅

**Goal**: Authenticated admin accessing LiveView pages gets current_user automatically via WebSocket session

**Independent Test**: Sign in, navigate to /chat or /users LiveView, verify current_user displays

### Tests for User Story 2

- [x] T015 [P] [US2] Integration test for LiveView session in `apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/integration/session_liveview_test.exs`

### Implementation for User Story 2

- [x] T016 [US2] LiveUserAuth on_mount works with ETS sessions (no changes needed)
- [x] T017 [US2] Session navigation across LiveView pages tested
- [x] T018 [US2] Unauthenticated LiveView access handled gracefully
- [x] T019 [US2] All US2 tests pass (5 LiveView integration tests)

**Checkpoint**: LiveView pages receive session data, current_user assigned on mount and reconnect

---

## Phase 5: User Story 3 - Session Persistence Across Browser Refreshes (Priority: P2) ✅

**Goal**: Admin session persists across browser refresh and tab reopen within validity period

**Independent Test**: Sign in, refresh browser, verify still authenticated

### Tests for User Story 3

- [x] T020 [US3] Session persistence tested in session_sign_in_test.exs (covered by existing tests)

### Implementation for User Story 3

- [x] T021 [US3] Session cookie max_age set to 8 hours in endpoint.ex
- [x] T022 [US3] Session lookup after page refresh tested in integration tests
- [x] T023 [US3] Session expiration cleanup implemented in Session.Store
- [x] T024 [US3] All persistence tests pass

**Checkpoint**: Sessions persist across page refresh, expire after 8 hours

---

## Phase 6: User Story 4 - Admin Sign Out (Priority: P2) ✅

**Goal**: Admin can sign out, completely invalidating their session server-side

**Independent Test**: Sign in, sign out, verify cannot access protected pages

### Tests for User Story 4

- [x] T025 [P] [US4] Integration test for sign-out flow in `apps/gsmlg_app_admin_web/test/gsmlg_app_admin_web/integration/session_sign_out_test.exs`

### Implementation for User Story 4

- [x] T026 [US4] AuthController.sign_out/2 clears session (existing clear_session works with ETS)
- [x] T027 [US4] Session data cleared on sign-out
- [x] T028 [US4] Post-sign-out access has no user session
- [x] T029 [US4] Session deletion logging added in Session.Store
- [x] T030 [US4] All US4 tests pass (4 sign-out tests)

**Checkpoint**: Sign-out fully invalidates session, prevents further access

---

## Phase 7: Polish & Cross-Cutting Concerns ✅

**Purpose**: Improvements that affect multiple user stories

- [x] T031 [P] Session expiration cleanup tested in store_test.exs
- [x] T032 [P] Session TTL configurable via application config
- [x] T033 Full test suite passes (32 tests, 0 failures)
- [x] T034 Code formatted with `mix format`
- [x] T035 Added lazy_html dependency for LiveView testing

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 and US2 are both P1 and can proceed in parallel
  - US3 and US4 are both P2 and can proceed in parallel after P1 stories
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Core session creation
- **User Story 2 (P1)**: Can start after Foundational - LiveView integration (parallel with US1)
- **User Story 3 (P2)**: Can start after Foundational - Session persistence (can run parallel with US4)
- **User Story 4 (P2)**: Can start after Foundational - Sign out (can run parallel with US3)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Session store operations before plug integration
- Plug integration before controller changes
- Core implementation before logging/polish

### Parallel Opportunities

- T005, T006 can run in parallel (different files)
- T009, T010 can run in parallel (different test files)
- T015 can run parallel with US1 implementation
- T020, T025 can run in parallel (different test files)
- T031, T032 can run in parallel (different concerns)

---

## Parallel Example: User Story 1 + User Story 2

```bash
# Since US1 and US2 are both P1 and work on different aspects,
# after Foundational phase, both can start simultaneously:

# Developer A: User Story 1 (HTTP session)
Task: "Unit test for Session.Store in store_test.exs"
Task: "Update AuthController for ETS session"

# Developer B: User Story 2 (LiveView session)
Task: "Integration test for LiveView session"
Task: "Verify LiveUserAuth works with ETS"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup - Create Session.Store GenServer
2. Complete Phase 2: Foundational - Configure endpoint, create plugs
3. Complete Phase 3: User Story 1 - Admin sign-in works with ETS
4. **STOP and VALIDATE**: Manual test sign-in → navigate → verify current_user
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → ETS infrastructure ready
2. Add User Story 1 → Test sign-in → Basic session works (MVP!)
3. Add User Story 2 → Test LiveView → Full page support
4. Add User Story 3 → Test refresh → Session persistence verified
5. Add User Story 4 → Test sign-out → Complete session lifecycle

### Parallel Team Strategy

With two developers:

1. Both complete Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (HTTP) → User Story 3 (Persistence)
   - Developer B: User Story 2 (LiveView) → User Story 4 (Sign-out)
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Session.Store must be started before endpoint (supervision tree order matters)
