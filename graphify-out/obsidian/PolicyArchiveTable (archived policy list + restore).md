---
source_file: "base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue"
type: "code"
community: "fetchGetArchivedPolicies()"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/fetchGetArchivedPolicies
---

# PolicyArchiveTable (archived policy list + restore)

## Connections
- [[Api.SystemManage.ArchivedPolicySearchParams DTO]] - `references` [EXTRACTED]
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - `semantically_similar_to` [INFERRED]
- [[ManagePolicyArchive view (policy recycle bin page, super-only)]] - `references` [EXTRACTED]
- [[fetchGetArchivedPolicies()]] - `calls` [EXTRACTED]
- [[fetchRestorePolicy()]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/fetchGetArchivedPolicies