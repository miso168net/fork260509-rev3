# Phase 0 Research: 011-role-management

> 接地源＝當前 lineage（rust-api `c377444`／base-web `a59c2738`、皆 010 收刀後）親 grep＋psql ground-truth＋2 平行 research agent（casbin write-path／facade·wire·seed）＋主線親驗。**NEEDS CLARIFICATION = 0**（brainstorm＋specify＋clarify 已拍；plan-phase act-on-code 確認/釘死見下）。
> 本刀借 rev2 016/018/021 設計、code 全新寫（§I.5／⚠️g）。grounding 確認 brainstorm 假設大致成立、釘死/校正 4 處（R1 casbin API・R2 非原子・R4 wire 非對稱・R5 net-new helper）。

## R1 — casbin policy WRITE API（全專案首次、釘死）
**Decision**：新增 `auth::set_role_menu_policies(enforcer: &mut Enforcer, role_code: &str, route_names: &[String]) -> Result<(), AppError>`：`remove_filtered_policy("", "p", 0, vec![role_code.into(), "".into(), "menu".into()])`（移除該 role 全部 v2='menu'、v1 空字串＝wildcard）→ `add_policies("", "p", new_rules)`（new_rules＝`[[role_code, route_name, "menu"]...]`）。經 `state.enforcer.write().await` 取 &mut。
**Rationale（親驗 Cargo.lock + vendored adapter src/action.rs + casbin 2.20.0 MgmtApi）**：casbin **2.20.0**；MgmtApi（Enforcer 實作）`add_policy`/`add_policies`/`remove_policy`/`remove_filtered_policy` 皆 `async fn(&mut self, sec, ptype, ...) -> Result<bool, casbin::Error>`。`remove_filtered_policy(&mut self, sec:&str, ptype:&str, field_index:usize, field_values:Vec<String>)`：field_index=0 起、空字串＝該欄 wildcard。vendored sea-orm-adapter `action.rs` 直接 `model.insert(conn)`/`Entity::delete_many().filter().exec(conn)` → **auto-persist**（casbin_rule 表即時更新＋in-memory model 更新、**無需 `save_policy`**）；下次 `get_filtered_policy`/`enforce` 即見新值。`SeaOrmAdapter` entity 僅 8 基底欄（id/ptype/v0-v5）→ 新 row 治理欄（protected/created_at/created_by）DB default（protected=false/created_by=NULL；波3 治理補）。
**Alternatives**：直接 entity::casbin_rule 寫 + reload enforcer（否決——繞 adapter、enforcer/DB drift、提前波3、最複雜、D2-C 已否）；逐 add_policy（可、但 add_policies 批次較省、用之）。

## R2 — casbin 寫與 op-log 非原子（確認、FR-008 best-effort）
**Decision**：updateRoleMenu 的 casbin policy 寫**無法與 op-log `mutate_in_txn` 同交易**；op-log 為 **best-effort**（policy 寫成功後記一筆 sys_role UPDATE op-log；不保證原子）。
**Rationale（親驗 adapter.rs:10/16 + state.rs:28）**：`SeaOrmAdapter::new(db)` 持**自有** `DatabaseConnection`（boot 注入、≠ `AppState.db`）；casbin 寫經此連線、與 handler 的 `mutate_in_txn`（用 AppState.db 開 txn）**不同連線/不同 txn**。故 policy 寫 commit 獨立於 op-log。D2 拍板接受此 best-effort（super-only、低頻、完整交易治理屬波3 policy-governance 行為島）。一般角色資料/home 寫＝entity 寫、走 mutate_in_txn、**原子 op-log 正常**。
**Alternatives**：把 op-log 也經 adapter 連線（否決——op-log 用 mutate_in_txn 既有機制、不為此 fork）；entity 直寫 casbin_rule 進 mutate_in_txn（否決——R1 Alternatives 同因）。

## R3 — sys_role facade 鏡像 sys_user 009（釘死簽名）
**Decision**：`sys_role.rs` 既有 `find_active`／`home_of_roles` 不動；補（鏡像 sys_user）：`list`（§5.8 filter roleName/roleCode/status＋PageRes）／`find_active_by_id`／`create`（mutate_in_txn＋INSERT op-log）／`update`（含 home 欄、no-op Ok(None)、UPDATE op-log）／`soft_delete`（delete guards 前置、SOFT_DELETE op-log、成對 deleted_at/by）／`batch_soft_delete`（整批拒）／`build_create_active_model`/`build_update_active_model`（純測 seam）。
**Rationale（親驗 sys_user.rs + handler/system_manage.rs:215 map_write_err）**：sys_user 已示範完整 §5.8 list（PageRes）＋create/update（mutate_in_txn）＋soft_delete＋batch＋build_*_active_model＋`map_write_err`（`e.sql_err()→SqlErr::UniqueConstraintViolation→Biz`）。role 同形：roleCode 23505→`biz.role.duplicateRoleCode`。`find_active` 僅濾 deleted_at（SoftDeletable、status 不濾、R7）。
**Alternatives**：無（既定 pattern 沿用）。

## R4 — wire 3 端 roleId/menuIds（釘死、⚠️r、非對稱確認）
**Decision**：`Role.id`＝number（CommonRecord、⚠️r）；`getRoleMenu`→`number[]`（menu ids）；`updateRoleMenu` body `{roleId:number, menuIds:number[]}`；`getRoleHome`→string／`updateRoleHome` `{roleId:number, home:string}`。**roleId/menuIds 維持 number、不轉 String**（與 009/010 單 body `id`→`String(id)` 慣例**非對稱**、刻意）。
**Rationale（親驗 menu-auth-modal.vue:12/70 + system-manage.d.ts:132 + rev3-system-manage.ts:90/116）**：menu-auth-modal `checks: shallowRef<number[]>`、`roleId: number`（prop）；`MenuTree{id:number,label,pId:number,children}`。rev3 wrapper 慣例＝單 body `id`→`String(id)`（fetchUpdateUser/Menu）、array `ids`→`ids.map(String)`（fetchBatchDelete*）。但 **roleId 是 getRoleMenu/updateRoleMenu 的獨立參數（非 body `id` 欄）→ 不套 String 慣例、維持 number**；menuIds 維持 number[]（handler 內 id↔route_name 映射、R5）。rust DTO `RoleMenuReq{role_id:i64, menu_ids:Vec<i64>}`（serde 收 number）；`RoleUpsertReq.id:Option<String>`（updateRole body id 沿 009 慣例 String、wrapper `String(model.id)`）。
**Alternatives**：roleId 也轉 String（否決——非 body id、徒增不一致；rust 收 number 較直）。

## R5 — 2 net-new facade helper（in-use guard ＋ id↔code/route_name 映射）
**Decision**：(a) `sys_user_role::count_users_by_role_id(conn, role_id)->Result<i64,DbErr>`（in-use guard、現無、新增）。(b) self-role guard：deleteRole 收 role id → `find_active_by_id(id).code` 比對 `roles_of_user(claims.uid)`（回 codes）。(c) getRoleMenu/updateRoleMenu id↔route_name：經 sys_menu（route_name↔id）映射；建議 sys_menu facade 加 `route_names_for_ids`/`ids_for_route_names`（或 handler 自 `list_active` 結果建 map、Model 欄存取非 entity:: path-root）。
**Rationale（親驗 sys_user_role.rs roles_of_user/roles_for_users）**：現有 `roles_of_user(uid)->Vec<String>`（codes）、`roles_for_users`、無 count-by-role；in-use guard 需 count → 新增 helper（小查詢、`Entity::find().filter(RoleId.eq).count()`）。self-role：roles_of_user 回 code、deleteRole 收 id → 需 id→code 映射（find_active_by_id）。getRoleMenu：role code→`menu_routes_for_roles([code])`（010 既有讀）→route_names→sys_menu id 映射。
**Alternatives**：roles_ids_of_user 新 helper 取 operator role ids 直接比 id（可選、plan/impl 定；本研究採 id→code 比對、復用既有 roles_of_user）。

## R6 — m002 9 role 端點 policy verbatim（確認、lint bump）
**Decision／親驗（m002_rev2_seeds.rs:108-131）**：9 端點 path/method 逐字＋授權：
- `getRoleList` GET — **R_SUPER + R_ADMIN**、protected=false
- `addRole`/`updateRole` POST、`deleteRole`/`batchDeleteRole` DELETE — R_SUPER、protected=false
- `getRoleMenu` GET、`updateRoleMenu` POST — R_SUPER、**protected=true**
- `getRoleHome` GET、`updateRoleHome` POST — R_SUPER、protected=false
`endpoint_coverage_lint` AS_BUILT `[&str;22]`→`[&str;31]`（+9）；9 皆 policy-routes（require_policy）→Assertion A m002 已 seed 自動過。
**Rationale**：require_policy(path,method) 須與 seed 逐字對齊；getRoleList 忠實 seed R_SUPER+R_ADMIN（註：R_ADMIN 無 manage_role menu→實務到不了 role 頁、getRoleList R_ADMIN access moot；忠實不收窄）。
**Alternatives**：無（seed 事實）。

## R7 — 2 deferred 項確認（status 語意／無 role restore）
**Decision／親驗**：(a) `sys_role` SoftDeletable 僅 `deleted_at_column`（find_active 濾 deleted_at、**不濾 status**）→ **status＝metadata（display enabled/disabled）、非存取閘**；本刀 status 可編輯、不作授權過濾（若日後「停用角色＝撤存取」屬加固、非本刀）。(b) grep rust-api（handler/facade）＋base-web（role module）**無 role restore**（無 restoreRole 端點/UI；menu 有 restoreMenu、role 無）→ 角色頁無回收桶、軟刪單向（可刪角色必無人用、殘留 policy 無害、波3 治理清）。
**Rationale**：CHECKLIST §3.12「getAllRoles/replace_roles 啟用角色語意（Role 刀 confirm）」已預示 status 語意；本刀 confirm＝metadata。role 無 restore＝base-web 無此 UI（§I.1 權威）、scope 預設。
**Alternatives**：status 作存取閘（否決——本刀 by-design metadata、加固另案）／加 role restore（否決——base-web 無 UI、scope OUT）。
