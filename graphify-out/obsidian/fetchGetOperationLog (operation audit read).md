---
source_file: "base-web/src/service/api/rev3-system-manage.ts"
type: "code"
community: "rev3 Menu Service Wrappers"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3_Menu_Service_Wrappers
---

# fetchGetOperationLog (operation audit read)

## Connections
- [[Api.SystemManage.OperationLogList (PageRes wrapper)]] - `references` [EXTRACTED]
- [[Api.SystemManage.OperationLogSearchParams DTO]] - `references` [EXTRACTED]
- [[OperationLogTable (operation audit table + payload expand + CSV export)]] - `calls` [EXTRACTED]
- [[pruneNullParams (strip unset filter params helper)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3_Menu_Service_Wrappers