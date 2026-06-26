---
type: community
cohesion: 0.67
members: 3
---

# role_delete_guard

**Cohesion:** 0.67 - moderately connected
**Members:** 3 nodes

## Members
- [[batch_delete_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[delete_role()]] - code - rust-api/server/src/handler/system_manage.rs
- [[role_delete_guard()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/role_delete_guard
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_System Manage Handlers]]
- 1 edge to [[_COMMUNITY_Role Entity Facade]]

## Top bridge nodes
- [[role_delete_guard()]] - degree 4, connects to 2 communities
- [[batch_delete_role()]] - degree 2, connects to 1 community
- [[delete_role()]] - degree 2, connects to 1 community