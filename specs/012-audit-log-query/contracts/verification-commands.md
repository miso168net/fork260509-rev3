# C-V Contract: verification-commands（012-audit-log-query、唯讀＋m005 delta）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`（下簡 `EXEC`）。改 `.rs` 先 **force-touch** 防 WSL2 stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**。**無新 crate／無新 dep**。
> 帳號（m002）：`Super`(R_SUPER)/`Admin`(R_ADMIN)/`User`(R_USER_COMMON)、`123456`。psql：`docker compose … exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。
> **★ 唯讀無污染**：3 讀端 live 測純 SELECT、**不寫日誌/不寫 op-log/無 cleanup**（異於 011 casbin 寫）；對 dev DB 現有資料（op-log 41／access 723／login 213 列級）斷言（取**已知存在值**驗 filter 命中＋非命中排除）。
> **★ m005 delta**：menu seed（manage_audit）＋3 讀端 R_SUPER policy＋manage_audit menu policy＋operation/access filter 索引；**無新業務表、無 ALTER 既有日誌表**。
> **★ bare-filter 假綠**：整支 test binary 用 `--test <name>`／bin 內單元 `--bin server <filter>`；「0 passed; N filtered out」＝沒命中、非綠。

## C-V-0 · build 綠（無新 crate/dep；m005 編入）
```bash
EXEC sh -c 'cd /app && find server/src server/tests migration/src -name "*.rs" -exec touch {} + && cargo build -p server -p migration --locked'
```
- 3 sink facade `list`＋`OperationLogFilter`/`AccessLogFilter`/`LoginAttemptFilter`＋`sys_user::names_for_ids`＋handler 3 端點＋main 3 路由＋m005 migration＋endpoint_coverage_lint 編譯綠；無新 dep。

## C-V-1 · 純測（filter/normalize/names_for_ids/IP-expr 若抽純函式）→ FR-006/007
```bash
EXEC sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server --bin server audit_'
```
- 若抽純 helper（filter where 組裝、operator_name→ids map、IP cast expr builder、日期 parse）→ 純測；無純函式者由 C-V-3 live 覆蓋（plan/tasks 明示）。看「N passed」非「0 filtered」。

## C-V-2 · 三守恆 lint（endpoint_coverage_lint [31→34]＋entity_access_lint）→ SC-008
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test endpoint_coverage_lint && cargo test -p server --test entity_access_lint'
```
- `AS_BUILT_ROUTES [&str;34]`＝既 31＋3（audit GET）；Assertion B registered==as-built；Assertion A 3 audit policy 對應 m005 seed；entity_access_lint：handler/main 零 path-root entity::、3 sink facade list 走 model/facade/ 豁免。

## C-V-3 · ★ live 3 端點分頁/filter（對真實列、含 fuzzy/IP/operator-by-名）→ FR-001~008/SC-001/002/003
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 audit_query'
```
- **唯讀無污染**（純 SELECT、不寫）：① getOperationLog/getAccessLog/getLoginAttempt 分頁（current/size、total）；② 空字串守門（未設 filter 回全部）；③ 精確（operation='UPDATE'／success=false／method='POST'）命中正確；④ **★ 文字模糊**（path/attempted_user_name/region/entity_table `LOWER LIKE ESCAPE` 部分比對、取已知值驗命中＋非含排除）；⑤ **★★ IP 模糊**（operator_ip/client_ip `host()::text LIKE` 部分比對——**本刀唯一無 codebase 先例之 SQL 形、首要驗證點**、取 dev DB 已知 client_ip 片段驗命中）；⑥ **operator by 名**（user_name LIKE→ids→`operator_id IN`、含已刪操作者）；⑦ created_at 範圍（from/to）；⑧ operator enrich（operatorName＝名、operator_id NULL→null、已刪操作者仍顯示名）。對應 SC-001/002/003。

## C-V-4 · live policy-gate（3 端點 R_SUPER-only）→ FR-009/SC-005
```bash
BASE=http://127.0.0.1:31081
for who in Admin User; do TK=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' -d "{\"userName\":\"$who\",\"password\":\"123456\"}" | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])");
  for ep in getOperationLog getAccessLog getLoginAttempt; do curl -s -o /dev/null -w "$who/$ep=%{http_code}\n" "$BASE/systemManage/$ep" -H "Authorization: Bearer $TK"; done; done   # 皆 403（envelope 5003）
# Super 正面 smoke：getOperationLog/getAccessLog/getLoginAttempt → 200 code 0000 PageRes
```
- Admin/User 對 3 讀端→403/5003 不洩資料（授權依 DB-fresh roles）；Super→200。對應 SC-005。

## C-V-5 · ★ m005 migration up→down→up 可逆 → SC-008
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) sh -c "cargo run -p migration -- down -n 1 && cargo run -p migration -- up"'   # 或 sea-orm-cli migrate down/up
# psql 驗：down 後 manage_audit menu/3+1 casbin policy/4 索引 消失；up 後重建；既有日誌表結構/資料不動
```
- m005 down 還原（DELETE seed＋DROP INDEX）、up 重建；**無新業務表**；既有 sys_operation_log/access_log/login_attempt 結構與資料零變。對應 SC-008。

## C-V-6 · base-web typecheck（3 honest typing、wire number 域）→ SC-009
```bash
docker compose … exec -T base-web sh -c 'cd /app && pnpm typecheck'   # --no-verify commit、§8.2.1
```
- `rev3-system-manage.ts` 3 wrapper＋3 honest `XxxLogItem`（nullable→`｜null`）；無 type-lie。

## C-V-7 · ★ CDP 經 front-nginx 真 `/api`（審計中心 3 tab）→ SC-001/004/005/009
```bash
# 經 :31080/api（front-nginx strip）；CDP scripts 見 docs/superpowers/000 + tests/000；token 注入 SOY_token
```
- Super→/manage/audit→**3 tab**（操作異動/API 存取/登入嘗試）各**真發 request**（斷言非假資料）→分頁→filter（operation/success 下拉、日期範圍、部分 IP/path/帳號 模糊、operator by 名）→**op-log 行展開看 payload before/after**→operator 名顯示（含已刪/系統空）；**hasAuth super-only**（非 super 側欄不見審計中心、直呼 5003）。**唯讀無污染**（不寫、無 cleanup）。對應 SC-001/004/005/009。

## C-V-8 · 零回歸 → FR-012/SC-008
```bash
EXEC sh -c 'cd /app && cargo build -p server --locked' ; curl -fsS http://127.0.0.1:31081/health   # ok
cd rust-api && git diff 011後..HEAD --name-only | grep -iE "entity/|enforce|require_policy|error\.rs|envelope" && echo "⚠️檢視" || echo "✅ infra 未動"
cd base-web && git diff 011後..HEAD --name-only | grep -iE "store/modules/route/|router/elegant/transform|service/api/system-manage|service/api/auth|service/request" && echo "⚠️違規" || echo "✅ frozen 未動"
```
- /health 零回歸；login/getUserInfo/getUserRoutes/enforce_mw/require_policy/From<DbErr>/008-011 不變；diff 既有日誌表 entity 未改、**migration 僅 seed+index 無業務表**；base-web frozen 未改（route store/transform/system-manage.ts/auth.ts/request）。對應 SC-008。

## C-V-9 · prod target image build（無新 crate、m005 編入）
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認 3 sink facade list/names_for_ids/handler/main/m005 編入 prod target（migrate stage 套 m005、無新 crate→無 Dockerfile COPY 變更、`--locked`）。

## 出口
C-V-0~9 全綠＝本刀 acceptance 通過；對應 spec SC-001~009。**唯讀無污染、無新 crate、m005 delta（無新業務表、up→down→up 可逆）。★ IP 模糊 `host()::text LIKE` 為唯一無先例 SQL 形、C-V-3 首要驗。** perf by inspection（§5.8 分頁＋m005 btree 索引、模糊 LIKE seq scan、⚠️a 預算內）。
