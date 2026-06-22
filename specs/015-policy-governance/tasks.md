# Tasks: Policy 治理島（授權規則回收桶）

**Feature Branch**: `015-policy-governance` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

> 接地 pin rust-api `7ec8fc3` / base-web `f3b2bf07`。**零 migration、零新 crate**（archive 表 m001、2 endpoint+menu policy seed m002 全波0已備）。
> 階段 2 由 `superpowers:executing-plans` + Workflow 依**實際相依/獨立可審邊界**重組執行單元（不綁本清單編號）。rust **全程 serial**（共用 target）；容器內 build/test（`--test-threads=1` live）；base-web `--no-verify`；★ 絕不 push/merge until finishing。

## Format: `[ID] [P?] [Story] Description with file path`
- `[P]`＝可平行（不同檔、無未完相依）；rust 跨檔仍 serial（共用 crate）、`[P]` 主要標 base-web↔rust 跨棧平行。
- `[US1/US2/US3]`＝對應 spec user story；Setup/Foundational/Polish 無 story label。
- 對外碼：archive-move/restore Applied / restore NoOp → `0000`；restore NotFound / 撤含 protected Rejected → `2222`；非 R_SUPER → `5003`。

---

## Phase 1: Setup

- [ ] T001 驗證前置（psql 經 postgres 容器）：`sys_casbin_policy_archive` 表存在（13 欄）＋ 2 endpoint policy seed（`/systemManage/getArchivedPolicies` GET、`/systemManage/restorePolicy` POST）＋ menu policy（`manage_policy-archive`）皆在 `casbin_rule`/`sys_role_policy`；dev stack `up --wait`；確認在 `015-policy-governance` branch。**無新 migration/crate**（C-V-0 前置）

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ 阻擋所有 user story；完成後才進 Phase 3+。**

- [ ] T002 archive facade 骨架：建 `rust-api/server/src/model/facade/sys_casbin_policy_archive.rs`（註冊進 `model/facade/mod.rs`；定義 `enum RestoreOutcome{Applied,NoOp,NotFound}`；`insert_archived`/`list`/`restore` 簽名 stub）—— entity-access 邊界須在 `model/facade/`（`entity_access_lint` 豁免）（D1/D2；阻 US1）
- [ ] T003 `reload_and_publish(&state)` helper + `CASBIN_INVALIDATE_CHANNEL="casbin:policy:invalidate"` const：`enforcer.write().await.load_policy()` + redis `publish`（best-effort、**fail-OPEN**）in `rust-api/server/src/handler/system_manage.rs`（或 `auth/enforce.rs`）+ `main.rs` const（D3/D4；US1 reload／US2 publish／US3 gate 共用）

## Phase 3: User Story 1 — 授權規則回收桶：撤銷可復原、受保護防誤撤 (P1) 🎯 MVP

**Goal**：撤銷某角色非受保護授權 → 移入回收桶（可復原）；回收桶頁 list + restore；撤含受保護核心 → 整批拒零變更。
**Independent Test**：撤銷非保護→psql 證 archive 列+casbin_rule live 無；回收桶頁 restore→回 live+archive 無；撤含 protected→整批拒、零變更。**（不需多副本）**

- [ ] T004 [US1] revoke→archive-move：改 `set_role_dimension` revoke（`rust-api/server/src/model/facade/sys_casbin_rule.rs:109-118`）HARD DELETE → 先 SELECT to-revoke 完整列（含 created_at/created_by）→ `insert_archived`（ptype/v0-v5 照搬、`created_at=Some(live.created_at)`、`created_by=live.created_by`、`archived_at=now`、`archived_by=Some(operator.id)`、`archive_reason="role_dimension_revoke"`〔≤32〕）→ DELETE casbin_rule（**同 txn 原子**）；protected-reject 維持 BEFORE 任何寫（D1；依 T002；§4.2 ①④、011 零回歸）
- [ ] T005 [US1] archive facade `restore(conn, archive_id, meta) -> Result<RestoreOutcome, DbErr>` in `sys_casbin_policy_archive.rs`：archive 查無→`NotFound`；live 7-col(ptype/v0-v5) 已存在→`NoOp`（DELETE archive、不 INSERT、不審計）；else→`Applied`（INSERT casbin_rule〔`created_at=archive.created_at.unwrap_or(now)`〕+ DELETE archive + 審計 `{role:v0,target:v1,dimension:v2}`、同 txn）（D2；依 T002；§4.2 ④、★ created_at coerce）
- [ ] T006 [US1] archive facade `list(conn, role_code?, dimension?, page, size) -> (Vec<Model>, total)` in `sys_casbin_policy_archive.rs`（鏡像 `sys_operation_log::list` 分頁；空字串 filter 守門 None）（D2；依 T002）
- [ ] T007 [US1] handler `getArchivedPolicies`（GET、`PageRes<ArchivedPolicy>` honest）+ `restorePolicy`（POST `{id}`、Applied/NoOp→`0000`、NotFound→`2222`；**Applied→`reload_and_publish`、NoOp/NotFound→跳**）in `rust-api/server/src/handler/system_manage.rs`（D2/D3；依 T003,T005,T006）
- [ ] T008 [US1] main.rs 註冊 2 route（`getArchivedPolicies` GET + `restorePolicy` POST、R_SUPER `require_policy`、m002 seed 已備）in `rust-api/server/src/main.rs` + **`AS_BUILT_ROUTES` 35→37** in `rust-api/server/tests/endpoint_coverage_lint.rs`（D2；依 T007）
- [ ] T009 [US1] **★ MODIFIES 既有 011 行為（cross-feature、非新增 code、review 須明捕）**：`updateRoleMenu` handler reload 觸發改：`if outcome.changed{load_policy}` → **`reload_and_publish` on Applied（Ok/非 Rejected、含空-diff）**（`rust-api/server/src/handler/system_manage.rs:1118-1127`）——§4.2 ③ 對齊、調整 011 reload-on-`changed`（**user 已確認 2026-06-22：§4.2-③ compliance fix；empty-diff updateRoleMenu 由 skip 改 reload+publish、non-empty-diff 與 role_menu_loop observable 行為保留**）（D3；依 T003,T004；§4.2 ③⑤）
- [ ] T010 [P] [US1] base-web typings：`ArchivedPolicy{id:number, roleCode, target, dimension, archivedTime, archivedBy:number|null, archiveReason, createdTime:string|null}` + `ArchivedPolicySearchParams`(RecordNullable) + `ArchivedPolicyList=Common.PaginatingQueryRecord<ArchivedPolicy>` in `base-web/src/typings/api/rev3-system-manage.d.ts`（**不動 frozen `system-manage.d.ts`**、rev3-inline）（D5；honest）
- [ ] T011 [P] [US1] base-web service：`fetchGetArchivedPolicies(params?)→request<ArchivedPolicyList>`（`pruneNullParams`）+ `fetchRestorePolicy(id:number)→request<null>`（POST `/systemManage/restorePolicy` `{id:String(id)}`）in `base-web/src/service/api/rev3-system-manage.ts`（D5；依 T010）
- [ ] T012 [US1] base-web 回收桶頁〔**MODAL-WIRING ★ (e)**、rev3-inline 檔頭標記〕：`base-web/src/views/manage/policy-archive/index.vue` + `modules/policy-archive-table.vue`（NDataTable col：role/target/dimension/archivedTime/archivedBy/reason；filter role/dimension；restore 鈕 NPopconfirm→`fetchRestorePolicy`→reload list；`hasAuth` gating；鏡像 012 audit-table + 010 menu restore）**＋ i18n 先 Schema 後 locale 同 commit**：`base-web/src/typings/app.d.ts`（`App.I18n.Schema` 加 `page.manage.policyArchive.*`）→ `base-web/src/locales/langs/{zh-cn,en-us}.ts`（`manage.policyArchive`）（D5；依 T011；base-web-i18n-schema gotcha）
- [ ] T013 [US1] live archive-move+restore+protected（in-crate `#[ignore]`、容器內 `--test-threads=1`、`DATABASE_URL`、trace_id `"015-archive-restore-smoke"`、snapshot-restore guard 自清）in `sys_casbin_policy_archive.rs`（或 `sys_casbin_rule.rs` test mod）：撤非保護→psql archive 列+casbin_rule live 無（原子）／restore→回 live+archive 無+審計`{role,target,dimension}`／restore 已 live→`0000` NoOp 無審計／restore 假 id→`2222`／**archive.created_at=NULL 之列 restore→casbin_rule.created_at coerce `now()`、無 NN violation〔★ 跨表型不對稱邊界 U1〕**／撤含 protected→整批 Rejected `2222` 零變更（C-V-2 + C-V-3 protected 部分；依 T004,T005）

**✅ Checkpoint US1**：MVP 可獨立交付驗（單副本 archive/restore/UI/protected）。

## Phase 4: User Story 2 — 多副本部署下授權變更跨副本一致收斂 (P2)

**Goal**：一副本授權變更 → 所有副本授權判斷收斂；通知通道斷線可恢復。
**Independent Test**：2 副本；A revoke→B enforce 依最新被拒；A restore→B 放行；KILL pubsub→重訂閱後仍收斂。

- [ ] T014 [US2] `spawn_policy_watcher(redis, enforcer)`（**獨立 task、鏡像 `spawn_settings_watcher`**）：`SUBSCRIBE casbin:policy:invalidate` → `enforcer.write().await.load_policy()`；斷線 30s backoff 重訂閱、**fail-OPEN**；boot `tokio::spawn` in `rust-api/server/src/main.rs`（D4；依 T003）
- [ ] T015 [US2] live 2-instance（`$DC --profile multi up -d rust-api-2 --wait`、:31082、shared pg/redis）：副本 A revoke 某授權→psql 證 archive→副本 B enforce 依最新被拒（`casbin:policy:invalidate` watcher 收斂）／A restore→B 放行／`redis-cli CLIENT KILL TYPE pubsub`→watcher 重訂閱後仍收斂；收尾 `--profile multi down`（C-V-5；依 T014,T009,T007）

**✅ Checkpoint US2**：跨副本收斂 + watcher 韌性驗。

## Phase 5: User Story 3 — 授權變更精準生效：只在真改變時重載與廣播 (P3)

**Goal**：只有 Applied（含空-diff）才 reload+publish；Rejected/restore NoOp/NotFound 不擾動。
**Independent Test**：被拒/NoOp/查無→不 reload 不廣播；真變更→reload+廣播。
> gate 實作已分佈於 US1（T007 restore NoOp/NotFound 跳、T009 updateRoleMenu Applied-reload 含空-diff）；本 phase = 精準性的**獨立驗證**（§4.2 ③ distinct testable property）。

- [ ] T016 [US3] live gate 精準驗（in-crate `#[ignore]`、`--test-threads=1`）：撤含 protected Rejected→**不** `load_policy`、**不** publish〔★ skip 案須斷言 **publish 計數=0**、非僅 reload 不觸發 U2〕／restore NoOp/NotFound→**不** reload **不** publish／**空-diff** set_role_dimension（送相同 desired）Applied→**仍** reload+publish（§4.2 ③「不優化」、011-adjust 證）／**menu-found-但-無-policy（§4.2 ③ 明列、C1）→仍 reload**／真變更 Applied→reload+publish（C-V-3 gate 部分；依 T009,T007）

**✅ Checkpoint US3**：gate 精準性驗（§4.2 ③）。

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T017 零回歸：`role_menu_loop` test teardown 加 archive 清理（`:290` 後 `DELETE sys_casbin_policy_archive WHERE ptype='p' AND v0=code AND v2='menu'`）in `rust-api/server/src/model/facade/sys_casbin_rule.rs`（D6；revoke 改 archive 後保 byte-identity 斷言不破）
- [ ] T018 [P] lints 綠：`entity_access_lint`（archive facade 在 model/facade/ 豁免、handler/main 零 path-root `entity::`）+ `endpoint_coverage_lint`（AS_BUILT 37、Assertion A 2 endpoint 已 seed）in 容器內（C-V-1；依 T008,T002）
- [ ] T019 live policy-gate + CDP 回收桶 UI：curl Super→200 / Admin·User→403/5003（C-V-4）；CDP `:31080` Super→`/manage/policy-archive` list+restore 真打+psql 證 move、Super-only（Admin/User 無側欄、直呼 5003）、§3.13 console error 消解（C-V-6；依 T012,T008）
- [ ] T020 零回歸 + prod build：`--ignored` 全套綠（teardown +archive 清後 byte-identity 不破）／非-ignored 全套綠／`git diff migration/` 空＋migration up→down→up 綠／base-web `pnpm typecheck`／**prod target image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`）（C-V-7；依全部）
- [ ] T021 final holistic review：§4.2 5 invariants ↔ C-V 對照齊（①DB-first→C-V-2／②protected→C-V-3／③gate→C-V-3,T016／④原子+審計→C-V-2／⑤reload+publish 跨副本→C-V-5）；spec SC-001~008 全覆蓋；US1~US3 acceptance 全綠

---

## Dependencies & 執行順序

```
Setup(T001) → Foundational(T002 archive facade, T003 reload_and_publish)
  → US1〔T004 revoke→archive, T005 restore, T006 list, T007 endpoints, T008 routes+AS_BUILT, T009 updateRoleMenu gate, T010∥T011∥T012 base-web, T013 live〕  ← MVP
  → US2〔T014 watcher, T015 2-instance live〕   （依 US1 的 revoke/restore）
  → US3〔T016 gate 精準驗〕                      （依 US1 T007/T009）
  → Polish〔T017 零回歸 teardown, T018 lints, T019 gate+CDP, T020 零回歸+prod build, T021 holistic〕
```
- **rust 全程 serial**（T002-T009,T013-T017 共用 crate、即使不同檔不平行 cargo）。
- **跨棧平行**：base-web（T010→T011→T012）可與 rust（T004-T009）平行推進（`[P]` 標 T010/T011）。
- **每 worktree commit 落地即 bump submodule pin**（§4.1 S9、逐單元邊界、不延末刀）。

## Parallel 機會
- US1 內：base-web 串（T010→T011→T012）∥ rust 串（T004→T005→T006→T007→T008→T009）；兩棧匯於 T013 live（需 rust endpoint + base-web 可選、live 主驗 rust）。
- T018 lints 與 T019 gate/CDP 可在 impl 完後平行（只讀/活體）。

## Implementation Strategy
- **MVP = US1**（Phase 1+2+3）：archive/restore/回收桶 UI/protected-reject 單副本完整可交付。其後 US2（跨副本）、US3（gate 精準）為增量。
- 階段 2 `executing-plans`：每執行單元一支 Workflow（implementer TDD→spec-compliance review→fix↔loop→code-quality review），主線單元邊界 checkpoint（git show --stat 自核 + 容器內自驗 + bump pin）→ 啟下一支；全完成 final holistic → `finishing-a-development-branch`（push/merge 需 user 同意）。
- **無單元測試之單元**（wiring/形狀類：T004 archive-move txn、T007/T008 endpoint wiring、T012 base-web view、T014 watcher、T017 teardown）由 acceptance（C-V）覆蓋、本檔已明示；可獨立純測者極少（restore 三態邏輯可考慮抽純 helper、否則 live 覆蓋）。
