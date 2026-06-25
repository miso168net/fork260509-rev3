---
source_file: "base-web/src/views/manage/role/modules/button-auth-modal.vue"
type: "code"
community: "Community 12"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Community_12
---

# ButtonAuthModal (role x button authorization tree)

## Connections
- [[Api.SystemManage.Button DTO (code + label)]] - `references` [EXTRACTED]
- [[RoleOperateDrawer (role addedit form, hosts 3 auth modals)]] - `references` [EXTRACTED]
- [[fetchGetAllButtons (all authorizable buttons registry)]] - `calls` [EXTRACTED]
- [[fetchGetRoleButton (role's authorized button codes)]] - `calls` [EXTRACTED]
- [[fetchUpdateRoleButton (DB-first casbin button policy write)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Community_12