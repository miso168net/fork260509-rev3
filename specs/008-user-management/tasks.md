---
description: "Task list — 008 User Management"
---

# Tasks: User Management（使用者管理）

**Input**: Design documents from `/specs/008-user-management/`（plan.md / spec.md / research.md / data-model.md / contracts/verification-commands.md / quickstart.md）

**Prerequisites**: plan.md ＋ spec.md（必）；research.md（★實碼 grep、含 Q3 critical gap）／data-model.md／contracts/ 皆在。

**Tests**: **included**（constitution §I.4 強制 SDD+TDD）。紀律（CLAUDE.md §3）：**純函式邏輯 test-first（red→green）**；**wiring／形狀對映類無新單元測試 → 由 acceptance 覆蓋**（contracts/ 的 C-V：live smoke + curl/psql + CDP），且 task 內**明示「無單元測試」及理由**。live 測 `#[ignore]` + `--test-threads=1`（共表、memory `live-ignore-tests-need-serial`）。

**Organization**: 按 user story（US1-US6、spec.md 優先序）分階段、各自獨立可測。

**實作紀律**: 交 `superpowers:executing-plans`（**不是 `/speckit-implement`**）；**`git push`／`git merge` 不得出現於 `finishing-a-development-branch` 前**（故本 tasks.md 不含 push/merge task）。

## Format: `[ID] [P?] [Story] Description`

- **[P]**：可並行（不同檔、無未完依賴）
- **[Story]**：US1-US6（setup/foundational/polish 無 story label）

## Path Conventions（plan.md Structure Decision）

- 後端：`rust-api/server/src/`（handler／model/facade／main.rs）＋`rust-api/server/tests/`
- 前端：`base-web/src/`（service/api／views/manage/user）

---

## Phase 1: Setup（共享骨架）

- [x] T001 建 `rust-api/server/src/handler/system_manage.rs` 模組骨架（空 6 fn stub）＋於 `rust-api/server/src/handler/mod.rs` 加 `pub mod system_manage;`
- [x] T002 [P] 建 `base-web/src/service/api/rev3-system-manage.ts` wrapper 骨架（rev3- 前綴、檔頭 `// [rev3-inline WRAPPER]` 標記；BASE-WEB-WRAPPER §III.1；**不改既有 `system-manage.ts`**）

---

## Phase 2: Foundational（阻塞所有 story、必先完成）

**⚠️ CRITICAL**：本階段未完、任何 user story 不得開工。

- [x] T003 [P] 在 `handler/system_manage.rs` 定 wire DTO（`UserListItem`／`UserSearchParams`／`UserUpsertReq`〔`id: Option<i64>`〕／`AllRoleItem`），`#[serde(rename_all="camelCase")]`；含 `i16↔string-enum`（`userGender`/`status` ↔ `"1"|"2"|null`）＋ **2^53 id fail-loud guard**（data-model §2）
- [x] T004 [P] **[test-first]** 在 `system_manage.rs` `#[cfg(test)]` 寫 **DTO serde round-trip 純測**（JSON↔i16 enum `"1"/"2"`+null／snake→camel／2^53 guard／`id`→number 含 getAllRoles；**有別於 T010 的 SelectStatement filter 形狀測**）— **先紅**後由 T003 轉綠
- [x] T005 [P] 加 `sys_role::find_active_by_codes(db,&[String])->Vec<Model>` facade（active + `Code.is_in`、empty-guard `Ok(vec![])`）＋**[test-first]** SQL-shape 純測（`build(Postgres).to_string()` pattern）— role code→id RI 解析用（data-model §3）
- [x] T006 [P] 加 `sys_user_role::find_role_ids_by_user_ids(db,&[i64])` ＋ `roles_for_users(db,&[i64])->Vec<(i64,Vec<String>)>` batch facade（避 list N+1、research R7）＋**[test-first]** SQL-shape 純測；**硬前置：先 grep m001 確認 `sys_user_role` btree(user_id) index 存在**（R7／analyze I5：batch perf load-bearing；缺則於 batch facade 落地前暴露為 perf-blocking）
- [x] T007 ★ **Q3 critical**：在 `handler/system_manage.rs`（或 facade）加撞名 pre-check（呼既有 `find_active_by_name`、命中且非本人 → `AppError::biz("用户名已存在")`→`2222`）＋**[test-first]** 純測斷 dup→**2222**（**非** `From<DbErr>`→5000；research Q3／error.rs:73-77）
- [x] T008 `rust-api/server/src/main.rs` 建 6 route 掛載骨架 ＋ `route_layer(from_fn_with_state(state, enforce_mw))` pattern（**首批 gated route**、`enforce_mw` 自 006 既有；research R4）— 依 T001
- [x] T009 在 `handler/system_manage.rs` 加 `AuditOperator{id: ctx.operator_id, ip: Some(ctx.client_ip)}` ＋ `trace_id: ctx.trace_id` 自 `Extension<RequestContext>` 取（007 as-built；SC-004 顯式 param）

**Checkpoint**：DTO／共享 facade／route 骨架／enforce pattern／dup-2222／audit-operator 就緒 → user story 可開工。

---

## Phase 3: User Story 1 — 瀏覽與搜尋使用者清單（P1）🎯 MVP

**Goal**：admin 看分頁 user 清單（含 roles）、依 name/nick/email 模糊＋phone/status/gender 精確 filter；角色下拉（getAllRoles）。
**Independent Test**：登入授權 admin → /manage/user → 見分頁清單＋roles → filter → 只剩命中列；getAllRoles 回 number id。

- [x] T010 [P] [US1] **[test-first]** `sys_user::search_active` filter SQL-shape 純測（name/nick/email LIKE `%x%`、phone/status/gender eq、null 略過、`id ASC`、paginate）— 先紅（`server/tests` 或 inline）
- [x] T011 [US1] 加 `sys_user::search_active(db,&UserSearchParams)->(Vec<Model>,u64)` facade（`find_active()`＋條件 filter＋id ASC＋paginate）— 依 T010
- [x] T012 [P] [US1] 加 `sys_role::all_active(db)->Vec<Model>` facade
- [x] T013 [US1] `get_user_list(Query<UserSearchParams>)` handler：`search_active` →（page user_ids）`roles_for_users` batch 組 userRoles → `Model→UserListItem` 映射 → `Res<PageRes<UserListItem>>`；掛 gated route — 依 T011/T006/T003/T008（**無新單測：wiring/映射、由 T015 live + C-V-7 覆蓋**）
- [x] T014 [US1] `get_all_roles()` handler：`all_active` → `AllRoleItem`（**id→number、不跟 mock string**）→ `Res<Vec<AllRoleItem>>`；掛 gated route — 依 T012/T008（**無新單測：wiring、由 T015 live 覆蓋**）
- [x] T015 [US1] **[live smoke `#[ignore]` serial]** `live_smoke_user_list`：getUserList filter（name 模糊/phone 精確）＋分頁＋userRoles join；getAllRoles `id` 為 number（C-V-3/4 對映）

**Checkpoint**：US1 可獨立 demo（list+search+roles+下拉）。base-web `fetchGetUserList`/`fetchGetAllRoles` 既有、讀端無前端新增。

---

## Phase 4: User Story 2 — 新增使用者（P1）

**Goal**：授權 admin 經 drawer 建 user（含 roles），預設密碼。
**Independent Test**：填表提交 → 新 user 入清單＋roles；同名 → 拒 2222。

- [x] T016 [US2] 加 `sys_user::create(db,fields,role_ids,operator,trace)->Model` facade（`mutate_in_txn`：argon2id(`"123456"`) host-gen password + INSERT + `replace_roles_in_txn`〔新增、見 T021 共用或此處先建〕 + `AuditEvent{Insert, payload_after: composite {..audit_json, roles}}`）— 依 T005/T007
- [x] T017 [US2] `add_user(Json<UserUpsertReq>)` handler：RI（dup pre-check→2222〔T007〕／`find_active_by_codes` 解 roleCode→ids、數不符→2222／status·gender 值域→2222）→ `create`；掛 gated route — 依 T016/T008（**無新單測：orchestration、由 T020 live + C-V-4 覆蓋**）
- [x] T018 [P] [US2] `rev3-system-manage.ts` 加 `addUser(model)` wrapper fn — 依 T002
- [x] T019 [US2] 接 `base-web/src/views/manage/user/modules/user-operate-drawer.vue` `handleSubmit` stub（create 分支→`addUser`）；原 `// request` 行保留為 `// [rev3-inline MW(c)] 原行: ...` 註解（MODAL-WIRING (c)、§III）— 依 T018（**無新單測：前端接線、由 C-V-6 CDP 覆蓋**）
- [x] T020 [US2] **[live smoke serial]** `live_smoke_user_create`：addUser→op-log **Insert** 列（`payload_after->'roles'` 在、`password`=`"<redacted>"`）；同名 addUser→**2222**（Q3）

**Checkpoint**：US1+US2 各自可獨立運作。

---

## Phase 5: User Story 3 — 編輯使用者（P1）

**Goal**：授權 admin 改 user（改名／狀態／roles）。
**Independent Test**：改 roles/status/name → 持久＋審計含 role-delta；改名撞名→拒；改已刪→拒。

- [x] T021 [US3] 加 `sys_user::update(db,id,fields,role_ids,operator,trace)->Model` facade（`mutate_in_txn`：snapshot 舊 composite〔`audit_json`＋`roles_for_user`〕 + UPDATE〔user_name 可變〕 + `replace_roles_in_txn` + `AuditEvent{Update, before+after composite}`）；同檔加 `replace_roles_in_txn(txn,user_id,&[i64])`（硬刪舊+插新、archetype C）— 依 T005/T007
- [x] T022 [US3] `update_user(Json<UserUpsertReq>)` handler：RI（`find_active_by_id(id)` 查無→2222／改名 `find_active_by_name` 撞名→2222／role 解析／值域）→ `update`；掛 gated route — 依 T021/T008（**無新單測：orchestration、由 T024 live 覆蓋**）
- [x] T023 [US3] `rev3-system-manage.ts` 加 `updateUser({...model, id})` wrapper（併 id、R3 edit 模式 model 帶 id）＋接 drawer `handleSubmit` update 分支 — 依 T018/T019（**無新單測：前端接線、C-V-6 覆蓋**）
- [x] T024 [US3] **[live smoke serial]** `live_smoke_user_update`：updateUser→**Update** 列 before/after **role-delta** 可見＋改名生效；改名撞名→2222；改已軟刪帳戶→2222

**Checkpoint**：US1-US3 各自可獨立運作。

---

## Phase 6: User Story 4 — 刪除使用者＋種子保護（P2）

**Goal**：單筆／批量刪除；種子帳號（id∈{1,2,3}）拒刪、批量含種子整批拒。
**Independent Test**：刪非種子→離開 active 清單；刪種子（單+批）→拒、零變更。

- [x] T025 [P] [US4] **[test-first]** 種子保護謂詞（`id∈{1,2,3}`）＋ batch 前置全量校驗 all-or-nothing 純測 — 先紅
- [x] T026 [US4] `delete_user(Query<{id:i64}>)` handler：種子保護（`id∈{1,2,3}`→2222）→ **複用既有 `sys_user::soft_delete`**（不改、Q1/Q2）；掛 gated route — 依 T025/T008
- [x] T027 [US4] `batch_delete_user(Query<{ids:Vec<i64>}>)` handler：前置全量校驗（任一 `id∈{1,2,3}`→整批 2222、不進 txn）→ 逐筆 `soft_delete`（各自獨立 txn、已軟刪 no-op 容忍）；掛 gated route — 依 T025/T026
- [x] T028 [P] [US4] `rev3-system-manage.ts` 加 `deleteUser({id})`／`batchDeleteUser({ids})` wrapper fns — 依 T002
- [x] T029 [US4] 接 `base-web/src/views/manage/user/index.vue` `handleDelete`/`handleBatchDelete` stub（→ wrapper）；原 `console.log`/`// request` 行保留為 `// [rev3-inline MW(a)] 原行: ...`（MODAL-WIRING (a)）— 依 T028（**無新單測：前端接線、C-V-6 覆蓋**）
- [x] T030 [US4] **[live smoke serial]** `live_smoke_user_delete`：deleteUser soft-delete＋種子 id∈{1,2,3}→2222；batch all-or-nothing（含種子整批拒）；已軟刪再刪→**no-op 零 audit**（Q2）

**Checkpoint**：US1-US4 各自可獨立運作。

---

## Phase 7: User Story 5 — 角色分級存取控制（P2）

**Goal**：各 admin 只能做其權限級允許的操作（R_SUPER 全寫；R_ADMIN 讀 list；R_USER_COMMON 只查角色）。
**Independent Test**：各級登入 → 允許者成、限制者拒（5003）。

- [x] T031 [US5] 驗 6 route 全掛 `route_layer(enforce_mw)`（無裸端點）；subject＝DB-fresh role code、驗既有 m002 policy（R5 矩陣）
- [x] T032 [US5] **stand up** `rust-api/server/tests/endpoint_coverage_lint.rs`（⚠️x 移交、首個 gated 刀）：build-failing lint 斷「每掛 enforce 的 route 有 ≥1 casbin policy」（容忍 seeded-but-unimplemented）；以 `entity_access_lint.rs` 為模板；`EXPECTED_ROUTE_COUNT` ＝ **本刀實際 gated route 數＝6**（getUserList/getAllRoles/addUser/updateUser/deleteUser/batchDeleteUser、別盲 DESIGN target 35、research R6／analyze C1）；視為 **SC-009 硬 gate**
- [x] T033 [US5] **[live smoke serial / curl]** forbidden-role：`User`/`Admin` token addUser → **5003**；`Admin` getUserList → ok（C-V-5）

**Checkpoint**：RBAC 驗證＋lint 守恆綠。

---

## Phase 8: User Story 6 — 使用者異動審計（含角色變更）（P3）

**Goal**：create/edit/delete 全進不可竄改審計；create/edit 含 role 前後；password 恆 redact。
**Independent Test**：各操作→審計列含 operator/time/before-after；role 變更見舊→新；password 不明文。

- [x] T034 [US6] **[live smoke serial]** `live_smoke_user_audit`（彙整審計斷言）：create→Insert（roles+redact）／update→Update **role-delta**（舊→新）／delete→SOFT_DELETE `payload_before` 15 欄 **無 roles**（**Q1=B**）／已軟刪→**零 audit**（**Q2=A**）／每筆 operator_id+trace_id 真值
- [x] T035 [US6] 驗 password 全程不明文：審計 `payload` 與 list/detail response 皆 `"<redacted>"`／不含 password 欄（FR-021）

**Checkpoint**：審計軌完整、Q1/Q2 live 驗（補 research 的 code-path-only gap）。

---

## Phase 9: Polish & Cross-Cutting

- [x] T036 [P] **p95 server-side C-V**（新類別、Q4）：`curl -w time_total` ×20 → getUserList p95<0.3s／add/update p95<0.5s（排冷啟）；psql 驗 `roles_for_users` batch 避 N+1（C-V-7）
- [x] T037 **CDP browser modal smoke（cutover）**：建 gitignored `base-web/.env.test.local`（`VITE_SERVICE_BASE_URL=http://rust-api:31081`）→ `tests/000` CDP（9229、localhost:31079、static mode）→ 導航 `/manage/user` → add/edit/delete 走真 rust-api → modal 關+列表刷新；**不導航 role/menu**（C-V-6；curl≠modal、雙軌）
- [x] T038 [P] curl+psql 全鏈 acceptance（C-V-4：login Super→getUserList→addUser→psql 驗 audit composite roles→同名 2222）
- [x] T039 [P] **fork-delta 稽核（MODAL-WIRING acceptance、analyze I6）**：`grep -rn rev3-inline base-web/src` 得完整 patch set ＝ 預期改動檔集（`rev3-system-manage.ts` 新＋`index.vue`／`user-operate-drawer.vue` 改）；確認 (i) `index.vue` handleDelete/handleBatchDelete ＋ drawer handleSubmit 原行保留為 `// [rev3-inline MW(a)/(c)] 原行: ...` (ii) `rev3-system-manage.ts` 4 wrapper fn 簽名正確 (iii) `system-manage.ts`／`auth.ts`／`route.ts` **未改**（§III ⚠️s）
- [x] T040 `cd rust-api && cargo build -p server --locked`（C-V-1、MSRV 1.86）＋ `cargo test -p server`（C-V-2 純測全綠）；確認 workspace members 仍 5（**無新 crate → prod build 不觸發**）
- [x] T041 跑 `quickstart.md` 驗收：C-V-1~8 全綠＋7 user-story acceptance scenarios＋10 SC＋Constitution Check 維持 PASS

---

## Dependencies & Execution Order

### Phase 依賴
- **Setup（P1）**：無依賴、即起。
- **Foundational（P2）**：依 Setup；**阻塞所有 user story**。
- **US1-US6（P3-P8）**：皆依 Foundational 完成；之後可並行（或依 P1→P2→P3 優先序循序）。
- **Polish（P9）**：依所有目標 story 完成。

### User Story 依賴／獨立性
- **US1（P1）**：依 Foundational；無 story 間依賴 → **MVP**。
- **US2（P1）**：依 Foundational；`create` facade 用 T005/T007（foundational）；可獨立測。
- **US3（P1）**：依 Foundational；`replace_roles_in_txn` 於 T021 建（US2 的 create 亦用 → 若 US2 先做可前移至 foundational；本表置 US3 並標 US2 依賴）。
- **US4（P2）**：依 Foundational；複用既有 `soft_delete`、與 US1-US3 獨立。
- **US5（P2）**：enforce route_layer 隨各 story route 掛載（T013/T014/T017/T022/T026/T027）；本階段＝驗證＋lint stand-up。
- **US6（P3）**：審計實作隨 US2/US3/US4 facade；本階段＝端到端審計驗證（Q1/Q2 live）。

### Story 內
- test-first 純函式（T004/T005/T006/T007/T010/T025）**先紅**後實作轉綠。
- facade（model）→ handler → route → 前端 wrapper/接線 → live smoke。
- wiring/orchestration task **無新單測**、由 live smoke + CDP（C-V）覆蓋（已於各 task 註明理由）。

### Parallel 機會
- Setup：T002 [P]。
- Foundational：T003/T004/T005/T006 [P]（不同檔/區）。
- US 內 [P]：T010·T012（US1）／T018（US2）／T028（US4）等不同檔。
- Foundational 完成後、US1-US6 可由不同人並行（各自獨立可測）。

---

## Parallel Example: Foundational

```bash
# T003 DTO+serde、T004 DTO 純測、T005 find_active_by_codes、T006 roles_for_users batch — 不同檔/區、可並行
Task: "T003 wire DTOs + serde in handler/system_manage.rs"
Task: "T004 [test-first] DTO serde 純測"
Task: "T005 sys_role::find_active_by_codes + test"
Task: "T006 sys_user_role::roles_for_users batch + test"
```

---

## Implementation Strategy

### MVP First（US1）
1. Phase 1 Setup → 2. Phase 2 Foundational（CRITICAL、阻塞）→ 3. Phase 3 US1 → 4. **STOP & VALIDATE**（list+search+roles 獨立測）→ demo。

### Incremental
US1（MVP）→ US2（create）→ US3（edit）→ US4（delete）→ US5（RBAC 驗+lint）→ US6（audit 驗）→ Polish（p95/CDP/全鏈/fork-delta 稽核/build）。每 story 獨立加值、不破前者。

### 收尾（非本 tasks.md 範圍、由 superpowers 流程）
全 story + Polish 綠後：`superpowers:finishing-a-development-branch` → 多段式 commit → `git merge --no-ff` 回 `rev3-admin-root`（**push/merge 才在此階段、保留 008 feature branch 供 audit**）。

---

## Notes
- [P]＝不同檔、無未完依賴；[Story]＝可追溯性。
- **test-first 純函式（驗先紅）；wiring 無新單測、acceptance 覆蓋（task 已註理由）**。live `#[ignore]` + `--test-threads=1`。
- 每 task 或邏輯組完成後 commit（**local**；push/merge 留收尾）。
- ★ **Q3**（dup→2222 pre-check、非 DbErr→5000）、**種子保護**（無既有碼）、**endpoint_coverage_lint**（不存在、008 建）、**p95 server-side**（新類別）為本刀實碼新增重點（research discrepancies）。
- 避免：vague task、同檔衝突、破壞 story 獨立性的跨 story 依賴。
