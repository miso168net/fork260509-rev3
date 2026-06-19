# Tasks: 011-role-management（角色 CRUD＋角色×選單授權＋角色首頁＝波2 第三刀）

**Input**: Design documents from `/specs/011-role-management/`

**Prerequisites**: plan.md ✅、spec.md ✅（7 US／10 FR／10 SC＋3 Clarifications）、research.md（R1 **DB-first write**・R2 **原子審計**・R3 sys_role facade・R4 wire・R5 net-new helper・R6 m002・R7 deferred）✅、data-model.md ✅、contracts/（verification-commands C-V-0~11＋role-management-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS、Q9 DB-first 合規）。

> **★ B1 校正（/speckit-analyze 抓出、user 拍板 option 1）**：Role×Menu 寫＝**DB-first**（`sys_casbin_rule::set_role_dimension` 直寫 `entity::casbin_rule` 11-col 於 `mutate_in_txn` 原子 op-log、②protected-reject、寫後 `enforcer.load_policy()` reload、**絕不用 MgmtApi `remove_filtered_policy`/`add_policies`**）——constitution §I.7 §4.2 ①DB-first/②protected/④原子/⑤reload。

**Tests**: 本 feature **有純函式測＋活體測＋lint**（constitution §I.4 TDD）。純測＝in-crate `#[cfg(test)]`（delete guard 三情境／build_*_active_model／id↔route_name 映射，**test-first**）；活體＝live（role CRUD／roleCode 23505→2222／delete guards＋batch 整批拒／**★ Role×Menu DB-first 讀寫閉環＋②protected-reject＋原子審計**／updateRoleHome→home_of_roles、`#[ignore]` `--test-threads=1`＋`DATABASE_URL`）；lint＝`endpoint_coverage_lint`（bump [22→31]）＋`entity_access_lint`。

**Organization**: 依 user story 分 phase。**★ 校正（research）**：零 migration；casbin **DB-first**（entity::casbin_rule 直寫、無 MgmtApi）；**★★ casbin 寫 commit→測 Role×Menu 必 cleanup**（snapshot+restore、psql 驗無殘留）；wire id 域＝number（roleId/menuIds 不轉 String、⚠️r）；**rust 全程 serial**、build/test **容器內** `docker compose … exec -T rust-api`（改 .rs 先 force-touch；`--test <name>`／`--bin server <filter>` 防假綠）；**live `--test-threads=1`＋`DATABASE_URL`**；base-web commit `--no-verify`；**逐單元兩段式 commit**（worktree→pin、S9）；**§I.4：全程不 push/merge**；**★ 無 .env flip**（010 已 dynamic）；**button-auth-modal 留 mock**（波3）。**無新 crate／無新 dep**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup

- [ ] T001 親驗前置（research R1/R6）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait` 全 healthy；psql 確認 sys_role 3 角色（home='home'、status=1）＋sys_user_role 指派（3 角色皆 in-use）＋9 role 端點 casbin policy（getRoleList R_SUPER+R_ADMIN／其餘 R_SUPER／getRoleMenu·updateRoleMenu protected=true）＋`role:*` button code（R_SUPER）＋casbin_rule（11-col、含 protected）皆 seed＝本刀**零 migration、無新 crate/dep**

**Checkpoint**: 環境就緒、表/seed/policy/button code 已在（無 migration）

## Phase 2: Foundational（blocking US1~US6：共享 facade 讀 seam＋count helper＋DTO）

- [ ] T002 [P] sys_role facade 讀 fn 於 `rust-api/server/src/model/facade/sys_role.rs`（既有 find_active/home_of_roles 不動）：`list`（§5.8 分頁/filter：roleName/roleCode 模糊 `LOWER(col) LIKE ESCAPE`、status 精確、空字串守門 normalize→`PageRes<Model>`）／`find_active_by_id`（update/delete guard/id→code 用）（data-model §1、research R3）
- [ ] T003 [P] sys_user_role facade `count_users_by_role_id(conn,role_id:i64)->Result<i64,DbErr>` 於 `rust-api/server/src/model/facade/sys_user_role.rs`（in-use guard、net-new；`Entity::find().filter(RoleId.eq).count()`；既有 roles_of_user/replace_roles_in_txn 不動）（data-model §2、research R5）
- [ ] T004 [P] handler DTO 於 `rust-api/server/src/handler/system_manage.rs`（沿 009）：`RoleUpsertReq`（id:Option<String>/roleName/roleCode/roleDesc?/status?、serde camelCase）／`RoleMenuReq{roleId:i64,menuIds:Vec<i64>}`／`RoleHomeReq{roleId:i64,home:String}`／`RoleSearchQuery`（current/size/roleName?/roleCode?/status?）；`RoleWrite` facade 寫入型＋`build_create_active_model`/`build_update_active_model` 純測 seam（**test-first**、成對審計欄、update 不動 created_*）（data-model §1/§5、research R3）

**Checkpoint**: sys_role 讀 seam＋count helper＋DTO＋active_model 純測綠就緒

## Phase 3: US1 — 超級管理員瀏覽角色清單 (P1) 🎯 MVP

**Goal**: 授權者分頁/filter 瀏覽角色（getRoleList、R_SUPER+R_ADMIN）。
**Independent Test**: C-V-3（partial）：getRoleList 分頁＋roleName/roleCode/status filter（空字串略過）。

- [ ] T005 [US1] handler `get_role_list(State,Extension<Claims>,Query<RoleSearchQuery>)->Res<PageRes<RoleListItem>>`（§5.8 filter＋PageRes、空字串守門 normalize、沿 009 get_user_list）於 `rust-api/server/src/handler/system_manage.rs`（data-model §5）
- [ ] T006 [US1] `rust-api/server/src/main.rs` 註冊 `GET /systemManage/getRoleList`（`route_layer(require_policy("/systemManage/getRoleList","GET"))`＋外層 enforce_mw、入 roles 子 router）＋`endpoint_coverage_lint` `AS_BUILT_ROUTES [&str;22]→[&str;23]`（+1、同 commit；getRoleList R_SUPER+R_ADMIN m002 已 seed）（data-model §6/§11、research R6）
- [ ] T007 [US1] C-V-3（partial）live（`#[ignore]` `--test-threads=1` `DATABASE_URL`）：getRoleList 分頁＋filter（roleName 模糊／status 精確／空字串守門回全部）。對應 SC-001

**Checkpoint**: US1 全綠＝MVP（角色清單讀就緒）→ **雙段 commit**（rust-api worktree→pin）

## Phase 4: US2 — 超級管理員新增/修改角色 (P2)

**Goal**: super addRole（roleCode 唯一）／updateRole；INSERT/UPDATE op-log。
**Independent Test**: C-V-3：CRUD round-trip＋roleCode dup→2222。

- [ ] T008 [US2] sys_role facade `create(conn,RoleWrite,operator,trace)->Result<Model,DbErr>`（mutate_in_txn＋INSERT op-log、entity_id=Some(after.id)）／`update(conn,id,RoleWrite,operator,trace)->Result<Option<Model>,DbErr>`（find_active_by_id None→Ok(None) no-op；含 name/desc/status〔home 由 US5〕；updated_at/by 成對；UPDATE op-log）於 `rust-api/server/src/model/facade/sys_role.rs`（data-model §1、research R3）
- [ ] T009 [US2] handler `add_role(State,Extension<RequestContext>,Extension<Claims>,Json<RoleUpsertReq>)->Res<()>`（`map_write_err`→23505→`biz.role.duplicateRoleCode`、禁裸 `?`、沿 009）／`update_role(...)`（id parse→update None→`biz.role.notFound`）於 handler/system_manage.rs（data-model §5、research R4）
- [ ] T010 [US2] `main.rs` 註冊 `POST /systemManage/addRole`＋`updateRole`（route_layer require_policy POST R_SUPER）＋`endpoint_coverage_lint` `[&str;23]→[&str;25]`（+2、同 commit）（data-model §6）
- [ ] T011 [US2] C-V-3 live：addRole（roleCode 唯一、INSERT op-log INET+trace）→updateRole（改 name/desc/status、UPDATE op-log）；**dup roleCode→`Biz("biz.role.duplicateRoleCode")` 2222 非 5000**（sql_err 路徑）；外層 txn rollback 隔離。對應 SC-001/002

**Checkpoint**: US2 全綠（新增/修改）→ **雙段 commit**

## Phase 5: US3 — 超級管理員刪除/批次刪除角色（守門） (P2)

**Goal**: super soft-delete 單/批（seeded/in-use/self 拒、批次整批拒）；SOFT_DELETE op-log。
**Independent Test**: C-V-4（delete guards 三情境＋batch 整批拒）。

- [ ] T012 [US3] sys_role facade `soft_delete(conn,id,operator,trace)->Result<Option<Model>,DbErr>`（mutate_in_txn＋成對 deleted_at/by＋SOFT_DELETE op-log）／`batch_soft_delete(conn,ids:&[i64],operator,trace)`（**逐項全過才執行、整批拒無 partial**、沿 010）於 `rust-api/server/src/model/facade/sys_role.rs`（delete guards 於 handler 前置、data-model §1/§8）
- [ ] T013 [US3] handler `delete_role(...Json<IdReq>)`／`batch_delete_role(...Json<IdsReq>)`（★ delete guards 前置〔research R5/D3〕：① role.code ∈ {R_SUPER,R_ADMIN,R_USER_COMMON} hardcode→`biz.role.seededProtected`；② `count_users_by_role_id(id)>0`→`biz.role.inUse`；③ self：`roles_of_user(claims.uid)` codes contains role.code〔id→code via find_active_by_id〕→`biz.role.cannotDeleteSelfRole`；batch 同 txn 先全檢查、整批拒）於 handler/system_manage.rs（data-model §5/§8）
- [ ] T014 [US3] `main.rs` 註冊 `DELETE /systemManage/deleteRole`＋`batchDeleteRole`（route_layer require_policy DELETE R_SUPER）＋`endpoint_coverage_lint` `[&str;25]→[&str;27]`（+2、同 commit）（data-model §6）
- [ ] T015 [US3] C-V-1 純測（delete guard 三情境核心 test-first）＋C-V-4 live：seeded/in-use/self 各→2222；**批次含可刪+不可刪→整批拒、DB 無變**；可刪 throwaway 無人用角色→可軟刪（外層 txn rollback 還原）。對應 SC-003

**Checkpoint**: US3 全綠（刪除守門）→ **雙段 commit**

## Phase 6: US4 — 超級管理員指派角色可見選單（★ DB-first casbin policy WRITE） (P2)

**Goal**: super getRoleMenu/updateRoleMenu（★ 全專案首次 casbin policy WRITE、**DB-first**）；與 010 getUserRoutes 讀寫閉環；原子審計＋②protected-reject。
**Independent Test**: C-V-5（★ DB-first 讀寫閉環＋②protected＋原子審計、**須 cleanup**）。

- [ ] T016 [US4] ★ **net-new facade `rust-api/server/src/model/facade/sys_casbin_rule.rs`**：`set_role_dimension<C:TransactionTrait>(conn,role_code,dimension,desired_objs,operator,trace,role_id)->Result<SetDimensionOutcome,SetDimensionError>`——**DB-first**：`mutate_in_txn` 內 read current `entity::casbin_rule`（11-col、filter ptype='p'∧v0=role_code∧v2=dim、見 protected）→diff→**②protected-reject**（to_revoke 任一 protected→`SetDimensionError::Rejected(objs)`、整批拒零變更）→revoke `Entity::delete_many().filter().exec`＋grant `ActiveModel{...,created_by:Set(Some(op.id)),protected:Set(false)}.insert`＋op-log `AuditEvent{op:Update,entity_table:"casbin_rule",entity_id:Some(role_id),before/after route_names}`（**同 txn 原子**）；`SetDimensionError{Db,Rejected(Vec<String>)}`／`SetDimensionOutcome{changed:bool}`。**絕不用 enforcer MgmtApi 寫**（data-model §3、research R1/R2）
- [ ] T017 [US4] id↔route_name 映射（research R5）：getRoleMenu 用 role code→`enforce::menu_routes_for_roles(&*state.enforcer.read().await,&[code])`〔010 既有讀、in-memory 合規〕→route_names→sys_menu route_name→id（orphan skip）；updateRoleMenu 用 menuIds→sys_menu route_names（不存在 id→skip tolerant、D1）。建議 sys_menu facade 加 `route_names_for_ids`/`ids_for_route_names`（或 handler 自 list_active 建 map、Model 欄存取非 entity:: path-root）於 `rust-api/server/src/model/facade/sys_menu.rs`/handler（data-model §4）
- [ ] T018 [US4] handler `get_role_menu(State,Extension<Claims>,Query<{roleId:i64}>)->Res<Vec<i64>>`（find_active_by_id None→`biz.role.notFound`→code→route_names→menu ids）／`update_role_menu(State,Extension<RequestContext>,Extension<Claims>,Json<RoleMenuReq>)->Res<()>`（find_active_by_id→menuIds→route_names→`sys_casbin_rule::set_role_dimension(code,"menu",route_names,op,trace,role_id)`→`SetDimensionError::Rejected`→`biz.role.menuProtected` 2222／`Db`→Internal；**Ok 且 outcome.changed→`state.enforcer.write().await.load_policy().await`** ⑤ reload）於 handler/system_manage.rs（data-model §5、research R1/R2）
- [ ] T019 [US4] `main.rs` 註冊 `GET /systemManage/getRoleMenu`＋`POST /systemManage/updateRoleMenu`（route_layer require_policy R_SUPER）＋`endpoint_coverage_lint` `[&str;27]→[&str;29]`（+2、同 commit）；`entity_access_lint`：entity::casbin_rule 僅 sys_casbin_rule facade（豁免）、handler/main 零 path-root entity::（data-model §6/§11）
- [ ] T020 [US4] C-V-5 ★ live **Role×Menu DB-first 讀寫閉環**（**★★ casbin 寫 commit→必 cleanup**）：① snapshot 測試角色原 v2='menu'；② updateRoleMenu→set_role_dimension（entity::casbin_rule delete_many+insert）；③ load_policy reload 後 getRoleMenu 回新集；④ `menu_routes_for_roles([code])`/getUserRoutes 反映新集；⑤ **★ F1 原子審計**：psql 驗 sys_operation_log 恰一筆 `entity_table='casbin_rule'∧entity_id=role_id∧op='UPDATE'`（與 casbin_rule 寫同 txn）；⑥ **②protected-reject**：移除 protected v2='menu'→`menuProtected` 2222、casbin_rule 零變更；⑦ **restore 原集**＋psql 驗 casbin_rule 回原狀。對應 SC-004＋**SC-007**

**Checkpoint**: US4 全綠（DB-first casbin WRITE 讀寫閉環、原子審計、②protected、casbin_rule 無殘留）→ **雙段 commit**

## Phase 7: US5 — 超級管理員設定角色首頁 (P2)

**Goal**: super getRoleHome/updateRoleHome（sys_role.home entity 寫、原子 op-log）。
**Independent Test**: C-V-6（updateRoleHome→home_of_roles 反映）。

- [ ] T021 [US5] handler `get_role_home(State,Extension<Claims>,Query<{roleId:i64}>)->Res<String>`（find_active_by_id→home、default "home"）／`update_role_home(...Json<RoleHomeReq>)->Res<()>`（sys_role.home entity 寫經 facade update/set_home、**原子 op-log**、沿 008/009 entity 寫）於 handler/system_manage.rs；facade 補 home 寫（復用 update 或 set_home）於 `rust-api/server/src/model/facade/sys_role.rs`（data-model §1/§5、research R3）
- [ ] T022 [US5] `main.rs` 註冊 `GET /systemManage/getRoleHome`＋`POST /systemManage/updateRoleHome`（route_layer require_policy R_SUPER）＋`endpoint_coverage_lint` `[&str;29]→[&str;31]`（+2、同 commit；9 role 路由全註冊完成）（data-model §6）
- [ ] T023 [US5] C-V-6 live：updateRoleHome（entity 寫、原子 op-log、外層 txn rollback）→getRoleHome 回新值／`home_of_roles([code])` 反映；UPDATE op-log。對應 SC-005（home value 端；登入導向見 T031 CDP）

**Checkpoint**: US5 全綠（角色首頁）→ **雙段 commit**

## Phase 8: US6 — 依角色授權存取角色管理（越權防護） (P2)

**Goal**: role 寫端/選單指派/首頁限 R_SUPER；getRoleList R_SUPER+R_ADMIN；非授權→403。三守恆。
**Independent Test**: C-V-7（Admin/User 寫 role〔含 batchDeleteRole〕→403／getRoleList R_ADMIN→200）；C-V-2（lint）。

- [ ] T024 [US6] C-V-7 live policy-gate（DB-fresh roles）：Admin getRoleList→200（seed R_SUPER+R_ADMIN）；Admin/User 對 addRole/updateRole/deleteRole/**batchDeleteRole**/getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome→403/5003 不洩資料（C1：batchDeleteRole 入負授權清單）。對應 SC-006
- [ ] T025 [US6] C-V-2：`cargo test -p server --test endpoint_coverage_lint`（`AS_BUILT_ROUTES [&str;31]`==as-built＋9 role policy-governed route 對應 m002 seed、Assertion A/B 綠）＋`entity_access_lint`（handler/auth/main 零 path-root entity::；entity::casbin_rule 僅 sys_casbin_rule facade）。對應 SC-008

**Checkpoint**: US6 全綠（越權＋三守恆）→ **commit**

## Phase 9: US7 + base-web 接線 + Polish & Cross-Cutting

- [ ] T026 [P] [US7] base-web WRAPPER（沿 009/010 rev3-* 檔）：`base-web/src/service/api/rev3-system-manage.ts` 加 `fetchAddRole`/`fetchUpdateRole`（id→String(id)）/`fetchDeleteRole`/`fetchBatchDeleteRole`（ids.map(String)）/`fetchGetRoleMenu(roleId:number)`/`fetchUpdateRoleMenu(roleId:number,menuIds:number[])`〔**roleId/menuIds 維持 number**〕/`fetchGetRoleHome(roleId)`/`fetchUpdateRoleHome(roleId,home)`＋`base-web/src/typings/api/rev3-system-manage.d.ts` `RoleUpsertModel`（Pick<Role,...>&{id?:number}、ADAPT declaration-merge、不改既有 Role）（data-model §10、research R4）
- [ ] T027 [P] [US7] base-web MODAL-WIRING (a)（`rev3-inline MW(a)`、原 stub 行註解保留）：`base-web/src/views/manage/role/index.vue` handleDelete→`fetchDeleteRole`／handleBatchDelete→`fetchBatchDeleteRole`（去 console.log）；`base-web/src/views/manage/role/modules/role-operate-drawer.vue` handleSubmit→add `fetchAddRole`／edit `fetchUpdateRole`；`base-web/src/views/manage/role/modules/menu-auth-modal.vue` getChecks→`fetchGetRoleMenu`／handleSubmit→`fetchUpdateRoleMenu`（checks:number[]；**移除受保護→後端 `menuProtected` 2222 toast 在地化、不靜默**）／getHome→`fetchGetRoleHome`／updateHome→`fetchUpdateRoleHome`（home 選項 getAllPages 010）（data-model §10）
- [ ] T028 [P] [US7] base-web MODAL-WIRING (b) hasAuth gating（`rev3-inline MW(b)`）：`base-web/src/views/manage/role/index.vue` 寫入鈕 `useAuth().hasAuth('role:add'/'role:edit'/'role:delete')`（`role:*` R_SUPER 已 seed）。**button-auth-modal.vue 留 mock**（波3）（data-model §10）
- [ ] T029 [P] [US7] base-web i18n（先 Schema 後 locale）：`base-web/src/typings/app.d.ts` `App.I18n.Schema.backend.biz` 加 `role:{duplicateRoleCode,notFound,seededProtected,inUse,cannotDeleteSelfRole,menuProtected}`（**6 鍵**、含 ★ `menuProtected`）＋`base-web/src/locales/langs/{zh-cn,en-us}.ts` `backend.biz.role.*` 全 6 鍵（data-model §9）
- [ ] T030 C-V-8 base-web `pnpm typecheck`（rev3 role wrapper＋RoleUpsertModel ADAPT 對齊 Role；wire roleId/menuIds number 域零型謊；`--no-verify` commit）。對應 SC-009/010
- [ ] T031 C-V-9 CDP 經 front-nginx 真 `/api`（**★★ 改 casbin policy/建角色→測後 cleanup**）：Super→/manage/role→分頁清單→新增（→**真發 addRole**→toast+列現）→改（→真發 updateRole）→**menu-auth-modal**：開某角色→getRoleMenu 勾選樹→改勾→存（→**真發 updateRoleMenu**）→**換該角色登入→側欄選單反映新指派**（讀寫閉環 D2）→設首頁（→真發 updateRoleHome）→**★ F2：換該角色登入→落地路由＝新首頁**（user-facing redirect、SC-005）→刪 throwaway 角色（→真發 deleteRole）；**斷言真發 request（非僅 toast）**；2222 toast 在地化（dup roleCode／**移除受保護選單→`menuProtected`**）；**hasAuth gating（非 super 無 role 寫入鈕、且 manage_role 選單不見）**；**★★ 測後 cleanup**（restore 改動角色原 v2='menu'、hard-delete 測試角色及殘留 policy、psql 驗 casbin_rule/sys_role 回原狀）。對應 SC-004/005/009
- [ ] T032 C-V-0 build `--locked`（容器內 force-touch、無新 dep、**無 MgmtApi 寫**）＋C-V-10 零回歸：`/health` ok；diff 零 migration/entity/schema；blanket From<DbErr>／enforce_mw／require_policy／menu_routes_for_roles／casbin Enforcer init·load_policy 未改；**base-web route store/transform/system-manage.ts/.d.ts/auth.ts/request 未改**；getUserRoutes/getUserInfo/menu/user/008 不變；psql 驗 casbin_rule 無測試殘留。對應 SC-010
- [ ] T033 C-V-11 prod target image build（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、無新 crate→輕、確認新 facade〔sys_role/sys_user_role/**sys_casbin_rule DB-first**〕/handler(role 9)/lint 編入）

## Dependencies

```
Setup (T001) ─→ Foundational (T002 sys_role reads／T003 count helper／T004 DTO+active_model 純測〔test-first〕)  [rust serial、[P]=不同檔可並行撰寫]
Foundational ──┬─→ US1 (T005 getRoleList→T006 main+lint[23]→T007 live)   [MVP；角色清單讀]
               ├─→ US2 (T008 create/update→T009 handler+23505→T010 main+lint[25]→T011 live)
               ├─→ US3 (T012 soft_delete/batch→T013 handler+delete guards→T014 main+lint[27]→T015 純測+live)   [復用 count helper]
               ├─→ US4 (T016 ★ sys_casbin_rule DB-first set_role_dimension→T017 id↔route_name→T018 handler+load_policy reload→T019 main+lint[29]→T020 ★讀寫閉環 live+②protected+F1 原子審計+cleanup)   [消費 010 menu_routes_for_roles/getUserRoutes]
               ├─→ US5 (T021 getRoleHome/updateRoleHome→T022 main+lint[31]→T023 live)   [entity 寫、原子]
               └─→ US6 (T024 policy-gate live〔含 batchDeleteRole〕／T025 lint 三守恆)        [require_policy 既有、本 phase 驗收]
US1~US6 ──→ US7+base-web+Polish (T026 wrapper／T027 MODAL-WIRING (a)／T028 hasAuth (b)／T029 i18n 6 鍵／T030 typecheck／T031 CDP+F2 redirect+cleanup／T032 零回歸／T033 prod build)
```

## Parallel Execution Examples

- **Foundational 並行撰寫**：T002（sys_role reads）∥ T003（count helper）∥ T004（DTO+active_model、不同檔/段）——cargo build/test 一次一個（rust serial）。
- **base-web [P]**：T026（wrapper/typings）∥ T027（MODAL-WIRING (a)）∥ T028（hasAuth (b)）∥ T029（i18n）——base-web worktree、不同檔可並行撰寫；惟 T030 typecheck 須前述完成、T031 CDP 須後端全綠+base-web restart。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔可並行撰寫」、cargo build/test 一次一個。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T007）＝Setup＋Foundational（sys_role reads＋count helper＋DTO+active_model test-first）＋US1（getRoleList 分頁/filter）＝最小價值（角色清單讀）。US2 新增/修改（T008~T011）／US3 刪除守門（T012~T015）／US4 角色×選單 **DB-first casbin WRITE 讀寫閉環**（T016~T020）／US5 角色首頁（T021~T023）緊接；US6 越權驗收+lint（T024~T025）／US7 前端 hasAuth+base-web 接線（T026~T031）；零回歸+prod build（T032~T033）收口。每 phase checkpoint 過才前進；任一 C-V fail＝修復重跑。**★ lint 逐路由 bump**（T006 [23]／T010 [25]／T014 [27]／T019 [29]／T022 [31]）保每 checkpoint endpoint_coverage_lint 綠。**★ casbin 寫 DB-first（entity::casbin_rule 直寫、原子審計、②protected、load_policy reload、絕不 MgmtApi）；測 Role×Menu 必 cleanup（snapshot+restore、psql 驗無殘留）；rust serial、容器內、改 .rs 先 force-touch、live `--test-threads=1`；逐單元兩段式 commit（worktree→pin S9）；base-web `--no-verify`；★ 無 .env flip；button-auth-modal 留 mock；全程不 push/merge（§I.4）。**

> **階段 2 交棒注記**（CLAUDE.md §3）：實作以 `superpowers:executing-plans` 起手、**Workflow 驅動**，依**實際相依/獨立可審邊界**重分執行單元（不綁本檔編號）——預期 **U1 Role CRUD**（Foundational T002-T004＋US1 T005-T007＋US2 T008-T011＋US3 T012-T015）／**U2 Role×Menu+home**（US4 T016-T020＋US5 T021-T023；★ **sys_casbin_rule DB-first set_role_dimension** 首次 casbin WRITE〔entity::casbin_rule 直寫、原子審計、②protected、load_policy reload、絕不 MgmtApi〕＋讀寫閉環 live【cleanup＋F1 原子審計斷言】＋home entity 寫）／**U3 base-web**（US7 T026-T029＋Polish T030-T033；wrapper+MODAL-WIRING (a)(b)+i18n 6 鍵+typecheck+CDP【cleanup＋F2 redirect】）為 3 load-bearing 單元；US6 越權 acceptance+lint（T024-T025）散入各 rust 單元邊界自驗；T032/T033 final holistic 收口。每單元邊界主線 `git show --stat HEAD` 復核＋容器內自驗＋bump submodule pin（S9 逐單元）；**★★ U2/CDP 的 casbin 寫測必顯式 cleanup＋psql 驗 casbin_rule 無殘留**；★ 絕不 push/merge（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
