---
type: community
members: 35
---

# get_access_log()

**Members:** 35 nodes

## Members
- [[csv_escape_field()]] - code - rust-api/server/src/handler/system_manage.rs
- [[dimension_display()]] - code - rust-api/server/src/handler/system_manage.rs
- [[enrich_operator_names()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_access_log()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_archived_policies()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_ip_rule_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_login_attempt()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_operation_log()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_role_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[get_user_list()]] - code - rust-api/server/src/handler/system_manage.rs
- [[invalid_sort()]] - code - rust-api/server/src/handler/system_manage.rs
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
- [[parse_sort_spec()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_err_key_is_invalid_sort()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_multi_ordered()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_trims_whitespace()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_success()]] - code - rust-api/server/src/handler/system_manage.rs
- [[push_csv_line()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv_bom_once_and_stable_header()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv_payload_json_cell_no_field_misalign()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv_zero_rows_header_only()]] - code - rust-api/server/src/handler/system_manage.rs
- [[resolve_operator_ids()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_enum()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_opt_i64()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/get_access_log
SORT file.name ASC
```

## Connections to other communities
- 35 edges to [[_COMMUNITY_system_manage.rs]]
- 17 edges to [[_COMMUNITY_ok()]]
- 1 edge to [[_COMMUNITY_menu_write_from_req()]]
- 1 edge to [[_COMMUNITY_user_write_from_req()]]

## Top bridge nodes
- [[normalize_enum_filter()]] - degree 6, connects to 4 communities
- [[get_access_log()]] - degree 15, connects to 2 communities
- [[get_operation_log()]] - degree 14, connects to 2 communities
- [[get_login_attempt()]] - degree 13, connects to 2 communities
- [[get_user_list()]] - degree 10, connects to 2 communities