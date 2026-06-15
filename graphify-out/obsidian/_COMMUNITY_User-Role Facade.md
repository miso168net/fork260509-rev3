---
type: community
cohesion: 1.00
members: 3
---

# User-Role Facade

**Cohesion:** 1.00 - tightly connected
**Members:** 3 nodes

## Members
- [[find_role_ids_by_user_id()]] - code - rust-api/server/src/model/facade/sys_user_role.rs
- [[roles_for_user()]] - code - rust-api/server/src/model/facade/sys_user_role.rs
- [[sys_user_role.rs_1]] - code - rust-api/server/src/model/facade/sys_user_role.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/User-Role_Facade
SORT file.name ASC
```
