# Data Model: 011-role-management

> 本刀＝rust facade（sys_role CRUD＋sys_user_role count helper＋**sys_casbin_rule DB-first set_role_dimension**）＋handler（system_manage.rs +9 端點）＋id↔code/route_name 映射＋main 註冊＋lint bump；base-web wrapper/MODAL-WIRING (a)(b)。**無持久實體變更、無 migration**（表＋seed＋policy＋button code m001/m002 已備、research R1/R6）。型/簽名一律當前 lineage（`c377444`/`a59c2738`）親 grep。
> **★ B1 校正**：Role×Menu 寫採 **DB-first**（facade 直寫 `entity::casbin_rule` 11-col 於 `mutate_in_txn` 原子 op-log、②protected-reject、寫後 `load_policy()` reload、**無 MgmtApi 寫**）——依 constitution §I.7 §4.2 ①DB-first/④原子/⑤reload（research R1/R2）。

## 0. 命名對照（同概念多形、刻意）
| 場景 | 形 | 例 |
|---|---|---|
| DB（entity 欄） | snake_case | `code`／`name`／`role_desc`／`home`／`status`／`deleted_at`；casbin_rule `ptype/v0-v5/protected/created_at/created_by` |
| 端點 path | camelCase 尾 | `/systemManage/getRoleList`／`/systemManage/updateRoleMenu` |
| wire DTO/typings | camelCase | `roleName`／`roleCode`／`roleId`／`menuIds`／`home` |
| **id 域（⚠️r）** | number | `Role.id`／`roleId`（獨立參數、不轉 String）／`menuIds` |
| casbin policy | ptype/v0/v1/v2 | `('p', role_code, route_name, 'menu')`（v2='menu' 選單可見性） |
| i18n biz key（6 鍵、§5/§9） | `biz.role.<condition>` camel | `duplicateRoleCode`／`notFound`／`seededProtected`／`inUse`／`cannotDeleteSelfRole`／`menuProtected` |

## 1. facade `server/src/model/facade/sys_role.rs`（改：+CRUD fn、archetype A、entity:: 合法）
既有不動：`find_active`（濾 deleted_at、R7）／`home_of_roles`。新增（鏡像 sys_user 009、research R3）：
**讀**：`list(conn, RoleSearchQuery)->PageRes<Model>`（§5.8：roleName/roleCode 模糊 `LOWER(col) LIKE ESCAPE`、status 精確、空字串守門）／`find_active_by_id(conn,id)->Option<Model>`。
**寫**（`<C:TransactionTrait>`、`mutate_in_txn`、6 審計欄成對 §I.6、同 txn op-log）：`create`（INSERT op-log）／`update`（含 home 欄、find None→Ok(None) no-op、UPDATE op-log）／`soft_delete`（delete guards 於 handler 前置、成對 deleted_at/by、SOFT_DELETE op-log）／`batch_soft_delete`（整批拒）。`build_create_active_model`/`build_update_active_model` 純測 seam。roleCode 23505 由 handler `map_write_err`。

## 2. facade `server/src/model/facade/sys_user_role.rs`（改：+count helper、research R5）
既有 `roles_of_user`/`roles_for_users`/`replace_roles_in_txn` 不動。新增 `count_users_by_role_id(conn,role_id:i64)->Result<i64,DbErr>`（`Entity::find().filter(RoleId.eq(role_id)).count()`；in-use guard）。

## 3. ★ facade `server/src/model/facade/sys_casbin_rule.rs`（net-new；DB-first 角色×選單寫；constitution §I.7 §4.2、research R1/R2）
```rust
pub enum SetDimensionError { Db(DbErr), Rejected(Vec<String>) }  // Rejected 攜 protected objs（②）
pub struct SetDimensionOutcome { pub changed: bool }             // 供 handler 決定是否 reload

// DB-first：直寫 entity::casbin_rule（11-col）於 mutate_in_txn、原子 op-log；無 MgmtApi 寫
pub async fn set_role_dimension<C: TransactionTrait>(conn:&C, role_code:&str, dimension:&str, desired_objs:&[String], operator:AuditOperator, trace:Option<String>, role_id:i64) -> Result<SetDimensionOutcome, SetDimensionError>
//   mutate_in_txn：
//     current = entity::casbin_rule::Entity::find().filter(ptype='p' ∧ v0=role_code ∧ v2=dimension).all(&txn)  // 11-col、見 protected
//     diff → to_revoke（current\desired）／to_grant（desired\current）
//     ② to_revoke 任一 protected==true → return Err(Rejected(那些 objs))（整批拒、零變更）
//     revoke: Entity::delete_many().filter(ptype='p' ∧ v0=role_code ∧ v2=dimension ∧ v1 IN to_revoke).exec(&txn)
//     grant: 逐 ActiveModel{ptype:Set("p"),v0:Set(role_code),v1:Set(obj),v2:Set(dimension),v3..v5:Set(""),created_at:Set(now),created_by:Set(Some(op.id)),protected:Set(false)}.insert(&txn)
//     op-log: AuditEvent{operation:Update, entity_table:"casbin_rule", entity_id:Some(role_id), payload_before:current route_names, payload_after:desired route_names}（同 txn、★原子）
//     changed = !to_revoke.is_empty() || !to_grant.is_empty()
```
- ★ **無 enforcer MgmtApi 寫**（不 remove_filtered_policy/add_policies）；casbin_rule 寫經 **entity::casbin_rule（AppState.db txn）**＝與 op-log 同連線同 txn 原子（research R2）。
- handler 在 set_role_dimension 回 Ok 且 `changed` **後**（txn 已 commit）：`state.enforcer.write().await.load_policy().await.map_err(|_|AppError::Internal)?`（⑤ 全量 reload、本地；單實例。cross-instance publish/watcher＝波3）。
- 讀端（getRoleMenu）：復用 010 `enforce::menu_routes_for_roles(&*state.enforcer.read().await, &[code])`（in-memory 讀、非寫、合規）。
- **lint**：entity::casbin_rule 僅本 facade（entity_access_lint 豁免）。

## 4. id ↔ route_name 映射（research R5；menu-auth-modal 用 menu id、casbin 用 route_name）
- **getRoleMenu(roleId)**：`find_active_by_id(roleId)` None→`biz.role.notFound`；命中→code→`menu_routes_for_roles([code])`→route_names→經 sys_menu 映射成 menu ids `number[]`（orphan route_name skip）。
- **updateRoleMenu(roleId, menuIds)**：menuIds→sys_menu find by ids→route_names→`set_role_dimension(role_code,"menu",route_names,...)`→Ok 且 changed→reload。menuIds 含不存在 id→skip（tolerant、對齊 read-side orphan skip；D1 校正）。
- sys_menu facade 建議加 `route_names_for_ids`/`ids_for_route_names`（或 handler 自 `list_active`〔010〕結果建 map、Model 欄存取非 entity:: path-root）。

## 5. handler `server/src/handler/system_manage.rs`（改：+9 端點、沿 009/010 檔）
```rust
struct RoleUpsertReq { id:Option<String>, role_name:String, role_code:String, role_desc:Option<String>, status:Option<String> }
struct RoleMenuReq { role_id:i64, menu_ids:Vec<i64> }   struct RoleHomeReq { role_id:i64, home:String }
// IdReq{id:String}／IdsReq{ids:Vec<String>}（009 既有）／RoleSearchQuery（§5.8 空字串守門）

get_role_list(...Query<RoleSearchQuery>)->Res<PageRes<RoleListItem>>   // R_SUPER+R_ADMIN
add_role(...Json<RoleUpsertReq>)->Res<()>     // create.map_err(map_write_err)→23505→biz.role.duplicateRoleCode
update_role(...Json<RoleUpsertReq>)->Res<()>  // id parse→update None→biz.role.notFound（name/desc/status；home 由 update_role_home）
delete_role(...Json<IdReq>) / batch_delete_role(...Json<IdsReq>)->Res<()>   // delete guards（§8）→2222；整批拒
get_role_menu(...Query<{roleId:i64}>)->Res<Vec<i64>>   // §4：role code→menu_routes_for_roles→route_name→menu id
update_role_menu(...Json<RoleMenuReq>)->Res<()>
//   find_active_by_id(role_id) None→biz.role.notFound；menu_ids→route_names；
//   set_role_dimension(code,"menu",route_names,op,trace,role_id) → match SetDimensionError::Rejected→biz.role.menuProtected 2222／Db→Internal；
//   Ok(outcome) 且 outcome.changed → state.enforcer.write().await.load_policy().await（⑤ reload）
get_role_home(...Query<{roleId:i64}>)->Res<String>   // find_active_by_id→home（default "home"）
update_role_home(...Json<RoleHomeReq>)->Res<()>       // sys_role.home entity 寫（facade update/set_home、原子 op-log）
```
- 回型 `Result<Json<Res<Value>>,AppError>`；handler/auth 零 path-root entity::（casbin 寫在 sys_casbin_rule facade；reload 用 enforcer）。
- `map_write_err`（沿 009）：sql_err→UniqueConstraintViolation→`Biz("biz.role.duplicateRoleCode")`。delete guards/notFound/menuProtected→handler match→`AppError::Biz`。casbin/reload 失敗→`AppError::Internal`。

## 6. main.rs router（改：9 路由 require_policy；鏡像 009/010、enforce.rs 不改）
入 roles 子 router（route_layer require_policy＋外層 enforce_mw）：getRoleList GET（R_SUPER+R_ADMIN、seed 決）／addRole·updateRole POST／deleteRole·batchDeleteRole DELETE／getRoleMenu GET·updateRoleMenu POST／getRoleHome GET·updateRoleHome POST。path/method 與 m002 seed 逐字對齊（research R6）。

## 7. wire 3 端對齊（§I.3、research R4；id 域 number）
| wire | typings | rust | 映射 |
|---|---|---|---|
| `Role.id` | number | i64 | number（⚠️r） |
| `roleName`/`roleCode`/`roleDesc` | string | name/code/Option | 直 |
| `status` | `'1'\|'2'\|null` | Option<i16> | i16→str |
| `getRoleMenu` 回 | `number[]` | route_names | route_name→sys_menu.id（orphan skip） |
| `updateRoleMenu` body | `{roleId:number,menuIds:number[]}` | `RoleMenuReq{role_id:i64,menu_ids:Vec<i64>}` | number（不轉 String、R4） |
| `getRoleHome`/`updateRoleHome` | string／`{roleId:number,home:string}` | `home:Option<String>` | 直（default "home"） |
| `RoleUpsertModel.id`（updateRole） | number? | — | wrapper `String(id)`（沿 009） |
- 2^53 fail-loud guard（沿 010 wire_id）。

## 8. delete guards（research R5、D3；handler 前置、跨 entity ⚠️o）
deleteRole(id)／batchDeleteRole(ids) 軟刪前逐項驗（任一失敗→整筆/整批拒 2222、DB 無變）：① `find_active_by_id` None→`biz.role.notFound`；② `role.code ∈ {R_SUPER,R_ADMIN,R_USER_COMMON}`（hardcode）→`biz.role.seededProtected`；③ `count_users_by_role_id(id)>0`→`biz.role.inUse`；④ `roles_of_user(claims.uid)` codes contains role.code→`biz.role.cannotDeleteSelfRole`。batch 同 txn 先全檢查、整批拒 no-partial（沿 010）。軟刪角色殘留 v2='menu' policy 無害（可刪角色必無人用；波3 治理清）。

## 9. i18n keys（BASE-WEB-I18N-WIRING、⚠️y；wire msg＝key 去 backend.）
- **locale**：`backend.biz.role.{duplicateRoleCode, notFound, seededProtected, inUse, cannotDeleteSelfRole, menuProtected}`（**6 鍵**、含 ★ `menuProtected`＝受保護選單可見性不可移除〔②protected-reject〕）——zh-cn(简体)/en-us，加於既有 `backend.biz`（009/010 之後）。
- **★ Schema**：`app.d.ts` `App.I18n.Schema.backend.biz` 加 `role:{...6 鍵}`（**先 Schema 後 locale**、沿 009/010）。

## 10. base-web wire＋frontend（WRAPPER／ADAPT／MODAL-WIRING (a)(b)、research R4）
- **L3 WRAPPER** `service/api/rev3-system-manage.ts`：`fetchAddRole`/`fetchUpdateRole`（id→String）/`fetchDeleteRole`/`fetchBatchDeleteRole`（ids.map(String)）/`fetchGetRoleMenu(roleId:number)`/`fetchUpdateRoleMenu(roleId:number,menuIds:number[])`（roleId/menuIds **維持 number**）/`fetchGetRoleHome(roleId)`/`fetchUpdateRoleHome(roleId,home)`。getRoleList/getAllRoles（system-manage.ts 既有）、getMenuTree/getAllPages（010）續用。
- **L1/L2 ADAPT** `typings/api/rev3-system-manage.d.ts`：`RoleUpsertModel`（`Pick<Role,'roleName'|'roleCode'|'roleDesc'|'status'>&{id?:number}`、declaration-merge、不改既有 `Role`）。
- **L4 MODAL-WIRING (a)**：`role/index.vue` handleDelete→fetchDeleteRole／handleBatchDelete→fetchBatchDeleteRole；`role-operate-drawer.vue` handleSubmit→add fetchAddRole／edit fetchUpdateRole；`menu-auth-modal.vue` getChecks→fetchGetRoleMenu／handleSubmit→fetchUpdateRoleMenu（checks:number[]；**移除受保護→後端 2222 `menuProtected` toast 在地化、不靜默**）／getHome→fetchGetRoleHome／updateHome→fetchUpdateRoleHome（home 選項 getAllPages 010）。標 `rev3-inline MW(a)`、原 stub 行註解保留。
- **L4 MODAL-WIRING (b)** hasAuth gating：role/index.vue 寫入鈕 `hasAuth('role:add'/'role:edit'/'role:delete')`（R_SUPER seed）。標 `rev3-inline MW(b)`。
- **button-auth-modal.vue 留 mock（波3）**；既有 system-manage.ts/.d.ts/auth.ts/request/route store/transform 不改；**無 .env flip**（010 已 dynamic）。

## 11. `server/tests/endpoint_coverage_lint.rs`（改：bump、research R6）
`AS_BUILT_ROUTES [&str;22]→[&str;31]`（+9 role path）。9 皆 policy-routes→Assertion A m002 已 seed 自動過；Assertion B registered==as-built；與註冊同 commit。

## 12. 排除聲明（OUT/MOOT）
- **MOOT（已 done）**：sys_role/sys_user_role/casbin_rule（11-col entity）/sys_casbin_policy_archive（13-col entity、本刀不消費）schema＋3 角色＋9 端點 policy＋`role:*` button code（m001/m002）／enforce_mw·require_policy·menu_routes_for_roles·buttons_for_roles·roles_of_user·mutate_in_txn〔任意 entity_table〕·SoftDeletable·to_audit_operator·blanket From·envelope·sql_err·PageRes·endpoint_coverage_lint（004-010）／casbin Enforcer init·`load_policy()`（reload 用）／base-web route store·transform·system-manage.ts〔getRoleList/getAllRoles/getMenuTree/getAllPages〕·auth.ts·role-search·menu-auth-modal getTree·Role/RoleList typings·hasAuth hook（既有）／010 getMenuTree/getAllPages/getUserRoutes。
- **OUT（遞延、波3）**：archive（revoke→`sys_casbin_policy_archive`；本刀 revoke=hard DELETE）／restore（←archive）／protected 策略**管理**（un-protect/re-protect；本刀僅 ②enforce「移除受保護→拒」）／PolicyMutated-gate 優化（③）／跨實例 `casbin:policy:invalidate` publish-watcher（本刀單實例本地 load_policy）／回收桶 UI／button-auth（getAllButtons/getRoleButton/updateRoleButton＋button-auth-modal）／endpoint-auth＋endpoint-auth-modal／role g-policy 角色繼承／role restore（無、軟刪單向）／role status 作存取閘（metadata）。
