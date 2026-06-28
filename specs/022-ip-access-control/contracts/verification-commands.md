# Contracts / Verification Commands: 022-ip-access-control

**Branch**: `022-ip-access-control` | **Date**: 2026-06-28

> 6 新 endpoint（沿 `/api/systemManage/*`、envelope `{data,code,msg}`、require_policy R_SUPER 守門）；blocked＝reuse `PermissionDenied`（5003/HTTP 403）。本檔＝C-V 活體驗收（curl `/api` + psql + redis-cli + CDP browser + migration + prod gate），對映 spec FR-001~016／SC-001~009。
> 共通：`B=http://127.0.0.1:31080/api`；`PSQL(){ docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres psql -U soybean -d soybean_admin_rust "$@"; }`；`RCLI(){ docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T redis-stack redis-cli -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning "$@"; }`；rust build/test 在 rust-api 容器內（§3、`--test-threads=1`、live 測需 `DATABASE_URL`+`REDIS_URL`〔/run/secrets〕）；throwaway 規則 cidr 用 TEST-NET（`203.0.113.0/24`、`198.51.100.0/24`）避撞真來源。

## C-V-0 — 前置
- dev stack healthy（含 redis-stack）；Super 登入 0000；m007 已套（`PSQL -tAc "SELECT to_regclass('sys_ip_rule');"`＝`sys_ip_rule`）。baseline：`PSQL -tAc "SELECT count(*) FROM sys_ip_rule;"`＝0；`RCLI KEYS 'ipgate:*'`＝空；`RCLI KEYS 'lockout:reset:*'`＝空。

## C-V-1 — 純函式測（test-first、不碰 IO）
- `decide(ip,&RuleSet)`：白集命中→Allow（即使同時黑集命中＝白優先）／黑集命中→Block／皆無→Allow（default-allow）。
- `in_set(ip, STRUCTURAL_EXEMPT)`：loopback/私網 v4/v6 →true；公網→false。
- `should_flush(flushed_exists)`（≤1/60s 節流）；restore 衝突守門（同 (cidr,rule_type) active 存在→拒）；寫端自鎖（deny 命中操作者 ip→拒）。
- 013 fallback 純邏輯：`conf==Fallback && peer∈tunnel && cf_cip → real_ip=cf_cip`；`peer∉tunnel`〔即使內網〕→ 不採信 cf_cip。容器內 `cargo test -p server <filter>` 綠（非 0-filtered）。

## C-V-2 — US1/FR-001/003/SC-001/002：黑名單封鎖、default-allow、有界成本
1. baseline：自本機 curl `$B/health`→200、`$B/auth/login`（Super）→0000（未列、default-allow）。
2. 新增 deny 規則涵蓋**某 TEST-NET**（非本機）：curl `$B/systemManage/addIpRule`（Super token、`{cidr:"203.0.113.0/24",ruleType:"deny"}`）→0000；`RCLI EXISTS`/list 確認。
3. 自本機（非被封段）續 curl→仍 200/0000（未受影響）。
4. 〔模擬被封來源〕注入 `X-Forwarded-For: 203.0.113.5`（經受信 proxy 路徑使 real_ip=該值）或以 live 測直驗：被封段請求→**HTTP 403、code 5003**；psql `sys_access_log` 該未認證請求**0 新列**（②b、FR-013、SC-009）。
5. 被封段送 100 次→每次 403、psql 無成長（有界成本 proxy、SC-001/002）。

## C-V-3 — US2/FR-001/004：白名單優先 + 跳 021 lockout
- 對某 TEST-NET 同時加 deny 與 allow（白優先）：該段請求→放行（200、非 403）。
- 白名單來源於 login：對 `zz022_x` 自白名單來源連送 >5 次失敗→**仍可續嘗試（不鎖、無 2222）**；`RCLI EXISTS lockout:user:zz022_x`＝0（D6 跳 L1/L2）。對照非白名單來源同樣失敗→第6次 2222（021 行為不變）。

## C-V-4 — FR-006：結構豁免 + 探針豁免（永遠可達、非 lockout-bypass）
- 即使加一條涵蓋 loopback/私網的 deny 規則（`127.0.0.0/8` 或 `10.0.0.0/8`）：自 loopback/私網請求→**仍 200**（結構豁免不可被規則擋）；`/health`、`/metrics`→**仍 200**（探針豁免）。
- ★ 結構豁免**不**跳 lockout：私網來源若未在 allow 名單、其登入失敗仍正常計入（豁免僅作用於阻擋、非 lockout-bypass、FR-006 註）。

## C-V-5 — FR-005/SC-004：fail-OPEN
- 令規則載不進（stop redis-stack 使 watcher 失聯 + 重啟 rust-api 使 boot DB 讀失敗模擬／或注入空 ruleset）→ 任一請求**放行**（含原本被封段）；既有 auth/casbin 仍守（Super 0000、受保護端點仍需 token）。恢復 redis-stack/重載。

## C-V-6 — FR-007/SC-003：規則熱刷新 ≤5s
- 新增/改/刪一條規則→`publish ipgate:invalidate`→watcher 重讀 DB→ArcSwap 換；量測「改規則」到「判定反映新規則」≤5s（無需重啟）。`docker compose logs rust-api | grep ipgate` 見重載。

## C-V-7 — FR-009/SC-005：寫端自鎖防護
- 以**操作者當前 real_ip** 所在網段建 deny 規則：curl `addIpRule`→**2222 拒**、規則不變更（`sys_ip_rule` count 不增）。update 既有規則使其命中自己 ip→同拒。

## C-V-8 — FR-010/SC-006：手動解鎖 reset-marker per-dim
- 令 `zz022_y` 連續失敗被鎖（第6次 2222、`RCLI EXISTS lockout:user:zz022_y`=1）→ curl `$B/systemManage/unlockLogin`（`{dimension:"user",value:"zz022_y"}`）→0000；`RCLI EXISTS lockout:user:zz022_y`=0、`RCLI GET lockout:reset:user:zz022_y`=unix→ `zz022_y` **下一次正確密碼登入即 0000**（reset 前失敗不計）。
- **per-dim 獨立**：both-dims 鎖（同來源跨帳號達 per-ip 20 + 某帳號達 per-user 5）→ 僅解 user 維→ip 維仍鎖（須兩維皆解、FR-010）。

## C-V-9 — FR-014/SC-007：CF Tunnel real_ip + 反偽造 + nginx 零回歸
- **tunnel 正路**：trust-model 配 `[[tunnel]]`〔窄 origin〕、模擬 cloudflared 直連（peer∈tunnel、XFF 無外部 client、帶 `CF-Connecting-IP: 203.0.113.9`）→ real_ip=`203.0.113.9`（live/單元測 `resolve_client_ip`）。
- **★ 反偽造（B2）**：peer ∈ 內網但 ∉ tunnel + 偽 `CF-Connecting-IP`→ real_ip **≠** 偽值（不採信）。
- **nginx 零回歸**：現有 `resolve_client_ip` 全部既有 case（`resolve_cases_*`/`apply_cf_overlay` 既有測）**全綠**（XFF 有 client 路徑不走 tunnel fallback）。

## C-V-10 — FR-013/SC-009：②c 被擋節流 obs
- 被封段持續請求→rust-api log（→loki）出 `target=security.ipgate`、含 `matched_cidr`/`blocked=N`、**節流 ≤1/60s/規則**（同窗多次只出 1 筆）。`docker compose logs rust-api --since 90s | grep security.ipgate` 計數 ≤ ceil(秒/60)。

## C-V-11 — FR-008/SC-002：CRUD UI（CDP browser、curl≠modal）
- CDP 開 `/manage/ip-rule`：列表**顯示全部含已刪**、Deleted 欄 NTag 二態；搜索（cidr/ruleType；**注**：U3 `IpRuleFilter` 僅 cidr+ruleType、無 description 搜索）+分頁；active 列 編輯/刪除、已刪列 **復原鈕**。
- 復原一條已刪規則→active；復原與既有同 (cidr,rule_type) active 衝突→**2222 toast**（在地化、非 raw key）。
- 寫端自鎖拒（加自己 ip deny）→**2222 toast** 在地化。手動解鎖 modal（dimension+value）→成功 toast。
- ★ 加 i18n 鍵後 `restart base-web` 防 vite stale-locale；斷言 toast 非 raw key。

## C-V-12 — migration up→down→up
- 容器內 migration：`up`（建表+seed）→`down`（drop sys_ip_rule + 移 casbin seed）→`up`（重建）皆綠；down 後 `to_regclass('sys_ip_rule')`=NULL、casbin 6 列移除；up 後復原。

## C-V-13 — lint + prod build gate
- 容器內：`cargo test -p server --test entity_access_lint` 綠（`sys_ip_rule` 只經 facade、handler/main 零 path-root `entity::`）／`--test endpoint_coverage_lint` 綠（`AS_BUILT_ROUTES` 44→50、`ALL_ENDPOINT_POLICIES` 36→42、main.rs==registry==seed 三源一致）。
- prod image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（新 migration+新 route、驗 multi-stage 無破口；arc-swap 為既有 dep）。

## C-V-14 — FR-015/SC-008：零回歸
- 未命中規則的正常 login（Super 0000／錯密碼 1000／鎖定 2222 toast `auth.login.locked` 不變）；既有受保護端點授權（casbin）、access-log、op-log 行為不變；既有 `resolve_client_ip` 全測綠（C-V-9）。

## 清理
- `PSQL -c "DELETE FROM sys_ip_rule WHERE cidr <<= '203.0.113.0/24' OR cidr <<= '198.51.100.0/24' OR description LIKE 'zz022%';"`（或測試 marker）；`RCLI` 清 `ipgate:*`、`lockout:*zz022*`、`lockout:reset:*`；`PSQL` 清 `sys_login_attempt WHERE attempted_user_name LIKE 'zz022_%'`→回 baseline。
