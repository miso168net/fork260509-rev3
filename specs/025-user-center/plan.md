# Implementation Plan: 个人中心（自助檢視/編輯資料 ＋ 修改密碼）

**Branch**: `025-user-center` | **Date**: 2026-07-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/025-user-center/spec.md`

## Summary

把 `/user-center` 的 `<LookForward/>` 佔位換成真個人中心：**4 區塊頁**（基本资料〔含 created/updated 唯讀列〕/手机/邮箱/改密码，naive `NForm`+`NCard`、版面複刻 `form/basic`＋`function/request`）＋**3 auth-only self 端點**（getProfile/updateProfile/changePassword、operator=`claims.uid`、免 casbin）＋**2 支窄寫 facade fn**（`update_own_profile` 寫 gender/nick/phone/email、`change_own_password` 寫 password；皆 §I.6 成對＋op-log redact）＋**喚醒 024 dormant `password_policy`**（改密碼 `find_all→from_settings→validate_password_complexity(&policy,新密,user_name)→verify(舊密)→hash→窄寫`）。前端動態密碼 rule 取自 `getSystemSettings`＋後端權威。created/updated 顯示語意分類（system/self/admin、僅管理員更新才顯示、不洩露 operator）。**零 migration**。

## Technical Context

**Language/Version**: Rust 1.86（rust-api）+ TypeScript / Vue 3（base-web）

**Primary Dependencies**: axum + SeaORM（後端）；naive-ui `NForm`/`NCard`/`NInput`/`NRadioGroup`/`NButton`（前端）

**Storage**: PostgreSQL（既有 `sys_user` 16 欄、**零 migration**）

**Testing**: cargo test（rust、容器內 `docker exec`、live serial `--test-threads=1`）+ pnpm typecheck；acceptance＝curl + psql + CDP（`contracts/verification-commands.md`）

**Target Platform**: Linux 容器（docker compose dev/prod）

**Project Type**: web（base-web 前端 + rust-api 後端、worktree+submodule 傘狀 monorepo）

**Performance Goals**: 自助端點罕用非熱路徑（改密碼現查政策 DB-fresh、不需快取）

**Constraints**: 3 auth-only 端點／2 窄寫 facade fn／**零 migration／零新 workspace crate／零 casbin seed**；`password_policy.rs` 喚醒（移除 `#![allow(dead_code)]`）；**MODAL-WIRING (g) amendment 已落（v1.3.0、⚠️ah、commit `63d35179`）**

**Scale/Scope**: 4 卡頁（+ 4 子元件）／3 端點 handler ＋ 2 facade fn ／`AS_BUILT_ROUTES` 50→53

## Constitution Check

*GATE: Phase 0 前須評估、Phase 1 後複查。* 對照 constitution **v1.3.0**（本刀 (g) amendment 後）§IV 九問：

| # | 檢查 | 裁定 |
|---|---|---|
| 1 | §I.1 base-web 權威（rust-api 缺 endpoint？）| ✅ PASS — 3 個新 self 端點前後端**同刀新增**、無缺口 |
| 2 | §IV.2 動 base-web inline？MODAL-WIRING (a)~(g)？| ✅ **gate CLEARED** — 改 `views/user-center/index.vue`（非-manage）＝**新用途 (g)**；**amendment 已落**（constitution v1.2.0→v1.3.0、§III.2 加 (g)、⚠️ah、commit `63d35179`、025 feature branch、user 親決 A）。`page.userCenter.*` 綁 (g)。實質不同於 024 ⚠️ag〔既授 (e) 頁內、不 bump〕：本刀跨出 `views/manage/**` 邊界、故 MINOR amend |
| 3 | §I.2 menu Casbin enforce？| ✅ N/A — `route.user-center` `hideInMenu:true`、無 menu 顯示/enforce 改 |
| 4 | §I.3 wire 對齊 typings？| ✅ PASS — 3 新 wire（新 typings 循 ADAPT declaration-merge）；biz 訊息 2222+i18n key（複用 `biz.password.tooWeak/mismatch`＋新 `oldMismatch`＋`biz.user.notFound`）、**13 碼矩陣不擴張**；`password` 永不上 wire |
| 5 | §I.5 從 rev2 拷貝 code？| ✅ PASS — handler/facade/前端全新寫；喚醒 024 dormant（自家碼）|
| 6 | §II 拍板 #1~#13 抵觸？| ✅ PASS — 無反轉（#12 brainstorm 落 `docs/superpowers/025-user-center.md`）|
| 7 | §III ★ 軌道？授權邊界內？| ✅ PASS — MODAL-WIRING (g)（#2 已 amend）；`backend.biz.password.*`→BASE-WEB-I18N-WIRING(⚠️aa)；新 typings→ADAPT／新 `rev3-user-center.ts` wrapper→WRAPPER／新 handler·facade→RUSTAPI-SOURCE-ISOLATION |
| 8 | §I.6 新建業務表含六審計欄？| ✅ N/A — **零 migration**（sys_user 欄早齊）；2 窄寫 fn 寫既有表 `updated_at`/`updated_by` **成對**（§I.6 合規）、operator=claims.uid |
| 9 | §I.7 行為島 invariants 保持？| ✅ PASS — 改密碼不改 token rotation/policy governance/single-session 不變式（「改密後撤 session」屬未來、非本刀）|

**Initial Gate 結論**：**9/9 通過**（#2 MODAL-WIRING (g) amendment 已落實、gate CLEARED、constitution v1.3.0）。可進 Phase 0/1。

**Post-Design 複查（Phase 1 後）**：設計未引入額外違反——2 窄寫 facade fn 守 facade-only＋§I.6 成對＋op-log redact；getProfile created/updated 語意解析不洩露 operator（不 join）；3 端點 auth-only（`AS_BUILT_ROUTES` 50→53、免 seed）；喚醒 024 原語（消費既測純函式）；前端 4 卡皆新檔/換佔位、循 (g)＋ADAPT/WRAPPER＋I18N-WIRING。**Gate 9/9 不變、可進 `/speckit-tasks`。**

## Project Structure

### Documentation (this feature)

```text
specs/025-user-center/
├── plan.md              # 本檔
├── research.md          # Phase 0：R1~R13 決策
├── data-model.md        # sys_user 讀寫子集 + wire DTO + created/updated 語意 + 驗證規則
├── quickstart.md        # 驗證流程
├── contracts/
│   ├── user-center-contract.md       # 3 auth-only 端點 + DTO + biz 碼 + created/updated + 024 消費
│   └── verification-commands.md       # C-V：curl/psql/CDP + 三守恆 + prod build
└── tasks.md             # /speckit-tasks 產（本步不產）
```

### Source Code（worktree）

```text
rust-api/                                        ← worktree（submodule pin）
├── server/src/
│   ├── handler/user_center.rs                   # 新：3 auth-only handler（getProfile/updateProfile/changePassword）+ DTO + created/updated 語意 + 改密碼消費 024
│   ├── handler/mod.rs                           # +mod user_center
│   ├── model/facade/sys_user.rs                 # +update_own_profile +change_own_password（2 窄寫 fn、§I.6 成對、op-log redact）
│   ├── auth/password_policy.rs                  # 移除 `#![allow(dead_code)]`（喚醒 dormant）
│   ├── main.rs                                  # +user_center router（route_auth 範式、enforce_mw、無 require_policy）+ merge
│   └── tests/endpoint_coverage_lint.rs          # AS_BUILT_ROUTES 50→53（3 auth-only 路徑）

base-web/                                        ← worktree（submodule pin）  ★MODAL-WIRING (g)
├── src/views/user-center/index.vue              # 換 LookForward → 4 卡容器（root flex-col-stretch gap-16px 修 overflow）
├── src/views/user-center/modules/               # 新：basic-info-card / phone-card / email-card / password-card
├── src/service/api/rev3-user-center.ts          # 新：fetchGetProfile/fetchUpdateProfile/fetchChangePassword  ★WRAPPER
├── src/typings/api/rev3-user-center.d.ts        # 新：profile/changePwd DTO  ★ADAPT
├── src/typings/app.d.ts                         # +App.I18n.Schema page.userCenter.* + backend.biz.password.*（先 Schema）
└── src/locales/langs/{zh-cn,en-us}.ts           # +page.userCenter.*（含 origin.*/verify.comingSoon）+ backend.biz.password.* 補缺  ★I18N-WIRING
```

**Structure Decision**：沿用 worktree+submodule 結構（CLAUDE.md §1）。後端集中：1 新 handler 檔（3 端點）＋sys_user facade 加 2 窄寫 fn＋喚醒 password_policy；前端 1 頁換佔位＋4 子卡＋wrapper/typings/i18n。所有寫入走既有 `mutate_in_txn`+§I.6；讀端 `find_active_by_id`+`roles_of_user`。

## Complexity Tracking

> 無須 justified 的 Constitution 違反（gate 9/9 通過）。以下登備查：

| 項目 | 說明 |
|---|---|
| **MODAL-WIRING (g) amendment（已落）** | `views/user-center`（非-manage）需新用途 (g)；constitution v1.2.0→v1.3.0 MINOR、⚠️ah、commit `63d35179`（025 feature branch，比照 023 ⚠️af 範式、隨收刀 merge 回 root）。user 親決 A。**收刀回填**：DECISIONS ⚠️ah 的 merge hash/pins/as-built＋MILESTONES §1 一行 |
| **喚醒 024 dormant `password_policy`** | 移除 `#![allow(dead_code)]`——024 刀刻意 dormant、025 為其 live 消費者（政策先行 2 刀組收尾）|
| **零 migration／§I.6 既有表窄寫** | sys_user 欄早齊；2 窄寫 fn 寫 `updated_at`/`updated_by` 成對＝§I.6 合規、非新表 archetype |
