---
source_file: "base-web/src/views/manage/menu/index.vue"
type: "code"
community: "rev3-system-manage.ts"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3-system-managets
---

# ManageMenu view (unified menu list with recycle bin + RBAC gating)

## Connections
- [[Api.SystemManage.MenuListItem DTO (unified list with deleted flag)]] - `references` [EXTRACTED]
- [[MenuOperateModal (addeditaddChild menu form + re-parent tree)]] - `references` [EXTRACTED]
- [[PolicyArchiveTable (archived policy list + restore)]] - `semantically_similar_to` [INFERRED]
- [[fetchBatchDeleteMenu()]] - `calls` [EXTRACTED]
- [[fetchDeleteMenu()]] - `calls` [EXTRACTED]
- [[fetchGetMenuListV2()]] - `calls` [EXTRACTED]
- [[fetchRestoreMenu()]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3-system-managets