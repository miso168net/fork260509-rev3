# Implementation Plan: Role Management（角色管理）

**Branch**: `009-role-management` | **Date**: 2026-06-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-role-management/spec.md`

## Summary

波 2 第一刀（Role 直刀、user 拍序 Role 先）：把後台 role 管理閉環（**純 sys_role CRUD**）。後端在既有 rust-api `server` crate 的 `handler/system_manage.rs` **續寫** 5 endpoint（`getRoleList` 分頁/**模糊** filter、`addRole`、`updateRole`、`deleteRole`、`batchDeleteRole`），以 **facade-only** 存取既有 `sys_role`（archetype A）、**handler 層做 application-RI**（⚠️o：撞碼／值域／soft-deleted 拒更／roleCode 不可變／種子保護），寫端經 005 `mutate_in_txn` 寫 **leaf 審計**（無 composite roles、無 password redact），5 route 逐條 `route_layer(enforce_mw)` 驗**既有 m002 casbin policy**（getRoleList=R_SUPER+R_ADMIN、寫端=R_SUPER）。前端走 BASE-WEB-WRAPPER 新檔 `rev3-system-manage.ts`（+4 wrapper）＋ MODAL-WIRING **(a)** 接 2 處 stub（index.vue delete/batchDelete、drawer handleSubmit add/update）＋ roleCode edit 禁改（FR-006）。**全程零 migration、零新 crate**（schema/seed/policy 全在波 0 m001–m002）。**授權指派（menu/button/endpoint 三維）明確 OUT**（需 net-new sys_menu）。技術取向與實碼 grep 驗證見 [research.md](./research.md)；wire DTO／facade 簽名／RI 見 [data-model.md](./data-model.md)。

## Technical Context

**Language/Version**: Rust（MSRV 1.86、`--locked`）後端；TypeScript + Vue 3 前端

**Primary Dependencies**: axum ／ sea-orm（facade）／ casbin enforce（in-tree）／ serde（**皆既有、無新增依賴**；Role 無 argon2、無敏感欄）；前端 Naive UI + 既有 axios service 層

**Storage**: PostgreSQL（**既有 schema、零 migration**；`sys_role`〔A〕表 + casbin policy 全在 m001/m002）

**Testing**: cargo test（純單測零 DB/HTTP ＋ `#[ignore]` live smoke、真 PG、`--test-threads=1`、`#[cfg(test)] mod` 於 `src/`〔server bin-only crate〕）＋ CDP node scripts（`tests/000`、modal smoke）＋ curl/psql（C-V contract）

**Target Platform**: Linux server（docker compose dev/prod stack）

**Project Type**: web-service（rust-api 後端）＋ web 前端（base-web）

**Performance Goals**: list p95 < 300ms／write（含同 txn audit）p95 < 500ms（**server-side 量測、排冷啟**，⚠️a 保守 SLA）；≤50 並發 admin、不設吞吐 SLA。role 表小、leaf 無 join → 預期遠優於上限

**Constraints**: 零 migration／凍結 wire 契約（envelope・逐欄 id 型 §I.3・13 碼矩陣）／facade-only 存取（entity_access_lint）／RI 在 handler 層（⚠️o）／rust code 零拷貝 rev2（§I.5）／MODAL-WIRING 五用途邊界＋fork-delta `rev3-inline` 標記（§II#3／§III）／**roleCode 不可變**（= casbin subject v0）／**leaf 審計**（無 composite、無 redact）／dup roleCode→2222（pre-check＋23505 race catch、**永不 5000**、clarify A）／**停用 role 不撤權、僅刪除撤權**（R6 既有 active-filter 行為、本刀不改）

**Scale/Scope**: 內部後台 ≤50 並發 admin；5 endpoint；**續寫** `system_manage.rs`（grow existing、非新檔）＋ `sys_role` facade 增補（6 fn＋2 struct＋AuditSerialize＋3 helper）＋ 1 base-web wrapper 檔 ＋ 2 stub 接線 ＋ roleCode disabled；**無新 workspace crate**（members 固定 5）

## Constitution Check

*GATE：Phase 0 前須過；Phase 1 後重檢。* 對照 constitution §IV 九題：

1. **§I.1 base-web 為權威？** ✅ 不違反 — 5 endpoint 全對齊 base-web `system-manage.ts`／`typings` 既有消費面（4 寫端目前是前端 stub、本刀補對應 rust endpoint；`fetchGetRoleList`/`fetchGetAllRoles` 既有讀端不動），無縮減設計範圍。授權指派（getRoleMenu/updateRoleMenu/…）OUT 屬**交付排程**（需 sys_menu）、非設計縮減。
2. **動 base-web inline？MODAL-WIRING 哪用途？授權邊界內？fork-delta 紀律？** ✅ 邊界內 — 用途 **(a)**（`index.vue` delete/batchDelete handler ＋ `role-operate-drawer.vue` handleSubmit create/update 接線）；wrapper 走 **BASE-WEB-WRAPPER**（`rev3-system-manage.ts` 新檔、不改既有 `system-manage.ts`/`auth.ts`/`route.ts`）。**一處 inline 超出純 request 接線＝drawer roleCode `:disabled="isEdit"`（FR-006 要求 edit 時 read-only）**——屬 (a) 同元件（operate-drawer）內最小屬性增補、upstream 衝突風險低、`rev3-inline` 標記。修改型原行註解保留（§III）。**(c) auth-modal 不啟用**（屬授權指派、OUT）。
3. **menu 顯示走 Casbin enforce？demo menu 依 ⚠️p？** ✅ 不涉 menu 顯示（本刀只 role CRUD）；`manage_role` 選單 m002 已 seed、不動；本刀**不碰 sys_menu/casbin menu 維度**。
4. **wire 對齊 §I.3 typings 權威序與不變式？** ✅ — envelope `{data,code,msg}`、code string、business error HTTP 200；id 逐欄 typings（`Role.id`=number、⚠️r、2^53 guard）；`status:EnableStatus|null`；`2222` 業務拒、`5003` enforce；`PageRes` camelCase；mock 僅補充 fixture。（逐欄對照 research R2／data-model §2。）
5. **拷貝 rev2 code？屬 §I.5 例外？防回歸？** ✅ 不拷貝 — rust 全新寫（參照讀允許）；不帶回 ⚠️r id-string／⚠️e Internal→500/`Number()` 補丁。
6. **抵觸 §II 拍板 #1~#13？** ✅ 無 — #1 帳號（用既有 seed）、#10 wire id（conform）、#3 MODAL-WIRING（用途 a、已授）；roleCode 不可變對齊「roleCode=casbin subject v0」（§I.2 機制）。
7. **觸及 §III ★ 軌道？授權邊界內？** ✅ — MODAL-WIRING ★ 用途 (a)（見 #2）；BASE-WEB-WRAPPER／ADAPT（L3／L1 預設可動）。CDP cutover 的 `.env.test.local` 是 gitignored 驗收檔、不改 committed `.env`（BASE-WEB-ADAPT 紀律）。
8. **新建業務表（6 審計欄）？** ✅ **零 migration** — 不建任何表；既有 `sys_role`（archetype A、6 審計欄＋partial-uniq `sys_role_code_active_uniq`）波 0 已建、本刀只讀寫。審計事件寫入既有 `sys_operation_log`（archetype B append-only）、**只寫事件、零 schema 變更**。
9. **觸及 §I.7 行為島？invariants 保持？** ✅ 不動 — 不碰 token rotation／policy governance／single-session；deleteRole 只 soft-delete `sys_role`、**不動 casbin/join**（grants 經既有 `roles_for_user`→`find_active_by_ids` active 濾自動 inert、R6）。

**Gate：PASS**（零 violation；Complexity Tracking 不需填）。

### Post-Design Re-check（Phase 1 後）

設計產出（research.md／data-model.md／contracts/）後重跑 §IV：**維持 PASS、零新 violation**。8-agent 實碼 grep 確認設計可落地（3 load-bearing claim 二次複驗）。須 implementer 處置的實碼缺口：

- **Q-DUP（強化非違反）**：既有 `From<DbErr>→5000`（`error.rs:73-77`）；dup roleCode 須 handler `find_active_by_code` pre-check→`biz(2222)`，**且** create 對 pg `23505`（`sys_role_code_active_uniq`）unique-violation targeted catch→`biz(2222)`，以兌現 **spec Clarification A**（race「永不系統失敗」）。設計含此 RI（data-model §4）；此**強化** §I.3「業務錯＝2222、5xxx 非業務」、**非違反**。
- **endpoint_coverage_lint bump（⚠️x 守恆延續、非違反）**：`EXPECTED_ROUTE_COUNT` 6→**11**（實際 gated route 數、非 DESIGN target 35）；5 條 role policy m002 已 seed（R5 複驗）→ 綠。
- **handler 放既有檔（grow `system_manage.rs`）**：act-on-code 推翻 brainstorm §5.9「傾向新檔」——008 共用 helper 為 private、同檔複用免改可見性、零 008 churn（research R4）。**非 constitution 議題**。
- **停用 role 不撤權（R6 既有行為）**：spec 對「停用角色是否授權」靜默；實碼 active-filter 僅濾 `deleted_at`（`soft_delete.rs:9-11`）→ 停用 role 仍授權、唯刪除撤權。對齊 spec Out-of-Scope/Assumptions、**本刀不改 enforce 基盤**。

Gate 結論不變：**PASS**。

## Project Structure

### Documentation (this feature)

```text
specs/009-role-management/
├── plan.md              # 本檔（/speckit-plan）
├── research.md          # Phase 0（8-agent 實碼 grep findings）
├── data-model.md        # Phase 1（entity／wire DTO／facade 簽名／handler-RI／leaf audit）
├── quickstart.md        # Phase 1（驗收 run 指南）
├── contracts/
│   └── verification-commands.md   # Phase 1（C-V-0..8：cargo／純測／live smoke／curl／psql／CDP／p95／lint）
├── checklists/requirements.md     # /speckit-specify 產出
└── tasks.md             # Phase 2（/speckit-tasks 產、本步不建）
```

### Source Code (repository root)

```text
rust-api/server/src/
├── handler/
│   └── system_manage.rs          # 改（grow）：+5 role handler（get_role_list／add_role／update_role／delete_role／batch_delete_role）
│                                  #   +RoleSearchParams／RoleListItem／RoleUpsertReq DTO（co-located、camelCase）
│                                  #   +ensure_role_code_available／is_seed_role helper；複用既有 private helper（wire_to_i16/blank_to_none/serialize_id_guarded/audit_operator/check_name_collision）
├── model/
│   └── facade/
│       └── sys_role.rs           # 改：+find_active_by_id／find_active_by_code／search_active／create／update／soft_delete
│                                  #   +NewRole／RoleFilter struct／impl AuditSerialize（無 redact）／create_query/update_set_query(code 不入)/soft_delete_query helper
├── main.rs                       # 改：+5 route ＋ 既有 route_layer(enforce_mw)（system_manage sub-router）
└── tests/endpoint_coverage_lint.rs  # 改：EXPECTED_ROUTE_COUNT 6→11 ＋ doc 註解更新

base-web/src/
├── service/api/rev3-system-manage.ts          # 改：+4 role wrapper（fetchAddRole/fetchUpdateRole〔併 id〕/fetchDeleteRole/fetchBatchDeleteRole；BASE-WEB-WRAPPER L3、rev3-inline）
├── views/manage/role/index.vue                # 改：接 handleDelete／handleBatchDelete stub（MODAL-WIRING a）
└── views/manage/role/modules/role-operate-drawer.vue  # 改：接 handleSubmit（add/update 分支、MODAL-WIRING a）＋ roleCode `:disabled="isEdit"`（FR-006）
```

**Structure Decision**: web-service（rust-api）＋ web 前端（base-web），沿既有 rev3 worktree+submodule 結構；後端**續寫既有 `system_manage.rs` + `sys_role.rs` facade**（無新檔、無新 workspace crate）、前端走 wrapper 新檔＋inline stub 接線。實際命名／放置以 research R1/R4（rust 結構）、R2/R3（wire）的 grep 為準（implementer act-on-code）。

## Complexity Tracking

> Constitution Check 零 violation、無需填此表。
