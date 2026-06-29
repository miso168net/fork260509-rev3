---
type: community
cohesion: 0.83
members: 4
---

# Menu Operate Modal (add edit

**Cohesion:** 0.83 - tightly connected
**Members:** 4 nodes

## Members
- [[Api.SystemManage.MenuUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[MenuOperateModal (addeditaddChild menu form + re-parent tree)]] - code - base-web/src/views/manage/menu/modules/menu-operate-modal.vue
- [[fetchAddMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateMenu()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Menu_Operate_Modal_add_edit
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_rev3-system-manage.ts]]

## Top bridge nodes
- [[MenuOperateModal (addeditaddChild menu form + re-parent tree)]] - degree 4, connects to 1 community
- [[fetchAddMenu()]] - degree 3, connects to 1 community
- [[fetchUpdateMenu()]] - degree 3, connects to 1 community