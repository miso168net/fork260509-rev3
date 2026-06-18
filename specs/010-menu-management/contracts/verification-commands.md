# C-V Contract: verification-commands（010-menu-management）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`（下簡寫 `EXEC`）。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**（共用 op-log/seed、外層 txn rollback 隔離）。**無新 workspace crate**（prod build 輕）。
> 預設帳號（m002 seed）：`Super`(R_SUPER)/`Admin`(R_ADMIN)/`User`(R_USER_COMMON)、密碼 `123456`。psql：`docker compose … exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。
> **★ MOOT（無 migration）**：sys_menu 表＋10 baseline＋66 demo＋menu-visibility policy＋13 endpoint policy＋button code 已 m001/m002/m004 seed（research R1）。
> **★ bare-filter 假綠**：跑整支 test binary 用 `--test <name>`／bin 內單元 `--bin server <filter>`；「0 passed; N filtered out」＝沒命中、非綠。

## C-V-0 · build 綠（無新 crate、無新 dep）
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server --locked'
```
- enforce `menu_routes_for_roles`／facade sys_menu（10 fn＋ReparentError/DeleteError enum）／handler route.rs（3）＋system_manage menu（8）／menu→tree 序列化／main /route/* 分層＋/systemManage/*Menu*／endpoint_coverage_lint 編譯綠；無新 dep。

## C-V-1 · 純測：tree build／reparent guard／delete guard／序列化／wire id → FR-001/003/005/006/SC-003/004
```bash
EXEC sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server --bin server menu_tree && cargo test -p server --bin server reparent && cargo test -p server --bin server delete_guard && cargo test -p server --bin server wire'
```
- flat→tree（parent_id 巢狀、order 排序、孤兒處理）；reparent 4 情境（TargetMissing/NotDirectory/WouldCycle〔含自身後代〕/ProtectedFixed）；delete guard（Protected/HasActiveChildren）；menu→route 序列化（icon_type==2→localIcon／href／multiTab／menuType i16→'1'/'2'）；**id 兩域**（MenuRoute.id→string、Menu.id→number、parentId 0=頂層、2^53 fail-loud）。看「N passed」非「0 filtered」。

## C-V-2 · build_*_active_model 純測（6 審計欄成對）→ FR-004/005
```bash
EXEC sh -c 'cd /app && cargo test -p server --bin server active_model'
```
- create active_model：route_name/menu_name/created_at/created_by Set；update active_model：基本欄+updated_at/updated_by 成對、**created_* 不 Set**。

## C-V-3 · 三守恆 lint（endpoint_coverage_lint bump [11→22]＋entity_access_lint）→ FR-007/SC-010
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test endpoint_coverage_lint && cargo test -p server --test entity_access_lint'
```
- `AS_BUILT_ROUTES [&str;22]`＝既 11＋11（3 /route/*＋8 /systemManage/*Menu*）；Assertion B registered==as-built；Assertion A 8 policy-governed menu 端點皆對應 m002 seed（/route/* public·auth-only **非** policy-routes、Assertion A 不要求其 seed）；handler/route/main 零 path-root entity::（entity_access_lint 續綠）。

## C-V-4 · live getUserRoutes 三角色 Casbin 過濾差異（`--ignored --test-threads=1`）→ FR-001/SC-001
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 get_user_routes'
```
- in-crate `#[ignore]`：對 R_SUPER/R_ADMIN/R_USER_COMMON 各取 roles→`menu_routes_for_roles`→過濾 list_active→tree；斷言（research R12 oracle）：**R_SUPER 含 manage_menu/manage_system-settings/manage_policy-archive**、**R_ADMIN 不含上述但含 manage_user/manage_role**、**R_USER_COMMON 僅 home/function/function_toggle-auth**；home＝'home'。或 curl：Super/Admin/User 各登入→`GET /route/getUserRoutes`→比對 routes 集差異＋home。

## C-V-5 · live menu CRUD round-trip＋23505 dup → FR-004/005/SC-002/006
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 menu_crud'
```
- 外層 txn rollback 隔離：add（route_name 唯一、INSERT op-log entity_id+真 INET+trace）→update（改 menu_name/合法 reparent 到某目錄、UPDATE op-log）→soft_delete→restore；**重複 route_name→`Biz("biz.menu.duplicateRouteName")` 2222 非 5000**（sql_err 路徑）。

## C-V-6 · live reparent guard＋delete guard 四情境＋整批拒 → FR-005/006/SC-003/004
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 menu_guard'
```
- reparent：目標不存在→TargetMissing(2222)／目標非目錄(menu_type==2)→NotDirectory／搬成自身後代→WouldCycle／本選單 protected→ProtectedFixed；delete：protected 選單→Protected(2222)／有 active 子選單→HasActiveChildren(2222)；**批次含父+其子（子同批被選）→整批拒、DB 無變**（spec Clarification 逐項驗）。

## C-V-7 · live 回收桶統一清單＋restore 孤兒 → FR-003/006/007/SC-007
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 menu_recycle'
```
- getMenuList/v2（list_all）含已刪除節點＋`deleted` flag（active+deleted 同樹）；getUserRoutes/getMenuTree（list_active）**不含**已刪；restore 一個父已刪的選單→parent_id=None（頂層）、RESTORE op-log（首 Restore consumer、entity_id+before/after）。

## C-V-8 · live policy-gate（menu 端點 R_SUPER）→ FR-007/SC-008
```bash
BASE=http://127.0.0.1:31081
TA=$(curl -s -X POST "$BASE/auth/login" -d '{"userName":"Admin","password":"123456"}' -H 'Content-Type: application/json' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/systemManage/getMenuList/v2" -H "Authorization: Bearer $TA"        # 403（Admin 非 super）
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$BASE/systemManage/addMenu" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{...}'  # 403
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/route/getUserRoutes" -H "Authorization: Bearer $TA"                 # 200（auth-only、Admin 取自己選單）
```
- Admin/User 對 /systemManage/*Menu*→403/5003；/route/getUserRoutes auth-only→200（回各自過濾選單）；getConstantRoutes public→200 無 token。

## C-V-9 · base-web typecheck（wire id 兩域＋deleted flag ADAPT）→ SC-011
```bash
docker compose … exec -T base-web sh -c 'cd /app && pnpm typecheck'   # --no-verify commit、§8.2.1
```
- `rev3-system-manage.ts` menu wrapper＋`MenuUpsertModel`/deleted flag ADAPT 對齊既有 Menu/Api.Route；wire 3 端零型謊（MenuRoute.id string／Menu.id number）。

## C-V-10 · CDP 經 front-nginx 真 `/api`（★.env dynamic 後、modal 真發 request）→ SC-001/002/004/007/008
```bash
# 經 :31080/api（front-nginx strip）；CDP scripts 見 docs/superpowers/000 + tests/000；token 注入 SOY_token 繞 flaky login-form
```
- **★ .env dynamic 後**：Super/Admin/User 三角色登入→側欄選單差異（**非 super 不見 manage_menu/system-settings 等 admin 選單**＝D1 選單可見性兌現）；login/404/403 可達（builtin、R-cr 確認）。Super→/manage/menu→統一清單（含已刪除欄）→新增（填表+父選擇 getMenuTree+page getAllPages→**真發 addMenu**→toast+列現）→編輯/reparent（→真發 updateMenu）→刪除（→真發 deleteMenu→已刪除列）→restore（→真發 restoreMenu→復活）→批次刪；**斷言真發 request（非僅 toast）**；2222 toast 經 `$t` 在地化；**非 super 無 menu/user 寫入鈕**（hasAuth gating）。getUserRoutes 失敗→導回登入（不白屏、FR-002）。

## C-V-11 · 零回歸 → FR-012/SC-011
```bash
EXEC sh -c 'cd /app && cargo build -p server --locked' ; curl -fsS http://127.0.0.1:31081/health   # ok
cd rust-api && git diff 009後..HEAD --name-only | grep -iE "migration/|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
cd base-web && git diff 009後..HEAD --name-only | grep -iE "store/modules/route/|router/elegant/|service/api/system-manage|service/api/auth|service/request" && echo "⚠️違規" || echo "✅ 既有檔未動"
```
- /health 零回歸；login/getUserInfo/enforce_mw/require_policy/buttons_for_roles/audit_mw/008 settings/009 user 不變；diff **零 migration/entity/schema**；`From<DbErr>` blanket 未改；**base-web route store/transform/system-manage.ts/.d.ts/auth.ts/request 不改**（只 .env mode＋rev3-* wrapper＋typings ADAPT＋MODAL-WIRING (a)(b) inline＋locale）；**.env flip 後 user/settings 頁本身不回歸**（僅選單可見性依角色變）。

## C-V-12 · prod target image build（無新 crate、輕）→ build 面
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認新 enforce/facade/handler(route+menu)/序列化/lint 編入 prod target（無新 crate→無 Dockerfile COPY 變更；`--locked`）。

## 出口
C-V-0~12 全綠＝本刀 acceptance 通過；對應 spec SC-001~011（SC-011 zero-regression＋wire；getUserRoutes perf by inspection：每登入一次、tree build O(n)、⚠️a 預算內）。**無 migration／無新 crate。★ .env dynamic flip 為 base-web 單元最後一步（getUserRoutes C-V-4 先綠）。**
