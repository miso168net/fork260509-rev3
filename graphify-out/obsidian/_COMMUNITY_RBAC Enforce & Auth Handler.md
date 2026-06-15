---
type: community
cohesion: 0.07
members: 43
---

# RBAC Enforce & Auth Handler

**Cohesion:** 0.07 - loosely connected
**Members:** 43 nodes

## Members
- [[LoginReq]] - code - rust-api/server/src/handler/auth.rs
- [[LoginToken_1]] - code - rust-api/server/src/handler/auth.rs
- [[RefreshReq]] - code - rust-api/server/src/handler/auth.rs
- [[RequestContext]] - code - rust-api/server/src/audit_ctx.rs
- [[UserInfo_1]] - code - rust-api/server/src/handler/auth.rs
- [[audit_ctx.rs]] - code - rust-api/server/src/audit_ctx.rs
- [[audit_mw()]] - code - rust-api/server/src/audit_ctx.rs
- [[auth.rs]] - code - rust-api/server/src/handler/auth.rs
- [[best_effort_audit()]] - code - rust-api/server/src/audit_ctx.rs
- [[build_enforcer()]] - code - rust-api/server/src/auth/enforce.rs
- [[buttons_for_roles()]] - code - rust-api/server/src/auth/enforce.rs
- [[buttons_for_roles_no_policy_yields_empty()]] - code - rust-api/server/src/auth/enforce.rs
- [[buttons_for_roles_reads_only_button_rows_deduped()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce.rs]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce_decision_is_three_column_exact()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce_mw()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce_proof_super_allow_user_deny_badtoken_3333()]] - code - rust-api/server/src/auth/enforce.rs
- [[err_body()]] - code - rust-api/server/src/handler/auth.rs
- [[expect_err()]] - code - rust-api/server/src/handler/auth.rs
- [[extract_trace_id()]] - code - rust-api/server/src/audit_ctx.rs
- [[get_user_info()]] - code - rust-api/server/src/handler/auth.rs
- [[headers_with()]] - code - rust-api/server/src/audit_ctx.rs
- [[issue_tokens()]] - code - rust-api/server/src/handler/auth.rs
- [[login()]] - code - rust-api/server/src/handler/auth.rs
- [[login_inner()]] - code - rust-api/server/src/handler/auth.rs
- [[login_req_deserializes_camel_case()]] - code - rust-api/server/src/handler/auth.rs
- [[login_token_serializes_camel_case()]] - code - rust-api/server/src/handler/auth.rs
- [[oneshot_get()]] - code - rust-api/server/src/auth/enforce.rs
- [[refresh_decision()]] - code - rust-api/server/src/handler/auth.rs
- [[refresh_invalid_returns_8888_never_3333()]] - code - rust-api/server/src/handler/auth.rs
- [[refresh_req_deserializes_camel_case()]] - code - rust-api/server/src/handler/auth.rs
- [[refresh_token()]] - code - rust-api/server/src/handler/auth.rs
- [[refresh_valid_reissues_pair()]] - code - rust-api/server/src/handler/auth.rs
- [[seeded_enforcer()]] - code - rust-api/server/src/auth/enforce.rs
- [[test_jwt()]] - code - rust-api/server/src/handler/auth.rs
- [[trace_id_absent_mints_uuid()]] - code - rust-api/server/src/audit_ctx.rs
- [[trace_id_empty_whitespace_mints_uuid()]] - code - rust-api/server/src/audit_ctx.rs
- [[trace_id_honor_present_id()]] - code - rust-api/server/src/audit_ctx.rs
- [[trace_id_trim_whitespace()]] - code - rust-api/server/src/audit_ctx.rs
- [[trace_id_truncate_to_64_chars()]] - code - rust-api/server/src/audit_ctx.rs
- [[user_id_to_wire()]] - code - rust-api/server/src/handler/auth.rs
- [[user_id_to_wire_in_range_and_boundary()]] - code - rust-api/server/src/handler/auth.rs
- [[user_info_serializes_camel_case_with_string_user_id()]] - code - rust-api/server/src/handler/auth.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/RBAC_Enforce__Auth_Handler
SORT file.name ASC
```
