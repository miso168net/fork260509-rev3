---
type: community
cohesion: 0.09
members: 27
---

# session.rs

**Cohesion:** 0.09 - loosely connected
**Members:** 27 nodes

## Members
- [[EffectivePolicy]] - code - rust-api/server/src/auth/session.rs
- [[RotationDecision]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_active_is_rotate()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_none_is_not_found()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_revoked_is_reuse()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_unknown_status_is_reuse()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_used_at_exact_grace_boundary_is_reuse()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_used_beyond_grace_is_reuse()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_used_with_null_used_at_is_reuse_fail_closed()]] - code - rust-api/server/src/auth/session.rs
- [[decide_rotation_used_within_grace_is_benign()]] - code - rust-api/server/src/auth/session.rs
- [[find_by_hash()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[find_by_hash_for_update()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[insert_token()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[mark_used()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[resolve_policy()]] - code - rust-api/server/src/auth/session.rs
- [[resolve_policy_explicit_off_overrides_global()]] - code - rust-api/server/src/auth/session.rs
- [[resolve_policy_explicit_on_overrides_global()]] - code - rust-api/server/src/auth/session.rs
- [[resolve_policy_inherit_follows_global_false()]] - code - rust-api/server/src/auth/session.rs
- [[resolve_policy_inherit_follows_global_true()]] - code - rust-api/server/src/auth/session.rs
- [[resolve_policy_unknown_follows_global()]] - code - rust-api/server/src/auth/session.rs
- [[revoke_all_user_chains()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[revoke_chain()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[revoke_other_chains()]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[session.rs]] - code - rust-api/server/src/auth/session.rs
- [[sys_token.rs_1]] - code - rust-api/server/src/model/facade/sys_token.rs
- [[toctou_revoked_chain_locks_to_reuse_no_rebake()]] - code - rust-api/server/src/model/facade/sys_token.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/sessionrs
SORT file.name ASC
```
