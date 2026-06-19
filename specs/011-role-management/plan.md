# Implementation Plan: 011-role-management（角色 CRUD＋角色×選單授權＋角色首頁＝波2 第三刀）

**Branch**: `011-role-management` | **Date**: 2026-06-19 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/011-role-management.md`（plan-phase act-on-code research 見下）

> **★ B1 校正（/speckit-analyze 抓出、user 拍板 option 1）**：Role×Menu 寫由原違規的 MgmtApi auto-persist（非原子、in-memory、rev2-034 anti-pattern）改為 **DB-first**（constitution §I.7 §4.2 ①DB-first/④原子審計/⑤reload）。詳 [research.md](research.md) R1/R2。

## Summary

把 `/manage/role` 接到真 rust-api：**角色 CRUD**（getRoleList 分頁/filter／add/update/delete/batch）＋**角色×選單授權**（getRoleMenu/updateRoleMenu，**全專案首次 casbin policy WRITE、DB-first**，與 010 getUserRoutes v2='menu' 讀端形成讀/寫閉環）＋**角色首頁**（getRoleHome/updateRoleHome、sys_role.home entity 寫）＋前端 hasAuth gating（`role:*`）。**9 端點**（getRoleList〔R_SUPER+R_ADMIN〕／add/update/delete/batch/getRoleHome/updateRoleHome〔R_SUPER〕／getRoleMenu/updateRoleMenu〔R_SUPER protected〕）。**零 migration／零 schema／零 entity 改／無新 crate**（sys_role/sys_user_role/casbin_rule〔11-col〕＋3 角色＋9 端點 policy＋`role:*` button code 皆 m001/m002 已備）。button-auth/endpoint-auth 留波3。

**plan-phase research 親驗（act-on-code、見 [research.md](research.md)）**：
1. **★ casbin WRITE＝DB-first（R1、B1 校正）**：新 facade `sys_casbin_rule::set_role_dimension`——`mutate_in_txn` 內讀 current `entity::casbin_rule`（11-col、見 protected）→diff→**②protected-reject**（to_revoke 有 protected→整批拒）→`delete_many`(revoke)+`insert`(grant、set created_by)+op-log（同 txn **原子**）；handler 在 commit 後 `enforcer.write().await.load_policy()` 全量 reload（⑤、本地）。**無 enforcer MgmtApi 寫**。entity::casbin_rule 11-col 在 facade 可寫（lint 豁免）。
2. **★ 原子審計（R2、校正原 best-effort）**：DB-first 直寫 entity::casbin_rule **於 AppState.db txn**＝與 op-log 同 txn → **原子**（非 MgmtApi/adapter 自有連線的非原子）。FR-008/SC-007 隨之改回原子。
3. **sys_role facade 鏡像 009**（R3）：補 list（§5.8+PageRes）/find_active_by_id/create/update〔含 home〕/soft_delete/batch/build_*_active_model；roleCode 23505→`biz.role.duplicateRoleCode`。
4. **wire 3 端**（R4、⚠️r）：Role.id number；getRoleMenu→number[]；roleId/menuIds **number 不轉 String**（獨立參數、非 body id）。
5. **net-new facade**（R5）：`sys_casbin_rule`（set_role_dimension DB-first＋SetDimensionError{Db,Rejected}＋讀端復用 menu_routes_for_roles）／`sys_user_role::count_users_by_role_id`（in-use guard）／id↔code·route_name 映射（self-role guard＋getRoleMenu）。
6. **m002 9 端點 verbatim**（R6）：getRoleList R_SUPER+R_ADMIN／其餘 R_SUPER／getRoleMenu·updateRoleMenu protected=true。lint AS_BUILT `[22→31]`。
7. **2 deferred 確認**（R7）：status＝metadata（非存取閘）；無 role restore；②protected-reject 在 波2；archive/restore/PolicyMutated-優化/publish-watcher＝波3。

## Technical Context

**Language/Version**: Rust 1.86.0＋TypeScript/Vue 3。
**Primary Dependencies**: server **無新增 dep／無新 crate**（既有 sea-orm 1.1.20／axum 0.7／casbin 2.20.0＋vendored sea-orm-adapter）。Role×Menu DB-first 寫用 **既有 `entity::casbin_rule`（11-col）+ sea-orm** + 既有 `enforcer.load_policy()` reload（**不**用 casbin MgmtApi 寫端）。base-web 零新 npm dep。
**Storage**: PostgreSQL（m001 schema）。**本刀無 migration**——`sys_role`(12 欄、無 protected)／`sys_user_role`(複合 PK)／`casbin_rule`(11 欄：8 基底+protected/created_at/created_by)＋seed 皆已備（research R1/R6）。
**Testing**: rust in-crate 純測（delete guard 三情境／build_*_active_model／id↔route_name）＋live `#[ignore]` smoke（role CRUD／23505→2222／delete guards＋batch 整批拒／**★ Role×Menu DB-first 讀寫閉環**〔set_role_dimension→load_policy→getUserRoutes 反映；②protected-reject〕／updateRoleHome→home_of_roles）＋`endpoint_coverage_lint`(31)＋`entity_access_lint`。**live `--test-threads=1`**；**★ casbin_rule 寫經 mutate_in_txn commit→ live 測 Role×Menu 須 snapshot+restore（讀寫閉環需 committed 寫供 load_policy 見、非可 rollback；psql 驗無殘留）**。base-web `pnpm typecheck`＋CDP。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。
**Target Platform**: 001 dev/prod 容器堆疊。
**Project Type**: web。rust：L4 facade（sys_role CRUD＋sys_user_role count＋**sys_casbin_rule DB-first set_role_dimension**）＋L5 handler（system_manage.rs +9＋id↔code/route_name＋delete guards＋reload after set_role_dimension）＋L4 main（9 路由 require_policy）＋L8 lint bump；base-web L3 wrapper（rev3 role 8 fn）＋L1/L2 typings（RoleUpsertModel）＋L4 view（MODAL-WIRING (a) CRUD+menu-auth-modal／(b) hasAuth role:*）＋Schema＋locale（backend.biz.role.* 6 鍵）。**★ 無 .env flip**（010 已 dynamic）。
**Performance Goals**: getRoleList 分頁讀（⚠️a p95<300ms）；role 寫＋同 txn 審計（<500ms）；set_role_dimension（小選單集 diff+delete/insert+load_policy reload、⚠️a 預算內）。
**Constraints**: `enforce_mw`/`require_policy`/`menu_routes_for_roles`/`buttons_for_roles`/`From<DbErr>` 本體不改；授權 subject＝DB-fresh roles；**零 migration/schema/entity 變更**；無新 crate；**base-web 既有檔不改**（route store/transform/system-manage.ts/auth.ts/request；button-auth-modal 留 mock）；**★ casbin 寫 DB-first（facade 直寫 entity::casbin_rule、原子 op-log、②protected-reject、寫後 load_policy reload；無 MgmtApi 寫）**（constitution §I.7 §4.2）；**★ 無 .env flip**；push/merge 凍結至 finishing（§I.4）。
**Scale/Scope**: 3+ 角色；9 rust 端點＋base-web role 頁接線。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前＋Phase 1 後＋**B1 校正後**複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | §I.1 base-web 權威？rust 缺 endpoint？ | **PASS**——role 頁+menu-auth-modal 既有（mock）；rust 補 9 端點；m002 policy 已 seed |
| 2 | base-web inline MODAL-WIRING？fork-delta？ | **PASS**——MODAL-WIRING (a) CRUD+menu-auth-modal 接線＋(b) hasAuth gating＋WRAPPER＋ADAPT＋I18N 皆既授；route store/transform/system-manage.ts/auth.ts 不動、button-auth-modal 留 mock |
| 3 | menu 走 Casbin enforce？demo ⚠️p？ | **PASS**——Role×Menu 寫 v2='menu' policy＝010 getUserRoutes 讀端寫端對手（讀寫閉環）；§I.2 指派來源 |
| 4 | wire §I.3 typings？ | **PASS**——Role.id number；getRoleMenu number[]；roleId/menuIds number（不轉 String、R4）；id↔route_name 映射消型謊 |
| 5 | rev2 source 拷貝？ | **PASS**——借 rev2 016/018/021 設計、code 全新寫；casbin DB-first set_role_dimension 為 DESIGN §4.2 canonical 形（非拷 rev2 code） |
| 6 | §II 拍板抵觸？ | **PASS**——無；⚠️r id 忠實 |
| 7 | §III ★ 軌道？邊界內？ | **PASS**——MODAL-WIRING (a)(b)＋WRAPPER＋ADAPT＋I18N 既授；frozen 檔不動 |
| 8 | 新建業務表（migration）？§I.6 六審計欄？ | **PASS（未觸）**——**零 migration**；sys_role archetype A 全審計欄已建；寫端成對審計欄。★ casbin_rule 寫經 **DB-first facade**（entity::casbin_rule 11-col、grant 設 created_at/created_by 治理欄、§I.6 精神）；非 adapter auto_save 旁路 |
| 9 | 觸 §I.7 行為島（token/policy/single-session）？ | **PASS（DB-first 合規、B1 校正後）**——Role×Menu 寫＝對 policy 行為島持久層做 set_role_dimension，**滿足 §4.2 凍結 invariant ①DB-first〔facade 直寫 casbin_rule、不碰 in-memory 寫〕②protected-reject〔to_revoke 含 protected→整批拒〕④原子審計〔casbin_rule 寫+op-log 同 mutate_in_txn〕⑤reload〔寫後 load_policy()〕**；**僅治理【功能】**（archive revoke→archive 表／restore／protected 策略管理 un-protect/re-protect／③PolicyMutated-gate 優化／跨實例 publish-watcher／回收桶 UI）**依 DESIGN §8.2 排波3**（行為島治理刀第一輪設計）——此為功能交付排序、非 invariant 反轉。本刀寫端已用 §4 state-machine 鏡頭合規寫（非「又一張 casbin 表」） |

**Gate 結論：9/9 PASS（B1 校正後、DB-first 合規）；無 Amendment；零 migration；無新 crate；Q9 §4.2 寫端 invariant ①②④⑤ 滿足、僅治理功能（archive/restore/un-protect/PolicyMutated 優化/publish-watcher）排波3；Complexity Tracking 不適用。**

> **無新 crate ⇒ prod build 輕**：9 端點皆 server 內 facade/handler/模組（無 workspace crate 新增）；C-V 仍跑 prod target build。

## Project Structure

### Documentation (this feature)
```text
specs/011-role-management/
├── spec.md              # /speckit-specify ✅（7 US／10 FR／10 SC＋Clarifications 3 拍板、B1 校正 DB-first）
├── plan.md              # 本檔（B1 校正 DB-first）
├── research.md          # Phase 0 ✅（R1 DB-first write・R2 原子・R3 sys_role facade・R4 wire・R5 net-new helper・R6 m002・R7 deferred）
├── data-model.md        # Phase 1 ✅（sys_role+sys_user_role+sys_casbin_rule DB-first set_role_dimension＋9 handler＋wire＋delete guards）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md      # C-V-0~11
│   └── role-management-contract.md    # 跨 feature 不變式（DB-first policy write／delete guards／wire／治理機波3）
└── checklists/requirements.md        # 17/17 ✅
```

### Source Code (repository root)
```text
rust-api/server/src/
├── model/facade/sys_role.rs          # 改：+list(§5.8+PageRes)/find_active_by_id/create/update(含 home)/soft_delete/batch/build_*_active_model
├── model/facade/sys_user_role.rs     # 改：+count_users_by_role_id(role_id)（in-use guard、net-new）
├── model/facade/sys_casbin_rule.rs   # ★ 新：set_role_dimension（DB-first：read current entity::casbin_rule→diff→②protected-reject→delete_many+insert+op-log 於 mutate_in_txn 原子）＋SetDimensionError{Db,Rejected}/SetDimensionOutcome{changed}
├── handler/system_manage.rs          # 改：+role 9 端點＋RoleUpsertReq/RoleMenuReq/RoleHomeReq DTO＋id↔code/route_name＋delete guards＋set_role_dimension 後 load_policy reload＋biz err map（含 menuProtected）
├── main.rs                           # 改：9 路由 route_layer(require_policy)＋入 roles 子 router（enforce.rs/require_policy 不改）
└── (error.rs 不改 blanket)           # role biz 2222 於 handler match；casbin/reload 失敗→AppError::Internal
rust-api/server/tests/endpoint_coverage_lint.rs  # 改：AS_BUILT_ROUTES [&str;22]→[&str;31]（+9）
base-web/src/
├── service/api/rev3-system-manage.ts      # 改（WRAPPER）：+fetchAddRole/UpdateRole/DeleteRole/BatchDeleteRole/GetRoleMenu/UpdateRoleMenu/GetRoleHome/UpdateRoleHome
├── typings/api/rev3-system-manage.d.ts    # 改（ADAPT）：+RoleUpsertModel
├── views/manage/role/index.vue            # 改（MODAL-WIRING (a)(b)）：handleDelete/handleBatchDelete→真 fn＋hasAuth(role:*) gating
├── views/manage/role/modules/role-operate-drawer.vue  # 改（MW (a)）：handleSubmit→addRole/updateRole
├── views/manage/role/modules/menu-auth-modal.vue      # 改（MW (a)）：getChecks→getRoleMenu／handleSubmit→updateRoleMenu〔menuProtected 2222 toast〕／getHome→getRoleHome／updateHome→updateRoleHome
├── typings/app.d.ts                        # 改（I18N-WIRING）：Schema backend.biz 加 role:{...6 鍵}（先 Schema 後 locale）
└── locales/langs/{zh-cn,en-us}.ts          # 改：backend.biz.role.{duplicateRoleCode,notFound,seededProtected,inUse,cannotDeleteSelfRole,menuProtected}
# ALREADY（不動）：entity/src/{sys_role,sys_user_role,casbin_rule〔11-col〕,sys_casbin_policy_archive〔波3〕}.rs／migration／enforce_mw+require_policy+menu_routes_for_roles+buttons_for_roles+roles_of_user／mutate_in_txn〔任意 entity_table〕+SoftDeletable+to_audit_operator／blanket From+envelope+sql_err map／casbin Enforcer init+load_policy／base-web route store+transform+system-manage.ts〔getRoleList/getAllRoles/getMenuTree/getAllPages〕+auth.ts+request+role-search+button-auth-modal〔mock〕+menu-auth-modal getTree+Role/RoleList typings+hasAuth／010 getMenuTree/getAllPages/getUserRoutes
```

**Structure Decision**：web。rust：facade（sys_role CRUD＋count helper＋**sys_casbin_rule DB-first**）＋handler（9 端點＋reload）＋main＋lint bump。base-web：WRAPPER＋ADAPT＋MODAL-WIRING (a)(b)＋locale（既有檔不改、無 .env flip）。**無 migration/entity/新 crate**。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS、B1 校正後 DB-first 合規）→ 不適用。

## 實作注意（移交 tasks；~3 Workflow 單元 §12）

1. **★ 順序（rust serial、容器內、改 .rs 先 force-touch）**：U1 Role CRUD（sys_role list/create/update/soft_delete〔delete guards〕/batch＋count_users_by_role_id＋handler 5＋main＋lint〔部分〕＋純測 delete guard＋live CRUD/23505/guards）→ U2 Role×Menu+home（**sys_casbin_rule set_role_dimension DB-first**＋id↔route_name＋handler getRoleMenu/updateRoleMenu〔+reload〕/getRoleHome/updateRoleHome＋main＋lint〔補 31〕＋live **DB-first 讀寫閉環**〔snapshot+restore+psql 驗無殘留〕＋②protected-reject＋updateRoleHome→home_of_roles）→ U3 base-web（rev3 wrapper 8＋RoleUpsertModel＋MODAL-WIRING (a)(b)＋i18n 6 鍵＋typecheck＋CDP〔cleanup〕）。
2. **★ 零 migration（R1/R6）**：表＋3 角色＋9 端點 policy＋`role:*` button code 皆 seed。
3. **★ casbin WRITE＝DB-first（R1、B1 校正、constitution §I.7 §4.2）**：`sys_casbin_rule::set_role_dimension` 於 `mutate_in_txn`：read current entity::casbin_rule（11-col）→diff→②protected-reject〔to_revoke 含 protected→`SetDimensionError::Rejected`→handler `biz.role.menuProtected` 2222〕→`delete_many`(revoke)+`insert`(grant、created_by=op)+op-log（entity_table="casbin_rule"、同 txn **原子**）；handler commit 後 `state.enforcer.write().await.load_policy().await`（⑤ reload）。**絕不**用 MgmtApi `remove_filtered_policy`/`add_policies`（B1 違規路徑）。
4. **★ 原子審計（R2）**：casbin_rule 寫+op-log 同 mutate_in_txn（AppState.db）→原子；非 best-effort。
5. **★ live/CDP cleanup（測 Role×Menu 必做）**：set_role_dimension 經 mutate_in_txn **commit**（讀寫閉環需 committed 寫供 load_policy 見、無法 txn-rollback 隔離）→ 測必 snapshot 角色原 v2='menu'→測→restore→psql 驗 casbin_rule 回原狀（勿污染 seed）。
6. **delete guards（R5、D3）**：seeded hardcode＋count_users_by_role_id in-use＋self id↔code；batch 整批拒。
7. **id↔route_name（R5）**：getRoleMenu route_names→ids（orphan skip）／updateRoleMenu ids→route_names（不存在 id skip tolerant、D1）。
8. **sys_role CRUD 鏡像 009（R3）**：list §5.8 filter＋PageRes；mutate_in_txn 寫；roleCode 23505→biz.role.duplicateRoleCode；home 由 updateRoleHome（entity 寫、原子）。
9. **lint（R6）**：AS_BUILT [22→31]；9 policy-routes m002 已 seed。entity_access_lint：handler/main 零 path-root entity::（casbin 寫在 sys_casbin_rule facade；id↔route_name 經 facade/Model 欄）。
10. **base-web**：rev3 wrapper（roleId/menuIds number）；MODAL-WIRING (a)(b)；menuProtected 2222 toast；i18n 先 Schema 後 locale；button-auth-modal 留 mock；無 .env flip。
11. **base-web commit `--no-verify`**；rust serial／容器內／force-touch／live `--test-threads=1`＋DATABASE_URL；逐單元兩段式 commit（worktree→pin、S9）；不 push/merge（§I.4）；CDP 不 defer（cleanup）。
12. **零回歸（FR-010/SC-010）**：enforce_mw/require_policy/menu_routes_for_roles/From<DbErr>/login/getUserInfo/getUserRoutes/health/008/009/010 不變；零 migration/entity/schema；base-web 既有檔不改；psql 驗 casbin_rule 無測試殘留。
