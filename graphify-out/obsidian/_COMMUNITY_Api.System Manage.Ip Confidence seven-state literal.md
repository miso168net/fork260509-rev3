---
type: community
cohesion: 0.20
members: 11
---

# Api.System Manage.Ip Confidence seven-state literal

**Cohesion:** 0.20 - loosely connected
**Members:** 11 nodes

## Members
- [[Api.SystemManage.AccessLogItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AccessLogList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AccessLogSearchParams DTO (incl httpStatusClass)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.IpConfidence seven-state literal union]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptSearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[confidenceOptions (7-state ip_confidence NSelect options)]] - code - base-web/src/views/manage/audit/modules/ip-confidence-options.ts
- [[fetchGetAccessLog()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetLoginAttempt()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[renderConfidenceTag (7-state ip_confidence colored NTag)]] - code - base-web/src/views/manage/audit/modules/ip-confidence-tag.tsx

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/ApiSystem_ManageIp_Confidence_seven-state_literal
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_prune Null Params()]]
- 2 edges to [[_COMMUNITY_rev3-system-manage.ts]]

## Top bridge nodes
- [[fetchGetAccessLog()]] - degree 4, connects to 2 communities
- [[fetchGetLoginAttempt()]] - degree 4, connects to 2 communities
- [[Api.SystemManage.IpConfidence seven-state literal union]] - degree 6, connects to 1 community