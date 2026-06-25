---
source_file: "base-web/src/views/manage/audit/modules/access-log-table.vue"
type: "code"
community: "Community 8"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Community_8
---

# AccessLogTable (API access audit table + filters + CSV export)

## Connections
- [[Api.SystemManage.AccessLogSearchParams DTO (incl httpStatusClass)]] - `references` [EXTRACTED]
- [[ManageAudit view (super-only audit center, 3-tab page)]] - `references` [EXTRACTED]
- [[confidenceOptions (7-state ip_confidence NSelect options)]] - `references` [EXTRACTED]
- [[fetchExportAccessLog (access log CSV export)]] - `calls` [EXTRACTED]
- [[fetchGetAccessLog (API access audit read)]] - `calls` [EXTRACTED]
- [[renderConfidenceTag (7-state ip_confidence colored NTag)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Community_8