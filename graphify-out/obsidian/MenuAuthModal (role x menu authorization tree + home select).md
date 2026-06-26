---
source_file: "base-web/src/views/manage/role/modules/menu-auth-modal.vue"
type: "code"
community: "Role Authorization Modals"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Role_Authorization_Modals
---

# MenuAuthModal (role x menu authorization tree + home select)

## Connections
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - `references` [EXTRACTED]
- [[fetchGetRoleHome (role login landing route_name)]] - `calls` [EXTRACTED]
- [[fetchGetRoleMenu (role's authorized menu ids)]] - `calls` [EXTRACTED]
- [[fetchUpdateRoleHome (role login landing write)]] - `calls` [EXTRACTED]
- [[fetchUpdateRoleMenu (DB-first casbin policy write)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Role_Authorization_Modals