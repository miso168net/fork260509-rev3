# 006-auth-island-min — Phase 0 Brainstorm（spec-design）

> 波 0 第六刀（001 infra-deploy → 002 rev2-schema-baseline → 003 envelope → 004 soft-delete-infra → 005 audit-op-log → **006 auth-island-min**）。
> 對應 rev2 013「Auth 島最小段」。本檔為 brainstorm 定稿的 spec-design，作為 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §1.5 L5/L7（auth domain primitive＋enforce_mw＋bearer helper 分層）＋§5.3（per-route enforce、subject＝DB-fresh role code、三欄精確相等）＋§8.3（Auth 島最小段＝login+enforce_mw 為各刀共同前提）＋波 0 出口「login→getUserInfo→enforce 最小鏈 curl 通」＋⚠️g（rust-api 全新寫、rev2 受控參照讀允許拷貝禁止）＋⚠️r（id 逐欄忠實 typings、2^53 fail-loud）＋wire 權威（base-web `typings/api/auth.d.ts`）＋003 §3.6（首個 envelope handler 刀必含 CDP）。本檔不得與之衝突（衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔）。

---

## 0. 刀界決策前情（合刀 → 兩 feature 緊接序列）

波 0 剩餘（第二 audit 刀＋Auth 島最小段）的寫入端深度糾纏：access-log 的寫入端＝`audit_ctx` 中介層（需 bearer verify 取 operator_id）、login-attempt 的寫入端＝login handler——兩者都住在 Auth 島；而 audit sink（entity+facade+xdb）又是 Auth 島會消費的基建。

紮根後關鍵發現：**auth-min 本身不依賴 audit sink**（login/enforce/getUserInfo 自身端到端可驗；login-attempt/access-log 寫是 best-effort overlay）。故拍板**整包 auth+audit 拆為兩 feature 緊接序列、零 dead-infra**：

- **006 auth-island-min**（本刀）＝stateless auth-min，端到端可驗、收掉波 0 出口「login→getUserInfo→enforce curl 通」。
- **007 audit overlay**（緊接）＝2 entity（access-log/login-attempt）+ 2 append-only facade + xdb crate + audit_ctx 中介層 + INET 寫入（`ipnetwork`），消費 006 的 bearer/login handler。

對齊 DESIGN（013/015 本就分刀）；兩步各自可 review。

## 1. 目標一句話

把後端 **stateless 認證地基**一次立起：JWT（HS256 sign/verify）＋bearer 抽取/驗證＋`enforce_mw`（casbin 三維 per-route enforce）＋login/refreshToken/getUserInfo 三 handler＋`AppState`（db＋jwt secret＋enforcer 單例）——讓 base-web 能真的 `login→getUserInfo→（受保護端點）enforce` 跑通，且後續所有受保護寫端刀都站在「per-route enforce 就位」的前提上；**全程 stateless**（無 sys_token/session/redis），有狀態的 token rotation/single-session/session_mode 留波 3 行為島。

## 2. Context（探索蒐集）

### 2.1 rev2 013 參考形（受控參照重寫、非照拷——⚠️g）
座標：`../fork260509-rev2/rust-api/server/src/`（讀允許、code 全新寫）。actual 結構（plan 期 research 須逐項 grep 校簽名）：
- **`auth/jwt.rs`**：`sign(...)→String` / `verify(token,secret,aud)→Result<Claims,_>`（HS256、leeway=0、驗 signature+exp+aud、iss 不驗）。rev2 `Claims` 含 `sid(028)/jti(030)`——**006 剝除 session 欄**、Claims 最小化為 `{user_id, roles, exp, iat, aud}`（+sub 視需要）。
- **`auth/bearer.rs`**：`bearer_token(headers)→Option<&str>`（case-sensitive `Bearer ` 前綴、trim、空＝None）／`verify_bearer(headers,secret,aud)→Option<Claims>`（組合、失敗 None、失敗策略交呼叫端）。
- **`auth/enforce.rs`**：`build_enforcer(db)→Result<Enforcer,casbin::Error>`（RBAC model＋SeaOrmAdapter、自動載 seeded policy）／`enforce_mw`（middleware）。rev2 enforce_mw 含 single-session(028) 7777 gate——**006 剝除**；最小＝bearer verify(None→3333) → **DB-fresh role lookup**（非信 JWT claims roles）→ enforce loop((role,path,method) 三欄精確相等、allow-override)→ 全 deny=403/5003、任一 allow=next。
- **`handler/auth.rs`**：`login`（argon2 verify user_name+password、停用 status gate、發 access+refresh pair）／`get_user_info`（bearer→user+roles+buttons）。rev2 login 含 sys_token/session pointer——**006 剝除**、純發 stateless JWT pair。`get_user_info` 的 `userName` ＝ `nick_name || user_name`（mock ground truth「User→User01」alias）。
- **`state.rs`**：`AppState{db, redis, jwt, enforcer: Arc<RwLock<Enforcer>>, session_mode(029)}`——**006 剝除 redis/session_mode**、AppState 最小＝`{db, jwt(access/refresh secret+ttl), enforcer}`。
- **router（main.rs flat-in-main）**：public（/auth/login、/auth/refreshToken、/auth/getUserInfo〔bearer-in-handler〕）＋enforce-gated（systemManage 等、屬波 1-2）。
- **`error.rs`**：rev2 handler `?` 傳播；006 須加 `From<DbErr>`＋`From<casbin::Error>` for `AppError`（003 §3.6 移交、首個需傳播外部錯誤的 handler 刀按需加）。

### 2.2 凍結權威
- **DESIGN §5.3**：`casbin_rule` 單表三維（v2＝HTTP method→endpoint / `'menu'`→可見 / `'button'`→按鈕）；RBAC model `r=p=sub,obj,act`（g 宣告未用、subject 直接 role code）、matcher 三欄精確相等無 glob、`R_SUPER` 逐端點列無 `*`；enforcer＝boot 單例 `Arc<RwLock<Enforcer>>` 無 cache、每請求對每 DB-fresh role 呼 `enforce`、watcher reload；**enforce_mw subject＝DB-fresh role code（非 JWT claims）**。menu 走 `enforce((role,name,'menu'))`、button 走 `get_filtered_policy`（讀已載 policy、非 enforce）。
- **DESIGN §8.3 共同前提**：Auth 島最小第一段（login + enforce_mw）先行——否則 §5.3 enforce 與 §5.2 operator_id 無從驗。本刀即此最小段（含 getUserInfo）。
- **波 0 出口條件**：「login→getUserInfo→enforce 最小鏈 curl 通」——本刀於 006 內以 enforce-proof route 達成。
- **wire 權威（base-web `typings/api/auth.d.ts`＋`service/api/auth.ts`）**：`LoginToken{token:string, refreshToken:string}`／`UserInfo{userId:string, userName:string, roles:string[], buttons:string[]}`；端點 `POST /auth/login {userName,password}`／`GET /auth/getUserInfo`／`POST /auth/refreshToken {refreshToken}`。**login 必回 token pair；refreshToken 端點存在**——故本刀 stateless 全 wire（見 §4 拍板）。
- **⚠️r**：id 逐欄忠實 typings——`userId` 為 string ⇒ getUserInfo 把 `user.id`(i64)→string＋2^53 fail-loud 守衛（003 §3.6 ⚠️r 首個落點）。
- **⚠️g**：rev2 source 受控參照（讀允許拷貝禁止）；auth 全新寫，rev2 僅作參照（同 003/004/005 形）。
- **003 §3.6 directed**：首個發出 envelope 的 handler 刀必含 CDP 經 front-nginx 驗 base-web 攔截器真讀 code/data/msg——006 即首個、含 CDP smoke。

### 2.3 rust-api 現況（005 後）
- workspace members＝`server`/`migration`/`sea-orm-adapter`/`entity`；002 已 vendored `sea-orm-adapter`（委派式 casbin adapter）＋m002/m004 seed casbin_rule（endpoint＋menu policy、全 R_SUPER ⚠️p）。
- server crate：`envelope.rs`/`error.rs`(003)＋`model/`(004 facade 三閘＋005 audit)；**無 `state.rs`/`auth/`/`handler/`**；deps **無 `jsonwebtoken`/`argon2`/`casbin`/`redis`**（argon2 0.5.3、casbin 2.20 已在 root workspace deps〔DESIGN line 118〕、jsonwebtoken 9 待加）；`main.rs` 僅 `/health` scaffold。
- **004 facade 可復用**：`find_active_by_name`（login 查 user）／`find_active_by_id`（getUserInfo 查 user）／`find_role_ids_by_user_id`＋`find_active_by_ids`（取 roles）。
- **secrets 已備**：`deploy/secrets/jwt_secret.txt`＋`refresh_token_secret.txt`（001 生成）⇒ 006 走 `_FILE` 讀。
- **button policy 未 seed**：m004 僅 `v2='menu'`、無 `v2='button'` ⇒ getUserInfo `buttons` 真查但現回 `[]`（誠實、波 3 Button 縱切後填）。

### 2.4 消費者（決定本刀面）
- **base-web 真消費**：pwd-login.vue→`/auth/login`、route guard→`/auth/getUserInfo`、攔截器→refreshToken。本刀為其首個真後端（取代 mock）。
- **enforce_mw 真消費者**＝波 1-2 systemManage 受保護端點（首個 gated 業務端點）。本刀 enforce_mw 為 infra-ahead（同 005 mutate_in_txn）＋一條 test/smoke-only proof route 釘死機制。
- **007 audit overlay 消費**：bearer（operator_id）＋login handler（login-attempt 寫點）。

## 3. Scope（拍板）

**本刀做（stateless auth-min + enforce 機制 + proof）：**
- `auth/jwt.rs`（HS256 sign/verify、Claims 最小〔無 sid/jti〕、access/refresh 兩 secret）。
- `auth/bearer.rs`（`bearer_token`＋`verify_bearer→Option<Claims>`）。
- `auth/enforce.rs`（`build_enforcer`〔casbin 2.20＋sea-orm-adapter〕＋`enforce_mw`〔bearer→DB-fresh role→enforce 三欄、**無 7777 gate**〕）。
- `handler/auth.rs`：`login`（argon2 verify＋停用 gate＋發 pair）／`refresh_token`（**stateless** 驗 refresh JWT→發新 pair）／`get_user_info`（user+roles+buttons、userId→string ⚠️r、userName＝nick_name‖user_name）。
- `state.rs`（`AppState{db, jwt, enforcer}`、jwt secret 走 `_FILE`、**無 redis/session_mode**）。
- `error.rs` ＋`From<DbErr>`＋`From<casbin::Error>`（§3.6）。
- `main.rs` boot（db→build_enforcer→讀 secrets→AppState）＋router（public 3 端＋/health；enforce-gated＝test/smoke-only proof route）。
- deps：＋`jsonwebtoken 9`／`argon2 0.5.3`／`casbin 2.20`／`sea-orm-adapter`(path)（**MSRV ≤ 1.86 驗**，§3.8 紀律）。
- 驗證（純測＋全棧 curl＋CDP smoke，見 §6）。

**Deferred（不在本刀）：**
- **波 3 Auth/Token/Session 合刀（rev2 026-030）**：`sys_token` rotation chain／reuse 偵測／single-session(028) 7777 gate／`current_session_id` pointer／redis session cache／`session_mode`(029)／settings_watcher／cleanup-job。本刀 stateless、Claims 無 sid/jti、enforce/getUserInfo 無 session gate。
- **007 audit overlay（rev2 015）**：access-log/login-attempt entity+facade＋audit_ctx 中介層＋xdb＋INET 寫入＋operator/trace 自動抽取。
- **波 2 Menu 刀（rev2 014/019-021）**：getUserRoutes/getConstantRoutes/isRouteExist＋DB-driven menu＋menu-dim enforce 過濾＋CDP 動態路由掛載驗證。
- **波 3 alt-login（⚠️m）**：reset-pwd/code-login/register/bind-wechat 4 流程 stub。
- **波 1 業務寫端**：systemManage CRUD（首個真 enforce-gated 端點）。

## 4. brainstorm 拍板

| # | 決策 | options | 結論 |
|---|---|---|---|
| 刀界/順序 | 合刀（Auth＋audit 一刀）／兩 feature 緊接序列／sink-only 先行 | 兩 feature 緊接序列（user 拍板） | **006 auth-min → 007 audit overlay 緊接序列**（auth-min 自身端到端可驗、零 dead-infra、對齊 DESIGN 013/015 分刀） |
| token/session 邊界 | stateless 全 wire／refresh 延波 3／拉有狀態 chain | stateless 全 wire（user 拍板） | **stateless 全 wire**：access+refresh 兩 stateless JWT＋stateless re-sign refresh；剝光 sys_token/rotation/reuse/single-session 7777/session_mode/redis（全波 3）；wire 完整無 type-lie |
| enforce 證明 | minimal enforce-proof route／只建機制延波 1／拉真 business 端點 | minimal enforce-proof route（user 拍板） | **test/smoke-only 最小受保護 proof route**：Super→200／無 policy role→403／bad token→3333；不污染 production router、不拉 business 端點、於 006 內收波 0 出口 |
| 驗證深度 | 純測＋全棧 curl＋CDP／CDP 延後／只直連 curl | 純測＋全棧 curl＋CDP（user 拍板） | **純測＋bounded 全棧 curl＋CDP browser smoke**（收 003 §3.6 directed）；CDP 驗到 getUserInfo+envelope 解析為止、route-mount 延波 2 |
| JWT secret 來源 | _FILE／直值 env | _FILE（secrets 已備） | **`_FILE`** 讀 `jwt_secret.txt`/`refresh_token_secret.txt`（同 003/004 secret 形；§3.4「_FILE vs env」就此定為 _FILE） |
| getUserInfo buttons | 真查／空 stub | 真查 | **真 casbin button-dim 查**（`get_filtered_policy((role,*,'button'))`）、現回 `[]`（button policy 波 3 seed；空＝誠實非 lie） |
| 新 crate / migration | — | — | **無 migration**（schema 全在 m001-m004）；**無新 workspace crate**（server 內加模組＋既有 sea-orm-adapter path dep）⇒ 非新 crate、但 deps 增量須跑 C-V build＋MSRV 驗 |

## 5. Design

### 5.1 架構洞察（守 DESIGN §1.5 分層）
- **三層職責**：`auth/jwt.rs`＋`auth/bearer.rs`＝L5 domain primitive（純、無 db）；`auth/enforce.rs::enforce_mw`＝L7 middleware（用 bearer helper＋db role lookup＋enforcer）；`handler/auth.rs`＝handler（回 `Res<T>` envelope）。`state.rs`＝L1 runtime-infra（AppState）。
- **enforce subject＝DB-fresh role**：enforce_mw 不信 JWT claims 的 roles、每請求重查 DB（`find_role_ids_by_user_id`），對每 role 呼 `enforce((role,path,method))`——freshness（policy/role 變更即時生效）。
- **stateless 是核心剝離**：JWT 自帶 user_id+roles（getUserInfo/login 用）、無 server-side session 查找；refresh＝純 JWT re-sign。這是與波 3（有狀態 rotation chain）的明確邊界、避免把 sys_token 機器拖進波 0。
- **enforcer 單例**：boot `build_enforcer(db)` 一次、`Arc<RwLock<Enforcer>>` 存 AppState、每請求 read lock。policy reload（watcher）屬波 3、本刀只建單例不建 watcher。

### 5.2 結構與檔案
- **新**：`server/src/auth/{mod,jwt,bearer,enforce}.rs`、`server/src/handler/{mod,auth}.rs`、`server/src/state.rs`。
- **改**：`server/src/main.rs`（boot＋router 重寫）、`server/src/error.rs`（+From impl）、`server/Cargo.toml`（+deps）、root `Cargo.toml`（+jsonwebtoken workspace dep）。
- **無 migration、無新 crate**。

### 5.3 簽名（actual 形交 plan 期 grep 校；本檔為形狀草案）
```rust
// auth/jwt.rs（L5 純）
pub struct Claims { pub user_id: i64, pub roles: Vec<String>, pub exp: usize, pub iat: usize, pub aud: String }
pub fn sign(user_id: i64, roles: &[String], secret: &str, ttl_secs: u64, aud: &str) -> Result<String, JwtError>;
pub fn verify(token: &str, secret: &str, aud: &str) -> Result<Claims, JwtError>;   // HS256, leeway=0, 驗 sig+exp+aud

// auth/bearer.rs（L5）
pub fn bearer_token(headers: &HeaderMap) -> Option<&str>;
pub fn verify_bearer(headers: &HeaderMap, secret: &str, aud: &str) -> Option<Claims>;

// auth/enforce.rs（L7）
pub async fn build_enforcer(db: DatabaseConnection) -> Result<Enforcer, casbin::Error>;
pub async fn enforce_mw(State(state): State<AppState>, req: Request, next: Next) -> Response;  // 無 7777 gate

// handler/auth.rs（回 envelope）
pub async fn login(State, Json<LoginReq{user_name,password}>) -> Res<LoginToken{token,refresh_token}>;
pub async fn refresh_token(State, Json<RefreshReq{refresh_token}>) -> Res<LoginToken>;          // stateless re-sign
pub async fn get_user_info(State, HeaderMap) -> Res<UserInfo{user_id:String,user_name,roles,buttons}>;
```
> wire camelCase（`userName`/`refreshToken`/`userId`）由 serde rename 對齊 typings；DTO 形 plan 期對 base-web typings 逐欄校（§I.3 wire 3 端對齊）。

### 5.4 enforce-proof route（test/smoke-only）
- 一條最小受保護 route（如 `GET /auth/enforce-check` 僅 test/smoke 配置掛載、或 `#[cfg(test)]`／smoke-gated），掛 `enforce_mw`。
- live smoke 斷言：Super token（有 policy）→ 200；無對應 policy 的 role token → 403（envelope PermissionDenied）；bad/expired token → 3333（TokenExpired）。
- 不留 production probe route（避免污染 router 與 endpoint_coverage_lint）。

### 5.5 驗證（ii＋CDP）
見 §6。

## 6. 驗證方向（交 /speckit-specify 形式化）

- **純 cargo test（test-first、零 DB/HTTP）**：
  - `jwt::sign`→`verify` roundtrip 取回 user_id/roles；竄改 signature→Err；過期 exp（leeway=0）→Err；wrong aud→Err。
  - `bearer::bearer_token`：`Bearer x`→Some("x")、無前綴/空/小寫 bearer→None、trim。
  - argon2 verify：對 m002 seed hash 驗 `123456`→true、錯密碼→false（用真實雜湊串測，非連 DB）。
  - enforce decision shape（可行則純測 enforce(model,policy) allow/deny；否則併 live smoke）。
- **bounded 全棧 curl**：起 front-nginx+base-web+rust-api+postgres+migrate；經 `/api` curl：`login`(Super/123456)→`Res{data:{token,refreshToken}}`；`getUserInfo`(bearer)→`Res{data:{userId,userName,roles,buttons}}`；enforce-proof route：Super→200、無 policy role→403、bad token→3333；`refreshToken`→新 pair。
- **CDP browser smoke（§3.6 directed）**：base-web pwd-login UI 提交→攔截器真讀 `login` envelope `code/data/msg`→存 token→`getUserInfo` envelope 解析。**驗到 getUserInfo+envelope 解析為止**；動態路由掛載需 getUserRoutes（波 2 Menu）→ 登 follow-up（不影響 §3.6「攔截器讀 envelope」目標）。
- **C-V build/MSRV**：容器 `cargo build --bins`／`cargo test -p server` 綠（+jsonwebtoken/argon2/casbin/sea-orm-adapter 編譯）；**新 deps 鎖定版 MSRV ≤ 1.86 驗**（§3.8）；`entity_access_lint` 續綠（auth/handler/state 不碰 raw entity、走 facade）。
- **殘留 grep**：auth/handler/state 內容零 rev2 token（以「前代」描述、⚠️g）。

## 7. Out of scope / Deferred / Backlog
- **波 3 Auth/Token/Session 合刀**：sys_token/rotation/reuse/single-session 7777/session pointer/session_mode/redis/cleanup-job/alt-login。
- **007 audit overlay**：access-log/login-attempt/audit_ctx/xdb/INET 寫入/operator-trace 自動抽取（消費本刀 bearer/login handler）。
- **波 2 Menu**：getUserRoutes/getConstantRoutes/isRouteExist/DB menu/menu-dim 過濾/CDP 動態路由掛載。
- **波 1 業務寫端**：systemManage CRUD（首個真 enforce-gated 端點，本刀 enforce_mw 的真消費者）。
- **§3.6 殘 follow-up**：CDP route-mount 段（待波 2 getUserRoutes）。

## 8. Phase 0 research 待辦（交 /speckit-plan 期 research.md；CLAUDE.md §3 三 grep 紀律）

- **rev2 013 actual 簽名逐項 grep**（受控參照、code 全新寫）：`auth/jwt.rs`(sign/verify/Claims 欄)／`auth/bearer.rs`／`auth/enforce.rs`(build_enforcer 的 model 字串＋adapter 用法＋enforce_mw 步驟)／`handler/auth.rs`(login argon2 用法＋停用 gate＋issue pair＋getUserInfo roles/buttons/userName alias)／`state.rs`(AppState 欄)／`main.rs`(router 掛法、enforce_mw route_layer、public vs gated)。**剝離線校**：明列哪些 rev2 段屬 session/token(028-030)＝本刀**不帶**。
- **wire 3 端對齊 grep**（§I.3）：對 login/getUserInfo/refreshToken／enforce-proof，同時 grep（a）rust handler return/DTO 型（serde rename camelCase）（b）base-web `service/api/auth.ts` inline 型＋`typings/api/auth.d.ts` 宣告型（c）base-web 攔截器（`service/request/index.ts`）對 envelope code/data/msg 的判讀（3333/7777 modal codes、success code）。
- **casbin/sea-orm-adapter actual grep**：`build_enforcer` 的 RBAC model 定義（r=p=sub,obj,act、g 未用）＋SeaOrmAdapter 載 policy 路徑＋casbin 2.20 API（Enforcer::new、enforce、get_filtered_policy）；確認 m002/m004 seeded policy（endpoint v2=method／menu v2='menu'）足以證 enforce。
- **argon2 seed hash grep**：m002 seed 的 argon2id hash 串（驗 `123456`）＋argon2 0.5.3 verify API（`Argon2::verify_password` / `PasswordHash`）。
- **依賴增量＋MSRV grep**：jsonwebtoken 9／argon2 0.5.3／casbin 2.20／sea-orm-adapter(path) 加入後 `cargo build` 綠；**新拉 crate 鎖定版 MSRV ≤ 1.86**（§3.8；jsonwebtoken 9 與其 ring/依賴鏈尤須驗）；確認不引入非預期重依賴。
- **DbErr→AppError／casbin::Error→AppError From 形**：對 003 `error.rs` 的 `AppError` 8 建構子，定 From impl 映射（DbErr→Internal(5000)？casbin::Error→Internal？登入特例→LoginFailed〔不經 From、handler 內顯式〕）。
- **enforce-proof route gating 形 grep**：確認 test/smoke-only route 的掛載方式（`#[cfg(test)]` mod router？或 smoke-feature gate？）不影響 production endpoint_coverage_lint〔波 0 後刀立〕。
- **CDP smoke 形 grep**：000 既有 CDP scripts（`tests/000-.../scripts/`）登入流程＋front-nginx `/api` 代理 conf；確認 base-web 指向真 rust-api（非 mock）的切換方式（`.env` `VITE_SERVICE_BASE_URL`/proxy）。

---

**brainstorm 定稿 2026-06-14；拍板（刀界＝006 auth-min→007 audit 兩 feature 緊接序列／token 邊界＝stateless 全 wire 剝光有狀態／enforce 證＝test-smoke-only proof route／驗證＝純測+全棧 curl+CDP/JWT secret＝_FILE／buttons 真查現空／無 migration 無新 crate）＋DESIGN §5.3 enforce ＋§8.3 共同前提 ＋⚠️g 全新寫 ＋⚠️r id-string ＋wire 權威 ＋003 §3.6 CDP。下一步：手動 `/speckit-specify`（input＝本檔；不自動觸發、否則 speckit.git.feature pre-hook 不跑）。**
