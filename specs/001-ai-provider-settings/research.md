# Research: AI Provider Settings

**Feature**: 001-ai-provider-settings
**Date**: 2025-12-21

## Existing Codebase Analysis

### Current Provider Resource (`GsmlgAppAdmin.AI.Provider`)

**Location**: `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider.ex`

**Existing Attributes**:
- `id` (UUID primary key)
- `name` (string, max 100 chars)
- `slug` (string, max 50 chars, unique identity)
- `api_base_url` (string)
- `api_key` (string, sensitive)
- `model` (string)
- `available_models` (array of strings)
- `default_params` (map)
- `is_active` (boolean, default true)
- `description` (string)
- `created_at`, `updated_at` (timestamps)

**Existing Actions**:
- `:create` - accepts all attributes
- `:update` - accepts all except slug
- `:read`, `:destroy` - defaults
- `:active` - filters by `is_active == true`
- `:by_slug` - lookup by slug

**Decision**: Extend existing resource with usage tracking attributes rather than creating separate resource. This simplifies queries and maintains data locality.

### Current Chat LiveView (`GsmlgAppAdminWeb.ChatLive.Index`)

**Location**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/chat_live/index.ex`

**Current Behavior**:
- Provider dropdown in sidebar (lines 281-300)
- First provider auto-selected on mount (line 23)
- No "no provider" state handling
- No settings link present

**Decision**: Add settings link at bottom of sidebar, add conditional "no provider selected" centered prompt in main area.

### Router Structure

**Location**: `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex`

**Current Pattern**: LiveViews in authenticated `live_session` block (lines 43-53)

**Decision**: Add provider settings routes within same authenticated live_session for consistency.

## Best Practices Applied

### Ash Framework Patterns

1. **Usage Tracking**: Add aggregated usage attributes directly to Provider resource
   - `total_messages` (integer, default 0)
   - `total_tokens` (integer, default 0)
   - `last_used_at` (utc_datetime_usec)

2. **API Key Masking**: Use computed attribute for display
   - Store full key (sensitive)
   - Compute masked version for UI (show last 4 chars)

3. **Increment Action**: Create dedicated action for usage updates
   - `increment_usage(message_count, token_count)`

### Phoenix LiveView Patterns

1. **Form Component**: Separate `form_component.ex` for add/edit
   - Reusable across modal and dedicated page contexts
   - Use `AshPhoenix.Form` for validation

2. **Settings Page Structure**:
   - Index: List all providers with actions
   - Show: Provider details with usage stats
   - Form: Modal for add/edit

3. **Navigation**: Use `JS.patch` for seamless transitions

### UI/UX Patterns

1. **No Provider State**: Centered card with icon and CTA button
2. **API Key Display**: Input type "password" or masked text with reveal toggle
3. **Delete Confirmation**: Modal with provider name confirmation
4. **Usage Display**: Card with metrics (messages, tokens, last used)

## Alternatives Considered

### Usage Tracking Approach

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| A. Attributes on Provider | Simple queries, atomic updates | Slight denormalization | **Selected** |
| B. Separate ProviderUsage resource | Clean separation | Extra joins, more complexity | Rejected |
| C. Time-series usage data | Historical analysis | Overkill for MVP | Rejected |

**Rationale**: For MVP, aggregated totals on Provider resource are sufficient. Historical tracking can be added later if needed.

### Settings Page Location

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| A. `/chat/settings` | Contextual, near chat | Nested under chat namespace | **Selected** |
| B. `/settings/providers` | Separate settings area | Requires nav structure | Rejected |
| C. Modal in chat page | No navigation | Limited space for CRUD | Rejected |

**Rationale**: `/chat/settings` maintains context while providing dedicated space for provider management.

## Technical Decisions Summary

1. **Extend Provider resource** with usage tracking attributes (not separate resource)
2. **Add `/chat/settings` routes** within existing authenticated live_session
3. **Create ProviderSettingsLive** with index, show, form_component modules
4. **Modify ChatLive.Index** to add settings link and no-provider prompt
5. **Use AshPhoenix.Form** for provider form with built-in validation
6. **Mask API keys** using computed attribute showing last 4 characters

All NEEDS CLARIFICATION items resolved. Ready for Phase 1 design.
