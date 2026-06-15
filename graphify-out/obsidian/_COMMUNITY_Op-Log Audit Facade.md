---
type: community
cohesion: 0.60
members: 6
---

# Op-Log Audit Facade

**Cohesion:** 0.60 - moderately connected
**Members:** 6 nodes

## Members
- [[audit_active_model()]] - code - rust-api/server/src/model/facade/sys_operation_log.rs
- [[audit_active_model_builds_insert_and_omits_operator_ip_when_no_operator()]] - code - rust-api/server/src/model/facade/sys_operation_log.rs
- [[audit_active_model_writes_operator_ip_inet_when_present()]] - code - rust-api/server/src/model/facade/sys_operation_log.rs
- [[event_with_ip()]] - code - rust-api/server/src/model/facade/sys_operation_log.rs
- [[sys_operation_log.rs_1]] - code - rust-api/server/src/model/facade/sys_operation_log.rs
- [[write_in_txn()]] - code - rust-api/server/src/model/facade/sys_operation_log.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Op-Log_Audit_Facade
SORT file.name ASC
```
