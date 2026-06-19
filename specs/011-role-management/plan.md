# Implementation Plan: 011-role-management（角色 CRUD＋角色×選單授權＋角色首頁＝波2 第三刀）

**Branch**: `011-role-management` | **Date**: 2026-06-19 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/011-role-management.md`（波2 第三刀；plan-phase act-on-code research 親驗校正見下）

## Summary

把 `/manage/role` 從 mock 接到真 rust-api：**角色 CRUD**（getRoleList 分頁/filter／addRole／updateRole／deleteRole／batchDeleteRole）＋**角色×選單授權**（getRoleMenu／updateRoleMenu，**全專案首次 casbin policy WRITE**，與 010 getUserRoutes 的 v2='menu' 讀端形成讀/寫閉環）＋**角色首頁**（getRoleHome／updateRoleHome、sys_role.home entity 寫）＋前端 hasAuth gating（`role:*`）。**9 端點**（getRoleList〔R_SUPER+R_ADMIN〕／addRole·updateRole·deleteRole·batchDeleteRole·getRoleHome·updateRoleHome〔R_SUPER〕／getRoleMenu·updateRoleMenu〔R_SUPER protected〕）。沿 008/009/010 `require_policy`／`mutate_in_txn` op-log／envelope／`sql_err`→2222／`endpoint_coverage_lint`／`soft_delete`。**零 migration／零 schema／零 entity 改／無新 crate**（sys_role/sys_user_role/casbin_rule＋3 角色＋9 端點 policy＋`role:*` button code 皆 m001/m002 已備）。button-auth/endpoint-auth 留波3。

**plan-phase research 親驗校正/確認**（act-on-code、見 [research.md](research.md)）：
1. **casbin WRITE API 釘死**（R1）：casbin **2.20.0** MgmtApi（`&mut Enforcer` via `.write().await`）`add_policies("","p",rules:Vec<Vec<String>>)`／`remove_filtered_policy("","p",0,vec![role,"","menu"])` 皆 async＋**auto-persist**（vendored sea-orm-adapter 直接 insert/delete＋更新 in-memory model、**無需 save_policy**）；無 `From<casbin::Error>`→handler 映 `AppError::Internal`。
2. **★ 非原子確認**（R2）：adapter 持**自有** DatabaseConnection（≠ AppState.db）→ casbin policy 寫**無法與 op-log `mutate_in_txn` 同交易**→ Role×Menu 審計 best-effort（FR-008、D2、非缺陷、不可避、波3 治理補）。
3. **sys_role facade 鏡像 009**（R3）：現有 `find_active`／`home_of_roles`；補 list（§5.8 filter＋PageRes）／create／update／soft_delete／batch／find_active_by_id／build_*_active_model（鏡像 sys_user）。`map_write_err`（sql_err→UniqueConstraintViolation→Biz）沿用、roleCode 23505→`biz.role.duplicateRoleCode`。
4. **wire 3 端釘死**（R4、⚠️r）：menu-auth-modal `checks:number[]`／`roleId:number`（prop）；`MenuTree{id:number,label,pId,children}`；rev3 wrapper 慣例＝單 body `id`→`String(id)`、array `ids`→`ids.map(String)`，但 **roleId 為獨立參數（非 body `id`）→ 維持 number、menuIds 維持 number[]**（非對稱、刻意）。
5. **2 net-new facade helper**（R5）：`sys_user_role::count_users_by_role_id(role_id)->i64`（in-use guard、現無）＋ id↔code/route_name 映射（self-role guard：deleteRole 收 id、`roles_of_user` 回 code → 需 find_active_by_id(role).code 比對 operator codes；getRoleMenu：role code→`menu_routes_for_roles([code])`→route_names→sys_menu route_name↔id 映射）。
6. **m002 9 端點 verbatim 確認**（R6）：path/method 逐字（getRoleList R_SUPER+R_ADMIN／其餘 R_SUPER／getRoleMenu·updateRoleMenu protected=true、getRoleHome·updateRoleHome protected=false）。`endpoint_coverage_lint` AS_BUILT `[&str;22]`→`[&str;31]`。
7. **2 deferred 項確認**（R7）：sys_role `find_active` 僅濾 deleted_at（**status＝metadata、非存取閘**）；rust/base-web **無 role restore**（角色頁無回收桶、軟刪單向）——皆 by-design、非缺口。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-api、`rust-toolchain.toml` pin）＋TypeScript/Vue 3（base-web、soybean-admin fork）

**Primary Dependencies**: server **無新增 dep／無新 crate**（既有 sea-orm 1.1.20／axum 0.7／**casbin 2.20.0**＋vendored sea-orm-adapter）。Role×Menu policy 寫用 casbin **既有** MgmtApi（`add_policies`/`remove_filtered_policy`、auto-persist）；sys_role CRUD 用既有 sea-orm。base-web 零新 npm dep。

**Storage**: PostgreSQL（既有 dev stack、m001 schema）。**本刀無 migration**——`sys_role`(12 欄、archetype A 軟刪+審計、無 protected 欄)／`sys_user_role`(複合 PK)／`casbin_rule`(8 基底+3 治理欄)＋3 角色+sys_user_role+9 端點 policy+`role:*` button code 皆 m001/m002 已 seed（research R1/R6）。

**Testing**: rust in-crate `#[cfg(test)]` 純測（delete guard 三情境〔seeded/in-use/self〕／id↔route_name 映射／build_*_active_model）＋live `#[ignore]` smoke（role CRUD round-trip／roleCode 23505→2222／delete guards＋batch 整批拒／**updateRoleMenu→getUserRoutes 讀寫閉環**／updateRoleHome→home_of_roles 反映）＋`endpoint_coverage_lint`(bump 31)＋`entity_access_lint`。**live 一律 `--test-threads=1` serial＋DATABASE_URL**。base-web `pnpm typecheck`＋CDP（role 頁 CRUD 真發、menu-auth-modal 指派真發 updateRoleMenu→換角色登入側欄變、hasAuth gating）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內 `docker exec`）。

**Project Type**: web（rust-api backend＋base-web frontend）——rust：L4 facade（sys_role CRUD＋`sys_user_role::count_users_by_role_id`）＋L4 casbin policy WRITE（`set_role_menu_policies`、MgmtApi、auth 層）＋L5 handler（system_manage.rs +9 端點＋RoleUpsertReq/RoleMenuReq/RoleHomeReq DTO＋id↔code/route_name 映射＋delete guards）＋L4 main（9 路由 require_policy）＋L8 endpoint_coverage_lint bump；base-web L3 wrapper（rev3-system-manage role 8 fn）＋L1/L2 typings（RoleUpsertModel ADAPT）＋L4 view（MODAL-WIRING (a) role CRUD+menu-auth-modal 接線／(b) hasAuth gating role:*）＋app.d.ts Schema＋locale（backend.biz.role.*）。**★ 無 .env flip**（010 已 dynamic）。

**Performance Goals**: getRoleList 分頁讀（非熱路徑、⚠️a p95<300ms）；role 寫單列＋同 txn 審計（⚠️a <500ms）；updateRoleMenu＝remove_filtered+add_policies（小選單集、casbin in-memory+adapter 寫、⚠️a 預算內）。

**Constraints**: `enforce_mw`/`require_policy`/`menu_routes_for_roles`/`buttons_for_roles`/`From<DbErr>` 本體不改（§3.4／⚠️o）；授權 subject＝DB-fresh roles（§I.3）；**零 migration/schema/entity 變更**；無新 crate；**base-web 既有檔不改**（route store/transform/system-manage.ts/auth.ts/request；只新增 rev3-* wrapper＋typings ADAPT＋MODAL-WIRING (a)(b) inline＋locale）；**★ casbin policy 寫經 MgmtApi、與 op-log 非同交易**（D2、FR-008 best-effort、不強制 protected＝波3）；**★ 無 .env flip**；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: 3+ 角色；9 rust 端點＋base-web role 頁接線＋menu-auth-modal 指派。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威？rust-api 缺對應 endpoint？ | **PASS**——base-web 有 role 頁＋role-operate-drawer＋menu-auth-modal（mock）＋role service fn（getRoleList/getAllRoles 既實作後端）；本刀 rust-api 補齊 9 對應 endpoint；m002 policy 已就位、兩端俱在 |
| 2 | 動 base-web inline？屬 MODAL-WIRING ★ 哪用途？依 fork-delta 紀律？ | **PASS**——MODAL-WIRING **(a)** 接線（role/index.vue CRUD＋role-operate-drawer submit＋menu-auth-modal getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome）＋**(b)** hasAuth gating（role 頁 `role:*`、§III.2 既授）＋WRAPPER（rev3-system-manage.ts role fn）＋ADAPT（RoleUpsertModel typings）＋I18N-WIRING（backend.biz.role.*）皆**既授**；**★ route store/transform/system-manage.ts/auth.ts 不動**（button-auth-modal 留 mock）→ 無「named track 外的既有檔編輯」、無 amendment |
| 3 | menu 顯示走 Casbin enforce？demo ⚠️p？ | **PASS**——Role×Menu 寫 v2='menu' policy＝010 getUserRoutes（`menu_routes_for_roles` 讀端）的**寫端對手**（讀/寫閉環）；§I.2 menu-Casbin-enforce 的指派來源即本刀；demo ⚠️p（可見性全由 v2='menu' policy 治理）honored |
| 4 | wire 對齊 §I.3 typings 權威？ | **PASS**——`Role.id`＝number（CommonRecord、⚠️r 同 User.id）；getRoleMenu→`number[]`（menu ids）；`roleId`＝number（獨立參數、非 body id→不轉 String、R4）；menuIds＝number[]；id↔route_name 映射（handler/facade）消型謊 |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——借 rev2 016/018/021 設計、code 全新寫（§I.5／⚠️g）；casbin policy 寫用標準 MgmtApi（非拷 rev2）；不帶回 id-string 漂移（⚠️r） |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——無拍板需改；⚠️r id 忠實；#7 dynamic（010 已兌現、本刀不碰 .env） |
| 7 | 觸 §III ★ 軌道？授權邊界內？ | **PASS**——MODAL-WIRING (a)(b)＋WRAPPER＋ADAPT＋I18N-WIRING 皆**本檔已授**、在邊界內；route store/transform/system-manage.ts/auth.ts 不動（button-auth-modal 留 mock）→ 不觸 named track 外 |
| 8 | 新建業務表（migration）？§I.6 六審計欄？ | **PASS（未觸）**——**零 migration**；`sys_role`（archetype A 軟刪+審計、m001）＋seed 皆已建。寫端 create/update/soft_delete 成對寫審計欄（§I.6）；**無 retrofit**。★ casbin policy 寫經 adapter（治理欄 protected/created_at/created_by default、波3 治理補；非 §I.6 業務 entity 審計欄範疇） |
| 9 | 觸 §I.7 行為島（token/policy/single-session）？ | **PASS（with note）**——Role×Menu 寫＝對 **policy 行為島的持久層**做 grant/revoke（v2='menu' policy rows）；但**只 data-island 指派、不建/不碰治理三態機**（archive／protected 強制／PolicyMutated／restore）——治理行為島於**波3**用 §4 state-machine 鏡頭第一輪設計（D2 拍板：本刀治理姿態最小、治理留波3）。本刀不違「行為島先設計狀態機」精神（未建治理機、僅指派；治理機波3）；casbin write 非原子 op-log（R2、FR-008 best-effort、文件化） |

**Gate 結論：9/9 PASS；無 Amendment；零 migration；無新 crate；Q9 policy-island sequencing 已 note（治理留波3、D2）；Complexity Tracking 不適用。**

> **無新 crate ⇒ prod build 輕**：9 端點皆 server 內 facade/handler/auth/模組（casbin 既有 dep、無 workspace crate 新增）→ 不觸 §3「新 crate ⇒ Dockerfile COPY」紀律；C-V 仍跑 prod target build 確認新碼編入。

## Project Structure

### Documentation (this feature)
```text
specs/011-role-management/
├── spec.md              # /speckit-specify ✅（7 US／10 FR／10 SC＋Clarifications 3 拍板）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 casbin write API・R2 非原子・R3 sys_role facade・R4 wire 3 端・R5 net-new helper・R6 m002 verbatim・R7 deferred 項）
├── data-model.md        # Phase 1 ✅（sys_role facade＋set_role_menu_policies＋9 handler＋DTO/wire 3 端＋delete guards＋id↔route_name）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md      # C-V-0~N
│   └── role-management-contract.md    # 跨 feature 不變式（Role×Menu policy write／delete guards／wire id／治理姿態）
└── checklists/requirements.md        # 17/17 ✅
```

### Source Code (repository root)
```text
rust-api/server/src/
├── model/facade/sys_role.rs        # 改：+list(§5.8 filter+PageRes)/find_active_by_id/create/update(含 home)/soft_delete(delete guards)/batch/build_*_active_model（find_active/home_of_roles 既存）
├── model/facade/sys_user_role.rs   # 改：+count_users_by_role_id(role_id)->i64（in-use guard、net-new）
├── auth/enforce.rs（或新 auth/policy.rs）  # 改/新：+set_role_menu_policies(enforcer,&mut,role_code,&[route_name])（MgmtApi remove_filtered+add_policies、auto-persist；enforce_mw/require_policy/menu_routes_for_roles 本體不動）
├── handler/system_manage.rs        # 改：+get_role_list/add_role/update_role/delete_role/batch_delete_role/get_role_menu/update_role_menu/get_role_home/update_role_home＋RoleUpsertReq/RoleMenuReq/RoleHomeReq DTO＋id↔code/route_name 映射＋delete guards＋role biz err map
├── main.rs                         # 改：9 路由 route_layer(require_policy)＋入 roles 子 router（enforce.rs/require_policy 不改）
└── (error.rs 不改 blanket)         # role biz 2222 於 handler match；casbin::Error→AppError::Internal（手動映射）
rust-api/server/tests/endpoint_coverage_lint.rs  # 改：AS_BUILT_ROUTES [&str;22]→[&str;31]（+9）
base-web/src/
├── service/api/rev3-system-manage.ts      # 改（WRAPPER）：+fetchAddRole/fetchUpdateRole/fetchDeleteRole/fetchBatchDeleteRole/fetchGetRoleMenu/fetchUpdateRoleMenu/fetchGetRoleHome/fetchUpdateRoleHome
├── typings/api/rev3-system-manage.d.ts    # 改（ADAPT）：+RoleUpsertModel（declaration-merge、不改既有 Role）
├── views/manage/role/index.vue            # 改（MODAL-WIRING (a)(b)）：handleDelete/handleBatchDelete→真 fn＋hasAuth(role:*) gating
├── views/manage/role/modules/role-operate-drawer.vue  # 改（MW (a)）：handleSubmit→addRole/updateRole
├── views/manage/role/modules/menu-auth-modal.vue      # 改（MW (a)）：getChecks→getRoleMenu／handleSubmit→updateRoleMenu／getHome→getRoleHome／updateHome→updateRoleHome
├── typings/app.d.ts                        # 改（I18N-WIRING）：App.I18n.Schema.backend.biz 加 role:{...}（先 Schema 後 locale）
└── locales/langs/{zh-cn,en-us}.ts          # 改（I18N-WIRING）：backend.biz.role.{duplicateRoleCode,notFound,seededProtected,inUse,cannotDeleteSelfRole}
# ALREADY（不動）：entity/src/{sys_role,sys_user_role,casbin_rule}.rs／migration（schema+3 role+9 端點 policy+role:* button code）／enforce_mw+require_policy+menu_routes_for_roles+buttons_for_roles+roles_of_user／mutate_in_txn+SoftDeletable+to_audit_operator／blanket From<DbErr>+envelope+sql_err map／casbin Enforcer init+load_policy／base-web route store+transform+system-manage.ts〔getRoleList/getAllRoles/getMenuTree/getAllPages〕+auth.ts+request+role-search+button-auth-modal〔留 mock〕+menu-auth-modal getTree+Role/RoleList typings+hasAuth hook／010 getMenuTree/getAllPages/getUserRoutes
```

**Structure Decision**：web（rust-api backend＋base-web frontend）。rust：facade（sys_role CRUD＋sys_user_role count helper）＋auth（set_role_menu_policies casbin WRITE）＋handler（9 端點＋id↔code/route_name 映射＋delete guards）＋main 註冊＋lint bump。base-web：WRAPPER＋ADAPT＋MODAL-WIRING (a)(b)＋locale（既有檔不改、route store/transform/system-manage.ts 不動、無 .env flip）。**無 migration/entity/新 crate**（地基 001-010 已 provisioned）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks；~3 Workflow 單元 §12 brainstorm）

1. **★ 順序（rust serial、容器內、改 .rs 先 force-touch）**：U1 Role CRUD（sys_role list/create/update/soft_delete〔delete guards：seeded hardcode＋count_users_by_role_id in-use＋self-role id↔code〕/batch＋handler 5 端點＋main＋lint〔部分〕＋純測 delete guard＋live CRUD/23505/guards）→ U2 Role×Menu+home（**set_role_menu_policies casbin WRITE**＋id↔route_name 映射＋handler getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋main＋lint〔補齊 31〕＋live **讀寫閉環** updateRoleMenu→getUserRoutes／updateRoleHome→home_of_roles／policy-gate）→ U3 base-web（rev3 wrapper 8 fn＋RoleUpsertModel＋MODAL-WIRING (a)(b)＋i18n＋typecheck＋CDP）。
2. **★ 零 migration（R1/R6）**：sys_role/sys_user_role/casbin_rule＋3 角色＋9 端點 policy＋`role:*` button code 皆已 seed；`require_policy` 直接對既存 policy 強制。
3. **★ casbin policy WRITE（R1、首次）**：`set_role_menu_policies`＝`enforcer.write().await` → `remove_filtered_policy("","p",0,vec![role_code,"".into(),"menu".into()])`（移除該 role 全部 v2='menu'）→ `add_policies("","p",new_rules)`（new_rules＝[[role_code,route_name,"menu"]...]）；auto-persist、無 save_policy；`casbin::Error`→`AppError::Internal`（手動）。
4. **★ 非原子（R2、D2）**：casbin 寫＋op-log 非同 txn → updateRoleMenu op-log best-effort（寫 policy 成功後記 op-log；entity_table='sys_role'、entity_id=roleId、operation=UPDATE、before/after=route_name 集）；文件化、波3 治理補。protected 不強制（波3）。
5. **★ delete guards（R5、D3）**：deleteRole/batchDeleteRole 前置：① role.code ∈ {R_SUPER,R_ADMIN,R_USER_COMMON}（hardcode）→`biz.role.seededProtected`；② `count_users_by_role_id(id)>0`→`biz.role.inUse`；③ id↔code：`roles_of_user(claims.uid)` 取 operator codes、to-delete role find_active_by_id→code、相符→`biz.role.cannotDeleteSelfRole`。batch 逐項全檢查、整批拒 no-partial（沿 010）。
6. **★ id↔route_name 映射（R5）**：getRoleMenu：find_active_by_id(roleId)→code→`menu_routes_for_roles(&enforcer.read(),[code])`→route_names→經 sys_menu（list_active/list_all 之 route_name↔id）映射成 menu ids `number[]`（orphan route_name skip）。updateRoleMenu：menuIds→sys_menu find by ids→route_names→set_role_menu_policies。建議 sys_menu facade 加 `route_names_by_ids`/`id_by_route_name` helper（或 handler 自 list_active 結果建 map；entity:: 僅 facade）。
7. **★ sys_role CRUD 鏡像 009（R3）**：list §5.8 filter（roleName/roleCode 模糊 LOWER LIKE ESCAPE、status 精確、空字串守門 normalize_str/enum_filter）＋PageRes；create/update mutate_in_txn＋op-log；roleCode 23505→`map_write_err`→`biz.role.duplicateRoleCode`；update 含 home 欄（getRoleHome/updateRoleHome 亦寫 home）。
8. **wire（R4、⚠️r）**：Role.id number；getRoleMenu→number[]；roleId number（獨立參數、不轉 String）；menuIds number[]；RoleUpsertModel id?:number（updateRole body id→String(id) 沿 wrapper 慣例）；RoleMenuReq/RoleHomeReq roleId 收 number（rust i64）。
9. **lint（R6）**：endpoint_coverage_lint AS_BUILT [22→31]；9 端點皆 require_policy（policy-routes）→Assertion A m002 已 seed 自動過；getRoleList R_SUPER+R_ADMIN。entity_access_lint：handler 零 path-root entity::（set_role_menu_policies 用 enforcer 非 entity::；id↔route_name 映射經 facade 或 Model 欄存取）。
10. **base-web（D1/D10）**：rev3 wrapper 8 fn（單 id→String、roleId/menuIds 維持 number）；MODAL-WIRING (a) role/index.vue+role-operate-drawer+menu-auth-modal（去 console.log stub、原行註解保留）；(b) hasAuth(role:add/edit/delete)；i18n 先 Schema 後 locale；**button-auth-modal 留 mock**；無 .env flip；frozen 既有檔不動。
11. **base-web commit `--no-verify`**（§8.2.1）；rust serial／容器內／改 .rs 先 force-touch／live `--test-threads=1`＋DATABASE_URL；**逐單元兩段式 commit（worktree→pin、S9）**；全程不 push/merge（§I.4）；CDP 不 defer（role CRUD＋menu-auth-modal 真發＋換角色側欄變、必 browser 軌）。
12. **零回歸（FR-010/SC-010）**：enforce_mw/require_policy/menu_routes_for_roles/buttons_for_roles/From<DbErr>/audit_mw/login/getUserInfo/getUserRoutes/health/008/009/010 不變；零 migration/entity/schema；base-web 既有檔（route store/transform/system-manage.ts/.d.ts/auth.ts）不改（diff 核）。
