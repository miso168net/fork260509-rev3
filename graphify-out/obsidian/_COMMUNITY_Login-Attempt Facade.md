---
type: community
cohesion: 0.42
members: 11
---

# Login-Attempt Facade

**Cohesion:** 0.42 - moderately connected
**Members:** 11 nodes

## Members
- [[LoginAttemptEvent]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model_builds_insert_with_seven_set_columns()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model_operator_id_none_failure_maps_to_set_none()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model_operator_id_some_success_maps_to_set_some()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model_trace_id_string_maps_to_some()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model_v4_client_ip_maps_to_slash_32()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[login_attempt_active_model_v6_client_ip_maps_to_slash_128()]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[sample_event()_1]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[sys_login_attempt.rs_1]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs
- [[write()_1]] - code - rust-api/server/src/model/facade/sys_login_attempt.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Login-Attempt_Facade
SORT file.name ASC
```
