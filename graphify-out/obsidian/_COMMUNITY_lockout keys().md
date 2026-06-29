---
type: community
cohesion: 0.43
members: 7
---

# lockout keys()

**Cohesion:** 0.43 - moderately connected
**Members:** 7 nodes

## Members
- [[ip_key()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_dim_key()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_keys()]] - code - rust-api/server/src/handler/auth.rs
- [[lockout_keys_ipv4_and_ipv6()]] - code - rust-api/server/src/handler/auth.rs
- [[tripped_keys()]] - code - rust-api/server/src/handler/auth.rs
- [[tripped_keys_match_lockout_keys_g1()]] - code - rust-api/server/src/handler/auth.rs
- [[user_key()]] - code - rust-api/server/src/handler/auth.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/lockout_keys
SORT file.name ASC
```

## Connections to other communities
- 12 edges to [[_COMMUNITY_auth.rs]]

## Top bridge nodes
- [[lockout_keys()]] - degree 7, connects to 1 community
- [[tripped_keys()]] - degree 6, connects to 1 community
- [[ip_key()]] - degree 4, connects to 1 community
- [[lockout_dim_key()]] - degree 4, connects to 1 community
- [[user_key()]] - degree 4, connects to 1 community