---
type: community
cohesion: 0.21
members: 21
---

# AppError Mapping

**Cohesion:** 0.21 - loosely connected
**Members:** 21 nodes

## Members
- [[.biz()]] - code - rust-api/server/src/error.rs
- [[.from()]] - code - rust-api/server/src/error.rs
- [[.internal()]] - code - rust-api/server/src/error.rs
- [[.into_response()_1]] - code - rust-api/server/src/error.rs
- [[.login_failed()]] - code - rust-api/server/src/error.rs
- [[.logout()]] - code - rust-api/server/src/error.rs
- [[.modal_logout()]] - code - rust-api/server/src/error.rs
- [[.not_found()]] - code - rust-api/server/src/error.rs
- [[.permission_denied()]] - code - rust-api/server/src/error.rs
- [[.token_expired()]] - code - rust-api/server/src/error.rs
- [[AppError]] - code - rust-api/server/src/error.rs
- [[biz_custom_msg_appears_in_body()]] - code - rust-api/server/src/error.rs
- [[db_err_maps_to_5000_internal()]] - code - rust-api/server/src/error.rs
- [[error.rs]] - code - rust-api/server/src/error.rs
- [[internal_maps_to_200_and_detail_never_leaks()]] - code - rust-api/server/src/error.rs
- [[login_failed_maps_to_200_envelope()]] - code - rust-api/server/src/error.rs
- [[not_found_maps_to_404_envelope()]] - code - rust-api/server/src/error.rs
- [[permission_denied_maps_to_403_envelope()]] - code - rust-api/server/src/error.rs
- [[reserved_codes_are_unconstructible_and_eight_are_distinct()]] - code - rust-api/server/src/error.rs
- [[resp_of()]] - code - rust-api/server/src/error.rs
- [[token_expired_modal_logout_logout_status_and_code()]] - code - rust-api/server/src/error.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/AppError_Mapping
SORT file.name ASC
```
