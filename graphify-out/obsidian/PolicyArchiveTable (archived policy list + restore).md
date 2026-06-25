---
source_file: "base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue"
type: "code"
community: "Community 8"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Community_8
---

# PolicyArchiveTable (archived policy list + restore)

## Connections
- [[Api.SystemManage.ArchivedPolicySearchParams DTO]] - `references` [EXTRACTED]
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - `semantically_similar_to` [INFERRED]
- [[ManagePolicyArchive view (policy recycle bin page, super-only)]] - `references` [EXTRACTED]
- [[OperationLogTable (operation audit table + payload expand + CSV export)]] - `semantically_similar_to` [INFERRED]
- [[fetchGetArchivedPolicies (policy recycle bin read)]] - `calls` [EXTRACTED]
- [[fetchRestorePolicy (restore archived policy)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Community_8