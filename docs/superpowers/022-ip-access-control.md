# 022-ip-access-control — spec-design（Phase 0 brainstorm）

> CLAUDE.md §3 階段 0 產物。交棒 → **手動** `/speckit-specify`（input＝本檔）起 `022-ip-access-control` feature branch（★ 勿排進 brainstorm 觸發、否則 `speckit.git.feature` pre-hook 不執行、見 §3）。
> 日期：2026-06-28。來源：021 收刀後 user 提「IP 白名單加入系統管理」→ brainstorm 中擴充為**通用 IP 存取閘（白名單＋黑名單、每請求放行/阻擋、CIDR、DB 真相→記憶體判定）**。承接：兌現 **019 §4.2「per-IP 信任白名單（免誤鎖 NAT/共用對外 IP）」**＋ **021 FR-012 L0 trusted-ip bypass seam**（`auth.rs:271`）；021 收刀已標「帳號-DoS 緩解優先級升高、宜緊接排程」（[DECISIONS §1 ⚠️ad]／CHECKLIST §4.2）。
> **★ scope 升級**：本刀**不只** lockout-bypass 白名單，而是**全站每請求的 IP 存取控制閘**（白名單放行 ＞ 黑名單阻擋 ＞ 其餘放行），白名單**順便**接 021 L0 seam 跳 lockout。
> **★ 本檔已納入收尾前獨立 cold-review 校正**（CF-CIP fallback 信任面收窄、reset per-dimension、blocked 零-DB 限定未認證、riders 獨立驗收——詳 §2 標 ☆R 處與 §7/§8）。

---

## 1. 背景與目標

**需求**（user 親提 2026-06-28）：把 IP **白名單＋黑名單**加進系統管理；存 DB 為真相、服務啟動後載入記憶體做**每請求**放行/阻擋判定；順序＝**先放行白名單、再阻擋黑名單**；名單支援 **CIDR**。

**動機**：019/021 只防登入面；無「依來源 IP 放行/封鎖整體存取」能力。021 把鎖做硬後**帳號-DoS（誤鎖合法 NAT/共用 IP）風險升高** → 需「信任來源白名單免被鎖」＋「封鎖已知惡意段」黑名單。

**目標**：應用層、runtime 可經系統管理 UI 編輯的 IP 存取閘——全站每請求對 `real_ip` 比對 CIDR（白>黑>default-allow）；DB 真相、boot 載入 in-process（ArcSwap）、redis pub/sub 門鈴熱刷新；**判定純記憶體、μs 級、DoS-resilient**（021 同課）；全程 fail-OPEN（§I.7）；admin 自鎖防護；附 admin 手動解鎖；**CF Tunnel（繞 nginx）部署正式化＋強化 real_ip 解析**。

**範圍**：IP 白/黑名單存取閘 ＋ admin 手動解鎖 ＋ CF Tunnel 拓樸文件化/013 強化。**非**：runtime 可調 lockout 門檻、IPv6 /64 群組、CAPTCHA、distinct-source HLL（§5）。

---

## 2. 拍板紀錄（user 親決 2026-06-28 brainstorm；☆R＝收尾 cold-review 校正）

| # | 拍板 | 結論 |
|---|---|---|
| **P1** | 閘範圍 | **全站每請求**：gate＝獨立中介層 `ipgate_mw`、疊 audit_mw **內側**（real_ip 已解析後）、cover 所有 rust-api 請求；`/health`·`/metrics` 永遠放行；僅 cover rust-api（/api/*）、不含 nginx 服務的前端 SPA 靜態資源。 |
| **P2** | 判定預設 + 失效 | **default-allow + fail-OPEN**：白放行 ＞ 黑阻擋 ＞ 其餘放行；規則載不進→全放行（§I.7、auth/casbin 仍守）。 |
| **P3** | 自鎖防護 | **寫端自鎖檢查**（新增/改 `deny` 命中操作者當前 real_ip → 2222、比照 009）＋ **loopback/私網結構豁免**（`127/8 ::1 10/8 172.16/12 192.168/16 fc00::/7` 硬編、不可被規則誤擋）＋ 白名單優先。 |
| **P4** | scope 邊界 | **IP 白/黑名單閘 ＋ admin 手動解鎖**；runtime 門檻 / IPv6 群組 / CAPTCHA / HLL 另刀（§5）。 |
| **P5** | 載入架構 | **方案 B**：DB 真相 → boot 讀 DB parse 進 **`ArcSwap<RuleSet>`** → 每請求 lock-free 比對；改規則 publish `ipgate:invalidate` → watcher 重讀 DB 換 ArcSwap。☆R **watcher 迴圈鏡像 `spawn_settings_watcher`；儲存 primitive 用 `arc-swap`（新外部 dep、比既有 `Arc<RwLock>` 更適 read-爆多/write-極少 熱路徑）。** redis 不能 CIDR 比對→判定必在 rust 記憶體、redis＝invalidate 門鈴。 |
| **P6** | CF Tunnel | **方案 A**：① 拓樸正式化（§4.11）；② 強化 `resolve_client_ip` minimal fallback——XFF 沒找到外部 client（`Fallback`）時用 `CF-Connecting-IP` 當 real_ip。☆R **信任面收窄**：**只在 peer ∈【窄的、明確配置的 tunnel-origin 信任層】時才採信 CF-CIP**（**非** blanket `is_trusted`＝整個內網）＋ 驗證訊號（cloudflared 注入的共享祕密 header／或 tunnel-origin 專屬條目），否則任何內網位置自帶偽 CF-CIP 即可控制閘判定（見 §4.6）。 |
| **P7** | 資料模型 | 砍 `enabled`；加 `order`（純查看排序、不影響比對、admin 給值、**永不覆寫**）；已刪沉底用**排序式** `ORDER BY (deleted_at IS NULL) DESC, order ASC, id ASC`（方案②、restore 安全）；列表**比照 menu 顯示全部含已刪 + Deleted 欄 + inline 復原**（復原含**同 (cidr,rule_type) active 衝突→2222** 守門）；**分頁/搜索比照 user**；**partial unique** `(cidr,rule_type) WHERE deleted_at IS NULL`。 |
| **P8** | 被擋回應 | **HTTP 403 + 通用 envelope、不新增 13-碼**。☆R **直接 reuse `AppError::PermissionDenied`（碼 5003／key `system.forbidden`／HTTP 403、既有 9 emittable 碼之一）**＝零新碼、且與 authz 拒絕無從區分（不洩黑名單）。 |
| **P9** | 手動解鎖 | **reset-marker**：清 `lockout:{dim}:{value}` L1 + 寫 `lockout:reset:{dim}:{value}=now`（TTL=窗）。☆R **021 L2 gate `since` 拆成 per-dimension**：`since_ip=max(now-窗, reset_ip_at)`、`since_user=max(now-窗, reset_user_at)`（各餵對應 count）；`sys_login_attempt` 確認 append-only 不可刪→reset-marker 為正確機制；both-dims 鎖（botnet）須兩維皆解才放行。 |
| **P10** | 命名 | **`022-ip-access-control`**。 |

---

## 3. Phase 0 研究實證（act-on-code 接地 @ 2026-06-28；exact 行於 `/speckit-plan` research.md 再固化）

- **中介層疊放**（`main.rs:564-600`）：外→內＝`prometheus_layer → audit_mw → router`（`.layer(A).layer(B)`＝B 較外較先跑；`main.rs:593/599` 自證）。`audit_mw`（`audit_ctx.rs:310-401`）全域每請求解析 real_ip + 注入 `RequestContext` extensions（`:356-363`）+ **post-phase 對【有 operator】請求寫 sys_access_log**（`:379-399`）；`enforce_mw`（`auth/enforce.rs:318`）per-protected-router。→ `ipgate_mw` 疊 `.layer(ipgate_mw).layer(audit_mw)`：audit_mw 注入後 ipgate_mw 讀 `ctx.client_ip`（**cold-review B1 已對碼確認此疊放時序成立**）。
- **settings 島 watcher**（`main.rs:645-692 spawn_settings_watcher` sub `settings:invalidate`→重讀 DB→store；`705-766 spawn_policy_watcher` 同）：DB 真相 + in-process `Arc<...>` + redis pub/sub。本刀 watcher **迴圈鏡像**之；☆R 儲存 primitive 既有為 `Arc<AtomicBool>`(settings,`state.rs:44`)/`Arc<RwLock<Enforcer>>`(policy,`:31`)，本刀新用 **`ArcSwap<RuleSet>`**（per-request lock-free、多欄結構最適）。
- **redis facade**（`redis.rs`）：get/set_ex/del/incr/take_suppressed/mark_locked/is_locked/publish/subscribe_pubsub；`set_revoked`/`revoked_at_of`(`:149-164`)＝**存值-型** marker 範式（reset-marker 直接沿用）。被擋鑑識 ②c 復用 021 incr/take_suppressed/節流、零新方法。
- **CIDR 既有**：sea-orm `with-ipnetwork`→`IpNetwork`（v4/v6、`.contains(IpAddr)`）；`audit_ctx.rs:106 in_set(ip,&[IpNetwork])`。
- **013 real_ip/trust**（`audit_ctx.rs:144-207 resolve_client_ip` peer-gate→Tier-1 CDN→Tier-2 XFF；**未受信 peer→`Direct`（`:146-148`）、∴ `Fallback`⟹peer 已受信**；`:264-284 apply_cf_overlay` **僅在 `X-CF-Verified==1` 採信 CF-CIP 且從不覆蓋 real_ip**；`internal_default` 含 `127/8`/`::1`、`cfg_full_trust`/`is_trusted:127-132`＝**整個內網**；`config.rs CdnEntry.connecting_ip_header` 已存在）。☆R 本刀 fallback **刻意、且【窄範圍】反轉**「CF-CIP 不覆蓋 real_ip」不變式＋補 tunnel-origin 驗證，見 §4.6。REVIEW SEC M-7：rust-api:31081 prod internal-only 為前提。
- **CRUD 範式**：menu（`sys_menu.order: Option<i32>`、`list_all()=find()`含已刪、DTO `deleted` bool、NTag 二態 + inline 復原 `index.vue:165-267`；menu soft_delete 不改 order→本刀改排序式沉底）；user（`sys_user::list_active(page,size,filter)→(records,total)`、6 filter `apply_if`、`PageRes{current,size,total,records}`、1-based→0-based）。
- **error/envelope**（`error.rs:50-91`）：`AppError::PermissionDenied`→碼 5003/key `system.forbidden`/HTTP 403（既有「唯一 403」；☆R impl 時更新其「enforce 刀才發」doc-comment＋驗 base-web 對 5003 的處置對 IP 閘合適）。
- **migration partial unique**：sea-query Index builder 不做 filtered index，但 `migration/src/m001_rev2_schema.rs:753-766` 已有 `execute_unprepared` 建 3 個 `… WHERE deleted_at IS NULL` partial unique 先例→本刀同款。
- **append-only**：`sys_login_attempt.rs:3-4/:51-54` 確認只 `write`/INSERT、無 update/delete→reset-marker 不刪列為正確機制。
- **021 L0 seam**：`auth.rs:271`；login gate **單一 `since`**（`:316,322-337`、註「兩窗同 900s→單一 since」）餵 ip/user 兩 count→☆R reset 需拆兩 since。
- **arc-swap**：全 Cargo.toml 無此 dep→新增外部 crate dep（非 workspace crate、無「新 crate 四處 Dockerfile COPY」負擔）。

---

## 4. 設計細節

### 4.1 兩條資料流
**① 管理流（冷）**：admin → base-web IP 名單頁 → CRUD handler（`require_policy` + 寫端自鎖檢查）→ facade 寫 `sys_ip_rule`（DB 真相、同 txn op-log）→ `publish ipgate:invalidate`。
**② 判定流（熱）**：每請求 → audit_mw 解析 real_ip（含 §4.6）→ `ipgate_mw` 對 `ArcSwap<RuleSet>` 純記憶體 lock-free 判定 → 放行續走 router/enforce_mw/handler；阻擋 §4.5 + HTTP 403。

### 4.2 資料模型 `sys_ip_rule`（新表 + migration）
entity `entity::sys_ip_rule`、facade `model/facade/sys_ip_rule.rs`；archetype＝受管實體 + soft-delete + 稽核 shadow（沿 system_settings/sys_role）。

| 欄 | 型 | 說明 |
|---|---|---|
| `id` | bigserial PK | |
| `cidr` | `IpNetwork`（pg cidr/inet） | v4/v6、單 IP=/32·/128 |
| `rule_type` | varchar | `'allow'`\|`'deny'` |
| `order` | `Option<i32>`（`column_name="order"`） | 純查看排序、不影響比對、永不覆寫 |
| `description` | varchar nullable | |
| `created_at/by`、`updated_at/by`、`deleted_at/by` | | 稽核 + soft-delete |

**migration `mNNN_create_sys_ip_rule`**（⚠️k 短編號；★ 破 rev3 連 4 刀 0-migration）：CREATE TABLE + `execute_unprepared` partial unique `(cidr,rule_type) WHERE deleted_at IS NULL`（沿 m001 先例；create 撞→23505→2222）+ casbin policy seed。無額外查詢索引（小表）。
**facade 兩查詢**：`load_active()→(allow,deny)`（`find_active()`、閘用、不看 order/desc）；`list(page,size,filter)→(records,total)`（**hybrid**＝`find()`含已刪 + 分頁/filter + `ORDER BY (deleted_at IS NULL) DESC, order ASC, id ASC` + 每列 `deleted` bool）。`create/update/soft_delete/restore(..., AuditMeta)` 同 txn op-log；restore 守門：同 (cidr,rule_type) 已有 active→2222（partial unique 為 backstop）。

### 4.3 執行期判定 `ipgate_mw`（獨立 layer、單一職責）
```
ipgate_mw(req, next):
  if path ∈ {/health, /metrics}: → next（探針豁免）
  ip = req.extensions().get::<RequestContext>()?.client_ip     # ☆R 用 .get() Option（無 ctx → fail-OPEN 放行；★絕不用 mandatory Extension extractor〔缺則 500=fail-closed〕）
  if in_set(ip, STRUCTURAL_EXEMPT): → next                      # 硬編 loopback/私網 const &[IpNetwork]、沿 in_set；★僅豁免【阻擋】、不等於 021 lockout-bypass（後者只認 explicit allow-list、§4.7、見 §4 註）
  rules = ip_rules.load()                                       # arc-swap lock-free
  if rules.allow.any(|n| n.contains(ip)): → next                # 白名單優先（亦 §4.7 跳 lockout）
  if rules.deny.any(|n| n.contains(ip)):  → §4.5 節流 obs → Err(AppError::PermissionDenied)   # 5003/HTTP 403、不洩黑名單
  → next（default-allow）
```
比對純記憶體、μs 級、零 DB/redis roundtrip。被擋請求在 **router/enforce_mw/handler 之前**被擋（不到那些昂貴層）；☆R 但**仍在 audit_mw 之後**（依賴其 real_ip）、∴ audit_mw 本身的 per-request 工作（resolve_client_ip/region/JWT verify）對被擋請求仍跑（皆 in-memory μs；DB 寫見 §4.5）。

> **註（A3 釐清）**：structural-exempt（loopback/私網）只豁免**阻擋**；它**不**自動跳 021 lockout（lockout-bypass 只認 §4.7 的 explicit `allow` 規則）。私網來源若要跳 lockout，須顯式加進 allow 名單。

### 4.4 載入：`RuleSet` + ArcSwap + boot + watcher
`pub struct RuleSet { allow: Vec<IpNetwork>, deny: Vec<IpNetwork> }`；`AppState.ip_rules: Arc<ArcSwap<RuleSet>>`。boot：`load_active()`→parse→`ArcSwap::from_pointee`，DB 錯→空集（fail-OPEN）。`spawn_ipgate_watcher`（**迴圈鏡像** `spawn_settings_watcher`）：sub `ipgate:invalidate`→重讀 DB→`ip_rules.store(新 RuleSet)`；斷線 backoff。

### 4.5 被擋鑑識（021 ②c 同款）+ DB 寫實況（☆R 校正）
- ②c：`incr("ipgate:blocked:{matched_deny_cidr}")` 累計 → 節流 ≤1/60s/規則 flush `tracing::warn!(target:"security.ipgate", matched_cidr, blocked=N)`→loki（復用 021 redis facade）。
- ☆R **DB 寫實況**：被擋請求**不到 access-log 寫點**？**只對【未認證】成立**——audit_mw post-phase（`audit_ctx.rs:379-399`）對 **operator 存在（有效 bearer）** 才寫 sys_access_log；**未認證被擋＝operator None＝零 DB 寫（＝volumetric DoS 主場景、閘的 DoS-resilience 在此）**；**認證後被擋（合法 user 的 IP 被列黑／攻擊者持低權 token 自被擋 IP）＝仍寫【一列】access-log（http_status=403、forensic 有用）**、非每請求成正比（單列）。**結論**：「鎖後 0 DB 寫」之宣稱**限定未認證**；認證被擋留一列稽核痕跡（刻意保留）。
- distinct-source HLL（被擋來源 IP 數）＝遞延（同 021）。

### 4.6 013 強化（CF-Connecting-IP minimal fallback、☆R 信任面收窄）
**問題**（cold-review B2 HIGH）：原設計 `Fallback && is_trusted(peer) && CF-CIP→real_ip=CF-CIP` 的 `is_trusted`＝**整個內網信任集**（10/172/192/loopback）→ 任何能直連 :31081 的內網位置自帶偽 `CF-Connecting-IP` 即可控制閘判定（＋經 §4.7 控 lockout-bypass）、且丟掉既有 `X-CF-Verified` 驗證 ＝ **閘的判定輸入可被內網偽造**。
**收窄設計**：
```
(real_ip, conf) = 現有 resolve_client_ip(peer, xff, tm)        # 不變
if conf == Fallback                                            # XFF 沒找到外部 client（典型＝cloudflared 直連）
   && peer ∈ TUNNEL_ORIGIN                                     # ★【窄】明確配置的 tunnel ingress（非 blanket is_trusted）
   && tunnel_verified(req)                                     # ★ 驗證訊號：cloudflared 注入的共享祕密 header（X-CF-Verified 的 tunnel 類比）／或 tunnel-origin 專屬條目
   && cf_connecting_ip 合法存在:
       real_ip = CF-Connecting-IP（CF 權威）
```
- **TUNNEL_ORIGIN**＝trust-model 新增的【窄】條目（reuse `CdnEntry.connecting_ip_header` 機制 / 或新 `tunnel` 條目），**只含實際 cloudflared ingress**、不含整個內網。
- 現有 nginx+CF 路徑（XFF 有 client、非 Fallback）**零改變、零回歸**；未受信 peer→`Direct`、CF-CIP 一律忽略（不可偽造）。
- **此為對 013「CF-CIP 不覆蓋 real_ip」不變式的【刻意、窄範圍】反轉**，收尾比照既往加 013 as-built 註記。
- ★ 精確的 TUNNEL_ORIGIN 配置形 + tunnel_verified 機制（共享祕密 vs 專屬條目）由 `/speckit-plan` 釘死（§8）。

### 4.7 白名單 → 021 L0 seam（兌現 021 FR-012）
`auth.rs:271` L0 seam 落地：login 起手 `if state.ip_rules.allow.any(contains client_ip) → 跳 021 L1/L2 lockout`。白名單同源 `state.ip_rules`。＝信任來源免被 account-DoS 鎖死。

### 4.8 admin 手動解鎖（reset-marker、☆R per-dimension）
端點清 `lockout:{dim}:{value}` L1 + companions ＋ 寫 `lockout:reset:{dim}:{value}=now`（TTL=窗、沿 `set_revoked` 存值範式）。**021 L2 gate `since` 拆兩維**（原為單一 since）：
```
since_ip   = max(now-窗, reset_ip_at)     → 餵 count_failed_by_ip_since
since_user = max(now-窗, reset_user_at)   → 餵 count_failed_by_user_since
```
reset 前失敗不計＝真解鎖（不刪 append-only 列）；reset 後新失敗仍累積（刻意、可 re-lock）。**both-dims 鎖（botnet）須兩維皆解**（解鎖 UI 支援同時解或提示）。fail-OPEN（redis 掛→退自動窗滑）。

### 4.9 CRUD handlers + 路由 + lint
`GET getIpRuleList`／`POST addIpRule`／`updateIpRule`／`DELETE deleteIpRule`(soft)／`POST restoreIpRule`／`POST unlockLogin`；皆 `require_policy` + 同 txn op-log；改規則後 publish invalidate；add/update deny 寫端自鎖檢查（命中 `ctx.client_ip`→2222）。overhead：`AS_BUILT_ROUTES`+`ALL_ENDPOINT_POLICIES` bump、casbin seed、`endpoint_coverage_lint` bump、sys_menu seed。

### 4.10 base-web UI（新頁 `/manage/ip-rule`）
列表（cidr/rule_type tag/order/description/**Deleted NTag**/時戳、搜索 cidr·rule_type·description + 分頁〔比照 user〕、active 列 編輯/刪除、已刪列 復原鈕〔比照 menu〕）＋ add/edit modal（cidr 驗證/rule_type 下拉/order/description）＋ 手動解鎖 modal（dimension+value、both-dims 提示）。軌道：MODAL-WIRING + BASE-WEB-WRAPPER + BASE-WEB-I18N-WIRING（`backend.*` biz key + `page.manage.ipRule.*`）+ elegant-router 新 view 重生 4 route 檔 + `route.<key>` i18n。

### 4.11 CF Tunnel 拓樸文件化（P6-①）
DESIGN 新節「部署入口拓樸/信任邊界」（3 ingress〔直連 nginx／CF→nginx／**CF Tunnel→rust-api 直連**〕+ 各信任邊界 + real_ip 來源 + **TUNNEL_ORIGIN 窄信任**；§1.0「nginx 單一入口」勘誤）／DECISIONS §1 新碼（⚠️ae）「CF Tunnel 繞 nginx 支援 + 013 CF-CIP 窄 fallback」／CLAUDE.md §8.2 第 4 啟動模式 tunnel／CHECKLIST §4.2（**☆R 用 § 錨、不用揮發行號**）分清模式 1（CF→nginx）/2（Tunnel 繞 nginx）。

---

## 5. v1 不做（defer）
runtime 可調 lockout 門檻（settings 島）／IPv6 /64 per-ip 群組／CAPTCHA／distinct-source HLL（blocked obs）／security.ipgate 具體 grafana alert rule（遞延 ops、本刀只發可告警訊號）／nginx-edge 層 IP 封鎖（本刀＝應用層 runtime 閘）／閘 cover 前端 SPA 靜態資源（僅 /api/*）。

## 6. 出口條件
- [ ] 黑名單 CIDR→該段每請求被擋（HTTP 403/5003）；白名單→放行（且跳 021 lockout）；其餘 default-allow。
- [ ] loopback/私網 + /health + /metrics 永遠放行（結構豁免、不等於 lockout-bypass）。
- [ ] 判定純記憶體 μs 級、零每請求 DB/redis；**未認證被擋＝0 DB 寫**（認證被擋＝1 列 access-log forensic、非成正比）；被擋走 ②c 節流 obs。
- [ ] DB 改規則→publish→watcher 熱刷新 ArcSwap。
- [ ] 寫端自鎖檢查；列表含已刪 + Deleted 欄 + 復原（衝突守門）；搜索/分頁。
- [ ] admin 手動解鎖（reset-marker、per-dim）→ 被鎖 user 立即可登入（both-dims 鎖須兩維皆解）。
- [ ] **CF Tunnel 直連（peer ∈ TUNNEL_ORIGIN + 驗證 + CF-CIP）→ real_ip=CF-CIP；★ 反偽造：trusted-但-非-tunnel peer 自帶偽 CF-CIP → 不採信**；現有 nginx 路徑零回歸。
- [ ] 全程 fail-OPEN；migration up→down→up；prod build gate；Constitution 9/9。

## 7. 測試/驗收策略（TDD；☆R riders 獨立 regression-proof）
- **純函式**：CIDR 比對（白>黑>豁免>default）、gate 決策、rule parse、restore 衝突守門、寫端自鎖、013 fallback 邏輯。
- **live `#[ignore]`**（容器內 `--test-threads=1`、需 DB+Redis）：load_active/watcher 重載/閘對真 ruleset/reset-marker per-dim 解鎖/blocked 節流。
- **☆R 013 信任變更獨立驗收**（HIGH 風險）：**現有 `resolve_client_ip` 全部既有 case 零回歸**（grep `resolve_cases_*`/`apply_cf_overlay` 既有測全綠）＋ **新增反偽造 case**（peer ∈ 內網但 ∉ TUNNEL_ORIGIN + 偽 CF-CIP → real_ip ≠ CF-CIP）＋ tunnel-direct 正路（peer ∈ TUNNEL_ORIGIN + 驗證 → CF-CIP）。
- **☆R 021 reset-marker 獨立驗收**：per-dim 獨立（解 user 維不影響 ip 維、反之）＋ both-dims 鎖須兩維皆解＋ 未認證/認證被擋 DB 寫差異斷言。
- **C-V acceptance**（curl/psql/redis-cli + CDP）：封段→403／白名單放行+跳 lockout／default-allow／loopback·health 豁免／手動解鎖→可登入；CDP（列表含已刪+復原+搜索分頁+寫端自鎖拒、i18n toast 在地化〔restart base-web 防 vite stale-locale〕）；**migration up→down→up**；**prod image build**（沿 §3 紀律、雖非新 workspace crate）。
- **lint**：`entity_access_lint`（sys_ip_rule 只經 facade）／`endpoint_coverage_lint`（新路由==seed）。

## 8. Phase 0 research 待固化（交 `/speckit-plan` research.md）
- `ipgate_mw` 確切疊放（`.layer` 順序）+ blocked reuse `AppError::PermissionDenied`（5003/HTTP 403）回應形 + base-web 對 5003 處置驗證 + `error.rs:50` doc-comment 更新。
- ☆R **CF-CIP fallback 信任邊界**：TUNNEL_ORIGIN 確切配置形（trust-model 新條目 vs reuse CdnEntry.connecting_ip_header）+ `tunnel_verified` 機制（cloudflared 共享祕密 header vs 專屬條目）+ `resolve_client_ip` 的 `Fallback` 精確分支 + fallback 插入點。
- ☆R **021 login gate `since` 單→雙拆分**（per-dim reset）的精確碼 + L0 seam 白名單跳過點 + sys_login_attempt append-only 確認。
- `sys_ip_rule` facade 三端對齊（rust DTO / base-web service+typings / view state）；CIDR 模糊搜尋（audit `ip_host_like` vs 文字 ILIKE）。
- `arc-swap` crate 穩定版 pin（workspace dep）；migration 短編號 + casbin seed 形 + endpoint_coverage_lint bump 數。

## 9. Constitution 9/9 預檢
1 base-web 權威✅｜2 MODAL-WIRING✅｜3 menu casbin✅｜4 wire 對齊✅（blocked=reuse 5003、非新 13-碼、不破 ⚠️f）｜5 無 rev2 拷貝✅｜6 無抵觸 #1~13✅｜7 軌道內✅（RUSTAPI-SOURCE-ISOLATION + MODAL-WIRING/WRAPPER/I18N-WIRING/ADAPT）｜8 新表 migration 合規✅（新受管實體、archetype 受管+soft-delete、非 retrofit〔⚠️ac〕）｜9 §I.7✅（新 gate 全 fail-OPEN；觸 021〔白名單跳 lockout + reset-marker per-dim since〕為 fail-OPEN+DB-truth 一致演進；013 CF-CIP 窄 fallback 為刻意窄範圍 as-built 演進）。**→ 9/9、1 合規 migration。**

## 10. 執行單元雛形（交 階段 2 Workflow 驅動）
- **U1 rust 地基**：013 CF-CIP 窄 fallback 強化〔★獨立零回歸驗收、§7〕 + `sys_ip_rule` entity/facade/migration + `RuleSet`/ArcSwap/boot/`spawn_ipgate_watcher`。
- **U2 rust 閘**：`ipgate_mw` + CIDR/結構豁免/path 豁免/fail-OPEN(.get Option) + blocked ②c 節流 obs + 白名單→021 L0 seam。
- **U3 rust CRUD+解鎖**：CRUD handlers/路由/casbin seed/lint + 寫端自鎖 + 手動解鎖（reset-marker per-dim）+ 021 L2 `since` 單→雙拆分〔★獨立驗收〕。
- **U4 base-web**：管理頁（列表/搜索/CRUD/復原/Deleted）+ 手動解鎖 UI + i18n + wrapper + elegant-router 重生。
- **Docs**：CF Tunnel 拓樸（DESIGN/DECISIONS/CLAUDE.md/CHECKLIST）——編入各單元 / 收口回填。

> rust 全程 serial；live 測容器內 `--test-threads=1`；逐單元兩段式 commit + bump pin（§4.1）；base-web `--no-verify`；★ 絕不 push/merge（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
