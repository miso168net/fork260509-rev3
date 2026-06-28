# Tasks: IP 存取控制閘（022-ip-access-control）

**Input**: Design docs from `specs/022-ip-access-control/`（plan.md／spec.md／research.md〔D1-D11〕／data-model.md／contracts/verification-commands.md〔C-V-0~14〕／quickstart.md）
**Branch**: `022-ip-access-control`
**Tests**: TDD requested（CLAUDE.md §3 + spec §7）→ 含測試任務（純函式 test-first；wiring/形狀由 live 測 + C-V acceptance 覆蓋）。

## Format: `[ID] [P?] [Story] Description`
- **[P]**＝可平行（不同檔、無未完相依）。**rust 任務一律不標 [P]**（共用 cargo target、§3 全程 serial）；唯 base-web typings/service 可 [P]。
- 路徑：rust-api worktree `rust-api/...`；base-web worktree `base-web/...`。

## Execution notes（交 階段 2 superpowers:executing-plans + Workflow）
- rust build/test 在 rust-api 容器內 `docker exec`（host 無 cargo）；live `#[ignore]` 測帶 `DATABASE_URL`+`REDIS_URL`〔/run/secrets〕+`--test-threads=1`；改 `.rs` 後 force-touch 防 /mnt/d stale-mtime；rust 全程 serial。
- base-web commit `--no-verify`（dev alpine pre-commit 必失敗、§memory）；加 i18n 鍵後 `restart base-web` 防 vite stale-locale。
- **★ 絕不 push/merge**（worktree commit 只 local、收尾才 finishing-a-development-branch）；逐單元邊界 bump submodule pin（§4.1 S9）。
- **1 migration（m007）/ 6 新 route / 0 新 workspace crate（arc-swap 提升既有 transitive）**；blocked reuse `PermissionDenied`(5003/403)、不新增 13-碼。

---

## Phase 1: Setup（前置）

- [ ] T001 確認 dev stack healthy（`docker compose -f docker-compose.yml -f docker-compose.dev.yml ps`、含 **redis-stack**）、Super 登入 0000；C-V-0 baseline（`sys_ip_rule` 待建、`RCLI KEYS 'ipgate:*'`＝空、`RCLI KEYS 'lockout:reset:*'`＝空）；`rust-api/server/Cargo.toml` 提升 `arc-swap = "1.9"` 為 direct dep（已 Cargo.lock 1.9.1 transitive、零 churn）、容器內 `cargo build -p server` 綠（C-V-0）

---

## Phase 2: Foundational（阻斷全 US — U1 rust 地基：013 real_ip + sys_ip_rule + RuleSet/ArcSwap/watcher）

- [ ] T002 [test-first] 純函式測 in `rust-api/server/src/audit_ctx.rs`（`#[cfg(test)]`）：`resolve_client_ip` **tunnel fallback**（`conf==Fallback` + `peer ∈ tunnel` + `CF-Connecting-IP` → real_ip=cf_cip）＋**★ 反偽造（B2）**（peer ∈ internal 但 ∉ tunnel + 偽 cf_cip → real_ip ≠ cf_cip）；**既有 `resolve_cases_*`/`apply_cf_overlay` 測不動＝零回歸**（C-V-1/9）
- [ ] T003 `TrustModel` 加 `tunnel: Vec<IpNetwork>` 欄 in `rust-api/server/src/config.rs`（仿 `internal_default` parse）＋ `deploy/trust-model.toml` 加 `[[tunnel]]` 範例（窄 cloudflared origin〔127.0.0.1/::1〕、註解「繞 nginx 直連 ingress、非整個內網、B2」）
- [ ] T004 `resolve_client_ip` tunnel fallback impl in `rust-api/server/src/audit_ctx.rs`（make T002 pass）：在現有 peer-gate→Tier-1→Tier-2 後，`conf==Fallback && peer∈tunnel && cf_cip 合法` → real_ip=cf_cip；**現有 nginx+CF 路徑（XFF 有 client）零改、零回歸**（D5）
- [ ] T005 entity `entity::sys_ip_rule` in `rust-api/entity/src/sys_ip_rule.rs`（`id` bigserial／`cidr: IpNetwork`／`rule_type: String`／`order: Option<i32>`〔`column_name="order"`〕／`description: Option<String>`／created_at·by·updated·deleted 稽核+soft-del；+`AuditSerialize`）
- [ ] T006 migration `m007_create_sys_ip_rule` in `rust-api/migration/src/`（+ 註冊 `lib.rs`）：`execute_unprepared` CREATE TABLE + **partial unique** `(cidr,rule_type) WHERE deleted_at IS NULL`（沿 m001:753-766）+ casbin seed **6 p-policy**〔`('p','R_SUPER',path,method,'','','',false)` × getIpRuleList/addIpRule/updateIpRule/deleteIpRule/restoreIpRule/unlockLogin〕+ menu policy `('p','R_SUPER','manage_ip-rule','menu',...)`；`down` 反序（DROP TABLE + 移 casbin seed）；up→down→up 綠（C-V-12）
- [ ] T007 [test-first] 純函式測 in `rust-api/server/src/ipgate.rs`（`#[cfg(test)]`）：`decide(ip,&RuleSet)`（白>黑>default-allow、**白優先即使黑亦命中**）／`in_set(ip,STRUCTURAL_EXEMPT)`（loopback/私網 v4/v6→true、公網→false）／`should_flush(flushed_exists)`／restore 衝突守門／寫端自鎖判定（C-V-1）
- [ ] T008 facade `sys_ip_rule` in `rust-api/server/src/model/facade/sys_ip_rule.rs`：`load_active()→(Vec<IpNetwork> allow, deny)`〔`find_active()` 分兩袋、閘用〕／`list(page,size,filter)→(records,total)`〔**hybrid `find()` 含已刪 + 分頁/filter + `ORDER BY (deleted_at IS NULL) DESC, order ASC, id ASC` + 每列 `deleted` bool**〕／`create/update/soft_delete/restore(...,AuditMeta)`〔同 txn op-log、沿 sys_menu〕；CIDR 模糊搜尋沿 `ip_host_like`
- [ ] T009 `rust-api/server/src/ipgate.rs`：`pub struct RuleSet{allow,deny:Vec<IpNetwork>}` + `STRUCTURAL_EXEMPT: &[IpNetwork]` const〔127/8·::1·10/8·172.16/12·192.168/16·fc00::/7〕 + `load_ruleset(db)→RuleSet`（DB 錯→空集 fail-OPEN）+ `decide()`（make T007 pass）
- [ ] T010 `AppState` 加 `ip_rules: Arc<ArcSwap<RuleSet>>` in `rust-api/server/src/state.rs` + boot `load_ruleset`→`ArcSwap::from_pointee` in `rust-api/server/src/main.rs`
- [ ] T011 `spawn_ipgate_watcher` in `rust-api/server/src/main.rs`（**鏡像 `spawn_settings_watcher`**：sub `ipgate:invalidate`→重讀 DB `load_ruleset`→`ip_rules.store`、斷線 backoff、redis-down 不啟）

---

## Phase 3: User Story 1 - 依來源黑名單封鎖（P1）🎯 MVP（U2 rust 閘）

**Goal**：全站每請求 `ipgate_mw` 對 real_ip 比對：path/結構豁免→白→黑(阻擋 403+②c)→default-allow；被封以有界成本最早期擋下、零每請求 DB/redis。
**Independent Test**：加 deny 規則涵蓋 TEST-NET→該段每請求 403/5003、未列放行、被封洪水 psql 不成長＋②c 節流 obs。

- [ ] T012 [US1] `ipgate_mw` middleware in `rust-api/server/src/ipgate.rs`：path∈{/health,/metrics}→放行；`ip=req.extensions().get::<RequestContext>()`〔**.get() Option、無 ctx→fail-OPEN 放行；★絕不用 mandatory `Extension` extractor**〕；`in_set(ip,STRUCTURAL_EXEMPT)`→放行；`rules=ip_rules.load()`；`allow.any(contains)`→放行；`deny.any(contains)`→§T013+`Err(AppError::PermissionDenied)`〔5003/403〕；else default-allow
- [ ] T013 [US1] ②c blocked 節流 obs in `rust-api/server/src/ipgate.rs`（T012 deny 路徑內）：`incr("ipgate:blocked:{matched_cidr}",ttl)`→`should_flush(get(ipgate:flushed:{cidr}).is_none())`→`take_suppressed`+`tracing::warn!(target:"security.ipgate",matched_cidr,blocked=n,...)`→loki+`set_ex(flushed,60)`（**復用 021 redis incr/take_suppressed**）
- [ ] T014 [US1] wire `.layer(ipgate_mw).layer(audit_mw)` in `rust-api/server/src/main.rs`（ipgate_mw audit_mw 內側、router 外、全請求 cover）
- [ ] T015 [US1] live `#[ignore]` 測 in `rust-api/server/src/ipgate.rs`（需 DB+Redis、`--test-threads=1`）：load_active/watcher 重載 + 閘對真 ruleset（deny→Block、allow→Allow、default-allow、結構豁免放行、②c 節流 ≤1/60s）
- [ ] T016 [US1] acceptance C-V-2/4/10（curl/psql/redis-cli + logs）：deny→403/5003、default-allow、loopback·私網·/health·/metrics 豁免、②c `security.ipgate` 節流、**未認證被擋 0 DB 寫**（psql sys_access_log 不成長 proxy）

**Checkpoint US1**：黑名單封鎖 + default-allow + 結構豁免 + ②c（MVP）；主線 bump rust-api pin。

---

## Phase 4: User Story 2 - 白名單放行 + 跳登入鎖定（P2）（U2 rust 閘）

**Goal**：白名單優先放行（gate 已含、US1）+ 白名單來源跳 021 lockout（L0 seam）。
**Independent Test**：白>黑同段放行；白名單來源 >5 失敗不鎖。

- [ ] T017 [US2] L0 seam in `rust-api/server/src/handler/auth.rs`（:271 seam）：login 起手 `if let Some(h)... state.ip_rules.allow.any(contains ctx.client_ip) → 跳過 021 L1/L2 lockout`（白名單同源 `state.ip_rules`、兌現 FR-012）
- [ ] T018 [US2] acceptance C-V-3（curl/redis-cli）：白>黑同段放行；白名單來源連送 >5 失敗→仍可嘗試（不鎖、`lockout:user` 未設）；非白名單對照→第6次 2222（021 不變）

**Checkpoint US2**：信任來源免被 account-DoS 鎖死；主線 bump pin。

---

## Phase 5: User Story 3 - 系統管理 IP 名單 CRUD（P2）（U3 rust + U4 base-web）

**Goal**：系統管理頁 CRUD（含已刪檢視+Deleted欄+搜索分頁+復原+寫端自鎖）。
**Independent Test**：CRUD+復原（衝突拒）+ 搜索分頁；加自己 ip deny→2222。

- [ ] T019 [US3] 5 CRUD handler in `rust-api/server/src/handler/system_manage.rs`：getIpRuleList〔分頁+filter+含已刪+`deleted` bool〕/addIpRule/updateIpRule/deleteIpRule(soft)/restoreIpRule〔衝突守門→2222〕；DTO（camelCase query + PageRes）；★ add/update `deny` 寫端自鎖檢查（命中 `ctx.client_ip`→2222 `biz.ipRule.selfLock`）；同 txn op-log；改規則後 `publish ipgate:invalidate`
- [ ] T020 [US3] wire 5 CRUD route + `require_policy(path,method)` in `rust-api/server/src/main.rs`（lint 中繼；最終 6 route 全綠於 T028）
- [ ] T021 [P] [US3] base-web typings in `base-web/src/typings/api/system-manage.d.ts`：`IpRule`/`IpRuleSearchParams`/`IpRuleListItem`〔含 `deleted`〕（BASE-WEB-ADAPT、**三端對齊** rust DTO↔typings↔view 防 type-lie）
- [ ] T022 [P] [US3] base-web service wrapper in `base-web/src/service/api/rev3-system-manage.ts`：6 fetch wrapper（含 unlock、對接 T026）（BASE-WEB-WRAPPER 新檔、view 直接路徑 import）
- [ ] T023 [US3] base-web view `base-web/src/views/manage/ip-rule/index.vue`：列表〔cidr/rule_type tag/order/description/**Deleted NTag**/時戳、搜索 比照 user、分頁、active 列 編輯/刪除、已刪列 **復原鈕** 比照 menu〕+ add/edit modal〔cidr 驗證/rule_type 下拉/order/description〕（MODAL-WIRING；**elegant-router 新 view 重生 4 route 檔**、commit 含 `components.d.ts`/route 檔）
- [ ] T024 [US3] base-web i18n in `base-web/src/locales/langs/{zh-cn,en-us}.ts` + `typings/app.d.ts` Schema：`backend.biz.ipRule.{selfLock,conflict,notFound}` + `page.manage.ipRule.*` + `route.manage_ip-rule`（**Schema 先後 locale、同 commit**、沿 memory base-web-i18n-schema-iii）
- [ ] T025 [US3] acceptance C-V-7/11（CDP browser、curl≠modal）：列表含已刪+Deleted欄+搜索分頁+復原（衝突→2222 toast）+ 寫端自鎖（加自己 ip deny→2222 toast 在地化）；**restart base-web 防 vite stale-locale、斷言 toast 非 raw key**

**Checkpoint US3**：CRUD 管理頁可用；主線 bump rust-api + base-web pin。

---

## Phase 6: User Story 4 - 管理者手動解鎖（P3）（U3 rust + U4 base-web）

**Goal**：手動解鎖（reset-marker per-dim、不刪 append-only 列）。
**Independent Test**：被鎖帳號→解鎖→可登入；both-dims 須兩維皆解。

- [ ] T026 [US4] unlock handler `unlockLogin` in `rust-api/server/src/handler/system_manage.rs`：`require_policy`；清 `del lockout:{dim}:{value}` + suppressed/flushed companions + `set_ex(lockout:reset:{dim}:{value}, now_unix, 窗)`（沿 `set_revoked` 存值範式）；op-log
- [ ] T027 [US4] 021 L2 gate **per-dim since** in `rust-api/server/src/handler/auth.rs`（:316-337）：`since_ip=max(now-窗, get(lockout:reset:ip:{ip}))`、`since_user=max(now-窗, get(lockout:reset:user:{name}))`，各餵 `count_failed_by_ip_since`/`count_failed_by_user_since`（**B3 單→雙拆分**、reset 前失敗不計）
- [ ] T028 [US4] wire unlock route + `require_policy` in `rust-api/server/src/main.rs`；**lint 最終全綠**：`AS_BUILT_ROUTES` 44→**50**、`ALL_ENDPOINT_POLICIES`（`enforce.rs`）36→**42**、main.rs==registry==seed 三源一致
- [ ] T029 [US4] base-web 解鎖 modal in `base-web/src/views/manage/ip-rule/index.vue`：dimension(user/ip)+value（both-dims 提示）+ i18n（`page.manage.ipRule.unlock.*`）
- [ ] T030 [US4] live `#[ignore]`/acceptance C-V-8：reset-marker per-dim 解鎖→被鎖 user 下次正確密碼即 0000；**per-dim 獨立**（解 user 維不動 ip 維）；both-dims 鎖須兩維皆解

**Checkpoint US4**：手動解鎖 + per-dim；主線 bump pin。

---

## Phase 7: User Story 5 - 韌性/安全/零回歸（P3）— cross-cutting 驗證

**Goal**：fail-OPEN、結構豁免、CF Tunnel real_ip 正確+反偽造、零回歸——皆獨立可驗屬性。
**Independent Test**：(a) 規則載不進→放行；(b) CF Tunnel 直連 real_ip 正確+反偽造；(c) 既有流程零回歸。

- [ ] T031 [US5] fail-OPEN 驗（C-V-5）：規則載不進（stop redis / 空 ruleset）→全放行（含被封段）、auth/casbin 仍守；碼面 grep 確認 gate 全 fail-open 路徑（`.get()`/`load()` 無 panic/mandatory extractor）
- [ ] T032 [US5] CF Tunnel 驗（C-V-9）：tunnel 正路（peer∈tunnel+cf_cip→real_ip=cf_cip）+ **反偽造**（非 tunnel peer 偽 cf_cip 不採信）+ **既有 `resolve_cases_*`/`apply_cf_overlay` 全測零回歸**
- [ ] T033 [US5] 零回歸驗（C-V-14）：未鎖正常 login（0000/1000/2222 toast `auth.login.locked` 不變）、既有 auth/casbin/access-log/op-log 行為不變、全 rust 既有測綠

---

## Phase 8: Polish & Cross-Cutting

- [ ] T034 lint + prod gate（C-V-12/13、容器內 + docker）：`cargo test -p server --test entity_access_lint` 綠（sys_ip_rule 只經 facade、handler/main 零 path-root `entity::`）／`--test endpoint_coverage_lint` 綠（44→50、36→42）／`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（新 migration+route、multi-stage 無破口、arc-swap 既有 dep）／migration up→down→up 綠
- [ ] T035 **CF Tunnel 拓樸文件化**：`docs/INTEGRATION-DESIGN.md` 新節「部署入口拓樸/信任邊界」（3 ingress〔直連 nginx／CF→nginx／CF Tunnel→rust-api 直連〕+ 各信任邊界 + real_ip 來源 + 窄 TUNNEL_ORIGIN；§1.0「nginx 單一入口」勘誤）／`INTEGRATION-DECISIONS.md` §1 新碼 **⚠️ae**（CF Tunnel 繞 nginx 支援 + 013 窄 CF-CIP fallback + 022 拍板全文）／`CLAUDE.md` §8.2 第4啟動模式 tunnel／`INTEGRATION-CHECKLIST.md` §4.2 分清模式 1（CF→nginx）/2（Tunnel 繞 nginx）（**§錨非揮發行號**）
- [ ] T036 清理 throwaway：psql `DELETE FROM sys_ip_rule WHERE cidr <<= '203.0.113.0/24' OR ...` + redis `DEL ipgate:* lockout:*zz022* lockout:reset:*` + `DELETE sys_login_attempt WHERE attempted_user_name LIKE 'zz022_%'` → 回 baseline
- [ ] T037 final holistic review（fresh-agent 冷讀）：spec FR-001~016 / SC-001~009 逐項對照 + Constitution 9/9 複核 + 全 rust 測 run（零回歸）+ **013/021 riders 獨立零回歸確認**（cold-review B1〔零-DB 限未認證〕/B2〔CF-CIP 窄信任+反偽造〕/B3〔per-dim reset〕/B4〔riders 隔離驗收〕已修驗）+ §I.7 fail-OPEN/§I.6 archetype 一致性
- [ ] T038 收尾準備（交 `superpowers:finishing-a-development-branch`）：擬多段式 commit + 進度回填清單（MILESTONES append、CHECKLIST 收尾、DECISIONS §1 登 ⚠️ae 拍板、§6 marker 收刀、013/021 as-built 註記、CF 拓樸 §4.2 提醒）—— **push/merge 需 user 同意**

---

## Dependencies & Story Completion Order

- **Setup（T001）** → **Foundational（T002-T011）** → **US1（T012-T016）** → **US2（T017-T018）** → **US3（T019-T025）** → **US4（T026-T030）** → **US5（T031-T033）** → **Polish（T034-T038）**。
- Foundational 阻斷全 US（013 real_ip / sys_ip_rule entity·facade·migration / RuleSet·ArcSwap·watcher）。
- US1 gate 為 US2（L0 seam 讀 `ip_rules.allow`）與 US3（CRUD `publish` 觸發 watcher）前提。
- **★ lint 全綠須 6 route 全 wire**（migration 已 seed 6）→ T028（US4）為 lint 最終出口；T020（US3）為中繼。
- rust 全程 serial（T002-T034 共用 cargo target）。

## Parallel opportunities
- **僅 base-web typings/service（T021/T022）可 [P]**（不同檔、無 rust 相依）。rust 全 serial（§3）。

## Implementation Strategy（MVP first）
- **MVP＝US1（Phase 1-3）**：黑名單封鎖 + default-allow + 結構豁免 + ②c —— 獨立可交付、封住惡意來源、DoS-resilient。
- 增量：US2（白名單+跳鎖）→ US3（CRUD 管理頁）→ US4（手動解鎖）→ US5（韌性/安全/零回歸驗）。
- 每 phase checkpoint：主線復核 + load-bearing 自驗（容器 cargo build/全 live 測 + acceptance）+ bump submodule pin（§4.1）。

## 執行單元對映（交 階段 2 Workflow 驅動）
- **U1 rust 地基** = T002-T011（013 tunnel fallback + sys_ip_rule entity/facade/migration m007 + RuleSet/ArcSwap/load/watcher）serial 一支。
- **U2 rust 閘** = T012-T018（ipgate_mw + 決策/豁免/fail-OPEN + ②c obs + layer wire + US2 L0 seam）serial 一支。
- **U3 rust CRUD+解鎖** = T019/T020 + T026/T027/T028（5 CRUD + unlock handler + per-dim since + **6 route 一次到位保 lint 綠**〔migration 已 seed 6〕）serial 一支。
- **U4 base-web** = T021-T024 + T029（typings/service/view/i18n + 解鎖 UI）。
- **acceptance（T016/T018/T025/T030/T031-T033）+ Polish（T034-T038）** = 主線邊界 checkpoint + 收口（T035 CF 拓樸 docs / T037 final review / T038 finishing）。
