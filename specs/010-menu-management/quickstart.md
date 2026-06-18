# Quickstart: 010-menu-management 驗證指南

> 從零驗證本刀（動態角色選單＋選單 CRUD＋統一回收桶＋越權防護＝波2 第二刀）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型/接線＝[data-model.md](data-model.md)；不變式＝[contracts/menu-management-contract.md](contracts/menu-management-contract.md)；ground-truth＝[research.md](research.md)。

## 前置
- dev stack 全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 m001 schema＋m002 seed〔`Super`/`Admin`/`User`/`123456`＋10 baseline menu＋menu-visibility policy＋13 menu endpoint policy＋button code menu:*/user:*/role:*〕＋m004 66 demo menu）。
- **無 migration**（表＋seed＋policy＋button code 已備、research R1）。
- rust 一律容器內跑；改 `.rs` 先 force-touch；rust serial；live `--test-threads=1`＋`DATABASE_URL`。
- base-web commit `--no-verify`（§8.2.1）。
- **★ `.env VITE_AUTH_ROUTE_MODE` 由 static→dynamic 為 base-web 單元【最後一步】**（getUserRoutes 後端先驗綠）。

## 驗證流程（13 步、對應 C-V-0~12）
1. **build 綠**（C-V-0）：force-touch → `cargo build -p server --locked`（enforce/facade/handler route+menu/序列化/main/lint、無新 dep）。
2. **純測**（C-V-1）：`cargo test -p server --bin server menu_tree / reparent / delete_guard / wire`（flat→tree／reparent 4 guard／delete guard／id 兩域 2^53）。
3. **active_model 純測**（C-V-2）：`cargo test -p server --bin server active_model`（成對審計欄、update 不動 created_*）。
4. **三守恆 lint**（C-V-3、★bump [11→22]）：`cargo test -p server --test endpoint_coverage_lint`（registered==as-built、policy-governed⊆seed、/route/* 三分類）＋`--test entity_access_lint`。
5. **live getUserRoutes 三角色**（C-V-4、★§I.2 首兌現）：`cargo test -p server -- --ignored --test-threads=1 get_user_routes`（R_SUPER 含 manage_menu／R_ADMIN 不含但含 manage_user/role／R_USER_COMMON 僅 home/function；home='home'）。
6. **live menu CRUD round-trip**（C-V-5）：`… menu_crud`（add 唯一+INSERT op-log INET→update/reparent UPDATE→soft_delete→restore；dup route_name→2222 非 5000）。
7. **live reparent/delete guard**（C-V-6）：`… menu_guard`（reparent 4 情境 2222／delete protected·has-children 2222／批次含父子整批拒）。
8. **live 回收桶統一+restore 孤兒**（C-V-7）：`… menu_recycle`（getMenuList/v2 含 deleted flag／getUserRoutes 不含已刪／restore 孤兒→頂層 RESTORE op-log）。
9. **live policy-gate**（C-V-8）：Admin/User /systemManage/*Menu*→403；/route/getUserRoutes auth-only→200；getConstantRoutes public→200 無 token。
10. **base-web typecheck**（C-V-9）：`pnpm typecheck`（rev3 menu wrapper＋deleted flag/MenuUpsertModel ADAPT 對齊；wire id 兩域零型謊）。
11. **CDP 經 front-nginx**（C-V-10、★.env dynamic 後 modal 真發 request）：三角色側欄差異（非 super 不見 admin 選單＝D1）＋login 可達（builtin）→Super→/manage/menu→統一清單（已刪除欄）→新增/改/reparent/刪/restore/批刪 真發 request＋toast 在地化＋非 super 無 menu/user 寫入鈕（hasAuth）；getUserRoutes 失敗→導回登入。
12. **prod image build**（C-V-12、無新 crate）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`。
13. **零回歸**（C-V-11）：`/health` ok；diff 零 migration/entity/schema；blanket From 未改；base-web route store/transform/system-manage.ts/.d.ts/auth.ts 未改；.env flip 後 user/settings 頁本身不回歸。

## 預期結果（對應 SC）
| 步 | 對應 SC | 通過 |
|---|---|---|
| 2-3 | SC-003/004/010 | 純測綠（tree/reparent/delete/wire/active_model）＋三守恆 |
| 5 | SC-001 | getUserRoutes 三角色過濾差異正確 |
| 6 | SC-002/006 | menu CRUD round-trip＋dup→2222 |
| 7 | SC-003/005 | reparent 4 guard＋delete guard＋批次整批拒 |
| 8 | SC-007 | 回收桶統一清單 deleted flag＋restore 孤兒→頂層 |
| 9 | SC-008 | menu 端點 R_SUPER／getUserRoutes auth-only |
| 10 | SC-011 | wire id 兩域零型謊 |
| 11 | SC-001/002/004/007/008 | CDP 真發 request＋三角色側欄＋已刪除列＋restore＋在地化＋hasAuth |
| 12-13 | （建置/SC-011） | prod build＋零回歸/零 schema |

## 不在本刀（各歸其刀）
- Role 刀：getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋menu-auth-modal（指派角色看哪些選單；消費本刀 getMenuTree/getAllPages）＋完整 Role CRUD。
- getDeletedMenus 端點（統一清單取代）／iframe 內嵌復原（沿 href 外開）／filter_routes 遞迴化（backlog）。
- system-settings button gating（research R11 moot skip、無 button code＋super-only）。
- R_ADMIN user:edit button vs user-write endpoint super-only seed 不對齊（research R11 nuance、登 follow-up）。
- 波3：policy governance／casbin_rule 治理欄／即時 token 撤銷。
