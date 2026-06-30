---
type: community
cohesion: 0.25
members: 16
---

# mutate_in_txn()

**Cohesion:** 0.25 - loosely connected
**Members:** 16 nodes

## Members
- [[.audit_json()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[batch_soft_delete()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[delete_check()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[entitysys_menuModel]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[find_active_by_id()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[has_active_children()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[id_of()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[list_active()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[menu_crud_create_soft_delete_restore_roundtrip()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[menu_guard_delete_protected_children_and_batch_reject()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[mutate_in_txn()]] - code - rust-api/server/src/model/audit.rs
- [[reparent_check()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[restore()_1]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[soft_delete()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[update()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[would_cycle()]] - code - rust-api/server/src/model/facade/sys_menu.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/mutate_in_txn
SORT file.name ASC
```

## Connections to other communities
- 13 edges to [[_COMMUNITY_sys_menu.rs]]
- 8 edges to [[_COMMUNITY_menu_recycle_unified_list_and_restore_or]]
- 7 edges to [[_COMMUNITY_now()]]
- 5 edges to [[_COMMUNITY_sys_role.rs]]
- 2 edges to [[_COMMUNITY_sys_casbin_rule.rs]]
- 1 edge to [[_COMMUNITY_audit.rs]]
- 1 edge to [[_COMMUNITY_sys_casbin_policy_archive.rs]]
- 1 edge to [[_COMMUNITY_system_settings.rs]]

## Top bridge nodes
- [[mutate_in_txn()]] - degree 15, connects to 6 communities
- [[update()]] - degree 13, connects to 3 communities
- [[soft_delete()]] - degree 11, connects to 3 communities
- [[menu_crud_create_soft_delete_restore_roundtrip()]] - degree 7, connects to 3 communities
- [[batch_soft_delete()]] - degree 8, connects to 2 communities