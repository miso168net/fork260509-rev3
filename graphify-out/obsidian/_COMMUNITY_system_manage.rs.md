---
type: community
cohesion: 0.02
members: 99
---

# system_manage.rs

**Cohesion:** 0.02 - loosely connected
**Members:** 99 nodes

## Members
- [[AccessLogItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[AccessLogQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[AllRoleItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[ArchivedPolicyItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[ArchivedPolicySearchQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[DateBound]] - code - rust-api/server/src/handler/system_manage.rs
- [[Endpoint]] - code - rust-api/server/src/handler/system_manage.rs
- [[ExportCsv]] - code - rust-api/server/src/handler/system_manage.rs
- [[IdReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[IdsReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[IpRuleListItem_1]] - code - rust-api/server/src/handler/system_manage.rs
- [[IpRuleSearchQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[IpRuleUpsertReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[LoginAttemptItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[LoginAttemptQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[MenuUpsertReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[OperationLogItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[OperationLogQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleButtonReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleDeleteBlock]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleEndpointsReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleHomeReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleIdQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleListItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleMenuReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleSearchQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[RoleUpsertReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[UnlockReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[UserListItem]] - code - rust-api/server/src/handler/system_manage.rs
- [[UserSearchQuery]] - code - rust-api/server/src/handler/system_manage.rs
- [[UserUpsertReq]] - code - rust-api/server/src/handler/system_manage.rs
- [[access_log_csv_row()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_date_parse_end_bound_dateonly_is_end_of_day_inclusive()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_date_parse_end_bound_rfc3339_passes_through()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_date_parse_independent_from_and_to()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_date_parse_none_empty_rfc3339_dateonly_malformed()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_entity_id_parse()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_http_status_class_parse()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_http_status_parse()]] - code - rust-api/server/src/handler/system_manage.rs
- [[audit_success_parse()]] - code - rust-api/server/src/handler/system_manage.rs
- [[batch_contains_self()]] - code - rust-api/server/src/handler/system_manage.rs
- [[batch_delete_user()]] - code - rust-api/server/src/handler/system_manage.rs
- [[cannot_delete_self_batch_contains_self_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[cannot_delete_self_empty_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[cannot_delete_self_no_self_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[cannot_delete_self_single_self_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[codes()]] - code - rust-api/server/src/handler/system_manage.rs
- [[csv_escape_field_always_quotes_and_doubles_quote()]] - code - rust-api/server/src/handler/system_manage.rs
- [[csv_escape_field_neutralizes_formula_triggers()]] - code - rust-api/server/src/handler/system_manage.rs
- [[date_ok()]] - code - rust-api/server/src/handler/system_manage.rs
- [[dt()]] - code - rust-api/server/src/handler/system_manage.rs
- [[escape_like()]] - code - rust-api/server/src/handler/system_manage.rs
- [[export_csv_serializes_camelcase()]] - code - rust-api/server/src/handler/system_manage.rs
- [[export_truncated_boundary()]] - code - rust-api/server/src/handler/system_manage.rs
- [[login_attempt_csv_row()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_menu_delete_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_menu_delete_err_db_to_internal()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_menu_delete_err_has_active_children_to_biz()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_menu_delete_err_protected_to_biz()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_role_delete_block()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_role_write_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_write_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_write_err_non_unique_to_internal()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_enum_filter_blank_to_none_and_parse()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_escape_like_metachars()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_page_defaults_and_clamp()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_str_filter_empty_to_none()]] - code - rust-api/server/src/handler/system_manage.rs
- [[operation_log_csv_row()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_export_truthy_only_true_and_one()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_duplicate_field_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_empty_none_blank_to_empty()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_invalid_direction_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[parse_sort_spec_malformed_token_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[payload_cell()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable_deleted_no_active_is_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable_live_revoke_is_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable_reused_newer_role_is_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable_reused_role_own_revoke_is_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable_role_soft_delete_is_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restorable_same_instant_is_false_errs_closed()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard_in_use_blocks()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard_ok_when_clear()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard_seeded_blocks()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard_seeded_takes_precedence_over_in_use()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard_self_role_blocks()]] - code - rust-api/server/src/handler/system_manage.rs
- [[roles_cell()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_not_self_always_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_disable_normalized_status_variants_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_disable_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_disable_unparseable_status_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_enable_normalized_status_variants_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_keep_super_enabled_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_keep_super_status_none_false()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_remove_super_and_disable_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_self_remove_super_true()]] - code - rust-api/server/src/handler/system_manage.rs
- [[system_manage.rs]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_enum_i16_to_string_or_null()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_id_2pow53_guard()]] - code - rust-api/server/src/handler/system_manage.rs
- [[wire_opt_i64_to_string_or_empty()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/system_managers
SORT file.name ASC
```

## Connections to other communities
- 35 edges to [[_COMMUNITY_get_access_log()]]
- 34 edges to [[_COMMUNITY_ok()]]
- 8 edges to [[_COMMUNITY_user_write_from_req()]]
- 8 edges to [[_COMMUNITY_add_ip_rule()]]
- 6 edges to [[_COMMUNITY_menu_write_from_req()]]
- 1 edge to [[_COMMUNITY_auth.rs]]

## Top bridge nodes
- [[system_manage.rs]] - degree 189, connects to 6 communities
- [[batch_delete_user()]] - degree 3, connects to 1 community