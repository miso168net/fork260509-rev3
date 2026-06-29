---
type: community
cohesion: 0.24
members: 10
---

# prune Null Params()

**Cohesion:** 0.24 - loosely connected
**Members:** 10 nodes

## Members
- [[Api.SystemManage.AuditCsvExport DTO (csv + truncated)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogSearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Rationale prune unset params to avoid empty-string serde 400 (curl != modal)]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportAccessLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportLoginAttempt()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportOperationLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetOperationLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[pruneNullParams()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/prune_Null_Params
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 3 edges to [[_COMMUNITY_Api.System Manage.Ip Confidence seven-state literal]]
- 1 edge to [[_COMMUNITY_fetch Get Archived Policies()]]

## Top bridge nodes
- [[pruneNullParams()]] - degree 9, connects to 3 communities
- [[fetchGetOperationLog()]] - degree 4, connects to 1 community
- [[fetchExportAccessLog()]] - degree 3, connects to 1 community
- [[fetchExportLoginAttempt()]] - degree 3, connects to 1 community
- [[fetchExportOperationLog()]] - degree 3, connects to 1 community