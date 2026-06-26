---
type: community
cohesion: 0.05
members: 55
---

# Auth & Casbin Enforce

**Cohesion:** 0.05 - loosely connected
**Members:** 55 nodes

## Members
- [[LoginReq]] - code - rust-api/server/src/handler/auth.rs
- [[LoginToken_1]] - code - rust-api/server/src/handler/auth.rs
- [[RefreshReq]] - code - rust-api/server/src/handler/auth.rs
- [[RouteExistQuery]] - code - rust-api/server/src/handler/route.rs
- [[Success]] - code - rust-api/server/src/handler/auth.rs
- [[UserInfo_1]] - code - rust-api/server/src/handler/auth.rs
- [[auth.rs]] - code - rust-api/server/src/handler/auth.rs
- [[auth_buttons_for_roles_filters_only_button_acts()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_endpoint_pairs_for_role_filters_only_method_acts()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_enforce_role_union_helper()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_enforce_seam_super_allow_user_deny()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_is_endpoint_method_recognizes_http_methods_only()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_is_subset_of_no_escalation_check()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_is_super_detects_super_role_code()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_menu_routes_for_roles_filters_only_menu_acts()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_reload_preserving_failure_keeps_old_policy()]] - code - rust-api/server/src/auth/enforce.rs
- [[auth_reload_preserving_success_swaps_policy()]] - code - rust-api/server/src/auth/enforce.rs
- [[bearer()]] - code - rust-api/server/src/auth/enforce.rs
- [[button_codes_for_role()]] - code - rust-api/server/src/auth/enforce.rs
- [[buttons_for_roles()]] - code - rust-api/server/src/auth/enforce.rs
- [[denylist_gate()]] - code - rust-api/server/src/auth/enforce.rs
- [[endpoint_pairs_for_role()]] - code - rust-api/server/src/auth/enforce.rs
- [[endpoint_pairs_for_roles()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce.rs]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce_mw()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce_role_path_method()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforcer_with_super_delete()]] - code - rust-api/server/src/auth/enforce.rs
- [[flatten_names_value()]] - code - rust-api/server/src/handler/route.rs
- [[get_constant_routes()]] - code - rust-api/server/src/handler/route.rs
- [[get_user_info()]] - code - rust-api/server/src/handler/auth.rs
- [[get_user_routes()]] - code - rust-api/server/src/handler/route.rs
- [[init_enforcer()]] - code - rust-api/server/src/auth/enforce.rs
- [[is_current()]] - code - rust-api/server/src/auth/enforce.rs
- [[is_endpoint_method()]] - code - rust-api/server/src/auth/enforce.rs
- [[is_locked_out()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_for_test()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_or_semantics()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_per_ip_boundary()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_per_user_boundary()]] - code - rust-api/server/src/handler/auth.rs
- [[is_route_exist()]] - code - rust-api/server/src/handler/route.rs
- [[is_subset_of()]] - code - rust-api/server/src/auth/enforce.rs
- [[is_super()]] - code - rust-api/server/src/auth/enforce.rs
- [[issue_rotated_pair()]] - code - rust-api/server/src/handler/auth.rs
- [[live_get_user_routes_per_role_filtering()]] - code - rust-api/server/src/handler/route.rs
- [[login()]] - code - rust-api/server/src/handler/auth.rs
- [[login_inner()]] - code - rust-api/server/src/handler/auth.rs
- [[menu_routes_for_roles()]] - code - rust-api/server/src/auth/enforce.rs
- [[refresh_token()]] - code - rust-api/server/src/handler/auth.rs
- [[reload_enforcer_preserving()]] - code - rust-api/server/src/auth/enforce.rs
- [[require_policy()]] - code - rust-api/server/src/auth/enforce.rs
- [[revoke_chain_and_logout()]] - code - rust-api/server/src/handler/auth.rs
- [[revoke_user_sessions()]] - code - rust-api/server/src/auth/enforce.rs
- [[rotate_locked_or_revoke()]] - code - rust-api/server/src/handler/auth.rs
- [[route.rs]] - code - rust-api/server/src/handler/route.rs
- [[user_visible_route_names()]] - code - rust-api/server/src/handler/route.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Auth__Casbin_Enforce
SORT file.name ASC
```
