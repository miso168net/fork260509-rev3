---
source_file: "base-web/src/views/manage/role/modules/endpoint-auth-modal.vue"
type: "code"
community: "Role Authorization Modals"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Role_Authorization_Modals
---

# EndpointAuthModal (role x API endpoint authorization tree)

## Connections
- [[Api.SystemManage.Endpoint DTO (path + method)]] - `references` [EXTRACTED]
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - `references` [EXTRACTED]
- [[fetchGetAllEndpoints (all authorizable API endpoints registry)]] - `calls` [EXTRACTED]
- [[fetchGetRoleEndpoints (role's authorized endpoints)]] - `calls` [EXTRACTED]
- [[fetchUpdateRoleEndpoints (DB-first casbin endpoint policy write)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Role_Authorization_Modals