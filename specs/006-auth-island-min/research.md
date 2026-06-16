# Phase 0 Research: 006-auth-island-min

> 接地源＝rust-api 005 後現況親 grep（entity/facade/error/migration/Dockerfile）＋base-web wire 親讀（auth.ts/auth.d.ts/store/locales）＋vendored `sea-orm-adapter` source＋`casbin_rule` seed（m002）親驗＋DESIGN §8.3/§4.1/§4.3/§5.3/§7.3＋constitution §I.1/§I.3/§I.5/§I.7＋brainstorm `docs/superpowers/006-auth-island-min.md`。**NEEDS CLARIFICATION = 0**（brainstorm 三刀界全決、clarify 0 問題）。
> ★ 研究推翻 brainstorm 兩個假設（見 R-C/R-G），並發現多項地基已由 001-003 provisioned（見 R-F/R-G）。

## R1 — scaffold：runtime 骨幹第一刀、dep 增量小於預期

**Decision**：006 為 rust-api **runtime 骨幹第一刀**（main.rs 仍 001 空殼〔僅 `/health`＋fallback、無 `AppState`/DB/auth〕）；新增 `server/src/{config,state}.rs`＋`auth/{jwt,bearer,password,enforce}.rs`＋`handler/auth.rs`＋`model/facade/{sys_token,sys_user_role}.rs`＋`facade/{sys_user,sys_role}.rs` 加 fn。**無 migration、無新 workspace crate**。
**Rationale（親驗）**：`facade/mod.rs` 現有 `sys_menu/sys_operation_log/sys_role/sys_user`、**無** `sys_token/sys_user_role`；`facade/sys_role.rs` 僅 `SoftDeletable`、無業務 fn。dep 增量比 brainstork 預期小：`argon2 0.5.3`／`casbin 2.20`／`sea-orm-adapter` **已是 workspace dep**（migration/adapter 用）→ server 加 `{ workspace = true }`／`{ path }`；**genuinely 新 dep 僅** `jsonwebtoken`（time-pin 風險、R-B）＋`uuid`（sid/jti/rotation_chain）＋`sha2`（token_hash）。
**⇒ Cargo.toml 變動有（非新 crate）→ acceptance 必含 prod target image build（R-I）。**

## R-A — argon2id verify（對齊 m002 seed）

**Decision**：server `auth/password.rs` 用 `argon2` 0.5.3 `PasswordHash::parse(&model.password)` ＋ `Argon2::default().verify_password(input.as_bytes(), &parsed)`；對齊 m002 seed 產法。
**Rationale（grep `migration/src/m002_rev2_seeds.rs:20-58`）**：seed 用 `Argon2::default().hash_password(b"123456", &salt).to_string()` → PHC `$argon2id$...` 字串；`Argon2::default()` 預設參數。`argon2 = "0.5.3"`（`rust-api/Cargo.toml:22` workspace dep）。⇒ verify 端 `Argon2::default()` 同預設、`PasswordHash` parse PHC 字串、`verify_password` 比對。
**Alternatives**：手構 Argon2 參數——否決（seed 用 default、verify 必對齊 default 否則永遠 verify 失敗）。

## R-B — jsonwebtoken ＋ time-pin landmine（核心風險）

**Decision**：server 加 `jsonwebtoken`（HS256 sign/verify、claims `{uid, sid, jti, rotation_chain, roles, iss, aud, exp, iat}`）。**加 dep 後第一件事 `cargo tree -i time` 判 real/inert**；若經 `simple_asn1` 把 `time` 拉進真 compile graph → `cargo update -p time --precise 0.3.37` ＋ pin `simple_asn1 0.6.3`（否則撞 1.86 MSRV：time≥0.3.41 宣告需 1.88）。
**Rationale（grep `rust-api/Cargo.toml:12-15` 註釋＋`Cargo.lock`）**：workspace 對 `time` 經 `default-features=false` 隔離（現 inert）；Cargo.lock `time 0.3.47`（feature-gated OUT）。`rust-toolchain.toml` pin `1.86.0`（嚴格）。jsonwebtoken 9.x 經 `simple_asn1` 是已知把 time 拉進真 graph 的路徑（CHECKLIST §3.7 已登 landmine）。access/refresh **兩把密鑰**（見 R-F）。
**Alternatives**：(a) opaque token＋全查 DB——否決（base-web localStorage bearer wire＋無狀態 access 驗證需 JWT）；(b) 不 pin time、賭 inert——否決（§3.7 明列風險、必驗）。

## R-C — Casbin model.conf ＋ vendored `sea-orm-adapter` API（★ 推翻 brainstorm 維度假設）

**Decision**：
- **enforcer init**：`SeaOrmAdapter::new(db_conn)`（自 `DatabaseConnection`、`adapter.rs:15-24`、`new()` 內跑 idempotent `migration::up`、casbin_rule 已存即 no-op）→ `Enforcer::new(model, adapter)`；`model` 用 **embedded 字串** `DefaultModel::from_str(MODEL_CONF)`（不 from_file→避開 prod 不 COPY examples 的坑、R-I）。
- **casbin model ＝ 純 3-tuple RBAC**（sub/obj/act）：
  ```
  [request_definition] r = sub, obj, act
  [policy_definition]  p = sub, obj, act
  [role_definition]    g = _, _
  [policy_effect]      e = some(where (p.eft == allow))
  [matchers]           m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
  ```
- **enforce_mw**：對 user 的每個 role `enforce((role, path, method))`；任一 allow → 放行、全 deny → 5003。
- **getUserInfo buttons**：`enforcer.get_filtered_policy(0, vec![role])` 後篩 `v2=="button"`、取 `v1`（button code）；或 `get_filtered_policy` 直接帶 v0=role；本刀對 user 的 roles 聯集去重。

**Rationale（★ 親驗 `m002_rev2_seeds.rs:87-120` 推翻 brainstorm「v2='button'/'menu'/'endpoint' 維度」假設）**：`casbin_rule` 72 列全 `ptype='p'`、schema `(ptype, v0..v5, protected)`：
- v0＝role code（`R_SUPER`/`R_ADMIN`/`R_USER_COMMON`）
- v1＝obj（endpoint path `/systemManage/getUserList`／menu route `home`／button code）
- **v2＝act**：endpoint＝**HTTP method**（`GET`/`POST`/`DELETE`）、menu＝`'menu'`、button＝`'button'`
- v3/v4/v5＝空字串、protected＝bool（19 列 true）
⇒ rev3 用**純 3-tuple RBAC**（非 domains 4-tuple）；endpoint enforce 的 act＝HTTP method（**非** 'endpoint' literal）。adapter API（`adapter.rs`）：`load_policy`/`load_filtered_policy`/`get_filtered_policy`/`enforce((sub,obj,act))→bool`。`casbin = "2.20"`（workspace、`default-features=false`）。
**Alternatives**：domains model（rbac_with_domains）——否決（seed 無 dom 維度、v3-v5 空）；from_file model.conf——否決（prod 不 COPY examples、用 from_str embedded）。

## R-D — `sys_token` 欄 ＋ insert 形 ＋ token_hash（★ 推翻 brainstorm「argon2 hash token」）

**Decision**：login `facade/sys_token.rs::insert_token` Set `user_id`/`token_hash`/`rotation_chain`/`status="active"`/`issued_at=now`/`expires_at=now+refresh_ttl`/`used_at=Set(None)`；`id`/`created_at` 不 Set（DB 生成）。`now` 走 `sea_orm::sqlx::types::chrono::Utc::now().into()`；`expires_at` 用 chrono `Duration`（同 re-export 鏈可達）。
- **★ token_hash ＝ `sha256(refresh_token_jwt)`**（`sha2` crate、hex/base64 字串）、**非** argon2（argon2 是密碼慢雜湊、token_hash 是快速 unique lookup〔波3 rotation 以 hash 查 token〕）——Agent 初判「PHC argon2id」誤把密碼雜湊與 token 雜湊混淆、已校正。
**Rationale（grep `entity/src/sys_token.rs:1-25`）**：9 欄＝`id:i64`(PK)／`user_id:i64`／`token_hash:String`(unique)／`rotation_chain:String`／`status:String`／`issued_at:DateTimeWithTimeZone`／`expires_at:DateTimeWithTimeZone`／`used_at:Option<DateTimeWithTimeZone>`／`created_at:DateTimeWithTimeZone`。無 Relation。`now` 路徑 005 facade 已實證。
**Alternatives**：token_hash 用 jti（uuid）當 lookup——可（波3 設計再定）；本刀只需 unique 值、sha256(refresh) 對齊 §4.1「token_hash UNIQUE」。

## R-E — wire 3-端對齊（§I.1 權威、三-grep）

**Decision**：handler 回 DTO 對齊 base-web：`LoginToken{ token:String, refreshToken:String }`／`UserInfo{ userId:String, userName:String, roles:Vec<String>, buttons:Vec<String> }`。`userId` 序列化為 **string**（i64→string、⚠️r 序列化邊界、2^53 守衛）。`userName` ＝ seed `nick_name`（User 的 nick_name='User01' → alias 自然成立、無需 runtime 特例）。
**Rationale（grep）**：(a) base-web `service/api/auth.ts:9-37`（login POST `{userName,password}`→LoginToken／getUserInfo GET→UserInfo／refreshToken〔006 不實作端點〕）；(b) `typings/api/auth.d.ts:8-18`（LoginToken/UserInfo 精確型、`userId:string`）；(c) `store/modules/auth/index.ts`（userInfo 消費、`hooks/business/auth.ts` `hasAuth` 按 button code 查 `userInfo.buttons`）。**User→User01 alias**：`m002_rev2_seeds.rs:54` seed `('User', …, 'User01', 1)`＝user_name='User'/nick_name='User01' → getUserInfo `userName` 取 nick_name 即得 alias。
**Alternatives**：userName 取 user_name＋runtime alias map——否決（nick_name seed 已含 alias、直接取 nick_name 最簡、無特例）；userId number——否決（⚠️r typings 為 string）。

## R-F — config/secret 讀取（★ 地基已 provisioned）

**Decision**：`config.rs` 沿 migration `main.rs` 模式讀 **已 provisioned 的 secret**：
- **DB URL**：env `DATABASE_URL` → `APP_DATABASE_URL_FILE`(讀檔) → `APP_DATABASE_URL`(env)；讀檔失敗主動 eprintln。
- **JWT access 密鑰**：`APP_JWT_JWT_SECRET_FILE`(讀檔) → `APP_JWT_JWT_SECRET`(env)。
- **JWT refresh 密鑰**：`APP_JWT_REFRESH_TOKEN_SECRET_FILE` → `APP_JWT_REFRESH_TOKEN_SECRET`。
- 驗長度 ≥32、拒 `change-me` 黑名單（誤配 boot panic）。
**Rationale（★ grep `docker-compose.yml`/`docker-compose.dev.yml`/`deploy/secrets/`/`migration/src/main.rs`）**：**001 已 provisioned 全部**——compose rust-api 已 mount `jwt_secret`/`refresh_token_secret`/`database_url`/`redis_url`＋env `APP_*_FILE`＋dev override env fallback；`deploy/secrets/{jwt_secret,refresh_token_secret,database_url,redis_url}.txt` 皆存在；`generate-secrets.sh` 生成。⇒ **006 零 compose/secret 變動、只加讀取碼**。**兩把簽署密鑰**（access=jwt_secret、refresh=refresh_token_secret）。
**Alternatives**：006 自建 secret 接線——否決（001 已 provisioned、只缺消費碼）。

## R-G — error.rs/碼 ＋ i18n（★ 地基已 provisioned）

**Decision**：006 **直接構造既有 `AppError` 變體**（`LoginFailed`/`TokenExpired`/`ModalLogout`/`PermissionDenied`/`Internal`/`Biz`）；**唯一新增＝`From<DbErr> for AppError`**（→`Internal`/5000；23505 unique-violation→2222 留波2 CRUD、login 不撞）。
**Rationale（★ grep `server/src/error.rs:31-52`）**：003 已建**全** AppError 9 變體＋13 碼：`LoginFailed`→1000(`auth.login.failed`)／`TokenExpired`→3333(`auth.token.expired`)／`ModalLogout`→7777(`auth.session.kicked`)／`Logout`→8888／`PermissionDenied`→5003(`system.forbidden`,403)／`Internal`→5000／`Biz(Cow)`→2222／`NotFound`→4040(404)／`Success`→0000。reserved 4 碼無變體（編譯期凍結）。`From<DbErr>` 未實作（`error.rs:12` 註明「首個產 DbErr 切片帶入」＝006）。`IntoResponse` 已建（404/403 覆寫、餘 200）。**i18n**：`auth.login.failed` 等 13 碼譯文 003 已 ship（`locales/langs/{zh-cn,en-us}.ts`）＋`translateBackendMsg`＋`service/request` 翻譯邊界已接 → **006 零 i18n/前端變動**。
**Alternatives**：006 加 1000/3333/7777 變體——否決（003 已建、直接用）。

## R-H — §I.7 single-session Constitution Check（Q9）

**Decision**：006 single-session ＝ **§4.3 minimal first-mount**：login `set_pointer`（`sys_user.current_session_id=sid`、plain txn 與 token insert 原子）＋access gate `is_current`（claims.sid==pointer？DB-truth、**fail-OPEN**）→ 不等 7777。**無條件跑 gate、不實作 session_policy 三態/runtime session_mode**（＝波3 在 gate 之上加 gating）。token 寫 `rotation_chain`+`used_at=NULL` forward-compat、**不實作 rotate/reuse**（§4.1＝波3）。
**Rationale**：§I.7 方向性 invariant 全守——pointer-truth-in-DB／is_current fail-OPEN／7777 通道／set_pointer 永遠執行（§4.3）；bearer verify fail-CLOSED（安全、方向相反）。006 不 bake 靜態 session_mode 變數（只 always-on gate）→ 非違反「session_mode 讀 runtime store」（未實作 ≠ 違反；波3 加可設定層）。token forward-compat 不違 §4.1（rotate 邏輯波3 才有）。**plan Constitution Check Q9 判定 PASS（state-machine 鏡頭：006 實作 pointer-set/is_current 兩 transition、rotate/reuse/policy transition 遞延波3）**。
**Alternatives**：006 讀 system_settings session_mode——否決（settings 管理＝波1、006 不依賴未建之物、always-on 最小且 forward-compat）。

## R-I — prod build 紀律（加 dep）

**Decision**：acceptance **必含 prod target image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`）；確認新 dep（jsonwebtoken/uuid/sha2/argon2/casbin/sea-orm-adapter）皆能於 prod multi-stage 編譯。
**Rationale（grep `deploy/Dockerfile.rust-api.txt`）**：builder COPY 全 4 crate（server/migration/entity/sea-orm-adapter）Manifest＋Source；`sea-orm-adapter` 已 COPY（006 接它無新 COPY 缺口）；examples（.conf/.csv）刻意免 COPY（→ model 用 `from_str` embedded、R-C）。**惟 006 動 Cargo.toml（加 dep）→ dev bind-mount 會遮 prod 編譯破口（如 time-pin 在 prod toolchain 才爆、或新 dep feature 缺）→ 必跑 prod build 驗（004 entity COPY 教訓、CLAUDE.md §3 紀律）**。runtime stage COPY `server`/`migration` binary（006 無新 binary）。
**Alternatives**：只靠 dev build——否決（§3 紀律明禁、dev bind-mount 遮 prod 破口）。

## 三-grep 紀律落地
- **facade/entity 返回型**：sys_token/sys_user/sys_role/sys_user_role Model 欄已親驗（R-A/R-D）；facade 回 raw Model。
- **wire 3-端**：login/getUserInfo DTO 對齊已親驗（R-E、userId=string、buttons=button code）。
- **命名對照**：AppError 變體/碼（R-G）、casbin v0-v2 語意（R-C）、sys_token 欄（R-D）皆親 grep actual code。
- **CDP smoke**：006 主鏈 curl 證；**1000 i18n toast 須 CDP**（§3.6 端到端首檢核、curl≠modal）；list filter 空字串守門＝N/A（006 無 list 端點）。
- **enforce 5003 demo 校正**：getUserInfo 為 auth-only（seed 無 /auth/* policy）→ 5003/casbin-deny 由 **enforce seam 測**對 seeded `/systemManage/*` policy 證（R_SUPER allow `/systemManage/deleteUser`、R_USER_COMMON deny），非 getUserInfo curl。
