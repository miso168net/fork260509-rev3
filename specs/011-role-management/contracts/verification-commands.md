# C-V Contract: verification-commands（011-role-management、DB-first）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`（下簡 `EXEC`）。改 `.rs` 先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**。**無新 crate／無新 dep**。
> 帳號（m002）：`Super`(R_SUPER)/`Admin`(R_ADMIN)/`User`(R_USER_COMMON)、`123456`。psql：`docker compose … exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。
> **★ MOOT（零 migration）**：sys_role/sys_user_role/casbin_rule（11-col）/sys_casbin_policy_archive（13-col、本刀不消費）＋3 角色＋9 端點 policy＋`role:*` button code 皆 m001/m002（research R1/R6）。
> **★★ casbin policy 寫＝DB-first（constitution §I.7 §4.2、B1 校正）**：`sys_casbin_rule::set_role_dimension` 於 `mutate_in_txn` 直寫 `entity::casbin_rule`（11-col、原子 op-log、②protected-reject）→handler 寫後 `enforcer.write().await.load_policy()` reload。**絕不用 MgmtApi `remove_filtered_policy`/`add_policies`。** 審計**原子**（同 txn、非 best-effort）。
> **★★ 測 Role×Menu 必 cleanup（讀寫閉環需 committed 寫）**：set_role_dimension 經 mutate_in_txn **commit**（load_policy 須讀 committed DB 才見新集）→ **無法 txn-rollback 隔離** → C-V-5/9 必 **snapshot 角色原 v2='menu'→測→restore→psql 驗 casbin_rule 回原狀**（勿污染 seed）。
> **★ bare-filter 假綠**：整支 test binary 用 `--test <name>`／bin 內單元 `--bin server <filter>`；「0 passed; N filtered out」＝沒命中、非綠。

## C-V-0 · build 綠（無新 crate/dep；DB-first facade）
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server --locked'
```
- sys_role facade（list/find_active_by_id/create/update〔含 home〕/soft_delete/batch）＋sys_user_role count_users_by_role_id＋**sys_casbin_rule::set_role_dimension（DB-first、entity::casbin_rule 直寫）**＋handler 9 端點＋main 9 路由＋endpoint_coverage_lint 編譯綠；無新 dep（casbin 2.20.0/sea-orm 既有）；**無 MgmtApi 寫呼叫**。

## C-V-1 · 純測：delete guard／active_model／id↔route_name → FR-002/004
```bash
EXEC sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server --bin server role_delete_guard && cargo test -p server --bin server role_active_model'
```
- delete guard 三情境核心（seeded code 命中／in-use count>0／self-role code 命中）；build_create/build_update active_model（成對審計欄、update 不動 created_*）；id↔route_name 映射（若抽 pure helper）。看「N passed」非「0 filtered」。

## C-V-2 · 三守恆 lint（endpoint_coverage_lint [22→31]＋entity_access_lint）→ SC-008
```bash
EXEC sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test endpoint_coverage_lint && cargo test -p server --test entity_access_lint'
```
- `AS_BUILT_ROUTES [&str;31]`＝既 22＋9（role）；Assertion B registered==as-built；Assertion A 9 role policy 端點對應 m002 seed（getRoleList R_SUPER+R_ADMIN／其餘 R_SUPER／getRoleMenu·updateRoleMenu protected）；**entity_access_lint**：handler/auth/main 零 path-root entity::；**entity::casbin_rule 僅 `model/facade/sys_casbin_rule.rs`（豁免）**。

## C-V-3 · live role CRUD round-trip＋23505 dup → FR-002/003/SC-001/002
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_crud'
```
- 外層 txn rollback 隔離（**entity 寫可回滾**）：add（roleCode 唯一、INSERT op-log entity_id+真 INET+trace）→update（改 name/desc/status、UPDATE op-log）→soft_delete；**重複 roleCode→`Biz("biz.role.duplicateRoleCode")` 2222 非 5000**（sql_err 路徑）；getRoleList §5.8 filter（roleName 模糊／status 精確／空字串守門）。對應 SC-001/SC-002。

## C-V-4 · live delete guards 三情境＋整批拒 → FR-004/SC-003
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_guard'
```
- seeded（刪 R_SUPER/R_ADMIN/R_USER_COMMON→`seededProtected` 2222）／in-use（刪有 sys_user_role 指派→`inUse` 2222）／self（operator 刪自身角色→`cannotDeleteSelfRole` 2222）；**批次含可刪+不可刪→整批拒、DB 無變**；可刪 throwaway 無人用角色→可軟刪（外層 txn rollback 還原）。對應 SC-003。

## C-V-5 · ★ live Role×Menu DB-first 讀寫閉環＋②protected-reject＋**原子審計**（【須 cleanup】）→ FR-005/FR-008/SC-004/SC-007
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_menu_loop'
```
- **★★ 非 txn 隔離**（set_role_dimension mutate_in_txn commit、load_policy 讀 committed）→ 測**必 snapshot+restore**：① snapshot 測試角色（建議 throwaway 或 R_ADMIN）原 v2='menu' route_names；② updateRoleMenu 改集→set_role_dimension（**DB-first：entity::casbin_rule delete_many+insert**）；③ handler `load_policy()` reload 後 getRoleMenu 回新集（route_name→menu id）；④ `menu_routes_for_roles([code])`／getUserRoutes 該角色反映新集（**讀寫閉環**）；⑤ **★ F1 原子審計**：psql 驗 `sys_operation_log` 恰一筆 `entity_table='casbin_rule' ∧ entity_id=role_id ∧ operation='UPDATE'`、before/after=route_name 集（**與 casbin_rule 寫同 txn 原子**）；⑥ **②protected-reject**：試移除某 protected v2='menu'（如 R_SUPER 的 manage_menu）→`biz.role.menuProtected` 2222、casbin_rule **零變更**；⑦ **restore 原集** + psql 驗 casbin_rule 回原狀（無殘留）。對應 SC-004（讀寫閉環）＋**SC-007（原子審計）**。

## C-V-6 · live updateRoleHome → home 反映 → FR-006/SC-005
```bash
EXEC sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 role_home'
```
- updateRoleHome（entity 寫、**原子 op-log**、外層 txn rollback）→getRoleHome 回新值／`home_of_roles([code])` 反映；UPDATE op-log。（登入導向首頁之 user-facing 驗證見 C-V-9 CDP。）對應 SC-005（home value 端）。

## C-V-7 · live policy-gate（role 端點授權、含 batchDeleteRole）→ FR-007/SC-006
```bash
BASE=http://127.0.0.1:31081
TA=$(curl -s -X POST "$BASE/auth/login" -d '{"userName":"Admin","password":"123456"}' -H 'Content-Type: application/json' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s -o /dev/null -w "getRoleList=%{http_code}\n" "$BASE/systemManage/getRoleList" -H "Authorization: Bearer $TA"          # 200（R_ADMIN seed）
for ep in addRole updateRole deleteRole batchDeleteRole updateRoleMenu updateRoleHome; do \
  curl -s -o /dev/null -w "$ep=%{http_code}\n" -X POST "$BASE/systemManage/$ep" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{}'; done  # 皆 403/5003（非 super）
curl -s -o /dev/null -w "getRoleMenu=%{http_code}\n" "$BASE/systemManage/getRoleMenu?roleId=2" -H "Authorization: Bearer $TA"  # 403/5003（protected R_SUPER）
```
- Admin getRoleList→200（seed R_SUPER+R_ADMIN）；Admin/User 對 addRole/updateRole/**deleteRole/batchDeleteRole**/getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome→403/5003 不洩資料（C1 校正：batchDeleteRole 入負授權清單）；授權依 DB-fresh roles。對應 SC-006。

## C-V-8 · base-web typecheck（RoleUpsertModel ADAPT、wire number 域）→ SC-009/010
```bash
docker compose … exec -T base-web sh -c 'cd /app && pnpm typecheck'   # --no-verify commit、§8.2.1
```
- `rev3-system-manage.ts` role 8 wrapper＋`RoleUpsertModel` ADAPT 對齊既有 Role；wire roleId/menuIds **number 域**零型謊。

## C-V-9 · CDP 經 front-nginx 真 `/api`（role 頁＋menu-auth-modal＋★首頁導向、【須 cleanup】）→ SC-004/005/009
```bash
# 經 :31080/api（front-nginx strip）；CDP scripts 見 docs/superpowers/000 + tests/000；token 注入 SOY_token 繞 flaky login-form
```
- Super→/manage/role→分頁清單→新增（→**真發 addRole**→toast+列現）→改（→真發 updateRole）→**menu-auth-modal**：開某角色→getRoleMenu 勾選樹→改勾→存（→**真發 updateRoleMenu**）→**換該角色登入→側欄選單反映新指派**（讀寫閉環 D2）→設首頁（→真發 updateRoleHome）→**★ F2：換該角色登入→落地路由＝新首頁**（user-facing redirect 驗證、SC-005）→刪 throwaway 角色（→真發 deleteRole）；**斷言真發 request（非僅 toast）**；2222 toast 在地化（dup roleCode／**移除受保護選單→`menuProtected`**）；**hasAuth gating（非 super 無 role 寫入鈕、且 manage_role 選單不見）**；**★★ 測後 cleanup**（restore 改動角色原 v2='menu'、hard-delete 測試角色及殘留 policy、psql 驗 casbin_rule/sys_role 回原狀）。

## C-V-10 · 零回歸 → FR-010/SC-010
```bash
EXEC sh -c 'cd /app && cargo build -p server --locked' ; curl -fsS http://127.0.0.1:31081/health   # ok
cd rust-api && git diff 010後..HEAD --name-only | grep -iE "migration/|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
cd base-web && git diff 010後..HEAD --name-only | grep -iE "store/modules/route/|router/elegant/transform|service/api/system-manage|service/api/auth|service/request" && echo "⚠️違規" || echo "✅ 既有檔未動"
```
- /health 零回歸；login/getUserInfo/getUserRoutes/enforce_mw/require_policy/menu_routes_for_roles/buttons_for_roles/audit_mw/casbin Enforcer init·load_policy/008/009/010 不變；diff **零 migration/entity/schema**；`From<DbErr>` blanket 未改；**base-web route store/transform/system-manage.ts/auth.ts/request 不改**（只 rev3-* wrapper＋typings ADAPT＋MODAL-WIRING (a)(b) inline＋locale；**無 .env flip**；button-auth-modal 留 mock）；psql 驗 casbin_rule 無測試殘留（C-V-5/9 cleanup 後）。

## C-V-11 · prod target image build（無新 crate、輕）→ build 面
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認新 facade（sys_role CRUD/sys_user_role count/**sys_casbin_rule DB-first**）/handler(role 9)/lint 編入 prod target（無新 crate→無 Dockerfile COPY 變更；`--locked`）。

## 出口
C-V-0~11 全綠＝本刀 acceptance 通過；對應 spec SC-001~010。**無 migration／無新 crate。★ casbin 寫 DB-first（entity::casbin_rule 直寫、原子審計、②protected-reject、load_policy reload、無 MgmtApi）。★★ C-V-5/9 測 Role×Menu 必 snapshot+restore＋psql 驗無殘留。** getRoleList perf by inspection（§5.8 分頁、⚠️a 預算內）。
