---
type: community
cohesion: 0.33
members: 7
---

# Button Auth Modal (role x

**Cohesion:** 0.33 - loosely connected
**Members:** 7 nodes

## Members
- [[Api.SystemManage.Button DTO (code + label)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ButtonAuthModal (role x button authorization tree)]] - code - base-web/src/views/manage/role/modules/button-auth-modal.vue
- [[Rationale DB-first casbin policy write, archived rules restorable (constitution I.74.2)]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetAllButtons()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleButton()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleButton()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Button_Auth_Modal_role_x
SORT file.name ASC
```

## Connections to other communities
- 4 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 2 edges to [[_COMMUNITY_Role Operate Drawer (role add]]
- 1 edge to [[_COMMUNITY_Endpoint Auth Modal (role x]]

## Top bridge nodes
- [[fetchUpdateRoleMenu()]] - degree 3, connects to 2 communities
- [[ButtonAuthModal (role x button authorization tree)]] - degree 5, connects to 1 community
- [[fetchGetAllButtons()]] - degree 3, connects to 1 community
- [[fetchUpdateRoleButton()]] - degree 3, connects to 1 community
- [[Rationale DB-first casbin policy write, archived rules restorable (constitution I.74.2)]] - degree 3, connects to 1 community