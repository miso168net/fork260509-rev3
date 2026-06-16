# Verification Commands — Role Management（009）C-V Contract

> Phase 1 contract（/speckit-plan）。每項 C-V ＝ acceptance 驗收命令骨架；implementer 實作後逐項跑綠。實際值（`$PG_URL`／`$TOKEN`／role body）見 quickstart.md。
> **prod-build 紀律（CLAUDE.md §3 Phase 1）**：009 **不新增 workspace crate**（members 固定 5：`server`/`migration`/`sea-orm-adapter`/`entity`/`xdb`、僅加 handler/facade 到既有 `server` crate）→「新 crate 必跑 prod target image build」**不觸發**；dev build 綠 ＋ live smoke 即足。**若實作中改為新增 crate，必補**：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`。
> **CDP 紀律**：本刀 CDP 不 defer（沿 008、C-V-6 這刀做）；curl 直送 ≠ base-web modal 對齊，C-V-4/5（curl）與 C-V-6（CDP）皆須跑。

## C-V-0 — workspace 構型守恆（無新 crate、analyze C3）
```bash
cd rust-api && cargo metadata --no-deps --format-version 1 \
  | python3 -c "import json,sys; p=json.load(sys.stdin)['packages']; print('members:',len(p), sorted(x['name'] for x in p))"
# 期 5（server / migration / sea-orm-adapter / entity / xdb）。實作前後各跑一次；變 6 = 誤加 crate → 必補 prod image build。
```

## C-V-1 — build ＋ MSRV lock
```bash
cd rust-api && cargo build -p server --locked   # MSRV 1.86；無新依賴、無新 crate
```

## C-V-2 — 純單測（test-first where pure、零 DB/HTTP）
```bash
cd rust-api && cargo test -p server   # search_active filter SQL-shape（roleName/roleCode LIKE %x%、status eq、null/blank 略過、id ASC）／i16↔string enum（status null）／2^53 id guard／種子謂詞 is_seed_role id∈{1,2,3}／dup→2222 pre-check 判定／endpoint_coverage_lint scan_tests
```
用既有 `build(DbBackend::Postgres).to_string()` pattern（如 008 `find_active_filters_soft_deleted`）斷言 SQL 形、零 DB。

## C-V-3 — live smoke（`#[ignore]`、真 PG、`--test-threads=1`）
```bash
cd rust-api && cargo test -p server -- --ignored --test-threads=1 live_smoke_role
```
覆蓋：addRole→op-log **Insert** 列（payload_after = role 12 欄、**無 roles、無 password**）／updateRole→**Update** 列（before/after：name/role_desc/status 變、**roleCode 不變**）／deleteRole→**SOFT_DELETE** 列（payload_before、after=None）／already-deleted→**no-op 零 audit**／dup roleCode→**2222**（pre-check）／並發撞碼（DB `23505`）→**2222**（非 5000、clarify A）／種子保護 id∈{1,2,3}→**2222**／getRoleList **模糊** filter（roleName/roleCode 部分字串命中）＋分頁＋id ASC。
（serial：共表 `sys_operation_log` 非 parallel-safe、memory `live-ignore-tests-need-serial`；live smoke 須 `#[cfg(test)] mod` 於 `src/`〔server 為 bin-only crate〕、bracketed cleanup。）

## C-V-4 — curl+psql：create/list/delete via front-nginx `/api`（enforce ＋ leaf audit ＋ dup 2222）
```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"Super","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s 'http://127.0.0.1:31080/api/systemManage/getRoleList?current=1&size=10' -H "Authorization: Bearer $TOKEN"
curl -s -X POST http://127.0.0.1:31080/api/systemManage/addRole -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"roleName":"CV角色","roleCode":"R_CV_TEST","roleDesc":"cv","status":"1"}'
psql "$PG_URL" -c "SELECT operation, entity_table, payload_after->>'code' FROM sys_operation_log ORDER BY id DESC LIMIT 1;"  # 斷 Insert + leaf payload（無 roles key）
# 再 addRole 同碼 R_CV_TEST → 期 envelope code "2222"（dup、pre-check）
# updateRole 改 R_CV_TEST 的 roleName + 試圖改 roleCode → 期 roleName 變、roleCode 不變（psql 驗）
# deleteRole id=<R_CV_TEST id> → soft-delete；deleteRole id=1（種子）→ 期 "2222"
```

## C-V-5 — curl enforce gate（讀寫分權 ＋ forbidden→`5003`）
```bash
# R_ADMIN：可讀 getRoleList（→0000）、但寫 addRole→5003
TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"Admin","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s 'http://127.0.0.1:31080/api/systemManage/getRoleList?current=1&size=10' -H "Authorization: Bearer $TOKEN_ADMIN"  # 期 0000（R_ADMIN 可讀）
curl -s -X POST http://127.0.0.1:31080/api/systemManage/addRole -H "Authorization: Bearer $TOKEN_ADMIN" \
  -H 'Content-Type: application/json' -d '{"roleName":"x","roleCode":"R_X","status":"1"}'  # 期 "5003"（R_ADMIN 無寫端 policy）
# R_USER_COMMON：連 getRoleList 都 5003（m002 只授 R_SUPER+R_ADMIN）
TOKEN_USER=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"User","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s 'http://127.0.0.1:31080/api/systemManage/getRoleList?current=1&size=10' -H "Authorization: Bearer $TOKEN_USER"  # 期 "5003"
```

## C-V-6 — CDP browser modal smoke（cutover → rust-api、限 `/manage/role`）
```bash
# 1) cutover：base-web/.env.test.local（008 已建、gitignored、複用）：
#    VITE_SERVICE_BASE_URL=http://rust-api:31081   （shadow apifox mock；*.local gitignored、不動 committed .env.test）
#    改 env 後須【重啟 base-web 容器】+ 待 healthy（vite 啟動讀 env）。
# 2) tests/000 CDP scripts（ws 9229、origin localhost:31079、static route mode）：複用 cdp-login.mjs/cdp-nav.mjs/cdp-capture-api.mjs，改選擇器對 role 頁：
#    quick-login(Super) → 導航 /manage/role → 驗表格 envelope code "0000"（getRoleList rust-api 真 3 角色、非 mock faker）
#      ★ list-load 載出真 3 角色 = 空字串 filter 守門正確（blank_to_none/wire_to_i16）；空列/2222 = 漏套（008 同款 bug）
#    開 role CRUD drawer → Runtime.evaluate 填 roleName/roleCode/roleDesc/status → 提交 add → 驗 drawer 關 + 列表刷新
#    開 edit drawer → 驗 roleCode 欄 disabled（FR-006）→ 改 roleName → 提交 → 驗
#    刪除 / 批量刪除按鈕 → 驗（非種子角色）
# 不導航 /manage/menu（前端在、rust-api 未實作→404）。
```

## C-V-7 — p95 server-side（list < 300ms、write < 500ms、⚠️a）
```bash
for i in $(seq 1 20); do
  curl -s -o /dev/null -w '%{time_total}\n' 'http://127.0.0.1:31080/api/systemManage/getRoleList?current=1&size=10' \
    -H "Authorization: Bearer $TOKEN"
done | sort -n | awk 'NR==19{print "list p95="$1"s"}'   # 排冷啟；server-side time_total；期 < 0.3s
```
write p95 < 500ms 同法（addRole/updateRole 計時、含同 txn audit）。role 表小（3+ 列）、無 N+1（leaf、無 join）→ 預期遠優於上限。

## C-V-8 — endpoint_coverage_lint bump（6 → 11、⚠️x SC-009 硬 gate）
```bash
cd rust-api && cargo test -p server endpoint_coverage_lint
```
改 `server/tests/endpoint_coverage_lint.rs`：`EXPECTED_ROUTE_COUNT` **6→11**（5 條 role route 加進 main.rs 後 lint 動態 derive 為 11、policy 皆已 seed〔R5〕→ 綠）；更新檔頭 doc 註解（role 端點不再是「seeded-but-unimplemented」範例、改舉 menu）。結構零改（count guard 外全自動）。controller sanity-bite：故意破一條 role policy/route → lint 須大聲失敗指名。

---

## SC ↔ C-V 對照（analyze V1）

| SC | C-V |
|---|---|
| SC-001 定位+編輯 <30s | C-V-6 CDP／C-V-4 curl（手測計時） |
| SC-002 100% 變更審計（no-op 零 audit） | C-V-3 live smoke（Insert/Update/SOFT_DELETE 列＋already-deleted no-op） |
| SC-003 edit before/after 審計 | C-V-3（update before/after：name/desc/status） |
| SC-004 種子不可刪 | C-V-3／C-V-4（種子 id∈{1,2,3}→2222、單+批） |
| SC-005 無重複 active code | C-V-2（dup 判定）＋C-V-3/4（同碼→2222、含 23505 race→2222） |
| SC-006 移除角色不再授權（inert） | C-V-3 facade-level（soft-deleted role 不入 roles_for_user；R6 active-filter 佐證）＋ curl 驗刪後不計入 |
| SC-007 0 越權 | C-V-5（R_ADMIN 寫→5003、R_USER_COMMON 讀→5003） |
| SC-008 p95 | C-V-7 |
| SC-009 0 裸端點 | C-V-8 endpoint_coverage_lint（EXPECTED=11） |
| SC-010 真打後端 | C-V-6 CDP（cutover→rust-api:31081、非 mock）＋C-V-4 curl+psql |

> **SC-010 live-vs-mock 稽核（analyze C2）**：跑 C-V-6 前確認 `base-web/.env.test.local` 的 `VITE_SERVICE_BASE_URL=http://rust-api:31081`（非 apifox mock）＋重啟 base-web；CDP capture 應見 request 落 rust-api、回真 envelope（非 mock 範本）。
> **SC-006 量法**：role 為 leaf、刪除即 soft-delete；inert 由既有 `roles_for_user`→`find_active_by_ids`（deleted_at 濾）保證（R6 實碼佐證），本刀不改該路徑 → facade-level 斷言「軟刪 role 不出現在某 user 的 effective codes」即足（無需重測 enforce 基盤）。

**驗收總綱**：C-V-0 workspace 守恆／C-V-1 build／C-V-2 純測／C-V-3 live smoke（leaf audit、dup 2222、23505 race 2222、種子 2222）／C-V-4·5 curl+psql（含 dup 2222、讀寫分權 5003）／C-V-6 CDP modal（cutover、roleCode disabled、空字串 filter 守門）／C-V-7 p95／C-V-8 lint bump 11。無新 crate → 無 mandatory prod build。
