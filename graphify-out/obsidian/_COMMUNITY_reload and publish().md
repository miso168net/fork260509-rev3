---
type: community
cohesion: 0.17
members: 13
---

# reload and publish()

**Cohesion:** 0.17 - loosely connected
**Members:** 13 nodes

## Members
- [[batch_delete_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[delete_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_endpoint_method()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_lowercase_and_mixed_to_upper()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_rejects_non_whitelisted()]] - code - rust-api/server/src/handler/system_manage.rs
- [[reload_and_publish()]] - code - rust-api/server/src/handler/system_manage.rs
- [[reload_publish_roundtrip()]] - code - rust-api/server/src/handler/system_manage.rs
- [[reload_publish_roundtrip_binds_correct_channel()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restore_policy()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_role_button()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_role_endpoints()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_role_menu()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/reload_and_publish
SORT file.name ASC
```

## Connections to other communities
- 13 edges to [[_COMMUNITY_system manage.rs]]
- 1 edge to [[_COMMUNITY_sys role.rs]]

## Top bridge nodes
- [[role_delete_guard()]] - degree 4, connects to 2 communities
- [[reload_and_publish()]] - degree 8, connects to 1 community
- [[normalize_endpoint_method()]] - degree 4, connects to 1 community
- [[batch_delete_role()]] - degree 3, connects to 1 community
- [[delete_role()]] - degree 3, connects to 1 community