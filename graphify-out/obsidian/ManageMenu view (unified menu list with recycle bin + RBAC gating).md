---
source_file: "base-web/src/views/manage/menu/index.vue"
type: "code"
community: "rev3 Menu Service Wrappers"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3_Menu_Service_Wrappers
---

# ManageMenu view (unified menu list with recycle bin + RBAC gating)

## Connections
- [[Api.SystemManage.MenuListItem DTO (unified list with deleted flag)]] - `references` [EXTRACTED]
- [[MenuOperateModal (addeditaddChild menu form + re-parent tree)]] - `references` [EXTRACTED]
- [[PolicyArchiveTable (archived policy list + restore)]] - `semantically_similar_to` [INFERRED]
- [[fetchBatchDeleteMenu (rev3 menu batch soft-delete wrapper)]] - `calls` [EXTRACTED]
- [[fetchDeleteMenu (rev3 menu soft-delete wrapper)]] - `calls` [EXTRACTED]
- [[fetchGetMenuListV2 (rev3 unified menu list, bare array tree)]] - `calls` [EXTRACTED]
- [[fetchRestoreMenu (rev3 menu restore wrapper)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3_Menu_Service_Wrappers