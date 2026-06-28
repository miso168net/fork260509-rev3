# Contracts / Verification Commands: 021-login-lockout-redis-cache

**Branch**: `021-login-lockout-redis-cache` | **Date**: 2026-06-28

> **無新 wire endpoint**（沿用 `/auth/login`、envelope/2222/`auth.login.locked` 不變）→ 無新 contract schema。本檔＝C-V 活體驗收命令（curl `/api` + psql + redis-cli + 量測 + 純函式/live 測），對映 spec FR/SC。
> 共通：`B=http://127.0.0.1:31080/api`；`PSQL(){ docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres psql -U soybean -d soybean_admin_rust "$@"; }`；`RCLI(){ docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T redis-stack redis-cli -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning "$@"; }`；唯一 throwaway user `zz021_<rand>`（失敗嘗試對任意 userName 皆寫一列、不需真帳號）；rust build/test 在 rust-api 容器內（§3、`--test-threads=1`、live 測需 `DATABASE_URL=$(cat /run/secrets/database_url)` ＋ `REDIS_URL=$(cat /run/secrets/redis_url)`）。

## C-V-0 — 前置
- stack healthy、redis-stack up、Super 登入 0000、IP 未鎖。baseline：`PSQL -tAc "SELECT count(*) FROM sys_login_attempt WHERE attempted_user_name LIKE 'zz021_%';"`＝0；`RCLI KEYS 'lockout:*'`＝空。

## C-V-1 — 純函式測（test-first、不碰 IO）
- `lockout_keys(ip,name)` 組 `lockout:ip:{ip}`/`lockout:user:{name}`；`tripped_keys(ip_fails,user_fails,...)`（20/5 門檻 → 各維度 set 哪些 key、含兩維皆觸發）；`should_flush(flushed_exists)`（不存在才 true）。
- `is_locked_out`/`is_locked_out_for_test` **不變**（沿 019、boundary 5/20、OR 語意已有測）。容器內 `cargo test -p server <filter>` 綠。

## C-V-2 — US1/SC-002/FR-001/FR-003：鎖後短路、0 DB 寫（②b）
1. 對 `userName=zz021_x` 送 **5 次** `POST $B/auth/login`（password 錯）→ 各回 `1000`（fail、各寫一列）；psql `WHERE attempted_user_name='zz021_x' AND success=false`＝**5**。
2. 第 **6** 次（L2 觸發鎖）→ `2222 auth.login.locked`；psql count＝**6**（觸發那發照寫、FR-006）；`RCLI EXISTS lockout:user:zz021_x`＝1。
3. 再送 **10 次**（L1 命中短路）→ 皆 `2222`；**psql count 仍＝6**（不隨壓制嘗試成長＝②b/FR-004 反轉、SC-002 持久列不成正比）；`RCLI GET lockout:suppressed:user:zz021_x` 或 flush 後計數反映被壓制數。

## C-V-3 — FR-002：per-user 維度短路任意來源（分散式打單帳號）
- C-V-2 後（`zz021_x` per-user 鎖、但僅 5-6 次 < per-ip 20 → **per-ip 未鎖**）：`RCLI EXISTS lockout:user:zz021_x`＝1、`RCLI EXISTS lockout:ip:<本機ip>`＝**0**。→ 證鎖由 **user 維度** 短路（與來源 IP 無關）；live 測補：注入不同 `real_ip` 的該帳號嘗試仍被 `lockout:user` 短路（不重新觸發 per-user COUNT）。

## C-V-4 — FR-007/D3：固定 TTL、命中不 refresh、自癒
- `RCLI TTL lockout:user:zz021_x` ≈ **900**（D3）；再送幾次壓制嘗試後 `RCLI TTL ...` **持續下降、不回彈至 900**（命中不 refresh）。
- **自癒**：①TTL 到期 key 消失；②②b 鎖中不寫新失敗列 → 觸發的 5-6 列於 ~900s 後 age-out → L2 重判 count<5 解鎖。**完整 900s 實時 defer**（過長）→ 以「TTL≈900 + 不 refresh + ②b 不寫」三者 + live 測（縮短窗變體或鎖讀序）覆蓋。

## C-V-5 — FR-008/SC-006：fail-OPEN（Redis-down → 退 L2 DB gate）
1. `docker compose … stop redis-stack`（或令 `state.redis=None`）。
2. 對 `zz021_y` 送 5 次失敗 → 第 6 次 → **仍 `2222`**（鎖定由 **L2 DB gate** 正確執行、L1 跳過）；登入正確性不破（Super 正確密碼仍 0000）。
3. `docker compose … start redis-stack`（恢復加速）。

## C-V-6 — FR-005/FR-011/SC-003/SC-004：②c 節流麵包屑
- 鎖定中持續壓制 → rust-api log（→ loki）出 `target=security.lockout` 結構化事件、含 `suppressed=N`（壓制次數、clarify Q1 必需）、`locked_key`/`dimension`；**節流 ≤1/60s/key**（同窗多次壓制只出 1 筆摘要）。loki/grafana 可查（FR-011；具體 alert rule 配置遞延 ops、不在本刀驗收）。
- 量測：`docker compose … logs rust-api --since 90s | grep security.lockout` 計數 ≤ ceil(壓制秒數/60)。

## C-V-7 — FR-009/SC-007：零回歸（未鎖路徑與 019 完全一致）
- 未鎖 user：正確密碼 → `0000`（Super）；錯密碼 → `1000`（一般化、不洩帳號存在）；每次嘗試照常寫一列 `sys_login_attempt`。鎖定 toast 仍 `auth.login.locked`（沿 019、無 i18n 新鍵）。`login_inner` 6 路徑、稽核欄、操作者語意不變。

## C-V-8 — SC-001/SC-002：鎖後對 DB 0 query 量測
- **live 測（首選）**：鎖後送 N 壓制嘗試、量測該路徑對 DB 的 query 數＝**0**（無 COUNT、無 INSERT；以 instrument／facade call counter／或斷言「sys_login_attempt 行數不變」proxy）。
- **psql proxy**：C-V-2.3 的「行數不隨壓制嘗試成長」即 0-write proxy；0-read 由 L1 早-return 在 count 前的碼面斷言覆蓋（grep L1 在 :226 `since` 計算前 return）。

## C-V-9 — lint + prod build gate
- 容器內：`cargo test -p server --test entity_access_lint` 綠（無 casbin entity 直存）／`cargo test -p server --test endpoint_coverage_lint` 綠（無新 route）。
- prod image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（無新 crate、驗 multi-stage 無破口）。

## 清理
- `PSQL -c "DELETE FROM sys_login_attempt WHERE attempted_user_name LIKE 'zz021_%';"`；`RCLI DEL lockout:user:zz021_x lockout:ip:... lockout:suppressed:user:zz021_x lockout:flushed:user:zz021_x`（或 `RCLI KEYS 'lockout:*'` 清 throwaway）；無殘留。
