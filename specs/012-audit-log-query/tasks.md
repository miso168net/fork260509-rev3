# Tasks: 012-audit-log-query（審計查詢讀端＋審計中心＝波2 殿後刀）

**Input**: Design documents from `/specs/012-audit-log-query/`

**Prerequisites**: plan.md ✅、spec.md ✅（7 US／12 FR／9 SC／6 Clarifications）、research.md（R1 facade list・R2 §5.8・R3 fuzzy・R4 **IP-expr net-new**・R5 names_for_ids・R6 m005・R7 main/lint・R8 wire）✅、data-model.md ✅、contracts/（verification-commands C-V-0~9＋audit-log-query-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS、唯讀、m005 無新業務表）。

> **★ 唯讀刀**：3 讀端純 SELECT、**不寫日誌/不寫 op-log/live 無 cleanup**（異於 011 casbin 寫）。**首個波 2 帶 migration 的刀＝m005 delta**（menu seed＋3 讀端 policy＋menu policy＋operation/access filter 索引、**無新業務表、無 ALTER 既有日誌表、up→down→up 可逆**）。

**Tests**: 純測（filter where 組裝／operator-name 解析／IP-expr builder／日期 parse，若抽純函式、test-first）＋live `#[ignore]`（3 端點分頁/filter／**IP 模糊 host()::text LIKE**／operator by 名／enrich／policy-gate／m005 up→down→up、`--test-threads=1`＋`DATABASE_URL`）＋`endpoint_coverage_lint`(34)＋`entity_access_lint`。base-web `pnpm typecheck`＋CDP。

**Organization**: 依 user story 分 phase。**★ 校正（research）**：m005 delta（無新業務表）；**IP 模糊 `host(col)::text LIKE`＝net-new 無 codebase 先例（R4、U1 facade live 首驗）**；fuzzy 文字 `LOWER LIKE ESCAPE`（非 PgExpr::ilike、沿 009）；operator enrich `sys_user::names_for_ids`（net-new、unfiltered 含已刪）；**唯讀無 cleanup**；wire id number（⚠️r）、3 honest item 型（nullable→`｜null`）；**rust 全程 serial**、build/test **容器內** `docker compose … exec -T rust-api`（改 .rs 先 force-touch；`--test <name>`／`--bin server <filter>` 防假綠）；**live `--test-threads=1`＋`DATABASE_URL`**；base-web commit `--no-verify`；**逐單元兩段式 commit**（worktree→pin、S9）；**§I.4：全程不 push/merge**；**無 .env flip**；base-web frozen 不改（route store/transform/system-manage.ts/auth.ts/request）。**無新 crate／無新 dep**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup

- [ ] T001 親驗前置（research R6）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait` 全 healthy；psql 確認三日誌表現有資料（sys_operation_log/sys_access_log/sys_login_attempt 各有列、含 op-log `entity_table='casbin_rule'` 011 列）＋**審計頁 menu/3 讀端 policy/operation·access filter 索引【尚未】seed**（m005 待建）＋sys_login_attempt 既有 2 索引在＝本刀加 m005 delta、無新業務表/無 ALTER

**Checkpoint**: 環境就緒、三日誌表有資料、m005 待建（baseline 確認）

## Phase 2: Foundational（blocking US1~US7：m005 seed/policy/index＋operator enrich seam）

- [ ] T002 ★ **m005 delta migration** `rust-api/migration/src/m005_audit_log_query.rs`（＋`lib.rs` 加 `mod m005_audit_log_query;`＋`Box::new(...)` 於 m004 後）：`up`（`get_connection().execute_unprepared` raw SQL、鏡像 m002 seed／m001 index）＝① sys_menu `manage_audit`〔parent=subquery `(SELECT id FROM sys_menu WHERE route_name='manage' AND deleted_at IS NULL)`、menu_type=2、route_path='/manage/audit'、component='view.manage_audit'、icon_type=1、i18n_key='route.manage_audit'、"order"、status=1、protected=false〕②casbin_rule 4 列〔`('p','R_SUPER','/systemManage/getOperationLog','GET','','','',false)` ×3〔get{Operation,Access,LoginAttempt}Log〕＋`('p','R_SUPER','manage_audit','menu','','','',false)`〕③CREATE INDEX ×4〔sys_operation_log(created_at)／(operator_id,created_at)、sys_access_log(created_at)／(operator_id,created_at)、命名 idx_<table>_<cols>〕；`down` 對稱（DELETE casbin by (v0,v1,v2)＋DELETE sys_menu by route_name＋DROP INDEX IF EXISTS ×4）；**idempotent（F3）：sys_menu `ON CONFLICT (route_name) WHERE deleted_at IS NULL DO NOTHING`〔partial unique、bare conflict-target 會 error、鏡像 m002〕／casbin `ON CONFLICT (ptype,v0..v5) DO NOTHING`／索引 `CREATE INDEX IF NOT EXISTS`**。**容器內 `cargo run -p migration -- up`＋psql 驗 seed/index 在**（data-model §8、research R6）
- [ ] T003 ★ net-new `sys_user::names_for_ids<C>(conn,ids:&[i64])->Result<HashMap<i64,String>,DbErr>` 於 `rust-api/server/src/model/facade/sys_user.rs`（`Entity::find().filter(Id.is_in(ids)).all`→id→user_name map、**不濾 `deleted_at`**＝含已刪、審計保留歷史名；既有 fn 不動）（data-model §4、research R5）

**Checkpoint**: m005 已套（menu/policy/index 在、up→down→up 可逆）＋operator enrich seam 就緒

## Phase 3: US1 — 超級管理員瀏覽操作異動日誌 (P1) 🎯 MVP

**Goal**: super 分頁/filter 瀏覽 op-log（getOperationLog、R_SUPER）。**Independent Test**: C-V-3（partial）：getOperationLog 分頁＋基本 filter＋operator 名。

- [ ] T004 [US1] sys_operation_log facade `list<C>(conn,page,size,OperationLogFilter)->(Vec<Model>,u64)` 於 `rust-api/server/src/model/facade/sys_operation_log.rs`（鏡像 sys_role::list、`.apply_if` 逐欄、`order_by_desc(created_at,id)`、`.paginate.fetch_page.num_items`；filter：entity_table/trace 模糊〔`Func::lower(col).like(LikeExpr.escape('\\'))`、非 ilike〕、operation/entity_id 精確、operator_ids `is_in`、**★ operator_ip 模糊 `host(col)::text LIKE`〔net-new、R4 首建〕**、created_from/to 範圍）＋`OperationLogFilter` struct＋若抽 IP-expr/filter 純 helper 則 **test-first** 純測（write sink 不動）（data-model §1/§5、research R1/R3/R4）
- [ ] T005 [US1] handler `get_operation_log(State,Extension<Claims>,Query<OperationLogQuery>)->Res<PageRes<OperationLogItem>>` 於 `rust-api/server/src/handler/system_manage.rs`（§5.8 normalize＋空字串守門＋**日期 parse〔僅起/僅訖寬鬆容忍、畸形→`backend.biz.audit.invalidDateRange` 2222、F2〕**＋★ operatorName 模糊→`sys_user` user_name LIKE〔unfiltered〕→operator_ids→facade.list→**operator 批次 enrich**〔`names_for_ids`〕→map Model→OperationLogItem〔camelCase、IpNetwork→host 字串、nullable→null、payloadBefore/After jsonb 原樣〕→PageRes；零 path-root entity::）（data-model §6、research R2/R5/R8）
- [ ] T006 [US1] `rust-api/server/src/main.rs` 加 audit Router＋註冊 `GET /systemManage/getOperationLog`（`route_layer(require_policy("/systemManage/getOperationLog","GET"))`＋外層 enforce_mw、`.merge(audit)`）＋`endpoint_coverage_lint` `AS_BUILT_ROUTES [&str;31]→[&str;32]`（+1、同 commit；m005 已 seed policy）（data-model §7/§12、research R7）
- [ ] T007 [US1] C-V-3（partial）live（`#[ignore]` `--test-threads=1` `DATABASE_URL`、**唯讀無污染**）：getOperationLog 分頁＋entity_table/operation filter＋★ **operator_ip 模糊 `host()::text LIKE` 首驗**〔取 dev DB 已知 IP 片段、確認 sea-query 渲染命中〕＋operator enrich 名。對應 SC-001/002

**Checkpoint**: US1 全綠＝MVP（op-log 讀＋IP-fuzzy 渲染證實）→ **雙段 commit**（rust-api worktree→pin）

## Phase 4: US2 — 超級管理員瀏覽 API 存取日誌 (P2)

**Goal**: super 瀏覽 access-log（getAccessLog、R_SUPER）。**Independent Test**: C-V-3：getAccessLog 分頁＋filter。

- [ ] T008 [US2] sys_access_log facade `list`＋`AccessLogFilter`（operator_ids／method 精確／path·xff·region 模糊／http_status 精確／client_ip 模糊 host()::text／created 範圍）於 `rust-api/server/src/model/facade/sys_access_log.rs`（data-model §2、research R1/R3/R4）
- [ ] T009 [US2] handler `get_access_log(...Query<AccessLogQuery>)->Res<PageRes<AccessLogItem>>`（§5.8＋enrich＋日期）於 handler/system_manage.rs（AccessLogItem：operatorId NOT NULL→number、clientIp/xForwardedFor/region）（data-model §6/§9）
- [ ] T010 [US2] `main.rs` 註冊 `GET /systemManage/getAccessLog`（require_policy）＋`endpoint_coverage_lint` `[&str;32]→[&str;33]`（+1、同 commit）（data-model §7）
- [ ] T011 [US2] C-V-3 live：getAccessLog 分頁＋path 模糊／method 精確／client_ip 模糊／region／日期範圍＋enrich。對應 SC-001

**Checkpoint**: US2 全綠 → **雙段 commit**

## Phase 5: US3 — 超級管理員瀏覽登入嘗試日誌 (P2)

**Goal**: super 瀏覽 login-attempt（getLoginAttempt、R_SUPER）。**Independent Test**: C-V-3：getLoginAttempt 分頁＋filter。

- [ ] T012 [US3] sys_login_attempt facade `list`＋`LoginAttemptFilter`（attempted_user_name 模糊／success 精確 bool／client_ip·xff·region 模糊／created 範圍）於 `rust-api/server/src/model/facade/sys_login_attempt.rs`（data-model §3、research R1/R3/R4）
- [ ] T013 [US3] handler `get_login_attempt(...Query<LoginAttemptQuery>)->Res<PageRes<LoginAttemptItem>>`（§5.8＋enrich〔operator_id nullable〕）於 handler/system_manage.rs（data-model §6/§9）
- [ ] T014 [US3] `main.rs` 註冊 `GET /systemManage/getLoginAttempt`（require_policy）＋`endpoint_coverage_lint` `[&str;33]→[&str;34]`（+1、同 commit；3 audit 端點全註冊）（data-model §7）
- [ ] T015 [US3] C-V-3 live：getLoginAttempt 分頁＋attempted_user_name 模糊／success 下拉／client_ip 模糊／日期範圍。對應 SC-001

**Checkpoint**: US3 全綠（3 端點全建）→ **雙段 commit**

## Phase 6: US4 — 多維篩選與搜尋（跨日誌 acceptance） (P2)

**Goal**: 文字/IP/路徑/帳號/地區/資料表模糊＋enum/數字精確＋日期範圍＋operator by 名，三日誌一致。**Independent Test**: C-V-3 全集（fuzzy/IP/operator-by-名/range）。

- [ ] T016 [US4] C-V-3 跨日誌 filter live（**唯讀**）：三端點驗 ① 空字串守門回全部；② **文字模糊**（path/帳號/region/entity_table 部分比對命中＋非含排除）；③ **★ IP 模糊**（operator_ip/client_ip `host()::text LIKE` 命中、跨三表一致、R4 完整證）；④ **operator by 名**（user_name LIKE→ids→`operator_id IN`、含已刪操作者）；⑤ enum/數字精確＋created 範圍；⑥ **畸形日期→2222 `invalidDateRange`（negative、F2）、僅起/僅訖寬鬆**。對應 SC-002

**Checkpoint**: US4 全綠（多維篩選一致）

## Phase 7: US5 — 操作者識別（顯示名、含已刪者） (P2)

**Goal**: operatorName enrich（現存顯示名／已刪仍顯示名／系統發起空）。**Independent Test**: C-V-3 enrich 三情境。

- [ ] T017 [US5] C-V-3 enrich live（**唯讀**）：① 現存使用者所為→顯示 user_name；② 已刪使用者所為→**仍顯示名**（`names_for_ids` unfiltered 證）；③ operator_id NULL（系統）→operatorName null。對應 SC-003

**Checkpoint**: US5 全綠（operator 識別正確）

## Phase 8: US7 — 授權防護（僅超管可稽核、越權） (P2)

**Goal**: 3 讀端 R_SUPER-only、非授權 403、三守恆。**Independent Test**: C-V-4（Admin/User→5003）；C-V-2（lint）。

- [ ] T018 [US7] C-V-4 live policy-gate（DB-fresh roles）：Admin/User 對 getOperationLog/getAccessLog/getLoginAttempt→403/5003 不洩資料；Super→200 PageRes。對應 SC-005
- [ ] T019 [US7] C-V-2：`cargo test -p server --test endpoint_coverage_lint`（`AS_BUILT [&str;34]`＝既 31＋3、Assertion A 3 audit policy 對應 m005 seed、B registered==as-built）＋`entity_access_lint`（handler/main 零 path-root entity::；3 sink facade list 走 model/facade/ 豁免）。對應 SC-008

**Checkpoint**: US7 全綠（越權＋三守恆）→ **commit**

## Phase 9: US6 + base-web 接線 + Polish & Cross-Cutting

- [ ] T020 [P] [US6] base-web WRAPPER（沿 009/010/011 rev3-* 檔）：`base-web/src/service/api/rev3-system-manage.ts` 加 `fetchGetOperationLog(params)`/`fetchGetAccessLog(params)`/`fetchGetLoginAttempt(params)`（GET、params=filter+current/size）（data-model §11、research R8）
- [ ] T021 [P] [US6] base-web ADAPT：`base-web/src/typings/api/rev3-system-manage.d.ts` `OperationLogItem`/`AccessLogItem`/`LoginAttemptItem`（**honest、nullable→`string｜null`／`number｜null`**、id number ⚠️r、operation enum）＋各 `XxxLogSearchParams`＋`XxxLogList=Common.PaginatingQueryRecord<Item>`（不改既有型）（data-model §9）
- [ ] T022 [US6] base-web MODAL-WIRING (e) 新頁（`rev3-inline`）：`base-web/src/views/manage/audit/index.vue`（NTabs 3 tab）＋`modules/{operation-log-table,access-log-table,login-attempt-table}.vue`（各 NDataTable＋filter 列〔operation/success/method 下拉、日期 NDatePicker range、path/帳號/IP/region NInput 模糊、operator NInput by 名〕＋NPagination；**op-log 行展開看 payload before/after**〔US6〕）（data-model §11）
- [ ] T023 [P] [US6] base-web i18n（先 Schema 後 locale）：`base-web/src/typings/app.d.ts` `App.I18n.Schema.page.manage.audit`（title/tab/col/filter）＋**`backend.biz.audit.invalidDateRange`（畸形日期 biz、非條件、F2 定）**＋`base-web/src/locales/langs/{zh-cn,en-us}.ts` 對應（data-model §10）
- [ ] T024 C-V-6 base-web `pnpm typecheck`（3 honest item 對齊、wire number 域零型謊；`--no-verify` commit）。對應 SC-009
- [ ] T025 C-V-7 CDP 經 front-nginx 真 `/api`（**唯讀無 cleanup**）：Super→/manage/audit→3 tab 各**真發 request**（斷言非假資料）→分頁→filter（operation/success 下拉、日期範圍、部分 IP/path/帳號 模糊、operator by 名）→**op-log payload 行展開**〔US6〕→operator 名顯示〔含已刪/系統空〕→**hasAuth super-only**（非 super 側欄不見審計中心、直呼 5003）。對應 SC-001/004/005/009
- [ ] T026 C-V-5 ★ m005 up→down→up 可逆（容器內 `migrate down -n 1`→psql 驗 manage_audit menu/4 policy/4 索引消失、既有日誌表不動→`migrate up` 重建）。對應 SC-008
- [ ] T027 C-V-8 零回歸：`/health` ok；diff 零既有日誌表 entity 改／enforce_mw·require_policy·From<DbErr> 未改／login/getUserInfo/getUserRoutes/008-011 不變；**base-web frozen（route store/transform/system-manage.ts/auth.ts/request）未動**；migration 僅 seed+index 無業務表；**唯讀無主動自審**（psql 驗查詢未新增 op-log 列；★ F1：既有 per-request access-log 基建對本 GET +1 列 sys_access_log＝基建軌跡、非本功能自審、預期）。對應 SC-006/008
- [ ] T028 C-V-9 prod target image build（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、無新 crate→輕、確認 3 facade list/names_for_ids/handler/main/**m005** 編入 migrate stage）。對應 build 面

## Dependencies

```
Setup (T001) ─→ Foundational (T002 m005 migration〔seed+index+up/down/up〕／T003 names_for_ids enrich)  [blocking 全 US]
Foundational ──┬─→ US1 (T004 op-log facade list+filter+★IP-expr→T005 handler+enrich→T006 main+lint[32]→T007 live〔IP-fuzzy 首驗〕)   [MVP]
               ├─→ US2 (T008 access facade→T009 handler→T010 main+lint[33]→T011 live)
               ├─→ US3 (T012 login facade→T013 handler→T014 main+lint[34]→T015 live)
               ├─→ US4 (T016 跨日誌 filter live)        [消費 US1-3 facade filter]
               ├─→ US5 (T017 enrich live)                [消費 T003 names_for_ids + US1-3 handler]
               └─→ US7 (T018 policy-gate live／T019 lint 三守恆)   [消費 US1-3 main require_policy]
US1~US7 ──→ US6+base-web+Polish (T020 wrapper／T021 typings／T022 audit 頁 3 tab+payload 展開／T023 i18n／T024 typecheck／T025 CDP／T026 m005 up/down/up／T027 零回歸／T028 prod build)
```

## Parallel Execution Examples

- **Foundational [P]**：T002（m005、migration crate）∥ T003（names_for_ids、server facade、不同 crate/檔）——惟 cargo build/test 一次一個（rust serial）。
- **base-web [P]**：T020（wrapper）∥ T021（typings）∥ T023（i18n）——不同檔可並行撰寫；T022（audit 頁）依 T020/T021；T024 typecheck 須前述完成、T025 CDP 須後端全綠+base-web restart。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔可並行撰寫」、cargo build/test 一次一個。

## Implementation Strategy

**MVP first**：Phase 1→2→3（T001~T007）＝Setup＋Foundational（m005＋names_for_ids）＋US1（getOperationLog 分頁/filter＋**IP-fuzzy 渲染首驗**）＝最小價值（op-log 讀）。US2/US3（其餘兩日誌）／US4（多維篩選 acceptance）／US5（enrich）／US7（越權+lint）緊接；US6+base-web 審計中心頁（T020-T025）／m005 可逆+零回歸+prod build（T026-T028）收口。每 phase checkpoint 過才前進；任一 C-V fail＝修復重跑。**★ lint 逐路由 bump（T006 [32]／T010 [33]／T014 [34]）保每 checkpoint endpoint_coverage_lint 綠；m005 一次 seed 3 policy（Foundational）、registered⊆seed 各 US 自動過。★ IP 模糊 host()::text LIKE net-new、U1 facade live 首驗（無 codebase 先例）；operator enrich names_for_ids unfiltered 含已刪；唯讀無 cleanup（純 SELECT、live/CDP 不污染）；fuzzy LOWER LIKE ESCAPE 非 ilike；rust serial、容器內、改 .rs 先 force-touch、live --test-threads=1；逐單元兩段式 commit（worktree→pin S9）；base-web --no-verify；frozen 既有檔不改、無 .env flip；m005 menu seed→view 同刀〔避 dangling：transform.ts getViewName 對缺 view **throw** 非 warn、F5；U1 seed→U2 view 同 feature 收口〕；全程不 push/merge（§I.4）。**

> **階段 2 交棒注記**（CLAUDE.md §3）：實作以 `superpowers:executing-plans` 起手、**Workflow 驅動**，依**實際相依/獨立可審邊界**重分執行單元（不綁本檔編號）——預期 **U1 rust 讀端+m005**（Foundational T002-T003＋US1 T004-T007＋US2 T008-T011＋US3 T012-T015＋US4 T016＋US5 T017＋US7 T018-T019；★ m005 delta〔up/down/up〕＋3 facade list〔IP-fuzzy host()::text **首驗**〕＋names_for_ids unfiltered＋3 handler enrich＋main 3 路由＋lint[34]＋live〔唯讀無污染〕）／**U2 base-web 審計中心頁**（US6 T020-T023＋Polish T024-T025；3 wrapper+3 honest typing+audit 3 tab+payload 展開+i18n+typecheck+CDP）為 2 load-bearing 單元；T026 m005 up/down/up＋T027 零回歸＋T028 prod build final holistic 收口。每單元邊界主線 `git show --stat HEAD` 復核＋容器內自驗（含 **IP-fuzzy 渲染**＋m005 可逆＋**psql 驗查詢無新增 op-log 列**＝唯讀證〔F1：per-request access-log +1/查屬基建、非自審〕）＋bump submodule pin（S9 逐單元）；**★ 唯讀無 cleanup**（純 SELECT）；★ 絕不 push/merge（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
