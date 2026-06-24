---
source_file: "base-web/src/service/api/rev3-system-manage.ts"
type: "code"
community: "rev3 Menu Service Wrappers"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3_Menu_Service_Wrappers
---

# fetchExportLoginAttempt (login attempt CSV export)

## Connections
- [[Api.SystemManage.AuditCsvExport DTO (csv + truncated)]] - `references` [EXTRACTED]
- [[LoginAttemptTable (login attempt audit table + filters + CSV export)]] - `calls` [EXTRACTED]
- [[pruneNullParams (strip unset filter params helper)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3_Menu_Service_Wrappers