---
type: community
cohesion: 0.35
members: 11
---

# JWT Sign/Verify

**Cohesion:** 0.35 - loosely connected
**Members:** 11 nodes

## Members
- [[Claims]] - code - rust-api/server/src/auth/jwt.rs
- [[aud_mismatch_is_rejected()]] - code - rust-api/server/src/auth/jwt.rs
- [[expired_token_is_rejected()]] - code - rust-api/server/src/auth/jwt.rs
- [[iss_is_not_validated()]] - code - rust-api/server/src/auth/jwt.rs
- [[jwt.rs]] - code - rust-api/server/src/auth/jwt.rs
- [[now_secs()]] - code - rust-api/server/src/auth/jwt.rs
- [[roundtrip_sign_then_verify_returns_claims()]] - code - rust-api/server/src/auth/jwt.rs
- [[sign()]] - code - rust-api/server/src/auth/jwt.rs
- [[tampered_token_is_rejected()]] - code - rust-api/server/src/auth/jwt.rs
- [[verify()]] - code - rust-api/server/src/auth/jwt.rs
- [[wrong_secret_is_rejected()]] - code - rust-api/server/src/auth/jwt.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/JWT_Sign/Verify
SORT file.name ASC
```
