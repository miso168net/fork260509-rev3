# Data Model: 009-user-management

> 本刀＝rust facade（sys_user 4 fn＋sys_user_role 3 fn＋sys_role 1 fn＋auth hash_password）＋handler 6 端點＋login gate＋error sql_err map＋main 接線（復用 008 require_policy）＋lint bump；base-web wire/MODAL-WIRING (a)。**無持久實體變更、無 migration**（表＋partial-unique＋6 端點 policy m001/m002/m003 已 seed、research R1）。型/簽名一律當前 lineage（`028289a`）親 grep（research R-A~R-D）。

## 0. 命名對照（同概念多形、刻意）
| 場景 | 形 | 例 |
|---|---|---|
| DB（entity 欄） | snake_case | `user_name`／`user_gender`／`nick_name`；sys_role＝**`code`/`name`/`role_desc`/`home`**（R2、**非** role_code/role_name） |
| 端點 path | camelCase 尾 | `/systemManage/getUserList`／`addUser`／`batchDeleteUser`（m002:97-116 親驗） |
| wire DTO/typings/component | camelCase | `userName`／`userGender`／`userRoles`／`createBy`／`roleCode` |
| i18n biz key | `biz.<entity>.<condition>` camel | `biz.user.duplicateUserName`／`cannotDeleteSelf`／`selfLockForbidden`／`notFound` |
| 前端頁/路由 | hyphen | `views/manage/user/`／`/manage/user`（既有） |

## 1. facade `server/src/model/facade/sys_user.rs`（改：+4 fn、archetype A、entity:: 合法）
既有不動：`soft_delete`(L47)／`find_by_user_name`(L82)／`find_by_id`(L95)／`set_pointer`／`current_session_id_of`／`impl SoftDeletable`(L10)／`impl AuditSerialize for Model`(L18-39、**已 redact password**、復用作 op-log payload)。新增：
```rust
// 分頁+filter 列表（讀端、排除 soft-deleted；§5.8 首 exercise）
pub async fn list_active<C: ConnectionTrait>(
    conn: &C, page: u64, size: u64, f: UserFilter,
) -> Result<(Vec<entity::sys_user::Model>, u64), DbErr>
//   use sea_orm::{QueryFilter, QueryOrder, QueryTrait, PaginatorTrait};
//   use sea_orm::sea_query::{Expr, LikeExpr}; use sea_orm::sea_query::extension::postgres::PgExpr;
//   let q = Entity::find_active()                                  // soft_delete.rs:19 (deleted_at IS NULL)
//     .apply_if(f.user_name,  |q,t| q.filter(ilike(Column::UserName,  &t)))   // 模糊（R6）
//     .apply_if(f.nick_name,  |q,t| q.filter(ilike(Column::NickName,  &t)))   // 模糊
//     .apply_if(f.user_email, |q,t| q.filter(ilike(Column::UserEmail, &t)))   // 模糊
//     .apply_if(f.user_phone, |q,t| q.filter(Column::UserPhone.eq(t)))         // 精確
//     .apply_if(f.user_gender,|q,g| q.filter(Column::UserGender.eq(g)))        // i16 精確
//     .apply_if(f.status,     |q,s| q.filter(Column::Status.eq(s)))            // i16 精確
//     .order_by_desc(Column::Id);                                  // 穩定序+靜音 paginator warn（R7）
//   let p = q.paginate(conn, size);
//   Ok((p.fetch_page(page).await?, p.num_items().await?))          // page=current-1（0-based、R7）
// fn ilike(col, t) -> SimpleExpr: Expr::col(col).ilike(LikeExpr::new(format!("%{}%", escape_like(t))).escape('\\'))

// 建（insert、首個 Insert op-log；密碼雜湊在 handler 算好傳入）
pub async fn create<C: TransactionTrait>(
    conn: &C, fields: UserWrite, password_hash: String,
    operator: AuditOperator, trace_id: Option<String>,
) -> Result<entity::sys_user::Model, DbErr>
//   mutate_in_txn: am = ActiveModel{ user_name:Set(f.user_name), password:Set(password_hash),
//     nick_name/user_gender/user_phone/user_email/status:Set(..), created_at:Set(now()),
//     created_by:Set(Some(operator.id)), session_policy:Set("inherit".into()), ..Default };
//   let after = am.insert(&txn).await?;            // 回填 DB-gen id
//   event = AuditEvent{ Insert, "sys_user", entity_id:Some(after.id), before:None,
//     after:Some(after.audit_json()), operator:Some(operator), trace_id };
//   Ok((txn, after, Some(event)))   // ★ 23505 由 handler 寫端 sql_err() map（§7）

// 改（by id、userName/password 不動；查無/已刪→Ok(None)）
pub async fn update<C: TransactionTrait>(
    conn: &C, id: i64, fields: UserWrite,
    operator: AuditOperator, trace_id: Option<String>,
) -> Result<Option<entity::sys_user::Model>, DbErr>
//   mutate_in_txn: before = find_active_by_id(id)? → None→Ok(None) no-op；
//     am = before.into_active_model(); am.nick_name/user_gender/user_phone/user_email/status = Set(..);
//     ★ 不 set user_name/password；am.updated_at=Set(Some(now())); am.updated_by=Set(Some(operator.id));  // 成對§I.6
//     after = am.update(&txn)?; event{ Update, entity_id:Some(id), before:Some(before.audit_json()),
//     after:Some(after.audit_json()), operator, trace }; Ok((txn, Some(after), Some(event)))

// 讀單筆（排除 soft-deleted；update/驗證用、非 find_by_id 含 soft-deleted 版）
pub async fn find_active_by_id<C: ConnectionTrait>(conn:&C, id:i64) -> Result<Option<Model>, DbErr>
//   Entity::find_active().filter(Column::Id.eq(id)).one(conn)
```
- `build_create_active_model`/`build_update_active_model` 純測 seam（欄映射、created_at/updated_at·updated_by 成對 Set）。**lint**：entity:: 僅 facade。
- `UserWrite{ user_name:String, nick_name:Option<String>, user_gender:Option<i16>, user_phone:Option<String>, user_email:Option<String>, status:Option<i16> }`（facade 入參、handler 從 DTO 轉）；`UserFilter{ user_name/nick_name/user_email/user_phone:Option<String>, user_gender/status:Option<i16> }`（**已 normalize 空字串→None**、§5/handler）。

## 2. facade `server/src/model/facade/sys_user_role.rs`（改：+2 fn；roles_of_user(L11) 不動）
```rust
// list 批次組裝（無 N+1、固定查詢；user_ids→{uid: Vec<code>}）
pub async fn roles_for_users<C: ConnectionTrait>(conn:&C, uids:&[i64]) -> Result<HashMap<i64,Vec<String>>, DbErr>
//   (1) sys_user_role filter UserId.is_in(uids) → Vec<(user_id, role_id)>
//   (2) sys_role(find_active) filter Id.is_in(distinct role_ids) → HashMap<role_id, code>
//   (3) 組 HashMap<user_id, Vec<code>>（缺空→[]）

// 整批替換 user 角色（與 user 寫同 txn；未知/已刪 code 靜默丟）
pub async fn replace_roles_in_txn(txn:&DatabaseTransaction, uid:i64, role_codes:&[String]) -> Result<(), DbErr>
//   delete_many sys_user_role WHERE user_id=uid;
//   ids = sys_role::find_active().filter(Code.is_in(role_codes)).select Id → Vec<i64>;  // 未知/已刪 code 自然不解出
//   insert_many sys_user_role{user_id:uid, role_id} for id in ids（空→skip）
```
> ★ `replace_roles_in_txn` **必在 create/update 的同一 `mutate_in_txn`**（roles/op-log 同成同敗、否則 desync）。

## 3. facade `server/src/model/facade/sys_role.rs`（改：+find_active list；現零 query fn）
```rust
pub async fn find_active<C: ConnectionTrait>(conn:&C) -> Result<Vec<entity::sys_role::Model>, DbErr>
//   Entity::find_active().order_by_asc(Column::Id).all(conn)   // getAllRoles 下拉用（R2：code/name）
```

## 4. `server/src/auth/password.rs`（改：+prod hash_password；既有 verify 不動、#[cfg(test)] hash 不動）
```rust
pub fn hash_password(plain: &str) -> Result<String, argon2::password_hash::Error>
//   let salt = SaltString::generate(&mut OsRng);
//   Argon2::default().hash_password(plain.as_bytes(), &salt).map(|h| h.to_string())   // 對齊 m002 seed + verify
```

## 5. handler `server/src/handler/system_manage.rs`（新；`handler/mod.rs` +pub mod）
```rust
// DTO（camelCase serde）
struct UserListItem { id:i64, user_name:String, user_gender:Option<String>, nick_name:Option<String>,
  user_phone:Option<String>, user_email:Option<String>, status:Option<String>, user_roles:Vec<String>,
  create_by:String, create_time:String, update_by:String, update_time:String }   // §9 映射；零 password
struct AllRoleItem { id:i64, role_name:String, role_code:String }                 // name→roleName, code→roleCode
struct UserUpsertReq { id:Option<String>, user_name:String, nick_name:Option<String>,
  user_gender:Option<String>, user_phone:Option<String>, user_email:Option<String>,
  status:Option<String>, user_roles:Vec<String> }   // 無 password；update 帶 id（body、String→i64）
struct IdReq{ id:String }   struct IdsReq{ ids:Vec<String> }

// GET getUserList（R_SUPER+R_ADMIN）
get_user_list(State, Extension<Claims>, Query<UserSearchQuery>) -> Res<PageRes<UserListItem>>
//   normalize: page=current.unwrap_or(1).max(1); size=size.unwrap_or(10).clamp(1,100);
//   filter: 空字串→None（str: .filter(|v|!v.is_empty()); gender/status: Some("")→None 再 parse i16）★§5.8
//   list_active(page-1, size, filter) → roles_for_users(ids) 組 user_roles → PageRes
// GET getAllRoles（R_SUPER+R_ADMIN+R_USER_COMMON）
get_all_roles(State, Extension<Claims>) -> Res<Vec<AllRoleItem>>   // sys_role::find_active → map（code→roleCode,name→roleName）
// POST addUser（R_SUPER）
add_user(State, Extension<RequestContext>, Extension<Claims>, Json<UserUpsertReq>) -> Res<()>
//   self-guard N/A（新建非自己）; hash = hash_password("123456")?; (operator,trace)=ctx.to_audit_operator(claims.uid);
//   create(...).map_err(dup_or_internal)? ＋ replace_roles_in_txn 同 txn   // ★ 23505→2222（§7）
// POST updateUser（R_SUPER）
update_user(State, Extension<RequestContext>, Extension<Claims>, Json<UserUpsertReq>) -> Res<()>
//   id = req.id.parse::<i64>().map_err(|_| Biz("biz.user.notFound"))?;
//   self-guard: id==claims.uid && (R_SUPER ∉ user_roles || status==Some("2")) → Biz("biz.user.selfLockForbidden") 2222
//   update(id,...) None→Biz("biz.user.notFound"); ＋ replace_roles_in_txn 同 txn   // userName/password 不動
// DELETE deleteUser{id} / batchDeleteUser{ids}（R_SUPER）
delete_user / batch_delete_user
//   ids parse String→i64; self in ids → Biz("biz.user.cannotDeleteSelf") 整批拒（無 partial）;
//   soft_delete(id) loop（已不存在/已刪 no-op 靜默略過、clarify Q2）; 各 entity_id Some(id)
```
- 回型 `Result<Json<Res<serde_json::Value>>, AppError>`（既有信封慣例）；DTO 零 path-root entity::。

## 6. login gate `server/src/handler/auth.rs`（改：login_inner 密碼驗證後、R10）
```text
... password::verify 通過後（auth.rs:76 後、let uid=model.id 前）：
  if model.status == Some(2) { return Err((Some(model.id), AppError::LoginFailed)); }   // 1000 統一失敗、防枚舉
```
- 復用既有 `AppError::LoginFailed`（1000、`auth.login.failed`）＝零新 i18n/變體；status 已在 find_by_user_name 回的 Model。

## 7. error 23505→2222 落點（research R5、⚠️o；blanket From<DbErr> 不動）
- 寫端（addUser/updateUser 的 create/update facade 呼叫處）：
```rust
.map_err(|e| match e.sql_err() {
    Some(sea_orm::SqlErr::UniqueConstraintViolation(_)) => AppError::Biz("biz.user.duplicateUserName".into()),
    _ => AppError::Internal,
})?
// use sea_orm::SqlErr;（同 DbErr 模組）；blanket impl From<DbErr> for AppError(→Internal)保持不變
```
- 確切落點（handler 呼叫處 map vs facade 返 typed err）impl 定；傾向 handler 呼叫處 `.map_err`（facade 仍回 `DbErr`、保持 facade 純粹）。**禁裸 `?`**（會走 blanket From→5000 type-lie、research R5 陷阱）。

## 8. main.rs router（改：users 子 router、鏡像 008 system_settings main.rs:99-121）
```text
let users = Router::new()
  .route("/systemManage/getUserList", get(handler::system_manage::get_user_list)
     .route_layer(middleware::from_fn_with_state(state.clone(), auth::enforce::require_policy("/systemManage/getUserList","GET"))))
  .route("/systemManage/getAllRoles", get(...get_all_roles).route_layer(...require_policy(".../getAllRoles","GET")))
  .route("/systemManage/addUser", post(...add_user).route_layer(...require_policy(".../addUser","POST")))
  .route("/systemManage/updateUser", post(...update_user).route_layer(...require_policy(".../updateUser","POST")))
  .route("/systemManage/deleteUser", delete(...delete_user).route_layer(...require_policy(".../deleteUser","DELETE")))
  .route("/systemManage/batchDeleteUser", delete(...batch_delete_user).route_layer(...require_policy(".../batchDeleteUser","DELETE")))
  .layer(middleware::from_fn_with_state(state.clone(), auth::enforce::enforce_mw));   // 外層 auth
// app: ....merge(users)...  audit_mw 已最外層（007）
```
- `require_policy(path:&'static str, method:&'static str)`（enforce.rs:153、不改）；6 policy m002 已 seed（R1）。

## 9. wire 3 端對齊（§I.3、research R9；type-lie 序列化邊界消解）
| wire（typings 權威） | typings 型 | rust entity | 序列化映射 |
|---|---|---|---|
| `id` | number | `id:i64` | **number**（⚠️r、非 to_string） |
| `userName` | string | `user_name:String` | 直 |
| `userGender` | `'1'\|'2'\|null` | `user_gender:Option<i16>` | `.map(\|n\|n.to_string())` |
| `nickName`/`userPhone`/`userEmail` | string | `Option<String>` | 直（null→?；typings 宣告 string，必要時 unwrap_or_default） |
| `status` | `'1'\|'2'\|null` | `status:Option<i16>` | `.map(\|n\|n.to_string())` |
| `userRoles` | string[] | （join） | `roles_for_users` code[]（批次） |
| `createBy`/`updateBy` | string（non-null） | `created_by/updated_by:Option<i64>` | `.map(\|v\|v.to_string()).unwrap_or_default()`（NULL→`""`＝忠實具現〔系統列無 operator〕、§I.3 lie-ledger 不需加列；i64→string 為 ⚠️r 邊界轉換、非謊） |
| `createTime` | string | `created_at:DateTimeWithTimeZone` | `.to_rfc3339()` |
| `updateTime` | string（non-null） | `updated_at:Option<...>` | `.map(\|v\|v.to_rfc3339()).unwrap_or_default()`（NULL→`""`） |
| `AllRole.id/roleName/roleCode` | number/string/string | sys_role `id/name/code` | id number；name→roleName；code→roleCode |
- **讀端零 password**（UserListItem 無 password 欄）。write `UserUpsertReq` 無 password（addUser 預設 123456 後端 hash）。drawer `Model`＝`Pick<User,...>`＝component state 天然對齊。2^53 fail-loud guard（id）。

## 10. i18n keys（BASE-WEB-I18N-WIRING (ii)(iii)、⚠️y canonical；wire msg＝key 去 backend. 前綴）
- **(ii) locale**：`backend.biz.user.duplicateUserName`（23505 dup）／`backend.biz.user.notFound`（查無/id parse 失敗）／`backend.biz.user.cannotDeleteSelf`／`backend.biz.user.selfLockForbidden`（自我降權/停用）——zh-cn/en-us 兩家、加於既有 `backend.biz`（zh:710-714 後）。攔截器/translateBackendMsg **無需改**（自動 `$t('backend.'+msg)`、R-D）。停用登入用 `auth.login.failed`（既有、復用）。
- **★ (iii) Schema**：`src/typings/app.d.ts` `App.I18n.Schema.backend.biz` 加 `user:{duplicateUserName,notFound,cannotDeleteSelf,selfLockForbidden}` 型（**先 Schema 後 locale**；locale dict 宣告 `const local: App.I18n.Schema`、缺 Schema 鍵→excess-property typecheck red、C-V-12 紅；同 008 「先 Schema 後 locale」）。Schema 與 locale 同 commit 對齊。

## 11. base-web wire＋frontend（WRAPPER/ADAPT/MODAL-WIRING (a)）
- `service/api/rev3-system-manage.ts`（新、`import {request} from '../request'`、view 直接路徑 import 非 barrel）：`fetchAddUser(model)`／`fetchUpdateUser(model)`（帶 id）／`fetchDeleteUser(id)`／`fetchBatchDeleteUser(ids)`／（getUserList/getAllRoles 既有 system-manage.ts 可續用或 wrap）。
- `typings/api/rev3-system-manage.d.ts`（新、declaration-merge `Api.SystemManage`）：`UserUpsertModel`（write DTO、`Pick<User,7 欄>` + 可選 id；不改既有 system-manage.d.ts）。
- `views/manage/user/index.vue`（MW (a)）：`handleDelete(id)`→`fetchDeleteUser`／`handleBatchDelete`→`fetchBatchDeleteUser`（去 console.log stub:147-159）；`rev3-inline MW(a)` 修改型原行註解保留。
- `views/manage/user/modules/user-operate-drawer.vue`（MW (a)）：`handleSubmit`(:105) 於 `await validate()` 後插 HTTP（`props.operateType` add→fetchAddUser／edit→fetchUpdateUser 帶 `props.rowData.id`）；**移除 getRoleOptions mock workaround**（grep 穩定 marker `// if the real request, remove the following code`、約 :82-89、行號易 rot）→`roleOptions.value = options`。
- **MW (b) hasAuth gating 不做**（R3、延波2 Menu 刀）。

## 12. `server/tests/endpoint_coverage_lint.rs`（改：bump、research R11）
- `AS_BUILT_ROUTES: [&str; 5]` → `[&str; 11]`，加 6 distinct path（getUserList/getAllRoles/addUser/updateUser/deleteUser/batchDeleteUser）。scan/assertion 不動；6 policy m002 已 seed→Assertion A 自動過；**與 main.rs 路由註冊同 commit**（dedup by path）。

## 13. 排除聲明（OUT/MOOT）
- **MOOT（已 done）**：表+partial-unique+FK+6 端點 policy（m001/m002/m003、R1）／sys_user/sys_role/sys_user_role entity／AuditSerialize for sys_user+redact（既存）／mutate_in_txn+SoftDeletable+PageRes+to_audit_operator+require_policy+blanket From<DbErr>+envelope（004/005/006/007/008）／User→User01 alias（006 getUserInfo）。
- **OUT（遞延）**：前端 hasAuth button gating＋dynamic menu（波2 Menu 刀、R3）／updateUserSessionPolicy+session-policy-modal（波3、§4.3）／即時 token 撤銷（波3、停用只擋新登入）／完整 Role CRUD+三權限 modal（§8.6 另刀；getAllRoles 僅下拉）／改密碼（updateUser 不動 password）／pg_trgm GIN index（未來）。
