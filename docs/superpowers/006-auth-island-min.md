# 006-auth-island-min — Phase 0 Brainstorm（spec-design）

> 波 0 第六刀（001 infra-deploy → 002 schema-baseline → 003 envelope → 004 soft-delete-infra → 005 audit-op-log → **006 auth-island-min**）。**波 0 出口最後一條**（`login→getUserInfo→enforce 最小鏈 curl 通`）的唯一達成刀；audit overlay（007）排其後。
> 對應前代 013「login＋getUserInfo＋enforce 最小鏈」。本檔為 brainstorm 定稿的 spec-design，作 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §8.3（兩案共同前提＝Auth 島最小第一段＝login＋enforce_mw）＋§4.1/§4.3（token rotation／single-session 行為島 invariant、**006 僅 first-mount、完整狀態機＝波3**）＋§5.3（Casbin enforce）＋§1.5 L5/L7（auth/enforce in-tree 層）＋§7.3（13 碼矩陣）＋§7.4（`/api` strip 前綴）＋**§I.1/§I.3（base-web 實碼＝wire 唯一權威）**＋§I.5（rust 全新寫、enforce 層 in-tree〔`server/src/auth/enforce.rs`〕、受控參照前代 source）＋§I.7（single-session invariant、006 forward-compat）＋拍板 #1（`Super/Admin/User`＋User→User01 alias）＋#7（dynamic route mode、**但 006 維持 static 至波2 Menu 刀**）。**衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（引用一律用穩定 §錨、不用揮發行號）。

---

## 1. 目標一句話

把後端「**runtime 骨幹＋Auth 島最小鏈**」一次立起：rust-api 至今仍是 001 空殼（無 `AppState`／DB／Redis／auth），006 是**第一個**接 config（DB URL＋JWT 密鑰）→ DB pool → `AppState` → Casbin `Enforcer` → bootstrap 的刀，並在其上接 `POST /auth/login`（argon2id verify＋簽 JWT＋建 single-session pointer）／`GET /auth/getUserInfo`（DB-fresh roles＋真 buttons）／`enforce_mw`（bearer→DB-fresh role→is_current→Casbin enforce）——讓 base-web 能真的登入、且波 0 出口最後一條（login→getUserInfo→enforce curl 通）達成。完整 token rotation／refresh／session 熱切換／cleanup-job 隨**波 3 合刀**；動態選單／getUserRoutes 隨**波 2 Menu 刀**。

## 2. Context（探索蒐集）

### 2.1 前代 013 參考形（受控參照重寫、非照拷——§I.5／⚠️g）
- 前代 013＝rust-api 首個 auth 段：JWT 簽驗（HS256、claims `{uid, sid, jti, roles, iss, aud, exp}`）＋argon2id verify＋`enforce_mw`（Casbin per-route）＋getUserInfo（DB-fresh role join）。
- **auth/enforce 層全新寫**（§I.5 例外清單唯 `sea-orm-adapter`／`xdb`；auth 不在內）→ 前代僅作設計參照（讀允許、拷貝禁止、防回歸：不帶回前代已被 ⚠️r/⚠️e 推翻的行為）。
- `sea-orm-adapter`（002 拷入的 vendored crate）＝Casbin 的 DB adapter，006 為**首個消費者**（init `Enforcer` 自 `casbin_rule` 載 policy）。

### 2.2 凍結權威
- **DESIGN §8.3 兩案共同前提**：兩交付案皆須先有「跨切地基（infra/envelope/soft-delete/audit）＋ **Auth 島最小第一段（login＋enforce_mw）**」——缺後者無法驗 §5.3 enforce 與 §5.2 operator_id。⇒ 006＝此「最小第一段」。
- **DESIGN §4.1 token rotation chain**：`token_hash` UNIQUE／per-token `jti`／`rotation_chain`（每 login 一 uuid、整鏈共用）／reuse 偵測撤鏈／`decide_rotation` 純函式／grace 30s。**006 僅 forward-compat**（login 建 `rotation_chain`＋寫 `sys_token`、**不**實作 rotate/reuse 邏輯、不填 `used_at`、不寫 `status` 轉移）。
- **DESIGN §4.3 single-session lifecycle**：pointer 真相在 DB（`sys_user.current_session_id`）、Redis 僅快取（persist-then-cache、可失憶 lazy rehydrate）；`is_current` **fail-OPEN**（backing-store 抖動不誤踢）；`set_pointer` 永遠執行；`session_policy`∈{inherit,on,off} × runtime `session_mode`；7777＝pointer 比對失敗、8888＝refresh 鏈撤/驗章失敗。**006 first-mount**＝login `set_pointer`＋access gate 掛 `is_current`（7777）；**session_policy 三態 × runtime session_mode 的可設定層＝波3**（見 §4 拍板 single-session）。
- **DESIGN §5.3 enforce**：menu／endpoint／button 三維 Casbin enforce；`enforce(role, obj, act)`、`v2` 維度（`menu`/`endpoint`/`button`）。**006**＝建 `enforce_mw` 通用 gate＋getUserInfo 的 buttons 查（`v2='button'`）；menu enforce（getUserRoutes）＝波2。
- **DESIGN §7.3 13 碼矩陣**：006 發 `0000`（成功）／`1000`（login 全失敗 collapse、msg key `auth.login.failed`）／`3333`（bearer verify 失敗：簽章/exp/aud）／`7777`（is_current 失敗）／`5003`（enforce deny、HTTP 403）／`5000`（DB/簽章 internal、⚠️e→HTTP 200 信封）。**禁發**：`3333/9999/9998` 不得出現於 refresh 端（006 無 refresh）；`8888` 僅 refresh rotate reuse/notfound（006 無）。
- **DESIGN §7.4**：front-nginx strip `/api`：對外 `/api/auth/login` → 容器內 `/auth/login`；006 router 登記**無 `/api` 前綴**的 `/auth/*`。
- **§I.1/§I.3 wire 權威**：base-web 實碼（`service/api/auth.ts`＋`typings/api/auth.d.ts`）＝唯一權威；envelope `{data,code,msg}`、`code` string、business error HTTP 200；**id 逐欄忠實 typings（⚠️r）**：`UserInfo.userId`＝**string**（DB i64、序列化邊界轉）。
- **§I.5**：rust 全新寫、enforce 層 in-tree（`server/src/auth/enforce.rs`、非獨立 crate）。
- **§I.7**：single-session invariant 凍結；006 守方向性（fail-OPEN／7777／pointer-truth／set_pointer 永遠執行），forward-compat（見 §4／§7）。
- **拍板 #1**：預設帳號 `Super/Admin/User`（login req）＋ getUserInfo response `User→User01` alias（⚠️c 模仿 mock）。
- **§3.4／§3.6／§3.7／§3.8（CHECKLIST follow-up，006 觸發）**：JWT `_FILE` vs env 優先序拍板／login 失敗 1000 i18n 端到端 CDP 首檢核／**time-pin landmine**（jsonwebtoken→simple_asn1 把 time 拉進真 graph）／`From<DbErr> for AppError`（006＝首個 handler 消費 facade）。

### 2.3 rust-api 現況（rev3 005 後——親驗）
- **`server/src/main.rs` 仍是 001 最小 scaffold**（親讀）：僅 `GET /health`＋`fallback(handler_404)`；檔頭明寫「本刀無 config / DB / redis / auth（YAGNI）」。**無 `AppState`、無 DB pool、無 Redis、無 config 讀取** ⇒ 006 是 runtime 骨幹第一刀。
- mods＝`envelope`／`error`／`model`。003 `error.rs` 有 `AppError`（9 變體凍結 13 碼）＋`Res`/`PageRes`；006 加 `From<DbErr>` 與 login/token-verify 相關碼路徑（1000/3333/7777）。
- 004：`entity` crate（11 模組、含 `sys_token`/`sys_user`/`sys_role`/`sys_user_role`/`casbin_rule`）＋`model/facade/`（`SoftDeletable`＋3 impl）＋`entity_access_lint`（facade 唯一管道守恆）。
- 005：`model/audit.rs`（`mutate_in_txn`）＋`facade/sys_operation_log.rs`（op-log sink）＋`sys_user::soft_delete` proof。**006 login 不消費 005 op-log**（login 非 operator-attributed 業務 mutation；見 §4）。
- `server` deps：`axum`/`serde`/`serde_json`/`tokio`/`tracing`/`sea-orm`/`entity`。**無 chrono 直接 dep**（now 走 `sea_orm::sqlx::types::chrono::Utc::now()`〔sea-orm re-export sqlx、sqlx-core re-export chrono::Utc；不改 Cargo.toml〕）。006 **加 dep**（非新 crate）：`jsonwebtoken`／`argon2`／`uuid`／`casbin`／`sea-orm-adapter`(path)。

### 2.4 base-web wire 現況（§I.1 權威——親驗）
- **`service/api/auth.ts`**：`fetchLogin(userName,password)` → `POST /auth/login` data `{userName,password}` 回 `Api.Auth.LoginToken`；`fetchGetUserInfo()` → `GET /auth/getUserInfo` 回 `Api.Auth.UserInfo`；`fetchRefreshToken(refreshToken)` → `POST /auth/refreshToken`（**006 不實作端點、但 login 仍簽發 refreshToken 字串**）；`fetchCustomBackendError` → `/auth/error`（⚠️c echo、隨 captcha 完整包、非 006 必須）。
- **`typings/api/auth.d.ts`**：`LoginToken{ token:string; refreshToken:string }`；`UserInfo{ userId:string; userName:string; roles:string[]; buttons:string[] }`（userId＝string〔⚠️r〕、roles＝role code、buttons＝button code 如 `"user:edit"`）。
- **login store 流程**（`store/modules/auth`）：`fetchLogin` → `loginByToken`（存 localStorage `SOY_token`/`SOY_refreshToken` + 內含 `fetchGetUserInfo`）→ redirect。**static route mode 下不呼叫 getUserRoutes**。
- **`.env`**：`VITE_AUTH_ROUTE_MODE=static`（拍板 #7 目標 dynamic、但 flip＋getUserRoutes＝波2 Menu 刀）；`VITE_STORAGE_PREFIX=SOY_`；`.env.test.local` `VITE_SERVICE_BASE_URL=http://rust-api:31081`。
- **refreshToken 攔截器**：rev3 尚未接（003 僅接 i18n 譯點）⇒ 006 不做 refresh 無 caller、token 過期 → 下一請求 3333 → base-web 重登（可接受）。

### 2.5 schema 現況（002 建齊、本刀不動）
- **`sys_user`**：`id` i64／`user_name` UNIQUE／`password`（argon2id hash、m002 seed）／`current_session_id` Option\<String\>（§4.3 pointer）／`session_policy` String／審計 6 欄。
- **`sys_token`**（archetype C、§4.1）：`id`／`user_id`／`token_hash` UNIQUE／`rotation_chain`／`status`／`issued_at`／`expires_at`／`used_at` Option／`created_at`。**006 login INSERT**（status=active、rotation_chain=新 uuid、used_at=NULL）、**不**做 rotate/reuse（波3）。
- **`sys_user_role`**（join、硬刪零審計）／**`sys_role`**（`code`＝`R_SUPER`/`R_ADMIN`/`R_USER_COMMON`）：getUserInfo roles 來源。
- **`casbin_rule`**（vendored adapter 建）：政策來源；m002/m004 seed 有 **button policies**（`v2='button'`、R_SUPER 12 筆）⇒ getUserInfo buttons **真查、非 stub**（前代研究「buttons 現空」假設已被實 seed 推翻）。
- **無 migration、無 schema 變動**（002 已建齊）。

### 2.6 消費者
- **直接**：base-web login 流程（login→getUserInfo）＋波 0 出口 curl 鏈。
- **下游復用**：`enforce_mw`／`bearer`／`AppState`／Casbin enforcer＝波 2+ 所有業務端點的地基；`facade/sys_role`/`sys_token` 隨後續刀復用。

## 3. Scope（拍板）

**本刀做（runtime 骨幹＋auth 最小鏈；§I.5 in-tree、無新 crate）：**
- **config／state／bootstrap**：`config.rs`（DB URL＋JWT 密鑰，`_FILE` 優先 env fallback）／`state.rs`（`AppState{ db, jwt, enforcer }`、**無 Redis**）／`main.rs` build state＋mount routes＋enforce layer＋boot init Casbin enforcer（自 `casbin_rule` 載）。
- **`POST /auth/login`**（public）：argon2id verify（對 m002 hash）→ 查 roles → 簽 JWT access＋refresh（claims 含 `sid`/`jti`/`rotation_chain`）→ `set_pointer`（`current_session_id=sid`）＋INSERT `sys_token`（plain txn 原子、**非** op-log）→ 回 `{token, refreshToken}`；全失敗 collapse → 1000（`auth.login.failed`）。
- **`GET /auth/getUserInfo`**（protected）：bearer verify → is_current → DB-fresh roles（`sys_user_role⋈sys_role`）＋真 buttons（Casbin `v2='button'`）→ `{userId:string, userName(User→User01 alias), roles[], buttons[]}`。
- **`enforce_mw`**（`auth/enforce.rs`）：通用 gate＝bearer verify → resolve user → DB-fresh role → is_current → Casbin `enforce`；006 掛 getUserInfo 證 allow，deny 路徑由測證（壞 token→3333、無權→5003）。
- **single-session first-mount**：login `set_pointer`＋access gate `is_current`（DB-truth、fail-OPEN、7777）；無條件跑 gate（不 bake session_mode 變數）。
- **`From<DbErr> for AppError`**（§3.6/§3.8）→ DbErr→5000。

**Deferred（各歸其刀、皆 forward-compatible）：**
- **波 3 Auth/Token/Session 合刀**：`/auth/refreshToken`＋rotation chain＋reuse 偵測＋`decide_rotation`＋grace＋`used_at`/`status` 轉移＋cleanup-job（L8 binary）＋session_policy 三態 × runtime `session_mode` 熱切換。
- **波 2 Menu 刀**：`/route/getUserRoutes`＋動態選單＋menu Casbin enforce＋`VITE_AUTH_ROUTE_MODE` flip dynamic。
- **007 overlay**：login 事件審計（`sys_access_log`/`sys_login_attempt`）＋`audit_ctx` 中介層＋xdb＋trusted-proxy XFF＋op-log `operator_ip` 回填。
- **Redis**：session cache（persist-then-cache）＋policy pub/sub invalidate（波3 policy governance）——006 single-session 走 DB-only。
- **排程**：alt-login/captcha stub（⚠️m）／login lockout（⚠️w、消費 007 的 `sys_login_attempt`）。
- **migration／新 crate**：全無（dep 變動有、見 §7）。

## 4. brainstorm 拍板

| # | 決策 | 結論 | 理由 |
|---|---|---|---|
| 刀界 scope | backbone+auth-min（A）vs 拆 backbone/auth（B） | **A：runtime 骨幹＋login/getUserInfo/enforce_mw 一刀** | backbone 由 auth 需求驅動；拆開＝建無消費者的 pool＝人造邊界 |
| **single-session（user 拍板）** | 建 pointer＋is_current gate／只寫 pointer／全延波3 | **建 pointer＋is_current gate**（DB-truth、Redis 後補、fail-OPEN、7777） | DESIGN §8.3 first-mount；真單一登入體驗；波3 只接 rotation、不 retrofit gate |
| session_mode 來源 | 靜態 ON／讀 system_settings／三態機 | **006 無條件跑 is_current gate、不 bake session_mode 變數** | §I.7 方向性 invariant 全守（fail-OPEN/7777/pointer-truth）；三態 × runtime mode 可設定層＝波3 在 006 gate 之上加 gating＝forward-compat、非違反 |
| **refresh（user 拍板）** | 延波3／最小 reissue | **延波3**（006 不做 `/auth/refreshToken`、login 仍簽 refreshToken 字串） | base-web 攔截器 rev3 未接、無 caller；DESIGN refresh rotation＝波3；006 不背 rotation 包袱 |
| **JWT 密鑰來源（user 拍板、§3.4）** | `_FILE` 優先／env 優先 | **`_FILE` 優先、env fallback** | 對齊既有 compose secrets 慣例（`database_url`/`redis_password` 皆 `_FILE`→docker secret）；密鑰不落 env |
| Redis | 接／後補 | **後補**（006 DB-only single-session） | 快取可後補（user 認可）；pub/sub＝波3 policy governance；減 006 backbone 面 |
| token 形 | JWT HS256／opaque+sys_token | **JWT HS256**（claims `{uid,sid,jti,rotation_chain,roles?,iss,aud,exp,iat}`；`sys_token` 存 hash＋chain forward-compat） | 對齊 base-web localStorage bearer wire＋前代 013；roles 入 claims 但 enforce 一律 DB-fresh（claims 僅 hint） |
| login 審計 | op-log（005）／plain txn | **plain txn、不進 op-log** | login 非 operator-attributed 業務 mutation；事件審計（誰幾時自哪 IP 登入）＝007 overlay 的 `sys_access_log`/`sys_login_attempt` |
| enforce 證明面 | 等波2 業務端點／getUserInfo+deny 測 | **getUserInfo（allow）＋deny 測（3333/5003）** | 波0 無業務端點；enforce_mw 機制本身可在最小面證；per-endpoint policy 矩陣＝波2+ |
| route mode | flip dynamic／維持 static | **維持 static** | dynamic+getUserRoutes+menu＝波2 Menu 刀；static 下 006 已足以登入 |
| getUserInfo buttons | stub 空／真查 Casbin | **真查（`v2='button'`）** | seed 確有 button policies（m002/m004、R_SUPER 12 筆）；base-web hasAuth 需真值；前代研究「buttons 現空」假設錯 |
| 驗證策略 | 純 test／+curl 鏈／+CDP | **純 test（JWT/argon2/enforce seam）＋curl 鏈＋CDP（1000 i18n toast）** | enforce/single-session compile 證不了；1000 i18n＝§3.6 端到端首檢核 |

## 5. Design

### 5.1 架構洞察
- **runtime 骨幹第一刀**：006 之前 rust-api 無狀態（純 `/health`）。006 立 `AppState{ db, jwt, enforcer }`＋config 讀取＋boot init enforcer，是後續所有有狀態端點的地基；此地基由 auth 的真實需求驅動（非預先抽象）。
- **三層職責**（守 §I.5）：`auth/`＝JWT/argon2/bearer/enforce 機制（純、可單測 seam）；`handler/auth.rs`＝端點編排（呼 facade＋auth 機制＋組 envelope）；`model/facade/`＝entity 存取唯一閘（roles join／token insert／pointer 寫、entity:: 在 facade 合法）。
- **enforce 一律 DB-fresh role**：claims 的 roles 僅 hint；`enforce_mw`／getUserInfo 一律即時查 `sys_user_role`（§5.3 DB-fresh、避免 token 內角色過期）。
- **原子但不審計的 login 寫**：`set_pointer`＋`sys_token` insert 綁同一 plain `DatabaseTransaction`（同成同敗），**不**經 005 `mutate_in_txn`（無 op-log）。

### 5.2 結構與檔案（§I.5）
```
server/src/
  config.rs            ← 新：讀 DB URL + JWT secret（_FILE 優先 env fallback）
  state.rs             ← 新：AppState{ db: DatabaseConnection, jwt: JwtConfig, enforcer: Arc<RwLock<Enforcer>> }
  auth/
    jwt.rs             ← 新：HS256 sign/verify + Claims struct
    bearer.rs          ← 新：extract Authorization: Bearer → verify → Claims（axum extractor/helper）
    password.rs        ← 新：argon2id verify
    enforce.rs         ← 新：enforce_mw 通用 gate（bearer→DB-fresh role→is_current→Casbin enforce）
  handler/auth.rs      ← 新：login, getUserInfo
  model/facade/
    sys_token.rs       ← 新：insert_token（find_by_hash = 波3）
    sys_role.rs        ← 新：roles_of_user（user_id → role code[]）；buttons_of_roles（Casbin v2='button'）
    sys_user.rs        ← 加：find_by_user_name / set_pointer(current_session_id) / is_current
  error.rs             ← 加：From<DbErr> for AppError（→5000）；確認 1000/3333/7777/5003 變體
  main.rs              ← 改：build AppState + mount /auth/* routes + enforce layer + boot init enforcer
Cargo.toml             ← 加 dep（非新 crate）：jsonwebtoken / argon2 / uuid / casbin / sea-orm-adapter(path)
```

### 5.3 data flow — `POST /auth/login`
1. 收 `{userName, password}` → `facade::sys_user::find_by_user_name`（活躍、未軟刪）→ 查無/停用 → **1000 collapse**（不洩漏帳號是否存在）。
2. `auth::password::verify(password, model.password)`（argon2id）→ 失敗 → **1000 collapse**。
3. 查 roles（`facade::sys_role::roles_of_user`）→ 生 `sid`=uuid／`jti`=uuid／`rotation_chain`=uuid → `auth::jwt::sign` access（短 TTL）＋refresh（長 TTL）。
4. plain txn：`set_pointer(user_id, sid)`（`current_session_id=sid`）＋`facade::sys_token::insert_token`（hash=sha256(refresh)、rotation_chain、status=active、issued/expires、used_at=NULL）→ commit。
5. 回 `Res::ok(LoginToken{ token, refreshToken })`。

### 5.4 data flow — `GET /auth/getUserInfo`（protected）
- 經 `enforce_mw`（bearer verify→is_current）後：`facade::sys_role::roles_of_user`（DB-fresh role code[]）＋`buttons_of_roles`（Casbin `v2='button'`）→ 組 `UserInfo{ userId: model.id.to_string()〔⚠️r〕, userName: alias(User→User01), roles, buttons }` → `Res::ok`。

### 5.5 data flow — `enforce_mw`（通用 gate）
1. `bearer::verify`（Authorization: Bearer）→ 失敗（缺/簽章/exp/aud）→ **3333**。
2. resolve user_id（claims.uid）→ `is_current`（claims.sid == `current_session_id`？DB-truth、**fail-OPEN**：DB 抖動不誤踢）→ 不等 → **7777**。
3. DB-fresh role → Casbin `enforce(role, path, method)` → deny → **5003**（HTTP 403）。
4. allow → 放行至 handler。

### 5.6 single-session（§4.3 first-mount、§I.7 forward-compat）
- pointer 真相＝`sys_user.current_session_id`（login `set_pointer` 寫 sid）；`is_current` 比對 claims.sid；**fail-OPEN**（讀失敗放行、不誤踢）；他處登入覆蓋 pointer → 舊 session 下次 gate → **7777**。
- **006 無條件跑 gate**、不實作 session_policy 三態／runtime `session_mode`（＝波3 在 gate 之上加 gating）→ §I.7 方向性 invariant 全守、非違反（plan 期 Constitution Check Q9 複核）。

### 5.7 error handling / 碼
- `From<DbErr> for AppError`（→5000、⚠️e HTTP 200 信封）；23505 unique-violation→2222 留波2 CRUD（login 不撞）。
- 1000（login collapse、msg key `auth.login.failed`）／3333（bearer fail）／7777（is_current fail）／5003（enforce deny、HTTP 403）；**禁發** 3333/9999/9998 於任何 refresh 端（006 無 refresh）。

### 5.8 testing / 驗證（C-V）
- **C-V-0 build**：容器內 `cargo build -p server` 綠（auth/handler/config/state/facade 編譯）。
- **C-V-1 純函式測**（無 DB）：JWT sign→verify roundtrip＋過期/壞簽 reject；argon2id verify（對已知 hash）；claims 解析；`enforce` decision seam（allow/deny）。
- **C-V-2 live curl 鏈**（stack healthy）：`/api/auth/login`（Super/123456→200+token）→ `/api/auth/getUserInfo`（bearer→roles/buttons）→ enforce allow；**deny**（壞 token→3333、無權 role→5003）；**7777**（同帳號二次 login→舊 token getUserInfo 被踢）；**1000**（壞密碼）。psql 驗 `sys_token` 寫入＋`current_session_id` 更新。
- **C-V-3 CDP**（§3.6 i18n 端到端首檢核）：base-web 瀏覽器 login 失敗 → toast 經 `$t` 顯示 `auth.login.failed` 在地化字串。
- **C-V-4 prod image build**（§7 紀律、加 dep）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（prod multi-stage 含新 dep＋`sea-orm-adapter` COPY）。
- **C-V-5 lint 守恆**：`entity_access_lint` 續綠（auth/handler 不可 path-root `entity::`；entity 存取全在 facade）。

## 6. Phase 0 research 待辦（移交 `/speckit-plan`）
- **R-A argon2id verify API**：grep m002 seed 用的 argon2 版本/參數（`migration/` 內），server 端 `argon2` crate `PasswordHash::new`＋`verify_password` 對齊；確認 hash 格式相容。
- **R-B jsonwebtoken ＋ time-pin landmine**（CHECKLIST §3.7 已登）：加 `jsonwebtoken` 後 `cargo tree -i time` 判 real/inert；若經 `simple_asn1` 入真 graph → `cargo update -p time --precise 0.3.37`＋pin `simple_asn1 0.6.3`（否則撞 1.86 MSRV：time≥0.3.41 宣告需 1.88）。定 HS256 claims 結構。
- **R-C Casbin `Enforcer` ＋ vendored `sea-orm-adapter` API**：grep adapter 公開 API（自 `DatabaseConnection`/URL 構造、`load_policy`、`enforce` 簽名）；確認 boot init 與 `model.conf`/policy 載入形；`v2` 維度查 buttons（`get_filtered_policy`）。
- **R-D `sys_token` 欄精確型 ＋ insert 形**：親讀 `entity/src/sys_token.rs`（user_id/token_hash/rotation_chain/status/issued_at/expires_at/used_at 型）；`now` 走 `sea_orm::sqlx::types::chrono::Utc::now()`（server 無 chrono dep、不改 Cargo.toml）。
- **R-E wire 3-端對齊**（三-grep 紀律）：(a) rust handler return（LoginToken/UserInfo DTO）／(b) base-web `auth.d.ts`（已親驗 §2.4）＋`auth.ts` inline 型／(c) component state（login store/userInfo）。釘 `userId=string`（⚠️r 序列化邊界 i64→string、2^53 守衛）、roles/buttons=string[]。
- **R-F config/AppState 模式**：grep `migration/src/main.rs` 既有 secret 讀檔模式（DB URL from `/run/secrets/...`），server config 對齊；`_FILE` 優先 env fallback 的讀法。
- **R-G error.rs 碼路徑**：grep 003 `AppError` 變體＋碼映射；確認 1000/3333/7777 變體在否、缺則加（對齊 §7.3 凍結碼、reserved 不增變體）。
- **R-H §I.7 Constitution Check**：plan 期 §IV Q9 複核 006 single-session first-mount（無條件 gate、不 bake session_mode）是否守 §I.7 方向性 invariant（傾向守、forward-compat）；如判觸字面「session_mode 讀 runtime store」→ 評 amendment vs 讀 system_settings seed fallback。
- **R-I prod build 紀律**：加 dep（非新 crate）→ acceptance **必含 prod target image build**（C-V-4）；確認 prod Dockerfile 的 workspace COPY 含 server 新 dep 與 `sea-orm-adapter`（後者 migration 已 COPY、複用）。
- **CDP**：1000 i18n toast 端到端（§3.6）＝006 唯一 CDP 軌；login→getUserInfo→enforce 主鏈以 curl 證、CDP 補 i18n 顯示面。

## 7. 風險 / 注意
- **time-pin landmine**（§3.7）：jsonwebtoken→simple_asn1→time 撞 1.86 MSRV——加 dep 第一件事 `cargo tree -i time`、必要時 pin（R-B）。
- **prod build 破口**（CLAUDE.md §3 紀律）：006 動 Cargo.toml（加 dep）＋接 `sea-orm-adapter`／casbin——dev bind-mount 會遮 prod multi-stage Dockerfile 缺 COPY；**必跑 C-V-4 prod image build**，勿只靠 dev。
- **§I.7 single-session**：006 first-mount 須守 fail-OPEN（DB 抖動不誤踢）／7777 通道／pointer-truth-in-DB／set_pointer 永遠執行；不 bake 靜態 session_mode（R-H、plan Q9 複核）。
- **DB-fresh role 非 claims**：enforce/getUserInfo 一律即時查 role（claims roles 僅 hint）——防 token 內角色過期授權漂移。
- **login 不洩帳號存在**：帳號不存在與密碼錯誤皆 collapse 為 1000（同 msg）。
- **fail-OPEN vs fail-CLOSED 別搞反**：`is_current` fail-OPEN（可用性）；bearer verify fail-CLOSED（安全）——兩者方向相反、§I.7 凍結。
- **login 寫非 op-log**：`set_pointer`+token insert 走 plain txn；事件審計（含 client_ip→region）＝007 overlay（本刀 OUT）。
- **curl≠modal**：enforce/single-session 主鏈以 curl 證，但 1000 i18n 顯示須 CDP（§3.6）；list filter 空字串守門等 modal 經典案例屬波1+（無 list 端點於 006）。
- **無回歸（SC-007）**：006 加端點但 `/health` 不變、既有路由不破；新碼編入執行中服務。
