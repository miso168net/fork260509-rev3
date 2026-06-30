---
type: community
cohesion: 0.15
members: 16
---

# RoleOperateDrawer (role add/edit form, h

**Cohesion:** 0.15 - loosely connected
**Members:** 16 nodes

## Members
- [[Api.SystemManage.RoleListItemRev3 DTO (honest role list item)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.RoleUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.SessionPolicy literal union]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.UserListItemRev3 DTO (honest user list item)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.UserUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ManageRole view (role list + CRUD + RBAC gating)]] - code - base-web/src/views/manage/role/index.vue
- [[Rationale number id - String(id) for backend serde String fields]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - code - base-web/src/views/manage/role/modules/role-operate-drawer.vue
- [[fetchAddRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchAddUser()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleListRev3()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetUserListRev3()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateUser()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/RoleOperateDrawer_role_add/edit_form_h
SORT file.name ASC
```

## Connections to other communities
- 9 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 1 edge to [[_COMMUNITY_ButtonAuthModal (role x button authoriza]]
- 1 edge to [[_COMMUNITY_EndpointAuthModal (role x API endpoint a]]

## Top bridge nodes
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - degree 7, connects to 3 communities
- [[fetchAddRole()]] - degree 3, connects to 1 community
- [[fetchGetRoleListRev3()]] - degree 3, connects to 1 community
- [[fetchUpdateRole()]] - degree 3, connects to 1 community
- [[fetchUpdateUser()]] - degree 3, connects to 1 community