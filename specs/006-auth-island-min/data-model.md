# Data Model: 006-auth-island-min

> 本刀＝**L5-L7 Auth 島最小段＋runtime 骨幹**。**無持久實體變更、無 migration**——`sys_user`/`sys_token`/`sys_role`/`sys_user_role`/`casbin_rule` 皆 002 凍結 schema。本檔定義 **auth 機制層型與接線**（config/state、JWT claims、auth 機制、facade 簽名、casbin model、wire DTO、data flow）；欄級權威＝m001／004 entity（不重抄、見 research.md R-A/R-D）。

## 1. runtime 骨幹（`config.rs` / `state.rs`）

### 1.1 `config.rs`（讀已 provisioned secret、R-F）
```rust
pub struct AppConfig {
    pub database_url: String,
    pub jwt_secret: String,            // access 簽署（APP_JWT_JWT_SECRET[_FILE]）
    pub refresh_token_secret: String,  // refresh 簽署（APP_JWT_REFRESH_TOKEN_SECRET[_FILE]）
}
```
- 讀法沿 `migration/src/main.rs`：env 直值 → `*_FILE`(讀檔 trim) → fallback；讀檔失敗 eprintln。
- 守門：每密鑰長度 ≥32、拒黑名單 `change-me*`（誤配 boot panic、不 silent）。

### 1.2 `state.rs`（AppState、無 Redis）
```rust
#[derive(Clone)]
pub struct AppState {
    pub db: sea_orm::DatabaseConnection,
    pub jwt: JwtConfig,                       // { access_secret, refresh_secret, access_ttl, refresh_ttl, iss, aud }
    pub enforcer: std::sync::Arc<tokio::sync::RwLock<casbin::Enforcer>>,
}
```
- boot（`main.rs`）：`Database::connect(cfg.database_url)` → `SeaOrmAdapter::new(db.clone())`（idempotent up、casbin_rule 已存 no-op）→ `Enforcer::new(DefaultModel::from_str(MODEL_CONF), adapter)` → `enforcer.load_policy()` → 入 `Arc<RwLock<_>>`。
- **無 Redis**（single-session DB-only、pub/sub＝波3）。

## 2. JWT（`auth/jwt.rs`、HS256、R-B）

### 2.1 Claims
```rust
#[derive(Serialize, Deserialize)]
pub struct Claims {
    pub uid: i64,            // user id（驗章後 resolve；wire userId=string、claims 內部 i64）
    pub sid: String,         // session id（single-session pointer 比對、uuid）
    pub jti: String,         // per-token uuid（§4.1 forward-compat、同秒去重）
    pub rotation_chain: String, // 換發鏈（§4.1 forward-compat）
    pub roles: Vec<String>,  // hint only（enforce/getUserInfo 一律 DB-fresh、見 §I.7 紀律）
    pub iss: String,
    pub aud: String,
    pub exp: i64,
    pub iat: i64,
}
```
- access（短 TTL、`jwt_secret` 簽）＋refresh（長 TTL、`refresh_token_secret` 簽）。`sign`/`verify`（exp/aud/iss 驗）。
- verify 失敗（缺/壞簽/exp/aud）→ caller 映 **3333**（TokenExpired、fail-CLOSED）。

## 3. auth 機制（`auth/password.rs`、`auth/bearer.rs`、`auth/enforce.rs`）

| 檔 | 介面 | 說明 |
|---|---|---|
| `password.rs` | `verify(input: &str, phc: &str) -> bool` | `argon2` 0.5.3：`PasswordHash::new(phc)`＋`Argon2::default().verify_password`（對 m002 PHC `$argon2id$...`、R-A） |
| `bearer.rs` | extract `Authorization: Bearer <jwt>` → `jwt::verify` → `Claims`；缺/壞 → 3333 | axum extractor/helper；access 密鑰驗 |
| `enforce.rs` | `MODEL_CONF: &str`（embedded 3-tuple RBAC）＋`enforce_mw`（middleware）＋`is_current` | 見 §5/§6 |

### 3.1 Casbin model（embedded `from_str`、R-C）
```
[request_definition] r = sub, obj, act
[policy_definition]  p = sub, obj, act
[role_definition]    g = _, _
[policy_effect]      e = some(where (p.eft == allow))
[matchers]           m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```
- `casbin_rule` 政策：v0=role／v1=obj（endpoint path／menu route／button code）／v2=act（**HTTP method** GET/POST/DELETE｜`'menu'`｜`'button'`）／v3-v5 空。
- enforce_mw：user roles 聯集、任一 `enforce((role, path, method))==true` → allow；全 false → 5003。
- buttons（getUserInfo）：對 user roles `get_filtered_policy` 篩 `v2=="button"` 取 v1、去重。

## 4. facade（`model/facade/`、entity:: 合法、回 raw Model）

| facade | fn | 說明 |
|---|---|---|
| `sys_user.rs`（加） | `find_by_user_name(db, name) -> Result<Option<Model>, DbErr>` | login 取帳號（活躍、未軟刪 `deleted_at IS NULL`）|
| `sys_user.rs`（加） | `set_pointer(txn, uid, sid) -> Result<(), DbErr>` | UPDATE `current_session_id=sid`（plain txn、與 token insert 原子）|
| `sys_user.rs`（加） | `current_session_id_of(db, uid) -> Result<Option<String>, DbErr>` | is_current gate 讀 pointer（DB-truth、fail-OPEN：Err→放行）|
| `sys_user_role.rs`（新） | `roles_of_user(db, uid) -> Result<Vec<String>, DbErr>` | join `sys_user_role⋈sys_role` 取 `code[]`（DB-fresh role）|
| `sys_token.rs`（新、archetype C） | `insert_token(txn, user_id, token_hash, rotation_chain, issued_at, expires_at) -> Result<(), DbErr>` | INSERT（status="active"、used_at=Set(None)；id/created_at DB 生成）。**無 rotate/find_by_hash**（波3）|

> facade import 沿 005 lint-safe 慣例（`entity::` 在 facade 合法；非 facade 層〔auth/handler/config/state〕零 path-root `entity::`、守 `entity_access_lint`）。

## 5. data flow — `POST /auth/login`
```
1. find_by_user_name(name) → None/查無 → AppError::LoginFailed(1000)
2. password::verify(input, model.password) → false → LoginFailed(1000)   // 與 1 不可區分、不洩帳號存在
3. roles_of_user(uid) → Vec<role code>
4. sid/jti/rotation_chain = uuid; now = Utc::now()
   access = jwt::sign(Claims{uid,sid,jti,rotation_chain,roles,exp=now+access_ttl,..}, jwt_secret)
   refresh = jwt::sign(Claims{..exp=now+refresh_ttl}, refresh_token_secret)
5. token_hash = sha256(refresh)
   db.transaction:  set_pointer(txn, uid, sid)  +  insert_token(txn, uid, token_hash, rotation_chain, now, now+refresh_ttl)  → commit  // 原子（plain txn、非 op-log）
6. Res::ok(LoginToken{ token: access, refreshToken: refresh })
```

## 6. data flow — `GET /auth/getUserInfo`（protected）
```
enforce_mw 前置（bearer verify → is_current）後：
1. roles = roles_of_user(claims.uid)            // DB-fresh
2. buttons = enforcer.get_filtered_policy(...) 篩 v2='button' 取 v1（對 roles 聯集去重）
3. model = find_by_id(claims.uid)               // userName=nick_name（User→User01 alias 自然）
4. Res::ok(UserInfo{ userId: model.id.to_string(), userName: model.nick_name.unwrap_or(model.user_name), roles, buttons })
```

## 7. data flow — `enforce_mw`（通用 gate、§5.5 spec）
```
1. bearer::verify → Err → AppError::TokenExpired(3333)            // fail-CLOSED
2. is_current: current_session_id_of(uid) == claims.sid ?
     Err（DB 抖動）→ 放行（fail-OPEN）
     Some(p) && p != sid → AppError::ModalLogout(7777)
3. （policy-governed route）roles = roles_of_user(uid); 任一 enforce((role, path, method))==true → allow; 全 false → AppError::PermissionDenied(5003, HTTP 403)
   （auth-only route 如 getUserInfo：跳過 step 3 policy 檢查、僅 1+2）
4. allow → 放行
```

## 8. wire DTO（§I.1/§I.3 權威、R-E）
```rust
// 對齊 base-web typings/api/auth.d.ts
struct LoginToken { token: String, refresh_token: String }       // serde rename camelCase: refreshToken
struct UserInfo { user_id: String, user_name: String, roles: Vec<String>, buttons: Vec<String> }  // camelCase; userId=string（i64→string、2^53 守衛）
```
- envelope `Res<T>`（003 既有）：`{data, code:"0000", msg:"common.success"}`；錯誤經 `AppError`→`IntoResponse`（碼/http 既有）。

## 9. 排除聲明（OUT、各歸其刀）
- **波3 Auth/Token/Session 合刀**：`/auth/refreshToken` 端點＋rotation chain＋reuse 偵測＋`decide_rotation`＋grace＋`used_at`/`status` 轉移＋cleanup-job＋session_policy 三態×runtime session_mode。
- **波2 Menu 刀**：`/route/getUserRoutes`＋menu enforce＋`VITE_AUTH_ROUTE_MODE` flip。
- **007 overlay**：login 事件審計（access-log/login-attempt）＋audit_ctx＋xdb＋op-log `operator_ip` 回填。
- **Redis**：session cache＋policy pub/sub（波3）。
- login 寫**不**經 005 op-log（plain txn、事件審計＝007）；refresh 字串本刀簽發但無消費端點。
