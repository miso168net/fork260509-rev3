# Implementation Plan: auth-island-min（stateless JWT login/refresh/getUserInfo＋casbin per-route enforce）

**Branch**: `006-auth-island-min` | **Date**: 2026-06-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-auth-island-min/spec.md`＋brainstorm `docs/superpowers/006-auth-island-min.md`（合刀 Auth＋第二 audit 拆 006→007 序列之首；token stateless 全 wire／enforce test-smoke-only proof／驗證 純測+全棧 curl+CDP／JWT secret _FILE／buttons 現空／無 migration 無新 crate）

## Summary

把 rust-api 的 **stateless 認證地基**一次立起：`auth/jwt.rs`（HS256 sign/verify、Claims 最小〔剝 sid/jti〕、access/refresh 兩 secret）＋`auth/bearer.rs`（bearer 抽取/驗證）＋`auth/enforce.rs`（casbin 2.20＋vendored sea-orm-adapter 的 `build_enforcer`＋per-route `enforce_mw`〔subject＝DB-fresh role code、三欄精確相等、剝 single-session 7777 gate〕）＋`auth/password.rs`（argon2 verify）＋`handler/auth.rs`（`login`〔argon2 驗＋停用 gate＋發 pair〕／`refresh_token`〔**stateless re-sign**、失敗→8888 反迴圈〕／`get_user_info`〔userId string⚠️r／userName=nick_name‖user_name／buttons casbin-dim 現空〕）＋`state.rs`（`AppState{db,jwt,enforcer}`、jwt secret `_FILE`、剝 redis/session_mode）＋`error.rs` 加 `From<DbErr>`/`From<casbin::Error>`（§3.6 泛型 fallback）＋`main.rs` boot/router 重寫（public 3 端＋health；enforce-gated＝test/smoke-only proof route）。驗證：純測（jwt/bearer/argon2/enforce-decision，test-first 零 DB/HTTP）＋bounded 全棧 curl（login→getUserInfo→enforce-proof→refresh）＋**CDP browser smoke**（base-web 攔截器解析真 rust-api envelope、首個信封 handler 刀 §3.6 directed）。**無 migration**（schema＋policy 在 m001-m004）；**非新 crate**（server 內加模組）；deps +`jsonwebtoken 9`（MSRV ≤ 1.86 已驗）。**有狀態 token rotation/single-session/session_mode/redis 全剝＝波 3；access-log/login-attempt/audit_ctx/xdb＝007；getUserRoutes/menu＝波 2。**

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-toolchain.toml`、001 落值）

**Primary Dependencies**: 既有 `entity`/`sea-orm-adapter`（002 vendored、path）；server crate 加 `jsonwebtoken = "9"`（**新**、root workspace+server；rev2 用 9、rev3 lock 無、MSRV ≈1.63＋ring 0.17 MSRV 1.61 ≤ 1.86 ⇒ 安全、§3.8/R5）＋`argon2 0.5.3`/`casbin 2.20`（已在 workspace deps+lock〔002/004〕、加進 server）＋`sea-orm-adapter`（path、build_enforcer 用）。axum/tokio/sea-orm（workspace）不動。**無 redis**（stateless）。

**Storage**: PostgreSQL（讀 `sys_user`〔login/getUserInfo〕＋`sys_role`/`sys_user_role`〔roles〕＋`casbin_rule`〔enforcer load＋button policy〕；schema＝m001、seed＝m002〔user/role/policy〕+m004〔menu policy〕；**本刀無 migration、無 schema/seed 變動**）。

**Testing**: `cargo test`——**test-first 純函式**（jwt sign/verify roundtrip+竄改/過期(leeway=0)/aud reject／bearer 抽取／argon2 roundtrip／enforce decision 三欄、**零 DB/HTTP**）＋**bounded 全棧 curl 实机 smoke**（front-nginx+base-web+rust-api+postgres+migrate；login Super/123456→getUserInfo→enforce-proof〔注入拋棄式 policy〕→refresh）＋**CDP browser smoke**（base-web pwd-login→攔截器解析 login/getUserInfo envelope；static 模式止於 getUserInfo）。

**Target Platform**: 005 交付 entity crate＋server model/（facade＋audit）；本刀加 server `auth/`+`handler/`+`state.rs`+改 `main.rs`/`error.rs`，不改 stack 拓撲（無新 service/crate）。

**Project Type**: backend infra（首個對外 HTTP handler 刀＋首個 envelope runtime 消費者＋首個 enforce 機制）

**Performance Goals**: N/A（⚠️a 效能數字屬波 1）

**Constraints**: stateless（無 sys_token/session/redis、Claims 無 sid/jti、enforce/getUserInfo 無 session gate）／enforce subject＝DB-fresh role（非 JWT claims、§5.3）／三欄精確相等無 glob／enforcer 單例 `Arc<RwLock>` 無 cache／JWT HS256 leeway=0／JWT_ISS/AUD＝"rev3-admin"／refresh **stateless re-sign**、失敗→8888（反迴圈鐵律 R2、**不得**回 3333/9999/9998）／userId string＋2^53 fail-loud（⚠️r）／enforce role-lookup DbErr→**fail-closed 5003**（DESIGN §10.1、R6）／handler 回 envelope（003、FR-009）／facade-only entity 存取（entity_access_lint 續綠）／rust-api 全新寫（⚠️g、rev2 受控參照）／無 migration／JWT secret `_FILE`。

**Scale/Scope**: `auth/{jwt,bearer,enforce,password}.rs`＋`handler/auth.rs`（3 handler+DTO）＋`state.rs`＋`facade/sys_user_role.rs` +`roles_for_user`＋`error.rs` +2 From impl＋`main.rs` boot/router＋deps＋驗證（純測+全棧 curl+CDP）。

## Constitution Check

*constitution-rev3 v1.0.0 §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威／缺 endpoint？ | **PASS**——006 實作 base-web wire 的 `/auth/login`/`getUserInfo`/`refreshToken`（auth.ts）、形對齊 typings；其餘端點（getUserRoutes/systemManage）屬波 2/1、base-web 現 `static` 模式不呼 getUserRoutes ⇒ 無「缺 base-web 呼叫的 endpoint」。endpoint 覆蓋波次遞增 |
| 2 | 動 base-web inline？ | **PASS**——僅可能改 base-web `.env`（指向真 rust-api 供 CDP smoke、BASE-WEB-ADAPT L1+L2 軌授權內）；**不動 views/manage inline**、不觸 MODAL-WIRING ★ |
| 3 | menu 走 Casbin enforce？ | **PASS（N/A）**——無 menu 端點；getUserInfo buttons 走 casbin `get_filtered_policy`（讀已載 policy、§5.3 形）；menu 端點屬波 2 |
| 4 | wire 對齊 §I.3 不變式？ | **PASS**——login/getUserInfo/refresh DTO 逐欄對齊 base-web typings（LoginToken/UserInfo、userId string⚠️r、camelCase serde rename）；envelope code 字串/success "0000"；refresh 反迴圈 8888（R2 wire 紀律）|
| 5 | 拷 rev2 source？ | **PASS（全新寫合規）**——auth/jwt/bearer/enforce/password/handler/state 全新寫（⚠️g 讀允許拷貝禁止）；sea-orm-adapter 為 002 已 vendored 例外（§I.5、不重拷）；防回歸：rev2 的 session/token-state（sid/jti/is_current/session_mode/sys_token）**未照拷**（本刀 stateless 剝離） |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——§I.2（前端零過濾、後端 enforce）＋⚠️c（auth 端點）＋⚠️r（id-string）＋§5.3（per-route enforce、即時角色、三欄精確）直接落實；無拍板需改 |
| 7 | 觸 §III ★ 軌道？ | **PASS（授權邊界內）**——觸 `RUSTAPI-SOURCE-ISOLATION`（rust-api 全新寫、已授權）＋`BASE-WEB-ADAPT`（.env 指向、L1+L2 預設可動）；**不觸 MODAL-WIRING ★／BUILD-CONFIG ★**（不動 views/manage、不動 router.ts pageExclude） |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——**無 migration、無新表/seed**（user/role/policy 在 m002/m004；本刀純 Rust 層 auth/handler/state） |
| 9 | 觸 §I.7 行為島？ | **PASS（刻意剝離）**——006 **stateless、明確剝除行為島部分**（token rotation/single-session/session 三態機＝波 3 §4.1/§4.3）；本刀無非平凡狀態機（JWT 自帶、無 server-side session 查找） |

**Gate 結論：9/9 PASS，無需 amendment、無 violation 待 justify。**（一個 spec↔DESIGN 措辭差〔FR-005 fail-closed 5003〕非 violation、交 `/speckit-analyze` 校正、見 research R6。）

## Project Structure

### Documentation (this feature)

```text
specs/006-auth-island-min/
├── spec.md              # /speckit-specify ✅（US1 登入發憑證 P1/US2 即時角色授權 P2/US3 取資訊+換發 P3＋13 FR＋8 SC）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 rev2 013 簽名+剝離線／R2 wire 3 端〔code"0000"/expired 3333/refresh 反迴圈 8888〕／R3 casbin+adapter+seeded policy／R4 argon2 roundtrip／R5 deps+MSRV〔jsonwebtoken 9 安全〕／R6 From+FR-005 校正／R7 enforce-proof+CDP 形）
├── data-model.md        # Phase 1 ✅（jwt/bearer/enforce/password/state/handler DTO/roles_for_user/From/排除）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── auth-contract.md          # jwt/bearer/argon2 純測＋enforce 判定＋handler envelope＋全棧 smoke＋CDP 斷言
│   └── verification-commands.md  # C-V-1~7（build+MSRV／純測／prod build／全棧 curl／CDP／殘留 grep／health）
├── checklists/requirements.md    # 16/16 ✅（specify）
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
├── rust-api/                          # worktree（兩段式 commit）
│   ├── Cargo.toml                     # +jsonwebtoken 9（workspace dep；MSRV ≤ 1.86 已驗）
│   └── server/
│       ├── Cargo.toml                 # +jsonwebtoken/argon2/casbin/sea-orm-adapter(path)
│       └── src/
│           ├── main.rs                # ★ 重寫 boot（db→build_enforcer→讀 secrets→AppState）＋router（public 3 端+health；enforce-gated proof〔test/smoke-only〕）；/health 保留
│           ├── state.rs               # ★ 新 AppState{db,jwt,enforcer}＋JwtConfig（_FILE、剝 redis/session_mode）
│           ├── error.rs               # ＋From<DbErr>/From<casbin::Error>→internal（§3.6 泛型 fallback）
│           ├── auth/
│           │   ├── mod.rs             # ＋pub mod jwt/bearer/enforce/password
│           │   ├── jwt.rs             # ★ 新（HS256 sign/verify、Claims 最小〔無 sid/jti〕、零 entity::）
│           │   ├── bearer.rs          # ★ 新（bearer_token＋verify_bearer）
│           │   ├── enforce.rs         # ★ 新（MODEL＋build_enforcer＋enforce_mw〔剝 7777 gate、fail-closed 5003〕＋buttons_for_roles）
│           │   └── password.rs        # ★ 新（argon2 verify/hash）
│           ├── handler/
│           │   ├── mod.rs             # ＋pub mod auth
│           │   └── auth.rs            # ★ 新（login/refresh_token/get_user_info＋DTO；refresh 失敗 8888／userId string 2^53）
│           └── model/facade/sys_user_role.rs  # ＋roles_for_user helper（消費 004、清 §3.7 dead_code）
└── （無 migration、無 Dockerfile 改動——非新 crate；C-V-3 prod build 驗 server 對 sea-orm-adapter 既有 COPY）
```

**Structure Decision**: server 內加 `auth/`+`handler/` 模組＋`state.rs`（**非新 workspace crate** ⇒ CLAUDE.md §3「新 crate ⇒ prod build」紀律不觸發；但 server 首次依賴 sea-orm-adapter〔path〕，C-V-3 跑一次 prod build 確認既有 COPY 涵蓋、rev2 COPY-gap 教訓）。`entity_access_lint`（004 既立）守護：auth/handler/state 經 facade 取 entity、不碰 raw entity::（jwt/bearer 純無 entity）。

## Phase 0：研究結論

見 [research.md](research.md)——R1 rev2 013 actual 簽名逐項 grep＋**剝離線校**（jwt 剝 sid/jti/session_id／enforce 剝 is_current 028／login 剝 session_policy/sys_token／state 剝 redis/session_mode）／R2 wire 3 端對齊（envelope code 字串/success "0000"／expired 3333/modal 7777/logout 8888／**refresh 反迴圈鐵律：失敗回 8888 非 3333**／typings 逐欄／userId string）／R3 casbin MODEL inline＋`SeaOrmAdapter::new(db)`＋`enforce((role,path,method))`＋buttons `get_filtered_policy`〔現空〕＋roles_for_user 組合 004／R4 argon2 seed runtime 生成⇒純測 roundtrip 自含／R5 deps+MSRV〔jsonwebtoken 9+ring 鏈 ≤ 1.86 安全、§3.8 解除〕／R6 From fallback＋**spec FR-005 校正**（DESIGN fail-closed 5003 權威、wire 不可區分、log 區分）／R7 enforce-proof test-smoke-only〔in-process oneshot+拋棄式 policy〕＋CDP 形〔base-web .env 指向真 rust-api、static 止於 getUserInfo〕。NEEDS CLARIFICATION＝0。

## Phase 1：設計產物

- [data-model.md](data-model.md)：jwt/bearer/enforce/password/state 型＋handler DTO（serde rename camelCase 對齊 typings）＋roles_for_user＋From impl＋結構守恆＋排除聲明。
- [contracts/auth-contract.md](contracts/auth-contract.md)：jwt/bearer/argon2 純測＋enforce 三欄判定＋handler envelope（login 0000/1000、refresh 8888 反迴圈、getUserInfo userId-string、enforce 200/403/3333、DB fail-closed 5003）＋全棧 smoke＋CDP 斷言。
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V-1~7（build+MSRV／純測／prod build／全棧 curl／CDP／殘留 grep〔含 rev3-admin〕／health）。
- [quickstart.md](quickstart.md)：從零驗證指南＋反迴圈/2^53/fail-closed/stateless/static 注意。

## 實作注意（移交 tasks）

1. **順序**：deps（workspace+server +jsonwebtoken／server +argon2/casbin/sea-orm-adapter）→ `auth/jwt.rs`+`bearer.rs`+`password.rs`（純、test-first 先紅後綠）→ `state.rs`（AppState/JwtConfig、_FILE）→ `auth/enforce.rs`（MODEL+build_enforcer+enforce_mw、剝 7777）→ `facade/sys_user_role.rs` +roles_for_user → `handler/auth.rs`（login/refresh/getUserInfo、reuse 004 facade）→ `error.rs` +From → `main.rs` boot/router 重寫 → enforce-proof（test/smoke-only oneshot）→ C-V（build/MSRV→純測→prod build→全棧 curl→CDP→殘留 grep）→ **兩段式 commit（worktree 逐 task、outer pin 隨同 bump——001-005 教訓）**。
2. **⚠️ refresh 反迴圈鐵律（R2）**：`/auth/refreshToken` 驗 refresh JWT 失敗→`logout()`(8888)、**絕不**回 token_expired(3333)/9999/9998（否則 base-web 攔截器 refresh 死循環；官方 docs guide/request/usage.md 紀律）。
3. **⚠️ userId string + 2^53（⚠️r）**：getUserInfo `user.id`(i64)→string、超 2^53→fail-loud（`internal`、不靜默截斷；003 §3.6 ⚠️r 首個落點）。
4. **⚠️ enforce DB-error fail-closed 5003（R6/DESIGN §10.1）**：role-lookup DbErr→`permission_denied()`(5003)＋`tracing::error` log（**非**放行、**非** internal、**非** 3333）；spec FR-005「可區分」讀為 log 層、交 `/speckit-analyze` 校正措辭。
5. **stateless 剝離紀律（⚠️g）**：rev2 的 session/token-state（sid/jti/session_id/session_policy/is_current/session_mode/redis/sys_token）**不照拷**；只取 minimal auth（jwt/bearer/enforce/login/refresh/getUserInfo）；refresh stateless re-sign、無 reuse 偵測（波 3）。
6. **結構保證**：jwt/bearer 純零 entity::；enforce/handler 經 facade（find_active_by_*/roles_for_user）取 entity、`entity_access_lint` 續綠；handler 回 envelope、不 re-export Entity；JWT_ISS/AUD＝"rev3-admin"（殘留 grep 守）。
7. **非新 crate / prod build**：server 內加模組⇒無強制 prod build；但 server 首次依賴 sea-orm-adapter（path）→ C-V-3 跑一次 prod target build 確認 COPY 無缺（rev2 COPY-gap 教訓）。
8. **CDP（§3.6 directed）**：base-web 指向真 rust-api（改 `.env`/proxy 或 smoke env、BASE-WEB-ADAPT 軌）；`static` 模式→驗到 login→getUserInfo+envelope 解析止、route-mount（getUserRoutes）延波 2。
9. **push/merge 全凍結（§I.4/⚠️u）**：實作期 commit only；tasks.md 不得出現 push／merge 步驟。
10. **失敗處置**：jwt/bearer/argon2/enforce 純測紅＝對 R1/R3 校；wire 對齊紅（全棧 curl/CDP）＝對 R2 校 DTO/envelope code/refresh 反迴圈；MSRV 紅＝對 R5 校 deps 版（cargo update --precise）。
