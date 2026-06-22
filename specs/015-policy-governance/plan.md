# Implementation Plan: Policy 治理島（授權規則回收桶）

**Branch**: `015-policy-governance` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/015-policy-governance/spec.md`

## Summary

把 011 鋪的 casbin policy 寫側（`set_role_dimension` DB-first + protected-reject + reload-on-`changed`、**revoke 是 HARD DELETE**、reload **local-only**）補成 **DESIGN §4.2 完整治理島**：revoke 改 **archive-move**（snapshot INSERT `sys_casbin_policy_archive` + DELETE `casbin_rule` 同 txn）＋ **restore**（archive→live、已 live→NoOp、假 id→NotFound）＋ **PolicyMutated gate**（reload+publish on Applied〔含空-diff、§4.2 align、調整 011 的 reload-on-`changed`〕）＋ **跨實例 `casbin:policy:invalidate` pub-sub**（新 `spawn_policy_watcher`、復用 014 `spawn_settings_watcher` 範式）＋ **policy-archive 回收桶 UI**（`views/manage/policy-archive`、MODAL-WIRING (e)）。

**★ 接地確認零 migration**：`sys_casbin_policy_archive`（`m001:665`、13 欄）＋ 2 endpoint policy seed（`/systemManage/getArchivedPolicies` GET、`/systemManage/restorePolicy` POST，`m002:166-167`）＋ menu policy（`m002:168`/`:253`、`manage_policy-archive`）＋ sys_role_policy seed（`m002:356-358`）**全在波0已備**（rev2 034/035 終態 squash）；本刀只【**註冊 endpoint + 實作 facade/handler/watcher/UI + bump `AS_BUILT_ROUTES` 35→37**】，**無新 migration、無新 crate**。決策/接地詳見 [research.md](./research.md)。

## Technical Context

**Language/Version**: Rust（rust-api、workspace MSRV 1.86）＋ TypeScript/Vue 3（base-web）

**Primary Dependencies**: axum / sea-orm / casbin / `redis`（**全既有**，Redis 基建 014 已建）；base-web naive-ui（既有）—— **無新 crate / 無新 dep**

**Storage**: PostgreSQL（`casbin_rule` ⇄ `sys_casbin_policy_archive` 狀態機 / `sys_operation_log` 審計——**全既有、零 migration**）＋ Redis（既有：**新增 pub-sub channel `casbin:policy:invalidate`、無 key/表**）

**Testing**: `cargo test`（in-crate `#[ignore]` live、容器內、`--test-threads=1`）/ `entity_access_lint` + `endpoint_coverage_lint`（`AS_BUILT_ROUTES` 35→37、Assertion A 已 seed）/ CDP（:31080、回收桶頁）/ curl / psql / **2-instance（rust-api-2 :31082、`profiles:[multi]`）跨副本收斂**

**Target Platform**: Linux 容器（docker compose dev/prod；dev 第二 instance `profiles:[multi]` opt-in）

**Project Type**: web（rust-api backend + base-web frontend；**無新 crate**）

**Performance Goals**: reload = 全量 `load_policy()`（RwLock write、§4.2 ⑤）；PolicyMutated gate 避免無謂 reload/廣播（Rejected/NoOp/NotFound 跳）；受全域 ⚠️a perf 預算；無本刀特定延遲目標

**Constraints**：容器內 build/test（host 無 toolchain）；rust 全程 serial；base-web `--no-verify`；Redis/DB 抖動 **fail-OPEN**（§I.7、watcher 重訂閱）；★ **絕不 push/merge until finishing**

**Scale/Scope**：新 archive facade + 改 `set_role_dimension` revoke（HARD DELETE→archive-move）+ restore/list facade + 2 endpoint + PolicyMutated gate + 新 `spawn_policy_watcher` + base-web 新管理頁；**零 migration、零新 crate**（較 014 更小 scope）；**6 實作單元**（research §D、Project Structure）

## Constitution Check

*GATE：Phase 0 前必過、Phase 1 後 re-check。* 對照 constitution **v1.1.2 §IV 9 項**：

| # | 檢查項 | 判定 | 說明 |
|---|---|---|---|
| 1 | §I.1 base-web 為權威（rust 補 endpoint） | ✅ PASS | 補 `getArchivedPolicies`/`restorePolicy`（base-web policy-archive 頁需；波0 seed 已備、但 endpoint 未註冊/實作）；`manage_policy-archive` menu 已 seed、建 view 即對齊 |
| 2 | 動 base-web inline？屬 MODAL-WIRING ★ 哪用途 (a)~(e)？ | ✅ PASS | **(e) 同 manage 範式新管理頁** `views/manage/policy-archive`（嚴格鏡像 010 menu / 012 audit）＋ `page.manage.policyArchive.*` i18n（先 Schema 後 locale）＋ `route.manage_policy-archive`（種子已備）。另：rev3-WRAPPER（`service/api/rev3-system-manage.ts` 新 fn）＋ rev3-ADAPT typing（`rev3-system-manage.d.ts` 新型、不動 frozen `system-manage.d.ts`）。循 §III fork-delta `rev3-inline` 紀律 |
| 3 | menu 顯示走 Casbin enforce？ | ✅ PASS | `manage_policy-archive` menu policy `m002:168` 已 seed（R_SUPER）；建 view 消解 §3.13 console error；**不新增 menu**、可見性走 §I.2 |
| 4 | wire 對齊 §I.3 typings 權威序與不變式？ | ✅ PASS | `getArchivedPolicies` 回 `PageRes<ArchivedPolicy>`（honest、id `number`、欄逐欄對齊 archive entity）；`restorePolicy` 回 `0000`/`2222`（**凍結 13 碼矩陣、無新碼**）；rev3-owned typing |
| 5 | 從 rev2 拷貝 code？防回歸？ | ✅ PASS | rust in-tree 重寫（archive facade/restore/gate/watcher 設計繼承 rev2 034/035、**code 不拷**）；復用 011 `set_role_dimension`＋014 Redis/watcher（in-tree、§I.5）；不帶回已推翻行為（rev2-034 MgmtApi anti-pattern 明確不用） |
| 6 | 抵觸 §II 拍板 #1~#13？ | ✅ PASS | 不觸 13 凍結拍板；**A 拍板（un-protect 不做）保 §4.2 ② protected-reject 不被繞**（見 item 9） |
| 7 | 觸及 §III ★ 軌道？授權內？ | ✅ PASS | **MODAL-WIRING (e)**（新管理頁）在授權邊界內；每處記 file:line + upstream 衝突風險（research §D5） |
| 8 | 新建業務表（migration）？§I.6 六欄？ | ✅ PASS（**核心**） | **零新表、零 migration**——`sys_casbin_policy_archive`（`m001:665`、13 欄、archetype D 變體：原 grant created_at/by + archived_at/by + archive_reason、無 update/delete 欄）＋ 2 endpoint policy seed（`m002:166-167`）＋ menu/role policy（`m002:168/253/356-358`）**全波0已備**；本刀只註冊 endpoint + 實作 + bump `AS_BUILT_ROUTES` 35→37（測試常數、**非 migration**） |
| 9 | 觸及 §I.7 行為島？invariants 保持？state-machine 鏡頭？ | ✅ PASS（**核心**） | 實作 §4.2 policy governance；逐 invariant 對齊〔① **DB-first**（不碰 enforcer MgmtApi `remove_filtered`/`add_policies`）／② **protected-reject**〔011 已有、零回歸〕／③ **PolicyMutated gate**（reload+publish on Applied〔含空-diff、§4.2「不優化」、本刀**調整 011 的 reload-on-`changed`**對齊〕；Rejected/restore NoOp/NotFound 跳）／④ revoke/restore 與審計**同 txn 原子**、restore 審計記 `{role,target,dimension}`／⑤ reload = 全量 `load_policy()` + `PUBLISH casbin:policy:invalidate`〕；用 §4.2 **state-machine 鏡頭**；**每 invariant 須自動化驗證**（§8.8 DoD、C-V）。**A 拍板（un-protect 不做）＝§4.2-faithful**（做 un-protect 會使 ② 可繞、須 §V.2 amend；不做＝保 invariants 凍結） |

**Gate 結論：通過 9/9**（零違反；**零 migration、零新 crate、無 Complexity 違反需登記**——較 014 顯著更小 scope）。

## Project Structure

### Documentation (this feature)
```text
specs/015-policy-governance/
├── plan.md / research.md / data-model.md / quickstart.md
├── contracts/verification-commands.md   # C-V-0~7
├── checklists/requirements.md（specify 產）
└── tasks.md（/speckit-tasks 產）
```

### Source Code — 6 實作單元（research §D）
```text
rust-api/
├── server/src/model/facade/sys_casbin_policy_archive.rs（新）  # D1/D2 archive facade：insert_archived / list（分頁、by role/dim）/ restore（move-back、NoOp/NotFound）
├── server/src/model/facade/sys_casbin_rule.rs                 # D1 set_role_dimension revoke: HARD DELETE → archive-move（同 txn snapshot+archive+delete）
├── server/src/handler/system_manage.rs                       # D2 getArchivedPolicies / restorePolicy handler；D3 updateRoleMenu+restorePolicy reload 改 PolicyMutated gate（Applied→reload+publish）
├── server/src/auth/enforce.rs / state.rs                     # D4 enforcer reload 點（reload_and_publish helper）
├── server/src/redis.rs                                       # D4 publish casbin:policy:invalidate（既有 RedisHandle）
├── server/src/main.rs                                        # D2 2 route（getArchivedPolicies GET / restorePolicy POST、require_policy、m002 seed）；D4 CASBIN_INVALIDATE_CHANNEL + spawn_policy_watcher（boot）
├── server/tests/endpoint_coverage_lint.rs                    # D2 AS_BUILT_ROUTES 35→37
└── server/src/model/facade/sys_casbin_rule.rs（test mod）     # D6 role_menu_loop teardown +archive cleanup（零回歸）
base-web/src/
├── typings/api/rev3-system-manage.d.ts                       # D5 ArchivedPolicy + ArchivedPolicySearchParams + ArchivedPolicyList（rev3-owned、不動 frozen）
├── service/api/rev3-system-manage.ts                         # D5 fetchGetArchivedPolicies（pruneNullParams）/ fetchRestorePolicy（String(id)）
├── views/manage/policy-archive/index.vue（新）                # D5 回收桶頁（鏡像 012 audit / 010 menu restore）
├── views/manage/policy-archive/modules/policy-archive-table.vue（新）  # D5 NDataTable + filter + restore（NPopconfirm→fetchRestorePolicy）
├── typings/app.d.ts + locales/langs/{zh-cn,en-us}.ts         # D5 page.manage.policyArchive.* i18n（先 Schema 後 locale）
```

**Structure Decision**：既有 web 結構、**零新 crate**。本刀＝對 011 casbin 寫側的 §4.2 行為島補完（archive/restore/gate/cross-instance）+ base-web 首個「回收桶」獨立頁（MODAL-WIRING (e)）。單元相依見 research §D，由 /speckit-tasks → 階段 2 `executing-plans` 編執行單元。

## Complexity Tracking

> **9/9 PASS 無 Constitution 違反**；本刀**無新增複雜度需登記**（零 migration、零新 crate、零新 dep；archive 表/endpoint seed/menu 全波0已備）。下表登記**唯一行為調整**供 user 知情（非違反、屬 §4.2-align）：

| 項 | 為何需要 | 為何不採更簡單替代 |
|---|---|---|
| **調整 011 的 reload-on-`changed` → reload-on-Applied（含空-diff）** | §I.7 §4.2 ③ 凍結「空-diff Applied 仍 reload（刻意、不優化）」；011 現以 `changed=!to_revoke.is_empty()\|\|!to_grant.is_empty()` gate、**空-diff 會 skip**（與 §4.2 不符） | 維持 011 的空-diff-skip＝違 §4.2 ③ 凍結不變式（須 §V.2 amend）；改為 Applied-reload＝§4.2-faithful、且 `load_policy()` 冪等（多一次無謂 reload 無害）。role_menu_loop 測做真變更（changed=true）、不受影響 |

> 本刀對 011/008/014 的觸碰：**011** `set_role_dimension`（revoke→archive）＋ `updateRoleMenu` handler（gate）＋ role_menu_loop 測（teardown 清 archive）；**014** 復用 Redis/watcher 範式（新增 channel + watcher、不改既有 settings watcher）。皆授權軌道內、不破既有行為（零回歸由 C-V 證）。
