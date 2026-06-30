---
type: community
cohesion: 0.32
members: 8
---

# pruneNullParams()

**Cohesion:** 0.32 - loosely connected
**Members:** 8 nodes

## Members
- [[Api.SystemManage.AuditCsvExport DTO (csv + truncated)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptSearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Rationale prune unset params to avoid empty-string serde 400 (curl != modal)]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportAccessLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportLoginAttempt()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportOperationLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetLoginAttempt()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[pruneNullParams()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/pruneNullParams
SORT file.name ASC
```

## Connections to other communities
- 5 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 3 edges to [[_COMMUNITY_Api.SystemManage.IpConfidence seven-stat]]
- 1 edge to [[_COMMUNITY_fetchGetArchivedPolicies()]]

## Top bridge nodes
- [[pruneNullParams()]] - degree 9, connects to 3 communities
- [[fetchGetLoginAttempt()]] - degree 4, connects to 2 communities
- [[fetchExportAccessLog()]] - degree 3, connects to 1 community
- [[fetchExportLoginAttempt()]] - degree 3, connects to 1 community
- [[fetchExportOperationLog()]] - degree 3, connects to 1 community