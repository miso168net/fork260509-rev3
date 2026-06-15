---
type: community
cohesion: 0.18
members: 14
---

# Bearer Token Verify

**Cohesion:** 0.18 - loosely connected
**Members:** 14 nodes

## Members
- [[bearer.rs]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_headers()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token_extracts_token()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token_none_when_empty()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token_none_when_lowercase_prefix()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token_none_when_missing()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token_none_without_prefix()]] - code - rust-api/server/src/auth/bearer.rs
- [[bearer_token_trims_surrounding_spaces()]] - code - rust-api/server/src/auth/bearer.rs
- [[verify_bearer()]] - code - rust-api/server/src/auth/bearer.rs
- [[verify_bearer_none_on_bad_signature()]] - code - rust-api/server/src/auth/bearer.rs
- [[verify_bearer_none_on_wrong_aud()]] - code - rust-api/server/src/auth/bearer.rs
- [[verify_bearer_none_when_no_header()]] - code - rust-api/server/src/auth/bearer.rs
- [[verify_bearer_valid_token_returns_claims()]] - code - rust-api/server/src/auth/bearer.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Bearer_Token_Verify
SORT file.name ASC
```
