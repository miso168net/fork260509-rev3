---
type: community
cohesion: 0.16
members: 16
---

# rev3-system-manage.ts

**Cohesion:** 0.16 - loosely connected
**Members:** 16 nodes

## Members
- [[MenuAuthModal (role x menu authorization tree + home select)]] - code - base-web/src/views/manage/role/modules/menu-auth-modal.vue
- [[Rationale DB-first casbin policy write, archived rules restorable (constitution I.74.2)]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[fetchAddIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteUser()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteUser()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetIpRuleList()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleHome()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestoreIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUnlockLogin()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleButton()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleHome()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[rev3-system-manage.ts]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/rev3-system-managets
SORT file.name ASC
```

## Connections to other communities
- 9 edges to [[_COMMUNITY_RoleOperateDrawer (role addedit form, h]]
- 6 edges to [[_COMMUNITY_ManageMenu view (unified menu list with]]
- 5 edges to [[_COMMUNITY_pruneNullParams()]]
- 4 edges to [[_COMMUNITY_EndpointAuthModal (role x API endpoint a]]
- 3 edges to [[_COMMUNITY_ButtonAuthModal (role x button authoriza]]
- 2 edges to [[_COMMUNITY_Api.SystemManage.IpConfidence seven-stat]]
- 2 edges to [[_COMMUNITY_fetchGetArchivedPolicies()]]
- 1 edge to [[_COMMUNITY_request]]

## Top bridge nodes
- [[rev3-system-manage.ts]] - degree 42, connects to 8 communities
- [[MenuAuthModal (role x menu authorization tree + home select)]] - degree 5, connects to 1 community
- [[fetchUpdateRoleButton()]] - degree 3, connects to 1 community
- [[Rationale DB-first casbin policy write, archived rules restorable (constitution I.74.2)]] - degree 3, connects to 1 community