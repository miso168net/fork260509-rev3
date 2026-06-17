# Data Model: 008-system-settings

> 本刀＝L4 facade（system_settings read/update）＋L5 handler（2 端點＋value_type 驗）＋L4 `require_policy` layer（policy 強制）＋L1 main 接線＋L8 endpoint_coverage_lint＋base-web wire/頁。**無持久實體變更、無 migration**（system_settings 表 m001 凍結 schema；端點/menu policy＋sys_menu 列已 m002 seed、見 research R1）。型/簽名一律走當前 lineage 親 grep（research R3-R9）。

## 0. 命名對照（同概念四形、刻意、analyze I1）
| 場景 | 形 | 例 |
|---|---|---|
| DB（entity/table/欄） | snake_case | `system_settings`／`setting_key`／`setting_value`／`value_type` |
| 後端 route_name／sys_menu | hyphen 字尾 | `manage_system-settings`（m002:251、elegant-router 編譯期自動生） |
| 端點 path | camelCase 尾 | `/systemManage/getSystemSettings`／`/systemManage/updateSystemSetting`（m002:162-163） |
| wire DTO／typings／component state | camelCase | `settingKey`／`settingValue`／`valueType`／`SystemSetting` |
| 前端頁目錄／路由路徑 | hyphen | `views/manage/system-settings/`／`/manage/system-settings` |
| i18n key | 各家族慣例 | `route.manage_system-settings`／`page.manage.systemSettings.*`／`backend.biz.systemSettings.*` |

> 四形並存為**刻意**（各層慣例：DB snake／route_name hyphen／wire camel／path hyphen）；非 drift。impl 須對齊各層慣例、勿混。

## 1. facade `server/src/model/facade/system_settings.rs`（新、archetype A、entity:: 合法）
```rust
// 讀全列（無刪除路徑、含所有 row；§5.0 system_settings 不套用分頁）
pub async fn find_all<C: ConnectionTrait>(conn: &C) -> Result<Vec<entity::system_settings::Model>, DbErr>

// 改單鍵值（mutate_in_txn 同 txn op-log；查無→Ok(None) no-op）
pub async fn update_by_key<C: TransactionTrait>(
    conn: &C, key: &str, new_value: String,
    operator: AuditOperator, trace_id: Option<String>,
) -> Result<Option<entity::system_settings::Model>, DbErr>
//   mutate_in_txn(conn, |txn| async move {
//     let before = Entity::find_by_id(key).one(&txn).await?;
//     match before { None => Ok((txn, None, None)),                       // no-op（查無、不寫審計、非 error）
//       Some(before) => {
//         let mut am = before.clone().into_active_model();
//         am.setting_value = Set(new_value);
//         am.updated_at = Set(Some(now)); am.updated_by = Set(Some(operator.id)); // §I.6 成對
//         let after = am.update(&txn).await?;
//         let event = AuditEvent{ operation: AuditOperation::Update, entity_table:"system_settings".into(),
//            entity_id: None /* PK 非 i64、entity_id 留 None；key 入 payload */,
//            payload_before: Some(before.audit_json()), payload_after: Some(after.audit_json()),
//            operator: Some(operator), trace_id };
//         Ok((txn, Some(after), Some(event))) } } }).await
```
- `impl AuditSerialize for entity::system_settings::Model`（手構 json、無敏感欄需遮蔽——KV 值非密；逐欄序列化）。
- `*_active_model` 純測 seam（欄映射、updated_at/by Set）；`facade/mod.rs` 加 `pub mod system_settings;`。**lint**：entity:: 僅此 facade 合法。
- **entity_id 注記**：op-log `entity_id: Option<i64>`、system_settings PK＝String→ `entity_id` 留 `None`，setting_key 入 payload_before/after json（plan/impl 確認此 mapping）。

## 2. handler `server/src/handler/system_settings.rs`（新；`handler/mod.rs` 加 `pub mod system_settings;`）
```rust
// DTO（camelCase wire）
struct SystemSettingItem { setting_key, setting_value, value_type, description: Option<String> } // serde camelCase
struct UpdateReq { setting_key: String, setting_value: String }                                   // serde camelCase

// GET /systemManage/getSystemSettings（super-only via require_policy）
pub async fn get_system_settings(State, Extension<Claims>) -> Result<Json<Res<serde_json::Value>>, AppError>
//   facade::system_settings::find_all(&state.db).await? → map SystemSettingItem[] → Res::ok(flat array)

// POST /systemManage/updateSystemSetting（super-only）
pub async fn update_setting(State, Extension<RequestContext>, Extension<Claims>, Json<UpdateReq>)
    -> Result<Json<Res<serde_json::Value>>, AppError>
//   1. 讀 target（find by key）→ 查無 → AppError::Biz("biz.systemSettings.notFound")  // 2222
//   2. validate_value_type(&target.value_type, &req.setting_value)? → 不符 → Biz("biz.systemSettings.invalidValue")  // 2222（§6）
//   3. let (operator, trace) = ctx.to_audit_operator(claims.uid);        // 007 seam helper（R9）
//   4. facade::system_settings::update_by_key(&state.db, &req.setting_key, req.setting_value, operator, trace).await?
//   5. Res::ok(...)
```
- DTO 零 path-root `entity::`（走 facade）；回型＝既有信封慣例 `Result<Json<Res<serde_json::Value>>, AppError>`。

## 3. `require_policy` layer（`server/src/auth/enforce.rs` 改：加、`enforce_mw` 不動、R3）
```text
require_policy(path: &'static str, method: &'static str) -> (掛 route_layer 的 middleware)
  middleware::from_fn_with_state(state.clone(), move |State(state), Extension(claims): Extension<Claims>, req, next| async move {
    let roles = facade::sys_user_role::roles_of_user(&state.db, claims.uid).await?;   // ★ DB-fresh、不信 claims.roles
    if !enforce_role_path_method(&*state.enforcer.read().await, &roles, path, method) {
        return Err(AppError::PermissionDenied);   // 5003 → HTTP 403
    }
    Ok(next.run(req).await)
  })
```
- **`enforce_mw` 一行不動**（守 §3.4）；受保護業務路由＝`enforce_mw`（注入 Claims）＋`require_policy`（DB-fresh 授權）兩層。
- perf：per-request 多一次 `roles_of_user` join（⚠️a p95<300ms 內；getUserInfo 已同 join、proven-affordable）。
- **plan 確認**：`require_policy` 回型（`impl Layer`/closure factory）＋ axum 0.7 per-route `route_layer` 疊兩層的具體寫法（鏡像 main.rs:92-95 enforce_mw `from_fn_with_state`）。

## 4. `server/src/main.rs`（改：註冊 2 路由＋分層）
```text
let system_settings = Router::new()
  .route("/systemManage/getSystemSettings", get(handler::system_settings::get_system_settings))
  .route("/systemManage/updateSystemSetting", post(handler::system_settings::update_setting))
  .layer(require_policy(...))            // 內層 policy（per-route、注意 ×2 端點 path/method 各自）
  .layer(from_fn_with_state(state, enforce_mw));  // 外層 auth
// merge 進 app；audit_mw 已最外層（007、access-log 自動覆蓋）
```
- **plan 確認**：兩端點 path/method 不同→ `require_policy` 須 per-route（非 router-level 單一 path）；可能各 route 各掛 `require_policy(path,method)`（route_layer），或 require_policy 自 req.uri()/method() 取——plan 定具體形（傾向各 route 掛各自 path/method 常數、與 endpoint_coverage_lint registry 對齊）。

## 5. op-log threading（R9、007 seam 首 live consumer）
- `ctx.to_audit_operator(claims.uid)`（audit_ctx.rs:47）→ `(AuditOperator{id:uid, ip:Some(IpNetwork::from(ctx.client_ip))}, Some(ctx.trace_id))` → 餵 `update_by_key`→`mutate_in_txn`→`write_in_txn`；op-log `operator_id`/`operator_ip`(真 INET)/`trace_id` 由恆 None→真值。

## 6. value_type 驗證（R5、handler 改前驗）
```text
validate_value_type(value_type: &str, value: &str) -> Result<(), AppError>
  // value_type 形 "enum:on,off"：split(':') → ["enum", "on,off"]；"enum" 分支→ 合法值集 = "on,off".split(',')；value ∈ 集？否 → Err(Biz("biz.systemSettings.invalidValue"))
  // 其他型（number/string/json）目前不 seeded → 純測涵蓋 enum；plan 標「型擴充隨需要」
```

## 7. base-web wire（R7、§I.3 三端對齊、首批業務 wire）
- DTO（rust）↔ typings（ts）↔ component state，全 camelCase：`settingKey/settingValue/valueType/description`。
- `service/api/rev3-system-settings.ts`（WRAPPER、新 rev3- 檔）：`fetchGetSystemSettings()`／`fetchUpdateSystemSetting(settingKey, settingValue)`。
- `typings/api/rev3-system-settings.d.ts`（ADAPT、新檔）：`SystemSetting`＋`UpdateSystemSettingReq`（augment `Api.SystemManage` 或新 namespace、不改既有 system-manage.d.ts）。

## 8. i18n keys（兩家族、兩軌道）
- **錯誤訊息（BASE-WEB-I18N-WIRING (ii)(iii)、⚠️y canonical）**：wire `msg`＝`biz.systemSettings.<condition>`、locale 落 `backend.biz.systemSettings.<condition>`（zh-cn/en-us 兩家）＋`app.d.ts` Schema `backend.biz.systemSettings` 型（先 Schema 後 locale）。conditions：`invalidValue`／`notFound`（plan 確認集）。攔截器無需改（既有 `translateBackendMsg` `$t('backend.'+msg)`）。
- **頁面標籤（MODAL-WIRING (e)）**：`route.manage_system-settings`（選單標題、對齊 m002:251 i18n_key）＋`page.manage.systemSettings.*`（頁內標籤）。

## 9. frontend 頁（R2 Option A、static、MODAL-WIRING (e)）
- `views/manage/system-settings/index.vue`（新頁、elegant-router static 自動生 route `manage_system-settings`）：載 `fetchGetSystemSettings`→ render KV（by value_type：`enum:on,off`→NSwitch）；改值→`fetchUpdateSystemSetting`→ envelope toast（成功 `$t(common.updateSuccess)`／2222 經攔截器 `$t` 自動譯）。鏡像既有 manage 頁（user/role）service→fetch→toast 範式。
- **波1 static 模式**：頁可達、無前端 role-meta gating（API `require_policy` super-only 強制）；選單-Casbin-visibility（getUserRoutes）＋`.env` dynamic ＝波2（R2）。

## 10. `server/tests/endpoint_coverage_lint.rs`（新、⚠️x 波1 立、R6）
- 鏡像 `entity_access_lint` 只讀掃描；分類 main.rs 已註冊 route：public（/health、/auth/login）／auth-only（/auth/getUserInfo）／policy-governed（system_settings ×2）；斷言「policy-governed route 必有對應 casbin p-policy seed（m002 已 seed〔R1〕）」＋「registered == as-built registry」。**plan 定確切斷言碼**（避 fallback 4040 誤判）。

## 11. 排除聲明（OUT／MOOT、各歸其刀）
- **MOOT（已 done、不重做）**：m005 seed migration（m002 已 seed 端點 policy＋menu policy＋sys_menu 列、R1）／system_settings entity＋schema（m001/004）／audit_ctx RequestContext＋to_audit_operator（007）／enforce_role_path_method seam（006）／mutate_in_txn＋From<DbErr>（005/006）／envelope 13 碼（003）。
- **OUT（遞延）**：dynamic-menu（getUserRoutes＋`.env` dynamic、拍板#7）＝波2 Menu 刀（R2）／§5.6 redis pub-sub watcher＋session_mode 熱快取＋consumption＝波3／多 key keyed-map（⚠️l）／§5.8 分頁·filter·空字串守門首 exercise＝波2 User／DbErr 23505→2222（本刀不觸、波2 CRUD、R8）／soft-delete 操作（無刪除路徑、seam only）。
