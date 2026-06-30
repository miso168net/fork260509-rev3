---
type: community
cohesion: 0.27
members: 10
---

# ManageMenu view (unified menu list with 

**Cohesion:** 0.27 - loosely connected
**Members:** 10 nodes

## Members
- [[Api.SystemManage.MenuListItem DTO (unified list with deleted flag)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.MenuUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - code - base-web/src/views/manage/menu/index.vue
- [[MenuOperateModal (addeditaddChild menu form + re-parent tree)]] - code - base-web/src/views/manage/menu/modules/menu-operate-modal.vue
- [[fetchAddMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetMenuListV2()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestoreMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/ManageMenu_view_unified_menu_list_with_
SORT file.name ASC
```

## Connections to other communities
- 6 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 1 edge to [[_COMMUNITY_fetchGetArchivedPolicies()]]

## Top bridge nodes
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - degree 7, connects to 1 community
- [[fetchAddMenu()]] - degree 3, connects to 1 community
- [[fetchGetMenuListV2()]] - degree 3, connects to 1 community
- [[fetchUpdateMenu()]] - degree 3, connects to 1 community
- [[fetchBatchDeleteMenu()]] - degree 2, connects to 1 community