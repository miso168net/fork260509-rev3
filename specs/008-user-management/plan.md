# Implementation Plan: User Management（使用者管理）

**Branch**: `008-user-management` | **Date**: 2026-06-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-user-management/spec.md`

## Summary

波 1 第一刀（User 直刀、刀位③=A）：把後台 user 管理閉環。後端在既有 rust-api `server` crate 新增一個 `handler/system_manage` 模組（6 endpoint：`getUserList` 分頁/filter、`getAllRoles` 下拉、`addUser`、`updateUser`、`deleteUser`、`batchDeleteUser`），以 **facade-only** 存取既有 schema、**handler 層做 application-RI**（⚠️o：撞名／role-code 解析／值域／種子保護），寫端經 005 `mutate_in_txn` 寫 **composite role-delta 審計**，6 route 逐條 `route_layer(enforce_mw)` 驗**既有 m002 casbin policy**。前端走 BASE-WEB-WRAPPER 新檔 `rev3-system-manage.ts` ＋ MODAL-WIRING 接 3 處 stub。**全程零 migration**（schema/seed/policy 全在波 0 m001–m004）。技術取向細節與實碼 grep 驗證見 [research.md](./research.md)。

## Technical Context

**Language/Version**: Rust（MSRV 1.86、`--locked`）後端；TypeScript + Vue 3 前端

**Primary Dependencies**: axum ／ sea-orm（facade）／ casbin enforce（in-tree）／ argon2（**皆既有、無新增依賴**）；前端 Naive UI + 既有 axios service 層

**Storage**: PostgreSQL（**既有 schema、零 migration**；m001 表 + m002–m004 seed）

**Testing**: cargo test（純單測零 DB/HTTP ＋ `#[ignore]` live smoke、真 PG、`--test-threads=1`）＋ CDP node scripts（`tests/000`、modal smoke）＋ curl/psql（C-V contract）

**Target Platform**: Linux server（docker compose dev/prod stack）

**Project Type**: web-service（rust-api 後端）＋ web 前端（base-web）

**Performance Goals**: list p95 < 300ms／write（含同 txn audit）p95 < 500ms／login p95 < 1s（**server-side 量測、排冷啟**，clarify Q4）；≤50 並發 admin、不設吞吐 SLA

**Constraints**: 零 migration／凍結 wire 契約（envelope・逐欄 id 型・13 碼矩陣 §I.3）／facade-only 存取（entity_access_lint）／RI 在 handler 層（⚠️o）／rust code 零拷貝 rev2（§I.5）／MODAL-WIRING 五用途邊界＋fork-delta `rev3-inline` 標記（§II#3／§III）

**Scale/Scope**: 內部後台 ≤50 並發 admin；6 endpoint；新 1 rust handler 模組 ＋ facade 增補 ＋ 1 base-web wrapper 檔 ＋ 3 stub 接線；**無新 workspace crate**（僅加模組到既有 `server` crate）

## Constitution Check

*GATE：Phase 0 前須過；Phase 1 後重檢。* 對照 constitution §IV 九題：

1. **§I.1 base-web 為權威？** ✅ 不違反 — 6 endpoint 全對齊 base-web `system-manage.ts`／`typings` 既有消費面（4 寫端目前是前端 stub，本刀補上對應 rust endpoint），無縮減設計範圍。
2. **動 base-web inline？MODAL-WIRING 哪用途？授權邊界內？fork-delta 紀律？** ✅ 邊界內 — 用途 **(a)**（`index.vue` delete/batchDelete handler ＋ drawer `// request` 接線）；wrapper 走 **BASE-WEB-WRAPPER**（`rev3-system-manage.ts` 新檔、不改既有 `system-manage.ts`）。修改型原行註解保留＋`rev3-inline` 標記、新檔檔頭標記（§III）。
3. **menu 顯示走 Casbin enforce？demo menu 依 ⚠️p？** ✅ 不涉 menu 顯示（本刀只 user CRUD）；`manage_user` 選單 m002 已 seed、不動。
4. **wire 對齊 §I.3 typings 權威序與不變式？** ✅ — envelope `{data,code,msg}`、code string、business error HTTP 200；id 逐欄 typings（`User.id`/`Role.id`=number，**含 getAllRoles 回 number 不跟 mock string**，⚠️r）；`2222` 業務拒、`5003` enforce；`PageRes` camelCase；mock 僅補充 fixture。（逐欄對照 research R2／data-model。）
5. **拷貝 rev2 code？屬 §I.5 例外？防回歸？** ✅ 不拷貝 — rust 全新寫（參照讀允許）；不帶回 ⚠️r id-string／⚠️e Internal→500/`Number()` 補丁。
6. **抵觸 §II 拍板 #1~#13？** ✅ 無 — #1 帳號 Super/Admin/User（用既有 seed）、#10 wire id（conform）、#3 MODAL-WIRING（用途 a、已授）。
7. **觸及 §III ★ 軌道？授權邊界內？** ✅ — MODAL-WIRING ★ 用途 (a)（見 #2）；BASE-WEB-WRAPPER／ADAPT（L3／L1 預設可動）。CDP cutover 的 `.env.test.local` 是 gitignored 驗收檔、不改 committed `.env`（BASE-WEB-ADAPT 紀律）。
8. **新建業務表（6 審計欄）？** ✅ **零 migration** — 不建任何表；既有 `sys_user`(archetype A)／`sys_role`(A)／`sys_user_role`(C join) 全在波 0、本刀只讀寫。
9. **觸及 §I.7 行為島？invariants 保持？** ✅ 不動 — 不碰 token rotation／policy governance／single-session；本刀只設 `status` 值（停用登入 gate 在 006/007、不重作）。

**Gate：PASS**（零 violation；Complexity Tracking 不需填）。

### Post-Design Re-check（Phase 1 後）

設計產出（research.md／data-model.md／contracts/）後重跑 §IV：**維持 PASS、零新 violation**。實碼 grep 確認設計可落地（Q1=B／Q2=A 實碼確認）。唯一須 implementer 處置的實碼缺口為 **Q3**（`From<DbErr>→5000`；dup user_name 須 handler `find_active_by_name` pre-check → `AppError::biz`→`2222`）—— 此**強化** §I.3「業務錯＝2222、5xxx 非業務」的對齊、**非違反**（設計已含此 RI、見 data-model §4）。另：本刀於 008 stand up `endpoint_coverage_lint`（⚠️x 守恆移交、非 violation）。Gate 結論不變：**PASS**。

## Project Structure

### Documentation (this feature)

```text
specs/008-user-management/
├── plan.md              # 本檔（/speckit-plan）
├── research.md          # Phase 0（實碼 grep findings）
├── data-model.md        # Phase 1（entity／DTO／wire 映射）
├── quickstart.md        # Phase 1（驗收 run 指南）
├── contracts/
│   └── verification-commands.md   # Phase 1（C-V：cargo／純測／live smoke／curl／psql／CDP／p95／lint）
├── checklists/requirements.md     # /speckit-specify 產出
└── tasks.md             # Phase 2（/speckit-tasks 產、本步不建）
```

### Source Code (repository root)

```text
rust-api/server/src/
├── handler/
│   ├── mod.rs                    # 改：註冊 system_manage 模組
│   └── system_manage.rs          # 新：6 handler fn（DTO 映射＋handler-RI＋orchestration）
├── model/
│   ├── dto（位置 research R4 定位）  # 新：UserListItem／UserSearchParams／UserUpsertReq／AllRoleItem（serde rename＋i16↔enum）
│   └── facade/
│       ├── sys_user.rs            # 改：search_active／create／update（mutate_in_txn）
│       ├── sys_role.rs            # 改：all_active／find_active_by_codes
│       └── sys_user_role.rs       # 改：replace_roles_in_txn／roles_for_users（batch）
├── main.rs                       # 改：6 route ＋ route_layer(enforce_mw)
└── <endpoint_coverage_lint>      # 新/改：正向 policy 覆蓋檢查（⚠️x 移交、位置 research R6 定位）

base-web/src/
├── service/api/rev3-system-manage.ts          # 新：4 寫端 wrapper（updateUser 併 id；BASE-WEB-WRAPPER L3）
├── views/manage/user/index.vue                # 改：接 handleDelete／handleBatchDelete stub（MODAL-WIRING a）
├── views/manage/user/modules/user-operate-drawer.vue  # 改：接 handleSubmit stub（MODAL-WIRING a）
└── typings/api/*（research R2／R3 確認）         # 改?：UserUpsertReq wire 型（drawer Model 無 id、wrapper 帶 id）
```

**Structure Decision**: web-service（rust-api）＋ web 前端（base-web），沿既有 rev3 worktree+submodule 結構；後端**純加模組到既有 `server` crate**（無新 workspace crate）、前端走 wrapper 新檔＋inline stub 接線。實際命名／放置以 research R4（rust 結構）、R2／R3（wire）的 grep 為準（implementer act-on-code）。

## Complexity Tracking

> Constitution Check 零 violation、無需填此表。
