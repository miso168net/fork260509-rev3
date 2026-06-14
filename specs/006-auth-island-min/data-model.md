# Data Model — 006-auth-island-min

> **權威序聲明**：①base-web wire 契約（`base-web/src/typings/api/auth.d.ts`＋`service/api/auth.ts`）＝DTO 形**唯一權威**（欄名/型）＞②DESIGN §5.3（enforce model/主體即時角色）＋§1.5（分層）＞③rev2 013 參考形（受控參照讀允許拷貝禁止 ⚠️g）＞④本檔。implementer 寫 code 時逐項對照 R1/R2/R3 grep 座標、act on actual code、不得只抄本檔。
> **stateless 剝離線**：所有 session/token-state（sid/jti/session_id/session_policy/redis/session_mode/is_current）＝波 3、本刀**不帶**（R1）。

## 1. 型別總覽

| 型別 | 檔（新/改） | 職責 | 來源/座標 |
|---|---|---|---|
| `Claims`／`sign`／`verify`／`JwtError` | `server/src/auth/jwt.rs`（新） | HS256 JWT、純、無狀態 | rev2 jwt.rs（剝 sid/jti/session_id 重寫） |
| `bearer_token`／`verify_bearer` | `server/src/auth/bearer.rs`（新） | bearer 抽取＋驗證 helper | rev2 bearer.rs |
| `MODEL`／`build_enforcer`／`enforce_mw` | `server/src/auth/enforce.rs`（新） | casbin per-route 授權 | rev2 enforce.rs（剝 is_current） |
| `verify_password`／`hash_password` | `server/src/auth/password.rs`（新） | argon2 驗證/雜湊 | rev2 password.rs |
| `roles_for_user` | `server/src/model/facade/sys_user_role.rs`（004 既有、加 helper） | user_id→active role codes | 組合 004 兩讀 fn |
| `buttons_for_roles` | `server/src/auth/enforce.rs` 或 handler（新） | casbin button-dim 查 | rev2 button_auth.rs |
| `AppState`／`JwtConfig` | `server/src/state.rs`（新） | runtime state（db/jwt/enforcer） | rev2 state.rs（剝 redis/session_mode） |
| `login`／`refresh_token`／`get_user_info`＋DTO | `server/src/handler/auth.rs`（新） | 三 handler、回 envelope | rev2 handler/auth.rs（剝 session） |
| `From<DbErr>`／`From<casbin::Error>` for `AppError` | `server/src/error.rs`（003 既有、加 impl） | 泛型 fallback→internal | §3.6 移交 |

## 2. `auth/jwt.rs`（新、L5 純、無 `entity::`）

```rust
pub struct Claims {              // serde；無 sid/jti（028/030 剝）
    pub sub: String,             // user_id 字串形
    pub user_id: i64,
    pub roles: Vec<String>,      // 簽發當下快照（授權時不信此、enforce 重查 DB）
    pub exp: usize, pub iat: usize,
    pub iss: String, pub aud: String,
}
pub fn sign(user_id: i64, roles: &[String], secret: &str, ttl_secs: u64, iss: &str, aud: &str) -> Result<String, JwtError>;
pub fn verify(token: &str, secret: &str, aud: &str) -> Result<Claims, JwtError>;   // HS256, leeway=0, 驗 exp+aud, iss 不驗
```
- 常數 `JWT_ISS="rev3-admin"`／`JWT_AUD="rev3-admin"`（⚠️g 改 rev2 字樣）。
- import 僅 `jsonwebtoken`＋`serde`；零 `entity::`／零 DB。

## 3. `auth/bearer.rs`（新、L5）

```rust
pub fn bearer_token(headers: &HeaderMap) -> Option<&str>;                          // "Bearer " 前綴 case-sensitive、trim、空→None
pub fn verify_bearer(headers: &HeaderMap, secret: &str, aud: &str) -> Option<Claims>;  // bearer_token + jwt::verify、失敗 None
```

## 4. `auth/enforce.rs`（新、L7 middleware）

```rust
pub(crate) const MODEL: &str = /* r=p=sub,obj,act; g=_,_(未用); e=some allow; m=三欄精確相等 */;
pub async fn build_enforcer(db: DatabaseConnection) -> Result<Enforcer, casbin::Error>;
    // = Enforcer::new(DefaultModel::from_str(MODEL).await?, SeaOrmAdapter::new(db).await?).await
pub async fn enforce_mw(State(state): State<AppState>, req: Request, next: Next) -> Response;
```
- `enforce_mw` 流程（剝 is_current 028）：`verify_bearer`→None→`token_expired()`(3333) ／ `path=uri.path()`,`method` ／ **DB-fresh** `roles_for_user(db, claims.user_id)`→**Err→fail-closed `permission_denied()`(5003)＋log**（DESIGN line 686、R6） ／ `for role in roles { if enforcer.enforce((role,path,method))? {allow} }`→全 deny→`permission_denied()`(5003)、任一 allow→`next.run(req)`。
- enforcer：`Arc<RwLock<Enforcer>>`（AppState）、read lock per request、無 decision cache（DESIGN §5.3）。

## 5. `auth/password.rs`（新）

```rust
pub fn verify_password(password: &str, phc_hash: &str) -> bool;  // PasswordHash::new + Argon2::default().verify_password
pub fn hash_password(plain: &str) -> String;                     // SaltString::generate(OsRng) + Argon2::default().hash_password
```
- argon2 0.5.3；驗 m002 runtime-seeded hash（random salt、驗 `123456`、R4）。

## 6. `state.rs`（新、L1 runtime-infra、剝 redis/session_mode）

```rust
pub struct JwtConfig { pub access_secret: String, pub access_ttl: u64, pub refresh_secret: String, pub refresh_ttl: u64, pub iss: String, pub aud: String }
#[derive(Clone)]
pub struct AppState { pub db: DatabaseConnection, pub jwt: Arc<JwtConfig>, pub enforcer: Arc<RwLock<Enforcer>> }
```
- jwt secret 走 **`_FILE`**（讀 `deploy/secrets/jwt_secret.txt`＋`refresh_token_secret.txt`；同 003/004 secret 形）；ttl/iss/aud 自 env/config。
- boot（main.rs）：db connect→`build_enforcer(db)`（panic by design）→讀 secrets→`AppState`。

## 7. `handler/auth.rs`（新、回 envelope；DTO 逐欄對齊 base-web typings R2）

```rust
// DTO（serde rename camelCase 對齊 typings）
struct LoginReq   { user_name: String, password: String }          // {userName,password}
struct LoginToken { token: String, refresh_token: String }         // {token,refreshToken}
struct RefreshReq { refresh_token: String }                        // {refreshToken}
struct UserInfo   { user_id: String, user_name: String, roles: Vec<String>, buttons: Vec<String> }  // {userId(string!),userName,roles,buttons}

pub async fn login(State<AppState>, Json<LoginReq>) -> Response;          // 成功 Res<LoginToken>(0000)；敗 login_failed(1000)
pub async fn refresh_token(State<AppState>, Json<RefreshReq>) -> Response;// 成功 Res<LoginToken>；refresh 失效 logout(8888)〔反迴圈 R2、非 3333〕
pub async fn get_user_info(State<AppState>, HeaderMap) -> Response;       // 成功 Res<UserInfo>；失效 token_expired(3333)
```
- **login**：`find_active_by_name`→None/Err→`login_failed`／`verify_password`→false→`login_failed`／`status==Some(2)`→`login_failed`／`roles_for_user`→Err→`login_failed`／`issue_tokens`(access+refresh、各自 secret/ttl)→Err→`internal`。
- **refresh_token**：`verify(refresh_token, refresh_secret, aud)`→Err→**`logout()`(8888)**（R2 反迴圈鐵律）／成功→重發 access+refresh pair（stateless、無 reuse 偵測＝波 3）。
- **get_user_info**：`verify_bearer`(access)→None→`token_expired`／`find_active_by_id`→None/Err→`token_expired`／`user_name=nick_name.unwrap_or(user_name)`／DB-fresh roles→buttons（casbin button-dim、現 `[]`）／`user_id`：**`i64`→string＋2^53 fail-loud 守衛**（⚠️r、超界→`internal` 不靜默截斷）。

## 8. `roles_for_user` helper（`facade/sys_user_role.rs`、消費 004、清 §3.7 dead_code）

```rust
pub async fn roles_for_user(db: &DatabaseConnection, user_id: i64) -> Result<Vec<String>, DbErr>;
    // find_role_ids_by_user_id(db,user_id) → find_active_by_ids(db,&ids) → .map(|r| r.code)
```
- 復用 004 `find_role_ids_by_user_id`＋`find_active_by_ids`（清其 dead_code）；回 active role codes（casbin subject）。

## 9. `error.rs` From impl（003 既有、加；§3.6）

```rust
impl From<DbErr> for AppError { fn from(e) -> Self { AppError::internal(e.to_string()) } }          // 泛型 fallback→5000
impl From<casbin::Error> for AppError { fn from(e) -> Self { AppError::internal(e.to_string()) } }  // 同
```
- **泛型 fallback**（供未來 `?`）；auth handler 多顯式語意映射、消費少；enforce role-lookup DbErr **不走 From**（顯式 fail-closed 5003、R6）。

## 10. enforce-proof route（test/smoke-only、R7）

- 不入 production router（傾向 `#[cfg(test)]` 組裝 router＋`oneshot` in-process 打）；avoid endpoint_coverage_lint〔後刀〕污染。
- live：smoke 注入拋棄式 policy `('p','R_SUPER','/__enforce_check__','GET')`→Super→200／無 R_SUPER role→403／bad token→3333；測後清。

## 11. 結構保證（守恆）
- `auth/jwt.rs`／`auth/bearer.rs`：純、零 `entity::`、零 DB。
- `auth/enforce.rs`／`handler/auth.rs`：經 **facade**（`find_active_by_*`／`roles_for_user`）取 entity、**不碰 raw entity::**（`entity_access_lint` 續綠、004 守恆）。
- handler 回 `Res<T>`/`AppError`→envelope（003、FR-009）；不 re-export Entity。

## 12. 排除聲明（不在本刀）
- **波 3**：sys_token rotation/reuse／single-session 7777 gate＋is_current／current_session_id pointer／session_mode(029)／settings_watcher／redis session cache／cleanup-job／alt-login 4 流程。
- **007**：access-log/login-attempt entity+facade／audit_ctx 中介層／xdb／operator-trace 自動抽取（消費本刀 bearer/login）。
- **波 2 Menu**：getUserRoutes/getConstantRoutes/isRouteExist／DB menu／menu-dim enforce 過濾／CDP route-mount。
- **波 1**：systemManage CRUD（enforce_mw 首個真 gated 端點）／endpoint_coverage_lint。
- **migration**：無（schema＋policy 在 m001-m004）。
