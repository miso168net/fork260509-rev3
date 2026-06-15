# Research: 006-auth-island-min（Phase 0）

**Date**: 2026-06-14 ｜ **Input**: spec.md＋brainstorm `docs/superpowers/006-auth-island-min.md`＋plan 期實 grep（rev2 013 受控參照 ⚠️g／base-web wire 權威／m001-m004 seed／rev3 003 error.rs／deps）

> CLAUDE.md §3 Phase 0 三 grep 紀律：① facade 真實返回型（R1/R3）② wire 3 端對齊（R2）③ data-model file:line 對照（R1-R7 已執行）。**所有 brainstorm 命名/簽名假設已對 actual code 校正**。NEEDS CLARIFICATION＝0。座標：rev2＝`../fork260509-rev2/rust-api/`、base-web＝`base-web/src/`、rev3＝本 repo。

## R1 · rev2 013 minimal-auth actual 簽名＋剝離線（⚠️g 讀允許、code 全新寫）

座標 `server/src/auth/{jwt,bearer,enforce,password}.rs`＋`handler/auth.rs`＋`state.rs`＋`main.rs`。

### R1.1 `jwt.rs`
- rev2：`sign(user_id:i64, roles:Vec<String>, secret:&str, ttl_secs:u64, iss:&str, aud:&str, session_id:&str)->Result<String,JwtError>`／`verify(token:&str, secret:&str, aud:&str)->Result<Claims,JwtError>`。HS256、**leeway=0**（覆寫 jsonwebtoken 預設 60s、deterministic exp）、驗 `exp`+`aud`、**`iss` 不驗**（資訊性）。
- rev2 `Claims{ sub, user_id:i64, roles:Vec<String>, exp:usize, iat:usize, iss:String, aud:String, sid:String〔028〕, jti:String〔030〕 }`。
- **006 剝離**：sign 去 `session_id` 參數；Claims 去 `sid`/`jti`（028/030 session-state＝波 3）。**006 Claims = `{ sub, user_id, roles, exp, iat, iss, aud }`**（保 iss 無害、仍不驗）。常數 `JWT_ISS="rev3-admin"`／`JWT_AUD="rev3-admin"`（rev2 為 "rev2-admin"、⚠️g 改）。
- **Decision**：006 `sign(user_id, roles, secret, ttl, iss, aud)->Result<String,JwtError>`（無 session_id）／`verify(token, secret, aud)->Result<Claims,JwtError>`。access/refresh 各自 secret＋ttl（見 R5）。

### R1.2 `bearer.rs`
- `bearer_token(headers:&HeaderMap)->Option<&str>`（`Bearer ` case-sensitive 前綴、trim、空→None）／`verify_bearer(headers, secret, aud)->Option<Claims>`（組合、失敗 None、失敗策略交呼叫端）。**006 原形沿用**（純、無狀態）。

### R1.3 `enforce.rs`
- `build_enforcer(db:DatabaseConnection)->Result<Enforcer,casbin::Error>` = `DefaultModel::from_str(MODEL)` + `SeaOrmAdapter::new(db)` + `Enforcer::new(model,adapter)`（自動載 seeded policy）。
- `enforce_mw(State<AppState>, req, next)->Response`：① `verify_bearer`→None→`AppError::token_expired()`（3333）② **〔剝〕`is_current`(028) 7777 gate**（波 3）③ `path=uri.path()`／`method`④ **DB-fresh roles**（`roles_for_user`、非 JWT claims；見 R3.2）⑤ enforce loop `enforcer.enforce((role,path,method))`、任一 allow→next、全 deny→`permission_denied()`（403/5003）。
- **DB-error 處置（⚠️ 見 R6 spec 校正）**：rev2／DESIGN §10.1：role-lookup DbErr→**fail-closed 5003**（非 3333、非 internal；安全預設：transient DB error 不得誤放行）、且 `tracing::error` log 區分。
- **006 剝離**：去 step ②（is_current）。

### R1.4 `handler/auth.rs`＋`password.rs`
- `login`：`find_active_by_name`→`Ok(None)`/`Err`→`login_failed`（不洩漏）→`verify_password(password,user.password)`（`PasswordHash::new(phc)`+`Argon2::default().verify_password`、見 R4）→`status==Some(2)`（停用）→`login_failed`→`roles_for_user`→`issue_tokens`（access+refresh、各自 secret/ttl）。**006 剝離**：去 `session_policy` 捕獲、`session_id`、sys_token 持久化。
- `get_user_info`：`verify_bearer`→**〔剝〕is_current(028)**→`find_active_by_id`→`user_name = nick_name.unwrap_or(user_name)`（User→User01 alias）→DB-fresh roles→buttons via casbin（R3.3）。失敗一律 `token_expired()`（3333、advisory 要求重認證）。
- **userId string（⚠️r）**：`UserInfo.userId` 型 string（base-web typings）；handler 將 `user.id:i64`→string＋**2^53 fail-loud 守衛**（超界 panic/error 而非靜默截斷；003 §3.6 ⚠️r 首個落點）。
- **Decision**：006 三 handler 採 rev2 形（剝 session）；錯誤**顯式語意映射**（login→login_failed／getUserInfo→token_expired／enforce→permission_denied）、非泛型 `?`（見 R6）。

### R1.5 `state.rs`＋`main.rs`
- rev2 `AppState{ db, redis, jwt:JwtConfig, enforcer:Arc<RwLock<Enforcer>>, session_mode〔029〕 }`。**006 剝離**：去 `redis`、`session_mode`。**006 `AppState{ db, jwt, enforcer }`**。`JwtConfig{ access_secret, access_ttl, refresh_secret, refresh_ttl, iss, aud }`（secret 走 _FILE、R5）。
- boot：`build_enforcer(db)`（panic by design）；`enforce_mw` 經 `axum::middleware::from_fn_with_state(state, enforce_mw)` 掛 **per-route route_layer**（非 global）。public：/health、/auth/login、/auth/refreshToken、/auth/getUserInfo。
- **Decision**：006 boot = db connect→build_enforcer→讀 jwt secrets→AppState；router public 3 端＋health＋**1 條 enforce-gated proof route**（R7）。

## R2 · wire 3 端對齊（§I.3、base-web 權威）

座標 `base-web/src/service/{request/index.ts, request/shared.ts, api/auth.ts}`＋`typings/api/auth.d.ts`＋`.env`。

- **envelope**：`{ data, code, msg }`、**`code` 為字串**；success 判定 `String(resp.data.code) === VITE_SERVICE_SUCCESS_CODE`、**success code = `"0000"`**（`.env`）。⇒ 006 成功回 `Res{ data, code:"0000", msg }`（003 envelope 已是此形）。
- **錯誤碼分類（`.env`、攔截器分支）**：modal logout `7777,7778`（彈窗踢人）／direct logout `8888,8889`／**expired token `9999,9998,3333`**（→ refresh-then-retry）。auth 用：未認證/失效→**3333**（token_expired、攔截器觸發 refresh）；權限不足→**5003**（不在上述清單、攔截器當一般 biz error）；他處登入→7777（波 3）。
- **⚠️ 反迴圈鐵律**：`/auth/refreshToken` **不得回 expired code（3333/9999/9998）**——否則攔截器 refresh 失敗又觸 refresh＝死循環；失敗須回 **`8888`(logout)**（mock 實證 8888 on bad refresh；官方 docs guide/request/usage.md 紀律）。⇒ **006 refresh handler：refresh JWT 失效→`logout()`(8888)、非 token_expired**。
- **Authorization**：`Bearer <token>`（localStorage `'token'`）。006 各受保護端點讀此 header。
- **typings（權威、逐欄對齊）**：`LoginToken{ token:string, refreshToken:string }`／`UserInfo{ userId:string, userName:string, roles:string[], buttons:string[] }`；req `POST /auth/login {userName,password}`／`POST /auth/refreshToken {refreshToken}`。⇒ 006 DTO serde rename camelCase（`user_name`↔`userName`、`refresh_token`↔`refreshToken`、`user_id`↔`userId`）。
- **Decision**：006 三端 DTO 逐欄對齊 typings；refresh 失敗→8888；userId string＋2^53 守衛。

## R3 · casbin 2.20 ＋ sea-orm-adapter ＋ seeded policy

- **MODEL（inline string、rev2 enforce.rs）**：`r=sub,obj,act`／`p=sub,obj,act`／`g=_,_`（宣告未用、subject 直接 role code）／`e=some(where p.eft==allow)`／`m=r.sub==p.sub && r.obj==p.obj && r.act==p.act`（三欄精確、無 glob）。006 原樣定義（DESIGN §5.3）。
- **R3.1 adapter**：rev3 vendored `sea-orm-adapter`（002）`SeaOrmAdapter::new(conn)->Result<Self>`（內跑 `migration::up`、冪等）。`build_enforcer` = `Enforcer::new(DefaultModel::from_str(MODEL).await?, SeaOrmAdapter::new(db).await?).await`。
- **R3.2 roles_for_user**：enforce/login/getUserInfo 需 user_id→**role code 清單**。004 facade 有 `find_role_ids_by_user_id`(sys_user_role)＋`find_active_by_ids`(sys_role)→`.code`。**006 加 helper** `sys_user_role::roles_for_user(db, user_id)->Result<Vec<String>,DbErr>`（組合二者取 active role codes）或於 handler 內組合。**Decision**：加 facade helper（消費 004 兩讀 fn、清 §3.7 dead_code）。
- **R3.3 buttons**：`enforcer.get_filtered_policy(0, vec![role,"".to_owned(),"button".to_owned()])->Vec<Vec<String>>`、取 `row[1]` 去重 union。**m004 未 seed `v2='button'`**（僅 endpoint v2=method＋menu v2='menu'、全 R_SUPER ⚠️p）⇒ **buttons 現回 `[]`**（誠實、波 3 Button 縱切 seed 後填）。
- **R3.4 seeded policy 足夠性**：m002/m004 seed endpoint policy（v2=HTTP method、35 systemManage 路徑、全 R_SUPER）＋menu。**enforce-proof route 的 policy**：proof route 為新路徑、seed **無**其 policy ⇒ 即使 Super 也 deny。**Decision**：enforce-proof **smoke 自行 seed** 一列 `('p','R_SUPER',<proof_path>,<method>)`（test 前插、後清）→ Super(有此 policy)→200、另一無此 policy 的 role→403；不污染基線 seed（見 R7）。
- **Decision**：build_enforcer 原形；buttons 真查現空；roles_for_user 加 helper；proof policy 由 smoke 注入。

## R4 · argon2 驗證（seed hash runtime 生成、純測 roundtrip）

- m002 seed 密碼雜湊為 **runtime 生成的 argon2id（random salt、每次 migration 不同字串、皆驗 `123456`）**（CLAUDE.md §8.1）⇒ **無固定 hash 字串可 grep**。
- `verify_password(password:&str, phc_hash:&str)->bool` = `PasswordHash::new(phc).and_then(|p| Argon2::default().verify_password(password.as_bytes(),&p)).is_ok()`；`hash_password(plain)->String`（`SaltString::generate(OsRng)`+`Argon2::default().hash_password`）。argon2 0.5.3。
- **Decision**：
  - **純測（test-first、零 DB）**：`hash_password("123456")`→`verify_password("123456",&h)==true`＋`verify_password("wrong",&h)==false`＋`verify_password("x","not-a-phc")==false`（roundtrip 自含、不依賴 seed 字串）。
  - **live smoke（真 DB）**：以實 seed user `Super`/`123456` login→成功（驗 runtime-seeded hash 真驗得過）。

## R5 · 依賴增量＋MSRV（§3.8 紀律）

- **加**：`jsonwebtoken = "9"`（root workspace deps＋server crate；rev2 用 "9"、rev3 lock **無**、006 新加）。`argon2 0.5.3`／`casbin 2.20`（已在 root workspace deps＋lock〔002/004〕、006 加進 **server crate** deps）。`sea-orm-adapter`（path dep、server crate 加；build_enforcer 用）。
- **MSRV（§3.8 地雷驗）**：`jsonwebtoken 9` MSRV ≈ 1.63；其依賴 `ring 0.17`（MSRV 1.61）／`serde`／`base64`——**全 ≤ 1.86**。casbin 2.20.0／argon2 0.5.3 已在 1.86 lock 編過。⇒ **新拉 crate（jsonwebtoken+ring 鏈）MSRV 安全、§3.8 疑慮解除**；C-V build 實證。
- **redis**：006 **不加**（stateless、無 session；rev2 的 redis 屬波 3 session cache）。
- **Decision**：deps 增 jsonwebtoken 9＋argon2/casbin/sea-orm-adapter（後三來自既有 workspace/path）；無 redis；C-V build 驗鏈＋MSRV。

## R6 · 錯誤映射（003 AppError）＋⚠️ spec FR-005 校正

- 003 `error.rs`：`AppError{code:BizCode(私), msg:Option<String>}`＋8 建構子（`login_failed`1000／`biz`2222／`token_expired`3333／`modal_logout`7777／`logout`8888／`not_found`4040／`permission_denied`5003／`internal`5000、Internal→HTTP200 ⚠️e／4 保留碼無建構子 ⚠️f）＋`IntoResponse`。
- **006 用法**：handler **顯式語意映射**（非泛型 `?`）：login 失敗→`login_failed()`；getUserInfo 任何問題→`token_expired()`（advisory）；enforce 全 deny→`permission_denied()`；refresh 失效→`logout()`(8888、反迴圈 R2)；token 缺/失效→`token_expired()`(3333)。
- **§3.6 From impl**：`From<DbErr>`／`From<casbin::Error>`→`AppError::internal(..)`（5000）作**泛型 fallback**（供未來 `?` 用、本刀 auth handler 多為顯式映射故消費少）；**enforce role-lookup DB error 不走 From**（顯式 fail-closed 5003、見下）。
- **⚠️ spec FR-005 校正（DESIGN＞spec）**：spec FR-005 寫「系統錯誤 MUST 與權限不足**可區分**」；但 **DESIGN §10.1 明示 role-lookup DbErr → fail-closed 5003（PermissionDenied 同碼）**——安全預設（transient DB error 不得誤放行）。⇒ 正解：**wire 層 DB error 與 permission-denied 同回 5003（fail-closed）、僅 log（`tracing::error`）區分**。FR-005「可區分」應讀為 **log/observability 層可區分、非 wire 層**。**留 `/speckit-analyze` 標此 spec↔DESIGN 差、建議 spec FR-005 措辭最小校正**（不阻塞 plan）。
- **Decision**：顯式語意映射為主；From→internal 為 fallback；DB-during-enforce fail-closed 5003（DESIGN 權威）、log 區分；FR-005 校正交 analyze。

## R7 · enforce-proof route gating 形 ＋ CDP smoke 形

- **proof route（test/smoke-only、不污染 production router／endpoint_coverage_lint）**：
  - 候選形：(a) `#[cfg(test)]` 限定的 router 組裝＋`tower::ServiceExt::oneshot` 直打（in-process、無需起 server）；(b) smoke-only：起 server 後 curl 一條 gated route（需 production router 含它）。**Decision 傾向 (a) in-process oneshot**——避免 production router 留 probe route（endpoint_coverage_lint〔後刀〕乾淨）；live smoke 另以真 DB 驗 enforce 對 seeded policy 的判定。
  - policy：smoke 前插 `casbin_rule('p','R_SUPER','/__enforce_check__','GET')`（拋棄式、後清）；Super token(具 R_SUPER＋此 policy)→200／無 R_SUPER 的合成 role token→403／bad token→3333。
- **CDP smoke（§3.6 directed）**：
  - 既有：`tests/000-base-web-docker-bootstrap/scripts/`（`cdp-login.mjs`/`cdp-clear-and-relogin.mjs`、CDP `ws://127.0.0.1:9229`）；登入＝點 quick-login 鈕→等 URL 變→驗 menu/username；gotchas：page-id 32-char、origin `localhost≠127.0.0.1`（localStorage 分立）、mock 限流。
  - **指向真 rust-api**：base-web `.env` `VITE_HTTP_PROXY` + `VITE_SERVICE_BASE_URL`（dev proxy `/proxy-default`→backend）；front-nginx `/api`→rust-api（prod）。006 CDP smoke 須讓 base-web 打真 rust-api（改 `.env`／smoke-專用 compose env、BASE-WEB-ADAPT L1 軌授權內）。
  - **static 模式天然成立**：base-web 現 `VITE_AUTH_ROUTE_MODE=static`→login→getUserInfo 後**不呼 getUserRoutes**⇒ CDP 驗到 getUserInfo+envelope 解析為止天然完整、無 getUserRoutes 404 困擾（dynamic 模式＝波 2）。
  - **Decision**：CDP 驗 base-web pwd-login→`/auth/login` envelope 攔截器解析→存 token→`/auth/getUserInfo` envelope 解析（static 模式止於此）；指向真 rust-api 經 `.env`／smoke env；route-mount 延波 2。

## 移交 plan/tasks 期紀律
- 波 3（Auth/Token/Session 合刀）：sys_token rotation/reuse/single-session 7777/session pointer/session_mode/redis/cleanup-job/alt-login——006 全剝。
- 007（audit overlay）：消費 006 的 bearer（operator_id）＋login handler（login-attempt 寫點）。
- 波 2 Menu：getUserRoutes/getConstantRoutes/isRouteExist＋DB menu＋menu-dim 過濾＋CDP route-mount。
- 波 1：systemManage CRUD（enforce_mw 首個真 gated 端點；endpoint_coverage_lint 屆時立）。
- spec FR-005 校正（fail-closed 5003 vs 可區分）→ `/speckit-analyze` 處理。
