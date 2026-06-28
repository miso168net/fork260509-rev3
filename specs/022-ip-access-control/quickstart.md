# Quickstart / Validation Guide: 022-ip-access-control

**Branch**: `022-ip-access-control` | **Date**: 2026-06-28

> 本檔＝驗證/執行指南（非實作碼）。完整 C-V 命令見 [contracts/verification-commands.md](contracts/verification-commands.md)；設計接地見 [research.md](research.md)／[data-model.md](data-model.md)。

## 前置
- dev stack healthy（含 **redis-stack**）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml ps`。
- **m007 migration 已套**（建 `sys_ip_rule` + casbin seed）：`PSQL -tAc "SELECT to_regclass('sys_ip_rule');"`。
- rust build/test 在 rust-api 容器內（host 無 cargo）；live 測需 `DATABASE_URL`+`REDIS_URL`〔/run/secrets〕、`--test-threads=1`；改 `.rs` 後 force-touch 防 /mnt/d stale-mtime；rust 全程 serial。
- 加 i18n 鍵後 `restart base-web` 防 vite stale-locale（CDP toast 在地化驗收前）。

## 驗證情境（對映 spec User Stories）

### US1 — 黑名單封鎖、有界成本、零 DB 寫（C-V-2/10）
1. 純函式測（test-first）：`decide`（白>黑>default-allow）、`in_set` 結構豁免、`should_flush` 節流 紅→綠。
2. 活體：加 deny 規則涵蓋 TEST-NET → 該段請求 HTTP 403/5003、未列來源放行；被封段洪水→psql `sys_access_log` 未認證 0 新列、②c `security.ipgate` 節流 obs。

### US2 — 白名單放行 + 跳 lockout（C-V-3）
- 白優先於黑（同段白+黑→放行）；白名單來源登入失敗 >5 次仍不鎖（D6 L0 seam 跳 L1/L2）、`lockout:user` 未設。

### US3 — 系統管理 CRUD（C-V-7/11、CDP）
- 列表含已刪+Deleted 欄+搜索分頁（比照 user/menu）；CRUD+復原（衝突→2222）；寫端自鎖（加自己 ip deny→2222 toast 在地化）。

### US4 — 手動解鎖（C-V-8）
- 被鎖帳號→`unlockLogin`（reset-marker per-dim）→下一次正確密碼即登入；both-dims 鎖須兩維皆解。

### US5 — 韌性/安全/零回歸（C-V-4/5/9/14）
- 結構豁免（loopback/私網/探針永遠可達、即使有涵蓋它們的 deny）；fail-OPEN（規則載不進→放行）；CF Tunnel 直連 real_ip=CF-CIP + **反偽造**（非 tunnel peer 偽 CF-CIP 不採信）+ nginx 路徑零回歸；未鎖正常 login 與既有 auth/casbin/audit 零回歸。

### 熱刷新 + Gate（C-V-6/12/13）
- 規則變更 ≤5s 生效（publish→watcher 重讀 ArcSwap）；migration up→down→up；`entity_access_lint`/`endpoint_coverage_lint`（44→50、36→42）綠；prod image build 綠。

## 清理
- `DELETE FROM sys_ip_rule WHERE ...TEST-NET/zz022...`＋`redis DEL ipgate:* lockout:*zz022* lockout:reset:*`＋`DELETE sys_login_attempt WHERE attempted_user_name LIKE 'zz022_%'`→回 baseline。

## 完成定義（出口）
- 黑名單→403、白名單→放行+跳 lockout、default-allow；結構/探針豁免；判定 μs 級零每請求 DB/redis（未認證被擋 0 DB 寫）；規則熱刷新；寫端自鎖防護；手動解鎖 per-dim；CF Tunnel real_ip 正確+反偽造+nginx 零回歸；fail-OPEN；1 migration up→down→up；lint + prod build；零回歸；Constitution 9/9。
