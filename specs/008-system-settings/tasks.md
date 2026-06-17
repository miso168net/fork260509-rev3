# Tasks: 008-system-settings（system_settings KV 打樋＝波1 第一刀）

**Input**: Design documents from `/specs/008-system-settings/`

**Prerequisites**: plan.md ✅、spec.md ✅（4 US／11 FR／7 SC）、research.md（R1 m005 MOOT・R2 static Option A・R3-R9 grep ground-truth）✅、data-model.md ✅、contracts/（verification-commands C-V-0~10＋system-settings-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS）。

**Tests**: 本 feature **有純函式測＋活體測＋lint**（constitution §I.4 TDD）。純測＝in-crate `#[cfg(test)]`（`validate_value_type`／facade `*_active_model`、test-first）；活體＝live psql/curl（policy-gate 5003／op-log INET round-trip／CDP）；lint＝新 `endpoint_coverage_lint`＋既有 `entity_access_lint`。

**Organization**: 依 user story 分 phase。**★ 校正（research）**：m005 MOOT——端點 policy×2＋menu policy＋sys_menu 列已 m002 seed → **本刀零 migration**；前端 **static Option A**（base-web static 模式、dynamic-menu 延波2）。**rust 全程 serial**、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime）；**live `#[ignore]` 一律 `--test-threads=1`**；base-web commit `--no-verify`；**兩段式 commit**（rust-api／base-web worktree→outer pin、不延後）；**§I.4：全程不 push/merge**。**無新 crate**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup

- [ ] T001 親驗前置（research R1）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait` 全 healthy；grep `rust-api/migration/src/m002_rev2_seeds.rs` 確認 system-settings 端點 policy×2（`getSystemSettings`/`updateSystemSetting`）＋menu policy（`manage_system-settings`）＋sys_menu 列（:251）**已 seed**＝本刀**零 migration、無新 crate/dep**

**Checkpoint**: 環境就緒、seed 已在（無 m005）

## Phase 2: Foundational（blocking 全 US：policy 強制＋值驗）

- [ ] T002 [P] `require_policy(path,method)` per-route layer 於 `rust-api/server/src/auth/enforce.rs`（加；`enforce_mw` 一行不動）：middleware 取 `State<AppState>`＋`Extension<Claims>` → **DB-fresh** `facade::sys_user_role::roles_of_user(&state.db, claims.uid).await?`（**不信 `claims.roles`**）→ `enforce_role_path_method(&*state.enforcer.read().await, &roles, path, method)` → false → `AppError::PermissionDenied`（5003/403）。鏡像 main.rs:92-95 `from_fn_with_state` 寫法（data-model §3、research R3）
- [ ] T003 [P] `validate_value_type(value_type:&str, value:&str)->Result<(),AppError>` 純函式（test-first、置 `rust-api/server/src/handler/system_settings.rs`）：解析 `enum:on,off` → value∈集？否→`Err(AppError::Biz(Cow::Borrowed("biz.systemSettings.invalidValue")))`（2222）。純測：enum 合法/非法（data-model §6、research R5、C-V-2）

**Checkpoint**: policy 強制層＋值驗就緒（純測綠）

## Phase 3: US1 — 超級管理員讀全站設定 (P1) 🎯 MVP

**Goal**: super get→全列 KV（鍵/值/型/說明）。
**Independent Test**: C-V-6（super 登入→getSystemSettings→全列含 single_session_default）；不依賴改/驗。

- [ ] T004 [US1] facade `find_all<C:ConnectionTrait>(conn)->Result<Vec<Model>,DbErr>`＋`impl AuditSerialize for entity::system_settings::Model`（手構 json）於新檔 `rust-api/server/src/model/facade/system_settings.rs`；`facade/mod.rs` 加 `pub mod system_settings;`（entity:: 此 facade 合法）
- [ ] T005 [US1] handler `get_system_settings(State, Extension<Claims>)->Result<Json<Res<serde_json::Value>>,AppError>`（`find_all`→map `SystemSettingItem` camelCase→flat 陣列）於新檔 `rust-api/server/src/handler/system_settings.rs`；`handler/mod.rs` 加 `pub mod system_settings;`（零 path-root entity::）
- [ ] T006 [US1] `rust-api/server/src/main.rs` 註冊 `GET /systemManage/getSystemSettings`（掛 `enforce_mw`→`require_policy("/systemManage/getSystemSettings","GET")` 兩層）
- [ ] T007 [P] [US1] base-web 讀 wire：`base-web/src/service/api/rev3-system-settings.ts`（新、WRAPPER 軌道、首個 rev3-* 檔）`fetchGetSystemSettings()`＋`base-web/src/typings/api/rev3-system-settings.d.ts`（新、ADAPT 軌道）`SystemSetting{settingKey,settingValue,valueType,description?}`
- [ ] T008 [P] [US1] base-web 頁 `base-web/src/views/manage/system-settings/index.vue`（新、MODAL-WIRING (e)、elegant-router static 自動生 route `manage_system-settings`）：載 `fetchGetSystemSettings`→ render KV（by value_type）；i18n `route.manage_system-settings`＋`page.manage.systemSettings.*`（zh-cn/en-us）
- [ ] T009 [US1] C-V-6 read live：super 登入→`GET /systemManage/getSystemSettings`→全列 KV（含 single_session_default）。對應 SC-001（讀面）

**Checkpoint**: US1 全綠＝MVP（讀成立）→ **雙段 commit**（rust-api worktree→pin；base-web worktree→pin）

## Phase 4: US2 — 改設定＋完整審計 (P2)

**Goal**: super update 單鍵→值變＋同 txn op-log（operator/operator_ip 真 INET/trace/before-after）、原子。
**Independent Test**: C-V-5（顯式 operator 餵 update_by_key→op-log 末列 UPDATE/真值）。

- [ ] T010 [US2] facade `update_by_key<C:TransactionTrait>(conn,key,new_value:String,operator:AuditOperator,trace_id)->Result<Option<Model>,DbErr>`（`mutate_in_txn`：查無→Ok(None) no-op；命中→Set setting_value＋updated_at/updated_by 成對〔§I.6〕＋同 txn op-log `AuditOperation::Update`〔before/after audit_json、entity_id None〕）＋`*_active_model` 純測（test-first、欄映射）於 facade/system_settings.rs（data-model §1、C-V-1）
- [ ] T011 [US2] handler `update_setting(State, Extension<RequestContext>, Extension<Claims>, Json<UpdateReq>)`（查 key 無→`Biz("biz.systemSettings.notFound")`；`validate_value_type`〔T003〕→不符 2222；`ctx.to_audit_operator(claims.uid)`〔007 seam〕餵 `update_by_key`）＋`UpdateReq{settingKey,settingValue}` DTO 於 handler/system_settings.rs（data-model §2、research R9）
- [ ] T012 [US2] `main.rs` 註冊 `POST /systemManage/updateSystemSetting`（`enforce_mw`→`require_policy("/systemManage/updateSystemSetting","POST")`）
- [ ] T013 [P] [US2] base-web 改 wire＋頁編輯：`rev3-system-settings.ts` 加 `fetchUpdateSystemSetting(settingKey,settingValue)`＋typings `UpdateSystemSettingReq`；`system-settings/index.vue` 加改值（`enum:on,off`→NSwitch toggle→存→`$t(common.updateSuccess)` toast；錯誤經攔截器 `$t` 自動譯）
- [ ] T014 [US2] C-V-5 op-log live smoke（in-crate `#[cfg(test)] #[ignore]` 置 facade/system_settings.rs、外層 txn rollback、`--test-threads=1`、`DATABASE_URL=$(cat /run/secrets/database_url)`）：顯式 `AuditOperator{id,ip:Some(IpNetwork::from(..))}`＋trace 餵 `update_by_key`→psql `sys_operation_log` 末列 `operation='UPDATE'`/`operator_id`/`operator_ip`(真 INET)/`trace_id` 非空、值已改。對應 SC-002

**Checkpoint**: US2 全綠（改＋審計原子）→ **雙段 commit**

## Phase 5: US3 — 越權防護 super-only (P2)

**Goal**: 非 super（已認證）讀/改→5003/403、不洩值；端點授權守恆。
**Independent Test**: C-V-6（Admin/User token 打端點→403）；C-V-3（endpoint_coverage_lint）。

- [ ] T015 [US3] `rust-api/server/tests/endpoint_coverage_lint.rs`（新、⚠️x 波1 立、鏡像 entity_access_lint 只讀掃描）：分類 main.rs 已註冊 route public（/health、/auth/login）/auth-only（/auth/getUserInfo）/policy-governed（system_settings×2）；斷言「policy-governed route 必有對應 m002 casbin p-policy seed」＋「registered==as-built registry」（**非 §7.1 @35**、research R6、C-V-3）
- [ ] T016 [US3] C-V-6 policy-gate live（★首 5003 live）：Super→get/update 通過（0000、值變 psql 證）；**Admin/User token→`GET/POST` 端點→HTTP 403、body code 5003、不洩值**。對應 SC-001

**Checkpoint**: US3 全綠（5003 首証＋lint）→ **雙段 commit**

## Phase 6: US4 — value_type 驗 (P3)

**Goal**: 非法值→2222 在地化、不寫；查無 key→2222。
**Independent Test**: C-V-2（純測）＋ live 對 enum 設定送非列舉值→2222、原值不變。

- [ ] T017 [US4] 確認 `update_setting`（T011）已整合 `validate_value_type`（T003）＋查無 key→`Biz("biz.systemSettings.notFound")`；補/確認純測涵蓋 enum 合法/非法/notFound 路徑（C-V-2、data-model §6）
- [ ] T018 [P] [US4] base-web i18n 錯誤鍵（I18N-WIRING (ii)(iii)、⚠️y canonical）：`base-web/src/typings/app.d.ts` `App.I18n.Schema` 的 `backend.biz` 擴 `systemSettings:{invalidValue,notFound}` 型（**先 Schema**）＋`base-web/src/locales/langs/{zh-cn,en-us}.ts` 加 `backend.biz.systemSettings.{invalidValue,notFound}` 譯文（後 locale）；攔截器不改（既有 `translateBackendMsg`）
- [ ] T019 [US4] live/CDP：對 single_session_default 送非 on/off→2222、在地化 toast「設定值不符型別」類、原值不變、無 op-log 變更。對應 SC-003

**Checkpoint**: US4 全綠（值驗＋i18n）→ **雙段 commit**

## Phase 7: Polish & Cross-Cutting

- [ ] T020 [P] C-V-0 build `--locked`＋C-V-4 `entity_access_lint` 守恆（handler/require_policy/main 零 path-root entity::）容器內綠
- [ ] T021 C-V-8 base-web `pnpm typecheck`（wire 3 端對齊＋`backend.biz.systemSettings` Schema typed-key、先 Schema 後 locale）
- [ ] T022 C-V-7 CDP 經 front-nginx 真 `/api` 全鏈：super 登入→/manage/system-settings 頁→toggle single_session_default→存→toast＋DB 值變；非法值→2222 toast；Admin/User→403。對應 SC-005
- [ ] T023 C-V-10 prod target image build（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、無新 crate→輕、確認新 handler/facade/require_policy/lint 編入）
- [ ] T024 C-V-9 零回歸收口：`/health` ok；`enforce_mw`/`audit_mw`/`is_current`/login/getUserInfo 不變；diff **零 migration/entity/schema**（m005 MOOT）；base-web 既有 auth.ts/system-manage.ts/route.ts/system-manage.d.ts **不改**（只新增 rev3-* wrapper/新 typings/新頁/locale 加 key、fork-delta rev3-inline 標記）；quickstart 11 步逐步對照綠。對應 SC-006/SC-007

## Dependencies

```
Setup (T001) ─→ Foundational (T002 require_policy／T003 validate_value_type)  [rust serial、[P]=不同檔可並行撰寫]
Foundational ──┬─→ US1 (T004 facade find_all→T005 handler get→T006 main route／T007 wire〔P〕／T008 頁〔P〕→T009 read live)   [MVP]
               ├─→ US2 (T010 facade update_by_key+active_model→T011 handler update→T012 main route／T013 wire+頁〔P〕→T014 op-log live)
               ├─→ US3 (T015 endpoint_coverage_lint／T016 5003 live)         [require_policy=T002 foundational、本 phase 為驗收+lint]
               └─→ US4 (T017 整合 validate→T018 i18n〔P〕→T019 非法值 live)
US1~US4 ──→ Polish (T020 lint+build／T021 typecheck／T022 CDP／T023 prod build／T024 零回歸)
```

## Parallel Execution Examples

- **概念並行**：T002（require_policy、enforce.rs）∥ T003（validate_value_type、handler）——不同檔可並行撰寫。T007（base-web wire）∥ T008（base-web 頁）∥ rust 端 task——base-web 與 rust-api 不同 worktree、可並行撰寫。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔/worktree 可並行撰寫」、cargo build/test 一次一個。
- **US3 多為 acceptance/lint**（require_policy 機制在 Foundational）；可緊接 US1/US2 後驗、彈性併段 commit。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T009）＝Setup＋Foundational（require_policy＋value 驗）＋US1（讀全鏈：facade→handler→main→wire→頁→read live）即最小價值（super 讀全站設定成立）。US2 改+審計（T010~T014）／US3 越權 5003+lint（T015~T016）／US4 值驗（T017~T019）緊接；Polish 收口（lint／typecheck／CDP／prod build／零回歸）。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進。**★ 校正**：m005 MOOT〔policy/menu 已 m002 seed〕→**零 migration**；前端 static〔dynamic-menu 延波2〕。**rust serial、容器內 build/test、改 .rs 先 force-touch、live `--test-threads=1`；兩段式 commit（rust-api／base-web worktree→pin）；base-web `--no-verify`；全程不 push/merge（§I.4）；首個 policy-governed 端點→`require_policy` DB-fresh＋5003 live 首証＋立 endpoint_coverage_lint**。

> **階段 2 交棒注記**（CLAUDE.md §3）：實作以 `superpowers:executing-plans` 起手、**Workflow 驅動**，依**實際相依/獨立可審邊界**重分執行單元（不綁本檔編號）——預期 Foundational（require_policy＋value 驗）＋US1 read 為一 load-bearing 單元、US2 update+op-log 為一單元、US3/US4 acceptance+lint 可併、base-web wire/頁/i18n 為 base-web worktree 單元、Polish 收口。
