# rev3 commit 里程碑永久紀錄（INTEGRATION-MILESTONES）

> **append-only、不在 SOP hook 注入**（避免 CHECKLIST 膨脹）。三區、§2/§3 與 CHECKLIST 同號區鏡像對應：
> 「§1 commit 里程碑表」收每筆 docs／feature commit 一行（表尾 append）；
> 「§2」收 CHECKLIST §2 完成波的收縮節（✅ 標題＋blockquote 摘要;批次搬入後 CHECKLIST 永遠聚焦當前波）；
> 「§3」收 CHECKLIST §3 已完成 follow-up 節的細節（批次搬入）。
> 歸檔流程見 [CLAUDE.md §7.5](../CLAUDE.md)。**與 [DECISIONS §2](INTEGRATION-DECISIONS.md) 的分工**：波次 as-built **詳帳**在 DECISIONS §2（權威）；本檔 §2 只收 CHECKLIST 的一行式快照歸檔，查波次細節一律去 DECISIONS。

---

## §1 commit 里程碑表

| commit | 日期 | 主題 |
|---|---|---|
| `f8e0728` | 2026-06-11 | Spec-Kit presets / extensions / skills 落地 |
| `f6c4939` | 2026-06-11 | .gitignore 補強 — 排除 Claude 憑證與 fork 子專案 |
| `e006b7c` | 2026-06-11 | CLAUDE.md 從 rev2 改寫為 rev3（身分／⏳ 目標態／port 3XXXX） |
| `8ebce10` | 2026-06-11 | CLAUDE.md 微調 — pre-hook 檔名、§7 跨檔引用改語意錨 |
| `2ec9cda` | 2026-06-11 | 註冊 base-web/rust-api 為 submodule（worktree+submodule 雙重身分落地） |
| `0713db4` | 2026-06-12 | CLAUDE.md 拔除 worktree/submodule 已落地 ⏳ |
| `03a1b01` | 2026-06-12 | bump base-web 到 dd771540 — x_fork.branch-origin.md 分支來源紀錄 |
| `fb87a67` | 2026-06-12 | bump rust-api 到 f73ef10 — x_fork.branch-origin.md 分支來源紀錄 |
| `7fd1ac6` | 2026-06-12 | 設計權威 INTEGRATION-DESIGN-rev3.md 入 docs/ |
| `88f9011` | 2026-06-12 | DESIGN 拍板回填 — 官方權威序＋六項拍板＋對賬修補 |
| `8f66fe0` | 2026-06-12 | graphify rev3 首次建圖（2060 nodes／311 communities／83.7x） |
| `46591c4` | 2026-06-12 | 000：保存 base-web/apifox mock API 捕獲原始資料 |
| `309099d` | 2026-06-12 | base-web standalone dev compose |
| `aea0e18` | 2026-06-12 | 000：補抓 mock 缺口端點＋CDP scripts git-track |
| `e898421` | 2026-06-12 | 000：13 端點對映表＋設計書比對文件落地 |
| `4aa7c89` | 2026-06-12 | INTEGRATION-DESIGN-rev3.md 歸位改名 INTEGRATION-DESIGN.md |
| `4724549` | 2026-06-12 | C 方案落地 — DESIGN 凍結藍圖＋INTEGRATION-DECISIONS.md 伴生活帳 |
| `4300b54` | 2026-06-12 | CHECKLIST/MILESTONES 落地 — 注入活檔成形、波 -1 文件層收齊 |
| `9d8303f` | 2026-06-12 | 外檔引用全面查驗修正 — ⏳ 同步現實＋DESIGN amendment 動線勘誤 |
| `e8e1a99` | 2026-06-12 | §7.1 改定 — rev2 研究三檔不移植不重作 |
| `ed2a789` | 2026-06-12 | SessionStart hook 落地 — 自 rev2 原樣承接（零改動） |
| `71cdd61` | 2026-06-12 | §7.5 歸檔 — MILESTONES append＋CHECKLIST 進展滾動 |
| `4ec9cc6` | 2026-06-12 | MILESTONES 三區化收整 — user 鏡像設計補一致性 |
| `612ddcd` | 2026-06-12 | 波 -1 constitution 重鑄項加 §V.2 提案位置搬家註記 |
| `167db96` | 2026-06-12 | **constitution-rev3 v1.0.0 凍結** — 13 項拍板融入（含 ⚠️s fork-delta 紀律）；波 -1 出口四項全綠、**波 -1 全完成** |
| `c9ffad5` | 2026-06-13 | **001-infra-deploy 全綠收刀（波 0 第一刀）** — master compose 5 service＋migrate gate＋dev/prod override＋deploy/ 全套＋rust-api scaffold（worktree `5d69c06`）；C-V-0~8 實機全綠（SC-001~007）、捕獲 redis `--dir` 持久化真 bug 並修；merge --no-ff、feature branch 保留 |
| `9233ae0` | 2026-06-13 | **002-rev2-schema-baseline 全綠收刀（波 0 第二刀）** — 前代 35 支 migration squash 為 4 支基線（m001 schema 11 表終態〔10 手寫＋casbin 委派 vendored adapter＋ALTER 治理欄〕／m002 seed 92 列 6 表〔argon2id 單一 hash〕／m003 user_role FK ×2 RESTRICT／m004 demo 選單 66＋policy 全 R_SUPER）＋sea-orm-adapter 整檔拷入（§I.5、worktree `91cfc80`）；tests/002 四支驗證 scripts（normalize 六規則）＋2 基準檔；C-V-0~9 實機全綠（SC-001~008）、修 m002 兩層 seed drift（id 順序 bug＋normalize 第六規則 row-order 正規化〔user 拍板方案 A、契約留痕 migration-chain.md §3〕）；merge --no-ff、feature branch 保留 |
| `082e366` | 2026-06-16 | **constitution v1.0.0→v1.1.0 amend**（⚠️aa、§V.3 MINOR） — §III 新增 `BASE-WEB-I18N-WIRING ★` 軌道；觸發＝003-envelope `/speckit-plan` Constitution Check Q2/Q7（base-web i18n 接線必改 inline：`service/request` 攔截器／`locales` backend 命名空間／`app.d.ts` Schema；⚠️y 已授權改動本身、但 §I.1 需 §III 軌道才合規）；授權三範圍 (i) 攔截器 msg 翻譯接線〔不改控制流〕(ii) locales backend 命名空間 (iii) app.d.ts Schema backend 型＋helper；走 fork-delta `rev3-inline`；user 親決 A |
| `13a01b1` | 2026-06-16 | **003-envelope 全綠收刀（波 0 第三刀）** — 統一回應信封＋msg-i18n key 規約 scope A 縱切兩端一刀：rust-api(`2d55a38`) `envelope.rs`(Res/PageRes＋IntoResponse)＋`error.rs`(AppError 9 變體凍結碼矩陣、reserved 4 碼型別層無變體＝編譯期 guard、`Biz(Cow)`、無 From<DbErr>/sea-orm〔R7〕)＋`main.rs` .fallback(handler_404)；in-crate 契約測 8 綠（碼/serde 欄序/http 映射/非人話無 CJK/文法 conformance〔US3〕）。base-web(`c2ad92f`、⚠️aa `BASE-WEB-I18N-WIRING ★`、rev3-inline) `app.d.ts` Schema backend 型＋雙語 langs（9 鍵）＋`translateBackendMsg` helper＋`service/request` 4 翻譯點（單一 translatedMsg 共用、:63 includes 守門納入、onError truthy-guard 保 fallback）；零新 npm dep。key 規約 ⚠️y 落定（4 根 common/auth/biz/system＋`<root>.<entity>.<condition>`＋去前綴 wire/前端 backend.）。C-V-0~3 全綠（rust test 8／curl 4040／typecheck＋tsx 10／prod build）、wire 3 端對齊零型謊；merge --no-ff、feature branch 保留 |
| `a1105f0` | 2026-06-17 | **004-soft-delete-infra 全綠收刀（波 0 第四刀）** — L2 entity 層（新 `entity` workspace crate、11 模組 DeriveEntityModel 機械反射 m001／130 欄；tstz→DateTimeWithTimeZone／jsonb→Json／INET→IpNetwork〔with-chrono/json/ipnetwork〕、worktree `698f48a`）＋L4 soft-delete 地基（`SoftDeletable` trait〔lint-clean 純 sea_orm 泛型〕＋3 facade impl〔sys_user/role/menu、entity:: 走 lint 豁免〕＋`find_active`、`a34aa1a`）＋facade 唯一管道守恆 `entity_access_lint`（兩階段 whiten 抹白+path-root `entity::` scan〔前界非 ident 非 `:`〕、scan fn 自測雙證非 vacuous、`e9a6d5c`）＋prod Dockerfile entity Manifest＋Source COPY（outer `cc78264`）；U1 with-ipnetwork 1.86 build 早驗綠〔ipnetwork 0.20.0 入圖、無退 String〕＋inert time 0.3.47 lock 註解校正（`3f87a25`）；C-V-0~3 全綠（build／lint 2 passed／live smoke 1 passed txn-rollback／prod image 158MB）、SC-007 零回歸、holistic review PASS 零 findings；零業務 endpoint/facade 方法/migration（SC-005）；merge --no-ff、feature branch 保留 |
| `98f1f7e` | 2026-06-17 | **005-audit-op-log 全綠收刀（波 0 第五刀；audit ×2 之首＝op-log 刀）** — L4 audit 機制地基：`model/audit.rs`（`AuditOperation`/`AuditOperator`/`AuditEvent`/`AuditSerialize`＋`mutate_in_txn` 泛型 `C:TransactionTrait`〔業務寫＋op-log 寫綁同一 DatabaseTransaction、同時 commit 或同時 rollback〕、純資料層零 `entity::`、worktree `8b5bdde`）＋op-log append-only sink（`facade/sys_operation_log::write_in_txn`、唯一構造 op-log ActiveModel、無 update/delete、archetype B）＋`sys_user` redact（`impl AuditSerialize` 手構 json、`password`→`<redacted>`、Model 無 Serialize derive〔R-C〕）＋單一 `sys_user::soft_delete` proof（`into_active_model`＋§I.6 `deleted_at`/`deleted_by` 成對、no-op 回 `Ok(None)`、worktree `ae9a721`）＋mod.rs 檔頭校正（T001、`3d9578f`）；C-V-0~3 全綠（build／redact 純測 1 passed／atomic live smoke 三路徑〔commit 寫 op-log／no-op 不寫／rollback write-then-Err 業務+審計一起不留、非 vacuous〕1 passed／entity_access_lint 守恆 2 passed）、holistic review 3-lens（FR/SC 覆蓋・原子性〔sea-orm savepoint 源碼實證〕・scope/append-only）mergeReady 零 blocker；零端點/migration/Cargo.toml/新 crate/entity 變動（SC-005）、機制表中立（SC-006）、SC-007 /health 零回歸；merge --no-ff、feature branch 保留 |
| `e279f23` | 2026-06-17 | **006-auth-island-min 全綠收刀（波 0 第六刀＝Auth 島最小段＋runtime 骨幹第一刀）** — runtime 骨幹（`config.rs` secret `_FILE` 優先＋長度/change-me 守門／`state.rs` AppState{db,jwt,enforcer}／`main.rs` boot：connect→`init_enforcer`〔SeaOrmAdapter＋`DefaultModel::from_str` embedded 3-tuple RBAC〕→mount /auth/*＋enforce layer、worktree 經 `87e10ab`）＋auth 機制（`auth/jwt.rs` HS256 雙鑰 sign/verify〔exp/iss/aud〕／`auth/password.rs` argon2id verify／`auth/enforce.rs` `enforce_mw` bearer〔3333 fail-CLOSED〕→is_current〔7777 fail-OPEN、pointer-truth-in-DB〕gate＋`enforce_role_path_method`/`buttons_for_roles` seam）＋facade（`sys_token::insert_token`／`sys_user_role::roles_of_user`／`sys_user::find_by_user_name·set_pointer·current_session_id_of·find_by_id`）＋`error.rs` `From<DbErr>`→Internal；login（`42ce024`：argon2 verify＋簽 access/refresh JWT＋token_hash=sha256(refresh)＋set_pointer+insert_token 同 plain txn 原子〔SC-008〕＋1000 collapse 不洩帳號存在）／getUserInfo（`b9de316`：DB-fresh roles＋casbin v2=button buttons＋User→User01 alias＋userId 字串）。5 執行單元 Workflow 驅動（deps+time-pin `04fc6f8`〔jsonwebtoken9→simple_asn1→time 進真圖、pin time 0.3.37+simple_asn1 0.6.3 配 1.86 MSRV〕→foundation `87e10ab`→login `42ce024`→getUserInfo+enforce/session `b9de316`→final-verify）；C-V-0~6 全綠（build／11 純測〔JWT5·argon2·3·enforce-seam/buttons/union 3〕／entity_access_lint 2／live login·getUserInfo·1000·3333·7777＋psql 原子證／CDP i18n toast「用户名或密码错误」／prod image build `--locked` 加 dep）、holistic spec+quality review 17 FR+9 SC 全 PASS 零 blocker（FR-008 stale-token DB-mutation 活證 claims hint-only）；零 migration/entity/base-web/i18n/compose（SC-009）、SC-007 /health 零回歸；merge --no-ff、feature branch 保留 |
| `96280d8` | 2026-06-18 | **007-audit-overlay 全綠收刀（波 0 第七刀〔末〕＝audit overlay；本刀收齊波 0）** — L3 `xdb` crate 整檔零改拷入（§I.5⚠️v、once_cell workspace dep、criterion/rand dev-tree 入 lock、time 0.3.37/simple_asn1 0.6.3 pin 不動、worktree `2fc0696`）＋L7 `audit_ctx`（`RequestContext`／`resolve_client_ip` XFF trusted-proxy〔peer-gate→rightmost-untrusted→fail-safe、anti-spoof、8 純測〕／`extract_trace_id`／`audit_mw` 全域最外層 operator-gate／`to_audit_operator` op-log threading seam）＋2 append-only facade sink（`sys_access_log`／`sys_login_attempt`、`IpAddr→IpNetwork::from` seam）＋state/config（`trusted_proxy_cidrs` fail-safe 空／`xdb_ready`／`XDB_FILEPATH`）＋main boot `Path::exists` 守門→`searcher_init`（缺檔 warn 降級不 panic、R1）＋`into_make_service_with_connect_info`＋login inner/outer split exactly-one（`15e6491`：not-found/wrong-pwd 同 1000、operator pre/post-identity）＋op-log threading live smoke（`fc4b50e`、T018）；T009 compose env（dev `XDB_FILEPATH=xdb/resources/...`＋`TRUSTED_PROXY_CIDRS` fail-safe）＋T019 Dockerfile xdb COPY（Manifest＋Source〔含 benches〕＋runtime `/app/resources/ip2region.xdb`＋builder `--locked`）。C-V-0~9 全綠（build `--locked`／3 純測 8+5+4／entity_access_lint 2／live login-attempt 成敗各列・access-log operator-gate・真 INET 無 42804・region 内网・behind-proxy 真 client IP・op-log INET round-trip／prod target image build 含 .xdb 11070083B）、holistic review PASS 零缺陷（16 FR＋9 SC 全 MET）；零 migration/entity/型遷移/base-web/i18n/nginx（SC-009）、enforce_mw 未動、SC-007 /health 零回歸；推進 DESIGN §5.9（直連→XFF trusted-proxy、DESIGN-detail 非 Amendment）；**波 0 出口四項達標**（entity_access_lint✅／migration up→down→up✅〔endpoint_coverage_lint ⚠️x 豁免移波1〕／envelope 13 碼✅／login→getUserInfo→enforce✅）→ 波 0 全完成；merge --no-ff、feature branch 保留 |
| `b52dafe` | 2026-06-18 | **008-system-settings 全綠收刀（波 1 第一刀＝system_settings KV 打樋；波 1 全完成）** — 3 全專案首次：(1) 首個 policy-governed 端點——新 `require_policy(path,method)` per-route layer（`from_fn_with_state`、DB-fresh `roles_of_user(db,claims.uid)` 不信 `claims.roles`〔FR-005〕→`enforce_role_path_method`→`PermissionDenied` 5003/403）、`enforce_mw` 本體一行不動（§3.4）＝兩層 auth→authz、5003→403 live 首証（Admin/User GET/POST→403 不洩值）；(2) 首個 007 op-log threading live consumer——update handler 經 `ctx.to_audit_operator(claims.uid)` 取真 operator/IP/trace 餵 `mutate_in_txn`、op-log `operator_ip` 由恆 None→真 INET round-trip（C-V-5 顯式 IpNetwork 203.0.113.7 by-trace 查證＋外層 txn savepoint rollback 不污染 seed）；(3) 立 `endpoint_coverage_lint`（⚠️x 波0 豁免移波1）——鏡像 entity_access_lint 只讀掃描、斷言 registered==as-built registry（5 route）＋policy-governed⊆m002 p-policy seed（非 §7.1 @35 字面）、含 scan_self_test。L4 facade（find_all/find_by_key/update_by_key〔mutate_in_txn 同 txn op-log UPDATE、查無 Ok(None) no-op、entity_id None+key 入 payload〕＋build_update_active_model 純測 seam＋AuditSerialize）＋L5 handler（get_system_settings flat／update_setting 先驗後改：notFound/invalidValue→2222、to_audit_operator 餵）＋L4 require_policy＋L1 main（GET/POST 各 route_layer require_policy＋外層 enforce_mw）＋L8 lint；base-web static 頁（rev3-system-settings.ts WRAPPER 首個 rev3-* 檔／rev3-system-settings.d.ts ADAPT／views/manage/system-settings/index.vue MODAL-WIRING(e) 簡 KV 頁 enum→NSwitch／app.d.ts Schema＋zh-cn/en-us locale backend.biz.systemSettings.*＋route/page key）。4 執行單元 Workflow 驅動（U1 read+require_policy `8e5a024`→U2 update+op-log `4f4952d`→U3 lint `3874182`／U4 base-web `5fdd6f0`＋§2 trim `223bc83e`）；C-V-0~11 全綠（build／純測 value_type+active_model／lint endpoint_coverage+entity_access／live op-log INET round-trip＋policy-gate 5003＋2222×2／CDP toast「更新成功」off↔on／typecheck／prod build／零回歸 perf 讀5.8ms改7.9ms）、holistic 雙 lens ready-to-merge 0 blocking；**零 migration/entity/schema**（m005 MOOT、m002:162-165/251 已 seed）、無新 crate、enforce_mw 未動、base-web 既有檔未動、SC-006/007 零回歸；rust-api `fc4b50e`→`3874182`、base-web `c2ad92f`→`223bc83e`；merge --no-ff、feature branch 保留 |

---

## §2 Roadmap & Phase 狀態 — 完成＋歸檔

>（收 [CHECKLIST §2](INTEGRATION-CHECKLIST.md) 完成波的收縮節〔✅ 標題＋blockquote 摘要〕；波完成批次搬入後 CHECKLIST 該波只留標題＋指標行、永遠聚焦當前波。as-built 詳帳在 DECISIONS §2〔權威〕，本節為收縮節鏡像歸檔。）

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> 機械建構＋constitution 重鑄兩段全交（pre-spec-kit、全落 default branch、無 feature branch）:outer repo＋worktree/submodule 註冊 `2ec9cda`（⚠️j/⚠️q）/ 設計書入檔＋拍板回填＋歸位改名 `7fd1ac6`→`4aa7c89` / C 方案文件體系 DECISIONS+CHECKLIST+MILESTONES `4724549`・`4300b54` / graphify 首建 `8f66fe0` / 000 base-web bootstrap＋13 端點對映 `46591c4`~`e898421` / SessionStart hook 原樣承接 `ed2a789` / **constitution-rev3 v1.0.0 凍結 `167db96`**（13 項拍板融入）。出口四項全綠（session 健檢/獨立 commit/grep rev2 歸零/speckit 可用）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基 ✅ 全完成+已歸檔 (2026-06-18)

> 七刀全收（001 infra-deploy `c9ffad5`／002 schema-baseline `9233ae0`／003 envelope `13a01b1`／004 soft-delete-infra `a1105f0`／005 audit-op-log `98f1f7e`／006 auth-island-min `e279f23`／007 audit-overlay `96280d8`;sub-crate 刀 ⚠️v 消解併入 002/007）。前置拍板 4 項（①flat-in-main／④僅 join FK／⚠️d redis pin／⚠️k mNNN）全拍（2026-06-13）。出口四項達標：dev stack healthy✅・三守恆〔entity_access_lint✅ 004・migration up→down→up✅ 002・endpoint_coverage_lint ⚠️x 豁免移波1〕・envelope 13 碼✅ 003・login→getUserInfo→enforce✅ 006 → 換波 1。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 1 — 第一刀＝`system_settings` 打樋 ✅ 全完成+已歸檔 (2026-06-18)

> 1 刀打樋（merge `b52dafe`）＝最輕 KV entity 跑完 §8.1 全管線、達 3 全專案首次（首個 policy-governed 端點＋require_policy 5003 live／首個 op-log threading live consumer INET round-trip／立 endpoint_coverage_lint ⚠️x）;零 migration、無新 crate;C-V-0~11 全綠、holistic ready-to-merge 0 blocking。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md);D1 波2 選單可見性 follow-up 見 §3.10。

---

## §3 Follow-up Backlog — 完成＋歸檔

>（收 [CHECKLIST §3](INTEGRATION-CHECKLIST.md) 已完成 `### 3.X` follow-up 節，累積數節後批次搬入、原處留收合指標。目前空。）

