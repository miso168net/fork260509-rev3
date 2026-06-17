# Implementation Plan: 006-auth-island-min（Auth 島最小段＝login＋getUserInfo＋enforce 最小鏈）

**Branch**: `006-auth-island-min` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/006-auth-island-min.md`（三刀界 user 拍板：single-session=建 pointer＋is_current gate／refresh=延波3／JWT 密鑰=_FILE 優先）

## Summary

L5-L7 **Auth 島最小段＋runtime 骨幹第一刀**：rust-api 至今仍 001 空殼（main.rs 僅 `/health`、無 `AppState`/DB/auth），006 第一次接 `config`（DB URL＋兩把 JWT 密鑰，`_FILE` 優先〔001 已 provisioned〕）→ DB pool → `AppState{ db, jwt, enforcer }` → Casbin `Enforcer`（`SeaOrmAdapter::new(db)`＋embedded 3-tuple RBAC model `from_str`、自 `casbin_rule` 載）→ bootstrap，並接：`POST /auth/login`（argon2id verify＋簽 JWT access/refresh＋`set_pointer`＋INSERT `sys_token`、plain txn 原子、失敗 collapse 1000）／`GET /auth/getUserInfo`（bearer→is_current→DB-fresh roles＋真 buttons〔Casbin `v2='button'`〕、`userName`=nick_name〔User→User01 alias〕、`userId`=string）／`enforce_mw`（bearer〔3333〕→is_current〔7777〕→Casbin `enforce((role,path,method))`〔5003〕）。完整 rotation/refresh/session 熱切換/cleanup＝波3；動態選單/getUserRoutes＝波2；登入事件審計＝007。對應前代 013。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-toolchain.toml` 嚴格 pin）

**Primary Dependencies**: server 加 dep——**新**：`jsonwebtoken`（HS256、⚠️ time-pin、R-B）／`uuid`（sid/jti/rotation_chain）／`sha2`（token_hash＝sha256(refresh)）；**已 workspace、加 `{workspace=true}`/`{path}`**：`argon2`(0.5.3)／`casbin`(2.20)／`sea-orm-adapter`(path)；已有：`axum`/`serde`/`serde_json`/`tokio`/`sea-orm`/`entity`。**無 chrono 直接 dep**（now 走 `sea_orm::sqlx::types::chrono::Utc::now()`）。

**Storage**: PostgreSQL（既有 dev stack、002 schema＋seed）。**本刀無 migration、無建表、無 schema 變更**（`sys_user`/`sys_token`/`sys_role`/`sys_user_role`/`casbin_rule` 皆 002 建齊＋seed）。**Redis 不接**（single-session 走 DB-only、pub/sub＝波3）。

**Testing**: rust in-crate `#[cfg(test)]` 純函式測（JWT sign/verify roundtrip＋過期/壞簽 reject、argon2id verify、claims 解析、Casbin enforce decision seam〔對 seeded policy allow/deny〕）＋live curl 鏈（login→getUserInfo→enforce、deny 3333/5003、7777、1000；psql 驗 sys_token/current_session_id）＋CDP（1000 i18n toast、§3.6）＋既有 `entity_access_lint`（守 auth/handler lint-clean）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。**含 prod target image build**（加 dep、R-I）。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內）。

**Project Type**: backend（rust-api workspace）——L5 auth/domain＋L7 router/middleware＋L4 facade，跨 §1.5 多層。

**Performance Goals**: login p95 < 1s（⚠️a 拍板保守預設）；其餘端點 N/A（本刀僅 auth 最小面）。

**Constraints**: RUSTAPI-SOURCE-ISOLATION（auth/enforce 全新寫、§I.5、不在拷貝例外〔唯 sea-orm-adapter/xdb〕、前代 013 受控參照）；**無 migration**（schema 002 凍）；§I.7 single-session first-mount forward-compat（不 bake session_mode、見 Constitution Check Q9）；wire 對齊 §I.1/§I.3（base-web 權威、userId=string）；JWT 密鑰 `_FILE` 優先（§3.4 拍板）；**time-pin landmine**（R-B、加 jsonwebtoken 後 `cargo tree -i time`）；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: 3 端點（login/getUserInfo + enforce_mw layer）＋runtime 骨幹（config/state/bootstrap/enforcer init）＋auth 機制 4 檔（jwt/bearer/password/enforce）＋facade 4 檔（sys_token/sys_user_role 新、sys_user/sys_role 加 fn）＋error From<DbErr>＋main.rs 改。新增 dep 5（3 新 2 workspace-expose）＋sha2。**零 migration/schema/base-web/i18n 變動**。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 為權威？rust-api 缺對應 endpoint？ | **PASS**——006 提供 base-web wire 權威要求的 `/auth/login`＋`/auth/getUserInfo`＋enforce gate（對齊 `auth.ts`/`auth.d.ts`）；不縮減設計範圍（refresh 端點/動態選單為排程遞延、非範圍縮減、§I.1「v1 從簡＝排程」） |
| 2 | 動 base-web inline？ | **PASS（未觸）**——零 base-web 改動（i18n 已隨 003 ⚠️aa ship；static route mode 維持、不 flip） |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（未觸 menu）**——006 建 enforce 機制本體，但 menu/getUserRoutes＝波2 Menu 刀；本刀無 menu／route 端點 |
| 4 | wire 對齊 §I.3 typings？ | **PASS**——LoginToken/UserInfo DTO 對齊 `auth.d.ts`（`userId`=string〔⚠️r〕、roles/buttons=string[]）；envelope/13 碼遵 003 凍結（1000/3333/7777/5003）；base-web 為唯一權威、mock 僅 fixture |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——auth/enforce 全新寫（§I.5；不在拷貝例外〔唯 sea-orm-adapter/xdb〕）；前代 013 受控參照（讀允許、拷貝禁止）；防回歸：不帶回 ⚠️r 廢除的 id-string〔本刀正用 string、無衝突〕／⚠️e 廢除的 Internal→HTTP500〔用 5000→HTTP200〕 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——#1（`Super/Admin/User`＋User→User01 alias〔nick_name seed〕）honored；#7（dynamic route mode）目標不變、006 維持 static 至波2 Menu 刀＝排程（非範圍縮減）；#11（`/api` 前綴 nginx strip、router 登記無前綴 `/auth/*`）對齊；無拍板需改 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸 ★）**——rust-api 走 RUSTAPI-SOURCE-ISOLATION（§III.1 預設可動）；無 base-web inline 改動（i18n ⚠️aa 已 003 ship）；無 MODAL-WIRING/BUILD-CONFIG ★ |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——無 migration、不建表（schema 002 已建；FR-017／SC-007）；§I.6 N/A（無建表） |
| 9 | 觸 §I.7 行為島？ | **PASS（觸 §4.3、invariants 全守）**——見下方 Q9 詳述 |

**Q9 詳述（§I.7 single-session §4.3）**：006 **觸** single-session 行為島，但僅 **minimal first-mount**、invariants 方向性全守：
- **守**：pointer-truth-in-DB（`current_session_id`）／`is_current` **fail-OPEN**（DB 抖動不誤踢）／7777 通道（pointer 比對失敗）／`set_pointer` 永遠執行（login 必寫）。bearer verify **fail-CLOSED**（安全、方向相反、刻意）。
- **遞延波3（非違反、forward-compat）**：session_policy 三態 × runtime `session_mode` 熱切換（006 無條件跑 gate、不 bake 靜態 session_mode 變數＝未實作可設定層、非 bake 違反值）；token rotation/reuse §4.1（006 寫 `rotation_chain`+`used_at=NULL` forward-compat、不實作 rotate 邏輯、無 refresh 端點）。
- **state-machine 鏡頭**：006 實作 pointer-set／is_current 兩 transition；rotate/reuse/session-policy transition 遞延波3。動 invariant 需 Amendment——006 **不動 invariant**（僅最小子集落地）⇒ 無 Amendment 需求。

**Gate 結論：9/9 PASS；無 violation 待 justify、Complexity Tracking 不適用。**

> **新 dep ⇒ prod build 紀律**：006 動 Cargo.toml（加 `jsonwebtoken`/`uuid`/`sha2`＋暴露 `argon2`/`casbin`/`sea-orm-adapter`），**非新 workspace crate**；故 acceptance **含 prod target image build**（C-V-5、R-I）——dev bind-mount 會遮 prod 編譯破口（time-pin/新 dep feature）。

## Project Structure

### Documentation (this feature)

```text
specs/006-auth-island-min/
├── spec.md              # /speckit-specify ✅（4 US／17 FR／9 SC／16-16 checklist）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1/R-A~R-I 全 ground-truth grep；推翻 2 brainstorm 假設）
├── data-model.md        # Phase 1 ✅（auth 型／JWT claims／facade 簽名／casbin model／DTO）
├── quickstart.md        # Phase 1 ✅（驗證流程）
├── contracts/
│   ├── verification-commands.md   # C-V-0~5（build／純測／live curl 鏈／CDP i18n／lint／prod build）
│   └── auth-island-contract.md    # login/enforce/single-session/wire 不變式
└── checklists/requirements.md     # 16/16 ✅
```

### Source Code (repository root)

```text
rust-api/server/src/
├── config.rs                 # ★ 新：讀 DB URL + 2 JWT 密鑰（_FILE 優先 env fallback、拒 change-me、長度守）
├── state.rs                  # ★ 新：AppState{ db: DatabaseConnection, jwt: JwtConfig, enforcer: Arc<RwLock<Enforcer>> }（無 Redis）
├── main.rs                   # 改：async build state + mount /auth/* + enforce layer + boot init enforcer
├── error.rs                  # 加：From<DbErr> for AppError（→5000）；既有變體 1000/3333/7777/5003 直接用
├── envelope.rs               # 003 既有（不動）
├── auth/                     # ★ 新（§I.5 L5/L7、全新寫）
│   ├── mod.rs
│   ├── jwt.rs                # HS256 sign/verify + Claims{ uid,sid,jti,rotation_chain,roles,iss,aud,exp,iat }
│   ├── bearer.rs             # extract Authorization: Bearer → verify → Claims（axum extractor/helper）
│   ├── password.rs           # argon2id verify（對 m002 PHC hash）
│   └── enforce.rs            # enforce_mw（bearer→DB-fresh role→is_current→Casbin enforce）+ model.conf embedded str
├── handler/                  # ★ 新
│   ├── mod.rs
│   └── auth.rs               # login, get_user_info
└── model/
    ├── mod.rs                # 加 pub mod 視需要
    └── facade/
        ├── mod.rs            # 加 pub mod sys_token; pub mod sys_user_role;
        ├── sys_token.rs      # ★ 新：insert_token（plain txn）
        ├── sys_user_role.rs  # ★ 新：role_ids_of_user / roles_of_user（join sys_role.code）
        ├── sys_user.rs       # 004/005 既有、加：find_by_user_name / set_pointer / current_session_id_of
        └── sys_role.rs       # 004 既有、加：codes_by_ids（或併 sys_user_role facade）

rust-api/server/Cargo.toml    # 加 dep：jsonwebtoken / uuid / sha2 / argon2(ws) / casbin(ws) / sea-orm-adapter(path)
# 不動：entity/、migration/、sea-orm-adapter/、deploy/（compose/secret 001 已 provisioned）、base-web/（i18n 003 已 ship）、server/tests/entity_access_lint.rs（既有續綠）
```

**Structure Decision**：backend（rust-api workspace）。L7 `main.rs`/`auth/enforce.rs`（router+middleware）＋L5 `auth/{jwt,bearer,password}.rs`/`handler/auth.rs`（auth/domain）＋L4 `model/facade/*`（entity 存取）＋L1 `config.rs`/`state.rs`（runtime 骨幹）。**無 entity/migration/base-web/deploy 改動**（地基 001-003 已 provisioned）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks）

1. **順序**：config/state（讀 secret、建 pool）→ auth/jwt（claims+sign/verify）→ auth/password（argon2 verify）→ facade（sys_user find/set_pointer、sys_user_role roles、sys_token insert）→ auth/enforce（model.conf embedded、enforcer init、enforce_mw、bearer、is_current）→ handler/auth（login/getUserInfo）→ main.rs（build AppState、mount、boot init enforcer）→ error From<DbErr> → 純測 → live curl → CDP → prod build → **兩段式 commit**（worktree → outer pin）。
2. **★ R-B time-pin（第一風險）**：加 `jsonwebtoken` 後**立刻** `cargo tree -i time`；若 real graph → `cargo update -p time --precise 0.3.37`＋pin `simple_asn1 0.6.3`（撞 1.86 MSRV 才需；inert 則註記）。
3. **R-C casbin**：`SeaOrmAdapter::new(db)`（idempotent up、casbin_rule 已存 no-op）→ `Enforcer::new(DefaultModel::from_str(MODEL), adapter)`；MODEL＝embedded 3-tuple RBAC（sub/obj/act、g）；enforce `(role, path, method)`；buttons `get_filtered_policy` 篩 v2='button' 取 v1。
4. **R-D token_hash**：`sha256(refresh_jwt)`（`sha2`）非 argon2；`now`/`expires_at` 走 sqlx-chrono Utc::now()/Duration。
5. **R-E wire**：DTO `userId=string`（i64→string、2^53 守衛）；`userName`=nick_name（alias 自然）；roles/buttons=string[]。
6. **R-F config**：沿 migration main.rs 模式讀 `APP_*_FILE` 優先；access=`APP_JWT_JWT_SECRET*`、refresh=`APP_JWT_REFRESH_TOKEN_SECRET*`；DB=`APP_DATABASE_URL*`。拒 change-me、長度 ≥32。
7. **R-G error**：直接構造既有 AppError 變體；唯一加 `From<DbErr>`（→Internal/5000）。i18n 零變動（003 已 ship）。
8. **§I.7 single-session**：is_current fail-OPEN／set_pointer 永遠／7777；bearer fail-CLOSED。不 bake session_mode。
9. **enforce 5003 demo**：getUserInfo auth-only（無 /auth/* policy）→ enforce_mw 對它＝bearer+is_current；casbin enforce/5003 由 **seam 測**對 seeded `/systemManage/*` policy 證（R_SUPER allow `/systemManage/deleteUser` DELETE、R_USER_COMMON deny）。
10. **lint 守恆**：auth/handler/config/state 不可 path-root `entity::`；entity 存取全在 facade（既有 `entity_access_lint` 續綠）。
11. **prod build／push 凍結**：加 dep → 必跑 prod image build（C-V-5）；實作期 commit only、tasks.md 不得出現 push/merge（§I.4）。
