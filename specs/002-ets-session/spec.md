# Feature Specification: ETS-Based Admin Session Management

**Feature Branch**: `002-ets-session`
**Created**: 2025-12-26
**Status**: Draft
**Input**: User description: "the gsmlg_app_admin_web is support for admin sign in, and the admin sign in should have a session, currently it does not work well. we need update the user login session module, login user session data should save in ets, rather than cookie. session are must automic enable in the web access, and all web page can simple get the current_user, as same as websocket, it also can pass cookie and assign current_user."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Admin Sign In with Persistent Session (Priority: P1)

An administrator navigates to the admin sign-in page and enters their credentials. Upon successful authentication, their session is established and persisted server-side. The admin is redirected to the dashboard where they can access all admin features without re-authenticating.

**Why this priority**: This is the core functionality - without reliable session establishment after sign-in, admins cannot use the system at all.

**Independent Test**: Can be fully tested by signing in as an admin user and verifying the session persists across page navigations.

**Acceptance Scenarios**:

1. **Given** an admin with valid credentials visits the sign-in page, **When** they submit correct username and password, **Then** they are authenticated and redirected to the dashboard with their session active.

2. **Given** an authenticated admin, **When** they navigate to any protected admin page, **Then** their session is automatically recognized and `current_user` is available on the page.

3. **Given** an admin with invalid credentials, **When** they attempt to sign in, **Then** they receive an error message and no session is created.

---

### User Story 2 - Session Availability in LiveView Pages (Priority: P1)

An authenticated admin accesses a LiveView-powered page (like the chat interface or user management). The page automatically recognizes their session and makes the current user available for display and authorization without requiring any additional authentication steps.

**Why this priority**: LiveView pages are the primary interface for admin users; session must work seamlessly with WebSocket-based connections.

**Independent Test**: Can be fully tested by navigating to a LiveView page after sign-in and verifying `current_user` is accessible in the template.

**Acceptance Scenarios**:

1. **Given** an authenticated admin, **When** they access a LiveView page via browser navigation, **Then** the LiveView socket receives the session data and `current_user` is assigned automatically.

2. **Given** an authenticated admin on a LiveView page, **When** the WebSocket reconnects (e.g., after network interruption), **Then** the session is restored and `current_user` remains available.

3. **Given** an unauthenticated user, **When** they attempt to access a protected LiveView page, **Then** they are redirected to the sign-in page.

---

### User Story 3 - Session Persistence Across Browser Refreshes (Priority: P2)

An authenticated admin refreshes their browser or closes and reopens a tab within the session validity period. The system recognizes their session and maintains their authenticated state without requiring them to sign in again.

**Why this priority**: Essential for user experience but depends on P1 stories being complete first.

**Independent Test**: Can be fully tested by signing in, refreshing the page, and verifying the user remains authenticated.

**Acceptance Scenarios**:

1. **Given** an authenticated admin with an active session, **When** they refresh the browser page, **Then** they remain authenticated and can continue working.

2. **Given** an authenticated admin with an active session, **When** they close and reopen the browser tab, **Then** they remain authenticated if session cookie is still valid.

---

### User Story 4 - Admin Sign Out (Priority: P2)

An authenticated admin clicks the sign-out button. Their session is terminated both client-side (cookie removed) and server-side (session data cleared). They are redirected to the sign-in page.

**Why this priority**: Important for security but secondary to sign-in functionality.

**Independent Test**: Can be fully tested by signing in, then signing out, and verifying the session is completely invalidated.

**Acceptance Scenarios**:

1. **Given** an authenticated admin, **When** they click sign out, **Then** their session is terminated and they are redirected to the sign-in page.

2. **Given** a signed-out admin, **When** they attempt to access a protected page directly (e.g., via bookmarked URL), **Then** they are redirected to sign-in.

3. **Given** a signed-out admin, **When** they try to use the back button to access cached protected pages, **Then** those pages do not function and require re-authentication.

---

### Edge Cases

- Session expiration during active use: When a session expires while the admin is actively using the system, the next request or LiveView action will detect the invalid session and redirect to sign-in.
- Concurrent sessions: Multiple concurrent sessions from the same admin account are allowed; each device/browser maintains its own independent session.
- Server restart: Sessions are not persisted; all active sessions are lost on server restart and admins must re-authenticate. This is acceptable for an admin interface with infrequent restarts.
- Storage capacity: Session storage is bounded by available memory; for 100 concurrent sessions (per SC-006), this is negligible.
- Orphaned session cookie: When a session cookie references a session ID that no longer exists (e.g., after restart or expiration cleanup), the user is treated as unauthenticated and redirected to sign-in.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST store session data in server-side storage instead of client-side cookies.

- **FR-002**: System MUST generate a unique session identifier for each authenticated session and store only this identifier in the client cookie.

- **FR-003**: System MUST automatically load session data and populate `current_user` on every HTTP request for authenticated users.

- **FR-004**: System MUST pass session information to LiveView WebSocket connections via the connection mechanism.

- **FR-005**: System MUST automatically assign `current_user` in LiveView socket assigns when a valid session exists.

- **FR-006**: System MUST invalidate and remove session data from server-side storage when an admin signs out.

- **FR-007**: System MUST handle expired or invalid session identifiers gracefully by treating the user as unauthenticated.

- **FR-008**: Session data MUST be available consistently across both regular HTTP requests and LiveView WebSocket connections.

- **FR-009**: System MUST maintain session state across page refreshes and browser tab reopens within the session validity period.

- **FR-010**: System MUST redirect unauthenticated users to the sign-in page when they attempt to access protected resources.

### Key Entities

- **Session**: Represents an authenticated user session, containing the user identifier, creation timestamp, expiration time, and any session metadata needed for the admin interface.

- **User (existing)**: The admin user entity from the Accounts domain that is loaded from the session and made available as `current_user`.

- **Session Store**: Server-side storage mechanism that maps session identifiers to session data, providing fast lookup and automatic expiration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Admins can sign in and remain authenticated across all page navigations without requiring re-authentication during a single session.

- **SC-002**: `current_user` is accessible on 100% of protected pages (both regular and LiveView) without errors or delays perceptible to users.

- **SC-003**: Session state persists correctly across browser refreshes with zero unexpected logouts during active use.

- **SC-004**: LiveView WebSocket connections receive session data and assign `current_user` automatically on every connection and reconnection.

- **SC-005**: Sign-out completely invalidates the session, preventing access to protected resources even with cached pages or back button usage.

- **SC-006**: The system handles 100 concurrent admin sessions without degradation in session lookup performance.

- **SC-007**: Invalid or expired session cookies result in smooth redirection to sign-in with no errors shown to users.

## Clarifications

### Session 2025-12-28

- Q: What should the session expiration duration be? → A: 8 hours (balance security and usability)
- Q: How should concurrent sessions from the same admin be handled? → A: Multiple concurrent sessions allowed
- Q: What happens when the server restarts and ETS tables are cleared? → A: Sessions lost on restart - admins must re-authenticate

## Assumptions

- The application runs on a single server node (distributed session storage across multiple nodes is out of scope for this feature).
- Session expiration period is 8 hours from last activity, balancing security with usability for admin work sessions.
- The existing authentication integration for password verification remains unchanged; only session storage mechanism changes.
- Session cookies will use secure, HTTP-only settings appropriate for production environments.
