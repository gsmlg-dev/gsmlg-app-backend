# Tasks: AI Provider Settings

**Input**: Design documents from `/specs/001-ai-provider-settings/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are NOT included unless explicitly requested.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md umbrella project structure:
- **Backend domain**: `apps/gsmlg_app_admin/lib/gsmlg_app_admin/`
- **Web/LiveView**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/`
- **Migrations**: `apps/gsmlg_app_admin/priv/repo/migrations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and database schema updates

- [x] T001 Create migration for usage tracking columns in `apps/gsmlg_app_admin/priv/repo/migrations/20251221104454_add_provider_usage_tracking.exs`
- [x] T002 Run migration with `mix ecto.migrate`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Extend Provider resource with usage attributes (total_messages, total_tokens, last_used_at) in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider.ex`
- [x] T004 Add masked_api_key computed attribute to Provider resource in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider.ex`
- [x] T005 Add increment_usage action to Provider resource in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider.ex`
- [x] T006 Add provider CRUD helper functions to AI domain in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/ai.ex`
- [x] T007 Add provider settings routes to router in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - View and Select AI Provider (Priority: P1) 🎯 MVP

**Goal**: Show "no provider selected" prompt and settings link on chat page, allow provider selection

**Independent Test**: Navigate to chat page with no provider, see prompt, click settings link, select a provider

### Implementation for User Story 1

- [x] T008 [US1] Add settings link at bottom of sidebar in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex`
- [x] T009 [US1] Add "no provider selected" centered prompt in chat area in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex`
- [x] T010 [US1] Create ProviderSettingsLive.Index module with provider list in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T011 [US1] Persist provider selection via localStorage in `apps/gsmlg_app_admin_web/assets/js/app.js` and `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex`
- [x] T012 [US1] Load saved provider selection on mount via JS hook in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex`

**Checkpoint**: User can see settings link, no-provider prompt, navigate to settings, and select a provider

---

## Phase 4: User Story 2 - Add New AI Provider (Priority: P1)

**Goal**: Allow administrators to add new AI providers via settings page

**Independent Test**: Navigate to settings, click Add Provider, fill form, save, verify provider appears in list

### Implementation for User Story 2

- [x] T013 [P] [US2] Create FormComponent for provider add/edit form in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`
- [x] T014 [US2] Add "Add Provider" button and modal trigger to Index in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T015 [US2] Implement form validation with AshPhoenix.Form in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`
- [x] T016 [US2] Implement save handler to create provider in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`
- [x] T017 [US2] Add validation error display in form in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`

**Checkpoint**: User can add new providers with full validation

---

## Phase 5: User Story 3 - Update Existing AI Provider (Priority: P2)

**Goal**: Allow administrators to edit existing provider configurations

**Independent Test**: Click edit on provider, modify API key, save, verify change persisted

### Implementation for User Story 3

- [x] T018 [US3] Add edit button/action to provider cards in Index in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T019 [US3] Pre-populate form with existing provider data in FormComponent in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`
- [x] T020 [US3] Implement update handler in FormComponent in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`
- [x] T021 [US3] Mask API key display (show only last 4 chars) in edit form via placeholder text in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/form_component.ex`

**Checkpoint**: User can edit existing providers with API key masking

---

## Phase 6: User Story 4 - Remove AI Provider (Priority: P2)

**Goal**: Allow administrators to delete providers with confirmation

**Independent Test**: Click delete on provider, confirm, verify provider removed and selection cleared if needed

### Implementation for User Story 4

- [x] T022 [US4] Add delete button to provider cards in Index in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T023 [US4] Implement delete confirmation dialog via data-confirm in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T024 [US4] Implement delete handler with Ash.destroy in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T025 [US4] Handle deleted provider - localStorage-based selection auto-clears on next page load if provider no longer exists

**Checkpoint**: User can delete providers with proper state management

---

## Phase 7: User Story 5 - View Provider Usage Statistics (Priority: P3)

**Goal**: Display usage statistics (messages, tokens) for each provider

**Independent Test**: View provider details page, see usage stats, verify zero usage for unused provider

### Implementation for User Story 5

- [x] T026 [P] [US5] Create ProviderSettingsLive.Show module for provider details in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/show.ex`
- [x] T027 [US5] Display usage statistics card (messages, tokens, last used) in Show in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/show.ex`
- [x] T028 [US5] Add provider name link to details page in Index in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T029 [US5] Integrate usage tracking increment after AI responses in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex`
- [x] T030 [US5] Handle "No usage yet" display for unused providers in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/show.ex`

**Checkpoint**: User can view usage statistics for all providers

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T031 Add flash messages for all CRUD operations in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T032 Add loading states for async operations in all settings LiveViews
- [x] T033 Add back navigation from settings to chat in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T034 Add toggle active status for providers in `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/provider_settings_live/index.ex`
- [x] T035 Run quickstart.md validation - verify all features work end-to-end, including provider selection persistence across page refreshes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P1 → P2 → P2 → P3)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - Uses Index from US1 but independently testable
- **User Story 3 (P2)**: Depends on FormComponent from US2 - Extends edit functionality
- **User Story 4 (P2)**: Can start after Foundational - Uses Index from US1 but independently testable
- **User Story 5 (P3)**: Can start after Foundational - New Show page, independent of other stories

### Within Each User Story

- Models/resources before LiveViews
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- T001 migration can run independently
- T003, T004, T005 can run in parallel (same file, different sections - careful coordination)
- T013 FormComponent can start while T010 Index is being built
- T026 Show module can run in parallel with any US4 tasks
- US1, US2, US4, US5 can theoretically run in parallel after Foundational (US3 depends on US2)

---

## Parallel Example: User Story 1 & 2

```bash
# After Foundational phase completes:

# Developer A - User Story 1:
Task: "Add settings link at bottom of sidebar in chat_live/index.ex"
Task: "Add no provider selected prompt in chat_live/index.ex"

# Developer B - User Story 2 (in parallel):
Task: "Create FormComponent for provider add/edit form"
Task: "Add Add Provider button and modal trigger to Index"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup (migration)
2. Complete Phase 2: Foundational (provider resource extensions, routes)
3. Complete Phase 3: User Story 1 (view and select)
4. Complete Phase 4: User Story 2 (add provider)
5. **STOP and VALIDATE**: Test adding and selecting providers
6. Deploy/demo if ready - users can now use chat with configured providers

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 + 2 → Test independently → Deploy (MVP with add/select!)
3. Add User Story 3 → Test edit functionality → Deploy
4. Add User Story 4 → Test delete functionality → Deploy
5. Add User Story 5 → Test usage stats → Deploy (Full feature!)

### Suggested MVP Scope

**Minimum Viable Product**: User Stories 1 & 2 (View/Select + Add Provider)
- Users can navigate to settings from chat
- Users can add new AI providers
- Users can select and use providers for chat
- Delivers core value without update/delete/usage features

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- FormComponent is reused between US2 (add) and US3 (edit)
