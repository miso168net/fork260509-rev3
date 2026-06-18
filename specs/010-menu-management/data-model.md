# Data Model: 010-menu-management

> 本刀＝rust facade（sys_menu 10 fn＋reparent/delete slim enum）＋enforce（menu_routes_for_roles）＋handler（route.rs 3＋system_manage.rs 8 端點）＋menu flat→tree 序列化＋main 分層＋lint bump；base-web `.env` dynamic＋wire/MODAL-WIRING (a)(b)。**無持久實體變更、無 migration**（表＋seed＋policy＋button code m001/m002/m004 已備、research R1）。型/簽名一律當前 lineage（`8ccea9d`/`c1806680`）親 grep（research R2-R12/R-cr）。

## 0. 命名對照（同概念多形、刻意）
| 場景 | 形 | 例 |
|---|---|---|
| DB（entity 欄） | snake_case | `parent_id`／`route_name`／`menu_type`／`hide_in_menu`／`#[sea_orm(column_name="order")] order`／`protected` |
| 端點 path | camelCase 尾／kebab | `/route/getUserRoutes`／`/systemManage/getMenuList/v2`／`/systemManage/addMenu` |
| wire DTO/typings | camelCase | `routeName`／`menuType`／`parentId`／`hideInMenu`／`iconType` |
| **id 兩域（⚠️r）** | string vs number | `Api.Route.MenuRoute.id`＝**string**／`Api.SystemManage.Menu.id`＝**number** |
| i18n biz key（全 8 鍵、§5/§8 權威） | `biz.menu.<condition>` camel | `duplicateRouteName`／`notFound`／`reparentTargetMissing`／`notDirectory`／`wouldCycle`／`protectedFixed`／`protectedNoDelete`／`hasActiveChildren` |
| component 字串 | layout$view | `layout.base$view.manage_menu`／`layout.base`／`view.manage_menu` |

## 1. enforce `server/src/auth/enforce.rs`（改：+menu_routes_for_roles；既有不動）
```rust
// 鏡像 buttons_for_roles（enforce.rs:114-128）、唯 rule[2]=="menu"（收 route_name）
pub fn menu_routes_for_roles(enforcer: &Enforcer, roles: &[String]) -> Vec<String>
//   for role in roles { for rule in enforcer.get_filtered_policy(0, vec![role.clone()]) {
//       if rule.len()>=3 && rule[2]=="menu" { let rn=rule[1].clone(); if !out.contains(&rn){out.push(rn)} } } } out
```
- `enforce_mw`/`require_policy`/`buttons_for_roles`/`enforce_role_path_method` 本體一行不動（§3.4）。

## 2. facade `server/src/model/facade/sys_menu.rs`（改：+10 fn＋2 slim enum、archetype A、entity:: 合法）
既有不動：`impl SoftDeletable`(現唯一)。新增：

**讀**（`<C: ConnectionTrait>`）：
```rust
list_active(conn) -> Result<Vec<Model>, DbErr>            // find_active().order_by_asc(Order/Id).all（getUserRoutes/getMenuTree 組樹）
list_all(conn)    -> Result<Vec<Model>, DbErr>            // find()（含 soft-deleted、getMenuList/v2 統一清單、R6）
find_active_by_id(conn, id) -> Result<Option<Model>, DbErr>  // reparent 目標/驗證用
route_name_exists(conn, &str) -> Result<bool, DbErr>     // isRouteExist（find_active route_name 比對）
distinct_pages(conn) -> Result<Vec<String>, DbErr>       // getAllPages（distinct component/route_name、R/D6）
```
**寫**（`<C: TransactionTrait>`、`mutate_in_txn`、6 審計欄成對 §I.6、同 txn op-log）：
```rust
create(conn, fields: MenuWrite, operator, trace) -> Result<Model, DbErr>
//   mutate_in_txn：ActiveModel set 各欄+created_at=now+created_by=Some(op.id) → insert → INSERT op-log（entity_id=Some(after.id)）
//   ★ 23505（route_name）由 handler 寫端 sql_err map（沿 009、§7）
update(conn, id, fields: MenuWrite, operator, trace) -> Result<Option<Model>, DbErr>
//   mutate_in_txn：find_active_by_id None→Ok(None)；命中→reparent_check(若 parent 變)→into_active_model set 各欄+updated_at/by 成對 → update → UPDATE op-log
//   ★ reparent_check 失敗：facade 回 Err 經 ReparentError→handler 映 2222（見下 enum；不依賴 AppError）
soft_delete(conn, id, operator, trace) -> Result<Option<Model>, DbErr>
//   mutate_in_txn：find_active_by_id None→Ok(None)；命中→delete_check（protected/has-active-children）→set deleted_at/by 成對 → SOFT_DELETE op-log
batch_soft_delete(conn, ids:&[i64], operator, trace) -> Result<(), DbErr>
//   ★ 逐項獨立 delete_check 全過才執行（整批拒、無 partial、spec Clarification）；各 id 各 SOFT_DELETE op-log
restore(conn, id, operator, trace) -> Result<Option<Model>, DbErr>
//   mutate_in_txn：find by id（含 soft-deleted）→若 parent_id 指向已刪/不存在→parent_id=None（孤兒→頂層 D5）→clear deleted_at/by → RESTORE op-log（首 consumer R9）
```
**slim error enum（⚠️o、不依賴 AppError、handler 映 2222）**：
```rust
pub enum ReparentError { Db(DbErr), TargetMissing, NotDirectory, WouldCycle, ProtectedFixed }
pub enum DeleteError   { Db(DbErr), Protected, HasActiveChildren }
// reparent_check(conn,id,new_parent:Option<i64>)->Result<(),ReparentError>：
//   new_parent=None → Ok（搬頂層合法、除非 self protected〔ProtectedFixed〕）；
//   Some(pid)：find_active_by_id(pid) None→TargetMissing；menu_type!=Some(1)→NotDirectory；
//   pid==id 或 pid ∈ descendants(id)→WouldCycle；self.protected→ProtectedFixed。
// delete_check(conn,id)：load→protected→Protected；find_active children count>0→HasActiveChildren。
// descendants(id)：遞迴/迭代查 active 子孫集（防環、tree-walk）。
```
- `MenuWrite{ parent_id:Option<i64>, route_name:String, menu_type:Option<i16>, menu_name:String, route_path/component/icon/i18n_key/href/active_menu:Option<String>, icon_type/status:Option<i16>, order:Option<i32>, hide_in_menu/keep_alive/constant/multi_tab:Option<bool>, fixed_index_in_tab:Option<i32>, query/buttons:Option<Json> }`（handler 從 DTO 轉、id/parentId String|number→i64、parentId 0→None）。
- `build_create_active_model`/`build_update_active_model` 純測 seam（欄映射、成對審計欄、update 不動 created_*）。**lint**：entity:: 僅 facade。

## 3. menu flat→tree 序列化（首立、RouteMeta D2-D4、research R7）
```text
fn build_tree(flat: Vec<Model>, visible: Option<&HashSet<String>>) -> Vec<Node>
//   parent_id 分組 → 巢狀；order ASC 排序；visible(Some)＝getUserRoutes Casbin 過濾後 route_name 集（None＝mgmt 全收）。
// 兩種 Node 序列化：
//   getUserRoutes → MenuRoute{ id:string(to_string), name:route_name, path:route_path, component, meta:{title(menuName i18n via i18n_key), i18nKey, icon|localIcon(icon_type==2), order, hideInMenu, keepAlive, constant, multiTab, href, activeMenu, query}, children }
//   getMenuList/v2 → Menu{ id:number, parentId:number(parent_id.unwrap_or(0)), menuType:"1"/"2", menuName, routeName, routePath, component, icon, iconType:"1"/"2", buttons(jsonb→[{code,desc}]), status, ...RouteMeta 子集, deleted:bool(deleted_at.is_some()), children }
```
- component：rust 直出 entity `component` 欄字串（已是 `layout.base$view.xxx` 格式、m002/m004 seed、transform.ts 對齊；rust 不轉換、原樣序列化）。
- icon_type==2 → 前端 localIcon（meta.localIcon）；==1 → icon（iconify）。href 非空＝外開（document 8 頁）。

## 4. handler `server/src/handler/route.rs`（新；/route/* 家族；`handler/mod.rs` +pub mod route）
```rust
get_user_routes(State, Extension<Claims>) -> Result<Json<Res<Value>>, AppError>   // auth-only
//   roles = roles_of_user(&db, claims.uid)（DB-fresh）；visible = menu_routes_for_roles(&enforcer, &roles) set；
//   flat = sys_menu::list_active；tree = build_tree(flat, Some(&visible))→MenuRoute[]；
//   home = role.home（取 roles 首個有 home、皆 'home' R3）；Res::ok(UserRoute{routes,home})
get_constant_routes() -> Result<Json<Res<Value>>, AppError>   // public（無 Extension<Claims>）
//   list_active filter constant==Some(true)→MenuRoute[]（現 seed 空→[]、R-cr）；Res::ok
is_route_exist(State, Extension<Claims>, Query<{routeName:String}>) -> Res<bool>   // auth-only
//   sys_menu::route_name_exists；Res::ok(bool)
```

## 5. handler `server/src/handler/system_manage.rs`（改：+8 menu 端點、沿 009 檔）
```rust
// DTO（camelCase serde）
struct MenuUpsertReq { id:Option<String>, parent_id:Option<i64>/*或 number*/, route_name:String, menu_type:Option<String>, menu_name:String,
  route_path/component/icon/i18n_key/href/active_menu:Option<String>, icon_type/status:Option<String>, order:Option<i32>,
  hide_in_menu/keep_alive/constant/multi_tab:Option<bool>, fixed_index_in_tab:Option<i32>, query/buttons:Option<Value> }  // 無 deleted；id/parentId 寫端轉 i64、parentId 0→None
struct IdReq{ id:String }   struct IdsReq{ ids:Vec<String> }

get_menu_list_v2(State, Extension<Claims>) -> Res<Vec<MenuListItem>>   // R_SUPER；list_all→build_tree(None)→含 deleted flag（R6）
get_menu_tree(State, Extension<Claims>) -> Res<Vec<MenuTreeItem>>      // R_SUPER；list_active→精簡樹（父選擇器）
get_all_pages(State, Extension<Claims>) -> Res<Vec<String>>           // R_SUPER；distinct_pages
add_menu(State, Extension<RequestContext>, Extension<Claims>, Json<MenuUpsertReq>) -> Res<()>
//   fields=menu_write_from_req；(op,trace)=ctx.to_audit_operator(claims.uid)；create.map_err(map_menu_write_err)?（23505→biz.menu.duplicateRouteName）
update_menu(...Json<MenuUpsertReq>) -> Res<()>
//   id parse；update(id,fields,..)→ReparentError match→biz 2222（reparentTargetMissing/notDirectory/wouldCycle/protectedFixed）；None→biz.menu.notFound；其餘 sql_err
delete_menu(...Json<IdReq>) / batch_delete_menu(...Json<IdsReq>) -> Res<()>
//   soft_delete/batch_soft_delete→DeleteError match→biz 2222（protectedNoDelete/hasActiveChildren）；None→notFound
restore_menu(...Json<IdReq>) -> Res<()>   // restore→None→notFound
```
- 回型 `Result<Json<Res<serde_json::Value>>, AppError>`（既有信封）；DTO 零 path-root entity::。
- `map_menu_write_err`（沿 009 map_write_err）：`sql_err()→UniqueConstraintViolation→Biz("biz.menu.duplicateRouteName")`；其餘 Internal。ReparentError/DeleteError→handler match→`AppError::Biz(...)`（不經 blanket From）。

## 6. main.rs router（改：/route/* 分層＋/systemManage/*Menu*；鏡像 009/008、enforce.rs 不改）
```text
// public（無 mw）：
let route_public = Router::new().route("/route/getConstantRoutes", get(handler::route::get_constant_routes));
// auth-only（enforce_mw、無 require_policy）：
let route_auth = Router::new()
  .route("/route/getUserRoutes", get(handler::route::get_user_routes))
  .route("/route/isRouteExist", get(handler::route::is_route_exist))
  .layer(from_fn_with_state(state.clone(), auth::enforce::enforce_mw));
// policy-governed（route_layer require_policy＋外層 enforce_mw、R_SUPER）：
let menus = Router::new()
  .route("/systemManage/getMenuList/v2", get(...get_menu_list_v2).route_layer(...require_policy("/systemManage/getMenuList/v2","GET")))
  .route("/systemManage/getMenuTree", get(...).route_layer(...require_policy(...,"GET")))
  .route("/systemManage/getAllPages", get(...).route_layer(...))
  .route("/systemManage/addMenu", post(...).route_layer(...require_policy(...,"POST")))
  .route("/systemManage/updateMenu", post(...))
  .route("/systemManage/deleteMenu", delete(...require_policy(...,"DELETE")))
  .route("/systemManage/batchDeleteMenu", delete(...))
  .route("/systemManage/restoreMenu", post(...require_policy(...,"POST")))
  .layer(from_fn_with_state(state.clone(), auth::enforce::enforce_mw));
// app: ....merge(route_public).merge(route_auth).merge(menus)...
```
- `require_policy` 8 menu 端點 path/method 與 m002 seed 逐字對齊（research R10/R1）。`mod handler::route;`。

## 7. wire 3 端對齊（§I.3、research R7；id 兩域 type-lie 消解）
| wire（typings 權威） | typings 型 | rust 來源 | 序列化映射 |
|---|---|---|---|
| `MenuRoute.id`（路由域） | string | `id:i64` | **to_string**（⚠️r、同 userId/MenuRoute） |
| `Menu.id`（管理域、CommonRecord） | number | `id:i64` | **number**（⚠️r、同 User.id） |
| `parentId`（管理域） | number | `parent_id:Option<i64>` | `.unwrap_or(0)`（0=頂層）；寫端 0→None |
| `menuType` | `'1'\|'2'` | `menu_type:Option<i16>` | `.map(\|n\|n.to_string())` |
| `iconType` | `'1'\|'2'` | `icon_type:Option<i16>` | 同上 |
| `status` | `'1'\|'2'\|null` | `status:Option<i16>` | i16→str |
| `buttons` | `MenuButton[]\|null` | `buttons:Option<Json>` | jsonb 直出（[{code,desc}]） |
| `query` | `[{key,value}]` | `query:Option<Json>` | jsonb 直出 |
| `component` | string | `component:Option<String>` | 直（`layout.base$view.xxx`、transform 對齊） |
| `deleted`（mgmt ADAPT） | boolean | `deleted_at:Option<...>` | `.is_some()`（rev3 ADAPT 加） |
| `MenuRoute.children`/`Menu.children` | 巢狀 | （tree build） | parent_id 組樹 |
| `home`（UserRoute） | string | `sys_role.home` | 直（皆 'home'、R3） |
- 2^53 fail-loud guard（id）。`createBy/updateBy/createTime/updateTime`（CommonRecord）沿 009 映射（Option<i64>→string/""、rfc3339）。

## 8. i18n keys（BASE-WEB-I18N-WIRING (ii)(iii)、⚠️y；wire msg＝key 去 backend.）
- **(ii) locale**：`backend.biz.menu.{duplicateRouteName, notFound, reparentTargetMissing, notDirectory, wouldCycle, protectedFixed, protectedNoDelete, hasActiveChildren}`——zh-cn(简体)/en-us，加於既有 `backend.biz`（009 後 user/systemSettings 之後）。攔截器/translateBackendMsg 無需改（自動 `$t('backend.'+msg)`）。
- **★ (iii) Schema**：`app.d.ts` `App.I18n.Schema.backend.biz` 加 `menu:{...8 鍵}`（**先 Schema 後 locale**、沿 009/008）。

## 9. base-web wire＋frontend（.env／WRAPPER／ADAPT／MODAL-WIRING (a)(b)、research R7/R8/R11/R-cr）
- **`base-web/.env`**（★ root、**非** `src/.env`、F1 校正）：`VITE_AUTH_ROUTE_MODE=static`→`dynamic`（BASE-WEB-ADAPT #7、**base-web 單元最後一步** R8）。route store/transform/builtin **不改**（R-cr）。
- **L3 WRAPPER** `service/api/rev3-system-manage.ts`（沿 009 檔加、direct-path）：`fetchAddMenu(model)`／`fetchUpdateMenu(model)`（帶 id）／`fetchDeleteMenu(id)`／`fetchBatchDeleteMenu(ids)`／`fetchRestoreMenu(id)`；getMenuList/v2·getMenuTree·getAllPages（system-manage.ts 既有）·getConstantRoutes/getUserRoutes（route.ts 既有）續用。
- **L1/L2 ADAPT** `typings/api/rev3-system-manage.d.ts`：`MenuUpsertModel`（write DTO、Pick<Menu,...>+可選 id）＋為 mgmt 列加 `deleted?:boolean`（declaration-merge `Api.SystemManage`、不改既有 `Menu`/`Api.Route`）。
- **L4 MODAL-WIRING (a)** `views/manage/menu/index.vue`：handleDelete→fetchDeleteMenu／handleBatchDelete→fetchBatchDeleteMenu（去 console.log stub）＋**新增「已刪除」欄**（讀 row.deleted）＋**restore action**（deleted 列→fetchRestoreMenu）；`menu-operate-modal.vue` handleSubmit→add→fetchAddMenu／edit/addChild→fetchUpdateMenu（getSubmitParams 既有、parentId 0=頂層）；父選擇 getMenuTree、page 下拉 getAllPages、route_name isRouteExist 前驗。標 `rev3-inline MW(a)`、原 stub 行註解保留。
- **L4 MODAL-WIRING (b)** hasAuth gating：menu/index.vue 寫入鈕 `hasAuth('menu:add'/'menu:edit'/'menu:delete')`；**retroactive** user/index.vue 寫入鈕 `hasAuth('user:add'/'user:edit'/'user:delete')`（R11、code 已 seed）。**system-settings skip**（R11、無 code+super-only moot）。標 `rev3-inline MW(b)`。
- 既有 system-manage.ts/.d.ts/auth.ts/request/route store/transform **不改**。

## 10. `server/tests/endpoint_coverage_lint.rs`（改：bump、research R10）
- `AS_BUILT_ROUTES [&str;11]→[&str;22]`，加 11 path（3 `/route/*`＋8 `/systemManage/*Menu*`）。`/route/getConstantRoutes`(public)/`getUserRoutes`/`isRouteExist`(auth-only) 入 AS_BUILT（Assertion B）但**非** policy-routes（Assertion A 不要求 seed）。scan/assertion 不動；8 `/systemManage/*Menu*` policy m002 已 seed→Assertion A 自動過；**與註冊同 commit**（dedup by path）。

## 11. 排除聲明（OUT/MOOT）
- **MOOT（已 done）**：sys_menu 表+28 欄+protected+partial-unique+10 baseline+66 demo+menu-visibility policy(17+66)+13 endpoint policy+button code（m001/m002/m004）／enforce_mw·require_policy·buttons_for_roles·roles_of_user·mutate_in_txn·SoftDeletable·AuditOperation::Restore·to_audit_operator·blanket From<DbErr>·envelope·sql_err map（004-009）／base-web route store 雙路徑·transform·builtin routes·filterAuthRoutesByRoles·getGlobalMenusByAuthRoutes·hasAuth hook·menu mgmt 頁 mock·Api.Route/Menu typings（既有）。
- **OUT（遞延）**：Role×Menu 授權（getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome+menu-auth-modal＝Role 刀、D2）／getDeletedMenus 端點（統一清單取代、R6）／iframe props 內嵌復原（沿 href 外開）／filter_routes 遞迴化（登 backlog）／system-settings button gating（R11 moot skip）／R_ADMIN user:edit button vs endpoint super-only seed 不對齊（R11 nuance、登 follow-up）／casbin_rule 治理欄（波 3）。
