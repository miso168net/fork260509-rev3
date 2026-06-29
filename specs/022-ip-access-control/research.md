# Phase 0 Research: 022-ip-access-control

**Branch**: `022-ip-access-control` | **Date**: 2026-06-28 | 接地自 act-on-code（as-built 為準；exact file:line 為 worktree 現碼）

> 固化 brainstorm（`docs/superpowers/022-ip-access-control.md`）§3/§8 與 spec FR/SC 的實作接地。涵蓋 5 個 plan-deferred 項（TUNNEL_ORIGIN 機制／casbin seed 授權／arc-swap 版本／migration 編號／CIDR 搜尋）+ 收尾 cold-review 4 校正的精確碼。

---

## D1 — 閘插點：`ipgate_mw` 疊 `audit_mw` 內側（real_ip 解析後、router 前）

- **Decision**：新獨立 layer `ipgate_mw`，axum 疊 `.layer(ipgate_mw).layer(audit_mw)`（audit_mw 較外較先跑、注入 `RequestContext` extensions，ipgate_mw 較內後跑、讀 `ctx.client_ip`）。
- **接地**：`main.rs:564-600` layer 疊放（外→內 prometheus→audit_mw→router；`:593/599` 自證「後 `.layer()`=較外」）；`audit_ctx.rs:356-363` 注入 RequestContext；`enforce.rs` per-router。
- **Rationale**：閘需 real_ip（audit_mw 產），故須在其後；在 router/enforce 前→被擋請求不到業務/auth/handler 層。
- **Alternatives**：整合進 audit_mw（被擋更早、省 audit_mw 下游）——否決：混職責、難單測；獨立 layer 單一職責可測（被擋仍跑 audit_mw 既有工作＝可接受、皆 μs in-memory、見 D4 DB 寫實況）。

## D2 — 載入：`RuleSet` + `ArcSwap` + boot + watcher（鏡像 settings watcher）

- **Decision**：`pub struct RuleSet { allow: Vec<IpNetwork>, deny: Vec<IpNetwork> }`；`AppState.ip_rules: Arc<ArcSwap<RuleSet>>`。boot `load_active()`→parse→`ArcSwap::from_pointee`（DB 錯→空集 fail-OPEN）；`spawn_ipgate_watcher`（**迴圈鏡像** `spawn_settings_watcher`）sub `ipgate:invalidate`→重讀 DB→`ip_rules.store(新)`、斷線 backoff。
- **接地**：`main.rs:645-692 spawn_settings_watcher`（sub→重讀→store 範式）／`705-766 spawn_policy_watcher`（同款）。**arc-swap 已在 `Cargo.lock 1.9.1`**（transitive）→ server crate `Cargo.toml` 提升為 direct dep `arc-swap = "1.9"`、**零版本 churn**。
- **Rationale**：每請求 lock-free `.load()`（read-爆多/write-極少 熱路徑最適、優於 `Arc<RwLock>` 之讀者序列化+跨 await 鎖）；redis 不能 CIDR 比對→判定必在 rust 記憶體、redis＝invalidate 門鈴（多副本就緒、沿 014/015）。
- **Alternatives**：`Arc<RwLock<RuleSet>>`（reuse 既有 policy primitive）——否決：讀者鎖競爭；redis 存規則每請求查——否決：CIDR 不能 redis 比對、整包拉太慢。

## D3 — 判定流 + 結構豁免 + fail-OPEN

- **Decision**：`ipgate_mw`：`path∈{/health,/metrics}→放行`；`ip=req.extensions().get::<RequestContext>()`〔**.get() Option、無 ctx→fail-OPEN 放行；★絕不用 mandatory `Extension` extractor〔缺則 500=fail-closed〕**〕；`in_set(ip, STRUCTURAL_EXEMPT)→放行`〔硬編 `const &[IpNetwork]` loopback/私網〕；`rules=ip_rules.load()`；`allow.any(contains)→放行`；`deny.any(contains)→②c obs + Err(PermissionDenied)`；else `default-allow`。
- **接地**：`audit_ctx.rs:106 in_set(ip,&[IpNetwork])`（線性 contains 範式）；`IpNetwork.contains(IpAddr)`（sea-orm with-ipnetwork、`entity/.../sys_login_attempt.rs:15 real_ip: IpNetwork`）。`STRUCTURAL_EXEMPT`＝`["127.0.0.0/8","::1/128","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]`。
- **Rationale**：結構豁免＝infra/admin 不可被規則鎖死之恢復途徑（FR-006）；**結構豁免只豁免【阻擋】、不等同 021 lockout-bypass**（後者只認顯式 allow 規則、D6）。

## D4 — blocked 回應 reuse 5003 + ②c 節流 obs + DB 寫實況（cold-review B1）

- **Decision**：blocked → `Err(AppError::PermissionDenied)`（**碼 5003／key `system.forbidden`／HTTP 403**、reuse 既有、**不新增 13-碼**）；②c：`incr("ipgate:blocked:{matched_deny_cidr}")`→節流 ≤1/60s/規則 flush `tracing::warn!(target:"security.ipgate", matched_cidr, blocked=N)`→loki（復用 021 redis incr/take_suppressed/should_flush）。
- **接地**：`error.rs:51/67/82/91` PermissionDenied→5003/system.forbidden/`StatusCode::FORBIDDEN`。`audit_ctx.rs:379-399` post-phase 對 **operator 存在（有效 bearer）** 才寫 sys_access_log。
- **★ DB 寫實況校正（B1）**：「被擋 0 DB 寫」**只對【未認證】成立**（operator None→不寫＝volumetric DoS 主場景）；**認證後被擋仍寫【一列】access-log（http_status=403、forensic 有用）**、非每請求成正比。
- **★ impl 註**：`error.rs:50` 的「5003 唯一 403、enforce 刀才發」doc-comment 於 ipgate 亦發後需更新；驗 base-web 對 5003 處置（攔截器/redirect）對 IP 閘合適。

## D5 — 013 強化：窄 `tunnel` 信任 + CF-Connecting-IP fallback（cold-review B2 收窄）

- **Decision**：`TrustModel` 加**窄欄 `tunnel: Vec<IpNetwork>`**（trust-model.toml `[[tunnel]]`、**只含實際 cloudflared origin**〔如 `127.0.0.1/32`/`::1/128`〕、非整個 `internal_default`）。**新 pure fn `apply_tunnel_fallback(client_ip, base_conf, peer, cf_cip, &tm) -> (IpAddr, Confidence)`**〔插在 handler 呼 `resolve_client_ip` 之後、`apply_cf_overlay` 之前〕：當 `base_conf==Fallback`〔XFF 沒解出外部 client〕**且 `peer ∈ tm.tunnel`** → 採信 `CF-Connecting-IP` 為 real_ip〔**override 分支回 `Confidence::Fallback` 不變**：tunnel 提供、未位置交叉驗證、不新增 enum variant〕；否則原值原 conf 透傳。**★ 不改 `resolve_client_ip(peer,xff,tm)` 簽名**〔無 cf_cip 入參、改它撞 ~12 既有呼叫點+測〔1 prod + 10 resolve_cases + 1 helper〕〕。
- **接地**：`audit_ctx.rs:34-63 Confidence`（7 態、`Fallback`＝整鏈受信/無錨點、回於 `:166`〔Tier-1 無左錨〕/`:206`〔Tier-2 全 skip〕）；`:144-207 resolve_client_ip`（peer-gate `:146-148` 未受信→Direct）；`:264-284 apply_cf_overlay`（既有僅 `X-CF-Verified==1` 採信、**從不覆蓋 real_ip**、gate 在 `{CdnAnchored,ProxyClean,ProxySoft}`〔**非 Fallback**、故 tunnel fallback 不可塞此 fn〕）；**handler `~:324` 呼 `resolve_client_ip`、`~:329-332` 自 header 取 cf_cip → 新 fn 插在 cf_cip 取出後〔~:332〕、`apply_cf_overlay`〔~:338〕前、`resolve_client_ip` 與其既有測〔10 `resolve_cases_*` `:506~611` + helper `:722`〕全不動**；`config.rs:32-59 TrustModel`（+`tunnel` 仿 `internal_default: Vec<IpNetwork>` parse）；`deploy/nginx/nginx.conf:46-80` geo+map（CF 邊緣段∪loopback→`X-CF-Verified`，**reuse、無需改 nginx**）。
- **Rationale（反偽造、B2）**：`peer ∈ tunnel`〔窄、只 cloudflared origin、配 :31081 internal-only〕即驗證——內網非 tunnel-origin 位置自帶偽 CF-CIP **不滿足** peer∈tunnel、不被採信。現有 nginx+CF 路徑（XFF 有 client、非 Fallback）**零改變、零回歸**。屬對 013「CF-CIP 不覆蓋 real_ip」不變式的**刻意、窄範圍**反轉（收尾加 013 as-built 註記）。
- **Alternatives**：reuse `CdnEntry`+verify——否決（CDN≠Tunnel 語義混淆）；blanket `is_trusted(peer)`——**否決（B2：整個內網可偽造）**；強制 cloudflared 注入 shared-secret header——defense-in-depth 可選加（plan tasks 評），但窄 peer 已足。

## D6 — 白名單 → 021 L0 seam（兌現 022-FR-004〔白名單免鎖〕、接 021 預留 seam〔021 FR-012〕）

- **Decision**：`auth.rs:271` L0 seam：login 起手 `if state.ip_rules.allow.any(contains client_ip) → 跳 021 L1/L2 lockout`。白名單同源 `state.ip_rules`（閘與 lockout-bypass 讀同份）。
- **接地**：`auth.rs:271 // L0 trusted-ip bypass seam（FR-012、未實作）`。
- **Rationale**：信任來源免被 account-DoS 鎖死（FR-004、019 §4.2 per-IP 白名單）。

## D7 — 手動解鎖 reset-marker + per-dimension since（cold-review B3）

- **Decision**：解鎖端點清 `lockout:{dim}:{value}` L1 key + companions ＋ 寫 `lockout:reset:{dim}:{value}=now_unix`（TTL=窗、**沿 `set_revoked` 存值範式**）。**021 L2 gate `since` 拆 per-dim**：`since_ip=max(now-窗, reset_ip_at)`、`since_user=max(now-窗, reset_user_at)`，各餵 `count_failed_by_ip_since`/`count_failed_by_user_since`。
- **接地**：`redis.rs:150-164 set_revoked/revoked_at_of`（存 unix 秒+parse、reset-marker 直接沿用）；`auth.rs:316-337` **現為單一 `since` 餵兩 count**〔`:327 count_failed_by_ip_since(...since)`、`:334 count_failed_by_user_since(...since)`〕→ per-dim reset **須在此拆兩 since**（B3）；`sys_login_attempt.rs:3-4/:51-54` 確認 append-only（reset-marker 不刪列為正確機制）。
- **Rationale**：DB 滑動窗 count 為鎖定真相、列不可刪（archetype B）；reset-marker 使 reset 前失敗不計＝真解鎖；per-dim 使解 user 維不誤動 ip 維（both-dims 鎖須兩維皆解、FR-010）。

## D8 — 資料模型 `sys_ip_rule` + migration m007

- **Decision**：新 entity `entity::sys_ip_rule`（`id` bigserial／`cidr: IpNetwork`／`rule_type` varchar allow|deny／`order: Option<i32>`〔`column_name="order"`〕／`description` nullable／created_at·by·updated·deleted 稽核+soft-del）。**migration `m007_create_sys_ip_rule`**：`execute_unprepared` CREATE TABLE + **partial unique** `(cidr,rule_type) WHERE deleted_at IS NULL` + casbin seed（D10）。
- **接地**：`entity/.../sys_login_attempt.rs:15 real_ip: IpNetwork`（cidr 欄仿、INET/CIDR）；`m001_rev2_schema.rs:753-766` `execute_unprepared` partial unique `WHERE deleted_at IS NULL`（3 先例）；`m006_audit_ip_forensics.rs:26-101` up/down 結構（`execute_unprepared`、down 反序）；migration 最後＝m006→本刀 **m007**。
- **Rationale**：CRUD 多列規則無法塞 KV `system_settings`（平坦單值）→新表；partial unique 防 active 重複（create 撞→23505→2222、沿 seaorm sql_err）。

## D9 — facade/handler 沿 sys_menu/sys_user 範式

- **Decision**：facade `sys_ip_rule`：`load_active()→(allow,deny)`〔`find_active()` 分兩袋、閘用〕／`list(page,size,filter)→(records,total)`〔**hybrid＝`find()`含已刪 + 分頁/filter + `ORDER BY (deleted_at IS NULL) DESC, order ASC, id ASC` + 每列 `deleted` bool**〕／`create/update/soft_delete/restore(...,AuditMeta)`〔同 txn op-log〕。handler 6 端 sync sys_menu/sys_user。
- **接地**：`sys_menu.rs:69-88 list_active/list_all`（order ASC,id ASC）／`:761-844 create/update(MenuWrite,AuditMeta)`／`:895-939 soft_delete/restore(id,AuditMeta)`＋ op-log `AuditEvent{operation,entity_table,entity_id,payload_before/after,operator/xff/conf/trace_id}`（`:775-785`）；`sys_user.rs list_active(page,size,filter)→(records,total)`＋`UserFilter`+`apply_if`+`PageRes{current,size,total,records}`（1-based→0-based）。CIDR 模糊搜尋沿 `ip_host_like`（audit）。
- **Rationale**：列表含已刪+Deleted欄+復原比照 menu；分頁搜索比照 user；零新範式。

## D10 — casbin seed + endpoint_coverage_lint bump

- **Decision**：6 新 route seed `('p','R_SUPER',path,method,'','','',false)` + menu policy `('p','R_SUPER','manage_ip-rule','menu',...)`（隨 m007、`ON CONFLICT DO NOTHING`）；**`AS_BUILT_ROUTES` 44→50**、**`ALL_ENDPOINT_POLICIES` 36→42**；每 route `main.rs` 掛 `require_policy(path,method)`。授權＝R_SUPER seed（⚠️p）、R_ADMIN 可經 016 runtime RBAC 授予。
- **接地**：`m005_audit_log_query.rs:55-63` casbin seed 形（`('p','R_SUPER',path,method,...,false)`+menu）；`endpoint_coverage_lint.rs:102-147 AS_BUILT_ROUTES`（44）；`enforce.rs:212-249 ALL_ENDPOINT_POLICIES`（36）+`:136-156 enforce_role_path_method`。
- **Rationale**：lint 鎖「main.rs==registry==seed」三源一致；R_SUPER-seed 安全預設、runtime 可放行 R_ADMIN（沿標準系統管理範式）。

## D11 — base-web 三端 wire 對齊（新管理頁）

- **Decision**：新 `views/manage/ip-rule/index.vue`（列表含已刪+Deleted NTag+搜索分頁 比照 user/menu+CRUD+復原+解鎖 modal）；`rev3-system-manage.ts` +6 wrapper；`typings/api/system-manage.d.ts` +`IpRule`/`IpRuleSearchParams`/`IpRuleListItem` 型；locale +`backend.biz.ipRule.*`/`page.manage.ipRule.*`/`route.manage_ip-rule`。
- **接地（三端對齊紀律）**：rust handler DTO（query filter camelCase、PageRes、`deleted` bool）↔ base-web service inline type + typings ↔ view state，三端逐欄對齊（防 type-lie）。新 view→elegant-router 重生 4 route 檔 + `route.<key>` i18n（沿 memory `base-web-elegant-router-regen-on-new-view`）。
- **CDP smoke defer 風險自覺**：列表/復原/搜索/自鎖拒/解鎖 + i18n toast 在地化須 CDP browser 軌（curl≠modal）；加 i18n 鍵後 `restart base-web` 防 vite stale-locale（memory `vite-stale-locale-new-key-raw-toast`）。

## schema/crate/route 摘要
- **1 migration（m007）**、**0 新 workspace crate**（arc-swap 提升既有 transitive dep）、**6 新 route**（lint bump 44→50/36→42）、**1 新 base-web view**。
- prod build gate 仍跑（新 migration+新 route、驗 multi-stage 無破口；§3 紀律）。
