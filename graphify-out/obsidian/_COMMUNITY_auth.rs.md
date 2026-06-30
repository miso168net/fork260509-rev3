---
type: community
cohesion: 0.11
members: 29
---

# auth.rs

**Cohesion:** 0.11 - loosely connected
**Members:** 29 nodes

## Members
- [[LoginReq]] - code - rust-api/server/src/handler/auth.rs
- [[LoginToken_1]] - code - rust-api/server/src/handler/auth.rs
- [[RefreshReq]] - code - rust-api/server/src/handler/auth.rs
- [[Success]] - code - rust-api/server/src/handler/auth.rs
- [[UserInfo_1]] - code - rust-api/server/src/handler/auth.rs
- [[auth.rs]] - code - rust-api/server/src/handler/auth.rs
- [[flushed_key()_1]] - code - rust-api/server/src/handler/auth.rs
- [[handle()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_for_test()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_or_semantics()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_per_ip_boundary()]] - code - rust-api/server/src/handler/auth.rs
- [[is_locked_out_per_user_boundary()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_cache_per_user_and_per_ip_g1()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_dim_and_reset_key_single_source()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_reset_key()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_reset_marker_per_dim_independent()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_suppressed_incr_and_throttle()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_ttl_no_refresh_and_failopen()]] - code - rust-api/server/src/handler/auth.rs
- [[login()]] - code - rust-api/server/src/handler/auth.rs
- [[login_inner()]] - code - rust-api/server/src/handler/auth.rs
- [[should_flush()_1]] - code - rust-api/server/src/handler/auth.rs
- [[should_flush_only_when_absent()]] - code - rust-api/server/src/handler/auth.rs
- [[since_floor_ts()]] - code - rust-api/server/src/handler/auth.rs
- [[since_floor_ts_lifts_on_reset()]] - code - rust-api/server/src/handler/auth.rs
- [[suppressed_and_flushed_key_derivation()]] - code - rust-api/server/src/handler/auth.rs
- [[suppressed_key()]] - code - rust-api/server/src/handler/auth.rs
- [[tripped_keys_per_dimension()]] - code - rust-api/server/src/handler/auth.rs
- [[unlock_login()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/authrs
SORT file.name ASC
```

## Connections to other communities
- 12 edges to [[_COMMUNITY_lockout_keys()]]
- 4 edges to [[_COMMUNITY_refresh_token()]]
- 1 edge to [[_COMMUNITY_enforce.rs]]
- 1 edge to [[_COMMUNITY_system_manage.rs]]
- 1 edge to [[_COMMUNITY_ok()]]

## Top bridge nodes
- [[auth.rs]] - degree 39, connects to 3 communities
- [[unlock_login()]] - degree 5, connects to 3 communities
- [[login()]] - degree 10, connects to 1 community
- [[lockout_cache_per_user_and_per_ip_g1()]] - degree 4, connects to 1 community