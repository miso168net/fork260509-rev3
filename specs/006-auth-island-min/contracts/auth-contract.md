# Contract: auth-contract（jwt/bearer/argon2 純測＋enforce 判定＋handler envelope＋实机 smoke＋CDP；test 權威）

> jwt/bearer/argon2/enforce-decision 為**純函式 test-first**（先紅後綠、零 DB/HTTP）；handler 行為＋enforce-proof＋wire 對齊由 **实机 smoke（全棧 curl）**＋**CDP browser smoke** 證。形對齊 R1/R2/R3 grep 與 data-model；紅了校實作、不調 contract 遷就實作（⚠️g 全新寫、形對齊 rev2 013／base-web wire）。

## 1. `jwt` 純測契約（test-first、零 DB/HTTP）

- `sign(uid, &roles, secret, ttl, iss, aud)` → token；`verify(token, secret, aud)` **MUST**：
  - roundtrip：`verify` 取回 `user_id==uid`、`roles==roles`、`aud==aud`。
  - **竄改 reject**：改 token 任一字元 / 用錯 secret → `Err`。
  - **過期 reject（leeway=0）**：`ttl=0`（或 exp 設過去）→ `verify` `Err`（剛過期亦拒、不寬限）。
  - **aud 不符 reject**：`verify(token, secret, "other-aud")` → `Err`。
  - **iss 不驗**：iss 不同不影響 `verify`（資訊性）。
- Claims **無 sid/jti**（028/030 剝）。

## 2. `bearer` 純測契約

- `bearer_token(headers)` **MUST**：`Authorization: Bearer xyz`→`Some("xyz")`；無 header / 無 `Bearer ` 前綴 / 空 token / 小寫 `bearer`→`None`；前後空白 trim。
- `verify_bearer(headers, secret, aud)` = `bearer_token`＋`jwt::verify`；無/壞 token→`None`（不 panic）。

## 3. `argon2` 純測契約（seed hash runtime 生成、roundtrip 自含、R4）

- `hash_password("123456")`→`h`；`verify_password("123456", &h)` **MUST** `true`；`verify_password("wrong", &h)` **MUST** `false`；`verify_password("x", "not-a-phc")` **MUST** `false`（不 panic）。
- **不依賴 seed 固定字串**（runtime random salt）。

## 4. `enforce` 判定契約（純測可行則純、否則併实机）

- 對 MODEL（r=p=sub,obj,act、三欄精確）＋一組 policy `('R_SUPER','/p','GET')`：
  - `enforce(("R_SUPER","/p","GET"))`→`true`；`enforce(("R_SUPER","/p","POST"))`→`false`（method 不符）；`enforce(("R_OTHER","/p","GET"))`→`false`（sub 不符）；`enforce(("R_SUPER","/q","GET"))`→`false`（obj 不符）。
- **subject＝DB-fresh role code**（非 JWT claims；enforce_mw 重查）。

## 5. handler envelope 契約（wire 對齊 R2；实机/CDP 驗）

| 端點 | 成功 | 失敗 |
|---|---|---|
| `POST /auth/login {userName,password}` | `Res{data:{token,refreshToken}, code:"0000"}` | 帳密錯/查無/停用→`login_failed`(code `"1000"`、HTTP 200)、**一致不洩漏哪步**；簽發失敗→`internal`(5000) |
| `POST /auth/refreshToken {refreshToken}` | `Res{data:{token,refreshToken}, code:"0000"}`（重發 pair） | refresh 失效→**`logout`(code `"8888"`)**〔R2 反迴圈鐵律、**不得**回 3333/9999/9998〕 |
| `GET /auth/getUserInfo`(Bearer) | `Res{data:{userId,userName,roles,buttons}, code:"0000"}`；`userId` **string**、`userName=nick_name‖user_name`、`buttons` 現 `[]` | token 缺/失效/user 查無→`token_expired`(code `"3333"`) |
| enforce-gated route(Bearer) | next（200） | 無 policy→`permission_denied`(code `"5003"`、HTTP 403)；token 缺/失效→`token_expired`(`"3333"`)；**role-lookup DB error→fail-closed `permission_denied`(5003)＋log**（R6/DESIGN line 686） |

- **⚠️r userId 2^53**：`user.id` 序列化為 string；超 2^53 → **fail-loud**（`internal`、不靜默截斷）。
- envelope `code` 為**字串**、成功 `"0000"`（003 envelope、base-web success code）。

## 6. bounded 实机 smoke 契約（全棧 curl、`#[ignore]` 或腳本、postgres+migrate seed）

> 起 front-nginx+base-web+rust-api+postgres+migrate；經 `/api` 或直連 rust-api `:31081`。seed user `Super`/`123456`（runtime argon2 hash）。

1. **login 成功**：`POST /api/auth/login {"userName":"Super","password":"123456"}`→`code:"0000"`＋`data.token`/`data.refreshToken` 非空。
2. **login 失敗一致**：錯密碼／查無帳號→皆 `code:"1000"`、回應無法區分（帳號枚舉防護）。
3. **getUserInfo**：帶 `Authorization: Bearer <token>`→`code:"0000"`＋`data.userId`(string)/`data.userName`/`data.roles`(含 R_SUPER)/`data.buttons`([])。
4. **refresh**：`POST /api/auth/refreshToken {"refreshToken":<r>}`→`code:"0000"`＋新 pair；壞 refresh→`code:"8888"`（非 3333）。
5. **enforce-proof**（注入拋棄式 policy `('p','R_SUPER','/__enforce_check__','GET')`）：Super token→200；無 R_SUPER 的合成 role token→403/`5003`；bad token→`3333`。測後清拋棄式 policy。
6. **過期/竄改**：過期 token→getUserInfo `3333`；竄改 token→`3333`。

## 7. CDP browser smoke 契約（§3.6 directed；base-web 真打 rust-api）

> base-web 指向真 rust-api（改 `.env` `VITE_SERVICE_BASE_URL`/proxy 或 smoke env、BASE-WEB-ADAPT 軌）；CDP `ws://127.0.0.1:9229`（注意 origin `localhost`≠`127.0.0.1`）。`VITE_AUTH_ROUTE_MODE=static`→不呼 getUserRoutes。

1. 開 base-web `/login`、pwd-login 填 `Super`/`123456`、submit。
2. **攔截器真讀 login envelope**：`POST /auth/login`→`code:"0000"`、攔截器判 success、`data.{token,refreshToken}` 存入 localStorage `token`/`refreshToken`。
3. **getUserInfo envelope 解析**：`GET /auth/getUserInfo`(Bearer)→`code:"0000"`、攔截器取 `data`、userInfo store 填 `userId/userName/roles/buttons`。
4. **驗到此為止**（static 模式不呼 getUserRoutes）；登入後動態路由掛載＝波 2 Menu（登 follow-up）。
- 目標：證 **curl 直送 ≠ base-web 判讀**——base-web 攔截器對真 rust-api envelope 的 code/data/msg 判讀正確（003 §3.6）。

## 8. 結構/守恆契約
- `auth/jwt.rs`/`bearer.rs` 純、零 `entity::`、零 DB；`auth/enforce.rs`/`handler/auth.rs` 經 facade 取 entity、`entity_access_lint` 續綠。
- handler 回 `Res<T>`/`AppError`→envelope（003、FR-009）；`/health` 不退化（SC-007）。
- 殘留：auth/handler/state 內容零 rev2 token（以「前代」描述、⚠️g、SC-008）。
