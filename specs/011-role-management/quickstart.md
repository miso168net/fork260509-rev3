# Quickstart: 011-role-management 驗證指南

> 角色 CRUD＋角色×選單授權（casbin policy WRITE）＋角色首頁。驗收命令全集＝[contracts/verification-commands.md](contracts/verification-commands.md)（C-V-0~11）；設計＝[data-model.md](data-model.md)／[plan.md](plan.md)；不變式＝[contracts/role-management-contract.md](contracts/role-management-contract.md)。**零 migration／無新 crate。**

## 前置
- dev stack healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（5 service healthy、migrate exited）。
- 帳號（m002）：`Super`/`Admin`/`User`、密碼 `123456`。
- **零 migration 親驗**：psql 確認 sys_role 3 角色（R_SUPER/R_ADMIN/R_USER_COMMON、home='home'）、sys_user_role 指派（3 角色皆 in-use）、9 role 端點 casbin policy、`role:*` button code 皆已 seed（research R6）。
- rust 驗證一律容器內（`docker exec`）；改 `.rs` 先 force-touch；live `--test-threads=1`＋`DATABASE_URL`。

## 核心驗證流程（end-to-end）

1. **build＋lint＋純測**（C-V-0/1/2）：容器內 `cargo build -p server --locked`；`role_delete_guard`/`role_active_model` 純測；`endpoint_coverage_lint`（[31]）＋`entity_access_lint` 綠。
2. **role CRUD live**（C-V-3）：role_crud round-trip（add/update/soft_delete、外層 txn rollback）＋roleCode dup→`biz.role.duplicateRoleCode` 2222（非 5000）。
3. **delete guards live**（C-V-4）：seeded/in-use/self 三守門→2222；批次整批拒 DB 無變。
4. **★ Role×Menu 讀寫閉環 live**（C-V-5、**casbin 寫非 txn 隔離→必 snapshot+restore**）：snapshot 角色原 v2='menu' → updateRoleMenu（remove_filtered+add_policies、auto-persist）→ getRoleMenu 回新集（route_name→menu id）→ `menu_routes_for_roles`/getUserRoutes 該角色反映 → **restore 原集** → psql 驗 casbin_rule 回原狀（無殘留）。
5. **role home live**（C-V-6）：updateRoleHome（entity 寫、原子 op-log）→getRoleHome/home_of_roles 反映。
6. **越權 live**（C-V-7）：Admin getRoleList→200（seed）；Admin/User 對 role 寫端/getRoleMenu→403/5003。
7. **base-web**（C-V-8/9）：`pnpm typecheck` 綠；CDP 經 :31080——role 頁 CRUD 真發 request、menu-auth-modal 指派→真發 updateRoleMenu→**換角色登入側欄反映**、setRoleHome 真發、hasAuth gating（非 super 無 role 寫鈕）。**★★ CDP/live 改了 casbin policy/建了角色 → 測後 cleanup**（restore policy、hard-delete 測試角色、psql 驗回原狀）。
8. **零回歸＋prod build**（C-V-10/11）：diff 零 migration/entity；enforce_mw/require_policy/menu_routes_for_roles/From<DbErr>/base-web frozen 未改；getUserRoutes/getUserInfo/menu/user 不變；`/health` ok；prod target image build。

## 出口
C-V-0~11 全綠＝acceptance 通過（SC-001~010）。**關鍵亮點**：updateRoleMenu↔getUserRoutes(010) 讀寫閉環（§I.2 選單可見性的寫端兌現）。**關鍵紀律**：casbin policy 寫非 txn 隔離→測試必顯式 cleanup、psql 驗無殘留（勿污染 seed）。

## 已知 follow-up（波3、不阻塞）
- updateRoleMenu op-log 非原子（best-effort、波3 policy-governance archive 收）；protected 不強制（波3）；button-auth/endpoint-auth（波3 Button/Endpoint policy 縱切、復用 set_role_*_policies pattern）；casbin_rule 治理欄 adapter 不設（波3）；role 無 restore（軟刪單向、by-design）；role status＝metadata（非存取閘、加固另案）。
