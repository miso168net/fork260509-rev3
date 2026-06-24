---
type: community
members: 32
---

# rev3 User/Role Service Wrappers

**Members:** 32 nodes

## Members
- [[Api.SystemManage.Button DTO (code + label)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.Endpoint DTO (path + method)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.RoleListItemRev3 DTO (honest role list item)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.RoleUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.SessionPolicy literal union]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.UserListItemRev3 DTO (honest user list item)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.UserUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ButtonAuthModal (role x button authorization tree)]] - code - base-web/src/views/manage/role/modules/button-auth-modal.vue
- [[EndpointAuthModal (role x API endpoint authorization tree)]] - code - base-web/src/views/manage/role/modules/endpoint-auth-modal.vue
- [[ManageRole view (role list + CRUD + RBAC gating)]] - code - base-web/src/views/manage/role/index.vue
- [[MenuAuthModal (role x menu authorization tree + home select)]] - code - base-web/src/views/manage/role/modules/menu-auth-modal.vue
- [[Rationale DB-first casbin policy write, archived rules restorable (constitution I.74.2)]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[Rationale number id - String(id) for backend serde String fields]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - code - base-web/src/views/manage/role/modules/role-operate-drawer.vue
- [[fetchAddRole (rev3 role write wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchAddUser (rev3 user write wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteRole (rev3 role batch soft-delete wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteRole (rev3 role soft-delete wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetAllButtons (all authorizable buttons registry)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetAllEndpoints (all authorizable API endpoints registry)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleButton (role's authorized button codes)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleEndpoints (role's authorized endpoints)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleHome (role login landing route_name)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleListRev3 (honest role list read, roleDesc nullable)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleMenu (role's authorized menu ids)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetUserListRev3 (honest user list read, nullable fields)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRole (rev3 role write wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleButton (DB-first casbin button policy write)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleEndpoints (DB-first casbin endpoint policy write)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleHome (role login landing write)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleMenu (DB-first casbin policy write)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateUser (rev3 user write wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/rev3_User/Role_Service_Wrappers
SORT file.name ASC
```
