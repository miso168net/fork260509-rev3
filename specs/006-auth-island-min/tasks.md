# Tasks: 006-auth-island-min（Auth 島最小段＋runtime 骨幹第一刀）

**Input**: Design documents from `/specs/006-auth-island-min/`

**Prerequisites**: plan.md ✅、spec.md ✅（US1~US4、17 FR、9 SC、16/16 checklist、NEEDS CLARIFICATION=0）、research.md（R1/R-A~R-I 全 ground-truth grep）✅、data-model.md（config/state＋JWT claims＋auth 機制＋facade＋casbin model＋DTO＋data flow）✅、contracts/（verification-commands C-V-0~6＋auth-island-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS、Q9 §I.7 forward-compat）

**Tests**: 本 feature **有純函式測＋活體測**（spec FR＋C-V）。純測＝in-crate `#[cfg(test)]`（JWT/argon2/claims/enforce-seam、無 DB、test-first 精神）；活體＝live curl 鏈（login→getUserInfo→enforce、3333/5003/7777/1000）＋psql＋CDP（1000 i18n）；lint＝既有 `entity_access_lint`（C-V-4）。

**Organization**: 依 user story 分 phase。**rust 全程 serial**（共用 target、即使 [P] 不平行 cargo）、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime 假綠）；**兩段式 commit**（rust-api worktree→outer pin、不延後）；**§I.4：全程不 push 不 merge**。**含 prod build**（加 dep、C-V-5、R-I）。**地基已 provisioned**：secret（001）／AppError 變體（003）／i18n（003）／argon2·casbin·sea-orm-adapter（workspace）。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（dep ＋ time-pin、blocking 全 US）

**Purpose**: 依賴就位、time-pin landmine 先排。⚠️ 動 rust-api worktree——兩段式 commit。

- [ ] T001 `rust-api/server/Cargo.toml` 加 dep：`jsonwebtoken`（HS256）／`uuid`（v4）／`sha2`（token_hash）／`argon2 = { workspace = true }`／`casbin = { workspace = true }`／`sea-orm-adapter = { path = "../sea-orm-adapter" }`。**★ 加 `jsonwebtoken` 後容器內立刻 `cargo tree -i time` 判 real/inert**；若經 `simple_asn1` 入真 graph → `cargo update -p time --precise 0.3.37` ＋（必要時 root `Cargo.toml` pin `simple_asn1 = "0.6.3"`）；於 Cargo.toml 註記實況（撞 1.86 MSRV 才 pin、inert 則註）。（research R-B）

**Checkpoint**: dep 解析、time-pin 已排（待 T013 build 驗）

## Phase 2: Foundational（runtime 骨幹＋auth 機制＋facade；blocking 全 US）

**Purpose**: config/state/bootstrap ＋ JWT/argon2/enforce 機制 ＋ facade ＋ error From<DbErr> ＋ main 接線——US1~US4 共享前置。

- [ ] T002 `rust-api/server/src/config.rs`（新）：`AppConfig{ database_url, jwt_secret, refresh_token_secret }`＋讀取（沿 `migration/src/main.rs` 模式：env 直值→`APP_*_FILE`〔讀檔 trim〕→fallback；access=`APP_JWT_JWT_SECRET[_FILE]`、refresh=`APP_JWT_REFRESH_TOKEN_SECRET[_FILE]`、db=`APP_DATABASE_URL[_FILE]`；讀檔失敗 eprintln；長度 ≥32、拒 `change-me*` 黑名單 boot panic）。`main.rs` 加 `mod config;`（research R-F）
- [ ] T003 `rust-api/server/src/state.rs`（新）：`AppState{ db: DatabaseConnection, jwt: JwtConfig, enforcer: Arc<RwLock<casbin::Enforcer>> }`（derive Clone；**無 Redis**）＋`JwtConfig{ access_secret, refresh_secret, access_ttl, refresh_ttl, iss, aud }`。`main.rs` 加 `mod state;`（data-model §1.2）
- [ ] T004 [P] `rust-api/server/src/auth/jwt.rs`（新）：`Claims{ uid:i64, sid, jti, rotation_chain, roles:Vec<String>, iss, aud, exp:i64, iat:i64 }`（Serialize/Deserialize）＋`sign(claims, secret)->String`／`verify(token, secret)->Result<Claims>`（HS256、exp/aud/iss 驗）。`auth/mod.rs` 串接（data-model §2）
- [ ] T005 [P] `rust-api/server/src/auth/password.rs`（新）：`verify(input:&str, phc:&str)->bool`（`argon2` 0.5.3 `PasswordHash::new(phc)`＋`Argon2::default().verify_password`、對 m002 PHC `$argon2id$...`）（research R-A）
- [ ] T006 `rust-api/server/src/model/facade/sys_token.rs`（新）＋`facade/mod.rs` 加 `pub mod sys_token;`：`insert_token(txn:&DatabaseTransaction, user_id:i64, token_hash:String, rotation_chain:String, issued_at, expires_at)->Result<(),DbErr>`——INSERT `entity::sys_token::ActiveModel`（status=Set("active")、used_at=Set(None)；id/created_at 不 Set）。**無 rotate/find_by_hash**（波3）（research R-D）
- [ ] T007 `rust-api/server/src/model/facade/sys_user_role.rs`（新）＋`facade/mod.rs` 加 `pub mod sys_user_role;`：`roles_of_user(db, uid:i64)->Result<Vec<String>,DbErr>`——join `sys_user_role⋈sys_role` 取 `code[]`（DB-fresh role）（data-model §4）
- [ ] T008 `rust-api/server/src/model/facade/sys_user.rs`（004/005 既有、加）：`find_by_user_name(db, name:&str)->Result<Option<Model>,DbErr>`（活躍、`deleted_at IS NULL`）／`set_pointer(txn:&DatabaseTransaction, uid:i64, sid:&str)->Result<(),DbErr>`（UPDATE current_session_id）／`current_session_id_of(db, uid:i64)->Result<Option<String>,DbErr>`（is_current 讀、entity:: 在 facade 合法）（data-model §4）
- [ ] T009 `rust-api/server/src/error.rs`（003 既有、加）：`impl From<DbErr> for AppError`（→`Internal`/5000）。既有變體 `LoginFailed`(1000)/`TokenExpired`(3333)/`ModalLogout`(7777)/`PermissionDenied`(5003) **直接用、不新增**（research R-G）
- [ ] T010 `rust-api/server/src/auth/enforce.rs`（新）：`MODEL_CONF: &str`（embedded 純 3-tuple RBAC、data-model §3.1）＋`init_enforcer(db)->Enforcer`（`SeaOrmAdapter::new(db)`＋`Enforcer::new(DefaultModel::from_str(MODEL_CONF), adapter)`＋`load_policy`）＋`bearer` extract+verify（→Claims、缺/壞→3333）＋`is_current`（claims.sid==`current_session_id_of`？DB-truth、**fail-OPEN**：Err→放行；不等→7777）＋`enforce_mw`（bearer→is_current→〔policy-governed route〕Casbin `enforce((role,path,method))`〔全 deny→5003〕；auth-only route 跳 policy 步）（research R-C、data-model §5/§7）
- [ ] T011 `rust-api/server/src/main.rs`（改）：`#[tokio::main] async` build `AppConfig`→`Database::connect`→`init_enforcer`→`AppState`；mount `POST /auth/login`（public）＋`GET /auth/getUserInfo`（套 `enforce_mw` auth-only）＋既有 `/health`＋fallback；`.with_state(AppState)`。加 `mod auth; mod handler;`（data-model §1.2、plan 實作注意.1）
- [ ] T012 `rust-api/server/src/handler/mod.rs`＋`handler/auth.rs`（新、骨架）：`login`／`get_user_info` handler 簽名就位（待 T014/T016 填內容；先回 stub 使 T013 build 綠）
- [ ] T013 C-V-0 build：容器內 force-touch `server/src` → `cargo build -p server` 綠（config/state/auth/handler/facade 編譯、新 dep 解析、time-pin 不撞 1.86）（依 T001~T012）
- [ ] T014 C-V-1 純函式測（無 DB、test-first 精神；in-crate `#[cfg(test)]`、fn 名含 `auth`）：JWT sign→verify roundtrip＋過期/壞簽/錯aud reject／argon2id verify（對 `Argon2::default().hash_password("123456")` 產 PHC、錯密碼 false）／Claims serde roundtrip／**Casbin enforce seam**（embedded MODEL＋fixture/seeded policy：`enforce(("R_SUPER","/systemManage/deleteUser","DELETE"))==true`、`("R_USER_COMMON",…)==false`＝**5003 證面**）。容器內 `cargo test -p server auth`（警覺「0 passed/N filtered」假綠）（依 T004/T005/T010）

**Checkpoint**: 機制核心＋build 綠＋純測綠（JWT/argon2/enforce-seam）→ **雙段 commit**（worktree→pin）

## Phase 3: US1 — 帳密登入取得會話憑證（P1）🎯 MVP

**Goal**: login 端到端（argon2 verify＋簽 JWT＋set_pointer＋insert_token 原子＋1000 collapse）。
**Independent Test**: C-V-2(a)(d)(g) login 成功/1000/atomic；不依賴 US2~US4。

- [ ] T015 [US1] `rust-api/server/src/handler/auth.rs` `login`（填）：收 `{userName,password}`→`facade::sys_user::find_by_user_name`（查無→`LoginFailed`）→`auth::password::verify`（false→`LoginFailed`、與查無不可區分）→`roles_of_user`→生 sid/jti/rotation_chain(uuid)＋`now`＋sign access(jwt_secret)/refresh(refresh_token_secret)→`token_hash=sha256(refresh)`→`db.transaction`〔`set_pointer`＋`sys_token::insert_token`〕原子→`Res::ok(LoginToken{token,refreshToken})`（serde camelCase）（data-model §5、research R-D/R-E）
- [ ] T016 [US1] C-V-2 login live curl（stack healthy）：`Super`/`123456`→200 `{token,refreshToken}`；壞密碼→`1000`/`auth.login.failed`；不存在帳號→**同** `1000` 同 msg（不洩存在）；psql 驗 `sys_token` 新列＋`sys_user.current_session_id` 更新（原子、SC-008）。對應 SC-001（依 T015）

**Checkpoint**: US1 全綠＝MVP（SC-001；login 成立）→ **雙段 commit**

## Phase 4: US2 — 取得登入者身分資訊（P2）

**Goal**: getUserInfo（bearer→is_current→DB-fresh roles＋真 buttons＋nick_name alias、userId=string）。
**Independent Test**: C-V-2(b)(c) getUserInfo roles/buttons/User→User01；需 US1 token。

- [ ] T017 [US2] `rust-api/server/src/handler/auth.rs` `get_user_info`（填）：經 `enforce_mw`（bearer+is_current）後——`roles_of_user(claims.uid)`＋`enforcer.get_filtered_policy` 篩 `v2="button"` 取 v1 去重＋`find_by_id`→`UserInfo{ userId: id.to_string()〔⚠️r〕, userName: nick_name.unwrap_or(user_name)〔User→User01〕, roles, buttons }`→`Res::ok`（data-model §6、research R-C/R-E）
- [ ] T018 [US2] C-V-2 getUserInfo live curl：`Super` token→`{userId(string), userName, roles[含 R_SUPER], buttons[非空]}`；`User` token→`userName=="User01"`（alias）。對應 SC-002（依 T017）

**Checkpoint**: US2 全綠（SC-002）→ **雙段 commit**

## Phase 5: US3 — 受保護資源權限守門（P2）

**Goal**: enforce_mw 守門證實——3333（bearer fail）＋5003（casbin deny、seam 證）。
**Independent Test**: C-V-2(e) 3333 ＋ C-V-1 enforce seam（5003）；enforce_mw 機制在 T010/T014 已落、本 phase 為 acceptance。

- [ ] T019 [US3] C-V-2 enforce live curl：getUserInfo 缺 token→`3333`；壞 token→`3333`。**5003**＝C-V-1（T014）enforce seam 證（R_SUPER allow／R_USER_COMMON deny `/systemManage/deleteUser`）——006 無 policy-governed 業務端點（getUserInfo auth-only）、不另構合成端點（避 scope creep、research R-C 校正）。對應 SC-003（依 T010/T014/T017）

**Checkpoint**: US3 全綠（SC-003）→ **雙段 commit**（或併前段）

## Phase 6: US4 — 單一裝置登入（P3）

**Goal**: single-session first-mount（set_pointer〔login〕＋is_current〔gate〕→7777）。
**Independent Test**: C-V-2(f) 二次 login、舊 token→7777、新 token ok；機制在 T010/T015 已落、本 phase 為 acceptance。

- [ ] T020 [US4] C-V-2 single-session live curl：`Super` 二次 login（T1 後 T2）→ 舊 token T1 呼 getUserInfo→`7777`（他處登入）；新 token T2→`0000`（正常）。驗 `is_current` fail-OPEN 不誤踢（正常情境放行）。對應 SC-004（依 T010/T015/T017）

**Checkpoint**: US4 全綠（SC-004）→ **雙段 commit**

## Phase 7: Polish & Cross-Cutting

- [ ] T021 C-V-3 CDP i18n（§3.6 端到端首檢核）：base-web 瀏覽器（front-nginx :31080）登入輸錯密碼→toast 顯示在地化「用户名或密码错误」（非 raw key）。驗 003 i18n 接線端到端（006 後端發 1000=`auth.login.failed`）。對應 SC-006
- [ ] T022 C-V-4 lint 守恆：容器內 force-touch `server/src server/tests` → `cargo test -p server --test entity_access_lint` 綠（auth/handler/config/state 零 path-root `entity::`、entity 存取全在 facade）。對應 FR-007
- [ ] T023 C-V-5 **prod target image build**（★加 dep 紀律、R-I）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（prod multi-stage 含新 dep、`--locked`、time-pin 在 1.86 prod toolchain 不撞；model.conf embedded `from_str` 無 examples COPY 坑）。對應 SC-007
- [ ] T024 收口驗證（**commit only——push/merge 凍結至 finishing、§I.4**）：rust-api worktree 全 task commit 齊＋outer pin == worktree HEAD（pin 隨 task bump 紀律回顧）＋specs/006 外層檔收；`git submodule status` rust-api 行首空格；**C-V-0~6 全綠彙整**（build／純測／login·getUserInfo·enforce·single-session live curl／CDP i18n／lint／prod build）；**SC-007 零回歸實證**：`curl -fsS http://127.0.0.1:31081/health` 回 `ok`；**SC-009 範圍核**：diff 確認零 migration/entity/base-web/i18n/compose-secret 變動、零新 binary、零 refresh 端點/menu/事件審計/多會話設定/lockout；quickstart 7 步逐步對照綠

## Dependencies

```
Setup (T001) ─→ Foundational (T002~T014)  [rust-api worktree、serial]
   T001（dep+time-pin）blocks all build；T002/T003（config/state）→ T011（main 用）
   T004/T005（jwt/password [P]）／T006/T007/T008（facade）／T009（error）／T010（enforce）→ T011（main 接線）→ T012（handler 骨架）→ T013（build）→ T014（純測）
Foundational ──┬─→ US1 (T015→T016)        [login 用 jwt/password/facade/atomic]
               ├─→ US2 (T017→T018)        [getUserInfo 用 bearer/enforce/roles/buttons/facade]
               ├─→ US3 (T019)             [enforce acceptance：3333 curl＋5003 seam〔T014〕]
               └─→ US4 (T020)             [single-session acceptance：7777 curl〔set_pointer T015＋is_current T010〕]
US1~US4 ──→ Polish (T021~T024)
```

## Parallel Execution Examples

- **概念並行**：T004（jwt.rs）∥ T005（password.rs）——不同檔、不同邏輯。facade T006/T007/T008 不同檔可並行撰寫。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔/邏輯可並行撰寫」、cargo build/test 一次一個。
- **US3/US4 為 acceptance phase**（機制在 Foundational/US1 已落）、可緊接 US2 後驗。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T016）＝Setup＋Foundational（runtime 骨幹＋auth 機制＋facade）＋US1（login proof）即最小價值（帳密登入成立）。US2 getUserInfo（T017~T018）＋US3 enforce（T019）＋US4 single-session（T020）緊接；Polish 收口（CDP／lint／**prod build**／零回歸／範圍核）。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進。**★ 實作第一步＝T001 加 jsonwebtoken 後立刻 `cargo tree -i time` 判 time-pin**。**rust serial、容器內 build/test、改 .rs 先 force-touch；兩段式 commit（worktree→pin）；全程不 push/merge；加 dep→必跑 prod build（C-V-5）**。
