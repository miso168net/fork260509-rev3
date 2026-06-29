---
type: community
cohesion: 0.32
members: 8
---

# refresh token()

**Cohesion:** 0.32 - loosely connected
**Members:** 8 nodes

## Members
- [[bearer()]] - code - rust-api/server/src/auth/enforce.rs
- [[denylist_gate()]] - code - rust-api/server/src/auth/enforce.rs
- [[enforce_mw()]] - code - rust-api/server/src/auth/enforce.rs
- [[is_current()]] - code - rust-api/server/src/auth/enforce.rs
- [[issue_rotated_pair()]] - code - rust-api/server/src/handler/auth.rs
- [[refresh_token()]] - code - rust-api/server/src/handler/auth.rs
- [[revoke_chain_and_logout()]] - code - rust-api/server/src/handler/auth.rs
- [[rotate_locked_or_revoke()]] - code - rust-api/server/src/handler/auth.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/refresh_token
SORT file.name ASC
```

## Connections to other communities
- 4 edges to [[_COMMUNITY_enforce.rs]]
- 4 edges to [[_COMMUNITY_auth.rs]]

## Top bridge nodes
- [[refresh_token()]] - degree 5, connects to 1 community
- [[enforce_mw()]] - degree 4, connects to 1 community
- [[rotate_locked_or_revoke()]] - degree 4, connects to 1 community
- [[denylist_gate()]] - degree 3, connects to 1 community
- [[is_current()]] - degree 3, connects to 1 community