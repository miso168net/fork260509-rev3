# Quickstart / Validation Guide: 021-login-lockout-redis-cache

**Branch**: `021-login-lockout-redis-cache` | **Date**: 2026-06-28

> 本檔＝驗證/執行指南（非實作碼）。完整 C-V 命令見 [contracts/verification-commands.md](contracts/verification-commands.md)；設計接地見 [research.md](research.md)／[data-model.md](data-model.md)。

## 前置
- dev stack healthy（含 **redis-stack**）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml ps`。
- rust build/test 在 rust-api 容器內（host 無 cargo）；live 測需 `DATABASE_URL=$(cat /run/secrets/database_url)` ＋ `REDIS_URL=$(cat /run/secrets/redis_url)`、`--test-threads=1`。
- 改 `.rs` 後 force-touch 防 /mnt/d stale-mtime；rust 全程 serial。

## 驗證情境（對映 spec User Stories）

### US1 — 鎖後成本有界、0 DB 寫（C-V-1/2/8）
1. 純函式測（test-first）：`lockout_keys`/`tripped_keys`/`should_flush` 紅→綠；`is_locked_out` 不變。
2. live/curl：對 throwaway `zz021_x` 連送 5 次失敗（各 `1000`、各寫一列）→ 第 6 次 `2222`（L2 觸發鎖、寫第 6 列）→ 再送 10 次（L1 短路 `2222`）→ **psql 該 user 行數仍＝6**（不隨壓制成長）+ `lockout:user:zz021_x` 存在。
3. 量測：鎖後壓制路徑對 DB query＝0（live 測 instrument / 行數不變 proxy）。

### US1 — per-user 維度短路任意來源（C-V-3）
- 5-6 次（per-user 鎖、per-ip 未鎖）→ `lockout:user:zz021_x`＝1、`lockout:ip:*`＝0 → 鎖由 user 維度短路（與來源無關、擋分散式）。

### US3 — 自癒 + fail-open + 零回歸（C-V-4/5/7）
- 自癒：`TTL lockout:user:zz021_x`≈900、命中不回彈；完整 900s 實時 defer（以 TTL+不refresh+②b不寫 + live 縮窗變體覆蓋）。
- fail-open：`stop redis-stack` → `zz021_y` 5 次失敗 → 第 6 次仍 `2222`（L2 DB gate 執行）→ `start redis-stack`。
- 零回歸：未鎖 user 正確密碼 `0000`／錯密碼 `1000`／每次照寫稽核；toast 仍 `auth.login.locked`。

### US2 — 鑑識麵包屑（C-V-6）
- 鎖中持續壓制 → rust-api log（→loki）出 `target=security.lockout`、`suppressed=N`、節流 ≤1/60s/key；grafana 可查（alert rule 配置遞延 ops）。

### Gate（C-V-9）
- `cargo test -p server --test entity_access_lint`／`--test endpoint_coverage_lint` 綠；`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠。

## 清理
- `DELETE FROM sys_login_attempt WHERE attempted_user_name LIKE 'zz021_%';`＋`redis-cli DEL lockout:*`（throwaway）→ 回 baseline。

## 完成定義（出口）
- 鎖後嘗試對 DB query＝0；per-user 短路任意來源；TTL≈900 自癒；②c 節流麵包屑出 loki；Redis-down 退 DB gate；未鎖路徑零回歸；0 migration/crate/route；Constitution 9/9。
