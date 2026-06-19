# Data Model: 011-role-management

> 本刀＝rust facade（sys_role CRUD＋sys_user_role count helper）＋auth（set_role_menu_policies casbin WRITE）＋handler（system_manage.rs +9 端點）＋id↔code/route_name 映射＋main 註冊＋lint bump；base-web wrapper/MODAL-WIRING (a)(b)。**無持久實體變更、無 migration**（表＋seed＋policy＋button code m001/m002 已備、research R1/R6）。型/簽名一律當前 lineage（`c377444`/`a59c2738`）親 grep（research R1-R7）。

## 0. 命名對照（同概念多形、刻意）
| 場景 | 形 | 例 |
|---|---|---|
| DB（entity 欄） | snake_case | `code`／`name`／`role_desc`／`home`／`status`／`deleted_at`／`deleted_by` |
| 端點 path | camelCase 尾 | `/systemManage/getRoleList`／`/systemManage/updateRoleMenu` |
| wire DTO/typings | camelCase | `roleName`／`roleCode`／`roleDesc`／`roleId`／`menuIds`／`home` |
| **id 域（⚠️r）** | number | `Role.id`＝number；`roleId`＝number（獨立參數、不轉 String）；`menuIds`＝number[] |
| casbin policy | ptype/v0/v1/v2 | `('p', role_code, route_name, 'menu')`（v2='menu' 選單可見性） |
| i18n biz key（全 5 鍵、§5/§9） | `biz.role.<condition>` camel | `duplicateRoleCode`／`notFound`／`seededProtected`／`inUse`／`cannotDeleteSelfRole` |

## 1. facade `server/src/model/facade/sys_role.rs`（改：+CRUD fn、archetype A、entity:: 合法）
既有不動：`find_active`（濾 deleted_at、R7）／`home_of_roles`。新增（鏡像 sys_user 009、research R3）：
**讀**：
```rust
list(conn, q: RoleSearchQuery) -> Result<PageRes<Model>, DbErr>   // §5.8：roleName/roleCode 模糊 LOWER LIKE ESCAPE、status 精確、空字串守門、分頁
find_active_by_id(conn, id) -> Result<Option<Model>, DbErr>       // update/delete guard/id→code 用
```
**寫**（`<C: TransactionTrait>`、`mutate_in_txn`、6 審計欄成對 §I.6、同 txn op-log）：
```rust
create(conn, fields: RoleWrite, operator, trace) -> Result<Model, DbErr>           // INSERT op-log；roleCode 23505 由 handler map_write_err
update(conn, id, fields: RoleWrite, operator, trace) -> Result<Option<Model>, DbErr>  // find None→Ok(None) no-op；含 home 欄；UPDATE op-log
soft_delete(conn, id, operator, trace) -> Result<Option<Model>, DbErr>             // delete guards 已於 handler 前置（跨 entity、見 §8）；set deleted_at/by 成對；SOFT_DELETE op-log
batch_soft_delete(conn, ids:&[i64], operator, trace) -> Result<(), DbErr>          // 整批拒（handler 前置全檢查）；各 SOFT_DELETE op-log
```
- `RoleWrite{ name:String, code:String, role_desc:Option<String>, home:Option<String>, status:Option<i16> }`（handler 從 DTO 轉）。updateRoleHome 復用 update（只動 home）或獨立 set_home（plan/impl 定；皆 entity 寫、原子 op-log）。
- `build_create_active_model`/`build_update_active_model` 純測 seam（成對審計欄、update 不動 created_*）。**lint**：entity:: 僅 facade。

## 2. facade `server/src/model/facade/sys_user_role.rs`（改：+count helper、research R5）
既有不動：`roles_of_user`（回 codes）／`roles_for_users`／`replace_roles_in_txn`。新增：
```rust
count_users_by_role_id(conn, role_id: i64) -> Result<i64, DbErr>   // Entity::find().filter(RoleId.eq(role_id)).count()；in-use guard 用
```

## 3. casbin policy WRITE `server/src/auth/enforce.rs`（或新 `auth/policy.rs`；★ 首次、research R1/R2）
```rust
// MgmtApi via write-lock；auto-persist（adapter 直寫 casbin_rule＋更新 in-memory）；無 save_policy
pub async fn set_role_menu_policies(enforcer: &mut Enforcer, role_code: &str, route_names: &[String]) -> Result<(), AppError>
//   enforcer.remove_filtered_policy("", "p", 0, vec![role_code.to_string(), String::new(), "menu".to_string()]).await.map_err(|_| AppError::Internal)?;  // 移除該 role 全部 v2='menu'（v1 空＝wildcard）
//   let rules: Vec<Vec<String>> = route_names.iter().map(|r| vec![role_code.into(), r.clone(), "menu".into()]).collect();
//   if !rules.is_empty() { enforcer.add_policies("", "p", rules).await.map_err(|_| AppError::Internal)?; }
//   Ok(())
```
- 呼叫端（handler）：`let mut g = state.enforcer.write().await; set_role_menu_policies(&mut g, &code, &route_names).await?;`。
- `enforce_mw`/`require_policy`/`menu_routes_for_roles`/`buttons_for_roles`/`enforce_role_path_method` 本體一行不動（§3.4）。`casbin::Error`→`AppError::Internal`（無 `From<casbin::Error>`、手動）。
- ★ 非原子（R2）：此寫經 adapter 自有連線、與 op-log mutate_in_txn 不同 txn → updateRoleMenu op-log best-effort（policy 寫成功後記）。protected 不強制（波3）。

## 4. id ↔ route_name 映射（research R5、menu-auth-modal 用 menu id、casbin 用 route_name）
- **getRoleMenu(roleId)**：`find_active_by_id(roleId)` None→`biz.role.notFound`；命中→code→`menu_routes_for_roles(&*enforcer.read().await, &[code])`（010 既有讀）→route_names→經 sys_menu 映射成 **menu ids `number[]`**（orphan route_name〔sys_menu 無對應〕skip）。
- **updateRoleMenu(roleId, menuIds)**：menuIds→sys_menu find by ids→route_names→`set_role_menu_policies(role_code, route_names)`。menuIds 含不存在 id→skip（或 2222、plan/impl 定；建議 skip 容錯）。
- sys_menu facade 建議加 `route_names_for_ids(conn,&[i64])->Vec<String>`／`ids_for_route_names(conn,&[String])->Vec<i64>`（或 handler 自 `list_active`〔010 既有〕結果建 HashMap、存取 Model.route_name/Model.id 欄非 entity:: path-root）。

## 5. handler `server/src/handler/system_manage.rs`（改：+9 端點、沿 009/010 檔）
```rust
// DTO（serde camelCase）
struct RoleUpsertReq { id:Option<String>, role_name:String, role_code:String, role_desc:Option<String>, status:Option<String> }  // updateRole body id→i64
struct RoleMenuReq { role_id:i64, menu_ids:Vec<i64> }   struct RoleHomeReq { role_id:i64, home:String }
// IdReq{id:String}／IdsReq{ids:Vec<String>}（009 既有、deleteRole/batchDeleteRole 復用）
// RoleSearchQuery{ current, size, role_name:Option<String>, role_code:Option<String>, status:Option<String> }（§5.8、空字串守門 normalize）

get_role_list(State, Extension<Claims>, Query<RoleSearchQuery>) -> Res<PageRes<RoleListItem>>   // R_SUPER+R_ADMIN
add_role(State, Extension<RequestContext>, Extension<Claims>, Json<RoleUpsertReq>) -> Res<()>   // create.map_err(map_write_err)→roleCode 23505→biz.role.duplicateRoleCode
update_role(...Json<RoleUpsertReq>) -> Res<()>          // id parse→update→None→biz.role.notFound；含 status/desc/name（home 由 updateRoleHome）
delete_role(...Json<IdReq>) / batch_delete_role(...Json<IdsReq>) -> Res<()>   // ★ delete guards（§8）→2222；整批拒
get_role_menu(State, Extension<Claims>, Query<{roleId:i64}>) -> Res<Vec<i64>>   // §4：role code→menu_routes_for_roles→route_name→menu id
update_role_menu(...Json<RoleMenuReq>) -> Res<()>       // §4：menu_ids→route_names→set_role_menu_policies（write-lock）；op-log best-effort（R2）
get_role_home(State, Extension<Claims>, Query<{roleId:i64}>) -> Res<String>   // find_active_by_id→home（default "home"）
update_role_home(...Json<RoleHomeReq>) -> Res<()>       // sys_role.home entity 寫、原子 op-log
```
- 回型 `Result<Json<Res<serde_json::Value>>, AppError>`（既有信封）；DTO 零 path-root entity::。
- `map_write_err`（沿 009）：`sql_err()→UniqueConstraintViolation→Biz("biz.role.duplicateRoleCode")`；其餘 Internal。delete guards/notFound→handler match→`AppError::Biz(...)`。casbin write 失敗→`AppError::Internal`。

## 6. main.rs router（改：9 路由；鏡像 009/010、enforce.rs 不改）
```text
let roles = Router::new()
  .route("/systemManage/getRoleList", get(...get_role_list).route_layer(...require_policy("/systemManage/getRoleList","GET")))
  .route("/systemManage/addRole", post(...).route_layer(...require_policy(...,"POST")))
  .route("/systemManage/updateRole", post(...))
  .route("/systemManage/deleteRole", delete(...require_policy(...,"DELETE")))
  .route("/systemManage/batchDeleteRole", delete(...))
  .route("/systemManage/getRoleMenu", get(...require_policy(...,"GET")))
  .route("/systemManage/updateRoleMenu", post(...require_policy(...,"POST")))
  .route("/systemManage/getRoleHome", get(...))
  .route("/systemManage/updateRoleHome", post(...))
  .layer(from_fn_with_state(state.clone(), auth::enforce::enforce_mw));
// app: ....merge(roles)...
```
- `require_policy` 9 端點 path/method 與 m002 seed 逐字對齊（research R6）。getRoleList 同時 R_SUPER+R_ADMIN（seed 決、單一 route_layer 即可、enforcer 對任一 role 命中即過）。

## 7. wire 3 端對齊（§I.3、research R4；id 域 number）
| wire（typings 權威） | typings 型 | rust 來源 | 序列化/映射 |
|---|---|---|---|
| `Role.id`（CommonRecord） | number | `id:i64` | number（⚠️r 同 User.id） |
| `roleName`/`roleCode`/`roleDesc` | string | `name`/`code`/`role_desc:Option` | 直（desc null→沿 009） |
| `status` | `'1'\|'2'\|null` | `status:Option<i16>` | i16→str |
| `getRoleMenu` 回 | `number[]` | role v2='menu' route_names | route_name→sys_menu.id（orphan skip） |
| `updateRoleMenu` body | `{roleId:number, menuIds:number[]}` | `RoleMenuReq{role_id:i64,menu_ids:Vec<i64>}` | number（**不轉 String**、獨立參數 R4） |
| `getRoleHome`/`updateRoleHome` | string／`{roleId:number,home:string}` | `sys_role.home:Option<String>` | 直（default "home"） |
| `RoleUpsertModel.id`（updateRole） | number? | — | wrapper `String(id)`（單 body id 沿 009 慣例） |
| CommonRecord `createBy/updateBy/createTime/updateTime` | string/"" | Option<i64>/tstz | 沿 009 映射 |
- 2^53 fail-loud guard（id、沿 010 wire_id）。

## 8. delete guards（research R5、D3；handler 前置、跨 entity ⚠️o 留 handler）
deleteRole(id)／batchDeleteRole(ids) 軟刪前逐項驗（任一失敗→整筆/整批拒 2222、DB 無變）：
1. `find_active_by_id(id)` None→`biz.role.notFound`。
2. `role.code ∈ {"R_SUPER","R_ADMIN","R_USER_COMMON"}`（hardcode seeded、sys_role 無 protected 欄、零 migration）→`biz.role.seededProtected`。
3. `sys_user_role::count_users_by_role_id(id) > 0`（in-use）→`biz.role.inUse`。
4. self-role：`roles_of_user(claims.uid)`（codes）contains `role.code`→`biz.role.cannotDeleteSelfRole`。
- batch：同 txn 先對所有 ids 全檢查、任一失敗整批拒 no-partial（沿 010 batch_soft_delete 紀律）。
- 軟刪角色殘留 v2='menu'/v2='button'/endpoint policy（v0=code）：可刪角色必無人用→無害；波3 policy-governance 清理。

## 9. i18n keys（BASE-WEB-I18N-WIRING、⚠️y；wire msg＝key 去 backend.）
- **locale**：`backend.biz.role.{duplicateRoleCode, notFound, seededProtected, inUse, cannotDeleteSelfRole}`——zh-cn(简体)/en-us，加於既有 `backend.biz`（009/010 之後）。攔截器 `$t('backend.'+msg)` 自動。
- **★ Schema**：`app.d.ts` `App.I18n.Schema.backend.biz` 加 `role:{...5 鍵}`（**先 Schema 後 locale**、沿 009/010）。

## 10. base-web wire＋frontend（WRAPPER／ADAPT／MODAL-WIRING (a)(b)、research R4）
- **L3 WRAPPER** `service/api/rev3-system-manage.ts`（沿 009/010、direct-path）：`fetchAddRole(model)`／`fetchUpdateRole(model)`（id→String(id)）／`fetchDeleteRole(id)`／`fetchBatchDeleteRole(ids)`（ids.map(String)）／`fetchGetRoleMenu(roleId:number)`／`fetchUpdateRoleMenu(roleId:number, menuIds:number[])`（roleId/menuIds **維持 number**）／`fetchGetRoleHome(roleId)`／`fetchUpdateRoleHome(roleId, home)`。getRoleList/getAllRoles（system-manage.ts 既有）、getMenuTree/getAllPages（010）續用。
- **L1/L2 ADAPT** `typings/api/rev3-system-manage.d.ts`：`RoleUpsertModel`（`Pick<Role,'roleName'|'roleCode'|'roleDesc'|'status'>&{id?:number}`；declaration-merge、不改既有 `Role`）。
- **L4 MODAL-WIRING (a)**：`role/index.vue` handleDelete→fetchDeleteRole／handleBatchDelete→fetchBatchDeleteRole（去 console.log）；`role-operate-drawer.vue` handleSubmit→add→fetchAddRole／edit→fetchUpdateRole；`menu-auth-modal.vue` getChecks→fetchGetRoleMenu／handleSubmit→fetchUpdateRoleMenu（checks:number[]）／getHome→fetchGetRoleHome／updateHome→fetchUpdateRoleHome（home 選項 getAllPages 010）。標 `rev3-inline MW(a)`、原 stub 行註解保留。
- **L4 MODAL-WIRING (b)** hasAuth gating：role/index.vue 寫入鈕 `hasAuth('role:add'/'role:edit'/'role:delete')`（`role:*` R_SUPER 已 seed）。標 `rev3-inline MW(b)`。
- **button-auth-modal.vue 留 mock（波3）**；既有 system-manage.ts/.d.ts/auth.ts/request/route store/transform 不改；**無 .env flip**（010 已 dynamic）。

## 11. `server/tests/endpoint_coverage_lint.rs`（改：bump、research R6）
- `AS_BUILT_ROUTES [&str;22]→[&str;31]`，加 9 path（getRoleList/addRole/updateRole/deleteRole/batchDeleteRole/getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome）。9 皆 policy-routes（require_policy）→Assertion A m002 已 seed 自動過；Assertion B registered==as-built。scan/assertion 不動；**與註冊同 commit**。

## 12. 排除聲明（OUT/MOOT）
- **MOOT（已 done）**：sys_role/sys_user_role/casbin_rule schema＋3 角色＋sys_user_role＋9 端點 policy＋`role:*` button code（m001/m002）／enforce_mw·require_policy·menu_routes_for_roles·buttons_for_roles·roles_of_user·mutate_in_txn·SoftDeletable·to_audit_operator·blanket From<DbErr>·envelope·sql_err map·PageRes·endpoint_coverage_lint（004-010）／casbin Enforcer init·load_policy·MgmtApi（add_policies/remove_filtered_policy auto-persist）／base-web route store·transform·system-manage.ts〔getRoleList/getAllRoles/getMenuTree/getAllPages〕·auth.ts·request·role-search·menu-auth-modal getTree·Role/RoleList typings·hasAuth hook（既有）／010 getMenuTree/getAllPages/getUserRoutes。
- **OUT（遞延）**：button-auth（getAllButtons/getRoleButton/updateRoleButton＋button-auth-modal 留 mock＝波3）／endpoint-auth（getRoleEndpoints/...＋endpoint-auth-modal net-new＝波3）／policy-governance（protected 強制/archive/restore/PolicyMutated＝波3 行為島）／role g-policy 角色繼承（無 seed）／casbin_rule 治理欄寫入（adapter 不設、波3）／role restore（無、軟刪單向）／role status 作存取閘（metadata、加固另案）。
