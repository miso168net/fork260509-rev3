---
source_file: "base-web/src/service/api/rev3-system-manage.ts"
type: "code"
community: "rev3 Menu Service Wrappers"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3_Menu_Service_Wrappers
---

# fetchGetArchivedPolicies (policy recycle bin read)

## Connections
- [[Api.SystemManage.ArchivedPolicyList (PageRes wrapper)]] - `references` [EXTRACTED]
- [[Api.SystemManage.ArchivedPolicySearchParams DTO]] - `references` [EXTRACTED]
- [[PolicyArchiveTable (archived policy list + restore)]] - `calls` [EXTRACTED]
- [[pruneNullParams (strip unset filter params helper)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3_Menu_Service_Wrappers