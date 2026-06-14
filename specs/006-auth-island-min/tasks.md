# Tasks: auth-island-min（stateless JWT login/refresh/getUserInfo＋casbin per-route enforce）

**Input**: Design documents from `/specs/006-auth-island-min/`

**Prerequisites**: plan.md ✅、spec.md ✅、research.md（R1~R7）✅、data-model.md ✅、contracts/（auth-contract＋verification-commands）✅、quickstart.md ✅

**Tests**: 本 feature **test-first TDD**（plan Testing 明示）——純函式：`jwt` sign/verify〔roundtrip/竄改/過期 leeway=0/aud reject〕＋`bearer` 抽取＋`argon2` roundtrip＋`enforce` decision〔三欄精確〕，**零 DB/HTTP**、inline `#[cfg(test)]` 先紅後綠＋**bounded 全棧 curl 实机 smoke**（login→getUserInfo→enforce-proof→refresh）＋**CDP browser smoke**（§3.6 directed、base-web 攔截器解析真 rust-api envelope）。

**Organization**: 依 user story 分 phase。**build 序＝依賴序、非 spec 優先序**——US1 login 為 P1 MVP，但其與 US2/US3 共享的 stateless 認證地基（jwt/bearer/password/state/enforce build/roles_for_user/boot）為 **Foundational（blocking 全 US）**、先行；三 US 為其上的 handler+route+smoke 薄層。**兩段式 commit 紀律（001-005 教訓）**：worktree task 完成即 worktree commit＋outer pin 隨同 bump（不延後）。**§I.4／⚠️u：全程不 push 不 merge**。**⚠️g：rev2 013 受控參照讀允許、code 全新寫；session/token-state（sid/jti/is_current/session_mode/redis/sys_token）剝離＝波 3**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（deps）

- [ ] T001 [P] 依賴增量：`rust-api/Cargo.toml` workspace deps ＋`jsonwebtoken = "9"`（新；MSRV ~1.63＋ring 0.17〔1.61〕≤ 1.86、research R5 已驗）；`rust-api/server/Cargo.toml` ＋`jsonwebtoken`/`argon2`/`casbin`/`sea-orm-adapter = { path = "../sea-orm-adapter" }`（argon2/casbin 自 workspace、sea-orm-adapter 既有 vendored crate）。

## Phase 2: Foundational（blocking 全 US；test-first 純函式＋boot/AppState/enforcer）

- [ ] T002 [P] test-first `auth/jwt.rs`（全新寫⚠️g、零 `entity::`）：`Claims{sub,user_id,roles,exp,iat,iss,aud}`〔**無 sid/jti**、剝 028/030〕＋`sign(user_id,&roles,secret,ttl,iss,aud)`＋`verify(token,secret,aud)`（HS256、leeway=0、驗 exp+aud、iss 不驗）；`JWT_ISS/JWT_AUD="rev3-admin"`。`#[cfg(test)]` 先紅後綠（contracts/auth-contract.md §1）：roundtrip 取回 user_id/roles／竄改 reject／過期(ttl=0) reject／aud 不符 reject。
- [ ] T003 [P] test-first `auth/bearer.rs`（純）：`bearer_token(headers)->Option<&str>`（`Bearer ` 前綴 case-sensitive/trim/空→None）＋`verify_bearer(headers,secret,aud)->Option<Claims>`。`#[cfg(test)]`（§2）：Bearer 抽取／無前綴·空·小寫→None／trim。
- [ ] T004 [P] test-first `auth/password.rs`：`verify_password(password,phc)->bool`（`PasswordHash::new`+`Argon2::default().verify_password`）＋`hash_password(plain)->String`（argon2 0.5.3）。`#[cfg(test)]`（§3）：hash→verify true／錯密碼 false／壞 phc false（roundtrip 自含、不依賴 seed 字串）。
- [ ] T005 `server/src/state.rs`（新）：`JwtConfig{access_secret,access_ttl,refresh_secret,refresh_ttl,iss,aud}`＋`AppState{db, jwt:Arc<JwtConfig>, enforcer:Arc<RwLock<Enforcer>>}`（**剝 redis/session_mode**；jwt secret 走 `_FILE` 讀 deploy/secrets）＋`server/src/error.rs` ＋`From<DbErr>`/`From<casbin::Error>`→`AppError::internal`（§3.6 泛型 fallback、data-model §9）。
- [ ] T006 `auth/enforce.rs`（新、build_enforcer 段）：`MODEL` inline（r=p=sub,obj,act／g=_,_ 未用／m 三欄精確／allow-override）＋`build_enforcer(db)`（`DefaultModel::from_str(MODEL)`+`SeaOrmAdapter::new(db)`+`Enforcer::new`）＋`buttons_for_roles(enforcer,&roles)`（`get_filtered_policy(0,[role,"","button"])` 去重 union）；`server/src/model/facade/sys_user_role.rs` ＋`roles_for_user(db,user_id)->Result<Vec<String>,DbErr>`（組合 004 `find_role_ids_by_user_id`+`find_active_by_ids`→codes、清 §3.7 dead_code）。`auth/mod.rs`/`handler/mod.rs` +mod。
- [ ] T007 `server/src/main.rs` boot/router 重寫＋C-V-1 建置驗：boot＝db connect→`build_enforcer(db)`〔panic by design〕→讀 jwt secrets(_FILE)→`AppState`；router public `/health`（**保留不退化**、C-V-7）＋ auth 路由樁位（隨 US 接）。容器 `cargo build --bins` 綠＋`grep jsonwebtoken Cargo.lock ≥1`＋`grep ring Cargo.lock ≥1`（MSRV 編得過即證）＋`cargo test -p server` 純測綠（T002-004＋003/004 既有）。worktree commit＋pin bump。

**Checkpoint**: 認證地基就位（jwt/bearer/argon2 純測綠、AppState＋enforcer 單例 boot、roles_for_user／build_enforcer 掛載、`entity_access_lint` 續綠、build 綠）。

## Phase 3: US1 — 帳密登入發憑證對（P1 MVP；依賴 Foundational）🎯 MVP

**Goal**: `POST /auth/login` 驗帳密發 access+refresh pair、失敗一致防枚舉
**Independent Test**: login `Super`/`123456`→`code:"0000"`＋token pair；錯密碼/查無→`code:"1000"` 不可區分

- [ ] T008 [US1] `server/src/handler/auth.rs`（新、login 段）＋wire route：`login(State,Json<LoginReq{user_name,password}>)`（serde rename `userName`）→credential 失敗→`login_failed`(1000)：`find_active_by_name`→`Ok(None)`／`verify_password`→false／`status==Some(2)` 停用；**DB/系統錯誤→`internal`(5000、FR-002)**：`find_active_by_name`→`Err`／`roles_for_user`→`Err`／`issue_tokens` 簽發→`Err`；成功→`sign` access(jwt.access_secret/ttl)+refresh(refresh_secret/ttl)→`Res<LoginToken{token,refresh_token}>`(0000)。`main.rs` +`POST /auth/login`（public）。容器 `cargo build`/`cargo test -p server` 綠；worktree commit＋pin bump。
- [ ] T009 [US1] 实机 smoke（C-V-4 部分）：全棧 `up --wait`（front-nginx+base-web+rust-api+postgres+migrate）；curl `POST /api/auth/login {Super,123456}`→`code:"0000"`＋token/refreshToken 非空；錯密碼／查無→皆 `code:"1000"`（回應不可區分、帳號枚舉防護、SC-003）。worktree commit＋pin bump。

**Checkpoint**: US1 全綠＝登入地基就位（發憑證對＋失敗一致；SC-001/003 達成）。

## Phase 4: US2 — 受保護端點即時角色授權（P2；依賴 Foundational）

**Goal**: `enforce_mw` per-route 授權（DB-fresh role、三欄精確、fail-closed）
**Independent Test**: enforce-proof route——Super(有 policy)→200／無 policy role→403/5003／bad token→3333

- [ ] T010 [US2] test-first `auth/enforce.rs`（enforce_mw 段）：`enforce_mw(State,req,next)`——`verify_bearer`→None→`token_expired`(3333)／path+method／`roles_for_user`→**Err→fail-closed `permission_denied`(5003)＋`tracing::error`**（DESIGN line 686、research R6、**非放行非 internal**）／enforce loop `enforcer.enforce((role,path,method))`→任一 allow→`next`、全 deny→`permission_denied`(5003)；**剝 is_current 7777 gate**（028 波 3）。`#[cfg(test)]` enforce decision（§4）先紅後綠：三欄精確 allow/deny。
- [ ] T011 [US2] enforce-proof route（test/smoke-only、不污染 production router／endpoint_coverage_lint）＋实机 smoke（C-V-4 部分）：傾向 `#[cfg(test)]` 組裝 router＋`tower::ServiceExt::oneshot` in-process 打；live 注入拋棄式 policy `('p','R_SUPER','/__enforce_check__','GET')`→Super token→200／無 R_SUPER 合成 role token→403/5003／bad token→3333；測後清 policy（research R7）。worktree commit＋pin bump。

**Checkpoint**: US2 全綠＝per-route 授權機制就位（200/403/3333、fail-closed；SC-002 達成、波 0 出口「enforce curl 通」於 006 收）。

## Phase 5: US3 — 取使用者資訊＋換發憑證（P3；依賴 Foundational）

**Goal**: `getUserInfo`（身分摘要）＋`refreshToken`（stateless re-sign、反迴圈 8888）
**Independent Test**: getUserInfo(Bearer)→userId(string)/userName/roles/buttons([])；refresh→新 pair；壞 refresh→8888

- [ ] T012 [US3] `handler/auth.rs`（get_user_info 段）＋wire route：`get_user_info(State,HeaderMap)`→`verify_bearer`→None→`token_expired`／`find_active_by_id`→None/Err→`token_expired`／`user_name=nick_name.unwrap_or(user_name)`／DB-fresh roles→`buttons_for_roles`（現 `[]`）／**`user_id`:i64→string＋2^53 fail-loud 守衛**（⚠️r、超界→`internal` 不靜默截斷）→`Res<UserInfo{userId,userName,roles,buttons}>`(0000)。`main.rs` +`GET /auth/getUserInfo`（public、bearer-in-handler）。容器 build/test 綠；worktree commit＋pin bump。
- [ ] T013 [US3] `handler/auth.rs`（refresh_token 段）＋wire route：`refresh_token(State,Json<RefreshReq{refresh_token}>)`→`verify(refresh_token,refresh_secret,aud)`→**Err→`logout`(8888)**〔R2 反迴圈鐵律、**絕不**回 3333/9999/9998〕／成功→重發 access+refresh pair（stateless、無 reuse 偵測＝波 3）→`Res<LoginToken>`(0000)。`main.rs` +`POST /auth/refreshToken`（public）。容器 build/test 綠；worktree commit＋pin bump。
- [ ] T014 [US3] 实机 smoke（C-V-4 部分）：getUserInfo(Bearer `Super` token)→`code:"0000"`＋`data.userId`(string)/`userName`/`roles`(含 R_SUPER)/`buttons`([])；refresh(有效)→新 pair；refresh(壞)→`code:"8888"`（非 3333）；過期/竄改 token→getUserInfo `3333`。worktree commit＋pin bump。

**Checkpoint**: US3 全綠＝身分摘要＋換發就位（userId string／buttons 空／反迴圈 8888；SC-004/005 達成）。

## Phase 6: Polish & Cross-Cutting

- [ ] T015 CDP browser smoke（C-V-5、§3.6 directed）：base-web 指向真 rust-api（改 `.env` `VITE_SERVICE_BASE_URL`/proxy 或 smoke env、BASE-WEB-ADAPT 軌）；CDP `:9229`（origin `localhost`≠`127.0.0.1`）；pwd-login `Super`/`123456` submit→攔截器讀 `/auth/login` envelope `code:"0000"`→存 token→`/auth/getUserInfo` envelope 解析→userInfo 填；**驗到此止**（`VITE_AUTH_ROUTE_MODE=static`→不呼 getUserRoutes、route-mount 延波 2）。證 base-web 攔截器對真 rust-api envelope 判讀正確（curl 直送 ≠ base-web 判讀）。沿用 tests/000 scripts 形。
- [ ] T016 C-V-3 prod build＋C-V-6 殘留 grep＋C-V-7 /health：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（server 新 sea-orm-adapter path dep 的 COPY 無缺、rev2 COPY-gap 教訓）＋`grep -rinE "rev2|21079|21080|21081" rust-api/server/src/auth/ handler/auth.rs state.rs` 零＋`grep -rnE "rev2-admin" rust-api/server/src/auth/` 零（JWT_ISS/AUD=rev3-admin）＋部署層 grep 零＋`grep -nE 'async fn health|"ok"' main.rs` 不變；拋棄式卷清理（`docker volume rm cv006-target`、停全棧）。
- [ ] T017 收口驗證（**commit only——push／merge 凍結至 finishing，§I.4／⚠️u**）：worktree 全 task commit 齊＋outer pin==worktree HEAD（per-task bump 紀律回顧）＋specs/006 外層檔全收（已隨 speckit auto-commit）＋`git submodule status` 行首空格。**非新 crate ⇒ 無 Dockerfile 改動**（C-V-3 prod build 為防 COPY-gap 驗、非新 crate 收口項）。

## Dependencies

```
Phase 1 (T001) ──→ Phase 2 Foundational (T002[P]/T003[P]/T004[P] → T005 → T006 → T007) ──→ ┬─ US1 (T008→T009)
                                                                                          ├─ US2 (T010→T011)
                                                                                          └─ US3 (T012→T013→T014)  ──→ Polish (T015→T016→T017)
Foundational（jwt/bearer/password 純＋state/error/enforce-build/roles_for_user/boot）= blocking 全 US；三 US 各自 handler+route+smoke、相互獨立（共用 Foundational）。
build 序＝依賴序（Foundational→US1/2/3）、**非 spec 優先序**——US1 P1 MVP 但其地基在 Foundational；三 US 接好地基後可並行（不同 handler 段、但同檔 handler/auth.rs＋main.rs，單 implementer 序列較穩）。
test-first：jwt/bearer/argon2（T002-004 純測先紅後綠）／enforce decision（T010）；实机 smoke（T009/T011/T014 全棧 curl）＋CDP（T015）。
```

## Parallel Execution Examples

- Phase 2：T002/T003/T004（jwt/bearer/password 三純檔、無互依）可並行；T005→T006→T007 序列（state/error→enforce-build/roles→boot）。
- US1/US2/US3：接好 Foundational 後概念上獨立（各自 handler 段+route+smoke）；但 `handler/auth.rs`＋`main.rs` 為共用檔、單 implementer 序列（US1→US2→US3 或優先序）較穩、避免同檔衝突。
- story 內 test→impl 嚴格序列（純函式 red→green）；实机 smoke 在該 story handler 就緒後。

## Implementation Strategy

**地基先行、三 US 薄層**：Phase 2 Foundational（jwt/bearer/argon2 純＋state/error/enforce-build/roles_for_user/boot）＝stateless 認證地基；US1（login）＝P1 MVP 薄層（接地基的 login handler+route+smoke）、可獨立交付驗收（發憑證對）；US2（enforce_mw+proof）＋US3（getUserInfo+refresh）各為授權/身分薄層。每 phase checkpoint 過了才前進；test-first 嚴格 red→green；**非新 crate ⇒ 無 mandatory prod build**（但 C-V-3 跑一次防 server→sea-orm-adapter COPY-gap）。任一純測 fail＝對 R1/R2/R3 grep 座標校形、不調測試遷就實作（jwt 紅校 R1／enforce 紅校 R3／wire envelope/反迴圈紅校 R2）。⚠️ refresh 失敗 8888（非 3333）／userId string 2^53／enforce DB-error fail-closed 5003 三條為 implementer 易錯點（plan §實作注意 2-4）。
