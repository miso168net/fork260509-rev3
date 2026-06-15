---
type: community
cohesion: 0.20
members: 21
---

# AppState & Trusted-Proxy Config

**Cohesion:** 0.20 - loosely connected
**Members:** 21 nodes

## Members
- [[.from_env()]] - code - rust-api/server/src/state.rs
- [[AppState]] - code - rust-api/server/src/state.rs
- [[JwtConfig]] - code - rust-api/server/src/state.rs
- [[file_or_env()]] - code - rust-api/server/src/state.rs
- [[ip()]] - code - rust-api/server/src/state.rs
- [[parse_trusted_cidrs()]] - code - rust-api/server/src/state.rs
- [[parse_trusted_cidrs_all_garbage_empty()]] - code - rust-api/server/src/state.rs
- [[parse_trusted_cidrs_empty_input()]] - code - rust-api/server/src/state.rs
- [[parse_trusted_cidrs_trim_garbage_and_bare_ip()]] - code - rust-api/server/src/state.rs
- [[parse_trusted_cidrs_two_cidrs()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_all_trusted_xff_failsafe_peer()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_empty_trusted_set_ignores_xff()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_forgery_protection_peer_untrusted()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_ipv6_client()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_malformed_token_skipped()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_multi_hop_skip_with_cdn_range()]] - code - rust-api/server/src/state.rs
- [[resolve_client_ip_rightmost_untrusted_hit()]] - code - rust-api/server/src/state.rs
- [[state.rs]] - code - rust-api/server/src/state.rs
- [[trusted_set()]] - code - rust-api/server/src/state.rs
- [[ttl_from_env()]] - code - rust-api/server/src/state.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/AppState__Trusted-Proxy_Config
SORT file.name ASC
```
