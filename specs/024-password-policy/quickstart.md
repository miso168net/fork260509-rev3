# Quickstart: 024-password-policy 驗證指南

> 本刀交付＝①admin 可在系統設定調 7 密碼政策 ②後端 `number` 型驗證 ③已完整單元測試的驗證原語（`validate_password_complexity`，本刀 dormant、供刀2）。以下為 end-to-end 驗證流程；細節指令見 [`contracts/verification-commands.md`](contracts/verification-commands.md)、契約見 [`contracts/settings-policy-contract.md`](contracts/settings-policy-contract.md)。

## 前置

- dev stack up：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`
- rust 命令一律**容器內**（host 無 toolchain）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`；live 測 serial `--test-threads=1`
- base-web 改動後 `docker compose … restart base-web`（vite 熱載新分支）
- 改 `.rs` 後先 force-touch 避 WSL2 stale-mtime 假綠：`find server/src -name '*.rs' -exec touch {} +`

## 1. Migration（m009 seed 7 列）

- migrate gate 自動套（`migration up`）；或手動 `docker compose … exec -T rust-api sh -c 'cd /app && cargo run -p migration -- up'`（★ `migration` 不在容器 PATH、走 `cargo run -p migration --`）。
- **可逆驗（三守恆）**：`cargo run -p migration -- down`（sea-orm 預設退 1 步＝m009）→ `cargo run -p migration -- up`。
- 驗：`psql … -c "SELECT setting_key,setting_value,value_type FROM system_settings WHERE setting_key LIKE 'password_%' ORDER BY setting_key"` → **7 列**（2 number + 5 enum:on,off、值＝保守預設）。

## 2. 單元測試（rust、容器內）— TDD 核心

- `validate_value_type` number 分支（擴既有 `value_type_tests`）：合法 `"12"`→ok、`"abc"/"0"/"-1"/"9999"`→2222。
- `password_policy`：`from_settings`（on/off/number parse、缺鍵預設）＋`validate_password_complexity` 逐 knob（長度上下界、四字元類、禁同帳號、全通過、回全部違規非短路）。
- 全綠。

## 3. Live 驗收（curl / psql）

- GET `getSystemSettings`（super token）→ 回含 7 個 `password_*` 列。
- POST `updateSystemSetting` `password_min_length=12` → psql 驗值變、`sys_operation_log` 一列（operator/trace）。
- POST `password_min_length` 值 `abc` / `-1` / `0` / `9999` → **2222** `biz.systemSettings.invalidValue`、值不變。

## 4. CDP（browser、curl≠modal）

- super 登入 → `/manage/system-settings` → 見 **5 個開關 + 2 個數字欄**（min/max length）。
- 切一開關 + 改 min_length → 重新載入回 server 真值（斷言持久）。

## 5. 三守恆 + 回歸

- `entity_access_lint`（`password_policy.rs` 零 `entity::`）／`endpoint_coverage_lint`（零新 route）／migration up→down→up — 全綠。
- `pnpm typecheck` 綠。
- `single_session_default` 開關仍運作（零回歸）。
- prod image build（輕、無新 crate；確認 m009 + `password_policy.rs` 編入 prod target）。

> 對映 spec SC-001~006（見 `contracts/verification-commands.md` 逐條 C-V）。
