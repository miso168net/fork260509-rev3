# Quickstart: 011-role-management 驗證指南

> 角色 CRUD＋角色×選單授權（**DB-first casbin policy WRITE**）＋角色首頁。驗收命令全集＝[contracts/verification-commands.md](contracts/verification-commands.md)（C-V-0~11）；設計＝[data-model.md](data-model.md)／[plan.md](plan.md)；不變式＝[contracts/role-management-contract.md](contracts/role-management-contract.md)。**零 migration／無新 crate。**
> **★ B1 校正**：Role×Menu 寫採 **DB-first**（facade 直寫 `entity::casbin_rule` 於 mutate_in_txn 原子 op-log、②protected-reject、寫後 `load_policy()` reload、無 MgmtApi）——constitution §I.7 §4.2。

## 前置
- dev stack healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（5 service healthy、migrate exited）。
- 帳號（m002）：`Super`/`Admin`/`User`、密碼 `123456`。
- **零 migration 親驗**：psql 確認 sys_role 3 角色（home='home'）、sys_user_role 指派（3 角色皆 in-use）、9 role 端點 casbin policy、`role:*` button code、casbin_rule（11-col、含 protected）皆已 seed（research R1/R6）。
- rust 驗證一律容器內（`docker exec`）；改 `.rs` 先 force-touch；live `--test-threads=1`＋`DATABASE_URL`。

## 核心驗證流程（end-to-end）

1. **build＋lint＋純測**（C-V-0/1/2）：容器內 `cargo build -p server --locked`（無 MgmtApi 寫）；`role_delete_guard`/`role_active_model` 純測；`endpoint_coverage_lint`（[31]）＋`entity_access_lint`（entity::casbin_rule 僅 sys_casbin_rule facade）綠。
2. **role CRUD live**（C-V-3）：role_crud round-trip（add/update/soft_delete、外層 txn rollback）＋roleCode dup→`biz.role.duplicateRoleCode` 2222（非 5000）。
3. **delete guards live**（C-V-4）：seeded/in-use/self 三守門→2222；批次整批拒 DB 無變。
4. **★ Role×Menu DB-first 讀寫閉環 live**（C-V-5、**casbin 寫 commit→必 snapshot+restore**）：snapshot 角色原 v2='menu' → updateRoleMenu→**set_role_dimension（entity::casbin_rule delete_many+insert 於 mutate_in_txn）** → handler `load_policy()` reload → getRoleMenu 回新集 → `menu_routes_for_roles`/getUserRoutes 該角色反映 → **★ F1 原子審計**：psql 驗 sys_operation_log 恰一筆 `entity_table='casbin_rule'`（與寫同 txn）→ **②protected-reject**：移除受保護 v2='menu'→`menuProtected` 2222、零變更 → **restore 原集** → psql 驗 casbin_rule 回原狀（無殘留）。
5. **role home live**（C-V-6）：updateRoleHome（entity 寫、原子 op-log）→getRoleHome/home_of_roles 反映。
6. **越權 live**（C-V-7）：Admin getRoleList→200（seed）；Admin/User 對 role 寫端（含 **batchDeleteRole**）/getRoleMenu→403/5003。
7. **base-web**（C-V-8/9）：`pnpm typecheck` 綠；CDP 經 :31080——role 頁 CRUD 真發 request、menu-auth-modal 指派→真發 updateRoleMenu→**換角色登入側欄反映**、setRoleHome→**換角色登入落地路由＝新首頁（★ F2 redirect）**、移除受保護→`menuProtected` toast、hasAuth gating。**★★ CDP/live 改了 casbin policy/建了角色 → 測後 cleanup**（restore policy、hard-delete 測試角色、psql 驗回原狀）。
8. **零回歸＋prod build**（C-V-10/11）：diff 零 migration/entity；enforce_mw/require_policy/menu_routes_for_roles/load_policy/From<DbErr>/base-web frozen 未改；getUserRoutes/getUserInfo/menu/user 不變；`/health` ok；prod target image build。

## 出口
C-V-0~11 全綠＝acceptance 通過（SC-001~010）。**關鍵亮點**：updateRoleMenu（DB-first 寫+reload）↔getUserRoutes(010) 讀寫閉環（§I.2 選單可見性的寫端兌現）＋**原子審計**（DB-first 之果）。**關鍵紀律**：casbin 寫 DB-first（entity::casbin_rule 直寫、絕不 MgmtApi）；測試必顯式 cleanup、psql 驗無殘留（勿污染 seed）。

## 已知 follow-up（波3、不阻塞）
- archive（revoke→sys_casbin_policy_archive；本刀 revoke=hard DELETE）／restore（←archive）／protected 策略**管理**（un-protect/re-protect；本刀僅 ②enforce 移除-拒）／③PolicyMutated-gate 優化／跨實例 `casbin:policy:invalidate` publish-watcher（本刀單實例本地 load_policy）／回收桶 UI／button-auth（+button-auth-modal）／endpoint-auth／role 角色繼承／role restore（無、軟刪單向）／role status 作存取閘（metadata）。
