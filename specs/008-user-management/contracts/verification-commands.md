# Verification Commands — User Management（008）C-V Contract

> Phase 1 contract（/speckit-plan）。每項 C-V ＝ acceptance 驗收命令骨架；implementer 實作後逐項跑綠。實際值（`$PG_URL`／`$TOKEN`／user body）見 quickstart.md。
> **prod-build 紀律（CLAUDE.md §3 Phase 1）**：008 **不新增 workspace crate**（members 固定 5：`server`/`migration`/`sea-orm-adapter`/`entity`/`xdb`、僅加模組到既有 `server` crate）→「新 crate 必跑 prod target image build」**不觸發**；dev build 綠 ＋ live smoke 即足。**若實作中改為新增 crate，必補**：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`。
> **CDP 紀律**：本刀 CDP 不 defer（clarify 拍 C-V-6 這刀做）；curl 直送 ≠ base-web modal 對齊，C-V-4/5（curl）與 C-V-6（CDP）皆須跑。

## C-V-1 — build ＋ MSRV lock
```bash
cd rust-api && cargo build -p server --locked   # MSRV 1.86；無新依賴、無新 crate
```

## C-V-2 — 純單測（test-first where pure、零 DB/HTTP）
```bash
cd rust-api && cargo test -p server   # search_active filter SQL-shape／find_active_by_codes／replace_roles／i16↔string enum／2^53 id guard／種子保護謂詞 id∈{1,2,3}／dup→2222 pre-check 判定
```
用既有 `build(DbBackend::Postgres).to_string()` pattern（如 `find_active_filters_soft_deleted`）斷言 SQL 形、零 DB。

## C-V-3 — live smoke（`#[ignore]`、真 PG、`--test-threads=1`）
```bash
cd rust-api && cargo test -p server --test '*' -- --ignored --test-threads=1 live_smoke_user_crud
```
覆蓋：addUser→op-log **Insert** 列（payload_after 含 redact password＋`roles`）／updateUser→**Update** 列（before/after **role-delta**）／deleteUser→**SOFT_DELETE** 列（payload_before 15 欄**無 roles**、Q1）／already-deleted→**no-op 零 audit**（Q2）／dup user_name→**2222**（Q3）／種子保護 id∈{1,2,3}→**2222**。
（serial：共表 `sys_operation_log`/`sys_user_role` 非 parallel-safe、memory `live-ignore-tests-need-serial`。）

## C-V-4 — curl+psql：create/list/delete via front-nginx `/api`（enforce ＋ audit）
```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"Super","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s 'http://127.0.0.1:31080/api/systemManage/getUserList?current=1&size=10' -H "Authorization: Bearer $TOKEN"
curl -s -X POST http://127.0.0.1:31080/api/systemManage/addUser -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"userName":"cvuser","nickName":"CV","userGender":"1","userPhone":"","userEmail":"","status":"1","userRoles":["R_USER_COMMON"]}'
psql "$PG_URL" -c "SELECT operation, entity_table, payload_after->'roles' FROM sys_operation_log ORDER BY id DESC LIMIT 1;"  # 斷 audit composite roles 在
# 再 addUser 同名 cvuser → 期 envelope code "2222"（dup、Q3 pre-check）
```

## C-V-5 — curl forbidden-role gate（→ `5003`）
```bash
TOKEN_USER=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"User","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s -X POST http://127.0.0.1:31080/api/systemManage/addUser -H "Authorization: Bearer $TOKEN_USER" \
  -H 'Content-Type: application/json' -d '{"userName":"x","userRoles":["R_USER_COMMON"]}'   # 期 envelope code "5003"（permission_denied；m002 只 seed R_SUPER 寫端）
```

## C-V-6 — CDP browser modal smoke（cutover → rust-api、限 `/manage/user`）
```bash
# 1) cutover：建 gitignored base-web/.env.test.local：
#    VITE_SERVICE_BASE_URL=http://rust-api:31081   （shadow apifox mock；*.local gitignored、不動 committed .env.test）
# 2) tests/000 CDP scripts（ws 9229、origin localhost:31079、static route mode）：
#    導航 /manage/user → 驗表格 envelope code "0000"（getUserList rust-api 真資料）
#    開 user CRUD modal → Runtime.evaluate 填表單（含 getAllRoles 角色下拉）→ 提交 add/update → 驗 modal 關＋列表刷新
#    刪除/批量刪除按鈕 → 驗
# 不導航 /manage/role、/manage/menu（rust-api 未實作、404）。
```

## C-V-7 — p95 server-side（list < 300ms、Q4、**新 C-V 類別**）
```bash
for i in $(seq 1 20); do
  curl -s -o /dev/null -w '%{time_total}\n' 'http://127.0.0.1:31080/api/systemManage/getUserList?current=1&size=10' \
    -H "Authorization: Bearer $TOKEN"
done | sort -n | awk 'NR==19{print "p95="$1"s"}'   # 排冷啟；server-side time_total
psql "$PG_URL" -c "SELECT count(*) FROM sys_user_role;"   # 驗 batch roles_for_users 避 N+1
```
write p95 < 500ms 同法（addUser/updateUser 計時、含同 txn audit）。**C-V-1~9（001-007）無 perf curl -w、008 首加**。

## C-V-8 — endpoint_coverage_lint stand-up（⚠️x 移交、首個 gated 刀）
```bash
cd rust-api && cargo test -p server endpoint_coverage_lint
```
新 build-failing lint：每掛 `enforce_mw` 的 route 有 ≥1 casbin policy（容忍 seeded-but-unimplemented policy）；以 `entity_access_lint` 為模板；`EXPECTED_ROUTE_COUNT` 用 wiring 時**實際 gated route 數**、別盲 assert 35（DESIGN target 僅參考）。

---

**驗收總綱**：C-V-1 build／C-V-2 純測／C-V-3 live smoke／C-V-4·5 curl+psql（含 dup 2222、forbidden 5003）／C-V-6 CDP modal（cutover）／C-V-7 p95 server-side／C-V-8 lint stand-up。無新 crate → 無 mandatory prod build。
