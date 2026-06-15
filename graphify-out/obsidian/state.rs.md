---
source_file: "rust-api/server/src/state.rs"
type: "code"
community: "AppState & Trusted-Proxy Config"
location: "L1"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/AppState__Trusted-Proxy_Config
---

# state.rs

## Connections
- [[AppState]] - `contains` [EXTRACTED]
- [[JwtConfig]] - `contains` [EXTRACTED]
- [[file_or_env()]] - `contains` [EXTRACTED]
- [[ip()]] - `contains` [EXTRACTED]
- [[parse_trusted_cidrs()]] - `contains` [EXTRACTED]
- [[parse_trusted_cidrs_all_garbage_empty()]] - `contains` [EXTRACTED]
- [[parse_trusted_cidrs_empty_input()]] - `contains` [EXTRACTED]
- [[parse_trusted_cidrs_trim_garbage_and_bare_ip()]] - `contains` [EXTRACTED]
- [[parse_trusted_cidrs_two_cidrs()]] - `contains` [EXTRACTED]
- [[resolve_client_ip()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_all_trusted_xff_failsafe_peer()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_empty_trusted_set_ignores_xff()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_forgery_protection_peer_untrusted()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_ipv6_client()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_malformed_token_skipped()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_multi_hop_skip_with_cdn_range()]] - `contains` [EXTRACTED]
- [[resolve_client_ip_rightmost_untrusted_hit()]] - `contains` [EXTRACTED]
- [[trusted_set()]] - `contains` [EXTRACTED]
- [[ttl_from_env()]] - `contains` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/AppState__Trusted-Proxy_Config