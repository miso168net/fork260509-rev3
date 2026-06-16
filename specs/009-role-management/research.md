# Research: Role Management（009）— Phase 0

> Phase 0 output（/speckit-plan）。**CLAUDE.md §3 紀律：act on actual code、不信 brainstorm 假設**。
> 本檔結論由 8-agent 平行 grep 真實 `rust-api`／`base-web` 實碼產出（非 brainstorm 推測）；每條附 grep 實證；**★ 標 implementer 必須處置的實碼缺口**。三個 load-bearing claim（m002 role policy／m001 partial-uniq／sys_role entity 欄）已 controller 二次 grep 複驗。

## R1 — sys_role facade 簽名（既有 vs 新增）＋ 008 寫路徑樣板 ＋ audit infra

- **Decision**: `sys_role` 現有 **4 個 query-only** facade fn 原樣複用；**新增 6 fn ＋ 2 struct ＋ 1 trait impl ＋ 3 query helper**。
  - 既有（grep 確認）：`find_active()→Select<Entity>`／`find_active_by_ids(db,&[i64])→Vec<Model>`／`find_active_by_codes(db,&[String])→Vec<Model>`／`all_active(db)→Vec<Model>`（getAllRoles 用，008 加）。**無任何寫路徑**。
  - 008 `sys_user` 寫路徑樣板（009 鏡像）：`create(db, fields:NewUser, roles:&[RoleModel], operator:AuditOperator, trace_id:Option<String>)→Model`、`update(db, id, fields:NewUser, roles:&[RoleModel], operator, trace_id)→Model`、`soft_delete(db, id, operator:AuditOperator, trace_id)→bool`；query helper `soft_delete_query`／`update_set_query`（建 `UpdateMany<Entity>`）；`impl AuditSerialize for Model`（redact password、15 欄）。
  - audit infra（`server/src/model/audit.rs`）：`AuditOperation{Insert,Update,SoftDelete,Restore}`（含 `as_str()`）；`AuditOperator{id:i64, ip:Option<IpAddr>}`（**無 derive、非 Clone**）；`AuditEvent{operation,entity_table,entity_id:Option<i64>,payload_before:Option<Value>,payload_after:Option<Value>,operator:Option<AuditOperator>,trace_id:Option<String>}`；`AuditSerialize::audit_json(&self)→Value`；`mutate_in_txn<R,F,Fut>(db,f)`（閉包回 `(DatabaseTransaction, R, Option<AuditEvent>)`、同 txn 經 `sys_operation_log::write_in_txn` 寫 op-log）。
- **Rationale**: `sys_role.rs:17-50`／`entity/src/sys_role.rs:8-22`／`sys_user.rs:47-75,96-213,245-265`／`audit.rs:14-81`／`sys_operation_log.rs:37-40`。facade-only archetype（`entity_access_lint` build-failing guard）。
- **★ gaps（net-new）**：`find_active_by_id`／`find_active_by_code`（**singular**、dup-check 用、現只有複數 `find_active_by_codes`）／`search_active(db,&RoleFilter,current,size)→(Vec<Model>,u64)`／`create`／`update`／`soft_delete`；struct `NewRole{code,name,role_desc,status,home}`、`RoleFilter`；`impl AuditSerialize for sys_role::Model`；query helper `create_query`／`update_set_query`／`soft_delete_query`。
- **★ delta vs 008**：`sys_role::create/update` **無 `roles` 參數**（Role 為 **leaf entity**、不觸 join）；`audit_json` **無 redaction**（sys_role 12 欄全 audit-safe、無 password）。
- **TYPE 注意**：`AuditOperator` 無 Clone → mutate_in_txn 閉包前先 `let operator_id = operator.id`（008 `sys_user.rs:103` 樣板）。

## R2/R3 — wire 三端型映射（entity↔wire↔base-web）＋ component state

- **Decision**: Role 鏈三端**對齊**、欄名固定 `roleName`/`roleCode`/`roleDesc`/`status`；`Role.id`→JSON **number**（⚠️r、`CommonRecord.id:number`、2^53 guard）。
  - typings（`system-manage.d.ts:10-29`）：`Role = CommonRecord<{roleName:string; roleCode:string; roleDesc:string}>`；`CommonRecord`（`common.d.ts:35-48`）帶 `id:number / createBy / createTime / updateBy / updateTime / status:EnableStatus|null`；`EnableStatus='1'|'2'`（`common.d.ts:32`）；`RoleSearchParams = Pick<Role,'roleName'|'roleCode'|'status'> & CommonSearchParams`；`AllRole = Pick<Role,'id'|'roleName'|'roleCode'>`。
  - service（`system-manage.ts:4-22`）：`fetchGetRoleList` / `fetchGetAllRoles` **既有（讀）**；`addRole`/`updateRole`/`deleteRole`/`batchDeleteRole` **不存在**（前端 stub）。
  - wrapper 樣板（`rev3-system-manage.ts:8-29`，008 User 形）：`fetchAddUser(model:Pick<...無 id>)`／`fetchUpdateUser(model:Pick<...> & {id:number})`／`fetchDeleteUser(id:number)`／`fetchBatchDeleteUser(ids:number[])`（DELETE，`ids` 逗號字串 query）。
  - `role/index.vue`：`handleDelete(id)`＝`console.log(id)` stub（`:124-129`）／`handleBatchDelete()`＝`console.log(checkedRowKeys.value)` stub（`:117-122`）；`:row-key="row=>row.id"`（numeric、`:159`）；search 欄 `roleName/roleCode/status`（`:14-20`，初始 null）。
  - `role/modules/role-operate-drawer.vue`：`type Model = Pick<Role,'roleName'|'roleCode'|'roleDesc'|'status'>`（**無 id**、`:47`）；`roleId = rowData?.id || -1`（`:68`）；`isEdit = operateType==='edit'`（`:70`）；`handleSubmit`＝validate→toast→close→emit **stub、不分 add/edit**（`:84-90`）。
- **Rationale**: 上列 file:line 實讀。
- **★ gaps / discrepancies**：
  1. **handleSubmit 不分 add/edit** → 須依 `operateType` 分支 `fetchAddRole(model)` vs `fetchUpdateRole({...model, id:roleId})`（MODAL-WIRING (a)）。
  2. **handleDelete/handleBatchDelete 是 console.log stub** → 接 `fetchDeleteRole`/`fetchBatchDeleteRole`（MODAL-WIRING (a)）。
  3. **roleCode edit 未禁改**（`:disabled` 未設）→ FR-006 要求「edit 時 roleCode read-only」→ drawer roleCode 欄加 `:disabled="isEdit"`（最小 inline、見 plan Constitution Check #2）。
  4. **drawer `:76` `Object.assign(model.value, jsonClone(rowData))`** 把整個 Role（含 id/審計欄）灌進 Pick model → 提交時帶多餘欄；後端 `RoleUpsertReq` serde **未設 `deny_unknown_fields`→ 多餘欄自動忽略**（非 data bug、同 008）；wrapper update 送 `{...model, id}` 即可。
  5. snake→camel：entity `code/name/role_desc`→wire `roleCode/roleName/roleDesc`；`status:Option<i16>`↔`'1'|'2'|null`（沿 008 `i16_to_wire`/`wire_to_i16`）。

## R4 — handler／error／route 結構 ＋ 008 共用 helper 可見性（Role handler 放哪）

- **Decision**: **Role handler 寫進既有 `handler/system_manage.rs`**（grow existing、非新檔）。理由：008 共用 helper 是該檔 **private fn**；同檔即可直接複用、**零 008 可見性 churn**。檔現 811 行、feature/endpoint 編排、Role 為自然延續。route 註冊於 `main.rs` 的 `system_manage` sub-router、統一 `.route_layer(enforce_mw)`（同 008）。
  - 共用 helper（`system_manage.rs:28-107`，private）：`i16_to_wire(Option<i16>)→Option<String>`（:28）／`wire_to_i16(Option<&str>)→Result<Option<i16>,()>`（:36，`Some("")→Ok(None)`）／`blank_to_none(Option<String>)→Option<String>`（:48）／`serialize_id_guarded`（:58，2^53 fail-loud）／`check_name_collision`（:79，純函式）／`ensure_user_name_available(db,name,self_id)`（:88，user-specific）／`audit_operator(&RequestContext)→Result<AuditOperator,AppError>`（:102，operator_id None→`internal`5000）。
  - error（`error.rs`／`envelope.rs`）：`AppError::biz(msg)`→`2222`（:34）／`permission_denied()`→`5003`（HTTP 403、:59）／`internal(detail)`→`5000`（HTTP 200、detail 僅 log、:64）；`BizCode` 矩陣（`envelope.rs:104-117`）`2222/5003/5000`；http_status 僅 `5003→403`、其餘含 `5000→200`（:138-147）。
  - `From<DbErr> for AppError`（`error.rs:73-77`）：**blanket→`internal(5000)`**（★ 見 Q-DUP）。
  - `RequestContext`（`audit_ctx.rs:31-37`）：`{operator_id:Option<i64>, client_ip:IpAddr, x_forwarded_for, region, trace_id:String}`、`audit_mw` 每請求注入（:49-103）；handler 取 `Extension<RequestContext>`。
  - route 樣板（`main.rs:88-105`）：`.route("/systemManage/<op>", get|post|delete(...))` ×6 → `.route_layer(from_fn_with_state(state.clone(), auth::enforce::enforce_mw))`。
- **Rationale**: 上列 file:line 實讀；`handler/mod.rs:4-5`（`pub mod auth; pub mod system_manage;`）。
- **★ gaps**：net-new role-specific helper `ensure_role_code_available(db,code,self_id)→Result<(),AppError>`（鏡像 `ensure_user_name_available`、復用純函式 `check_name_collision`）；net-new seed 謂詞 `is_seed_role(id)`（id∈{1,2,3}）。**brainstorm §5.9「傾向新檔」被 act-on-code 推翻**：helper private、新檔需改可見性 → grow existing 較省 churn。

## R5 — m002 casbin policy（5 role 端點）＋ sys_role seed

- **Decision**: 5 端點 casbin policy **全在 m002、已 seed**（seeded-but-unimplemented、本刀補 handler）；存取矩陣＝**getRoleList: R_SUPER+R_ADMIN／addRole·updateRole·deleteRole·batchDeleteRole: R_SUPER only**。sys_role seed **sequence-driven**（不寫 id）→ id 1/2/3 = R_SUPER/R_ADMIN/R_USER_COMMON。`roleCode = casbin subject(v0)` → 故 **roleCode 不可變**。
- **Rationale（controller 複驗）**: `m002:108-109`（getRoleList R_SUPER+R_ADMIN GET）／`:110-112`（getAllRoles 三角色 GET）／`:117-118`（addRole/updateRole R_SUPER POST）／`:119-120`（deleteRole/batchDeleteRole R_SUPER DELETE）；`m002:65-67`（sys_role seed `('R_SUPER',...),('R_ADMIN',...),('R_USER_COMMON',...)` 不寫 id）；`m002:78-82`（sys_user_role 以 `code` subquery 解 role_id、非 hardcode）。
- **★ 注意**：policy v0=roleCode(subject)、v1=path、v2=HTTP method（大寫）；handler route 的 **path 字面＋method 必與 m002 完全一致**（`/systemManage/getRoleList` GET 等），否則 endpoint_coverage_lint 抓 missing。
- **★ 範圍佐證**：`getRoleMenu/updateRoleMenu/getRoleButton/getRoleEndpoints/getRoleHome/updateRoleHome`（`m002:128-153`）亦已 seed 但**屬授權指派維度、本刀 OUT**（需 sys_menu）→ 維持 seeded-but-unimplemented、被 lint 容忍。

## R6 — soft-deleted role inert ＋ 停用（status）角色是否仍授權（spec clarify 延後題）

- **Decision**: **soft-deleted role 自動 inert**（`roles_for_user`/`roles_for_users` 走 `sys_role::find_active_by_ids` → `SoftDeletable::find_active()` 僅濾 `deleted_at IS NULL`）→ deleteRole **不需動 casbin/join**、grants 自動失效。**停用（status=2）但未刪的 role 仍授權**——active filter **只濾 deleted_at、不濾 status**；唯有 soft-delete 才撤權。
- **Rationale**: `sys_user_role.rs:26,94`（roles_for_user/users → find_active_by_ids）；`sys_role.rs:16-19`（find_active 委派 SoftDeletable）；`soft_delete.rs:9-11`（`find_active()` 濾 `deleted_at_column().is_null()`、**無 status**）；`enforce.rs:104`（enforce_mw 取 DB-fresh role codes 經 roles_for_user）。
- **★ acceptance 預期（鎖定 spec clarify 延後題）**：**停用 role 不撤權、僅刪除撤權**——對齊 spec Out-of-Scope「停用 baseline role 允許、只擋刪」＋ Assumptions。**本刀不改此行為**（純 CRUD、不碰 enforce 基盤）；live smoke 不需驗停用撤權（非本刀責）。日後若需「停用即撤權」＝新增 `find_active_and_enabled`（`deleted_at IS NULL AND status<>2`）＝另刀。

## R7 — endpoint_coverage_lint bump（6→11）

- **Decision**: `server/tests/endpoint_coverage_lint.rs` `const EXPECTED_ROUTE_COUNT = 6`（:30）→ **bump 11**。lint 從 `main.rs` 動態 derive gated route（`/systemManage/` 前綴＋method）、交叉檢查每條有 ≥1 m002 `'p'` policy；**容忍 seeded-but-unimplemented 多餘 policy**。5 條 role route 加進 main.rs 後 lint 自動 derive 為 11 條、policy 皆已 seed（R5 驗）→ 綠。
- **Rationale**: 全檔讀（`endpoint_coverage_lint.rs:1-83` 含 EXPECTED guard `assert_eq!`；derive 邏輯純函式、有 scan_tests 單測）。
- **★ gaps**：(1) bump `EXPECTED_ROUTE_COUNT` 6→11；(2) 更新檔頭 doc 註解（`:8` 把 role 端點從「seeded-but-unimplemented 範例」移除、改舉 menu 端點為例；`:22-26` count 說明）；(3) 結構**零改**（count guard 外全自動）。controller sanity-bite：故意破一條 policy/route → lint 須大聲失敗指名。

## ★★ Q-DUP（CRITICAL）— dup roleCode → 2222（非 5000）＋ 並發 race 裁決

- **Decision**: addRole 須 `find_active_by_code(roleCode)` **pre-check 命中→`AppError::biz`→`2222`**（不可依賴 `From<DbErr>`）。DB partial-unique `sys_role_code_active_uniq`（`m001:759-760`，`code WHERE deleted_at IS NULL`）為 data-integrity backstop ＋ 並發 race 最終裁決者。
- **★★ spec clarify 對齊（user 選 A：race「surfaces as same business rejection 2222、never a system failure」）**：因 `From<DbErr>` blanket→`5000`（`error.rs:73-77`），**單靠 pre-check 無法保證 race 也回 2222**（漏過 pre-check 又撞 DB 約束會浮 5000）。**故 create 路徑須對 unique-violation（pg SQLSTATE `23505` on `sys_role_code_active_uniq`）做 targeted catch → biz(2222)**，才完整兌現 clarify A。pre-check 為常態最佳化（≤50 admin 幾乎全覆蓋）、constraint-catch 為 race 守門（保證永不 5000）。
- **Rationale**: `error.rs:73-77`（blanket DbErr→5000）；`m001:759-760`（partial-uniq 在）；`envelope.rs:106,116`（2222/5000）；008 `ensure_user_name_available`（`system_manage.rs:88-95`）pre-check 樣板。
- **★ gaps**：net-new `find_active_by_code`（R1）；net-new `ensure_role_code_available` pre-check；create facade/handler 的 23505→2222 remap（見 data-model §4）。

## R8 — base-web wrapper／MODAL-WIRING／CDP cutover ＋ 空字串 filter

- **Decision**: **新增** `rev3-system-manage.ts` 4 role wrapper（WRAPPER §III.1、`rev3-inline` 標記）；MODAL-WIRING **(a)** 接 2 處（index.vue delete/batchDelete、drawer handleSubmit add/update）＋ drawer roleCode `:disabled="isEdit"`（FR-006）。CDP cutover **沿 008 §6**：`base-web/.env.test.local`（→`http://rust-api:31081`、gitignored）**已存在可複用**；CDP scripts（`tests/000/scripts/cdp-login.mjs`/`cdp-nav.mjs`/`cdp-capture-api.mjs`/`cdp-clear-and-relogin.mjs`）改選擇器對 `/manage/role`。**只導航 `/manage/role`**（`/manage/menu` 有前端、無後端→404）。
- **★ 空字串 filter（008 同款 bug 必中招）**：base-web axios `paramsSerializer`（`packages/axios/src/options.ts:52-54`）`stringify(params)` **無 skipNulls** → search 欄 null 序列化成空字串 query。後端守門＝既有 `wire_to_i16(Some(""))→Ok(None)`（`system_manage.rs:36`）＋`blank_to_none`（:48）；**getRoleList handler 須對 roleName/roleCode 套 `blank_to_none`、status 套 `wire_to_i16`**。cutover 後 CDP `/manage/role` 列表載出真 3 角色＝守門正確；空列/2222＝漏套。
- **Rationale**: `.env.test`（apifox mock）／`.env.test.local`（rust-api:31081、`.gitignore` `.env.*.local`）／`.env:17,26`（`VITE_AUTH_ROUTE_MODE=static`＋`VITE_HTTP_PROXY=Y`）；`get_user_list`（`system_manage.rs:187-241`）樣板；`wire_to_i16` 單測（`:485-493`）。
- **★ 修正**：brainstorm §5.6 把 drawer handleSubmit 標 **MW(c)** 有誤——依 constitution §III.2，create/update＋delete 接線全屬 **(a)**；**(c) 是 role×權限維度 auth-modal、本刀 OUT**。

---

## ★ Discrepancies / implementer act-on-code（必讀彙整）

1. **Q-DUP critical**：dup roleCode 目前→`5000`；須 `find_active_by_code` pre-check→`biz(2222)` ＋ create 對 `23505` unique-violation remap→`2222`（兌現 clarify A「race 永不 5000」）＋ dup→2222 測試。
2. **brainstorm §5.3 的 6 facade fn ＋ struct ＋ AuditSerialize 全是設計文字、實碼零實作**（實 facade 只有 4 query fn）；implementer 全建。
3. **base-web 4 寫端 fn 不存在**；必在**新** `rev3-system-manage.ts` 建。
4. **handler 放既有 `system_manage.rs`（grow）**、非新檔（helper private、複用免改可見性）；**推翻 brainstorm §5.9「傾向新檔」**。
5. **leaf 審計**：create/update/soft_delete **無 `roles` 參數、無 redaction**（Role 12 欄全 audit-safe）；與 008 composite/redact 樣板的兩處 delta。
6. **MODAL-WIRING 全是 (a)**（含 drawer create/update 接線）；**(c) auth-modal 屬 OUT**（brainstorm 標 (c) 為誤）。drawer 另加 roleCode `:disabled="isEdit"`（FR-006、最小 inline、(a) 同元件內）。
7. **endpoint_coverage_lint bump 6→11**＋doc 註解更新；結構零改。
8. **停用 role 仍授權**（active filter 僅濾 deleted_at）；本刀不改、acceptance 不驗撤權。
9. **getRoleList = R_SUPER+R_ADMIN**（R_ADMIN 可讀清單）；寫端 R_SUPER only（m002 實證、對齊 spec 矩陣）。
10. **drawer `:76` 灌整 rowData** 進 Pick model → 提交帶多餘欄；後端 serde 忽略 unknown（非 bug、同 008）。

---

**所有 NEEDS CLARIFICATION 已解**（R1-R8 grep 確認、Q-DUP/R6 實碼裁定；3 load-bearing claim controller 複驗）。Phase 1（data-model.md／contracts/）見同目錄。
