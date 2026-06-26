---
source_file: "base-web/src/views/manage/role/index.vue"
type: "code"
community: "Role Authorization Modals"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Role_Authorization_Modals
---

# ManageRole view (role list + CRUD + RBAC gating)

## Connections
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - `references` [EXTRACTED]
- [[fetchBatchDeleteRole (rev3 role batch soft-delete wrapper)]] - `calls` [EXTRACTED]
- [[fetchDeleteRole (rev3 role soft-delete wrapper)]] - `calls` [EXTRACTED]
- [[fetchGetRoleListRev3 (honest role list read, roleDesc nullable)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Role_Authorization_Modals