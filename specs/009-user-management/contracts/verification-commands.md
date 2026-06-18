# C-V Contract: verification-commands（009-user-management）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`（下簡寫 `EXEC`）。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**（共用 op-log/seed、外層 txn rollback 隔離）。**無新 workspace crate**（prod build 輕）。
> 預設帳號（m002 seed）：`Super`(R_SUPER)/`Admin`(R_ADMIN)/`User`(R_USER_COMMON)、密碼 `123456`。DB（容器內）：`/run/secrets/database_url`；psql：`docker compose … exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。
> **★ MOOT（無 migration）**：表＋partial-unique＋6 端點 p-policy 已 m001/m002/m003 seed（research R1）；本刀無 schema 變更。
> **★ bare-filter 假綠**：跑整支 test binary 用 `--test <name>`；看到「0 passed; N filtered out」＝沒命中、非綠。

## C-V-0 · build 綠（無新 crate、無新 dep）
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server --locked'
```
- facade（sys_user 4 fn／sys_user_role 3 fn／sys_role find_active）／auth hash_password／handler system_manage（6）／login gate／main users router／error sql_err map／endpoint_coverage_lint 編譯綠；`LOWER(col) LIKE ... ESCAPE`（原 `PgExpr::ilike` runtime 失效、改 `BinOper::Like`＋LOWER、見 research R6 校正）/`apply_if`/`PaginatorTrait`/`SqlErr` 解析（sea-orm 1.1.20）；無新 dep。

## C-V-1 · filter/page normalize＋escape_like 純測 → FR-001/SC-001
```bash
EXEC sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server normalize'
```
- 空字串→None（`""`→skip）；非空字串→ILIKE pattern；status/gender `Some("")→Ok(None)`、`"1"/"2"→Some(1/2)`；page current 默 1·max(1)、size 默 10·clamp[1,100]；`escape_like("a%_\\")`=`"a\\%\\_\\\\"`（backslash 先）。

## C-V-2 · build_*_active_model 純測（6 審計欄成對）→ FR-004/005/SC-003/004
```bash
EXEC sh -c 'cd /app && cargo test -p server active_model'
```
- create active_model：user_name/password/created_at/created_by Set、session_policy `"inherit"`；update active_model：基本欄+`updated_at`/`updated_by` 成對 Set、**user_name/password 不 Set**。

## C-V-3 · id 序列化 2^53 guard＋enum i16↔string 純測 → FR-010
```bash
EXEC sh -c 'cd /app && cargo test -p server wire'
```
- id>2^53 fail-loud；`Some(1i16)→"1"`/`Some(2i16)→"2"`/`None→null`（userGender/status）；createBy `Some(7i64)→"7"`/`None→""`。

## C-V-4 · endpoint_coverage_lint（bump +6）→ FR-010/SC-009
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test endpoint_coverage_lint'
```
- `AS_BUILT_ROUTES [&str;11]`＝既 5＋6 user distinct path；Assertion B registered==as-built（main.rs route 集 == 陣列）；Assertion A 6 policy-governed route 皆對應 m002 p-policy seed。「N passed」非「0 filtered」。

## C-V-5 · entity_access_lint 守恆 → SC-010
```bash
EXEC sh -c 'cd /app && cargo test -p server --test entity_access_lint'
```
- handler/error/main 零 path-root `entity::`（entity 全在 facade、續綠）。

## C-V-6 · live addUser→INSERT op-log INET round-trip＋23505 dup（`--ignored --test-threads=1`）→ FR-003/004/006/SC-003
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 add_user'
```
- in-crate `#[ignore]` smoke（外層 txn rollback 不污染 seed）：顯式 operator(`AuditOperator{id,ip:Some(IpNetwork)}`)+trace→create+replace_roles_in_txn 同 txn → psql `sys_user` 新列（password 經 argon2 `verify("123456")` 通過）+`sys_user_role`(指派 role)+`sys_operation_log` 末列 `operation='INSERT'`/`entity_id`=新 id/`operator_id`/`operator_ip`(真 INET)/`trace_id` 非空；**重複 user_name→`AppError::Biz("biz.user.duplicateUserName")`（2222、非 5000）**（sql_err 路徑、research R5）。

## C-V-7 · live updateUser（userName/password 不變、roles 替換、self-guard）→ FR-004/SC-004
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 update_user'
```
- update 既有 user：nick/gender/phone/email/status 變、**user_name 與 password hash 不變**（psql 比對）、`sys_user_role` 替換為新 code 集、op-log `UPDATE`；查無 id→`Biz("biz.user.notFound")`；**self-guard**：operator 改自己移除 R_SUPER ∥ 設自己 status=2 → `Biz("biz.user.selfLockForbidden")` 2222 整筆不執行（DB 無變）。

## C-V-8 · live delete/batch（soft-delete、cannot-delete-self、缺漏略過）→ FR-005/SC-005
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 delete_user'
```
- soft_delete→`deleted_at`/`deleted_by` 成對、不再現於 `find_active`、op-log `SOFT_DELETE` entity_id Some(id)；**含 operator 自身 id（單筆或批次）→`Biz("biz.user.cannotDeleteSelf")` 整批拒、DB 無任何變**；批次含已不存在/已刪 id→該等靜默略過、其餘有效照刪（idempotent、clarify Q2）。

## C-V-9 · live getUserList（分頁+模糊+精確+空字串守門+超範圍+零 password）→ FR-001/002/SC-001/002
```bash
BASE=http://127.0.0.1:31081
TS=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
# 空字串 filter（★模擬前端、不可回 0 列）：
curl -s "$BASE/systemManage/getUserList?current=1&size=10&userName=&userGender=&nickName=&userPhone=&userEmail=&status=" -H "Authorization: Bearer $TS"   # records 非空、total 真實
# 模糊 userName（子字串、大小寫不敏感）：
curl -s "$BASE/systemManage/getUserList?current=1&size=10&userName=us" -H "Authorization: Bearer $TS"   # 命中 User 等含 "us"
# 精確 userPhone：
curl -s "$BASE/systemManage/getUserList?current=1&size=10&userPhone=<完整號>" -H "Authorization: Bearer $TS"   # 全等才回
# 超範圍頁：
curl -s "$BASE/systemManage/getUserList?current=999&size=10" -H "Authorization: Bearer $TS"   # records:[]、total 真實
```
- 回 `{data:{records:[{id:number,userName,userGender,nickName,userPhone,userEmail,status,userRoles:[code],createBy,createTime,updateBy,updateTime}],current,size,total},code:"0000"}`；**記錄無 `password` 欄**（grep 回應）；id 為 number；userGender/status `"1"/"2"/null`。**★ 空字串守門必過**（rev2 整頁 0 列 regression 防線）。

## C-V-10 · live policy-gate＋停用登入 → FR-007/009/SC-006/007
```bash
TA=$(curl -s -X POST "$BASE/auth/login" -d '{"userName":"Admin","password":"123456"}' -H 'Content-Type: application/json' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/systemManage/getUserList" -H "Authorization: Bearer $TA"   # 200（Admin 可讀 list）
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$BASE/systemManage/addUser" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{...}'   # 403（Admin 寫被擋）
TU=$(curl -s -X POST "$BASE/auth/login" -d '{"userName":"User","password":"123456"}' -H 'Content-Type: application/json' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/systemManage/getUserList" -H "Authorization: Bearer $TU"   # 403（User 讀 list 被擋）
# 停用登入：Super 把某 user status=2 → 該 user 登入 → code 1000
curl -s -X POST "$BASE/auth/login" -d '{"userName":"<disabled>","password":"123456"}' -H 'Content-Type: application/json'   # code:"1000"（統一失敗、不洩停用）
```
- Admin 讀 list 200、寫 403/5003；User 讀 list 403/5003；停用 user 登入→1000（與帳密錯同訊息）。授權 DB-fresh roles（不信 claims.roles）。

## C-V-11 · CDP 經 front-nginx 真 `/api`（★空 param+模糊、modal 真發 request）→ SC-008
```bash
# 經 :31080/api（front-nginx strip）；CDP scripts 見 docs/superpowers/000 + tests/000
```
- Super 登入→/manage/user 頁→**搜尋（刻意全空＝回全部非 0 列；模糊 userName 子字串）**→新增（填表+選角色 chip 真 code→真發 addUser→toast 成功+列表現新列）→編輯（改暱稱/角色→真發 updateUser）→刪除（NPopconfirm→真發 deleteUser→列消失）→批次刪→真發 batchDeleteUser；**斷言真發 request（非僅 toast、stub 假綠防線）**；2222 toast 經 `$t` 在地化；角色下拉用真 getAllRoles（mock workaround 已移除、chip 顯真 code）。非 super→403。

## C-V-12 · base-web typecheck（wire 3 端＋write DTO）→ SC-008
```bash
docker compose … exec -T base-web sh -c 'cd /app && pnpm typecheck'   # --no-verify commit、§8.2.1
```
- `rev3-system-manage.ts` wrapper＋`rev3-system-manage.d.ts`(UserUpsertModel) 對齊既有 User/UserSearchParams/AllRole；wire 3 端零型謊。

## C-V-13 · 零回歸 → SC-010
```bash
EXEC sh -c 'cd /app && cargo build -p server --locked' ; curl -fsS http://127.0.0.1:31081/health   # ok
cd rust-api && git diff --name-only 008後..HEAD | grep -iE "migration/|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
```
- /health 零回歸；login/getUserInfo/enforce_mw/require_policy/audit_mw/008 settings 不變；diff **零 migration/entity/schema**；`From<DbErr>` blanket 未改；base-web 既有 system-manage.ts/.d.ts/auth.ts/request 攔截器不改（只新增 rev3-* wrapper+typings+MODAL-WIRING (a) inline+locale 加 key）。

## C-V-14 · prod target image build（無新 crate、輕）→ build 面
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認新 facade/handler/login gate/error map/lint 編入 prod target（無新 crate→無 Dockerfile COPY 變更；`--locked`）。

## 出口
C-V-0~14 全綠＝本刀 acceptance 通過；對應 spec SC-001~011（SC-011 perf by inspection：list 讀 flat 分頁 SELECT+roles 批次、寫單列+同 txn 審計+1 roles_of_user join，⚠️a 預算內；可選 `curl -w '%{time_total}'` spot-check）。**無 migration／無新 crate。**
