---
type: community
cohesion: 0.25
members: 9
---

# Role Operate Drawer (role add

**Cohesion:** 0.25 - loosely connected
**Members:** 9 nodes

## Members
- [[Api.SystemManage.RoleUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[MenuAuthModal (role x menu authorization tree + home select)]] - code - base-web/src/views/manage/role/modules/menu-auth-modal.vue
- [[Rationale number id - String(id) for backend serde String fields]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - code - base-web/src/views/manage/role/modules/role-operate-drawer.vue
- [[fetchAddRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleHome()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleHome()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Role_Operate_Drawer_role_add
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 3 edges to [[_COMMUNITY_Manage Role view (role list]]
- 2 edges to [[_COMMUNITY_Button Auth Modal (role x]]
- 1 edge to [[_COMMUNITY_Endpoint Auth Modal (role x]]

## Top bridge nodes
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - degree 7, connects to 3 communities
- [[MenuAuthModal (role x menu authorization tree + home select)]] - degree 5, connects to 1 community
- [[fetchAddRole()]] - degree 3, connects to 1 community
- [[fetchUpdateRole()]] - degree 3, connects to 1 community
- [[fetchGetRoleHome()]] - degree 2, connects to 1 community