---
type: community
cohesion: 0.07
members: 38
---

# Menu & Policy Admin UI

**Cohesion:** 0.07 - loosely connected
**Members:** 38 nodes

## Members
- [[Api.SystemManage.AccessLogItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AccessLogList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AccessLogSearchParams DTO (incl httpStatusClass)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.ArchivedPolicy DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.ArchivedPolicyList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.ArchivedPolicySearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.AuditCsvExport DTO (csv + truncated)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.IpConfidence seven-state literal union]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.LoginAttemptSearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.MenuListItem DTO (unified list with deleted flag)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.MenuUpsertModel DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogItem DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogList (PageRes wrapper)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[Api.SystemManage.OperationLogSearchParams DTO]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[ManageMenu view (unified menu list with recycle bin + RBAC gating)]] - code - base-web/src/views/manage/menu/index.vue
- [[ManagePolicyArchive view (policy recycle bin page, super-only)]] - code - base-web/src/views/manage/policy-archive/index.vue
- [[MenuOperateModal (addeditaddChild menu form + re-parent tree)]] - code - base-web/src/views/manage/menu/modules/menu-operate-modal.vue
- [[PolicyArchiveTable (archived policy list + restore)]] - code - base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue
- [[Rationale prune unset params to avoid empty-string serde 400 (curl != modal)]] - rationale - base-web/src/service/api/rev3-system-manage.ts
- [[confidenceOptions (7-state ip_confidence NSelect options)]] - code - base-web/src/views/manage/audit/modules/ip-confidence-options.ts
- [[fetchAddMenu (rev3 menu write wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchBatchDeleteMenu (rev3 menu batch soft-delete wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchDeleteMenu (rev3 menu soft-delete wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportAccessLog (access log CSV export)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportLoginAttempt (login attempt CSV export)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchExportOperationLog (operation log CSV export)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetAccessLog (API access audit read)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetArchivedPolicies (policy recycle bin read)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetLoginAttempt (login attempt audit read)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetMenuListV2 (rev3 unified menu list, bare array tree)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetOperationLog (operation audit read)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestoreMenu (rev3 menu restore wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchRestorePolicy (restore archived policy)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateMenu (rev3 menu write+reparent wrapper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[pruneNullParams (strip unset filter params helper)]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[renderConfidenceTag (7-state ip_confidence colored NTag)]] - code - base-web/src/views/manage/audit/modules/ip-confidence-tag.tsx

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Menu__Policy_Admin_UI
SORT file.name ASC
```
