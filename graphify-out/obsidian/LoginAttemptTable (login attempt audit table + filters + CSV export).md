---
source_file: "base-web/src/views/manage/audit/modules/login-attempt-table.vue"
type: "code"
community: "rev3 Menu Service Wrappers"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/rev3_Menu_Service_Wrappers
---

# LoginAttemptTable (login attempt audit table + filters + CSV export)

## Connections
- [[Api.SystemManage.LoginAttemptSearchParams DTO]] - `references` [EXTRACTED]
- [[ManageAudit view (super-only audit center, 3-tab page)]] - `references` [EXTRACTED]
- [[confidenceOptions (7-state ip_confidence NSelect options)]] - `references` [EXTRACTED]
- [[fetchExportLoginAttempt (login attempt CSV export)]] - `calls` [EXTRACTED]
- [[fetchGetLoginAttempt (login attempt audit read)]] - `calls` [EXTRACTED]
- [[renderConfidenceTag (7-state ip_confidence colored NTag)]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/rev3_Menu_Service_Wrappers