---
source_file: "rust-api/server/src/audit_ctx.rs"
type: "code"
community: "audit_ctx.rs"
location: "L1"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/audit_ctxrs
---

# audit_ctx.rs

## Connections
- [[Confidence]] - `contains` [EXTRACTED]
- [[RequestContext]] - `contains` [EXTRACTED]
- [[apply_cf_overlay()]] - `contains` [EXTRACTED]
- [[apply_cf_overlay_match_upgrades_verified()]] - `contains` [EXTRACTED]
- [[apply_cf_overlay_mismatch_flags()]] - `contains` [EXTRACTED]
- [[apply_cf_overlay_noop_cases()]] - `contains` [EXTRACTED]
- [[apply_tunnel_fallback()]] - `contains` [EXTRACTED]
- [[apply_tunnel_fallback_adopts_cf_cip_on_tunnel_peer()]] - `contains` [EXTRACTED]
- [[apply_tunnel_fallback_noop_when_cf_cip_absent()]] - `contains` [EXTRACTED]
- [[apply_tunnel_fallback_noop_when_not_fallback()]] - `contains` [EXTRACTED]
- [[apply_tunnel_fallback_rejects_spoof_from_non_tunnel_internal()]] - `contains` [EXTRACTED]
- [[audit_mw()]] - `contains` [EXTRACTED]
- [[best_effort_audit()]] - `contains` [EXTRACTED]
- [[cfg_full_trust()]] - `contains` [EXTRACTED]
- [[cidr()]] - `contains` [EXTRACTED]
- [[extract_trace_id()]] - `contains` [EXTRACTED]
- [[extract_trace_id_blank_falls_back()]] - `contains` [EXTRACTED]
- [[extract_trace_id_falls_back_to_uuid()]] - `contains` [EXTRACTED]
- [[extract_trace_id_honors_request_id()]] - `contains` [EXTRACTED]
- [[extract_trace_id_truncates_to_64()]] - `contains` [EXTRACTED]
- [[in_set()]] - `contains` [EXTRACTED]
- [[ip()]] - `contains` [EXTRACTED]
- [[is_cdn()]] - `contains` [EXTRACTED]
- [[is_internal()]] - `contains` [EXTRACTED]
- [[is_my_public()]] - `contains` [EXTRACTED]
- [[is_trusted()]] - `contains` [EXTRACTED]
- [[normalize_caps_token_count()]] - `contains` [EXTRACTED]
- [[normalize_drops_garbage()]] - `contains` [EXTRACTED]
- [[normalize_empty_input()]] - `contains` [EXTRACTED]
- [[normalize_mixed_separators()]] - `contains` [EXTRACTED]
- [[normalize_strips_bracket_v6_port()]] - `contains` [EXTRACTED]
- [[normalize_strips_v4_port()]] - `contains` [EXTRACTED]
- [[normalize_strips_v6_zone()]] - `contains` [EXTRACTED]
- [[normalize_xff_tokens()]] - `contains` [EXTRACTED]
- [[resolve_all_trusted_falls_back_to_peer()]] - `contains` [EXTRACTED]
- [[resolve_cases_01_direct()]] - `contains` [EXTRACTED]
- [[resolve_cases_02_standard_cf()]] - `contains` [EXTRACTED]
- [[resolve_cases_03_cdn_multi_proxy_anchor()]] - `contains` [EXTRACTED]
- [[resolve_cases_04_left_injection()]] - `contains` [EXTRACTED]
- [[resolve_cases_05_bypass_fake_cdn()]] - `contains` [EXTRACTED]
- [[resolve_cases_06_no_cdn_multi_proxy_soft()]] - `contains` [EXTRACTED]
- [[resolve_cases_07_consecutive_my_public()]] - `contains` [EXTRACTED]
- [[resolve_cases_08_binding_soft()]] - `contains` [EXTRACTED]
- [[resolve_cases_09a_dual_role_blindspot()]] - `contains` [EXTRACTED]
- [[resolve_cases_09b_dual_role_via_cdn()]] - `contains` [EXTRACTED]
- [[resolve_cases_10_iis_format()]] - `contains` [EXTRACTED]
- [[resolve_cases_11_tunnel()]] - `contains` [EXTRACTED]
- [[resolve_cases_12_all_trusted_fallback()]] - `contains` [EXTRACTED]
- [[resolve_cdn_anchored()]] - `contains` [EXTRACTED]
- [[resolve_client_ip()]] - `contains` [EXTRACTED]
- [[resolve_dual_role_soft()]] - `contains` [EXTRACTED]
- [[resolve_empty_trusted_returns_peer_direct()]] - `contains` [EXTRACTED]
- [[resolve_ipv6()]] - `contains` [EXTRACTED]
- [[resolve_multi_hop_skips_all_trusted()]] - `contains` [EXTRACTED]
- [[resolve_rightmost_untrusted_skips_trusted()]] - `contains` [EXTRACTED]
- [[resolve_skips_malformed_token()]] - `contains` [EXTRACTED]
- [[resolve_trusted_peer_no_xff()]] - `contains` [EXTRACTED]
- [[resolve_untrusted_peer_ignores_spoofed_xff()]] - `contains` [EXTRACTED]
- [[resolve_with_overlay()]] - `contains` [EXTRACTED]
- [[strip_port_and_parse()]] - `contains` [EXTRACTED]
- [[tm_internal()]] - `contains` [EXTRACTED]
- [[tm_tunnel()]] - `contains` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/audit_ctxrs