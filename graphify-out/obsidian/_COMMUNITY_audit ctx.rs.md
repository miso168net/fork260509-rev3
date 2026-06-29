---
type: community
cohesion: 0.07
members: 65
---

# audit ctx.rs

**Cohesion:** 0.07 - loosely connected
**Members:** 65 nodes

## Members
- [[.as_str()]] - code - rust-api/server/src/audit_ctx.rs
- [[.to_audit_meta()]] - code - rust-api/server/src/audit_ctx.rs
- [[Confidence]] - code - rust-api/server/src/audit_ctx.rs
- [[RequestContext]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_cf_overlay()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_cf_overlay_match_upgrades_verified()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_cf_overlay_mismatch_flags()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_cf_overlay_noop_cases()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_tunnel_fallback()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_tunnel_fallback_adopts_cf_cip_on_tunnel_peer()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_tunnel_fallback_noop_when_cf_cip_absent()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_tunnel_fallback_noop_when_not_fallback()]] - code - rust-api/server/src/audit_ctx.rs
- [[apply_tunnel_fallback_rejects_spoof_from_non_tunnel_internal()]] - code - rust-api/server/src/audit_ctx.rs
- [[audit_ctx.rs]] - code - rust-api/server/src/audit_ctx.rs
- [[audit_mw()]] - code - rust-api/server/src/audit_ctx.rs
- [[best_effort_audit()]] - code - rust-api/server/src/audit_ctx.rs
- [[cfg_full_trust()]] - code - rust-api/server/src/audit_ctx.rs
- [[cidr()]] - code - rust-api/server/src/audit_ctx.rs
- [[extract_trace_id()]] - code - rust-api/server/src/audit_ctx.rs
- [[extract_trace_id_blank_falls_back()]] - code - rust-api/server/src/audit_ctx.rs
- [[extract_trace_id_falls_back_to_uuid()]] - code - rust-api/server/src/audit_ctx.rs
- [[extract_trace_id_honors_request_id()]] - code - rust-api/server/src/audit_ctx.rs
- [[extract_trace_id_truncates_to_64()]] - code - rust-api/server/src/audit_ctx.rs
- [[in_set()]] - code - rust-api/server/src/audit_ctx.rs
- [[ip()]] - code - rust-api/server/src/audit_ctx.rs
- [[is_cdn()]] - code - rust-api/server/src/audit_ctx.rs
- [[is_internal()]] - code - rust-api/server/src/audit_ctx.rs
- [[is_my_public()]] - code - rust-api/server/src/audit_ctx.rs
- [[is_trusted()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_caps_token_count()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_drops_garbage()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_empty_input()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_mixed_separators()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_strips_bracket_v6_port()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_strips_v4_port()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_strips_v6_zone()]] - code - rust-api/server/src/audit_ctx.rs
- [[normalize_xff_tokens()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_all_trusted_falls_back_to_peer()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_01_direct()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_02_standard_cf()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_03_cdn_multi_proxy_anchor()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_04_left_injection()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_05_bypass_fake_cdn()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_06_no_cdn_multi_proxy_soft()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_07_consecutive_my_public()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_08_binding_soft()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_09a_dual_role_blindspot()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_09b_dual_role_via_cdn()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_10_iis_format()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_11_tunnel()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cases_12_all_trusted_fallback()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_cdn_anchored()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_client_ip()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_dual_role_soft()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_empty_trusted_returns_peer_direct()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_ipv6()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_multi_hop_skips_all_trusted()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_rightmost_untrusted_skips_trusted()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_skips_malformed_token()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_trusted_peer_no_xff()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_untrusted_peer_ignores_spoofed_xff()]] - code - rust-api/server/src/audit_ctx.rs
- [[resolve_with_overlay()]] - code - rust-api/server/src/audit_ctx.rs
- [[strip_port_and_parse()]] - code - rust-api/server/src/audit_ctx.rs
- [[tm_internal()]] - code - rust-api/server/src/audit_ctx.rs
- [[tm_tunnel()]] - code - rust-api/server/src/audit_ctx.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/audit_ctxrs
SORT file.name ASC
```
