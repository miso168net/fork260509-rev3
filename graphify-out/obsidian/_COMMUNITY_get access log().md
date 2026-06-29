---
type: community
cohesion: 0.15
members: 28
---

# get access log()

**Cohesion:** 0.15 - loosely connected
**Members:** 28 nodes

## Members
- [[dimension_display()]] - code - rust-api/server/src/handler/system_manage.rs
- [[enrich_operator_names()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_access_log()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_all_roles()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_archived_policies()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_ip_rule_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_login_attempt()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_menu_list_v2()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_menu_tree()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_operation_log()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_role_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_role_menu()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_user_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[is_export_truncated()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_current()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_size()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_str_filter()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_audit_date()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_entity_id()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_export()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_http_status()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_http_status_class()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_success()]] - code - rust-api/server/src/handler/system_manage.rs
- [[resolve_operator_ids()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_enum()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_id()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_opt_i64()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/get_access_log
SORT file.name ASC
```

## Connections to other communities
- 28 edges to [[_COMMUNITY_system manage.rs]]
- 3 edges to [[_COMMUNITY_records to csv()]]
- 2 edges to [[_COMMUNITY_normalize enum filter()]]

## Top bridge nodes
- [[get_access_log()]] - degree 13, connects to 2 communities
- [[get_operation_log()]] - degree 12, connects to 2 communities
- [[get_login_attempt()]] - degree 11, connects to 2 communities
- [[get_role_list()]] - degree 8, connects to 2 communities
- [[get_user_list()]] - degree 8, connects to 2 communities