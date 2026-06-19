# Phase 0 Research: 011-role-management

> 接地源＝當前 lineage（rust-api `c377444`／base-web `a59c2738`、皆 010 收刀後）親 grep＋psql ground-truth＋3 平行 research agent（casbin write-path／facade·wire·seed／**DB-first 寫 seam**）＋主線親驗。**NEEDS CLARIFICATION = 0**。
> **★ B1 校正（/speckit-analyze 抓出、user 拍板 option 1）**：原 R1/R2 的「MgmtApi `remove_filtered_policy`+`add_policies` auto-persist、與 op-log 非原子」**違反 constitution §I.7 §4.2 ①DB-first／④原子審計／⑤reload 凍結不變式**（rev2-034 被推翻舊路徑）。R1/R2/R5 已改 **DB-first**（facade 直寫 `entity::casbin_rule` 於 `mutate_in_txn`、原子 op-log、②protected-reject、寫後 `load_policy()` reload、無 MgmtApi 寫）。R3/R4/R6/R7 不變。

## R1 — casbin policy WRITE＝DB-first（★ 全專案首次、constitution §I.7 §4.2 合規）
**Decision**：新增 facade `model/facade/sys_casbin_rule.rs`（net-new）`set_role_dimension<C: TransactionTrait>(conn, role_code:&str, dimension:&str /*"menu"*/, desired_objs:&[String], operator, trace) -> Result<SetDimensionOutcome, SetDimensionError>`，**DB-first**：於 `mutate_in_txn`（AppState.db 同一 txn）：① read current `entity::casbin_rule`（11-col、filter `ptype='p' ∧ v0=role_code ∧ v2=dimension`）；② diff(current vs desired)→to_revoke/to_grant；③ **②protected-reject**：to_revoke 任一 `protected=true`→`SetDimensionError::Rejected`（整批拒、零變更）；④ revoke＝`Entity::delete_many().filter(...to_revoke...).exec(&txn)`、grant＝逐 `ActiveModel{ptype,v0,v1=obj,v2=dim,created_at=now,created_by=Some(op.id),protected=false}.insert(&txn)`；⑤ op-log `AuditEvent{operation:Update, entity_table:"casbin_rule", entity_id:Some(role_id), before/after=route_name 集}`（同 txn、**原子**）。handler 在 txn commit **後** `state.enforcer.write().await.load_policy().await`（⑤ 全量 reload、本地）。**無 enforcer MgmtApi 寫**（不 `remove_filtered_policy`/`add_policies`）。
**Rationale（親驗 constitution §I.7 §4.2 lines 107-111 + DESIGN §4.2 line 245-248 + entity/src/casbin_rule.rs + audit.rs + soft_delete.rs lint 契約）**：constitution §I.7 §4.2 凍結 invariant ①「DB-first——寫側只動 DB（casbin_rule/archive）、不碰 in-memory enforcer」（明文舉 rev2-034 改掉的舊路徑＝MgmtApi auto_save 旁路寫 DB＋非原子稽核）④「revoke/restore 與審計同 txn 原子」⑤「reload＝全量 load_policy()」。DESIGN §4.2 line 245「`set_role_dimension(role,dim,desired[])=diff→批次 revoke+grant（單 txn）`」、line 111「（rev2 034）後寫側 DB-first 走 L4 facade、不經 adapter auto_save」。`entity::casbin_rule` 為 **11-col governance entity**（id/ptype/v0-v5/protected/created_at/created_by、DeriveEntityModel、ActiveModel insert + Entity::delete_many 可寫、facade 可讀 protected/設 created_by），**有別於 adapter 的 8-col entity**；facade 層 entity:: 走 entity_access_lint 豁免。
**Alternatives**：MgmtApi `remove_filtered_policy`+`add_policies` auto-persist（**否決＝B1**——觸 in-memory、走 adapter auto_save 旁路、審計另起 txn 非原子＝constitution §I.7 §4.2 ①④ 凍結 invariant 反轉〔§V.3 MAJOR〕、rev2-034 anti-pattern）。

## R2 — casbin 寫與 op-log **原子**（DB-first 之果、校正原「非原子 best-effort」）
**Decision**：updateRoleMenu 的 casbin_rule 寫與 op-log **同一 `mutate_in_txn`（AppState.db）原子**（同成同敗）；非「盡力而為」。reload（load_policy）在 commit 後本地執行（單實例；cross-instance `casbin:policy:invalidate` publish/watcher＝波3）。
**Rationale（親驗 audit.rs mutate_in_txn + state.rs）**：原「非原子」係 **MgmtApi 路徑**之果（adapter 持自有 DatabaseConnection ≠ AppState.db）。DB-first 改為 facade 直寫 `entity::casbin_rule` **於 AppState.db 的 txn**＝與 op-log 同連線同 txn → **原子**（constitution §I.7 §4.2 ④ 滿足）。FR-008/SC-007 隨之由 best-effort 改回原子。
**Alternatives**：保留 adapter 連線寫（否決——非原子、即 B1）。

## R3 — sys_role facade 鏡像 sys_user 009（釘死簽名、不變）
**Decision**：`sys_role.rs` 既有 `find_active`／`home_of_roles` 不動；補 `list`（§5.8 filter＋PageRes）／`find_active_by_id`／`create`／`update`（含 home）／`soft_delete`／`batch_soft_delete`／`build_*_active_model`（純測 seam）。`map_write_err`（sql_err→UniqueConstraintViolation→Biz）沿用、roleCode 23505→`biz.role.duplicateRoleCode`。
**Rationale**：sys_user 009 已示範完整 §5.8 list（PageRes）＋mutate_in_txn 寫＋soft_delete＋batch＋build_*_active_model＋map_write_err。`find_active` 僅濾 deleted_at（status 不濾、R7）。
**Alternatives**：無。

## R4 — wire 3 端 roleId/menuIds（釘死、⚠️r、非對稱、不變）
**Decision**：`Role.id`＝number；`getRoleMenu`→`number[]`（menu ids）；`updateRoleMenu` body `{roleId:number, menuIds:number[]}`；`getRoleHome`→string／`updateRoleHome` `{roleId:number, home:string}`。roleId/menuIds **維持 number、不轉 String**（與單 body `id`→`String(id)` 慣例非對稱、刻意）。
**Rationale（親驗 menu-auth-modal.vue:12/70 + system-manage.d.ts:132 + rev3-system-manage.ts wrapper 慣例）**：menu-auth-modal `checks:number[]`／`roleId:number`；MenuTree `{id:number,label,pId,children}`。roleId 為獨立參數非 body `id`→不套 String 慣例。rust DTO `RoleMenuReq{role_id:i64,menu_ids:Vec<i64>}`；`RoleUpsertReq.id:Option<String>`（updateRole body id 沿 009 String）。
**Alternatives**：roleId 轉 String（否決——非 body id、徒增不一致）。

## R5 — net-new facade（sys_casbin_rule DB-first ＋ count helper ＋ id↔route_name 映射）
**Decision**：(a) **`model/facade/sys_casbin_rule.rs`（net-new）**：`set_role_dimension`（DB-first、R1）＋slim `SetDimensionError{Db(DbErr),Rejected(Vec<String>/*protected objs*/)}`＋`SetDimensionOutcome{changed:bool}`（供 handler 決定是否 reload）；讀端 getRoleMenu 復用 010 `enforce::menu_routes_for_roles(&*enforcer.read().await,[code])`（in-memory 讀、非寫、合規）→route_names。(b) `sys_user_role::count_users_by_role_id(conn,role_id)->i64`（in-use guard、net-new）。(c) self-role guard：deleteRole 收 id→`find_active_by_id(id).code` 比對 `roles_of_user(claims.uid)`（codes）。(d) id↔route_name：sys_menu route_name↔id 映射（getRoleMenu route_name→id／updateRoleMenu id→route_name；建議 sys_menu facade `route_names_for_ids`/`ids_for_route_names` 或 handler 自 `list_active` 建 map）。
**Rationale（親驗 sys_user_role.rs roles_of_user / entity::casbin_rule 11-col / DESIGN §4.2 set_role_dimension）**：現無 casbin write facade（net-new）；set_role_dimension DB-first 寫端＋menu_routes_for_roles 讀端（讀 in-memory 合規）；count-by-role 現無→新增；id↔code/route_name 映射 handler/facade。
**Alternatives**：auth::set_role_menu_policies MgmtApi（否決＝B1、R1）。

## R6 — m002 9 role 端點 policy verbatim（確認、lint bump、不變）
**Decision／親驗（m002_rev2_seeds.rs:108-131）**：getRoleList GET R_SUPER+R_ADMIN（f）／addRole·updateRole POST·deleteRole·batchDeleteRole DELETE R_SUPER（f）／getRoleMenu GET·updateRoleMenu POST R_SUPER（**protected=true**）／getRoleHome GET·updateRoleHome POST R_SUPER（f）。`endpoint_coverage_lint` AS_BUILT `[&str;22]→[&str;31]`（+9）；9 皆 policy-routes→Assertion A m002 已 seed 自動過。
**Rationale**：require_policy 須與 seed 逐字對齊；getRoleList 忠實 seed R_SUPER+R_ADMIN（R_ADMIN 無 manage_role menu→access moot）。
**Alternatives**：無。

## R7 — deferred 項確認（status metadata／無 role restore／②protected IN 波2／治理機 波3）
**Decision／親驗**：(a) `sys_role` `find_active` 僅濾 deleted_at（**status＝metadata、非存取閘**）。(b) **無 role restore**（角色頁無回收桶、軟刪單向）。(c) **②protected-reject 在 波2**（DB-first 可讀 protected、frozen invariant、防 super 誤刪自身 admin 選單可見性）；revoke 在 波2＝**hard DELETE**（archive-move 波3）。(d) **波3 才做**：archive（revoke→archive 表）／restore（←archive）／protected 策略**管理**（un-protect/re-protect）／PolicyMutated-gate 優化（③）／跨實例 publish-watcher／回收桶 UI（DESIGN §4.2／§8.2 治理刀）。`sys_casbin_policy_archive` 表已建（m001）但本刀不消費（無 FK 強制、revoke=DELETE）。
**Rationale**：CHECKLIST §3.12 status confirm；base-web 無 role restore UI（§I.1）；②protected 為 §4.2 frozen invariant、DB-first 自然可 enforce（讀 protected 欄）；archive/restore/治理機＝§4.2 行為島波3。
**Alternatives**：status 作存取閘／role restore／②不 enforce（皆否決——前二 scope OUT、後者違 frozen invariant）。
