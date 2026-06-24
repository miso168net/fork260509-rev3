# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 4 observability ✅ 全完成（2026-06-25）— 一刀 018-observability、三執行單元 obs-min→obs-full→dashboard（merge `c1a3224`、feature branch 保留）＝完全 opt-in 維運觀測層〔loki/alloy/grafana log＋prometheus/exporter/pushgateway metrics＋6 dashboard＋3 alert〕、rust 埋点 RUSTAPI-SOURCE-ISOLATION〔json log+trace_id 關聯／/metrics+casbin counter／cleanup push〕、零 base-web/零 migration/零新 crate、MSRV 1.86 確證。波 3 ✅（014/015/016）＋pre-波4 017 ✅（merge `c7f5936`）＋波 2 ✅（009-012）＋D11 013 ✅ 已收**（as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-25 波 4 observability ✅ 全綠收刀：018-observability merge `c1a3224`**：一刀三執行單元（U0 MSRV→U1 obs-min log→U2 obs-full metrics→U3 dashboard→Polish）;rust json log+trace_id 關聯〔fields_trace_id join sys_access_log〕／`/metrics`+casbin_enforce_total{decision}+cleanup pushgateway／6 grafana dashboard〔CDP 實渲染〕／3 alert〔5xx idle false-firing 修〕。4 Workflow 驅動+整體 holistic CONCERNS 無 BLOCK;C-V-0~8+prod build+MSRV 全綠;零 base-web/migration/新 crate、Constitution 9/9。詳 [DECISIONS §2](INTEGRATION-DECISIONS.md)／[REVIEW-018](REVIEW-018-observability.md)
- **2026-06-24 波 4 啟動：018-observability Phase 0 brainstorm 落地**：一刀 018＋三執行單元 obs-min→obs-full→dashboard（D1）、rev2 對等+hindsight、defer 同 rev2（D2）；act-on-code 接地（axum 0.7／無 log-side trace_id span→U1 含小 rust 單元／nginx 404+JSON 已就緒不動／`grafana_admin_password` DESIGN:706 落差須補／★MSRV 1.86 必檢）。spec-design `676b13be`、pending 手動 `/speckit-specify`。詳 [018 spec-design](superpowers/018-observability.md)

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **波 4 observability ✅ 全完成、目前無 active feature**（018-observability merge `c1a3224`、feature branch 保留）。下一波 roadmap 見 [DESIGN §8.4](INTEGRATION-DESIGN.md);候選遞延項＝alt-login 4 流程 stub〔⚠️m post-波3 v1-completeness slot、§4.2〕／audit scale 兩項〔pg_trgm／archive purge、§4.2〕／log retention purge〔⚠️n、§4.2〕。018 自身遞延 backlog 見 §3.I。Auth 島／治理島 §4.2／三維 RBAC runtime 編輯／觀測層皆已閉口

---

## 2. Roadmap & Phase 狀態

對齊 CLAUDE.md §3 SDD-TDD 工作流 + [DESIGN §8.4 交付波次](INTEGRATION-DESIGN.md)（波次定義/出口條件在彼）。本節為動態 status 追蹤;完成波 as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);完成波摘要累積數波後批次搬 [MILESTONES §2](INTEGRATION-MILESTONES.md)、本節永遠聚焦當前波。

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基 ✅ 全完成+已歸檔 (2026-06-18)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 1 — 第一刀＝`system_settings` 打樋 ✅ 全完成+已歸檔 (2026-06-18)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 2 — data islands ✅ 全完成+已歸檔 (2026-06-19)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### D11 遞延刀 — 013-xff-real-ip-forensics ✅ 全完成+已歸檔 (2026-06-21)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 3 — 行為島＋policy ✅ 全完成+已歸檔 (2026-06-22)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### pre-波4 017-audit-center-enhancement ✅ 全完成+已歸檔 (2026-06-23)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 4 — observability ✅ 全完成+已歸檔 (2026-06-25)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md);018 遞延 backlog 見 §3.I。

### 持續性維護

- [ ] upstream rebase（定期 `git rebase upstream/example`〔base-web〕＋docs 源倉 `upstream/main`;CLAUDE.md §4.6;⚠️s fork-delta 紀律＋zdiff3/rerere 已配套）
- [ ] graphify 圖譜更新（大改後 `graphify update`;最近一輪 2026-06-13、4176 nodes/567 communities——**早於 001 收刀**,**波 0 全收（001-007 七刀）＋波 1（008 system_settings）＋波 2（009 user-management＋010 menu-management＋011 role-management＋012 audit-log-query）＋D11（013 xff-real-ip-forensics）＋波 3（014 auth-token-session／015 policy-governance／016 button-endpoint-policy）＋pre-波4（017 audit-center-enhancement）＋波4（018 observability〔rust 埋点 audit_ctx span/event＋main.rs /metrics+json subscriber＋enforce.rs casbin counter＋cleanup-job push_metrics;deploy obs config loki/alloy/prometheus/grafana-provisioning〕）新碼均未入圖（★ 註：本項起首「最近一輪 2026-06-13/4176 nodes」與 [MILESTONES §1](INTEGRATION-MILESTONES.md) 的 2026-06-24 graphify update〔4176→5127 同步 008-017→prune 3271 nodes〕矛盾＝前 session 漏更;待以 `graphify-out/manifest.json`／[GRAPHIFY-NOTES §1](GRAPHIFY-NOTES.md) 核實圖譜實況後校正日期/節點數/已入圖範圍）**〔001 scaffold/compose/deploy・002 migration×4/sea-orm-adapter・003 envelope/i18n・004 entity crate/soft-delete lint・005 audit・006 auth runtime・007 xdb crate/audit_ctx・008 system_settings facade/handler/require_policy/endpoint_coverage_lint＋base-web 新頁/wrapper/i18n・009 user CRUD facade/handler＋base-web user 接線・010 menu facade/handler/enforce〔menu_routes_for_roles〕/flat→tree 序列化/route.rs＋base-web menu 接線/.env dynamic/route store 例外・011 role facade〔★ net-new sys_casbin_rule set_role_dimension DB-first＋sys_role CRUD＋sys_user_role count＋sys_menu id↔route_name〕/handler 9 端點/main/lint＋base-web role 接線/menu-auth-modal/i18n・012 audit〔m005 migration＋sys_operation/access/login_log list+filter＋sys_user names_for_ids unfiltered〕/handler 3 唯讀端點/main audit group/lint glob＋base-web 審計中心頁〔NTabs 3 tab＋3 子表 payload 展開＋honest typings＋i18n〕・013 xff-real-ip-forensics〔audit_ctx 兩層解析重寫〔normalize/resolve→(IpAddr,Confidence)/apply_cf_overlay/Confidence 七態〕＋config TrustModel〔新 toml dep〕＋m006＋3 entity 改名加欄＋3 facade 四欄寫+list filter＋model/audit AuditMeta＋handler wire+filter/auth＋base-web 審計四欄顯示/篩選/ip-confidence-tag+options/i18n＋deploy nginx geo/map+trust-model〕・014 auth-token-session〔Redis 基建/rotation/single-session/denylist/cleanup-job crate/2-instance compose〕・015 policy-governance〔sys_casbin_policy_archive facade/archive-restore/gate/spawn_policy_watcher/回收桶 UI〕・016 button-endpoint-policy〔set_role_endpoints 雙鍵 diff/all_buttons JSON registry/endpoint registry+M2 lint/回收桶 v2-推導/base-web 三維 role drawer UI〕〕,待一輪 update;docs 同期大改〔INTEGRATION-* 四檔／008 specs〕亦未入圖、惟 `.graphifyignore` 排除 docs/、docs 入圖另案）

---

## 3. Follow-up Backlog

> 2026-06-22 thematic 重組（de-bloat）：原 per-feature §3.1 至 §3.20 散列收成跨刀主題群 §3.A 至 §3.H；已結 follow-up 與**舊→新 §錨對照**見 [MILESTONES §3](INTEGRATION-MILESTONES.md) + git history（pre-debloat `16b53a3`）。均不阻塞、消費刀/觸發時處理。

> **★ 為何剩餘 `[ ]` 多輪收不掉 + §3／§4 分流（2026-06-24 校準）**：可做的實質 hygiene 已收完（含 F4＝最後一個 codeable 項）。剩餘按「本版觸發時做」vs「未來版本/長期」分流（`[x]`＝做完；以下皆**非待辦遺漏**）：
> - **§3 留（本版剩餘、觸發/反應時做、波4 可能命中）**：TRIGGER〔lint CONST 守門／validate_value_type／`set_var` edition2024〕｜REACTIVE〔op-log count 隔離〕｜OWN-CUT〔batch_soft_delete／soft_delete fault-test／protected 訊息，併的是 rev3 內未來刀〕｜low-doable〔image pin 殘留／001 邊角／examples fixture／misc〕
> - **§4.2 移（未來版本實現、非 v1、長期追蹤）**：DEFER-prod〔cert external／trust-model 填值，需真 prod 環境〕｜WON'T-DO v1〔prod 多副本〕｜SCALE〔pg_trgm／archive purge〕｜scheduled-feature〔alt-login〕。（§3.H 雜項內同性質項 Redis 熱快取/login fallback/dispatcher/pruneNullParams 保留壓縮原處、不重列）

### 3.A 公網/prod 部署前硬化（跨刀彙整：001/012/013/014/018）

> 公網/prod 部署前一次性硬化；dev 不受影響。原散於各刀，收成單一清單。

- [x] ✅ **nginx 硬化**〔001、pre-波4 2026-06-23〕：nginx.conf `server_tokens off`＋prod.conf 443 HSTS/X-Frame-Options/X-Content-Type-Options（`nginx -t` 掛 rev3_net 過）；`/health` 雙 Content-Type 早已 `default_type`（自述 stale）
- [x] ✅ **TLS/secret/腳本**〔001〕：compose secrets 預檢〔`deploy/preflight-secrets.sh` 自 001 已備✅〕／generate-secrets dual-write 連動重生✅／generate-dev-cert renew＋chmod 600／離線 fallback✅。（`front_nginx_certs external:true` 拍板、需真 prod → 移 §4.2）
- [ ] **image pin 一致性**〔001〕：〔pre-波4 done：base-web runtime `nginx:alpine→nginx:1.31.0-alpine` 對齊 front-nginx✅；★ node:26/postgres:17 維持大版本 pin＝拍板#4 house style、刻意不 patch-pin〕。仍 open（low/觸發）：alpine/openssl:latest（低、一次性）／debian:bookworm-slim（本機未 pull、不猜 date tag、延後）
- [x] ✅ **XFF 上限**〔012/013、pre-波4 2026-06-23〕：`normalize_xff_tokens` 加 `MAX_XFF_TOKENS=32` token cap（test-first `normalize_caps_token_count`）
- [x] ✅ **cleanup-job 上線**〔014、pre-波4 2026-06-23〕：profile-gated compose sidecar（`cleanup-job` service、`profiles:[prod]` opt-in、sleep-loop `--execute` 每日〔`CLEANUP_INTERVAL_SECS` 預設 86400〕、復用 prod image+database_url secret〔APP_DATABASE_URL_FILE〕、healthcheck disabled；docker-compose.yml）;live 驗 executed 刪 0 列+running 非 crash-loop。仍 open（low）：最小權限 secret `cleanup_database_url`（現走全權 DATABASE_URL）
- 〔→ §4.2〕餘「需真 prod 環境/拓樸」項（trust-model 部署填值〔013〕／prod 多副本〔014、research §D 不做 v1〕／cert external）已移 §4.2 未來版本實現
- [ ] **001 其他邊角**：~~prod migrate 無意義 HEALTHCHECK→disable~~（早已 disable、自述 stale✅）；migrate redis depends_on 措辭對齊；dev watcher cargo-watch→bacon/watchexec 評估；`set_var` runtime（edition 2024 升級時）；rust-api/.gitignore `debug`/`target` pattern 錨；cargo cache 卷遮蓋/冷卷首啟 flap 已在 CLAUDE.md §8.2.1（quickstart 補述可選）
- [ ] **alloy 非-root 硬化**〔018、prod security pass、brainstorm §5 defer〕：obs alloy 現 `user:root` 讀 `/var/run/docker.sock`（docker-SD 採集全容器 stdout）;prod 硬化時改非-root user + docker group/sock 權限（dev 不受影響、功能不變）。同類 prod-only 硬化，可與本節其他項一併處理。

### 3.B typings 收斂 sweep ✅ 全完成+已歸檔 (2026-06-23)

> 4 項全收（MenuList type-lie／drawer null-flow／excel demo／016 未引用型、跨刀 009/010/011/016）;詳 [MILESTONES §3](INTEGRATION-MILESTONES.md)。

### 3.C 審計中心 enhancement ✅ 四項全完成 (C-1/C-3/C-4/F4、2026-06-23~24)

> C-1 http_status 類別 filter／C-3 CSV 匯出／C-4 op-log 角色 delta（017 收、merge `c7f5936`）＋F4 CSV 截斷信號嚴格化（2026-06-24、`7ac45c7`）兌現，詳 [MILESTONES §1](INTEGRATION-MILESTONES.md)。**兩 scale 項（模糊 LIKE→`pg_trgm` GIN／archive retention-purge）移 §4.2 未來版本**。

### 3.D alt-login stub 刀 → 移 §4.2 未來版本實現 (排程 future feature、⚠️m、2026-06-24)

> 排程 post-波3 v1-completeness slot；接地/工量見 [DECISIONS §1](INTEGRATION-DECISIONS.md) ⚠️m。內容移 §4.2 長期追蹤。

### 3.E test/lint 健壯化（跨刀：007/008/011/013、觸發時加守門）

- [ ] op-log count EntityId-only 隔離脆弱性〔007-era；`op_log_atomic_three_paths` 014 已 trace_id 化；sys_role/menu/casbin 殘留未觀察 flaky、真失敗再統一 trace_id 化〕
- [ ] `endpoint_coverage_lint` `first_string_after` 抽取假設字面字串〔008；引入 `.route(CONST,…)`/`require_policy(CONST,…)` 須加守門或 self-test〕
- [ ] `validate_value_type` 非 enum 型保守放行〔008；新值型 seed 須補驗證分支＋守恆斷言〕
- [x] ✅ pre-existing dead〔pre-波4 2026-06-23 重構順手清〕：`sys_casbin_rule.rs` ConnectionTrait unused import〔011 起〕已刪／`RequestContext.operator_id` never-read〔007 起〕已移除欄位+賦值

### 3.F policy-seed 對齊校正 ✅ 翻案結案+已歸檔 (2026-06-23、維持現狀)

> 翻案＝維持現狀〔updateUser/manage_role 經 016 runtime 可授 R_ADMIN、零 migration、非缺陷〕;詳 [MILESTONES §3](INTEGRATION-MILESTONES.md)。

### 3.G request interceptor i18n ✅ 全完成+已歸檔 (2026-06-23)

> 4040/5003（HTTP 404/403）native axios error 在地化（onError translateBackendMsg、⚠️aa 授權、CDP 驗 403 toast）;詳 [MILESTONES §3](INTEGRATION-MILESTONES.md)。

### 3.H keep-deferred 雜項【參考清單、非勾選】（觸發/own-cut/永不混合、壓縮）

> 本節為 deferred 雜項**參考**、非待辦勾選——含「觸發時做」「own-cut 併未來刀」「won't-fix/by-design **永不**」三種混合（各項「何時」見內聯括註）。故刻意**不用 `[ ]`、不期待歸零**；真有觸發再從這撈。

- **rust robustness**〔014、low〕：〔pre-波4 done：settings/policy watcher reconnect 後補 DB re-read/reload✅；Redis boot connect 包 `tokio::timeout(5s)`✅〕仍 open〔SCALE〕：Redis `sess:{uid}` pointer 熱快取 deferred（X-01 sanctioned、QPS 高再啟）
- **vendored adapter**〔002〕：〔pre-波4 done：移除 async-trait/tokio 被忽略的 default-features=false、消 build warning✅〕仍 open〔TRIGGER〕：examples fixture（builder 內跑 cargo test 時 COPY）
- **optimization re-defer**：~~iframe props 內嵌〔010 D2〕~~（moot：rev3 動態選單不走 iframe-page props 路徑✅）；~~`filter_routes` 遞迴化〔010 D3〕~~（stale：rust+前端兩端早已遞迴✅）；`batch_soft_delete` sentinel DbErr→自管 txn〔OWN-CUT、併下次 menu 治理刀〕〔010〕；soft_delete 中途失敗審計（原子性已由 mutate_in_txn 保證、僅缺 fault-inject 測、OWN-CUT）〔005〕
- **UX/cosmetic**〔low〕：~~endpoint modal 扁平→可按 path 群組〔016〕~~（pre-波4 done：path 群組 NTree+check-strategy=child✅、synthKey 016 已加固、CDP 驗渲染）；~~ArchivedPolicy createdTime 未顯欄〔015〕~~（pre-波4 done：加「建立时间」欄✅、CDP 驗欄頭）；protected 訊息泛化未 surface 具體〔OWN-CUT：facade 已攜 detail、缺 AppError 攜帶+i18n 插值+暴露安全評估〕〔011/016〕；login fallback「No match」transient〔**永不/won't-fix**：動 frozen upstream auth/index.ts、低收益〕〔010〕
- **misc**：dynamic route `/route/*` 真流量重抓〔000、低 archival〕；`inline_coverage_lint` 候選〔⚠️s、待 ⚠️q migrate〕；base-web i18n 單元測 fidelity〔003、待 vitest 環境〕；~~`TrustModel.Binding.dual_role` 從不消費〔013〕~~（pre-波4 done：net-dead 確認〔只寫不讀〕、移除欄位✅、`b63928b`）；rev2 redis `--dir` bug 回灌〔001、rev2 維護時〕；dispatcher `server)` 不 shift〔001、**永不/won't-fix**、blob 凍結〕；pruneNullParams 雙防線〔012、**永不/by-design 刻意保留、非待辦**〕；specs 筆誤家族 255〔012〕/263〔013〕/338〔016〕（as-built 權威在 DECISIONS、spec 快照、勘誤可選、不單獨追蹤）

### 3.I observability follow-up（018、非 blocker、spec 容許/正確設計）

- [ ] **postgres dashboard docker 空態**〔018 U3、low/cosmetic〕：community 板 grafana 9628 的 `release`／`instance` template var 依賴 k8s label（kubernetes_namespace/release）、docker 下 postgres_exporter v0.19.1 不 emit→該類 filter 面板空態〔核心 pg_up/連線/DB stats 仍出圖、spec C-V-6「panel 有資料/正確空態」容許〕。欲消空面板：改 docker 友善板（grafana 12485）或重寫變數 query（`label_values(pg_up,instance)`）。
- **request-completion 無認證請求 log 噪音**〔018 U1、by-design 非待辦〕：FR-006「每請求一行」使所有無認證請求亦輸出一行 INFO log——尤其 `/health`（docker healthcheck）與 `/metrics`（prometheus scrape、metrics profile 啟用時每 15s）〔loki 72h+opt-in 已界範圍〕;如噪音過大可選 subscriber path 過濾〔權衡 trace_id join 完整性〕。
- [ ] **spec as-built 全面校正**〔018、doc〕：data-model §1.3 noDataState（5xx as-built=OK）／tasks T019／C-V-4 contract（已部分校正會假失敗的命令）留 `/speckit-analyze` 批次對齊 as-built。

---

## 4. 跨 feature 待驗證項 / 未來版本實現

> 兩用途：**(a) 跨 feature 待驗證項**（目前無）；**(b) 未來版本實現**＝明確【非 rev3 v1 範圍】的長期項（需真 prod 環境/拓樸、scale v1 不會到、已決不做 v1、或排程 future feature）。與 §3 區別：**§3＝本版剩餘、觸發/反應時做（波4 可能命中）**；**§4.2＝未來版本才實現、長期追蹤**（仍隨 SOP 注入、不遺失）。§3.H 雜項內亦有同性質項（Redis 熱快取/login fallback/dispatcher/pruneNullParams）、保留壓縮原處不重列。

### 4.1 跨 feature 待驗證項

（目前無）

### 4.2 未來版本實現（非 v1、長期追蹤）

- [ ] **prod 部署前 TLS/拓樸**（需真 prod 環境）〔001/013〕：`front_nginx_certs` 是否 `external:true`（拍板項、prod-deploy 時定）／operator 填 `trust-model.toml` 實際拓樸（my_public／cloudflared ingress；CF 官方 IP 段 nginx geo ↔ trust-model.toml 兩處同步、漂移風險、評單一來源）
- [ ] **prod 多副本**〔014〕：research §D 明示不做 v1；真橫向擴展待 nginx LB＋共用 DB/Redis（dev rust-api-2 invariant 已驗、prod nginx 仍單一 proxy_pass）
- [ ] **審計 scale 兩項**〔012/015/017〕：模糊 LIKE seq-scan→`pg_trgm` GIN（C-2、需 CREATE EXTENSION+migration、規模增長再做）／archive 表 retention/purge（C-5、purge spec 明示不做、log-retention ⚠️n 家族、obs波或量大時）
- [ ] **alt-login 4 流程 stub**（排程 future feature、⚠️m、post-波3 v1-completeness slot）〔原 §3.D〕：code-login／register／reset-pwd 後端 stub（service+handler+route、復用 hash/JWT）／bind-wechat（前端空殼＋真 OAuth、最低 v1 價值）／⚠️c alova-demo 完整包（sendCaptcha/verifyCaptcha/`/auth/error`、排前確認真缺端點）；前端 3 表單已完整、後端 4 全缺；接地見 [DECISIONS §1](INTEGRATION-DECISIONS.md) ⚠️m
- [ ] **obs alert notification 投遞 channel**（FR-017 v1 明確排除、future feature）〔018〕：波 4 已 provision 3 baseline grafana alert rule（rules-only、條件成立轉 Alerting、僅介面狀態可見）;v1 **不投遞**通知。未來版本加 grafana contact point + notification policy（需 channel creds：email SMTP／webhook／IM bot）;brainstorm §5／spec Out-of-Scope defer，與 alt-login 同屬 v1-completeness 後排程 feature

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 29**:①flat-in-main 沿用｜② C+ typings-as-oracle｜④僅 join 表加 FK｜⑤凍結邊界=archetype+行為島+碼表入憲｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️d redis tag 建時 pin 數字版｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️g 受控參照 rev2 source｜⚠️i MODAL-WIRING 五用途全授+BUILD-CONFIG 不收錄｜⚠️j rust-api 沿倉換分支｜⚠️k migration 短編號 mNNN_<name>｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings｜⚠️s fork-delta 雙模式(原行註解保留+rev3-inline 標記)｜⚠️t schema 波 0 一次全建(rev2 終態 squash 基線+delta 顯式分離;seed 口徑 92 列/6 表勘誤 2026-06-13)｜⚠️v casbin_rule 委派式建表+adapter 併入 002(sub-crate 刀消解)｜③ B=`system_settings` 第一刀(2026-06-16)｜⚠️a perf 保守預設(p95 300/500/1s・99.5%)｜⚠️b 審計讀端 做+波2 殿後｜⚠️o application-RI hybrid(intra 下沉 facade/跨 facade·restore 留 handler)｜⚠️u §IV 第10題 不採納｜⚠️x endpoint_lint 波0 豁免移波1｜⚠️y biz-msg i18n A(前端譯·msg=key;規約於 003-envelope 落定〔4 根+文法+13 碼 key+兩端接線+locale 外包 backend.〕·刀1+ 僅套用)｜⚠️aa BASE-WEB-I18N-WIRING ★ 軌道(constitution §III amend v1.1.0;授權 i18n inline 接線：service/request 攔截器/locales backend 命名空間/app.d.ts Schema)｜⚠️ab constitution §I.3 措辭 PATCH(釐清 msg 載 i18n key 對齊 ⚠️y、v1.1.1)｜⚠️ac constitution §I.6「無 retrofit」釐清=archetype 審計欄;既有表 domain forensic 刻意可逆演進放行(PATCH v1.1.2、013 analyze C1)｜⚠️m alt-login 排程＝**重議→延後出波3**(2026-06-22、user 親決 C;alt-login 4 流程 stub〔含 captcha〕移 post-波3 v1-completeness slot、§3.D;#13 v1-stub-mode 不變、僅 re-schedule、§11.13 排程性拍板)

**009-user clarify／as-built（spec.md ## Clarifications／contract §3.2;非 ⚠️ 碼級）**:self-lock 防自鎖對稱守門(禁超管自我移除超管角色/自我停用→2222 整筆拒)｜批次刪缺漏 idempotent skip(已不存在/已刪 id 靜默略過、cannot-delete-self 仍獨立整批拒)｜ILIKE 處方校正(`PgExpr::ilike().escape()` runtime 失效〔sea-query 0.32.7 escape hack 不含 pg ILIKE〕→改 `LOWER(col) LIKE ESCAPE`、權威見 user-management-contract §3.2 供 Role/Menu 刀繼承)

**010-menu clarify／as-built（spec.md ## Clarifications／menu-management-contract;非 ⚠️ 碼級）**:批次刪父子整批拒(逐項獨立驗證、批內任一 protected/有 active 子〔即使子同批被選〕即整批拒、no-partial、不做批內 cascade/排序)｜retroactive hasAuth gating 含 user/settings(user 頁 user:* gate〔code 已 seed〕、system-settings skip〔無 code+super-only moot〕)｜route store rev3-inline 例外(dynamic 分支合併前端 builtin 常數路由 login/403/404/500、修 FR-002／R-cr 預示缺口、user 拍板 option 1;C-V-11 零回歸註記為授權例外)

**011-role clarify／as-built（spec.md ## Clarifications／role-management-contract;非 ⚠️ 碼級）**:menu-auth only(D1、button-auth/endpoint-auth＋policy 治理機留波3)｜Role×Menu 治理姿態＝DB-first 合規(D2、★ B1 校正後——直寫 casbin_rule＋同交易原子審計＋②protected-reject 整批拒＋寫後 load_policy reload、絕無 MgmtApi;archive/restore/un-protect/PolicyMutated-優化/publish-watcher 治理機留波3)｜delete guards 種子+使用中+自身(D3、批次整批拒)｜as-built:net-new facade `sys_casbin_rule`(set_role_dimension DB-first)＋`sys_user_role::count_users_by_role_id`;id↔route_name 經 sys_menu facade(orphan skip);roleId/menuIds 維 number 域(⚠️r);2 review-minor 修(set_role_dimension dedup desired 防重複 menu_id 撞 UNIQUE／SetDimensionError #[allow(dead_code)] payload);2 holistic nit 修(G1 role_home live op-log 斷言加 trace_id 守門非冪等／N1 C-V-7 method 對齊 DELETE)

**013-xff clarify／as-built（brainstorm 拍板＋實作期 user 親決;非 ⚠️ 碼級）**:C3 Tier-1 CDN 錨不硬 gate(維持位置錨、防注入靠網路層主防線+CDN_ANCHORED≠CDN_VERIFIED in-band 訊號)｜C2 四欄全顯示(序 ip_confidence→peer_ip→real_ip→x_forwarded_for)｜C1 三模糊(real_ip/peer_ip/x_forwarded_for)+一下拉(ip_confidence)篩｜★ op-log 四欄補滿 4/4(實作期 user 親決「補滿 4/4」、反轉 D7「不動 16 facade」設計＝net-new AuditMeta bundle thread operator xff/confidence 過 ~15 facade、AuditOperator 維持 Copy)｜⚠️ac constitution §I.6 釐清背書 m006 ALTER 合規演進(已列已決 28)

**015-policy clarify／as-built（A 拍板 user 親決 2026-06-22;非 ⚠️ 碼級）**:**A un-protect/re-protect 不做**＝受保護核心授權維持不可經 UI 撤銷(防誤鎖核心存取;§4.2-faithful、做它須 §V.2 amend ② protected-reject)｜as-built:revoke→archive-move(同 txn 原子、可復原非硬刪)＋restore 三態(Applied/NoOp/NotFound、created_at 跨表 nullable→NN `unwrap_or(now)` coerce)＋PolicyMutated gate(updateRoleMenu **由 reload-on-changed 改 reload-on-Applied【含空-diff、§4.2 ③ 不優化、調整 011、user 確認】**、restorePolicy Applied→reload/NoOp·NotFound→skip)＋跨副本 `spawn_policy_watcher`(嚴格鏡像 014、復用 Redis 基建/`CASBIN_INVALIDATE_CHANNEL`)＋回收桶 UI(restore 鈕無 button-policy 種子、**不以假碼 hasAuth 隱藏**、後端 require_policy 為唯一安全邊界保 SC-006)｜零 migration、零新 crate(archive 表/seed 全波0已備)｜★ elegant-router 新 view→自動生成 route 註冊 4 檔+route.manage_policy-archive i18n(建檔當下看不到、主線最終 checkpoint 接住、見 memory)

**016-button-endpoint clarify／as-built（4 拍板 user 親決 2026-06-22 brainstorm;非 ⚠️ 碼級）**:**scope C＝button＋endpoint 完整 runtime 編輯**(補完三維 RBAC)｜**un-protect 不做**(延續 015 A、endpoint 15 protected 不可經 UI 撤、§4.2-faithful)｜**回收桶 v2-推導**(dimension 由 v2 推導 menu|button=原值/HTTP method→endpoint、不改 archive_reason)｜**endpoint 鎖出靠既有 15 protected endpoint seed**(恢復路徑、零 migration、無硬鎖出)｜as-built:button＝reuse `set_role_dimension("button")`＋`all_buttons` 自 sys_menu.buttons JSON registry;**endpoint＝net-new `set_role_endpoints` (path,method) 雙鍵 diff＝真實 (v0=role,v1=path,v2=method) enforce 列〔DELETE 按 id、protected-reject 任何寫前、★絕無 v2='endpoint' 平行編碼、治理 helper 全復用 015〕**;`AS_BUILT_ROUTES` 37→43+M2 雙向 registry assertion〔`ALL_ENDPOINT_POLICIES`==registered policy-governed〕;base-web MODAL-WIRING (c)〔button un-mock+endpoint-auth-modal 新建+第三鈕〕;typings 收斂 fold-in〔RoleListItemRev3/User honest 讀型、新 rev3 wrapper 非改 frozen〕;roleId 維 number 域(⚠️r);3 LOW 不阻擋見 §3.B/§3.H

**017-audit clarify／as-built（brainstorm 5 拍板＋spec.md Q1 clarify、user 親決 2026-06-23;非 ⚠️ 碼級）**:**D1 CSV 匯出範圍**＝三表(operation/access/login)+當前篩選+cap 1萬列｜**D2 角色 delta 覆蓋**＝addUser+updateUser+停用/刪除 全生命週期(三寫端 create/update/soft_delete)｜**D3 current_session_id**＝保留不遮蔽(forensic session 關聯、非 redact;結 §3.C「redact 評估〔005〕」開項)｜**D4(工程拍) C-1 filter UX**＝class 下拉與既有精確值並存(AND、非取代)｜**D5(工程拍) C-3 機制**＝approach B query-param 變體+CSV-in-envelope(否決 A 新端點〔需 R_SUPER policy seed=migration〕／raw text-csv〔token 在 localStorage、browser nav 無 auth〕)｜**Q1 clarify(spec.md)**＝op-log CSV roles_before/after 加專屬兩欄(自前後快照抽)、payload 完整內容仍留獨立欄｜as-built:零 migration/端點/crate、Constitution 9/9、5 執行單元 Workflow 驅動、CDP 抓修 class filter label i18n(filter.statusClass placeholder→col.statusClass 名詞);as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)

**開放 9**(依最晚決策點分組):
- 波 1~3:⚠️m alt-login 入波(波3排程前)｜⚠️w login lockout(做、刀位/設計待排程;消費 audit-overlay 的 sys_login_attempt 索引)
- 不阻塞/觸發時:⑥a-d 新能力包｜⚠️h 排程重議｜⚠️l settings 多 key｜⚠️n log retention

---

## 6. 軌道授權快查(SOP 注入用)

> 完整定義與 ★ 軌道 spec 義務（file:line＋upstream 衝突評估）見 DESIGN §9.4。

| 軌道 | 等級 | 範圍一句話 |
|---|---|---|
| BASE-WEB-ADAPT | L1+L2 預設可動 | `.env*`＋typings 新檔（新增為主、禁刪既有 type/field） |
| BASE-WEB-WRAPPER | L3 預設可動 | `service/api/rev3-*.ts` 一律新檔;不改既有 auth/route/system-manage.ts |
| BASE-WEB-BUILD-CONFIG ★ | L4 已授、未動用 | `build/plugins/router.ts` pageExcludePatterns、嚴格限隱藏 demo menu（⚠️p 拍板後議題消解） |
| MODAL-WIRING ★ | L4 五用途 (a)~(e) | `views/manage/**` inline:接線/hasAuth gating/新權限 modal/復原控制/新管理頁;**絕不擴張到其他 inline** |
| RUSTAPI-SOURCE-ISOLATION | rust-api 整棵樹 | 全新寫;設計繼承、code 不拷貝;research 不准 grep rev1 source |

---

## 7. 已完成里程碑

完整 commit 里程碑歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)(append-only、不在 SOP 注入,避免本檔膨脹)。

§1「最新進展」滾動最近 2 條;歷史在 MILESTONES.md 永久保留。歸檔流程見 [CLAUDE.md §7.5](../CLAUDE.md)。
