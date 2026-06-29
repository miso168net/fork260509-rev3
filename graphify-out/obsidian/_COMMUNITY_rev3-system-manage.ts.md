---
type: community
cohesion: 0.17
members: 15
---

# rev3-system-manage.ts

**Cohesion:** 0.17 - loosely connected
**Members:** 15 nodes

## Members
- [[Api.SystemManage.MenuListItem DTO (unified list with deleted flag)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - code - base-web/src/views/manage/menu/index.vue
- [[fetchAddIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteUser()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteUser()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetIpRuleList()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetMenuListV2()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestoreIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestoreMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUnlockLogin()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateIpRule()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[rev3-system-manage.ts]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/rev3-system-managets
SORT file.name ASC
```

## Connections to other communities
- 6 edges to [[_COMMUNITY_Manage Role view (role list]]
- 5 edges to [[_COMMUNITY_Role Operate Drawer (role add]]
- 5 edges to [[_COMMUNITY_prune Null Params()]]
- 4 edges to [[_COMMUNITY_Button Auth Modal (role x]]
- 3 edges to [[_COMMUNITY_Menu Operate Modal (add edit]]
- 3 edges to [[_COMMUNITY_fetch Get Archived Policies()]]
- 3 edges to [[_COMMUNITY_Endpoint Auth Modal (role x]]
- 2 edges to [[_COMMUNITY_Api.System Manage.Ip Confidence seven-state literal]]
- 1 edge to [[_COMMUNITY_request]]

## Top bridge nodes
- [[rev3-system-manage.ts]] - degree 42, connects to 9 communities
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - degree 7, connects to 2 communities