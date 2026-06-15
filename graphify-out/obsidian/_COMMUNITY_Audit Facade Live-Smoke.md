---
type: community
cohesion: 0.12
members: 26
---

# Audit Facade Live-Smoke

**Cohesion:** 0.12 - loosely connected
**Members:** 26 nodes

## Members
- [[.as_str()]] - code - rust-api/server/src/model/audit.rs
- [[.audit_json()]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[AuditEvent]] - code - rust-api/server/src/model/audit.rs
- [[AuditOperation]] - code - rust-api/server/src/model/audit.rs
- [[AuditOperator]] - code - rust-api/server/src/model/audit.rs
- [[AuditSerialize]] - code - rust-api/server/src/model/audit.rs
- [[Model_7]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[audit.rs]] - code - rust-api/server/src/model/audit.rs
- [[audit_count()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[audit_json_redacts_password_and_retains_user_name()]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[find_active()_1]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[find_active_by_id()]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[find_active_by_name()]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[find_active_filters_soft_deleted()_1]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[hard_clean()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[insert_throwaway()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[live_smoke.rs]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[live_smoke_audit_commit_atomic()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[live_smoke_audit_no_op()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[live_smoke_audit_rollback_atomic()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[live_smoke_oplog_backfill()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[live_smoke_soft_delete_and_read_cluster()]] - code - rust-api/server/src/model/facade/live_smoke.rs
- [[mutate_in_txn()]] - code - rust-api/server/src/model/audit.rs
- [[soft_delete()]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[soft_delete_query()]] - code - rust-api/server/src/model/facade/sys_user.rs
- [[sys_user.rs_1]] - code - rust-api/server/src/model/facade/sys_user.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Audit_Facade_Live-Smoke
SORT file.name ASC
```
