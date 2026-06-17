# C-V Contract: verification-commands（007-audit-overlay）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**（共用 audit 表、非 parallel-safe）。**含 prod target image build（C-V-8、新 crate、research R9）**。
> 預設帳號（m002 seed）：`Super`/`Admin`/`User`、密碼 `123456`。DB（容器內）：`postgres://soybean:...@postgres:5432/soybean_admin_rust`（`/run/secrets/database_url`）。psql：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。

## C-V-0 · build 綠（xdb crate 連結）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo build -p server --locked'
```
- `xdb`（新 workspace member）解析＋連結；`audit_ctx`/2 facade/login split/state/config 編譯綠；`ipnetwork` 走 sea-orm re-export（無新顯式 dep）；1.86 不撞 MSRV。

## C-V-1 · `resolve_client_ip` 純測（test-first、零 DB）→ SC-003／FR-006/007

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server resolve_client_ip'
```
- rightmost-untrusted 命中（`peer∈trusted, XFF="real, cf_edge"`〔cf_edge∈trusted〕→`real`）／多 hop 跳 trusted／IPv4＋IPv6／畸形 token 略過／**直連 peer∉trusted＋偽造 XFF→回 peer（anti-spoof）**／全 trusted・空 XFF→fail-safe peer／`TRUSTED_PROXY_CIDRS` 空→peer。
> ⚠️「0 passed; N filtered out」＝filter 沒命中＝非綠。

## C-V-2 · facade `*_active_model` 純測（IpAddr→IpNetwork）→ SC-004／FR-003/005/008

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server active_model'
```
- `IpAddr→IpNetwork` V4→/32・V6→/128；欄映射齊；access/login 對稱；login `operator_id` Set(None)/Set(Some)。

## C-V-3 · `extract_trace_id` 純測 → FR-010／SC-005

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server trace_id'
```
- x-request-id honored（trim≤64 UTF-8-safe）／缺→非空 uuid。

## C-V-4 · live INET no-42804 ＋ region 內網非 NULL → SC-007／FR-006/009

```bash
# 經 front-nginx 觸一次認證請求（見 C-V-6）或直連帶 X-Forwarded-For；再 psql：
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres \
  psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT client_ip, region FROM sys_access_log ORDER BY id DESC LIMIT 1;"
```
- `client_ip` 為真 INET 值（**無 PG 42804**）；私有/內網 IP → `region` 非 NULL（「内网IP」類）。
- xdb_ready=false 情境（缺檔）→ region NULL、**不崩潰**（FR-009 降級；可另以缺檔啟動驗）。

## C-V-5 · live login-attempt 成＋敗各一列（失敗帶 IP）→ SC-002／FR-004/005/011

```bash
BASE=http://127.0.0.1:31080/api   # 經 front-nginx（XFF 轉發）；或 :31081 直連
curl -s -X POST "$BASE/auth/login" -d '{"userName":"Super","password":"WRONG"}'   # 失敗
curl -s -X POST "$BASE/auth/login" -d '{"userName":"Super","password":"123456"}'  # 成功
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres \
  psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT attempted_user_name, success, operator_id, client_ip IS NOT NULL AS has_ip FROM sys_login_attempt ORDER BY id DESC LIMIT 2;"
```
- 失敗列：`success=false / operator_id=NULL（pre-identity password-wrong）/ has_ip=true`；成功列：`success=true / operator_id=1`。**每終端結果恰一列**（不重不漏）。

## C-V-6 · live access-log operator-gate → SC-001／FR-001/002

```bash
BASE=http://127.0.0.1:31081
TOKEN=$(curl -s -X POST "$BASE/auth/login" -d '{"userName":"Super","password":"123456"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s "$BASE/auth/getUserInfo" -H "Authorization: Bearer $TOKEN" >/dev/null   # 認證 → 1 列
curl -s "$BASE/auth/getUserInfo" >/dev/null                                      # 未認證 → 0 列
curl -fsS "$BASE/health" >/dev/null                                              # health → 0 列
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres \
  psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT operator_id, method, path, http_status FROM sys_access_log ORDER BY id DESC LIMIT 3;"
```
- 認證 getUserInfo → 恰一列（operator_id 非空、method=GET、path=/auth/getUserInfo、http_status=200）；未認證 getUserInfo／health／login → **無**新列（operator-gate）。

## C-V-7 · live op-log threading（test-only smoke）→ SC-006／FR-013

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 oplog_threading'
```
- test 顯式構造受稽核上下文（`AuditOperator{id, ip:Some(IpNetwork::from(client_ip))}`＋trace）餵 `soft_delete`/`mutate_in_txn`、psql 驗 op-log 末列 `operator_id`/`operator_ip`/`trace_id` 由恆 None→真值（INET round-trip）。production handler threading＝波1+（非本刀 live）。

## C-V-8 · prod target image build（★ 新 crate 紀律、R9）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- prod multi-stage 含 `xdb`（Manifest＋Source＋`benches`＋`resources/ip2region.xdb` COPY）、`--bins` 跳 `[[bench]]` 編譯、`--locked`；驗 `.xdb` 在 image 內；prod boot log `xdb_ready=true`。對應 SC-008。
> dev bind-mount 遮 prod xdb COPY＋`[[bench]]` 坑 → **必跑此條**。

## C-V-9 · entity_access_lint 守恆 ＋ 零回歸 → SC-009／FR-014/016

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test entity_access_lint'
curl -fsS http://127.0.0.1:31081/health    # 回 "ok"
cd rust-api && git diff --name-only 006後..HEAD | grep -iE "migration|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
```
- `audit_ctx`/`handler`/`config`/`state` 零 path-root `entity::`（entity 全在 facade、續綠）；/health 零回歸；diff 零 migration/entity/base-web/i18n/nginx（三 audit 表 append-only、無 schema 變更）。

## 出口
C-V-0~9 全綠＝本刀 acceptance 通過；對應 spec SC-001~009。**含 prod build（C-V-8、新 crate）**。
