# Feature Specification: User Management（使用者管理）

**Feature Branch**: `008-user-management`

**Created**: 2026-06-15

**Status**: Draft

**Input**: User description: "@docs/superpowers/008-user-management.md ultrathink"

## Clarifications

### Session 2026-06-15

- Q: Should the removal (delete) audit record include the deleted account's prior role assignments, like create/edit do? → A: No — the removal audit keeps the existing single-account snapshot **without** roles; this create/edit-vs-removal asymmetry is **deliberate**, and a downstream audit-query consumer reconstructs an account's roles at removal time by association rather than from the audit record (recorded as a known precondition for the later audit-query feature).
- Q: When an already-removed account is "removed" again (e.g. a retried batch), is an audit record written? → A: No — a no-op produces no audit record; only an actual state change is audited. "100% audited" means every real change is recorded, not every attempt.
- Q: How is a rename-vs-create race on the same username resolved (the uniqueness check and the write are not atomic)? → A: The active-uniqueness constraint is the final arbiter; the pre-check is an optimization for the supported (≤50-admin) scale, and a race that slips past it surfaces as the **same business rejection** — not a transport/system failure or partial state. No version / optimistic-lock field is added (that would require a schema change).
- Q: At which boundary is the performance target (SC-008) measured? → A: Server-side processing time (including the in-transaction audit write), excluding cold-start, measured by direct timed calls to the backend; front-end rendering latency is measured separately.
- Q: When a submitted role became unavailable between form load and submit, how should the front end present the rejection? → A: The back end guarantees the business rejection; refined front-end messaging / auto-refresh of the role list is a follow-up (out of scope for this feature).

## User Scenarios & Testing *(mandatory)*

The actors are **administrators** of the back-office. They hold one of three permission levels: a **super-admin** (full user management), an **admin** (may view the user list), and a **regular** account (may only look up the role list). Three **baseline accounts** seeded at setup must never be deletable.

### User Story 1 - View & search the user list (Priority: P1)

An administrator opens the user-management screen and sees a paginated list of active user accounts, each showing its username, nickname, gender, phone, email, status, and assigned roles. The administrator narrows the list by typing part of a name/nickname/email or by selecting an exact phone/status/gender.

**Why this priority**: Seeing and finding accounts is the foundation of all management; nothing else is usable without it.

**Independent Test**: Sign in as an administrator allowed to view users, open the list, confirm accounts and their roles appear with paging, then apply a filter and confirm only matching accounts remain.

**Acceptance Scenarios**:

1. **Given** active accounts exist, **When** the administrator opens the list, **Then** a paginated list shows each account with its username, nickname, gender, phone, email, status, assigned roles, and created/updated metadata.
2. **Given** the list is open, **When** the administrator types part of a username, nickname, or email, **Then** only accounts whose corresponding field contains that text are shown.
3. **Given** the list is open, **When** the administrator selects an exact status, gender, or phone, **Then** only accounts matching that exact value are shown.
4. **Given** several search fields are left blank, **When** the administrator searches, **Then** the blank fields do not constrain the results.

### User Story 2 - Create a user (Priority: P1)

An authorized administrator opens the create form, fills in the username, nickname, gender, phone, email, status, and one or more roles, and submits. The new account is created with a standard default password and the chosen roles.

**Why this priority**: Adding accounts is a primary management action and a prerequisite for onboarding.

**Independent Test**: Submit the create form with valid data and confirm the new account appears in the list with the assigned roles; submit a username that already exists and confirm creation is refused with a clear message.

**Acceptance Scenarios**:

1. **Given** the create form with valid data, **When** the administrator submits, **Then** a new account is created with the chosen roles and a default password, and it appears in the list.
2. **Given** a username already used by an active account, **When** the administrator submits, **Then** creation is refused and the administrator is told the username is taken.
3. **Given** the form includes a role that does not exist or is inactive, **When** the administrator submits, **Then** creation is refused.

### User Story 3 - Edit a user (Priority: P1)

An authorized administrator opens an existing account, changes any of its fields — including renaming it, changing its status, or adjusting its assigned roles — and submits.

**Why this priority**: Keeping accounts correct (roles, status, profile) is core day-to-day management.

**Independent Test**: Edit an account's roles, status, and name, confirm the changes persist and the audit trail reflects them; attempt to rename to a taken username and confirm refusal.

**Acceptance Scenarios**:

1. **Given** an existing account, **When** the administrator changes its profile, status, or roles and submits, **Then** the changes persist and are reflected in the list.
2. **Given** an existing account, **When** the administrator renames it to an unused username, **Then** the rename succeeds.
3. **Given** an existing account, **When** the administrator renames it to a username already held by another active account, **Then** the rename is refused.
4. **Given** an account that has already been removed, **When** the administrator attempts to edit it, **Then** the edit is refused.

### User Story 4 - Delete users with baseline protection (Priority: P2)

An authorized administrator removes a single account or a selected batch. The three baseline accounts can never be removed, and a batch that contains any baseline account is rejected as a whole.

**Why this priority**: Removal matters but is secondary to viewing, creating, and editing; protection prevents catastrophic loss of the seeded admin accounts.

**Independent Test**: Remove a non-baseline account and confirm it leaves the active list; attempt to remove a baseline account (single and inside a batch) and confirm both are refused with nothing changed.

**Acceptance Scenarios**:

1. **Given** a non-baseline account, **When** the administrator removes it, **Then** it disappears from the active list and can no longer be edited.
2. **Given** a baseline account, **When** the administrator attempts to remove it, **Then** the removal is refused.
3. **Given** a batch selection that includes a baseline account, **When** the administrator removes the batch, **Then** the whole batch is refused and **no** account in it is removed.
4. **Given** a batch of non-baseline accounts, **When** the administrator removes the batch, **Then** all of them leave the active list.

### User Story 5 - Role-based access control (Priority: P2)

Each administrator may only perform the user-management operations their permission level grants. A super-admin manages users fully; an admin may view the list; a regular account may only look up the role list.

**Why this priority**: Prevents unauthorized changes to accounts; a governance guarantee distinct from the management actions themselves.

**Independent Test**: Sign in at each permission level and confirm permitted operations succeed while restricted ones are denied.

**Acceptance Scenarios**:

1. **Given** an admin-level account, **When** it views the user list, **Then** the request is allowed.
2. **Given** an admin-level account, **When** it attempts to create, edit, or remove a user, **Then** the request is denied.
3. **Given** a regular-level account, **When** it requests the user list, **Then** the request is denied; **When** it requests the role list, **Then** the request is allowed.

### User Story 6 - Change audit trail (Priority: P3)

Every create, edit, and removal is recorded in an immutable audit trail that captures who acted, when, what changed (before and after), and — for create/edit — the previous and new role assignments. Passwords never appear in the trail.

**Why this priority**: Traceability and compliance; valuable but does not block the core management flow.

**Independent Test**: Perform create/edit/remove actions and confirm each produces an audit entry with operator, timestamp, and before/after state; confirm role changes show old and new roles; confirm no password appears in clear text.

**Acceptance Scenarios**:

1. **Given** any create, edit, or removal, **When** it completes, **Then** an audit entry records the acting administrator, the time, the operation, and the affected account's before/after state.
2. **Given** an edit that changes a user's roles, **When** it completes, **Then** the audit entry shows both the previous and the new role set.
3. **Given** any recorded operation, **When** the audit entry is inspected, **Then** the account password appears only in redacted form, never in clear text.

### Edge Cases

- Removing an account that was already removed is treated as a no-op (no error, no double effect, and **no audit record** is written) so a retried batch is safe.
- If an infrastructure failure interrupts a batch removal **after** the baseline-protection check passes, accounts removed before the failure stay removed and the rest are untouched; the administrator can safely retry.
- A search field left blank (or cleared) does not filter on that field.
- Creating an account whose username matches a previously-removed account is allowed (removed usernames are freed for reuse).
- If two administrators concurrently claim the same username (one renames an account to it while another creates a new account with it), the active-uniqueness constraint is the final arbiter and the losing operation receives the same "username already taken" business rejection — not a system failure.
- Assigning a role that was removed/deactivated between loading the form and submitting is refused.
- Submitting an out-of-range status or gender value is refused.
- A baseline account may be renamed or have its roles/status changed; only its removal is blocked.

## Requirements *(mandatory)*

### Functional Requirements

**List & lookup**

- **FR-001**: System MUST present administrators a paginated list of active user accounts, each showing username, nickname, gender, phone, email, status, assigned roles, and who/when the account was created and last updated.
- **FR-002**: System MUST let administrators narrow the list by username, nickname, or email via partial-text match, and by phone, status, or gender via exact match; blank search fields MUST NOT constrain results; results MUST have a stable default ordering.
- **FR-003**: System MUST provide administrators the full set of currently-active roles for selection when assigning roles to an account.

**Create**

- **FR-004**: System MUST let an authorized administrator create a new account by supplying username, nickname, gender, phone, email, status, and one or more roles.
- **FR-005**: System MUST assign every newly created account a standard default password (the concrete value is fixed by the design — see data-model); administrators do not set or see passwords through this feature.
- **FR-006**: System MUST refuse creation when the chosen username already belongs to another active account, and inform the administrator of the conflict.

**Edit**

- **FR-007**: System MUST let an authorized administrator edit an existing account's username, nickname, gender, phone, email, status, and assigned roles.
- **FR-008**: System MUST allow renaming an account and MUST refuse a rename that collides with another active account's username.
- **FR-009**: System MUST refuse any edit targeting an account that has already been removed.

**Role & value validity**

- **FR-010**: System MUST refuse a create or edit that references any role which does not exist or is not active; if **any** submitted role is invalid the **entire** operation is rejected and no roles are partially applied (no silent skipping).
- **FR-011**: System MUST refuse a create or edit with an out-of-range status or gender value.
- **FR-012**: System MUST persist a user's full role set as supplied on each create/edit (the submitted set fully replaces any prior assignment).

**Remove**

- **FR-013**: System MUST let an authorized administrator remove a single account or a selected batch of accounts; removal MUST be recoverable-safe — a **soft removal** that marks the account removed (taken out of active lists, restorable in principle) rather than permanently erasing it (permanent erasure is future scope).
- **FR-014**: System MUST prevent removal of the three baseline accounts (the seeded super-admin, admin, and regular accounts — identified by their immutable internal ids 1/2/3) by any single or batch path; protection is keyed by id (not username), so it persists even after a baseline account is renamed, and these ids must never be reused or renumbered.
- **FR-015**: System MUST refuse an entire batch removal that includes any baseline account, leaving every account in that batch unchanged.
- **FR-016**: System MUST still allow editing (including renaming) the baseline accounts — only their removal is protected.

**Access control**

- **FR-017**: System MUST restrict each user-management operation to administrators whose permission level grants it, and deny the operation to permission levels without that grant — per the Access-Control Matrix below.
- **FR-018**: System MUST ensure no user-management operation is reachable without an access-control check.

**Access-Control Matrix** (which permission level may perform each operation):

| Operation | super-admin | admin | regular |
|---|:--:|:--:|:--:|
| View / search user list | ✓ | ✓ | ✗ |
| Look up role list | ✓ | ✓ | ✓ |
| Create / Edit / Delete / Batch-delete user | ✓ | ✗ | ✗ |

**Audit & integrity**

- **FR-019**: System MUST record every create, edit, and removal in an immutable audit trail capturing the acting administrator, the time, the operation type, and the affected account's state — **before and after** for create/edit, and **before-only** for removal (no after-state).
- **FR-020**: System MUST include the account's previous and new role assignments in the audit record for **create and edit** operations; the **removal** audit record intentionally does **not** embed role assignments (the account's roles at removal time remain reconstructable by association — a deliberate asymmetry, see *Clarifications*).
- **FR-021**: System MUST never expose or record account passwords in clear text — in audit records or in any list/detail response.
- **FR-022**: System MUST apply each change and its audit record together as one unit, so there is never a change that took effect without a matching audit record (or an audit record without the change).

**Result signalling**

- **FR-023**: System MUST report business refusals (taken username, baseline-account removal, invalid role or value) via a **distinct business error code** (per the frozen data contract), clearly distinguishable from both success and from system/transport failures.
- **FR-024**: System MUST keep all responses consistent with the project's established response and data contract, introducing no new contract variants.

### Key Entities

- **User account**: a person's login identity — has a username (unique among active accounts), nickname, gender, phone, email, an enabled/disabled status, a password (set to a default at creation, never shown), zero or more assigned roles, and audit metadata (who/when created and last updated). Removable in a recoverable way.
- **Role**: a named grouping of permissions — has a code and a display name and may be active or inactive. A user holds zero or more roles.
- **User–role assignment**: the association linking a user to each of its roles; fully replaced whenever a user's roles are edited.
- **Audit record**: an immutable entry describing one user-management change — the acting administrator, timestamp, operation type, and before/after snapshot (password redacted). Create and edit snapshots embed the role assignments; removal snapshots intentionally do not (deliberate asymmetry — see *Clarifications*).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can locate a specific account via search and open it for editing in under 30 seconds.
- **SC-002**: 100% of create/edit/remove actions that cause an actual state change produce a corresponding audit record — no unaudited change is observed in testing; a no-op (e.g. re-removing an already-removed account) produces no audit record.
- **SC-003**: 100% of role-changing edits show both the previous and the new role set in the audit record.
- **SC-004**: The three baseline accounts cannot be removed by any path — 0 successful removals across single and batch attempts in testing.
- **SC-005**: No two active accounts ever share the same username — 0 duplicate active usernames after create and rename testing.
- **SC-006**: Account passwords never appear in any audit record or list/detail response — 0 clear-text password exposures observed.
- **SC-007**: Administrators are limited to the operations their permission level allows — 0 successful unauthorized user-management operations in testing.
- **SC-008**: For the supported back-office scale (up to ~50 concurrent administrators), the list feels instant and changes feel immediate — measured as **p95 server-side processing time** across representative requests (including the in-transaction audit write, excluding cold-start): list **< 300ms** and individual create/edit/delete **< 500ms** under that load. Front-end rendering latency is measured separately.
- **SC-009**: Every user-management operation is covered by an access-control check — 0 operations reachable without one (verified by coverage review).
- **SC-010**: The administrator interface's user actions (create, edit, remove, batch-remove) complete end-to-end against the live system — 100% succeed against the real backend (not placeholder/mock data) in acceptance testing.

## Assumptions

- The administrator-facing screens (list page with search, create/edit form, single and batch removal actions, role-selection dropdown) already exist in the admin interface; this feature supplies the backing operations and connects the existing actions to them.
- The data foundation already exists and is **not** changed by this feature: the storage for accounts, roles, role assignments, and audit records; the three baseline accounts (super-admin, admin, regular) with their roles; and the access-control grants for user-management operations.
- The default password applied to new accounts is the project's standard development default.
- "Authorized administrator" and which permission level may perform which operation are defined by the existing access-control baseline (super-admin: full management; admin: view list; regular: role lookup only).
- The supported scale is an internal back-office of up to ~50 concurrent administrators, not a high-throughput public system; no aggressive caching or batching is assumed.
- All responses honor the project's frozen response/data contract (envelope shape, identifier representation, and the fixed error-code vocabulary) defined by the project constitution; this feature introduces no new contract variants.
- Baseline-account protection identifies the three seeded accounts by their stable internal identifiers, so the protection holds even if such an account is renamed.
- Acceptance verification exercises the **real backend** (the administrator interface is pointed at the live system rather than its default mock data source) for end-to-end checks.
- Audit events are written to the existing append-only audit log (present from the foundation work); this feature writes events only and changes no schema.
- The user list returns all active (non-removed) accounts **regardless of enabled/disabled status**; filtering by status is an explicit administrator choice, not automatic.
- The `User → User01` display alias applies only to the current-user (login) info, **not** to the user-management list; the list shows actual usernames.

## Out of Scope

- Changing or resetting passwords of existing accounts (no password field in the management form); passwords are set only to the default at creation.
- Managing roles or menus themselves (this feature only manages users; the role list is read-only here, used for assignment).
- A recycle bin / restore experience for removed accounts.
- Querying or browsing the audit trail through a UI (this feature writes audit records; reading them is separate).
- Alternate sign-in flows, captcha, and sign-in lockout.
- System-wide settings.
- Status-based protection of baseline accounts — disabling a baseline account (setting it inactive) is **allowed**; only its **removal** is protected. The disabled-account login gate lives in the authentication foundation and is unchanged by this feature.
- Refined front-end handling when a chosen role becomes unavailable between form load and submit — the back end correctly rejects the submission with a business error; smarter front-end messaging or auto-refresh of the role list is a follow-up.
