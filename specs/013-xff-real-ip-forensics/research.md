# Phase 0 Research: XFF → real_ip 鑑識

> 演算法全文、12 解析案例、信任地基、逐層接地改動、m006 DDL、nginx geo snippet 詳見 `docs/superpowers/000-rust-api-xff-real-ip-research.md`（下稱 **research-doc**）。本檔以 Decision / Rationale / Alternatives 格式固化關鍵決策，並收掉 spec-design §10 的 plan-level opens（皆無 `NEEDS CLARIFICATION` 殘留）。

## D1 — 兩層信任模型（取代單一信任集）
- **Decision**：normalize → peer-gate(`DIRECT`) / Tier-1 CDN 位置錨(`CDN_ANCHORED`) / Tier-2 my-public+binding 走訪(`PROXY_CLEAN`/`PROXY_SOFT`) / fallback(`FALLBACK`)，回 `(IpAddr, Confidence)`。
- **Rationale**：Tier-1 位置錨對「漏設我方 public IP」免疫（盲剝 CDN 右側）；Tier-2 清單在無 CDN 時定邊界；連續多跳逐點迭代 skip。研究見 research-doc §3.2 / §4 案例 2/3/6/7。
- **Alternatives**：單一信任集 rightmost-untrusted（現況；漏設某 public IP 即解錯）；固定 hop 數剝除（reverse proxy 多跳且可變、depth 不固定、不可行）。

## D2 — Tier-1 CDN 錨「不硬 gate」(C3)
- **Decision**：Tier-1 看到鏈中有 CDN 段即位置錨，**不要求** nginx `X-CF-Verified`。
- **Rationale**：用 CF 但未設 nginx 閘時解析仍正確；防注入假 CDN IP 靠**網路層擋直連**（主防線）+ `CDN_ANCHORED`≠`CDN_VERIFIED` in-band 異常訊號。research-doc §8.6-10 / 案例 5。
- **Alternatives**：硬 gate（注入攻擊失效、但耦合「CF 解析正確」於「nginx 閘已設」，且未設時 Tier-2 會誤把 CF 邊緣 IP 當 real_ip）。

## D3 — CF-Connecting-IP = top-level confidence overlay（不取代解析）
- **Decision**：解出 `(real, base)` 後套 overlay：`X-CF-Verified==1` ∧ `CF-Connecting-IP` 有值 ∧ base∈{anchored,clean,soft} → `cip==real ? CDN_VERIFIED : CDN_MISMATCH`；保留 positional real。脫離 Tier-1、Tier-1/Tier-2 結果皆套。
- **Rationale**：同時支援 direct-CF（Tier-1）與 Tunnel（Tier-2、鏈無 CDN 段）；nginx `$remote_addr` 是唯一不可偽造的「經過 CF」證明。research-doc §11.1 / §12 / §13。
- **Alternatives**：rust 自爬 XFF 判 CF-ness（XFF-injectable、已撤）；mismatch 改採 CF-Connecting-IP（撤回——app 層它不比 positional 更可信）。

## D4 — nginx 用 `geo`（非 `map`）做 CF-verified 閘
- **Decision**：`geo $remote_addr $x_cf_verified`（命中集 = CF 邊緣段 ∪ cloudflared ingress `127.0.0.1`/`::1`/docker bridge）；`map $x_cf_verified $cf_cip_safe` strip 非 CF 源；`proxy_set_header` 轉發；**不啟 realip**。
- **Rationale**：`map` 不支援原生 CIDR、CF 段是 CIDR → 必用 `geo`。research-doc §8 L9 / §12.3 / §13.3。

## D5 — 四欄 forensic × 三審計表（統一）
- **Decision**：`peer_ip`/`real_ip`(←`client_ip`)/`x_forwarded_for`/`ip_confidence`；operation_log 對應 `operator_*`；新欄 nullable；entity 與 m006 同步。
- **Rationale**：三表鑑識模型一致（C2/C1 拍板要四欄全顯示全可篩）。schema 細節見 data-model.md。
- **Alternatives**：只 access/login 兩表四欄（被否決；C2/C1 要三表一致）。

## D6 — `ip_confidence` = TEXT；confidence wire = literal union
- **Decision**：DB `TEXT`、entity `Option<String>` 直映；wire 為 7 字串 literal union。
- **Rationale**：直存 enum 小字串、無 i16 映射層；wire literal 對齊 rust serde 實輸出。
- **Alternatives**：smallint（增 enum↔i16 映射層、7 值過度）；wire `string|null`（保守、但 rust 保證 7 字串故用 literal）。

## D7 — `AuditOperator` 維持 `Copy`（op-log threading 漏斗收斂）
- **Decision**：`AuditOperator` 只塞 Copy 型（peer/real = `Option<IpNetwork>`），`xff`/`confidence`（String/enum）走 `AuditEvent` 帶。
- **Rationale**：避免 `AuditOperator` 失去 `Copy` → 不動 16 個 facade mutating fn 的 read-then-move pattern。research-doc §8 L6 / regression。
- **Alternatives**：四欄 flatten 進 `AuditOperator`（失 Copy、須重驗 16 facade）。

## D8 — 結構化 TOML 信任 config（boot-only、env fallback）
- **Decision**：`TrustModel{ cdn(+connecting_ip_header) / my_public(+dual_role) / internal_default / bindings }`；CIDR 欄字串收 + post-load `parse::<IpNetwork>()`；缺檔 fallback flat `TRUSTED_PROXY_CIDRS`；誤配 fail-safe 退保守。
- **Rationale**：per-proxy 綁定 env 表達不了；fail-safe 沿現有哲學。
- **Alternatives**：扁平 env-only（無法表達 per-proxy 綁定）。

## D9 — `dual_role` 降級規則
- **Decision**：Tier-2 走過標 `dual_role` 的 my-public IP、又解出更左值 → confidence 降 `PROXY_SOFT`（保留 positional、不亂猜）。
- **Rationale**：模型化「我方 public IP 同時當 client」盲區、讓 confidence 抓得到。research-doc §5.1 / §11.3-9。

## 收掉的 plan-level opens（spec-design §10）
- **TRUST_MODEL_FILE**：env 名 `TRUST_MODEL_FILE`、TOML 放 `deploy/trust-model.toml`（範本）、dev/prod compose bind-mount 進 rust-api 容器（`/app/deploy/trust-model.toml` 或固定 mount point）；**dev 空/缺檔 → fallback flat env → all-direct**（預期 dev 行為）。
- **`toml` 版本**：`0.8`、`default-features=false`、`features=["parse"]`、Cargo.lock 防禦釘版、容器內驗 1.86 編得過（沿 time/simple_asn1 MSRV 教訓、§6 全域紀律 surface）。
- **CF edge CIDR 集**：**不內建**；operator 自填官方 `cloudflare.com/ips-v4|v6` + cloudflared docker bridge 實際段（geo 命中集）。
- **config reload**：**boot-only**（拓樸變更稀少且刻意；不做 hot-reload watcher、保持簡單）。
