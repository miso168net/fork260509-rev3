# Quickstart: 025-user-center 驗證指南

> 交付＝個人中心 4 卡頁（基本资料〔含 created/updated 唯讀列〕/手机/邮箱/改密码）＋3 auth-only self 端點＋2 窄寫 facade fn＋喚醒 024 `password_policy`、零 migration。細節見 [`contracts/user-center-contract.md`](contracts/user-center-contract.md)、C-V 見 [`contracts/verification-commands.md`](contracts/verification-commands.md)。

## 前置
- dev stack up：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`。
- rust 命令容器內：`docker compose … exec -T rust-api <cmd>`；live serial `--test-threads=1`；改 `.rs` 先 force-touch。
- **加 i18n 鍵後 `restart base-web`**（vite stale-locale、CDP toast 驗前先做）。

## 1. 後端（3 auth-only 端點 + 2 窄寫 facade + 喚醒 024）
- `handler/user_center.rs`（getProfile/updateProfile/changePassword）；`sys_user` facade +`update_own_profile`/`change_own_password`；`password_policy.rs` 移除 `#![allow(dead_code)]`；main.rs +user_center router（`route_auth` 範式、無 require_policy）；`AS_BUILT_ROUTES` 50→53。
- 單元（TDD 核心）：created/updated 語意解析純函式（system/self/admin、adminUpdatedAt admin-only）；changePassword 順序（notFound/mismatch/oldMismatch/tooWeak）——邏輯可測部分 test-first，wiring 由 acceptance 覆蓋（於 tasks/plan 明示無純測者）。

## 2. Live（curl/psql）
- getProfile 回自己 profile + created/updated 語意（種子→system、admin 改過→adminUpdatedAt 有值）。
- updateProfile 改 gender/nick/phone/email 持久（psql），不動 user_name/password/status。
- changePassword：happy→新密可 login；舊密錯/確認不符/違政策→2222；op-log password redact。

## 3. CDP（4 卡 + 動態 rule + 佔位 + i18n）
- `/user-center` 見 4 卡；改料/改密持久；密碼卡動態 rule 隨 admin 政策；手机/邮箱驗證鈕→toast 建置中（佔位）；i18n 非 raw key。

## 4. 三守恆 + 回歸 + build
- `entity_access_lint`（facade-only）／`endpoint_coverage_lint`（AS_BUILT 53）／migration up→down→up（零 migration 未破）＋`pnpm typecheck`。
- 零回歸（getUserInfo 4 欄/login/enforce/既有頁不變、024 設定仍運作）。
- prod image build（無新 crate）。

> 對映 spec SC-001~008（見 `contracts/verification-commands.md` 逐條 C-V）。治理：MODAL-WIRING (g) amendment 已落（v1.3.0、⚠️ah、`63d35179`）。
