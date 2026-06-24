---
type: "query"
date: "2026-06-24T04:31:23.106051+00:00"
question: "resolve_client_ip() 兩層信任如何判定真實 client IP、防 XFF 偽造污染審計（013）？"
contributor: "graphify"
source_nodes: ["resolve_client_ip()", "is_trusted()", "is_cdn()", "normalize_xff_tokens()", "apply_cf_overlay()", "audit_mw()"]
---

# Q: resolve_client_ip() 兩層信任如何判定真實 client IP、防 XFF 偽造污染審計（013）？

## Answer

resolve_client_ip(peer,xff,tm)(audit_ctx.rs:142-205) 純函式兩層信任：A.peer-gate——peer 不在 trust set(cdn∪my_public∪internal∪binding.internal)→(peer,Direct) 在建 chain 前就 return、XFF 完全忽略(防偽根基、keystone)。chain=normalize(xff)++[peer](peer 最右最可信)。B.Tier-1 CDN anchor——鏈含 CDN→rposition 最右 CDN、往左第一個非 CDN=real_ip(CdnAnchored)、CDN 右側盲剝免疫漏設;左側全 CDN→Fallback。C.Tier-2(無 CDN)——由右而左 skip internal/my_public/binding.internal、第一個非我方=real_ip(ProxyClean;dual_role 或 binding 相鄰不符→ProxySoft 軟降不停線);全受信→Fallback。Confidence 7 態(direct/cdn_anchored/proxy_clean/proxy_soft/cdn_verified/cdn_mismatch/fallback)=誠實 provenance、寫 op-log operator_ip_confidence + access-log。apply_cf_overlay(:262)只調 confidence 永不動 real_ip:X-CF-Verified==1(nginx 注入)∧cip∧base∈{CdnAnchored/ProxyClean/ProxySoft}→cip==real:CdnVerified、≠:CdnMismatch。對抗驗證 overall confirmed、6 偽造全擋:(1)直連攻擊偽 XFF→peer-gate Direct;(2)CDN 後 prepend 左側偽→anchor 取右側真 hop;(3)偽 CDN-range token→直連被 peer-gate、CDN 後則在真 CDN 左側 rposition 取不到;(4)偽 CF-Connecting-IP→nginx geo 用不可偽 remote_addr 只對真 CF CIDR 設 verified、且 base=Direct 時 overlay 不適用雙閘;(5)flooding/garbage→normalize cap 32+filter_map drop;(6)IPv6/port/zone→strip_port_and_parse 正規化後才比 CIDR。找不到任何 XFF/peer 組合能在高信任(ProxyClean/CdnVerified)下騙出錯 real_ip(錯 IP 只會落 Direct/Fallback/CdnAnchored/CdnMismatch)。nuance:MAX_XFF_TOKENS=32 cap 算 raw split 段非 kept IP(32+ 前置空/garbage 段可 silent drop 真 IP=drop/DoS edge、非攻擊者 IP 抬升)。caveat:rust 盲信 nginx X-CF-Verified→CF 反偽保證依賴 nginx 永遠在前。圖盲點對比:此子系統同模組 unqualified call→全 EXTRACTED 完整捕獲(resolve_client_ip #3 god node)、異於 facade qualified-call 漏邊(GRAPHIFY-NOTES §2.8)。

## Source Nodes

- resolve_client_ip()
- is_trusted()
- is_cdn()
- normalize_xff_tokens()
- apply_cf_overlay()
- audit_mw()