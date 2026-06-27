# Tasks: 角色刪除授權歸檔（020-role-delete-policy-archive）

**Input**: Design docs from `specs/020-role-delete-policy-archive/`（plan.md／spec.md／research.md／data-model.md／contracts/verification-commands.md／quickstart.md）
**Branch**: `020-role-delete-policy-archive`
**Tests**: TDD requested（CLAUDE.md §3 + spec §7）→ 含測試任務（純函式 test-first；wiring/形狀類由 facade live 測 + C-V acceptance 覆蓋）。

## Format: `[ID] [P?] [Story] Description`
- **[P]**＝可平行（不同檔、無未完相依）。**rust 任務一律不標 [P]**：共用 cargo target、CLAUDE.md §3 全程 serial（即使邏輯獨立）。base-web 任務 [P] 限不同檔且無相依。
- 路徑：rust-api worktree `rust-api/...`／base-web worktree `base-web/...`。

## Path Conventions（本刀）
- rust：`rust-api/server/src/model/facade/{sys_role,sys_casbin_rule,sys_casbin_policy_archive}.rs`、`rust-api/server/src/handler/system_manage.rs`
- base-web：`base-web/src/{typings/api/rev3-system-manage.d.ts, typings/app.d.ts, locales/langs/{zh-cn,en-us}.ts, views/manage/policy-archive/modules/policy-archive-table.vue}`

## Execution notes（交 階段 2 superpowers:executing-plans + Workflow）
- rust build/test 在 rust-api 容器內 `docker exec`（host 無 cargo）；live `#[ignore]` 測帶 `DATABASE_URL` + `--test-threads=1`；改 `.rs` 後 force-touch 防 /mnt/d stale-mtime。
- base-web commit `--no-verify`（alpine pre-commit 壞）；自驗 `pnpm typecheck`；加 i18n 鍵後 `restart base-web` 防 vite stale-locale 再跑 CDP。
- **★ 絕不 push/merge**（worktree commit 只 local，收尾才 finishing-a-development-branch）；每執行單元邊界 bump submodule pin（§4.1）。

---

## Phase 1: Setup（前置）

- [ ] T001 確認 dev stack healthy（`docker compose -f docker-compose.yml -f docker-compose.dev.yml ps`）、CDP:9229 活、Super 登入 0000、測試 IP 未鎖；psql 記 baseline（`SELECT count(*) FROM sys_casbin_policy_archive;` 與 `SELECT DISTINCT v0 FROM casbin_rule WHERE ptype='p';`）（C-V-0）

---

## Phase 2: Foundational（阻斷前置 — US1 FR-012 與 US2 共用）

- [ ] T002 [test-first] restorability 衍生**純函式**單元測試 in `rust-api/server/src/handler/system_manage.rs`（`#[cfg(test)]`）：`restorable(reason:&str, active_role_created_at:Option<DateTimeWithTimeZone>, archived_at:DateTimeWithTimeZone)->bool`，覆蓋 data-model.md 真值表 5 情境（live 撤銷=true／role_soft_delete=false／已刪無active=false／重用 created_at>archived=false／重用後新撤銷=true）
- [ ] T003 實作純函式 `restorable(...)`（make T002 pass）in `rust-api/server/src/handler/system_manage.rs`（撤銷類 reason 集＝role_dimension_revoke/role_button_revoke/role_endpoint_revoke；AND active_created_at.is_some() AND active_created_at < archived_at）

---

## Phase 3: User Story 1 - 角色刪除即清授權、重建同 code 不繼承（Priority: P1）🎯 MVP

**Goal**：角色軟刪（單筆/批次）同交易移除+歸檔該 code 全維 casbin 授權；重建同 code 查授權皆空（getMenu 路徑）。
**Independent Test**：建角色 grant 三維→deleteRole→重建同 code→getRoleMenu/Button/Endpoints 皆 []；psql casbin v0=code＝0、archive role_soft_delete 列存在。

### Tests for User Story 1 ⚠️（live、in-crate `#[ignore]`+env-gate）
- [ ] T004 [US1] facade live 測 in `rust-api/server/src/model/facade/sys_casbin_rule.rs`（`#[cfg(test)] #[ignore]`）：`archive_all_role_policies` — 建拋棄角色 grant menu+button+endpoint→呼 helper→斷言 casbin `ptype='p' v0=code` 全消 + `sys_casbin_policy_archive` 三維列 reason=`role_soft_delete`+archived_by；**0-授權角色**＝archived 回 0、no-op
- [ ] T005 [US1] soft_delete 整合 live 測 in `rust-api/server/src/model/facade/sys_role.rs`（`#[ignore]`）：soft_delete 後同 txn casbin 全消+archive 增（單筆與 batch 變體）；rollback 隔離（外層 txn）

### Implementation for User Story 1（rust serial）
- [ ] T006 [US1] 新 facade helper `archive_all_role_policies(txn,&role_code,operator_id)->Result<usize,DbErr>` in `rust-api/server/src/model/facade/sys_casbin_rule.rs`（讀 `ptype='p' AND v0=code` 全維 Model→`sys_casbin_policy_archive::insert_archived(txn,&rows,Some(op_id),"role_soft_delete")`→`casbin_rule::delete_many` 同條件→回列數；走 facade、不破 entity_access_lint）
- [ ] T007 [US1] extend `sys_role::soft_delete` in `rust-api/server/src/model/facade/sys_role.rs`：mutate_in_txn closure 內設 deleted_at/by 後呼 `archive_all_role_policies(&txn, &before.code, operator.id)`（同 txn）；簽名/呼叫端取得 role_code（自 before Model）；回傳補 archived 數供 handler 判 reload
- [ ] T008 [US1] extend `sys_role::batch_soft_delete` in `rust-api/server/src/model/facade/sys_role.rs`：單 txn 迴圈內每角色呼 archive helper；累計 archived 總數回傳
- [ ] T009 [US1] handler `delete_role`(1208)/`batch_delete_role`(1239) in `rust-api/server/src/handler/system_manage.rs`：守門（seeded/in-use/self）**後**走擴充 soft_delete；txn commit 後 `archived>0 → reload_and_publish(&state).await?`（archived==0 skip、PolicyMutated gate）
- [ ] T010 [US1] acceptance（rust 容器 curl/psql）：C-V-1（delete→重建同 code→getRoleMenu/Button/Endpoints 皆 []、casbin v0=code＝0）+ C-V-2（archive role_soft_delete 列）+ C-V-8（reload）+ C-V-10（batch 變體 + 守門整批拒零歸檔）

**Checkpoint US1**：重建同 code 無 getMenu 繼承（MVP 達成）；主線 bump rust-api submodule pin。

---

## Phase 4: User Story 2 - 回收桶顯示 + 標示來源 + 不可手動復原（Priority: P2）

**Goal**：歸檔列在回收桶可見、欄位標來源、`restorable=false` 不可復原（涵蓋 FR-005 role_soft_delete + FR-012 既有撤銷列刪後/重用後）；後端守門為安全邊界。
**Independent Test**：回收桶顯 role_soft_delete 列 restorable=false + 來源譯文 + 復原鈕停用；restorePolicy 打不可復原列→2222；FR-012 既有撤銷列刪後/重用後 restorable=false。

### Tests for User Story 2 ⚠️（live）
- [ ] T011 [US2] live 測 in `rust-api/server/src/handler/system_manage.rs`（`#[ignore]`）或 facade：getArchivedPolicies restorable 衍生（live 角色撤銷列=true／role_soft_delete=false／FR-012 既有撤銷列刪後=false、重用後=false）+ restorePolicy 守門（不可復原列→NotRestorable→2222）

### Implementation for User Story 2
- [ ] T012 [US2] `ArchivedPolicyItem`(387) +`restorable: bool` + `get_archived_policies`(1844) 衍生 in `rust-api/server/src/handler/system_manage.rs`：批次取 page rows 的 distinct v0 → 查 active `sys_role` code→created_at map（新 facade 讀 `sys_role::active_created_at_by_codes` 或既有）→ per row 套 `restorable()`（T003）；不過濾 role_soft_delete
- [ ] T013 [US2] facade `sys_casbin_policy_archive::restore` 加 `RestoreOutcome::NotRestorable`（載列後套 restorability 衍生、不 mutate）+ handler `restore_policy`(1888) map → `AppError::Biz("biz.policy.notRestorable")`（2222）in `rust-api/server/src/{model/facade/sys_casbin_policy_archive.rs, handler/system_manage.rs}`
- [ ] T014 [P] [US2] base-web `ArchivedPolicy` 型 +`restorable: boolean` in `base-web/src/typings/api/rev3-system-manage.d.ts:285-294`（rev3 wrapper、ADAPT 軌、rev3-inline 標記）
- [ ] T015 [P] [US2] base-web i18n Schema in `base-web/src/typings/app.d.ts`：`backend.biz.policy.notRestorable`（@329 區 backend.biz 加 policy）+ `page.manage.policyArchive.*`（reason labels：roleDimensionRevoke/roleButtonRevoke/roleEndpointRevoke/roleSoftDelete + notRestorable 指示）（@963 區）（I18N-WIRING iii、先 Schema）
- [ ] T016 [US2] base-web locales 雙語 in `base-web/src/locales/langs/{zh-cn,en-us}.ts`：對應 T015 鍵的 zh-cn/en-us 譯文（policyArchive reason labels + notRestorable）（I18N-WIRING ii、後 locale；depends T015）
- [ ] T017 [US2] base-web `policy-archive-table.vue` in `base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue`：archiveReason 欄(73-79)→`$t` 友善 label map；operate 欄(80-100)→`row.restorable===false` 顯「不可復原」停用態（無復原鈕）/ `true` 維持復原鈕（MODAL-WIRING、rev3-inline；depends T014,T016）
- [ ] T018 [US2] acceptance/CDP：C-V-4（restorable 旗標）+ C-V-5（FR-012 既有撤銷列刪後/重用後 restorable=false + restorePolicy→2222 未裝回）+ C-V-6（role_soft_delete 列 restorePolicy→2222）+ C-V-9（CDP 回收桶顯示+來源譯文+復原鈕停用、雙語、restart base-web 後驗 toast 非 raw key）

**Checkpoint US2**：回收桶透明 + 不可誤復原 + restore-path 封閉；主線 bump rust-api + base-web submodule pin。

---

## Phase 5: User Story 3 - 不傷既有治理、資料不丟、原子（Priority: P3）

**Goal**：原子（注入失敗全回滾）、零回歸（既有撤銷→復原仍可用）、lint/prod gate 綠。
**Independent Test**：archive 步注入 error→角色與 casbin 皆回滾；live 角色撤銷→復原 0000；lint+prod build 綠。

### Tests for User Story 3 ⚠️（live）
- [ ] T019 [US3] 原子回滾 live 測 in `rust-api/server/src/model/facade/sys_role.rs`（`#[ignore]`）：archive 步注入 DbErr→soft_delete 整 txn 回滾（角色 deleted_at 未設 ⇔ casbin 未動 ⇔ archive 未增）（C-V-3、FR-003）

### Implementation / Validation for User Story 3
- [ ] T020 [US3] 零回歸驗（curl/psql + CDP）：live 角色手動撤銷一條→回收桶 restorable=true→restorePolicy 0000（Applied、casbin 復原、archive 硬刪消費）（C-V-7、既有 015/016 流程不變）
- [ ] T021 [US3] lint + prod gate（rust 容器 + docker）：`cargo test -p server --test entity_access_lint` 綠 / `--test endpoint_coverage_lint` 綠 / `docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（C-V-11）

---

## Phase 6: Polish & Cross-Cutting

- [ ] T022 清理 throwaway（soft-delete 角色 / psql 清其 casbin_rule + archive 列）→ DB 回 baseline（archive 與 §T001 一致、無殘留 active 角色/casbin/user_role）
- [ ] T023 final holistic review：spec FR-001~012 / SC-001~007 逐項對照 + Constitution 9/9 複核 + 全 rust 測 run（零回歸）+ data-model.md:87 stale 勘誤評估（收尾刀時）
- [ ] T024 收尾準備（交 finishing-a-development-branch）：擬多段式 commit + 進度回填清單（MILESTONES append、CHECKLIST §3.K 勾掉/歸檔、DECISIONS §1 登拍板〔修向 + Q1 FR-012 created_at 衍生〕、§6 marker）—— **push/merge 需 user 同意**

---

## Dependencies & Story Completion Order

- **Setup（T001）** → **Foundational（T002-T003）** → **US1（T004-T010）** → **US2（T011-T018）** → **US3（T019-T021）** → **Polish（T022-T024）**。
- Foundational `restorable()`（T003）阻斷 US1 的 FR-012 驗（T010 重建路徑）與 US2（T012/T013）。
- US1（archive-on-delete）為 US2 顯示的前提（要有 role_soft_delete 列才驗回收桶）。
- US3 原子/回歸/gate 依賴 US1+US2 已落地。
- rust 全程 serial（T002-T013,T019,T021 共用 target）；base-web T014/T015 可 [P]（不同檔），T016 依 T015、T017 依 T014+T016。

## Parallel opportunities
- base-web：T014（型）與 T015（Schema）可平行；其餘 rust serial。
- 跨 worktree：US2 的 rust（T011-T013）與 base-web（T014-T017）邏輯獨立、但執行上 rust serial 段先行、base-web 隨後（wire 對齊 restorable）。

## Implementation Strategy（MVP first）
- **MVP＝US1（Phase 1-3）**：角色刪除清授權 + 重建不繼承（getMenu 路徑）—— 獨立可交付、封住 P-011-1 核心靜默繼承。
- 增量：US2（回收桶透明+不可復原+restore-path 封閉 FR-012）→ US3（原子/回歸/gate）。
- 每 phase checkpoint：主線復核 + load-bearing 自驗（容器 cargo build/test）+ bump submodule pin（§4.1 逐單元）。

## 執行單元對映（交 階段 2 Workflow 驅動）
- **U1 rust**＝T002-T013,T019,T021（Foundational + US1 + US2-rust + US3-rust）serial 一支。
- **U2 base-web**＝T014-T017（US2-base-web）一支。
- acceptance/CDP（T010/T018/T020）+ Polish（T022-T024）＝主線邊界 checkpoint。
