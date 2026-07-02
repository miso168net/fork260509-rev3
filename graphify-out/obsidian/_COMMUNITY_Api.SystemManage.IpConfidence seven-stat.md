---
type: community
members: 13
---

# Api.SystemManage.IpConfidence seven-stat

**Members:** 13 nodes

## Members
- [[Api.SystemManage.AccessLogItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AccessLogList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AccessLogSearchParams DTO (incl httpStatusClass)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.IpConfidence seven-state literal union]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogSearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[confidenceOptions (7-state ip_confidence NSelect options)]] - code - base-web/src/views/manage/audit/modules/ip-confidence-options.ts
- [[fetchGetAccessLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetOperationLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[renderConfidenceTag (7-state ip_confidence colored NTag)]] - code - base-web/src/views/manage/audit/modules/ip-confidence-tag.tsx

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/ApiSystemManageIpConfidence_seven-stat
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_pruneNullParams()]]
- 2 edges to [[_COMMUNITY_rev3-system-manage.ts]]

## Top bridge nodes
- [[fetchGetOperationLog()]] - degree 4, connects to 2 communities
- [[fetchGetAccessLog()]] - degree 4, connects to 2 communities
- [[Api.SystemManage.LoginAttemptList (PageRes wrapper)]] - degree 2, connects to 1 community