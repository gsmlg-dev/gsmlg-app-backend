# Feature Specification: Apps Management Module

**Feature Branch**: `003-apps-management`
**Created**: 2026-01-08
**Status**: Draft
**Input**: User description: "add a new module to admin_web, to manage apps, the current apps are static at apps/gsmlg_app_web/lib/gsmlg_app_web/controllers/apps_html, we should make them configurable, the app_web still does not need database, but can load the apps data from admin's API and should cache them to static files, and update them with a command in release"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Admin Creates and Manages Apps (Priority: P1)

An administrator accesses the admin interface to add, edit, or remove app entries that will be displayed on the public website. Each app has details like name, description, icon, supported platforms, category, and store links.

**Why this priority**: This is the core functionality - without the ability to manage apps in admin, the entire feature has no value. It enables administrators to maintain app listings without code changes.

**Independent Test**: Can be fully tested by logging into admin, creating a new app entry with all required fields, and verifying it appears in the apps list. Delivers immediate value as soon as the admin interface is functional.

**Acceptance Scenarios**:

1. **Given** an authenticated admin user, **When** they navigate to the Apps Management section, **Then** they see a list of all configured apps with options to add, edit, or delete.

2. **Given** an admin is on the Apps Management page, **When** they click "Add New App" and fill in all required fields (name, description, icon, platforms, category), **Then** the app is saved and appears in the list.

3. **Given** an existing app in the list, **When** the admin clicks edit and modifies the app name, **Then** the change is saved and reflected in the list.

4. **Given** an existing app in the list, **When** the admin clicks delete and confirms, **Then** the app is removed from the system.

5. **Given** an admin adding a new app, **When** they add store links (App Store, Play Store, F-Droid), **Then** each link is validated as a proper URL and stored with the app.

---

### User Story 2 - Admin API Exposes Apps Data (Priority: P2)

The admin backend provides an API endpoint that returns the list of all active apps in a structured format. This API is consumed by the public website to display the apps listing.

**Why this priority**: The API is the bridge between admin management and public display. Without it, changes made in admin cannot be reflected on the public site.

**Independent Test**: Can be tested by calling the API endpoint directly and verifying it returns valid data structure with all app fields. Delivers value by enabling any client to fetch current app listings.

**Acceptance Scenarios**:

1. **Given** apps exist in the admin system, **When** a request is made to the apps API endpoint, **Then** a list of all active apps is returned with complete details.

2. **Given** an app with store links, **When** the API response is received, **Then** store links include the store type (appstore, playstore, fdroid) and URL.

3. **Given** the API endpoint, **When** accessed without authentication, **Then** the request succeeds (public read-only endpoint for caching purposes).

---

### User Story 3 - Public Website Caches Apps from API (Priority: P3)

The public website (app_web) fetches apps data from the admin API and caches it to a static file. This cached data is used to render the apps listing page, eliminating the need for database access in app_web.

**Why this priority**: Caching enables the public site to display apps without runtime API calls, improving performance and reducing coupling. Depends on the API being available first.

**Independent Test**: Can be tested by running the cache update command and verifying a static cache file is created with the expected data structure. Delivers value by enabling offline/fast apps display.

**Acceptance Scenarios**:

1. **Given** the admin API has apps data, **When** the cache update command is executed, **Then** a static cache file is created in the app_web priv directory.

2. **Given** a cached apps file exists, **When** the public website renders the apps page, **Then** it reads from the cached file instead of making an API call.

3. **Given** the cache file does not exist, **When** the public website tries to render apps, **Then** it gracefully handles the missing cache with an empty list or fallback message.

---

### User Story 4 - Release Command Updates Apps Cache (Priority: P4)

A release command is available to update the apps cache as part of deployment or maintenance. This can be run during deployment to ensure fresh data.

**Why this priority**: Enables operational workflow for keeping the public site in sync with admin without manual intervention. Nice-to-have after core features work.

**Independent Test**: Can be tested by executing the release command in a release environment and verifying the cache is updated. Delivers value by automating the sync process.

**Acceptance Scenarios**:

1. **Given** a deployed release, **When** the cache update command is executed via release command, **Then** the apps cache is refreshed from the admin API.

2. **Given** the admin API is unreachable during cache update, **When** the command is executed, **Then** an appropriate error message is displayed and the existing cache is preserved.

---

### Edge Cases

- What happens when an app has no store links? System displays the app without store buttons.
- What happens when the icon path is invalid? System displays a placeholder icon.
- How does the system handle duplicate app labels? System prevents saving and shows validation error.
- What happens when the admin API is unavailable during cache update? Command fails gracefully with error message, preserving existing cache.
- What happens when the cached file is corrupted? System falls back to empty list and logs the error.

## Requirements *(mandatory)*

### Functional Requirements

#### Admin App Management
- **FR-001**: System MUST allow authenticated admins to view a list of all configured apps
- **FR-002**: System MUST allow admins to create new app entries with: name, label (unique identifier), short description, long description, icon path, platforms, and category
- **FR-003**: System MUST allow admins to edit existing app entries
- **FR-004**: System MUST allow admins to delete app entries (soft delete - marks as inactive, hidden from public)
- **FR-004a**: System MUST allow admins to restore previously deleted apps
- **FR-004b**: System MUST allow admins to view deleted apps separately (e.g., "Show deleted" filter)
- **FR-005**: System MUST validate app labels are unique across all entries
- **FR-006**: System MUST support multiple store links per app (App Store, Play Store, F-Droid, others)
- **FR-007**: System MUST validate store links as valid URLs
- **FR-007a**: System MUST allow admins to manually reorder apps (drag-drop or position numbers)
- **FR-007b**: System MUST display apps in the configured display order on both admin and public sites

#### Admin API
- **FR-008**: System MUST expose a public API endpoint that returns only active (non-deleted) apps
- **FR-009**: API response MUST include: name, label, short_description, long_description, icon_path, platforms, category, display_order, and store_links
- **FR-010**: API MUST return data in a structured format suitable for caching

#### Public Website Caching
- **FR-011**: System MUST provide a mechanism to fetch apps from admin API and cache to a static file
- **FR-012**: Cached file MUST be stored in the app_web priv directory
- **FR-013**: System MUST use cached data when rendering the apps listing page
- **FR-014**: System MUST gracefully handle missing or corrupted cache files

#### Release Integration
- **FR-015**: System MUST provide a release command to update the apps cache
- **FR-016**: Cache update command MUST handle API failures gracefully
- **FR-017**: System MUST read admin API URL from environment variable (ADMIN_API_URL) for cache updates

### Key Entities

- **App**: Represents a mobile/desktop application with name, label (unique identifier), short_description, long_description, icon_path, platforms (list of: ios, android, macos, windows, linux), category (network, utility, development), display_order (position for manual sorting), active status (for soft delete), and associated store links
- **StoreLink**: Represents a link to an app store with store_type (appstore, playstore, fdroid, other) and URL
- **AppsCache**: Static file containing serialized list of all apps for the public website

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Admins can add a new app entry in under 2 minutes
- **SC-002**: Apps page on public website loads in under 500ms using cached data
- **SC-003**: Cache update command completes in under 10 seconds under normal network conditions
- **SC-004**: 100% of app data changes made in admin are reflected on public site after cache update
- **SC-005**: System maintains zero downtime for the apps listing page during cache updates

## Clarifications

### Session 2026-01-08

- Q: How should apps be ordered for display? → A: Manual ordering (admin can set position/drag-drop)
- Q: What happens when an admin deletes an app? → A: Soft delete (mark as inactive/hidden, recoverable)
- Q: How does app_web know the admin API URL for cache updates? → A: Environment variable (ADMIN_API_URL)
- Q: How should app descriptions be structured? → A: Two fixed fields (short description + long description)

## Assumptions

- The admin backend (admin_web) has database access via Ash framework
- The public website (app_web) intentionally avoids database dependencies for simplicity
- The admin API endpoint URL is configured via ADMIN_API_URL environment variable and reachable via HTTP during cache updates
- App icons are stored as static assets and referenced by path
- Internationalization of app names/descriptions is handled at the template level (using gettext), not in the stored data
- The cache file format will be Elixir term format for easy loading
