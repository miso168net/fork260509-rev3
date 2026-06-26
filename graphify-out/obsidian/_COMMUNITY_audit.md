---
type: community
cohesion: 0.23
members: 12
---

# audit

**Cohesion:** 0.23 - loosely connected
**Members:** 12 nodes

## Members
- [[.as_str()_1]] - code - rust-api/server/src/model/audit.rs
- [[AuditEvent]] - code - rust-api/server/src/model/audit.rs
- [[AuditMeta]] - code - rust-api/server/src/model/audit.rs
- [[AuditOperation]] - code - rust-api/server/src/model/audit.rs
- [[AuditOperator]] - code - rust-api/server/src/model/audit.rs
- [[AuditSerialize]] - code - rust-api/server/src/model/audit.rs
- [[audit.rs]] - code - rust-api/server/src/model/audit.rs
- [[with_roles()]] - code - rust-api/server/src/model/audit.rs
- [[with_roles_empty_yields_empty_array_not_null()]] - code - rust-api/server/src/model/audit.rs
- [[with_roles_non_object_passthrough()]] - code - rust-api/server/src/model/audit.rs
- [[with_roles_preserves_existing_keys()]] - code - rust-api/server/src/model/audit.rs
- [[with_roles_sorts_role_codes()]] - code - rust-api/server/src/model/audit.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/audit
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_mutate_in_txn]]

## Top bridge nodes
- [[audit.rs]] - degree 11, connects to 1 community