---
type: community
cohesion: 0.32
members: 8
---

# user_write_from_req()

**Cohesion:** 0.32 - loosely connected
**Members:** 8 nodes

## Members
- [[add_user()]] - code - rust-api/server/src/handler/system_manage.rs
- [[req_with_policy()]] - code - rust-api/server/src/handler/system_manage.rs
- [[self_lock_violation()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_user()]] - code - rust-api/server/src/handler/system_manage.rs
- [[user_write_from_req()]] - code - rust-api/server/src/handler/system_manage.rs
- [[user_write_from_req_accepts_valid_session_policy()]] - code - rust-api/server/src/handler/system_manage.rs
- [[user_write_from_req_none_session_policy_is_none()]] - code - rust-api/server/src/handler/system_manage.rs
- [[user_write_from_req_rejects_invalid_session_policy()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/user_write_from_req
SORT file.name ASC
```

## Connections to other communities
- 8 edges to [[_COMMUNITY_system_manage.rs]]
- 2 edges to [[_COMMUNITY_ok()]]
- 1 edge to [[_COMMUNITY_get_access_log()]]

## Top bridge nodes
- [[user_write_from_req()]] - degree 7, connects to 2 communities
- [[update_user()]] - degree 4, connects to 2 communities
- [[add_user()]] - degree 3, connects to 2 communities
- [[req_with_policy()]] - degree 4, connects to 1 community
- [[user_write_from_req_accepts_valid_session_policy()]] - degree 3, connects to 1 community