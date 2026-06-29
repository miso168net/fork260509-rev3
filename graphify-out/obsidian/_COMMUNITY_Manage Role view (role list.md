---
type: community
cohesion: 0.18
members: 11
---

# Manage Role view (role list

**Cohesion:** 0.18 - loosely connected
**Members:** 11 nodes

## Members
- [[Api.SystemManage.RoleListItemRev3 DTO (honest role list item)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.SessionPolicy literal union]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.UserListItemRev3 DTO (honest user list item)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.UserUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ManageRole view (role list + CRUD + RBAC gating)]] - code - base-web/src/views/manage/role/index.vue
- [[fetchAddUser()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteRole()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleListRev3()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetUserListRev3()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateUser()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Manage_Role_view_role_list
SORT file.name ASC
```

## Connections to other communities
- 6 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 3 edges to [[_COMMUNITY_Role Operate Drawer (role add]]

## Top bridge nodes
- [[fetchUpdateUser()]] - degree 3, connects to 2 communities
- [[ManageRole view (role list + CRUD + RBAC gating)]] - degree 4, connects to 1 community
- [[fetchGetRoleListRev3()]] - degree 3, connects to 1 community
- [[Api.SystemManage.RoleListItemRev3 DTO (honest role list item)]] - degree 3, connects to 1 community
- [[fetchAddUser()]] - degree 2, connects to 1 community