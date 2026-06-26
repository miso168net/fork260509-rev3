---
type: community
cohesion: 0.67
members: 3
---

# role_write_from_req

**Cohesion:** 0.67 - moderately connected
**Members:** 3 nodes

## Members
- [[add_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_write_from_req()]] - code - rust-api/server/src/handler/system_manage.rs
- [[update_role()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/role_write_from_req
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_System Manage Handlers]]
- 1 edge to [[_COMMUNITY_Audit Log Handlers]]

## Top bridge nodes
- [[role_write_from_req()]] - degree 4, connects to 2 communities
- [[add_role()]] - degree 2, connects to 1 community
- [[update_role()]] - degree 2, connects to 1 community