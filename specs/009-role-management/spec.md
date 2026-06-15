# Feature Specification: Role Management（角色管理）

**Feature Branch**: `009-role-management`

**Created**: 2026-06-15

**Status**: Draft

**Input**: User description: "@docs/superpowers/009-role-management.md ultrathink"

## User Scenarios & Testing *(mandatory)*

The actors are **administrators** of the back-office. Two permission levels matter for this feature: a **super-admin** (full role management) and an **admin** (may view the role list). A **regular** account has no role-management access. Three **baseline roles** seeded at setup — the super-admin role, the admin role, and the regular role — must never be deletable.

This feature manages roles themselves as a pure catalogue: creating, viewing, editing, and removing role records. **Assigning permissions to a role** (linking menus, buttons, or endpoints to it) is a separate, later feature and is out of scope here.

### User Story 1 - View & search the role list (Priority: P1)

An administrator opens the role-management screen and sees a paginated list of active roles, each showing its display name, code, description, status, and created/updated metadata. The administrator narrows the list by typing part of a role name or role code, or by selecting an exact status.

**Why this priority**: Seeing and finding roles is the foundation of all role management; nothing else is usable without it.

**Independent Test**: Sign in as an administrator allowed to view roles, open the list, confirm roles appear with paging, then apply a filter and confirm only matching roles remain.

**Acceptance Scenarios**:

1. **Given** active roles exist, **When** the administrator opens the list, **Then** a paginated list shows each role with its name, code, description, status, and created/updated metadata.
2. **Given** the list is open, **When** the administrator types part of a role name or role code, **Then** only roles whose corresponding field contains that text are shown.
3. **Given** the list is open, **When** the administrator selects an exact status, **Then** only roles matching that exact status are shown.
4. **Given** several search fields are left blank, **When** the administrator searches, **Then** the blank fields do not constrain the results.

### User Story 2 - Create a role (Priority: P1)

An authorized administrator opens the create form, fills in the role name, role code, description, and status, and submits. A new role is created with those values.

**Why this priority**: Adding roles is a primary management action and a prerequisite for later permission assignment.

**Independent Test**: Submit the create form with valid data and confirm the new role appears in the list; submit a role code that already exists and confirm creation is refused with a clear message.

**Acceptance Scenarios**:

1. **Given** the create form with valid data, **When** the administrator submits, **Then** a new role is created with the chosen name, code, description, and status, and it appears in the list.
2. **Given** a role code already used by an active role, **When** the administrator submits, **Then** creation is refused and the administrator is told the code is taken.
3. **Given** an out-of-range status value, **When** the administrator submits, **Then** creation is refused.

### User Story 3 - Edit a role (Priority: P1)

An authorized administrator opens an existing role, changes its display name, description, or status, and submits. The role's code is fixed and cannot be changed.

**Why this priority**: Keeping role names, descriptions, and status correct is core day-to-day management.

**Independent Test**: Edit a role's name, description, and status, confirm the changes persist and the audit trail reflects them; confirm the role code is left unchanged; attempt to edit a removed role and confirm refusal.

**Acceptance Scenarios**:

1. **Given** an existing role, **When** the administrator changes its name, description, or status and submits, **Then** the changes persist and are reflected in the list.
2. **Given** an existing role, **When** the administrator submits an edit, **Then** the role's code remains exactly as it was (the code is not editable through this feature).
3. **Given** a role that has already been removed, **When** the administrator attempts to edit it, **Then** the edit is refused.
4. **Given** an out-of-range status value, **When** the administrator submits an edit, **Then** the edit is refused.

### User Story 4 - Delete roles with baseline protection (Priority: P2)

An authorized administrator removes a single role or a selected batch. The three baseline roles can never be removed, and a batch that contains any baseline role is rejected as a whole.

**Why this priority**: Removal matters but is secondary to viewing, creating, and editing; protection prevents catastrophic loss of the seeded roles that the whole access-control system depends on.

**Independent Test**: Remove a non-baseline role and confirm it leaves the active list; attempt to remove a baseline role (single and inside a batch) and confirm both are refused with nothing changed.

**Acceptance Scenarios**:

1. **Given** a non-baseline role, **When** the administrator removes it, **Then** it disappears from the active list and can no longer be edited.
2. **Given** a baseline role, **When** the administrator attempts to remove it, **Then** the removal is refused.
3. **Given** a batch selection that includes a baseline role, **When** the administrator removes the batch, **Then** the whole batch is refused and **no** role in it is removed.
4. **Given** a batch of non-baseline roles, **When** the administrator removes the batch, **Then** all of them leave the active list.
5. **Given** a role currently granted to some users, **When** the administrator removes it, **Then** the role stops counting toward those users' effective permissions, and no permission grants or user assignments are erased (removal does not cascade).

### User Story 5 - Role-based access control (Priority: P2)

Each administrator may only perform the role-management operations their permission level grants. A super-admin manages roles fully; an admin may view the list; a regular account may not access role management at all.

**Why this priority**: Prevents unauthorized changes to the role catalogue, which underpins the entire permission system; a governance guarantee distinct from the management actions themselves.

**Independent Test**: Sign in at each permission level and confirm permitted operations succeed while restricted ones are denied.

**Acceptance Scenarios**:

1. **Given** an admin-level account, **When** it views the role list, **Then** the request is allowed.
2. **Given** an admin-level account, **When** it attempts to create, edit, or remove a role, **Then** the request is denied.
3. **Given** a regular-level account, **When** it requests the role list, **Then** the request is denied.

### User Story 6 - Change audit trail (Priority: P3)

Every create, edit, and removal is recorded in an immutable audit trail that captures who acted, when, and what changed (before and after). The audit record describes only the role's own fields.

**Why this priority**: Traceability and compliance; valuable but does not block the core management flow.

**Independent Test**: Perform create/edit/remove actions and confirm each produces an audit entry with operator, timestamp, and before/after state of the role's fields.

**Acceptance Scenarios**:

1. **Given** any create, edit, or removal, **When** it completes, **Then** an audit entry records the acting administrator, the time, the operation type, and the affected role's before/after state.
2. **Given** an edit that changes a role's name, description, or status, **When** it completes, **Then** the audit entry shows both the previous and the new values.
3. **Given** any recorded role-management operation, **When** the audit entry is inspected, **Then** it captures only the role's own fields — it does not embed permission grants or user assignments.

### Edge Cases

- Removing a role that was already removed is treated as a no-op (no error, no double effect, and **no audit record** is written) so a retried batch is safe.
- If an infrastructure failure interrupts a batch removal **after** the baseline-protection check passes, roles removed before the failure stay removed and the rest are untouched; the administrator can safely retry.
- A search field left blank (or cleared) does not filter on that field.
- Creating a role whose code matches a previously-removed role is allowed (removed codes are freed for reuse).
- Submitting an out-of-range status value is refused.
- A baseline role may be renamed, re-described, or have its status changed; only its removal is blocked.
- A removed role's existing permission grants and user assignments remain in storage but are **inert** — they no longer count toward any user's effective permissions; cleaning them up is future governance scope.

## Requirements *(mandatory)*

### Functional Requirements

**List & lookup**

- **FR-001**: System MUST present administrators a paginated list of active roles, each showing the role name, role code, description, status, and who/when the role was created and last updated.
- **FR-002**: System MUST let administrators narrow the list by role name or role code via partial-text match, and by status via exact match; blank search fields MUST NOT constrain results; results MUST have a stable default ordering.

**Create**

- **FR-003**: System MUST let an authorized administrator create a new role by supplying a role name, role code, description, and status.
- **FR-004**: System MUST refuse creation when the chosen role code already belongs to another active role, and inform the administrator of the conflict.

**Edit**

- **FR-005**: System MUST let an authorized administrator edit an existing role's name, description, and status.
- **FR-006**: System MUST treat a role's code as immutable — no edit through this feature may change a role's code (the code is the stable permission identifier); the code field is presented read-only when editing.
- **FR-007**: System MUST refuse any edit targeting a role that has already been removed.

**Value validity**

- **FR-008**: System MUST refuse a create or edit with an out-of-range status value.

**Remove**

- **FR-009**: System MUST let an authorized administrator remove a single role or a selected batch of roles; removal MUST be recoverable-safe — a **soft removal** that marks the role removed (taken out of active lists, restorable in principle) rather than permanently erasing it (permanent erasure is future scope).
- **FR-010**: System MUST prevent removal of the three baseline roles (the seeded super-admin, admin, and regular roles — identified by their immutable internal ids 1/2/3) by any single or batch path; protection is keyed by id (not code), so it persists even after a baseline role is renamed, and these ids must never be reused or renumbered.
- **FR-011**: System MUST refuse an entire batch removal that includes any baseline role, leaving every role in that batch unchanged.
- **FR-012**: System MUST still allow editing (name, description, status) the baseline roles — only their removal is protected.
- **FR-013**: System MUST NOT cascade on removal — removing a role MUST NOT erase its existing permission grants or user-role assignments; a removed role simply stops counting toward any user's effective permissions (a removed role is never treated as active). Cleanup of residual grants/assignments is future governance scope.

**Access control**

- **FR-014**: System MUST restrict each role-management operation to administrators whose permission level grants it, and deny the operation to permission levels without that grant — per the Access-Control Matrix below.
- **FR-015**: System MUST ensure no role-management operation is reachable without an access-control check.

**Access-Control Matrix** (which permission level may perform each operation):

| Operation | super-admin | admin | regular |
|---|:--:|:--:|:--:|
| View / search role list | ✓ | ✓ | ✗ |
| Create / Edit / Delete / Batch-delete role | ✓ | ✗ | ✗ |

**Audit & integrity**

- **FR-016**: System MUST record every create, edit, and removal in an immutable audit trail capturing the acting administrator, the time, the operation type, and the affected role's state — **before and after** for create/edit, and **before-only** for removal (no after-state).
- **FR-017**: System MUST record a role as a **leaf entity** in the audit trail — the audit snapshot captures only the role's own fields (name, code, description, status, audit metadata) and MUST NOT embed permission grants or user-role assignments (those are not part of a role-CRUD change).
- **FR-018**: System MUST apply each change and its audit record together as one unit, so there is never a change that took effect without a matching audit record (or an audit record without the change).

**Result signalling**

- **FR-019**: System MUST report business refusals (taken role code, baseline-role removal, batch containing a baseline role, out-of-range value, edit of a removed role) via a **distinct business error code** (per the frozen data contract), clearly distinguishable from both success and from system/transport failures.
- **FR-020**: System MUST keep all responses consistent with the project's established response and data contract, introducing no new contract variants.

### Key Entities

- **Role**: a named grouping of permissions — has a code (unique among active roles and **immutable** once created), a display name, a description, an enabled/disabled status, and audit metadata (who/when created and last updated). Removable in a recoverable way. The three baseline roles seeded at setup cannot be removed.
- **Audit record**: an immutable entry describing one role-management change — the acting administrator, timestamp, operation type, and before/after snapshot of the role's own fields. As a leaf entity, the snapshot does **not** embed permission grants or user-role assignments.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can locate a specific role via search and open it for editing in under 30 seconds.
- **SC-002**: 100% of create/edit/remove actions that cause an actual state change produce a corresponding audit record — no unaudited change is observed in testing; a no-op (e.g. re-removing an already-removed role) produces no audit record.
- **SC-003**: 100% of role edits record both the previous and the new values of the changed fields in the audit trail.
- **SC-004**: The three baseline roles cannot be removed by any path — 0 successful removals across single and batch attempts in testing.
- **SC-005**: No two active roles ever share the same code — 0 duplicate active role codes after create testing.
- **SC-006**: A removed role no longer counts toward any user's effective permissions — 0 cases where a soft-removed role still grants access in testing.
- **SC-007**: Administrators are limited to the operations their permission level allows — 0 successful unauthorized role-management operations in testing.
- **SC-008**: For the supported back-office scale (up to ~50 concurrent administrators), the list feels instant and changes feel immediate — measured as **p95 server-side processing time** across representative requests (including the in-transaction audit write, excluding cold-start): list **< 300ms** and individual create/edit/delete **< 500ms** under that load. Front-end rendering latency is measured separately.
- **SC-009**: Every role-management operation is covered by an access-control check — 0 operations reachable without one (verified by coverage review).
- **SC-010**: The administrator interface's role actions (create, edit, remove, batch-remove) complete end-to-end against the live system — 100% succeed against the real backend (not placeholder/mock data) in acceptance testing.

## Assumptions

- The administrator-facing screens (list page with search, create/edit form, single and batch removal actions) already exist in the admin interface; this feature supplies the backing operations and connects the existing actions to them.
- The data foundation already exists and is **not** changed by this feature: the storage for roles and audit records; the three baseline roles (super-admin, admin, regular); and the access-control grants for role-management operations.
- "Authorized administrator" and which permission level may perform which operation are defined by the existing access-control baseline (super-admin: full role management; admin: view list; regular: no role-management access).
- The supported scale is an internal back-office of up to ~50 concurrent administrators, not a high-throughput public system; no aggressive caching or batching is assumed.
- All responses honor the project's frozen response/data contract (envelope shape, identifier representation, and the fixed error-code vocabulary) defined by the project constitution; this feature introduces no new contract variants.
- Baseline-role protection identifies the three seeded roles by their stable internal identifiers, so the protection holds even if such a role is renamed.
- Acceptance verification exercises the **real backend** (the administrator interface is pointed at the live system rather than its default mock data source) for end-to-end checks.
- Audit events are written to the existing append-only audit log (present from the foundation work); this feature writes events only and changes no schema.
- The role list returns all active (non-removed) roles **regardless of enabled/disabled status**; filtering by status is an explicit administrator choice, not automatic.
- A role's code doubles as its stable permission-subject identifier in the access-control system; this is why the code is immutable and why removal is soft (so existing grants degrade safely rather than breaking).

## Out of Scope

- **Assigning permissions to a role** — linking menus, buttons, or endpoints to a role (the permission-assignment dimension). This requires a role's permission catalogue that does not yet exist and is deferred to the Menu feature (or a dedicated assignment slice after it).
- Changing a role's code (the code is immutable).
- Cascade cleanup on removal — removing a role does not delete its permission grants or user-role assignments; residual cleanup is future governance scope.
- A recycle bin / restore experience for removed roles.
- Querying or browsing the audit trail through a UI (this feature writes audit records; reading them is separate).
- The read-only role dropdown used when assigning roles to users (already delivered by the user-management feature).
- System-wide settings.
- Status-based protection of baseline roles — disabling a baseline role (setting it inactive) is **allowed**; only its **removal** is protected.
- Governance lifecycle of roles (archive/restore/protected-policy state machine) — a later wave.
