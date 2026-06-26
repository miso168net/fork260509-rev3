---
type: community
cohesion: 0.15
members: 27
---

# Audit Log Handlers

**Cohesion:** 0.15 - loosely connected
**Members:** 27 nodes

## Members
- [[dimension_display()]] - code - rust-api/server/src/handler/system_manage.rs
- [[enrich_operator_names()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_access_log()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_all_roles()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_archived_policies()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_login_attempt()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_menu_list_v2()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_menu_tree()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_operation_log()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_role_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_role_menu()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_user_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[is_export_truncated()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_current()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_enum_filter()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_size()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_str_filter()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_audit_date()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_entity_id()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_export()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_http_status()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_http_status_class()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_success()]] - code - rust-api/server/src/handler/system_manage.rs
- [[resolve_operator_ids()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_enum()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_id()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_opt_i64()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Audit_Log_Handlers
SORT file.name ASC
```

## Connections to other communities
- 27 edges to [[_COMMUNITY_System Manage Handlers]]
- 3 edges to [[_COMMUNITY_records_to_csv]]
- 1 edge to [[_COMMUNITY_role_write_from_req]]
- 1 edge to [[_COMMUNITY_menu_write_from_req]]
- 1 edge to [[_COMMUNITY_user_write_from_req]]

## Top bridge nodes
- [[normalize_enum_filter()]] - degree 6, connects to 4 communities
- [[get_access_log()]] - degree 13, connects to 2 communities
- [[get_operation_log()]] - degree 12, connects to 2 communities
- [[get_login_attempt()]] - degree 11, connects to 2 communities
- [[wire_id()]] - degree 11, connects to 1 community