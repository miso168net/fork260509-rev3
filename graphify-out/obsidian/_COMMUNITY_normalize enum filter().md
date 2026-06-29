---
type: community
cohesion: 0.22
members: 10
---

# normalize enum filter()

**Cohesion:** 0.22 - loosely connected
**Members:** 10 nodes

## Members
- [[add_menu()]] - code - rust-api/server/src/handler/system_manage.rs
- [[add_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_menu_write_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[menu_write_from_req()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_enum_filter()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_write_from_req()]] - code - rust-api/server/src/handler/system_manage.rs
- [[str_enum_to_i16()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_menu()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[value_to_opt_i64()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/normalize_enum_filter
SORT file.name ASC
```

## Connections to other communities
- 10 edges to [[_COMMUNITY_system manage.rs]]
- 2 edges to [[_COMMUNITY_get access log()]]
- 1 edge to [[_COMMUNITY_user write from req()]]

## Top bridge nodes
- [[normalize_enum_filter()]] - degree 6, connects to 3 communities
- [[menu_write_from_req()]] - degree 5, connects to 1 community
- [[role_write_from_req()]] - degree 4, connects to 1 community
- [[update_menu()]] - degree 4, connects to 1 community
- [[str_enum_to_i16()]] - degree 3, connects to 1 community