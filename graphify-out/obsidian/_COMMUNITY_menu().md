---
type: community
cohesion: 0.20
members: 10
---

# menu()

**Cohesion:** 0.20 - loosely connected
**Members:** 10 nodes

## Members
- [[build_management_list_tree()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[build_menu_list_node_self()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[build_menu_list_subtree()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[delete_guard_deletable_leaf_ok()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[delete_guard_has_active_children_rejected()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[delete_guard_protected_rejected()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[management_list_tree_includes_deleted_and_flag()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[menu()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[menu_enum_str()]] - code - rust-api/server/src/model/facade/sys_menu.rs
- [[menu_opt_i64_str()]] - code - rust-api/server/src/model/facade/sys_menu.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/menu
SORT file.name ASC
```

## Connections to other communities
- 10 edges to [[_COMMUNITY_sys_menu.rs]]
- 2 edges to [[_COMMUNITY_now()]]
- 1 edge to [[_COMMUNITY_menu_recycle_unified_list_and_restore_or]]
- 1 edge to [[_COMMUNITY_build_user_route_tree()]]

## Top bridge nodes
- [[menu()]] - degree 7, connects to 3 communities
- [[build_management_list_tree()]] - degree 4, connects to 2 communities
- [[management_list_tree_includes_deleted_and_flag()]] - degree 4, connects to 2 communities
- [[build_menu_list_node_self()]] - degree 4, connects to 1 community
- [[build_menu_list_subtree()]] - degree 3, connects to 1 community