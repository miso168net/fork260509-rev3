---
description: "Task list for 025-user-center"
---

# Tasks: 个人中心（自助檢視/編輯資料 ＋ 修改密碼）

**Input**: Design documents from `specs/025-user-center/`（plan.md / spec.md / research.md / data-model.md / contracts/）

**Tests**: rev3 採 **TDD**（CLAUDE.md §3）——純函式 test-first（US3 created/updated 語意解析）；data/wiring 類由 acceptance（curl/psql/CDP）覆蓋、並於該 story 明示「無純測及理由」。

**Organization**: 按 4 個 user story 分階段、各自可獨立驗收。

## Format: `[ID] [P?] [Story?] Description`

- **[P]**：可平行（不同檔/工具鏈）。**★ rust 全程 serial**（共用 `target`、即使標 [P] 也不平行 cargo；CLAUDE.md §3）——本刀 [P] 僅出現在 base-web 任務。
- **[Story]**：US1~US4；Setup/Foundational/Polish 無 story 標籤。
- 路徑相對 worktree：`rust-api/…`、`base-web/…`。

## 執行紀律（烤進每個實作單元、CLAUDE.md §3）

- **rust**：build/test 容器內 `docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`；改 `.rs` 先 force-touch；**全程 serial**。
- **兩段式 commit**：worktree commit（rust-api 正常 conventional；base-web `--no-verify`）→ 外層 bump submodule pin（逐單元、不延末刀）。
- **★ 絕不 `git push` / `git merge`**（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
- **治理**：MODAL-WIRING (g) amendment **已落**（constitution v1.3.0、⚠️ah、commit `63d35179`）——實作階段**不需再動 constitution**。

---

## Phase 1: Setup

- [ ] T001 確認在 `025-user-center` 分支、dev stack `up -d --wait` 就緒；本刀**無新 workspace crate/依賴**、**零 migration**（sys_user 欄早齊）；(g) amendment 已落（`63d35179`、不需再動）。

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 3 story 共用的前後端骨架（先於 US 填充）

- [ ] T002 後端骨架：建 `rust-api/server/src/handler/user_center.rs`（3 wire DTO：`GetProfileRes`〔**US1 子集 6 欄；`createdAt`/`createdBy`/`adminUpdatedAt` 3 欄由 US3 T014 擴**〕/`UpdateProfileReq`/`ChangePwdReq`〔camelCase、data-model §2〕 + 3 handler fn 簽名〔`Extension<Claims>`、auth-only〕，body 暫 minimal）＋`handler/mod.rs` `+mod user_center`＋`main.rs` 掛 `user_center` router（仿 `route_auth` main.rs:190、`.layer(enforce_mw)`、無 `require_policy`、3 route：getProfile GET / updateProfile POST / changePassword POST）＋`server/tests/endpoint_coverage_lint.rs` `AS_BUILT_ROUTES` **50→53**（加 3 路徑、陣列容量）。
- [ ] T003 [P] 前端骨架：`base-web/src/views/user-center/index.vue` 換 `<LookForward/>` → 4 卡容器（root `flex-col-stretch gap-16px` **修 overflow**、DECISIONS ⚠️ag 範式）＋建 `views/user-center/modules/`（`basic-info-card`/`phone-card`/`email-card`/`password-card` 佔位）＋`src/service/api/rev3-user-center.ts`（`fetchGetProfile`/`fetchUpdateProfile`/`fetchChangePassword` skeleton、直接路徑 import 慣例）＋`src/typings/api/rev3-user-center.d.ts`（3 DTO 型、declaration-merge）。**★MODAL-WIRING (g)**。
- [ ] T004 [P] i18n scaffold：`src/typings/app.d.ts` App.I18n.Schema `page.userCenter.*`（區塊標題/欄位/按鈕/改密碼標籤＋`createdAt`/`updatedAt`＋`origin.system`/`origin.adminCreated`/`origin.selfCreated`/`origin.adminUpdated`＋`verify.comingSoon`）＋`backend.biz.password.*` 命名空間 → `src/locales/langs/{zh-cn,en-us}.ts` 對應（**先 Schema 後 locale**；zh-CN 為主）。

**Checkpoint**: 骨架就緒、US1~US4 可填充。

---

## Phase 3: User Story 1 - 檢視與編輯個人基本資料 (Priority: P1) 🎯 MVP

**Goal**: 使用者見自己 profile（帳號/角色唯讀 + 性別/昵稱/手機/郵箱可改）並儲存。

**Independent Test**: getProfile 回 profile；updateProfile 改 gender/nick/phone/email 持久、不動 user_name/password；CDP 見基本资料/手机/邮箱卡可改可存。

> **無純測（理由）**：US1 ＝讀寫 wiring、無新純函式 → acceptance（curl/psql/CDP）覆蓋。

- [ ] T005 [US1] facade `update_own_profile` 於 `rust-api/server/src/model/facade/sys_user.rs`：仿 `update`/`build_update_active_model`（sys_user.rs:359/286）的 `mutate_in_txn`——`into_active_model` 只 `Set` nick/gender/phone/email ＋ `updated_at`/`updated_by`（§I.6 成對、operator=`meta.operator.id`）；user_name/password/status/roles **Unchanged**；op-log **不套 `with_roles`**。
- [ ] T006 [US1] handler `getProfile` + `updateProfile` 於 `rust-api/server/src/handler/user_center.rs`：getProfile→`find_active_by_id(claims.uid)`＋`roles_of_user(claims.uid)`〔code〕→回 userName/roles/gender/nick/phone/email〔created/updated 欄留 US3〕；updateProfile→`ctx.to_audit_meta(claims.uid)`→`update_own_profile`（operator=自己、不信 body id）。（依賴 T005）
- [ ] T007 [P] [US1] 前端 `base-web/src/views/user-center/modules/basic-info-card.vue`（userName/roles 唯讀顯示＋gender `NRadioGroup`〔`userGenderOptions`〕＋nick `NInput`＋保存→`fetchUpdateProfile`）＋`phone-card.vue`/`email-card.vue` 的**值 input＋保存**（共用 updateProfile 送全 model；rule 用 `patternRules.phone/email`）。
- [ ] T008 [US1] 驗 US1（容器內 + CDP）：curl getProfile 回 profile；curl updateProfile 改 4 欄→psql 持久、user_name/password 不變＋斷言 operator=`claims.uid`（body 無 target-id、self-only 結構驗）；CDP `/user-center` 見基本资料/手机/邮箱卡可改可存 → FR-001/002/003/004、SC-001/007。（依賴 T006、T007）

**Checkpoint**: US1 可獨立驗收（自助檢視/編輯 profile＝MVP）。

---

## Phase 4: User Story 2 - 修改自己的密碼 (Priority: P2)

**Goal**: 舊/新/確認改密碼、新密符合 024 管理員政策。

**Independent Test**: happy→新密可 login；舊密錯/確認不符/違政策→2222；op-log password redact；CDP 動態 rule 隨政策。

- [ ] T009 [US2] facade `change_own_password` 於 `sys_user.rs`（只 `Set` password ＋ `updated_at`/`updated_by`、`mutate_in_txn` op-log redact）＋喚醒 `rust-api/server/src/auth/password_policy.rs`（移除檔頭 `#![allow(dead_code)]`）。
- [ ] T010 [US2] handler `changePassword` 於 `handler/user_center.rs`（順序：`find_active_by_id`→無`biz.user.notFound`；`confirm==new`否`biz.password.mismatch`；`verify(old,phc)`false`biz.password.oldMismatch`；載政策`find_all`→pairs→`from_settings`→`validate_password_complexity(&policy,new,&user_name)`Err`biz.password.tooWeak`；`hash_password(new)`→`change_own_password`）＋**新建** `biz.password.{tooWeak,mismatch,oldMismatch}` 三碼〔★ 全庫零命中＝淨新：後端 `AppError::Biz` 發射 + 前端 `backend.biz.password.*` locale 三鍵、勿誤為複用〕；唯 `biz.user.notFound` 複用既有。（依賴 T009）
- [ ] T011 [P] [US2] 前端 `password-card.vue`（舊/新/確認 `NInput`＋`createConfirmPwdRule(newPwd)`〔與 `patternRules` 皆取自 `hooks/common/form.ts` 的 `useFormRules()` composable：`const { createConfirmPwdRule, patternRules } = useFormRules()`、非裸 import〕＋`onMounted fetchGetSystemSettings()` 組動態密碼 rule＋改密码→`fetchChangePassword`）＋`backend.biz.password.*` 譯文補（zh-cn/en-us）。
- [ ] T012 [US2] 驗 US2（容器內 + CDP）：curl changePassword happy→psql PHC 變、新密 login；舊密錯/確認不符/違政策→2222 對應碼；op-log password `<redacted>`；CDP 改 admin 政策 min_length 後前端 rule 反映 → FR-005~009、SC-002/003/004。（依賴 T010、T011）

**Checkpoint**: US1 + US2 皆可獨立驗收。

---

## Phase 5: User Story 3 - 檢視帳號建立與更新來源 (Priority: P3)

**Goal**: 顯示建立時間+來源（system/admin）、被管理員更新過才顯示「由管理员更新」；本人/未更新不顯示；不洩露哪個 admin。

**Independent Test**: `cargo test` 語意解析純函式全綠；curl+CDP：種子→system、admin 改過→adminUpdatedAt 有值、本人/未改→null。

### Tests for US3 (TDD — 先寫、預期紅) ⚠️

- [ ] T013 [US3] **test-first**：`rust-api/server/src/handler/user_center.rs` `#[cfg(test)] mod` 加 created/updated 語意解析純函式測——`createdBy`（`None`→system／`Some(uid)`→self／`Some(other)`→admin）＋`adminUpdatedAt`（`updated_by` 非 null 且 ≠ uid→`Some(rfc3339)`／本人 or None→`None`）。**先寫、預期紅**（解析 fn 未實作）。

### Implementation for US3

- [ ] T014 [US3] 實作語意解析 fn（純、data-model §3）＋擴 `getProfile` DTO 加 `createdAt`（rfc3339）/`createdBy`（enum）/`adminUpdatedAt`（Option）——**不 join、不回 operator uid/name**。→ T013 綠。（依賴 T013 test-first 先紅、且擴 US1 之 T006 getProfile）
- [ ] T015 [P] [US3] 前端 `basic-info-card.vue` 加**唯讀資訊列**：`创建时间 <createdAt>（<origin 訊息>）`；`adminUpdatedAt` 非 null 才顯示 `更新时间 …（由管理员更新）`、否則整列不顯示（本人/未更新隱藏）＋ `origin.*` i18n 已於 T004 scaffold。
- [ ] T016 [US3] 驗 US3（curl + CDP）：種子帳號→`createdBy:"system"`、admin-建→`"admin"`、被 admin 改過→`adminUpdatedAt` 有值+CDP「由管理员更新」、本人改過/未改→null+無更新列；回應不含 operator 身分 → FR-011/012/013、SC-006。（依賴 T014、T015）

**Checkpoint**: US1+US2+US3 皆可獨立驗收。

---

## Phase 6: User Story 4 - 手機/信箱驗證入口（預留） (Priority: P3)

**Goal**: 手機/信箱卡備發送/驗證碼/驗證控件為預留（不接後端）。

**Independent Test**: CDP 見手机/邮箱卡 3 預留控件、點擊 toast 建置中、值仍可改存。

- [ ] T017 [P] [US4] 前端 `phone-card.vue`/`email-card.vue` 加預留控件：發送驗證碼 `NButton`＋驗證碼 `NInput`＋驗證 `NButton`，點擊 `window.$message?.info($t('page.userCenter.verify.comingSoon'))`（不接後端）＋`verify.comingSoon` i18n 已於 T004。
- [ ] T018 [US4] 驗 US4（CDP、restart base-web 後）：手机/邮箱卡見 3 預留控件、點擊 toast「功能建置中」（非 raw key）、值仍可改存 → FR-010、SC-005。（依賴 T017）

**Checkpoint**: 4 story 皆可獨立驗收。

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T019 三守恆（容器內、rust serial）：`cargo test -p server --test entity_access_lint`（2 窄寫 fn facade-only）＋`cargo test -p server --test endpoint_coverage_lint`（AS_BUILT 53、3 auth-only 無 seed）＋`migration down`→`up`（零 migration、僅確認未破）。
- [ ] T020 [P] base-web `pnpm typecheck` 綠（容器內）。
- [ ] T021 零回歸驗（curl/CDP）：`getUserInfo` 仍 4 欄、login/enforce 不變、既有 manage 頁不破、024 system-settings 政策設定仍運作（喚醒 password_policy 後）→ SC-008。
- [ ] T022 prod image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`（確認 `handler/user_center.rs`＋2 窄寫 fn＋喚醒 password_policy 編入 prod）。
- [ ] T023 跑 `specs/025-user-center/quickstart.md` 全流程收尾驗證。

---

## Dependencies & Execution Order

### Phase 相依
- **Setup（T001）**→ **Foundational（T002-T004）**→ **US1-US4** → **Polish**。
- ★ rust 共用 target **全程 serial**：rust story 順序執行（US1 rust → US2 → US3），base-web（T003/T007/T011/T015/T017）可與 rust 平行。

### User Story 相依
- **US1 (P1)**：T005→T006（facade 前於 handler）；T007 [P]；T008 需 T006+T007。
- **US2 (P2)**：T009→T010（facade+喚醒 前於 handler）；T011 [P]；T012 需 T010+T011。**與 US1 邏輯獨立**（自有卡+端點）。
- **US3 (P3)**：T013→T014（test-first）；**T014 擴 US1 的 getProfile（T006）→ 依賴 US1**；T015 [P]（擴 US1 basic-info-card）；T016 需 T014+T015。
- **US4 (P3)**：T017 擴 US1 的 phone/email 卡（T007）→ **依賴 US1**；T018 需 T017。

### Within Story（TDD）
- US3 T013 test-first **須先紅** → T014 實作轉綠。
- US1/US2/US4 data/wiring → acceptance 覆蓋（US1 已明示無純測）。

### Parallel Opportunities
- base-web 卡/i18n（T003/T004/T007/T011/T015/T017/T020）可與 rust 平行；rust 任務間不平行（serial）。

---

## Implementation Strategy

### MVP First（US1）
1. Setup（T001）→ Foundational（T002-T004）→ US1（T005-T008）→ **STOP & VALIDATE**（自助檢視/編輯 profile）。此即 MVP。

### Incremental Delivery
1. US1 → 檢視/編輯 profile（MVP）。
2. US2 → 改密碼（消費 024 政策）。
3. US3 → 建立/更新來源顯示。
4. US4 → 驗證入口預留。
5. Polish（三守恆/typecheck/回歸/prod build/quickstart）。

---

## Notes
- [P]＝不同檔/工具鏈、無相依；**rust 全程 serial**（即使 [P]）。
- 逐單元 worktree commit → 外層 bump submodule pin（不延末刀）。base-web commit `--no-verify`；自驗 `pnpm typecheck`。
- **絕不 push/merge**（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
- 治理 (g) amendment 已落（`63d35179`）；**收刀回填** DECISIONS ⚠️ah 的 merge hash/pins/as-built＋MILESTONES §1 一行。
- 消費 024：`from_settings(&[(&str,&str)])`＋`validate_password_complexity(&policy, new, &user_name)`〔含 user_name〕；喚醒 dormant 模組。
