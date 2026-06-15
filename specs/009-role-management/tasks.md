---
description: "Task list — 009 Role Management"
---

# Tasks: Role Management（角色管理）

**Input**: Design documents from `/specs/009-role-management/`（plan.md / spec.md / research.md / data-model.md / contracts/verification-commands.md / quickstart.md）

**Prerequisites**: plan.md ＋ spec.md（必）；research.md（★8-agent 實碼 grep、含 Q-DUP critical gap）／data-model.md／contracts/ 皆在。

**Tests**: **included**（constitution §I.4 強制 SDD+TDD）。紀律（CLAUDE.md §3）：**純函式邏輯 test-first（red→green）**；**wiring／形狀對映類無新單元測試 → 由 acceptance 覆蓋**（contracts/ 的 C-V：live smoke + curl/psql + CDP），且 task 內**明示「無單元測試」及理由**。live 測 `#[ignore]` + `--test-threads=1`（共表 `sys_operation_log` 非 parallel-safe、memory `live-ignore-tests-need-serial`；`#[cfg(test)] mod` 於 `src/`、server bin-only crate）。

**Organization**: 按 user story（US1-US6、spec.md 優先序）分階段、各自獨立可測。

**實作紀律**: 交 `superpowers:executing-plans`（**不是 `/speckit-implement`**）；**`git push`／`git merge` 不得出現於 `finishing-a-development-branch` 前**（故本 tasks.md 不含 push/merge task）。base-web commit 一律 `--no-verify`（hook 在 alpine 壞、memory `base-web-precommit-hook-broken-in-alpine`）；rust implementer subagent **串行**（共用 target 平行 build 交叉污染、008 教訓）。

## Format: `[ID] [P?] [Story] Description`

- **[P]**：可並行（不同檔、無未完依賴）
- **[Story]**：US1-US6（setup/foundational/polish 無 story label）

## Path Conventions（plan.md Structure Decision — **grow existing**、非新檔）

- 後端：`rust-api/server/src/handler/system_manage.rs`（續寫）／`rust-api/server/src/model/facade/sys_role.rs`（續寫）／`main.rs`／`rust-api/server/tests/endpoint_coverage_lint.rs`
- 前端：`base-web/src/service/api/rev3-system-manage.ts`（續寫）／`base-web/src/views/manage/role/`

---

## Phase 1: Setup（grow-existing 前置）

- [ ] T001 [P] 確認 grow-existing 前置：`handler/system_manage.rs`／`model/facade/sys_role.rs`／`main.rs`／`tests/endpoint_coverage_lint.rs`／`base-web/src/service/api/rev3-system-manage.ts` 皆既有可擴；CDP cutover `base-web/.env.test.local`（008 建、gitignored、`VITE_SERVICE_BASE_URL=http://rust-api:31081`）present 可複用；`tests/000` CDP scripts 可複用。**確認無新檔／無新 workspace crate（members 固定 5）／無 migration**。

---

## Phase 2: Foundational（阻塞所有 story、必先完成）

**⚠️ CRITICAL**：本階段未完、任何 user story 不得開工。

- [ ] T002 在 `handler/system_manage.rs` 加 5 role handler **空骨架**（`get_role_list`/`add_role`/`update_role`/`delete_role`/`batch_delete_role`、最小回傳 placeholder 使編譯過）＋ `main.rs` 的 `system_manage` sub-router 註冊 5 route（**既有 `route_layer(enforce_mw)` 自動覆蓋**：getRoleList=GET、addRole/updateRole=POST、deleteRole/batchDeleteRole=DELETE、path 字面須與 m002 完全一致、R5）＋ `tests/endpoint_coverage_lint.rs` **`EXPECTED_ROUTE_COUNT` 6→11**＋檔頭 doc 註解更新（role 端點不再列為「seeded-but-unimplemented」範例、改舉 menu）→ 編譯過＋lint 綠（policy 皆已 seed、R5）
- [ ] T003 [P] 在 `system_manage.rs` 定 wire DTO（`RoleSearchParams`〔current/size/roleName?/roleCode?/status?〕／`RoleListItem`〔id number+2^53 guard／roleName／roleCode／roleDesc?／status／createBy／createTime／updateBy／updateTime〕／`RoleUpsertReq`〔`id:Option<i64>`／roleName／roleCode／roleDesc?／status〕），`#[serde(rename_all="camelCase")]`；status `i16↔"1"|"2"|null`（複用既有 `i16_to_wire`/`wire_to_i16`）＋ 2^53 id fail-loud guard（複用 `serialize_id_guarded`）；serde **不設 `deny_unknown_fields`**（drawer 多餘欄忽略、data-model §2）
- [ ] T004 [P] **[test-first]** 在 `system_manage.rs` `#[cfg(test)]` 寫 **RoleListItem/RoleUpsertReq serde 純測**（JSON↔i16 enum `"1"/"2"`+null／snake→camel〔name→roleName/code→roleCode/role_desc→roleDesc〕／`id`→number+2^53 guard；**有別於 T009 的 SelectStatement filter 形狀測**）— **先紅**後由 T003 轉綠
- [ ] T005 [P] 在 `facade/sys_role.rs` 定 `NewRole{code,name,role_desc:Option,status:Option<i16>}` ＋ `RoleFilter{role_name:Option,role_code:Option,status:Option<i16>}` struct（model 層、不收 wire DTO、避層級倒置、沿 008 `ActiveUserFilter`；data-model §3）
- [ ] T006 [P] 加 `sys_role::find_active_by_id(db,i64)->Option<Model>` ＋ `find_active_by_code(db,&str)->Option<Model>`（active 濾、singular、dup-check／update-delete pre-check 用）＋**[test-first]** SQL-shape 純測（`build(Postgres).to_string()` pattern、斷 `deleted_at IS NULL` + code/id eq）— data-model §3
- [ ] T007 加 `impl AuditSerialize for sys_role::Model`（**leaf**：role 12 欄全入、**無 redaction**〔無 password〕、**無 roles key**〔role 不觸 join〕）＋**[test-first]** `audit_json()` 純測（斷 12 欄在、無 roles/password key）— data-model §6（write 路徑共用、阻塞 US2/US3/US4）
- [ ] T008 ★ **Q-DUP**：在 `system_manage.rs` 加 `ensure_role_code_available(db,code,self_id)` pre-check helper（呼 `find_active_by_code`、命中→`AppError::biz("角色代码已存在")`→`2222`、復用純函式 `check_name_collision`）＋ `is_seed_role(id)->bool`（id∈{1,2,3}）＋**[test-first]** 純測斷 dup→**2222**（**非** `From<DbErr>`→5000、research Q-DUP／error.rs:73-77）＋ seed 謂詞

**Checkpoint**：route 骨架（5 gated、lint 綠 11）／DTO／facade structs+reads／leaf AuditSerialize／dup-2222+seed helper 就緒 → user story 可開工。

---

## Phase 3: User Story 1 — 瀏覽與搜尋角色清單（P1）🎯 MVP

**Goal**：admin 看分頁 role 清單、依 roleName/roleCode 模糊＋status 精確 filter。
**Independent Test**：登入 Super/Admin → /manage/role → 見分頁清單 → filter → 只剩命中列；空 filter 不限縮；id 為 number。

- [ ] T009 [P] [US1] **[test-first]** `sys_role::search_active` filter SQL-shape 純測（roleName/roleCode LIKE `%x%`、status eq、null/blank 略過、`id ASC`、paginate）— 先紅
- [ ] T010 [US1] 加 `sys_role::search_active(db,&RoleFilter,current,size)->(Vec<Model>,u64)` facade（`find_active()`＋`role_name`/`role_code` `.contains`＋`status` `.eq`＋null 略過＋id ASC＋paginate）— 依 T009/T005
- [ ] T011 [US1] 填 `get_role_list(Query<RoleSearchParams>)` handler body：`RoleSearchParams`→`blank_to_none`（roleName/roleCode）＋`wire_to_i16`（status）正規化〔**空字串→None、008 同款 bug 守門**〕→`RoleFilter`→`search_active`→`Model→RoleListItem` 映射→`Res<PageRes<RoleListItem>>`（route 已於 T002 wired）— 依 T010/T003（**無新單測：wiring/映射、由 T012 live + C-V-7 覆蓋**）
- [ ] T012 [US1] **[live smoke `#[ignore]` serial]** `live_smoke_role_list`：getRoleList roleName/roleCode 模糊命中＋status 精確＋分頁＋`id ASC`＋`id` 為 number；**空字串 filter 守門**（`status=""`/`roleName=""`→None、列表非空、回真 3 角色）（C-V-3/4 對映）

**Checkpoint**：US1 可獨立 demo（list+模糊 search）。base-web `fetchGetRoleList` 既有、讀端無前端新增。

---

## Phase 4: User Story 2 — 新增角色（P1）

**Goal**：授權 admin 經 drawer 建 role；同碼拒 2222。
**Independent Test**：填表提交 → 新 role 入清單；同 roleCode → 拒 2222。

- [ ] T013 [US2] 加 `sys_role::create(db,fields:NewRole,operator,trace)->Model` facade（`mutate_in_txn`：`create_query`〔INSERT、created_by=operator.id、home 用 entity default〕＋`AuditEvent{Insert, payload_after:Some(audit_json), before:None}`〔**leaf、無 roles**〕）；★ **對 pg `23505`（`sys_role_code_active_uniq`）unique-violation targeted catch → `AppError::biz`→`2222`**（兌現 spec Clarification A「race 永不 5000」、繞過 `From<DbErr>`→5000、data-model §4）— 依 T005/T007/T008
- [ ] T014 [US2] 填 `add_role(Json<RoleUpsertReq>)` handler body：RI（`ensure_role_code_available(roleCode)` dup→2222〔T008〕／`status` 值域 `wire_to_i16`→2222）→ `create`（route 已 wired）— 依 T013（**無新單測：orchestration、由 T017 live + C-V-4 覆蓋**）
- [ ] T015 [P] [US2] `rev3-system-manage.ts` 加 `fetchAddRole(model:Pick<Role,'roleName'|'roleCode'|'roleDesc'|'status'>)` wrapper（POST `/systemManage/addRole`、`// [rev3-inline WRAPPER]` 標記；不改既有 `system-manage.ts`）— 依 T001
- [ ] T016 [US2] 接 `base-web/src/views/manage/role/modules/role-operate-drawer.vue`：`handleSubmit` stub（create 分支→`fetchAddRole`）＋ roleCode `NInput` 加 `:disabled="isEdit"`（FR-006 edit 時 read-only）；原 stub 行保留為 `// [rev3-inline MW(a)] 原行: ...`（MODAL-WIRING (a)、§III）— 依 T015（**無新單測：前端接線、由 C-V-6 CDP 覆蓋**）
- [ ] T017 [US2] **[live smoke serial]** `live_smoke_role_create`：addRole→op-log **Insert** 列（`payload_after` = role 12 欄、**無 roles key、無 password**）；同碼 addRole→**2222**（pre-check）；**並發撞碼（DB `23505`）→2222**（非 5000、Clarification A）

**Checkpoint**：US1+US2 各自可獨立運作。

---

## Phase 5: User Story 3 — 編輯角色（P1）

**Goal**：授權 admin 改 role（roleName/roleDesc/status）；**roleCode 不可變**；改已刪→拒。
**Independent Test**：改 name/desc/status → 持久＋審計 before/after；roleCode 不變；改已軟刪→拒 2222。

- [ ] T018 [US3] 加 `sys_role::update(db,id,fields:NewRole,operator,trace)->Model` facade（`mutate_in_txn`：snapshot 舊 `audit_json` → `update_set_query`〔UPDATE name/role_desc/status；**code 欄不入**、updated_at/by 成對 §I.6〕→ `AuditEvent{Update, before/after}`）＋ `create_query`/`update_set_query`/`soft_delete_query` helper（建 stmt、沿 008）— 依 T005/T007
- [ ] T019 [US3] 填 `update_role(Json<RoleUpsertReq>)` handler body：RI（`find_active_by_id(id)` 查無→2222〔soft-deleted 拒更〕／`status` 值域→2222；**roleCode 不可變＝提交的 code 不傳入 update**）→ `update`（route 已 wired）— 依 T018（**無新單測：orchestration、由 T021 live 覆蓋**）
- [ ] T020 [US3] `rev3-system-manage.ts` 加 `fetchUpdateRole({...model,id})` wrapper（併 id、R3 edit 模式）＋接 drawer `handleSubmit` update 分支（`operateType` 判定）— 依 T015/T016（**無新單測：前端接線、C-V-6 覆蓋**）
- [ ] T021 [US3] **[live smoke serial]** `live_smoke_role_update`：updateRole→**Update** 列 before/after（roleName/roleDesc/status 變、**roleCode 不變**〔即使提交改 code〕）；改已軟刪 role→2222

**Checkpoint**：US1-US3 各自可獨立運作。

---

## Phase 6: User Story 4 — 刪除角色＋種子保護（P2）

**Goal**：單筆／批量 soft-delete；種子 role（id∈{1,2,3}）拒刪、批量含種子整批拒。
**Independent Test**：刪非種子→離開 active 清單；刪種子（單+批）→拒、零變更。

- [ ] T022 [P] [US4] **[test-first]** batch 前置全量校驗 all-or-nothing 純測（任一 id∈{1,2,3}→整批拒；comma-parse 惡形→拒）＋ `is_seed_role`〔已於 T008〕複用斷言 — 先紅
- [ ] T023 [US4] 加 `sys_role::soft_delete(db,id,operator,trace)->bool` facade（沿 008 形：`mutate_in_txn`、`soft_delete_query`〔deleted_at/by 成對〕、`AuditEvent{SoftDelete, before:audit_json, after:None}`；已軟刪→`Ok((txn,false,None))` no-op 零 audit）— 依 T007/T018（helper）
- [ ] T024 [US4] 填 `delete_role(Query<{id:i64}>)` handler body：種子保護（`is_seed_role(id)`→2222）→ `soft_delete`（route 已 wired）— 依 T022/T023
- [ ] T025 [US4] 填 `batch_delete_role(Query<{ids:String}>)` handler body：comma-parse（惡形→2222）→ 前置全量種子校驗（任一 `is_seed_role`→整批 2222、不進 txn、FR-011）→ 逐筆 `soft_delete`（各自獨立 txn、已軟刪 no-op 容忍、⚠️a）— 依 T022/T023/T024
- [ ] T026 [P] [US4] `rev3-system-manage.ts` 加 `fetchDeleteRole(id)`（DELETE `?id=`）／`fetchBatchDeleteRole(ids:number[])`（DELETE `?ids=1,2,3`）wrapper — 依 T001
- [ ] T027 [US4] 接 `base-web/src/views/manage/role/index.vue` `handleDelete`/`handleBatchDelete` stub（→ wrapper、await 後刷新）；原 `console.log` 行保留為 `// [rev3-inline MW(a)] 原行: ...`（MODAL-WIRING (a)）— 依 T026（**無新單測：前端接線、C-V-6 覆蓋**）
- [ ] T028 [US4] **[live smoke serial]** `live_smoke_role_delete`：deleteRole soft-delete＋種子 id∈{1,2,3}→2222；batch all-or-nothing（含種子整批拒、一筆不刪）；已軟刪再刪→**no-op 零 audit**

**Checkpoint**：US1-US4 各自可獨立運作。

---

## Phase 7: User Story 5 — 角色分級存取控制（P2）

**Goal**：各 admin 只能做其權限級允許的操作（R_SUPER 全寫＋讀；R_ADMIN 讀 list；R_USER_COMMON 無 role 管理）。
**Independent Test**：各級登入 → 允許者成、限制者拒（5003）。

- [ ] T029 [US5] 驗 5 role route 全掛 `route_layer(enforce_mw)`（無裸端點）；subject＝DB-fresh role code、驗既有 m002 policy（R5 矩陣：getRoleList=R_SUPER+R_ADMIN、addRole/updateRole/deleteRole/batchDeleteRole=R_SUPER）
- [ ] T030 [US5] `endpoint_coverage_lint` 綠驗（`EXPECTED_ROUTE_COUNT=11` 已於 T002 bump、doc 更新確認）＋**sanity-bite**（暫破一條 role policy 或 route → `cargo test endpoint_coverage_lint` 須大聲失敗指名 → 復原）；SC-009 硬 gate（C-V-8）
- [ ] T031 [US5] **[live smoke serial / curl]** 讀寫分權：`Admin` token getRoleList→**ok(0000)**、addRole→**5003**；`User` token getRoleList→**5003**（C-V-5）

**Checkpoint**：RBAC 驗證＋lint 守恆綠（11）。

---

## Phase 8: User Story 6 — 角色異動審計（leaf）（P3）

**Goal**：create/edit/delete 全進不可竄改 leaf 審計；**無 composite roles、無 password**。
**Independent Test**：各操作→審計列含 operator/time/before-after（role 自身欄）；無 roles/password key。

- [ ] T032 [US6] **[live smoke serial]** `live_smoke_role_audit`（彙整審計斷言）：create→Insert（`payload_after` 12 欄）／update→Update before/after（roleName/roleDesc/status 變、**code/created 不變**）／delete→SOFT_DELETE `payload_before`、after=None／已軟刪→**零 audit**／每筆 operator_id+trace_id 真值
- [ ] T033 [US6] 驗 **leaf 性**（FR-017）：op-log `payload` **無 `roles` key、無 `password` 欄**（Role 12 欄全 audit-safe）；對照 008 composite/redact 的兩處 delta（無 composite role-delta、無 redaction）

**Checkpoint**：leaf 審計軌完整。

---

## Phase 9: Polish & Cross-Cutting

- [ ] T034 [P] **p95 server-side C-V**（⚠️a）：`curl -w time_total` ×20 → getRoleList p95<0.3s／addRole·updateRole p95<0.5s（排冷啟、含同 txn audit）；role 表小、leaf 無 join → 預期遠優於上限（C-V-7）
- [ ] T035 **CDP browser modal smoke（cutover）**：`base-web/.env.test.local`（008 建、複用、`→rust-api:31081`）→ **重啟 base-web 容器** → `tests/000` CDP（9229、localhost:31079、static mode、改選擇器對 role 頁）→ 導航 `/manage/role` → **列表載真 3 角色（空字串 filter 守門印證）** → drawer add/edit（**驗 roleCode disabled**）/delete 走真 rust-api → drawer 關+列表刷新；**不導航 `/manage/menu`**（無後端→404）（C-V-6；curl≠modal、雙軌）
- [ ] T036 [P] curl+psql 全鏈 acceptance（C-V-4：login Super→getRoleList→addRole→psql 驗 leaf audit〔無 roles key〕→同碼 2222→updateRole 改 name 試改 code〔驗 code 不變〕→deleteRole id=1 種子→2222）
- [ ] T037 [P] **fork-delta 稽核（MODAL-WIRING acceptance）**：`grep -rn rev3-inline base-web/src` 得完整 patch set ＝ 預期改動檔集（`rev3-system-manage.ts` +4 wrapper〔新增區塊〕＋`index.vue`／`role-operate-drawer.vue` 改）；確認 (i) `index.vue` handleDelete/handleBatchDelete ＋ drawer handleSubmit 原行保留為 `// [rev3-inline MW(a)] 原行: ...` (ii) drawer roleCode `:disabled="isEdit"` 在 (iii) 4 wrapper fn 簽名正確 (iv) `system-manage.ts`／`auth.ts`／`route.ts` **未改**（§III ⚠️s）
- [ ] T038 `cd rust-api && cargo build -p server --locked`（C-V-1、MSRV 1.86）＋ `cargo test -p server`（C-V-2 純測全綠）；確認 workspace members 仍 **5**（C-V-0、**無新 crate → prod build 不觸發**）
- [ ] T039 跑 `quickstart.md` 驗收：C-V-0~8 全綠＋6 user-story acceptance scenarios（spec §User Scenarios）＋10 SC＋Constitution Check 維持 PASS

---

## Dependencies & Execution Order

### Phase 依賴
- **Setup（P1）**：無依賴、即起。
- **Foundational（P2）**：依 Setup；**阻塞所有 user story**。T002（route 骨架+lint bump）使編譯+lint 綠、為後續前置。
- **US1-US6（P3-P8）**：皆依 Foundational 完成；之後可並行（或依優先序 P1→P2→P3 循序）。
- **Polish（P9）**：依所有目標 story 完成。

### User Story 依賴／獨立性
- **US1（P1）**：依 Foundational；無 story 間依賴 → **MVP**。
- **US2（P1）**：依 Foundational（`create` 用 T007 AuditSerialize／T008 dup helper）；可獨立測。
- **US3（P1）**：依 Foundational；`update`/query helper 於 T018 建；drawer update 分支 T020 依 T016（同檔）。
- **US4（P2）**：依 Foundational；`soft_delete` 用 T018 的 helper；與 US1-US3 邏輯獨立。
- **US5（P2）**：enforce route_layer 於 T002 隨 5 route 一次掛載；本階段＝驗證＋lint 綠驗+sanity-bite。
- **US6（P3）**：審計實作隨 US2/US3/US4 facade（T013/T018/T023）；本階段＝端到端 leaf 審計驗證。

### Story 內
- test-first 純函式（T004/T006/T009/T022／及 T008 helper 測）**先紅**後實作轉綠。
- facade（model）→ handler body（route 已 wired）→ 前端 wrapper/接線 → live smoke。
- wiring/orchestration task **無新單測**、由 live smoke + CDP（C-V）覆蓋（已於各 task 註明理由）。

### Parallel 機會
- Setup：T001 [P]。
- Foundational：T003/T004/T005/T006 [P]（不同檔/區；T002 須先〔骨架使編譯過〕、T007/T008 依 reads）。
- US 內 [P]：T015（US2 wrapper）／T026（US4 wrapper）等不同檔。
- Foundational 完成後、US1-US6 可由不同人並行（各自獨立可測）。

---

## Parallel Example: Foundational

```bash
# T002 先（骨架+route+lint bump 使編譯+lint 綠）；之後 T003/T004/T005/T006 不同檔/區、可並行
Task: "T003 wire DTOs + serde in handler/system_manage.rs"
Task: "T004 [test-first] DTO serde 純測"
Task: "T005 NewRole/RoleFilter structs in facade/sys_role.rs"
Task: "T006 find_active_by_id/find_active_by_code reads + SQL-shape test"
```

---

## Implementation Strategy

### MVP First（US1）
1. Phase 1 Setup → 2. Phase 2 Foundational（CRITICAL、阻塞）→ 3. Phase 3 US1 → 4. **STOP & VALIDATE**（list+模糊 search 獨立測）→ demo。

### Incremental
US1（MVP）→ US2（create）→ US3（edit）→ US4（delete）→ US5（RBAC 驗+lint）→ US6（leaf audit 驗）→ Polish（p95/CDP/全鏈/fork-delta 稽核/build）。每 story 獨立加值、不破前者。

### 收尾（非本 tasks.md 範圍、由 superpowers 流程）
全 story + Polish 綠後：`superpowers:finishing-a-development-branch` → 多段式 commit → `git merge --no-ff` 回 `rev3-admin-root`（**push/merge 才在此階段、保留 009 feature branch 供 audit**）。

---

## Notes
- [P]＝不同檔、無未完依賴；[Story]＝可追溯性。
- **test-first 純函式（驗先紅）；wiring 無新單測、acceptance 覆蓋（task 已註理由）**。live `#[ignore]` + `--test-threads=1`、`#[cfg(test)] mod` 於 `src/`。
- 每 task 或邏輯組完成後 commit（**local**；push/merge 留收尾）。base-web commit `--no-verify`、rust implementer 串行。
- ★ 本刀實碼新增重點（research ★ discrepancies）：**Q-DUP**（dup→2222 pre-check ＋ create 內 `23505` race catch、皆非 5000）／**leaf 審計**（無 composite/redact）／**roleCode 不可變**（update 不入 code、前端 disabled）／**種子保護**（id∈{1,2,3}）／**endpoint_coverage_lint bump 6→11**（非 stand-up）／**handler 續寫既有檔**（grow `system_manage.rs`/`sys_role.rs`）。
- 避免：vague task、同檔衝突、破壞 story 獨立性的跨 story 依賴。
