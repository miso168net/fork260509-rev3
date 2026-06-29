---
type: community
cohesion: 0.33
members: 7
---

# fetch Get Archived Policies()

**Cohesion:** 0.33 - loosely connected
**Members:** 7 nodes

## Members
- [[Api.SystemManage.ArchivedPolicy DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.ArchivedPolicyList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.ArchivedPolicySearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ManagePolicyArchive view (policy recycle bin page, super-only)]] - code - base-web/src/views/manage/policy-archive/index.vue
- [[PolicyArchiveTable (archived policy list + restore)]] - code - base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue
- [[fetchGetArchivedPolicies()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestorePolicy()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/fetch_Get_Archived_Policies
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 1 edge to [[_COMMUNITY_prune Null Params()]]

## Top bridge nodes
- [[fetchGetArchivedPolicies()]] - degree 5, connects to 2 communities
- [[PolicyArchiveTable (archived policy list + restore)]] - degree 5, connects to 1 community
- [[fetchRestorePolicy()]] - degree 2, connects to 1 community