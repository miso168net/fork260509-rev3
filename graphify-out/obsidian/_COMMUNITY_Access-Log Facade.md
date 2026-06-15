---
type: community
cohesion: 0.47
members: 9
---

# Access-Log Facade

**Cohesion:** 0.47 - moderately connected
**Members:** 9 nodes

## Members
- [[AccessLogEvent]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[access_log_active_model()]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[access_log_active_model_builds_insert_with_nine_set_columns()]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[access_log_active_model_trace_id_string_maps_to_some()]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[access_log_active_model_v4_client_ip_maps_to_slash_32()]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[access_log_active_model_v6_client_ip_maps_to_slash_128()]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[sample_event()]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[sys_access_log.rs_1]] - code - rust-api/server/src/model/facade/sys_access_log.rs
- [[write()]] - code - rust-api/server/src/model/facade/sys_access_log.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Access-Log_Facade
SORT file.name ASC
```
