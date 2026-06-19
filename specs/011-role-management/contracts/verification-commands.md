# C-V Contract: verification-commands（011-role-management）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`（下簡寫 `EXEC`）。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**。**無新 workspace crate**（prod build 輕）。
> 預設帳號（m002 seed）：`Super`(R_SUPER)/`Admin`(R_ADMIN)/`User`(R_USER_COMMON)、密碼 `123456`。psql：`docker compose … exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。
> **★ MOOT（無 migration）**：sys_role/sys_user_role/casbin_rule＋3 角色＋9 端點 policy＋`role:*` button code 已 m001/m002 seed（research R1/R6）。
> **★★ casbin policy 寫【非 txn-rollback 隔離】**：set_role_menu_policies 經 adapter **自有連線** auto-persist 到 casbin_rule（≠ entity live 測的外層 txn rollback）→ **凡測 updateRoleMenu 的 live／CDP 必【顯式 cleanup】**（snapshot 該 role 原 v2='menu' policy → 測後 restore；或用 throwaway 測試角色 + 測後移除其 policy + hard-delete 角色）。**勿污染 seed**（同 010 CDP cdp_smoke hard-delete 教訓、但此處連 in-crate live 也須手動清、因 casbin 寫不回滾）。
> **★ bare-filter 假綠**：跑整支 test binary 用 `--test <name>`／bin 內單元 `--bin server <filter>`；「0 passed; N filtered out」＝沒命中、非綠。

## C-V-0 · build 綠（無新 crate、無新 dep）
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server --locked'
```
- sys_role facade（list/create/update/soft_delete/batch/find_active_by_id）＋sys_user_role count_users_by_role_id＋auth set_role_menu_policies（MgmtApi）＋handler 9 端點＋main 9 路由＋endpoint_coverage_lint 編譯綠；無新 dep（casbin 2.20.0 既有）。

## C-V-1 · 純測：delete guard／id↔route_name／build_active_model → FR-002/004
```bash
EXEC sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server --bin server role_delete_guard && cargo test -p server --bin server role_active_model'
```
- delete guard 三情境核心（seeded code 命中／in-use count>0／self-role code 命中）；build_create active_model（set created_*）／build_update（updated_* 成對、created_* 不動）；id↔route_name 映射（若抽 pure helper）。看「N passed」非「0 filtered」。

## C-V-2 · 三守恆 lint（endpoint_coverage_lint bump [22→31]＋entity_access_lint）→ SC-008
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test endpoint_coverage_lint && cargo test -p server --test entity_access_lint'
```
- `AS_BUILT_ROUTES [&str;31]`＝既 22＋9（role）；Assertion B registered==as-built；Assertion A 9 policy-governed role 端點皆對應 m002 seed（getRoleList R_SUPER+R_ADMIN／其餘 R_SUPER／getRoleMenu·updateRoleMenu protected）；handler/auth/main 零 path-root entity::（set_role_menu_policies 用 enforcer 非 entity::）。

## C-V-3 · live role CRUD round-trip＋23505 dup → FR-002/003/SC-001/002
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_crud'
```
- 外層 txn rollback 隔離（**entity 寫**：create/update/soft_delete 可回滾）：add（roleCode 唯一、INSERT op-log entity_id+真 INET+trace）→update（改 name/desc/status、UPDATE op-log）→soft_delete；**重複 roleCode→`Biz("biz.role.duplicateRoleCode")` 2222 非 5000**（sql_err 路徑）；getRoleList §5.8 filter（roleName 模糊 LOWER LIKE／status 精確／空字串守門）。

## C-V-4 · live delete guards 三情境＋整批拒 → FR-004/SC-003
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_guard'
```
- seeded（刪 R_SUPER/R_ADMIN/R_USER_COMMON→`seededProtected` 2222）／in-use（刪有 sys_user_role 指派之角色→`inUse` 2222）／self（operator 刪自身角色→`cannotDeleteSelfRole` 2222）；**批次含可刪+不可刪→整批拒、DB 無變**（逐項驗）。可刪正向：建 throwaway 無人用角色→可軟刪（外層 txn rollback 還原）。

## C-V-5 · ★ live Role×Menu 讀寫閉環（casbin WRITE、【須 cleanup】）→ FR-005/SC-004
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_menu_loop'
```
- **★★ 非 txn 隔離**：set_role_menu_policies 經 adapter auto-persist casbin_rule（外層 txn 不回滾）→ 測**必 snapshot+restore**：① 記某測試角色（建議 throwaway 或 R_ADMIN）原 v2='menu' route_names；② updateRoleMenu 改集（remove_filtered+add_policies）；③ getRoleMenu 回新集（route_name→menu id）；④ `menu_routes_for_roles([code])`／getUserRoutes 該角色反映新集；⑤ **restore 原集**（set_role_menu_policies 還原）。op-log best-effort 記一筆（非原子、R2）。**測完 psql 驗 casbin_rule 該角色 v2='menu' 回原狀**（無殘留污染）。

## C-V-6 · live updateRoleHome → home 反映 → FR-006/SC-005
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_home'
```
- updateRoleHome（entity 寫、**原子 op-log**、外層 txn rollback）→getRoleHome 回新值／`home_of_roles([code])` 反映；UPDATE op-log。

## C-V-7 · live policy-gate（role 端點授權）→ FR-007/SC-006
```bash
BASE=http://127.0.0.1:31081
TA=$(curl -s -X POST "$BASE/auth/login" -d '{"userName":"Admin","password":"123456"}' -H 'Content-Type: application/json' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/systemManage/getRoleList" -H "Authorization: Bearer $TA"          # 200（R_ADMIN seed）
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$BASE/systemManage/addRole" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{...}'  # 403/5003（非 super）
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/systemManage/getRoleMenu?roleId=2" -H "Authorization: Bearer $TA"  # 403/5003（protected R_SUPER）
```
- Admin getRoleList→200（seed R_SUPER+R_ADMIN）；Admin/User 對 addRole/updateRole/deleteRole/getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome→403/5003 不洩資料；授權依 DB-fresh roles。

## C-V-8 · base-web typecheck（RoleUpsertModel ADAPT、wire number 域）→ SC-009/010
```bash
docker compose … exec -T base-web sh -c 'cd /app && pnpm typecheck'   # --no-verify commit、§8.2.1
```
- `rev3-system-manage.ts` role 8 wrapper＋`RoleUpsertModel` ADAPT 對齊既有 Role；wire roleId/menuIds number 域零型謊。

## C-V-9 · CDP 經 front-nginx 真 `/api`（role 頁＋menu-auth-modal 真發、【須 cleanup】）→ SC-004/009
```bash
# 經 :31080/api（front-nginx strip）；CDP scripts 見 docs/superpowers/000 + tests/000；token 注入 SOY_token 繞 flaky login-form
```
- Super→/manage/role→分頁清單→新增角色（填表→**真發 addRole**→toast+列現）→改（→**真發 updateRole**）→**menu-auth-modal**：開某角色→getRoleMenu 勾選樹→改勾→存（**真發 updateRoleMenu**）→**換該角色登入→側欄選單反映新指派**（讀寫閉環、D2）→設角色首頁（**真發 updateRoleHome**）→刪 throwaway 角色（→真發 deleteRole）；**斷言真發 request（非僅 toast）**；2222 toast 在地化（dup roleCode）；**hasAuth gating**：非 super 無 role 寫入鈕（且非 super 連 manage_role 選單都不見）。**★★ CDP 改了 casbin policy／建了角色 → 測後 cleanup**（restore 改動角色的原 v2='menu'、hard-delete 測試角色及其殘留 policy；psql 驗 casbin_rule/sys_role 回原狀）。

## C-V-10 · 零回歸 → FR-010/SC-010
```bash
EXEC sh -c 'cd /app && cargo build -p server --locked' ; curl -fsS http://127.0.0.1:31081/health   # ok
cd rust-api && git diff 010後..HEAD --name-only | grep -iE "migration/|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
cd base-web && git diff 010後..HEAD --name-only | grep -iE "store/modules/route/|router/elegant/transform|service/api/system-manage|service/api/auth|service/request" && echo "⚠️違規" || echo "✅ 既有檔未動"
```
- /health 零回歸；login/getUserInfo/getUserRoutes/enforce_mw/require_policy/menu_routes_for_roles/buttons_for_roles/audit_mw/008/009/010 不變；diff **零 migration/entity/schema**；`From<DbErr>` blanket 未改；**base-web route store/transform/system-manage.ts/auth.ts/request 不改**（只 rev3-* wrapper＋typings ADAPT＋MODAL-WIRING (a)(b) inline＋locale；**無 .env flip**）；psql 驗 casbin_rule 無測試殘留（C-V-5/9 cleanup 後）。

## C-V-11 · prod target image build（無新 crate、輕）→ build 面
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認新 facade/auth(set_role_menu_policies)/handler(role 9)/lint 編入 prod target（無新 crate→無 Dockerfile COPY 變更；`--locked`）。

## 出口
C-V-0~11 全綠＝本刀 acceptance 通過；對應 spec SC-001~010。**無 migration／無新 crate。★★ casbin policy 寫非 txn 隔離→ C-V-5/9 必顯式 cleanup、psql 驗無殘留。** getRoleList perf by inspection（§5.8 分頁、⚠️a 預算內）。
