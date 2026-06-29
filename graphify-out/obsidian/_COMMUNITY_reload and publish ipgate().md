---
type: community
cohesion: 0.32
members: 8
---

# reload and publish ipgate()

**Cohesion:** 0.32 - loosely connected
**Members:** 8 nodes

## Members
- [[add_ip_rule()]] - code - rust-api/server/src/handler/system_manage.rs
- [[delete_ip_rule()]] - code - rust-api/server/src/handler/system_manage.rs
- [[map_ip_rule_write_err()]] - code - rust-api/server/src/handler/system_manage.rs
- [[normalize_cidr()]] - code - rust-api/server/src/handler/system_manage.rs
- [[reload_and_publish_ipgate()]] - code - rust-api/server/src/handler/system_manage.rs
- [[restore_ip_rule()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_ip_rule()]] - code - rust-api/server/src/handler/system_manage.rs
- [[validate_rule_type()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/reload_and_publish_ipgate
SORT file.name ASC
```

## Connections to other communities
- 8 edges to [[_COMMUNITY_system manage.rs]]

## Top bridge nodes
- [[reload_and_publish_ipgate()]] - degree 5, connects to 1 community
- [[add_ip_rule()]] - degree 4, connects to 1 community
- [[update_ip_rule()]] - degree 4, connects to 1 community
- [[normalize_cidr()]] - degree 3, connects to 1 community
- [[restore_ip_rule()]] - degree 3, connects to 1 community