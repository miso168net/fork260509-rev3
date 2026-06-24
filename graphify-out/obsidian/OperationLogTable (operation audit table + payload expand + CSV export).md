---
source_file: "base-web/src/views/manage/audit/modules/operation-log-table.vue"
type: "code"
community: "rev3 Menu Service Wrappers"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3_Menu_Service_Wrappers
---

# OperationLogTable (operation audit table + payload expand + CSV export)

## Connections
- [[Api.SystemManage.OperationLogSearchParams DTO]] - `references` [EXTRACTED]
- [[ManageAudit view (super-only audit center, 3-tab page)]] - `references` [EXTRACTED]
- [[PolicyArchiveTable (archived policy list + restore)]] - `semantically_similar_to` [INFERRED]
- [[confidenceOptions (7-state ip_confidence NSelect options)]] - `references` [EXTRACTED]
- [[fetchExportOperationLog (operation log CSV export)]] - `calls` [EXTRACTED]
- [[fetchGetOperationLog (operation audit read)]] - `calls` [EXTRACTED]
- [[renderConfidenceTag (7-state ip_confidence colored NTag)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3_Menu_Service_Wrappers