# Quickstart (Validation Guide): 017-audit-center-enhancement

**Date**: 2026-06-23 | 端到端驗證指南。實作細節見 [data-model.md](data-model.md)；完整命令見 [contracts/verification-commands.md](contracts/verification-commands.md)。

## 前置

- dev stack 起：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（front-nginx/base-web/rust-api/postgres/redis 全 healthy）。
- dev 帳號：`Super`/`Admin`/`User`（密碼 `123456`）。審計中心 R_SUPER-only（`/manage/audit`）。
- rust 在容器內跑（host 無 toolchain）；改 `.rs` 前 force-touch（WSL2 /mnt/d stale-mtime）。

## 驗證情境（對應 User Stories）

### US1 — 角色變更稽核（P1）
1. 以 Super/Admin 改某 user 角色（編輯/新建/停用/刪除）。
2. psql 查該操作 trace_id 的 `sys_operation_log`：`payload_before/after->'roles'`。
3. 預期：update 列 before/after 角色集如實；add 列 after=初始角色、before null；delete 列 before=刪前、after=`[]`；未動角色 update before==after（集合）。
→ 詳 [C-V-3](contracts/verification-commands.md)。**斷言限自身 trace_id**（共享 seed entity_id append-only）。

### US2 — CSV 匯出（P2）
1. 進 `/manage/audit` 任一分頁、套用篩選。
2. 按「匯出」→ 下載 `<table>_<timestamp>.csv`。
3. 預期：內容＝當前篩選結果（≤1 萬列）；中文不亂碼（UTF-8 BOM）；op-log CSV 含 `rolesBefore`/`rolesAfter` 欄；total>1萬時 toast 提示截斷；非 Super 403。
→ 詳 [C-V-2](contracts/verification-commands.md)（curl）+ [C-V-4](contracts/verification-commands.md)（CDP 下載）。

### US3 — http_status 類別篩（P3）
1. API 存取分頁選類別「4xx」。
2. 預期：列表僅 400–499；清除（全部）還原；class 與精確值同設＝AND。
→ 詳 [C-V-2](contracts/verification-commands.md)（curl 收窄）+ [C-V-4](contracts/verification-commands.md)（CDP UI）。

## 驗收閘（合併）

| 閘 | 命令參考 |
|---|---|
| build/lint（endpoint_coverage_lint 數不變）/typecheck | [C-V-0](contracts/verification-commands.md) |
| 純函式單元測（parse_http_status_class／with_roles／csv／parse_export） | [C-V-1](contracts/verification-commands.md) |
| curl wire（class 收窄／export 200 CSV／非 Super 403／空 param 守門） | [C-V-2](contracts/verification-commands.md) |
| psql op-log roles delta（trace_id 隔離） | [C-V-3](contracts/verification-commands.md) |
| CDP UI（class filter／三 tab 匯出下載／op-log payload roles） | [C-V-4](contracts/verification-commands.md) |
| 回歸（零 migration／prod build／既有 audit 行為／typecheck） | [C-V-5](contracts/verification-commands.md) |

## 完成定義
spec §5 SC-001~008 全達；C-V-0~5 全綠；零 migration/crate/端點；Constitution 9/9 PASS（見 plan.md）。
