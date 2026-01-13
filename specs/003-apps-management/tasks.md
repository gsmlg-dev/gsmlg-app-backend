# Tasks: Apps Management Module

**Input**: Design documents from `/specs/003-apps-management/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are NOT included unless explicitly requested.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md umbrella project structure:
- **Admin domain**: `apps/gsmlg_app_admin/lib/gsmlg_app_admin/`
- **Admin web/LiveView**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/`
- **Admin migrations**: `apps/gsmlg_app_admin/priv/repo/migrations/`
- **Public web**: `apps/gsmlg_app_web/lib/gsmlg_app_web/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database schema and project structure initialization

- [x] T001 Generate Ash migrations for Apps domain with `mix ash_postgres.generate_migrations --name add_apps_management` in `apps/gsmlg_app_admin/`
- [x] T002 Run migrations with `mix ecto.migrate`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Ash domain and resources that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Create Apps domain module in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/apps.ex`
- [x] T004 [P] Create App resource with attributes (name, label, short_description, long_description, icon_path, platforms, category, display_order, is_active) in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/resources/app.ex`
- [x] T005 [P] Create StoreLink resource with attributes (app_id, store_type, url, display_order) in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/resources/store_link.ex`
- [x] T006 Add relationships between App and StoreLink resources (has_many/belongs_to)
- [x] T007 Register Apps domain in main application config `apps/gsmlg_app_admin/lib/gsmlg_app_admin.ex`
- [x] T008 Add Apps domain code interface functions (create_app, update_app, list_apps, etc.) in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/apps.ex`

**Checkpoint**: Foundation ready - Apps domain functional via IEx, user story implementation can now begin

---

## Phase 3: User Story 1 - Admin Creates and Manages Apps (Priority: P1) 🎯 MVP

**Goal**: Enable administrators to create, edit, delete (soft), restore, and reorder app entries

**Independent Test**: Login to admin, navigate to Apps Management, create a new app with all fields, verify it appears in the list, edit it, delete it, restore it

### Implementation for User Story 1

- [x] T009 [US1] Add apps management routes to router (live "/apps", etc.) in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`
- [x] T010 [US1] Create AppsManagementLive.Index module with apps list in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T011 [US1] Add navigation link to Apps Management in admin sidebar in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/components/layouts/app.html.heex`
- [x] T012 [P] [US1] Create AppsManagementLive.Form component for create/edit in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/form.ex`
- [x] T013 [US1] Implement "Add New App" button and form modal in Index in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T014 [US1] Implement store links management in Form (add/remove multiple links) in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/form.ex`
- [x] T015 [US1] Implement edit app functionality with form pre-population in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T016 [US1] Implement soft delete with confirmation dialog in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T017 [US1] Implement restore functionality for deleted apps in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T018 [US1] Add "Show deleted" filter toggle in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T019 [US1] Implement manual reordering (drag-drop or position input) in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`
- [x] T020 [US1] Add form validation with error display (label uniqueness, URL validation) in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/form.ex`
- [x] T021 [US1] Add flash messages for all CRUD operations in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/apps_management_live/index.ex`

**Checkpoint**: Admin can fully manage apps - create, edit, delete, restore, reorder

---

## Phase 4: User Story 2 - Admin API Exposes Apps Data (Priority: P2)

**Goal**: Provide public API endpoint returning all active apps with store links

**Independent Test**: Call `GET /api/apps` directly with curl, verify JSON response matches OpenAPI spec with complete app data

### Implementation for User Story 2

- [x] T022 [US2] Create AppsController with index action in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/controllers/api/apps_controller.ex`
- [x] T023 [US2] Add API route `GET /api/apps` to router in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`
- [x] T024 [US2] Implement `list_active_with_store_links/0` function in Apps domain in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/apps.ex`
- [x] T025 [US2] Implement JSON serialization matching OpenAPI spec in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/controllers/api/apps_controller.ex`
- [x] T026 [US2] Ensure API returns apps ordered by display_order in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/resources/app.ex`

**Checkpoint**: Public API endpoint functional and returning correct data format

---

## Phase 5: User Story 3 - Public Website Caches Apps from API (Priority: P3)

**Goal**: Enable app_web to fetch and cache apps data, use cache for rendering

**Independent Test**: Run `GsmlgAppWeb.AppsCache.sync_from_api("http://localhost:4153")` in IEx, verify `priv/apps_cache.bin` created, access apps page in app_web

### Implementation for User Story 3

- [x] T027 [US3] Create AppsCache module with sync and load functions in `apps/gsmlg_app_web/lib/gsmlg_app_web/apps_cache.ex`
- [x] T028 [US3] Implement `sync_from_api/1` to fetch from admin API and write cache file in `apps/gsmlg_app_web/lib/gsmlg_app_web/apps_cache.ex`
- [x] T029 [US3] Implement `load/0` to read cached apps from file in `apps/gsmlg_app_web/lib/gsmlg_app_web/apps_cache.ex`
- [x] T030 [US3] Handle missing cache file gracefully (return empty list) in `apps/gsmlg_app_web/lib/gsmlg_app_web/apps_cache.ex`
- [x] T031 [US3] Handle corrupted cache file gracefully (log error, return empty list) in `apps/gsmlg_app_web/lib/gsmlg_app_web/apps_cache.ex`
- [x] T032 [US3] Update AppsController to use AppsCache instead of static data in `apps/gsmlg_app_web/lib/gsmlg_app_web/controllers/apps_controller.ex`
- [x] T033 [US3] Update apps list template to render from cached data in `apps/gsmlg_app_web/lib/gsmlg_app_web/controllers/apps_html/list.html.heex`

**Checkpoint**: Public website renders apps from cache file, handles edge cases gracefully

---

## Phase 6: User Story 4 - Release Command Updates Apps Cache (Priority: P4)

**Goal**: Provide release command to update apps cache during deployment

**Independent Test**: Build release, run `bin/gsmlg_app_backend eval "GsmlgAppWeb.Release.sync_apps_cache"`, verify cache updated

### Implementation for User Story 4

- [x] T034 [US4] Add `sync_apps_cache/0` function to Release module in `apps/gsmlg_app_web/lib/gsmlg_app_web/release.ex`
- [x] T035 [US4] Read ADMIN_API_URL from environment variable in release task in `apps/gsmlg_app_web/lib/gsmlg_app_web/release.ex`
- [x] T036 [US4] Handle API connection failures gracefully with error message in `apps/gsmlg_app_web/lib/gsmlg_app_web/release.ex`
- [x] T037 [US4] Preserve existing cache on API failure in `apps/gsmlg_app_web/lib/gsmlg_app_web/release.ex`
- [x] T038 [US4] Add success/failure output messages for release command in `apps/gsmlg_app_web/lib/gsmlg_app_web/release.ex`

**Checkpoint**: Release command fully functional for production deployments

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T039 [P] Seed initial app data from existing static apps in `apps/gsmlg_app_admin/priv/repo/seeds.exs`
- [x] T040 Run quickstart.md validation - verify all features work end-to-end
- [x] T041 Verify apps display correctly on public website with cached data

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1): Can start immediately after Foundational
  - US2 (P2): Can run in parallel with US1 (different files)
  - US3 (P3): Requires US2 completion (needs API to cache from)
  - US4 (P4): Requires US3 completion (extends cache module with release task)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1: Setup
    ↓
Phase 2: Foundational
    ↓
    ├── US1 (P1): Admin CRUD ──────┐
    │                              │
    └── US2 (P2): Admin API ───────┤ (parallel)
                   ↓               │
              US3 (P3): Cache ─────┘
                   ↓
              US4 (P4): Release Command
                   ↓
Phase 7: Polish
```

### Within Each User Story

- Domain/resources before LiveViews
- Controllers before views
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- T004 and T005 (App and StoreLink resources) can run in parallel
- T010 and T012 (Index and Form components) can run in parallel
- US1 and US2 can run in parallel (different files, no dependencies)
- T039 seeds can run once data model is stable

---

## Parallel Example: Foundational Phase

```bash
# Launch resource creation in parallel:
Task: "Create App resource in apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/resources/app.ex"
Task: "Create StoreLink resource in apps/gsmlg_app_admin/lib/gsmlg_app_admin/apps/resources/store_link.ex"
```

## Parallel Example: User Story 1

```bash
# After routes added, launch LiveView components in parallel:
Task: "Create AppsManagementLive.Index in apps_management_live/index.ex"
Task: "Create AppsManagementLive.Form in apps_management_live/form.ex"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup (migrations)
2. Complete Phase 2: Foundational (Ash domain and resources)
3. Complete Phase 3: User Story 1 (admin CRUD)
4. Complete Phase 4: User Story 2 (API endpoint)
5. **STOP and VALIDATE**: Admin can manage apps, API returns data
6. Deploy/demo if ready - manual cache updates possible

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test admin UI → Deploy (Admin can manage apps!)
3. Add User Story 2 → Test API → Deploy (API available for clients!)
4. Add User Story 3 → Test cache → Deploy (Public site uses cache!)
5. Add User Story 4 → Test release command → Deploy (Full automation!)

### Suggested MVP Scope

**Minimum Viable Product**: User Stories 1 & 2 (Admin CRUD + API)
- Admins can create, edit, delete, restore, and reorder apps
- API endpoint available for fetching app data
- Delivers core value - app management without code changes

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Cache format: Erlang binary term (`:erlang.term_to_binary/1`) for fast loading
- Environment variable: `ADMIN_API_URL` for production cache sync
