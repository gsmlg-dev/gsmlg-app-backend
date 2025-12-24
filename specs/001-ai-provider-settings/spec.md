# Feature Specification: AI Provider Settings

**Feature Branch**: `001-ai-provider-settings`
**Created**: 2025-12-20
**Status**: Draft
**Input**: User description: "on /chat page, it should have a setting option at the bottom of left menu, it will to a new page for setup ai provider, support add, update, remove and show usage. if no ai provider selected, it should show a select provider message at the center of the page."

## Clarifications

### Session 2025-12-21

- Q: Are AI providers shared across all users or scoped to individual users? → A: Shared - All users see the same provider list configured by admins

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View and Select AI Provider (Priority: P1)

An administrator accesses the chat page and needs to select an AI provider before they can start chatting. If no provider is currently selected, they see a clear message in the center of the page prompting them to select or configure a provider. They can click a settings link in the left menu to access provider configuration.

**Why this priority**: This is the core functionality - without a selected provider, the chat feature cannot work. Users must be able to see their current state and take action.

**Independent Test**: Can be fully tested by navigating to the chat page with no provider selected, verifying the prompt message appears, and then selecting an existing provider.

**Acceptance Scenarios**:

1. **Given** I am on the chat page with no AI provider selected, **When** the page loads, **Then** I see a centered message indicating I need to select or configure an AI provider
2. **Given** I am on the chat page, **When** I look at the left menu, **Then** I see a "Settings" option at the bottom of the menu
3. **Given** I have AI providers configured, **When** I select a provider from the available options, **Then** that provider becomes active for my chat sessions

---

### User Story 2 - Add New AI Provider (Priority: P1)

An administrator wants to add a new AI provider (such as DeepSeek, Zhipu AI, or Moonshot AI) to enable chat functionality. They navigate to the settings page, fill out the provider details including name, API endpoint, and API key, then save the configuration.

**Why this priority**: Users must be able to add providers before they can use the chat feature. This is foundational functionality.

**Independent Test**: Can be tested by navigating to settings, adding a new provider with valid credentials, and verifying it appears in the provider list.

**Acceptance Scenarios**:

1. **Given** I am on the AI provider settings page, **When** I click "Add Provider", **Then** I see a form to configure a new provider
2. **Given** I am filling out the add provider form, **When** I enter valid provider details and save, **Then** the provider is added to my list of available providers
3. **Given** I am adding a provider, **When** I submit without required fields, **Then** I see validation errors indicating what is missing

---

### User Story 3 - Update Existing AI Provider (Priority: P2)

An administrator needs to update an existing AI provider's configuration, such as changing the API key or updating the endpoint URL. They navigate to settings, select the provider to edit, make changes, and save.

**Why this priority**: Important for maintenance but secondary to initial setup. Users need to be able to modify configurations when API keys rotate or settings change.

**Independent Test**: Can be tested by editing an existing provider's API key and verifying the change is persisted.

**Acceptance Scenarios**:

1. **Given** I am on the AI provider settings page with existing providers, **When** I click edit on a provider, **Then** I see a form pre-filled with that provider's current settings
2. **Given** I am editing a provider, **When** I change settings and save, **Then** the updated configuration is persisted
3. **Given** I am editing a provider, **When** I cancel without saving, **Then** no changes are made

---

### User Story 4 - Remove AI Provider (Priority: P2)

An administrator wants to remove an AI provider that is no longer needed. They navigate to settings, select the provider to remove, confirm the deletion, and the provider is removed from the system.

**Why this priority**: Important for cleanup and management but not critical for initial use of the feature.

**Independent Test**: Can be tested by removing an existing provider and verifying it no longer appears in the provider list.

**Acceptance Scenarios**:

1. **Given** I am on the AI provider settings page with existing providers, **When** I click delete on a provider, **Then** I see a confirmation dialog
2. **Given** I am confirming deletion, **When** I confirm, **Then** the provider is removed from my list
3. **Given** the deleted provider was currently selected, **When** deletion completes, **Then** the system prompts me to select a different provider

---

### User Story 5 - View Provider Usage Statistics (Priority: P3)

An administrator wants to see usage statistics for their configured AI providers to understand costs and usage patterns. They navigate to settings and view usage metrics for each provider.

**Why this priority**: Valuable for cost management and monitoring but not essential for core chat functionality.

**Independent Test**: Can be tested by viewing the settings page and verifying usage statistics are displayed for providers that have been used.

**Acceptance Scenarios**:

1. **Given** I am on the AI provider settings page, **When** I view a provider's details, **Then** I see usage statistics including message count and token usage
2. **Given** a provider has not been used, **When** I view its details, **Then** I see zero usage or a "No usage yet" message

---

### Edge Cases

- What happens when all providers are deleted? The system shows the "select provider" message on the chat page.
- How does system handle invalid API credentials? Display a clear error message when validation fails during add/update.
- What happens if the currently selected provider is deleted? Clear the selection and prompt user to select a new provider.
- How does system handle network errors when testing provider connections? Show appropriate error messages with retry option.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a settings link at the bottom of the left menu on the chat page
- **FR-002**: System MUST show a centered message when no AI provider is selected, prompting the user to configure or select a provider
- **FR-003**: System MUST provide a dedicated settings page for AI provider management accessible from the chat page
- **FR-004**: System MUST allow administrators to add new AI providers with name, type, API endpoint, API key, and optional model parameters
- **FR-005**: System MUST allow administrators to update existing AI provider configurations
- **FR-006**: System MUST allow administrators to remove AI providers with confirmation
- **FR-007**: System MUST display usage statistics for each provider including total messages sent and tokens consumed
- **FR-008**: System MUST validate required fields when adding or updating providers
- **FR-009**: System MUST securely store API keys (keys should not be displayed in full after initial entry)
- **FR-010**: System MUST allow users to select an active provider for chat sessions
- **FR-011**: System MUST persist provider selection across user sessions

### Key Entities

- **AI Provider**: Represents a configured AI service shared across all users (e.g., DeepSeek, Zhipu AI, Moonshot AI). Contains name, provider type, API endpoint, API key, model configuration, and active status. Configured by administrators, visible to all authenticated users.
- **Provider Usage**: Tracks usage metrics per provider including message count, token consumption, and last used timestamp. Aggregated across all users.
- **User Provider Selection**: Links a user to their currently selected AI provider from the shared provider list for chat sessions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can add a new AI provider in under 2 minutes
- **SC-002**: Users see the "select provider" prompt within 1 second when accessing chat with no provider selected
- **SC-003**: Provider CRUD operations complete within 3 seconds
- **SC-004**: 100% of provider additions with valid credentials succeed on first attempt
- **SC-005**: Usage statistics are updated in real-time (within 5 seconds of chat activity)
- **SC-006**: API keys are masked after initial entry, showing only last 4 characters

**Implementation Note**: SC-001 through SC-003 are UX guidelines validated through manual testing during quickstart.md verification. No automated performance tests are required for this feature scope.

## Assumptions

- Users accessing this feature are authenticated administrators
- The existing AI provider data model (GsmlgAppAdmin.AI.Provider) will be extended to support usage tracking
- Provider types are limited to OpenAI-compatible APIs (DeepSeek, Zhipu AI, Moonshot AI, OpenAI)
- AI providers are shared across all users; administrators configure providers centrally
- Usage tracking is aggregated per provider (not per-user)
- The left menu already exists on the chat page and can accommodate an additional settings link
