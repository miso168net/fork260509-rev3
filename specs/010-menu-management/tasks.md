# Tasks: 010-menu-management（動態角色選單＋選單 CRUD＋統一回收桶＋越權防護＝波2 第二刀）

**Input**: Design documents from `/specs/010-menu-management/`

**Prerequisites**: plan.md ✅、spec.md ✅（6 US／12 FR／11 SC＋2 Clarifications）、research.md（R1 零 migration・R2 menu_routes_for_roles・R3 getUserRoutes/home・R4 menu_type/reparent・R5 delete guard・R6 回收桶統一・R7 wire id 兩域・R-cr getConstantRoutes builtin・R8 .env flip・R9 Restore・R10 lint 3-class・R11 Q2/seed nuance・R12 per-role oracle）✅、data-model.md ✅、contracts/（verification-commands C-V-0~12＋menu-management-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS）。

**Tests**: 本 feature **有純函式測＋活體測＋lint**（constitution §I.4 TDD）。純測＝in-crate `#[cfg(test)]`（tree build／reparent guard 4 情境／delete guard／menu→route 序列化／id 兩域 wire／build_*_active_model，**test-first red→green**）；活體＝live（getUserRoutes 三角色過濾／menu CRUD／reparent·delete guard／23505／restore 孤兒／op-log INSERT·UPDATE·SOFT_DELETE·**RESTORE**、`#[ignore]` `--test-threads=1`＋`DATABASE_URL`）；lint＝`endpoint_coverage_lint`（bump [11→22]）＋既有 `entity_access_lint`。

**Organization**: 依 user story 分 phase。**★ 校正（research）**：零 migration（sys_menu 表＋10 baseline＋66 demo＋menu-visibility policy＋13 endpoint policy＋button code menu:*/user:* 已 m001/m002/m004 seed）；menu_type 1=目錄/2=頁（reparent 目標須目錄）；getConstantRoutes 回 [] 相容（login/404/403=前端 builtin）；home 三角色皆 'home'；**rust 全程 serial**、build/test **容器內** `docker compose … exec -T rust-api`（改 .rs 先 force-touch；`--test <name>`／`--bin server <filter>` 防 bare-filter 假綠）；**live `#[ignore]` 一律 `--test-threads=1`＋`DATABASE_URL`**；base-web commit `--no-verify`；**逐單元兩段式 commit**（rust-api／base-web worktree→outer pin、S9）；**§I.4：全程不 push/merge**；**★ `.env` dynamic flip 為最後一步**（getUserRoutes 先驗綠）。**無新 crate／無新 dep**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup

- [ ] T001 親驗前置（research R1）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait` 全 healthy；grep `rust-api/migration/src/m002_rev2_seeds.rs`＋`m004_demo_menu_seeds.rs` 確認 sys_menu 10 baseline＋66 demo＋menu-visibility `v2='menu'` policy（17+66）＋13 menu endpoint p-policy（全 R_SUPER）＋button code `menu:add/edit/delete`/`user:add/edit/delete`（v2='button'）皆 seed＝本刀**零 migration、無新 crate/dep**

**Checkpoint**: 環境就緒、表/seed/policy/button code 已在（無 migration）

## Phase 2: Foundational（blocking US1~US4：共享 facade seam＋enforce＋tree 序列化＋純函式）

- [ ] T002 [P] enforce `menu_routes_for_roles(enforcer,&[role])->Vec<String>` 於 `rust-api/server/src/auth/enforce.rs`（鏡像 `buttons_for_roles` L114-128、`get_filtered_policy(0,[role])` 濾 `rule[2]=="menu"`→收 `rule[1]` route_name union；enforce_mw/require_policy/buttons_for_roles 本體不動）（data-model §1、research R2）
- [ ] T003 [P] sys_menu facade 讀 fn 於 `rust-api/server/src/model/facade/sys_menu.rs`（SoftDeletable 既存）：`list_active`（find_active order_by order/id）／`list_all`（find 含 soft-deleted、R6）／`find_active_by_id`／`route_name_exists(&str)->bool`／`distinct_pages()->Vec<String>`（data-model §2）
- [ ] T004 [P] menu flat→tree 序列化 helper（**test-first**）於 `rust-api/server/src/handler/system_manage.rs`（或 route 共用）：`build_tree(flat, visible:Option<&HashSet>)`→巢狀（parent_id 分組、order 排序）；MenuRoute 序列化（`id`→string、component 原樣、meta icon_type==2→localIcon/href/multiTab/menuType i16→'1'/'2'）／Menu 序列化（`id`→number、parentId 0=頂層、deleted flag）。純測：tree build／id 兩域 2^53 fail-loud（data-model §3、research R7）
- [ ] T005 [P] handler/mod.rs 加 `pub mod route;`（為 US1 handler/route.rs 預備）

**Checkpoint**: enforce menu 過濾＋facade 讀 seam＋tree 序列化（純測綠）就緒

## Phase 3: US1 — 登入後依角色呈現動態選單 (P1) 🎯 MVP

**Goal**: 登入後側欄選單＝getUserRoutes 依 DB-fresh roles 經 Casbin v2='menu' 過濾（前端零過濾）；常數頁恆在；載入失敗安全回退。
**Independent Test**: C-V-4（三角色 getUserRoutes 過濾差異：super 含 manage_menu／admin 不含但含 manage_user/role／common 僅 home/function；home='home'）。

- [ ] T006 [US1] handler `get_user_routes(State,Extension<Claims>)->Res<UserRoute>`（auth-only；`roles_of_user(claims.uid)`→`menu_routes_for_roles`→過濾 `list_active`→`build_tree(Some(visible))`→MenuRoute[]＋home=role.home〔皆 'home' R3〕）於 `rust-api/server/src/handler/route.rs`（新、鏡像 getUserInfo auth.rs:205-231）（data-model §4、research R3）
- [ ] T007 [US1] handler `get_constant_routes()->Res<Vec<MenuRoute>>`（public、`list_active` filter constant==Some(true)→現空 []、R-cr）＋`is_route_exist(Query)->Res<bool>`（auth-only、`route_name_exists`）於 handler/route.rs（data-model §4）
- [ ] T008 [US1] `rust-api/server/src/main.rs` 加 /route/* 分層：`/route/getConstantRoutes`（**public**、無 mw）／`/route/getUserRoutes`＋`/route/isRouteExist`（**auth-only**、`enforce_mw`、**無 require_policy**）＋`endpoint_coverage_lint` `AS_BUILT_ROUTES [&str;11]→[&str;14]`（+3 /route/*、Assertion A 不要求其 seed、R10、同 commit）（data-model §6/§10）
- [ ] T009 [US1] C-V-4 live（`#[ignore]` `--test-threads=1` `DATABASE_URL`）：getUserRoutes 三角色 Casbin 過濾差異（R12 oracle）＋home='home'。對應 SC-001

**Checkpoint**: US1 全綠＝MVP（動態角色選單後端就緒；base-web .env 翻 dynamic 後生效〔T028〕）→ **雙段 commit**（rust-api worktree→pin）

## Phase 4: US2 — 超級管理員瀏覽選單樹（含已刪除統一清單） (P2)

**Goal**: super 樹狀瀏覽全部選單（active＋soft-deleted、「已刪除」狀態欄）；getAllPages/getMenuTree 供管理用。
**Independent Test**: C-V-7（getMenuList/v2 含 deleted flag、getUserRoutes 不含已刪）。

- [ ] T010 [US2] handler `get_menu_list_v2`（R_SUPER、`list_all`→`build_tree(None)`→含 deleted flag、R6）／`get_menu_tree`（`list_active` 精簡樹、父選擇器）／`get_all_pages`（`distinct_pages`）於 `rust-api/server/src/handler/system_manage.rs`（沿 009 檔；data-model §5）
- [ ] T011 [US2] `main.rs` 註冊 `GET /systemManage/getMenuList/v2`＋`getMenuTree`＋`getAllPages`（各 `route_layer(require_policy(...,"GET"))`、入 menus 子 router R_SUPER）＋`endpoint_coverage_lint` `[&str;14]→[&str;17]`（+3、同 commit）
- [ ] T012 [US2] C-V-7（partial）live：getMenuList/v2 統一清單（active＋deleted＋flag）／getMenuTree（active only）／getAllPages。對應 SC-003

**Checkpoint**: US2 全綠（統一清單讀端）→ **雙段 commit**

## Phase 5: US3 — 超級管理員新增/修改選單（含搬移守門） (P2)

**Goal**: super addMenu（route_name 唯一）／updateMenu（含 reparent 3+1 guard）；INSERT/UPDATE op-log。
**Independent Test**: C-V-5（CRUD round-trip＋dup→2222）＋C-V-6（reparent 4 情境）。

- [ ] T013 [US3] sys_menu facade `create(conn,MenuWrite,operator,trace)`（mutate_in_txn＋INSERT op-log、entity_id=Some(after.id)）／`update(conn,id,MenuWrite,operator,trace)->Option<Model>`（find_active_by_id None→Ok(None)；reparent 變更→`reparent_check`；UPDATE op-log）＋**`reparent_check`→`ReparentError{Db,TargetMissing,NotDirectory,WouldCycle,ProtectedFixed}`**（facade slim enum、不依賴 AppError、3+1 guard：目標存在+active／menu_type==1／非自身後代〔遞迴 descendants 防環〕／self protected→父固定）＋`build_*_active_model` 純測〔C-V-2〕於 `rust-api/server/src/model/facade/sys_menu.rs`（data-model §2、research R4、⚠️o）
- [ ] T014 [US3] handler `add_menu(State,Extension<RequestContext>,Extension<Claims>,Json<MenuUpsertReq>)->Res<()>`（`map_menu_write_err`→23505→`biz.menu.duplicateRouteName`、禁裸 `?`、沿 009）／`update_menu(...)`（id parse→`biz.menu.notFound`；ReparentError match→`biz.menu.{reparentTargetMissing,notDirectory,wouldCycle,protectedFixed}` 2222；update None→notFound）於 handler/system_manage.rs（data-model §5、research R7、⚠️r parentId 0→None）
- [ ] T015 [US3] `main.rs` 註冊 `POST /systemManage/addMenu`＋`updateMenu`（route_layer require_policy POST、入 menus）＋`endpoint_coverage_lint` `[&str;17]→[&str;19]`（同 commit）
- [ ] T016 [US3] C-V-5＋C-V-6（partial）live：addMenu（route_name 唯一、INSERT op-log INET）→updateMenu（合法 reparent、UPDATE op-log）；**dup route_name→2222 非 5000**；reparent 4 情境（TargetMissing/NotDirectory/WouldCycle/ProtectedFixed）各 2222。對應 SC-002/003/005/006

**Checkpoint**: US3 全綠（新增/修改+reparent guard）→ **雙段 commit**

## Phase 6: US4 — 超級管理員刪除/復原選單（軟刪＋回收桶） (P2)

**Goal**: super soft-delete 單/批（protected/has-children 拒、批次整批拒）；restore（孤兒→頂層）；SOFT_DELETE/RESTORE op-log。
**Independent Test**: C-V-6（delete guard）＋C-V-7（restore 孤兒）。

- [ ] T017 [US4] sys_menu facade `soft_delete(conn,id,operator,trace)`（mutate_in_txn＋`delete_check`→`DeleteError{Db,Protected,HasActiveChildren}`〔protected／find_active children count>0〕＋成對 deleted_at/by＋SOFT_DELETE op-log）／`batch_soft_delete(&[i64])`（**逐項 delete_check 全過才執行、整批拒無 partial**、spec Clarification）／`restore(conn,id,operator,trace)`（find 含 soft-deleted→父已刪/不存在→parent_id=None〔孤兒→頂層 D5〕→clear deleted_at/by→**RESTORE op-log 首 consumer** R9）於 facade/sys_menu.rs（data-model §2、research R5/R9、⚠️o）
- [ ] T018 [US4] handler `delete_menu(...Json<IdReq>)`／`batch_delete_menu(...Json<IdsReq>)`（DeleteError match→`biz.menu.{protectedNoDelete,hasActiveChildren}` 2222）／`restore_menu(...Json<IdReq>)`（None→notFound）於 handler/system_manage.rs（data-model §5）
- [ ] T019 [US4] `main.rs` 註冊 `DELETE /systemManage/deleteMenu`＋`batchDeleteMenu`＋`POST /systemManage/restoreMenu`（route_layer require_policy、入 menus）＋`endpoint_coverage_lint` `[&str;19]→[&str;22]`（+3、同 commit；11 menu 路由全註冊完成）
- [ ] T020 [US4] C-V-6＋C-V-7 live：delete/batch（soft-delete deleted_at/by 成對、SOFT_DELETE op-log）；**protected/有 active 子拒、批次含父+其子整批拒、DB 無變**；restore 孤兒→頂層（parent_id=None、RESTORE op-log）。對應 SC-005/007

**Checkpoint**: US4 全綠（刪除 guard＋回收桶 restore）→ **雙段 commit**

## Phase 7: US5 — 依角色授權存取選單管理（越權防護） (P2)

**Goal**: menu 管理端點限 R_SUPER；getUserRoutes auth-only 過濾；非授權→403。三守恆。
**Independent Test**: C-V-8（Admin/User 寫 403／getUserRoutes auth-only 200）；C-V-3（lint）。

- [ ] T021 [US5] C-V-8 live policy-gate（DB-fresh roles）：Admin/User 對 /systemManage/*Menu*（getMenuList/addMenu/deleteMenu 等）→403/5003；`/route/getUserRoutes` auth-only→200（回各自過濾）；`/route/getConstantRoutes` public→200 無 token。對應 SC-008
- [ ] T022 [US5] C-V-3：`cargo test -p server --test endpoint_coverage_lint`（`AS_BUILT_ROUTES [&str;22]`==as-built＋8 menu policy-governed route 對應 m002 seed＋3 /route/* 入 AS_BUILT 非 policy-routes、Assertion A/B 綠）＋`entity_access_lint`（handler/route/main 零 path-root entity::）。對應 FR-007/SC-010

**Checkpoint**: US5 全綠（越權＋三守恆）→ **commit**

## Phase 8: US6 — 選單管理頁寫入鈕依權限顯隱 (P3)

**Goal**: menu 頁寫入鈕 hasAuth gating；retroactive user 頁（Q2、code 已 seed）；system-settings skip（R11 moot）。
**Independent Test**: C-V-10（CDP 非 super 無 menu/user 寫入鈕）。

- [ ] T023 [P] [US6] base-web hasAuth gating（MODAL-WIRING (b)、`rev3-inline MW(b)`）：`base-web/src/views/manage/menu/index.vue` 寫入鈕 `useAuth().hasAuth('menu:add'/'menu:edit'/'menu:delete')`＋**retroactive** `base-web/src/views/manage/user/index.vue` 寫入鈕 `hasAuth('user:add'/'user:edit'/'user:delete')`（R11、code 已 seed）。**system-settings skip**（R11、無 code＋super-only moot）（data-model §9）

**Checkpoint**: US6（前端 gating）→ 併入 base-web 雙段 commit

## Phase 9: base-web 接線 + Polish & Cross-Cutting（含 ★ .env dynamic 最後翻）

- [ ] T024 [P] base-web wrapper（WRAPPER §III.1、沿 009 rev3-* 檔）：`base-web/src/service/api/rev3-system-manage.ts` 加 `fetchAddMenu`/`fetchUpdateMenu`/`fetchDeleteMenu`/`fetchBatchDeleteMenu`/`fetchRestoreMenu`（direct-path import、view 用）＋`base-web/src/typings/api/rev3-system-manage.d.ts` `MenuUpsertModel`（write DTO）＋mgmt 列 `deleted?:boolean`（ADAPT declaration-merge、不改既有 Menu/Api.Route）（data-model §9）
- [ ] T025 [P] base-web MODAL-WIRING (a)（`rev3-inline MW(a)`、原 stub 行註解保留）：`base-web/src/views/manage/menu/index.vue` `handleDelete`→`fetchDeleteMenu`／`handleBatchDelete`→`fetchBatchDeleteMenu`（去 console.log）＋**新增「已刪除」欄**（讀 row.deleted）＋**restore action**（deleted 列→`fetchRestoreMenu`）；`base-web/src/views/manage/menu/modules/menu-operate-modal.vue` `handleSubmit`→add `fetchAddMenu`／edit·addChild `fetchUpdateMenu`（getSubmitParams 既有、parentId 0=頂層）、父選擇 getMenuTree／page getAllPages／route_name isRouteExist 前驗（data-model §9）
- [ ] T026 [P] base-web i18n（I18N-WIRING (ii)(iii)、先 Schema 後 locale）：`base-web/src/typings/app.d.ts` `App.I18n.Schema.backend.biz` 加 `menu:{duplicateRouteName,notFound,reparentTargetMissing,notDirectory,wouldCycle,protectedFixed,protectedNoDelete,hasActiveChildren}`〔(iii)〕＋`base-web/src/locales/langs/{zh-cn,en-us}.ts` `backend.biz.menu.*` 全 8 鍵〔(ii)〕（data-model §8）
- [ ] T027 C-V-9 base-web `pnpm typecheck`（rev3 menu wrapper＋MenuUpsertModel/deleted flag ADAPT 對齊 Menu/Api.Route；wire id 兩域零型謊；`--no-verify` commit）。對應 SC-011
- [ ] T028 ★ base-web `.env`（★ 在 **base-web/.env** root、**非** `src/.env`、易誤；F1 校正）`VITE_AUTH_ROUTE_MODE` static→dynamic（BASE-WEB-ADAPT #7、**base-web 單元最後一步**——T006-T009 getUserRoutes 先驗綠才翻；route store/transform/builtin 不改、R-cr/R8）（data-model §9、research R8）
- [ ] T029 C-V-10 CDP 經 front-nginx 真 `/api`（★.env dynamic 後）：三角色側欄差異（非 super 不見 admin 選單＝D1）＋login/404/403 builtin 可達；Super→/manage/menu→統一清單（已刪除欄）→新增（父選擇/page/route_name 前驗→**真發 addMenu**→toast+列現）→改/reparent（→真發 updateMenu）→刪（→真發 deleteMenu→已刪除列）→restore（→真發 restoreMenu）→批刪；**斷言真發 request**；2222 toast 在地化；**hasAuth gating（F5 校正、忠實 seed）：非 super 之 menu 頁整頁隱（dynamic 選單無 manage_menu）；user 頁 R_ADMIN 仍見 `user:edit` 鈕（m002 seed R_ADMIN 有 user:edit、R11 nuance）但無 `user:add/delete` 鈕**；getUserRoutes 失敗→導回登入（不白屏）。對應 SC-001/002/004/007/008
- [ ] T030 C-V-0 build `--locked`（容器內 force-touch、無新 dep）＋C-V-11 零回歸：`/health` ok；diff 零 migration/entity/schema；blanket From<DbErr> 未改；enforce_mw/require_policy/buttons_for_roles 未改；**base-web route store/transform/system-manage.ts/.d.ts/auth.ts/request 未改**；.env flip 後 user/settings 頁本身不回歸；008/009 不變。對應 SC-011
- [ ] T031 C-V-12 prod target image build（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、無新 crate→輕、確認新 enforce/facade/handler(route+menu)/序列化/lint 編入）

## Dependencies

```
Setup (T001) ─→ Foundational (T002 menu_routes_for_roles／T003 facade reads／T004 tree 序列化〔test-first〕／T005 mod route)  [rust serial、[P]=不同檔可並行撰寫]
Foundational ──┬─→ US1 (T006 getUserRoutes→T007 getConstantRoutes/isRouteExist→T008 main /route/*+lint→T009 live)   [MVP；動態路由讀]
               ├─→ US2 (T010 getMenuList(v2)/getMenuTree/getAllPages→T011 main+lint→T012 live)   [統一清單讀]
               ├─→ US3 (T013 create/update+reparent ReparentError→T014 handler+23505→T015 main+lint→T016 live)
               ├─→ US4 (T017 soft_delete/batch/restore+DeleteError→T018 handler→T019 main+lint→T020 live)   [復用 soft-delete pattern]
               ├─→ US5 (T021 policy-gate live／T022 lint 三守恆)        [require_policy 既有、本 phase 驗收]
               └─→ US6 (T023 base-web hasAuth gating)                    [base-web]
US1~US6 ──→ base-web+Polish (T024 wrapper／T025 MODAL-WIRING (a)／T026 i18n／T027 typecheck／★T028 .env dynamic〔最後〕／T029 CDP／T030 零回歸／T031 prod build)
```

## Parallel Execution Examples

- **Foundational 並行撰寫**：T002（enforce）∥ T003（facade reads）∥ T004（tree 序列化、不同檔/段）∥ T005（mod）——cargo build/test 一次一個（rust serial）。
- **base-web [P]**：T023（hasAuth gating）∥ T024（wrapper/typings）∥ T025（MODAL-WIRING）∥ T026（i18n）——base-web worktree、不同檔可並行撰寫；惟 T027 typecheck 須前述完成、★T028 .env flip 須 T006-T009 驗綠後最後做。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔可並行撰寫」、cargo build/test 一次一個。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T009）＝Setup＋Foundational（enforce menu 過濾＋facade reads＋tree 序列化 test-first）＋US1（getUserRoutes 全鏈：三角色 Casbin 過濾→tree→{routes,home}）＝最小價值（動態角色選單成立、收 D1 選單可見性）。US2 讀（T010~T012）／US3 新增·修改+reparent（T013~T016）／US4 刪除·復原（T017~T020）緊接；US5 越權驗收+lint（T021~T022）／US6 前端 gating（T023）；base-web 接線+Polish（wrapper/MODAL-WIRING/i18n/typecheck/★.env dynamic 最後翻/CDP/零回歸/prod build）。每 phase checkpoint 過才前進；任一 C-V fail＝修復重跑。**★ lint 逐路由 bump**（T008 [14]／T011 [17]／T015 [19]／T019 [22]）保每 checkpoint endpoint_coverage_lint 綠。**rust serial、容器內、改 .rs 先 force-touch、live `--test-threads=1`；逐單元兩段式 commit（worktree→pin S9）；base-web `--no-verify`；★ .env dynamic 最後翻；全程不 push/merge（§I.4）。**

> **階段 2 交棒注記**（CLAUDE.md §3）：實作以 `superpowers:executing-plans` 起手、**Workflow 驅動**，依**實際相依/獨立可審邊界**重分執行單元（不綁本檔編號）——預期 **U1 動態路由讀**（Foundational T002-T005＋US1 T006-T009）／**U2 選單寫 CRUD**（US3 T013-T016；create/update+reparent ReparentError+23505+op-log）／**U3 刪除+回收桶+統一清單讀**（US2 T010-T012〔getMenuList/v2 list_all〕＋US4 T017-T020；soft_delete/batch+restore+DeleteError）／**U4 base-web**（US6 T023＋Polish T024-T029；wrapper+MODAL-WIRING (a)(b)+i18n+typecheck+★.env dynamic 最後翻+CDP）為 4 load-bearing 單元；US5 越權 acceptance+lint（T021-T022）散入各 rust 單元邊界自驗；T030/T031 final holistic 收口。每單元邊界主線 `git show --stat HEAD` 復核＋容器內自驗＋bump submodule pin（S9 逐單元）；★ .env dynamic flip 為 U4 末步（getUserRoutes 先綠）；★ 絕不 push/merge（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
