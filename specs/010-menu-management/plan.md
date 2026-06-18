# Implementation Plan: 010-menu-management（動態角色選單＋選單 CRUD＋統一回收桶＋越權防護＝波2 第二刀）

**Branch**: `010-menu-management` | **Date**: 2026-06-19 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/010-menu-management.md`（波2 第二刀；plan-phase research 親驗校正見下）

## Summary

把 `/manage/menu` 從 mock 切到真 rust-api（**選單 CRUD＋統一回收桶**），並把後台側欄選單從前端 static 本地路由切到 **DB-driven dynamic**（`/route/getUserRoutes` 經 Casbin `v2='menu'` 過濾、§I.2 首兌現）：**11 端點**（/route：getConstantRoutes〔public〕／getUserRoutes〔auth-only〕／isRouteExist〔auth-only〕；/systemManage：getMenuList/v2／getMenuTree／getAllPages／addMenu／updateMenu／deleteMenu／batchDeleteMenu／restoreMenu〔皆 R_SUPER〕）＋`.env static→dynamic`＋D1（選單可見性自動達成＋前端 hasAuth gating）。達成 **3 個全專案首立**：`menu_routes_for_roles`（Casbin v2='menu' 過濾、鏡像 `buttons_for_roles`）／reparent 3+1 guard facade 自驗（⚠️o 主消費者、slim `ReparentError` enum）／menu flat→tree 序列化（RouteMeta D2-D4）。`AuditOperation::Restore` 首個 op-log consumer。沿 008/009 `require_policy`／op-log threading／envelope／`sql_err`→2222／`endpoint_coverage_lint`。**零 migration／零 schema／零 entity 改／無新 crate**（sys_menu 表＋10 baseline＋66 demo＋menu-visibility policy＋13 endpoint policy＋button code 皆 m001/m002/m004 已備）。

**plan-phase research 親驗校正/確認**（act-on-code、見 [research.md](research.md)）：
1. **Q2 retroactive gating zero-migration 可行**：`user:add/edit/delete` button code **已 m002 seed**（user 頁 gating 零 migration）；**`system-settings:*` 無 button code**＋系統設定頁 R_SUPER-only（選單對非 super 已隱）→ 其 button gating **moot、skip**（不為 moot 加 migration；Q2「未 seed→surface」之解＝skip+本報告 surface）。
2. **getConstantRoutes ↔ §I.2 常數相容**：login/404/403 為前端 **builtin routes**（router 建立時掛載、非經 store constant 機制／非經 getConstantRoutes）→ getConstantRoutes 回 `[]`（sys_menu constant=true 現為空）即可、**無需改 route store**（base-web 既有檔不動、守 contract §6.3）；implementer 仍須 CDP 確認 dynamic 模式下 login/404/403 可達。
3. **home 解析 trivial**：`sys_role.home` 三角色皆 `'home'`（多 role 解析 moot）。
4. **menu_type 語意**：1=目錄（layout.base、無 view component、可有 children）／2=頁（view.*）→ reparent「目標須目錄型」＝`menu_type==1`。
5. **seed nuance（flag、非本刀修）**：R_ADMIN 有 `user:edit` button＋`manage_role` menu，但 user-write/role 端點 R_SUPER-only → 按鈕/選單可見但動作 403（既有 seed 與 endpoint policy 不對齊）；本刀 gating 忠實 seed、此不對齊登 follow-up、不在本刀修。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-api、`rust-toolchain.toml` pin）＋TypeScript/Vue 3（base-web、soybean-admin fork）

**Primary Dependencies**: server **無新增 dep／無新 crate**（既有 sea-orm 1.1.20／axum 0.7／casbin）。menu_routes_for_roles 用既有 `Enforcer::get_filtered_policy`（同 buttons_for_roles）；tree-build 為純 Rust（無新 dep）。base-web 零新 npm dep。

**Storage**: PostgreSQL（既有 dev stack、m001 schema）。**本刀無 migration**——`sys_menu`(28 欄、archetype A＋protected)／partial-unique `sys_menu_route_name_active_uniq`／10 baseline＋66 demo＋menu-visibility policy（17 baseline＋66 demo）＋13 endpoint policy＋button code 皆 m001/m002/m004 已 seed（research R1）。

**Testing**: rust in-crate `#[cfg(test)]` 純測（tree build flat→nested／reparent 3+1 guard／delete guard〔protected+has-children〕／menu→route 序列化〔icon_type/href/multiTab〕／id 兩域 wire／build_*_active_model）＋live `#[ignore]` smoke（getUserRoutes 三角色 Casbin 過濾差異／menu CRUD round-trip／reparent·delete guard／23505 dup／restore 孤兒／op-log INSERT·UPDATE·SOFT_DELETE·**RESTORE**）＋`endpoint_coverage_lint`(bump)＋`entity_access_lint`。**live 一律 `--test-threads=1` serial**。base-web `pnpm typecheck`＋CDP 經 front-nginx（**.env dynamic 後**三角色側欄差異＋mgmt CRUD 真發＋已刪除列＋restore）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內 `docker exec`）。

**Project Type**: web（rust-api backend＋base-web frontend）——rust：L4 facade（sys_menu list_active/list_all/find_active_by_id/route_name_exists/distinct_pages/create/update〔reparent guard〕/soft_delete〔delete guard〕/batch/restore）＋L4 enforce（menu_routes_for_roles）＋L5 handler（route.rs 3 端點＋system_manage.rs 8 端點）＋L4 main（/route/* 與 /systemManage/*Menu* 分層）＋menu→tree 序列化＋reparent/delete slim error enum＋L8 endpoint_coverage_lint bump；base-web L0 `.env`（VITE_AUTH_ROUTE_MODE dynamic）＋L3 wrapper（rev3-system-manage.ts menu fn）＋L1/L2 typings（deleted flag ADAPT）＋L4 view（MODAL-WIRING (a) mgmt 接線+已刪除列+restore／(b) hasAuth gating menu+user）＋typings app.d.ts Schema＋locale（backend.biz.menu.*）。

**Performance Goals**: getUserRoutes 每登入一次（非熱路徑）：DB-fresh roles join＋Casbin get_filtered_policy＋menu tree build；menu CRUD 寫單列＋同 txn 審計。p95 保守（⚠️a；getUserRoutes <300ms、寫 <500ms）；選單量小（~76+10）、tree build O(n)。

**Constraints**: `enforce_mw`/`require_policy`/`buttons_for_roles`/`From<DbErr>` 本體不改（§3.4／⚠️o）；授權 subject＝DB-fresh roles（§I.3／§3.4）；**零 migration/schema/entity 變更**；無新 crate；**base-web 既有檔不改**（.env mode 切換＝BASE-WEB-ADAPT；route store/transform/builtin routes 不動——getConstantRoutes=[] 相容；只新增 rev3-* wrapper＋typings ADAPT＋MODAL-WIRING (a)(b) inline＋locale 加 key）；**★ `.env` dynamic flip 為 base-web 單元最後一步**（getUserRoutes 後端先驗綠）；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: 選單樹 ~76 demo＋10 baseline；3 角色；11 rust 端點＋base-web mgmt 頁接線＋動態模式切換。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威？rust-api 缺對應 endpoint？ | **PASS**——base-web 有 menu mgmt 頁＋route store dynamic 路徑＋service fn（getUserRoutes/getMenuList 等、現打非實作後端）；本刀 rust-api 補齊 11 對應 endpoint；m002 policy 已就位、兩端俱在 |
| 2 | 動 base-web inline？屬 MODAL-WIRING ★ 哪用途？依 fork-delta 紀律？ | **PASS**——MODAL-WIRING **(a)** 接線（menu/index.vue delete/batch/restore＋menu-operate-modal submit＋已刪除列）＋**(b)** hasAuth gating（menu 頁＋retroactive user 頁、§III.2 既授 v1.0.0/v1.3.0）＋BASE-WEB-ADAPT（`.env` VITE_AUTH_ROUTE_MODE dynamic＝#7 既授／typings deleted flag ADAPT）＋WRAPPER（rev3-system-manage.ts menu fn）＋I18N-WIRING（backend.biz.menu.*）皆**既授**；**★ route store/transform/builtin 不動**（getConstantRoutes=[] 相容、research R-cr）→ 無「named track 外的既有檔編輯」、無 amendment |
| 3 | menu 顯示走 Casbin enforce？demo ⚠️p？ | **PASS（本刀首兌現）**——本刀即 §I.2「menu 走 Casbin enforce」的落地（getUserRoutes `menu_routes_for_roles` v2='menu' 過濾、前端零過濾）；demo ⚠️p（全 seed R_SUPER、hideInMenu/pageExcludePatterns 不啟用）honored |
| 4 | wire 對齊 §I.3 typings 權威？ | **PASS**——**id 兩域**（`Api.Route.MenuRoute.id`=string／`Api.SystemManage.Menu.id`〔CommonRecord〕=number、⚠️r）；MenuRoute=ElegantConstRoute+id；Menu=CommonRecord+menu 欄+RouteMeta 子集；deleted flag 經 rev3 ADAPT（不改既有 Menu）；parentId=number（0=頂層）；component 字串 `layout.base$view.xxx`（transform 對齊） |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——借 rev2 014/019/020/021/025 設計、code 全新寫（§I.5／⚠️g）；不帶回 rev2 hideInMenu/pageExcludePatterns 隱藏取向（⚠️p 推翻）、不帶回 id-string 漂移（⚠️r） |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——**#7 dynamic route mode 本刀兌現**（`.env` static→dynamic、getUserRoutes 落地）；⚠️p demo seed；#1 名不動；無拍板需改 |
| 7 | 觸 §III ★ 軌道？授權邊界內？ | **PASS**——MODAL-WIRING (a)(b)＋BASE-WEB-ADAPT（.env #7／typings ADAPT）＋WRAPPER＋I18N-WIRING 皆**本檔已授**、在邊界內；route store 不動（R-cr）→ 不觸 named track 外 |
| 8 | 新建業務表（migration）？§I.6 六審計欄？ | **PASS（未觸）**——**零 migration**；`sys_menu`（archetype A 全 6 審計欄＋protected、m001）＋10 baseline＋66 demo＋policy＋button code 皆已建。寫端 create/update/delete/restore 成對寫審計欄（§I.6）；**無 retrofit** |
| 9 | 觸 §I.7 行為島（token/policy/single-session）？ | **PASS（未觸）**——menu＝資料島；getUserRoutes 只讀 sys_menu＋Casbin 過濾、不動 token rotation／policy governance／single-session 三台狀態機；dynamic 模式切換不碰行為島 invariants |

**Gate 結論：9/9 PASS；無 Amendment；§II #7 dynamic 本刀兌現；零 migration；無新 crate；Complexity Tracking 不適用。**

> **無新 crate ⇒ prod build 輕**：11 端點皆 server 內 facade/handler/enforce/模組（無 workspace crate 新增）→ 不觸 §3「新 crate ⇒ Dockerfile COPY」紀律；C-V 仍跑 prod target build 確認新碼編入。

> **★ Q2 surface（user 拍板 B 之執行細節、本報告呈報）**：retroactive hasAuth gating——**user 頁可做（user:* code 已 seed、零 migration）**；**system-settings 頁 skip**（無 button code＋R_SUPER-only 選單已隱→gating moot；不為 moot 加 migration）。若 user 仍要 settings 頁 button-code（migration），請於 plan review 指示；預設 skip。

## Project Structure

### Documentation (this feature)
```text
specs/010-menu-management/
├── spec.md              # /speckit-specify ✅（6 US／12 FR／11 SC＋Clarifications 2 拍板）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 零 migration・R2 menu_routes_for_roles・R3 getUserRoutes/home・R4 menu_type/reparent・R5 delete guard・R6 回收桶統一・R7 wire id 兩域・R-cr getConstantRoutes 相容・R8 .env flip・R9 AuditOperation::Restore・R10 lint 3-class・R11 Q2 button code・R12 per-role 可見性 oracle）
├── data-model.md        # Phase 1 ✅（facade 10 fn＋enforce 1 fn＋handler 11 端點＋DTO/wire 3 端＋reparent/delete enum＋tree 序列化＋base-web 接線）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md     # C-V-0~N
│   └── menu-management-contract.md   # 跨 feature 不變式（getUserRoutes Casbin 過濾／reparent guard／delete guard／回收桶統一／wire id 兩域／dynamic mode）
└── checklists/requirements.md       # 16/16 ✅
```

### Source Code (repository root)
```text
rust-api/server/src/
├── model/facade/sys_menu.rs   # 改：+list_active/list_all/find_active_by_id/route_name_exists/distinct_pages/create/update〔reparent guard〕/soft_delete〔delete guard〕/batch/restore＋reparent ReparentError/delete DeleteError slim enum＋build_*_active_model 純測（SoftDeletable 既存）
├── auth/enforce.rs            # 改：+menu_routes_for_roles（v2='menu' 過濾、鏡像 buttons_for_roles；enforce_mw/require_policy/buttons_for_roles 本體不動）
├── handler/route.rs           # ★ 新：get_user_routes（auth-only、Casbin 過濾→tree→{routes,home}）／get_constant_routes（public）／is_route_exist
├── handler/system_manage.rs   # 改：+get_menu_list_v2（all+deleted）/get_menu_tree/get_all_pages/add_menu/update_menu/delete_menu/batch_delete_menu/restore_menu＋menu DTO＋menu→tree 序列化＋menu biz err map
├── handler/mod.rs             # 改：+pub mod route;
├── main.rs                    # 改：/route/*（public/auth-only 分層）＋/systemManage/*Menu*（require_policy）.merge；+mod
└── (error.rs 不改 blanket)    # menu biz 2222 於 handler match（reparent/delete enum→2222、route_name 23505 sql_err、沿 009）
rust-api/server/tests/endpoint_coverage_lint.rs  # 改：AS_BUILT_ROUTES [&str;11]→[&str;22]（+11；/route/* public·auth-only 入 AS_BUILT 但非 policy-routes）
base-web/src/
├── .env                                   # 改（BASE-WEB-ADAPT、#7）：VITE_AUTH_ROUTE_MODE static→dynamic（★ base-web 單元最後一步）
├── service/api/rev3-system-manage.ts      # 改（WRAPPER）：+fetchAddMenu/fetchUpdateMenu/fetchDeleteMenu/fetchBatchDeleteMenu/fetchRestoreMenu（getMenuList/v2·getMenuTree·getAllPages·route.ts 既有續用）
├── typings/api/rev3-system-manage.d.ts    # 改（ADAPT）：menu write DTO＋deleted flag（declaration-merge、不改既有 Menu/Api.Route）
├── views/manage/menu/index.vue            # 改（MODAL-WIRING (a)(b)）：handleDelete/handleBatchDelete→真 fn＋「已刪除」欄＋restore action＋hasAuth(menu:*) gating
├── views/manage/menu/modules/menu-operate-modal.vue  # 改（MW (a)）：handleSubmit→addMenu/updateMenu／getMenuTree 父選擇／getAllPages／isRouteExist 前驗
├── views/manage/user/index.vue            # 改（MW (b) retroactive）：寫入鈕 hasAuth(user:*) gating（Q2、user code 已 seed）
├── typings/app.d.ts                        # 改（I18N-WIRING (iii)）：App.I18n.Schema.backend.biz 加 menu:{...}（先 Schema 後 locale）
└── locales/langs/{zh-cn,en-us}.ts          # 改（I18N-WIRING (ii)）：backend.biz.menu.{duplicateRouteName,notFound,reparentTargetMissing,notDirectory,wouldCycle,protectedFixed,protectedNoDelete,hasActiveChildren}
# ALREADY（不動）：entity/src/sys_menu.rs／migration（m001/m002/m004 schema+10 baseline+66 demo+policy+button code）／enforce_mw+require_policy+buttons_for_roles+roles_of_user（006/008）／mutate_in_txn+SoftDeletable+AuditOperation::Restore+to_audit_operator（004/005/007）／blanket From<DbErr>+envelope+sql_err map（003/009）／base-web route store 雙路徑+transform+builtin routes+filterAuthRoutesByRoles+getGlobalMenusByAuthRoutes+hasAuth hook+menu mgmt 頁 mock+Api.Route/Menu typings（既有）
```

**Structure Decision**：web（rust-api backend＋base-web frontend）。rust：facade-only（sys_menu 補 fn＋reparent/delete slim enum）＋enforce menu_routes_for_roles＋handler/route.rs（新）＋handler/system_manage.rs（menu 端點）＋main 分層＋lint bump。base-web：.env mode 切換＋WRAPPER＋ADAPT＋MODAL-WIRING (a)(b)＋locale（既有檔不改、route store 不動）。**無 migration/entity/新 crate**（地基 001-009 已 provisioned）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks；~4-5 Workflow 單元 §12 brainstorm）

1. **★ 順序（rust serial、容器內、改 .rs 先 force-touch）**：U1 動態路由讀（menu_routes_for_roles＋list_active＋tree 序列化＋handler/route.rs＋main /route/*＋lint）→ U2 選單寫 CRUD（create/update＋reparent ReparentError＋route_name 23505 map＋op-log Insert/Update＋handler add/update_menu＋getMenuTree/getAllPages＋main＋lint）→ U3 刪除＋回收桶（soft_delete〔protected+has-children DeleteError〕＋batch＋restore〔re-parent 孤兒〕＋list_all＋handler delete/batch/restore/getMenuList(v2)＋main＋lint）→ U4 base-web（rev3 wrapper＋ADAPT deleted flag＋mgmt 接線(MW a)+已刪除列+restore＋hasAuth gating(MW b、menu+user)＋backend.biz.menu.* i18n＋**最後翻 .env dynamic**＋CDP）。
2. **★ 零 migration（R1）**：sys_menu 表＋10 baseline＋66 demo＋menu-visibility policy（17+66）＋13 endpoint policy＋button code（menu:*/user:*/role:*）皆已 seed；`require_policy` 直接對既存 policy 強制；getDeletedMenus policy 已 seed 但本刀 drop 該端點（unused、lint 允許）。
3. **★ menu_routes_for_roles（R2、§I.2 首兌現）**：鏡像 `buttons_for_roles`（enforce.rs:114-128）、`get_filtered_policy(0,[role])` 濾 `rule[2]=="menu"`→收 `rule[1]`（route_name）union；getUserRoutes 用以過濾 list_active→tree。
4. **★ getUserRoutes（R3、鏡像 getUserInfo）**：auth-only（enforce_mw、無 require_policy）；DB-fresh `roles_of_user(claims.uid)`→menu_routes_for_roles→過濾 list_active→flat→tree 序列化→`{routes:MenuRoute[], home}`；home＝role.home（皆 'home'、R3）。
5. **★ reparent 3+1 guard（R4、⚠️o）**：`ReparentError{Db(DbErr),TargetMissing,NotDirectory,WouldCycle,ProtectedFixed}`（facade slim enum、不依賴 AppError）；3+1＝目標存在+active／目標 menu_type==1（目錄）／非自身後代（防環、需遞迴查 descendant）／本選單 protected→父固定；handler match→biz 2222。
6. **★ delete guard（R5、⚠️o）**：soft_delete 前查 `protected`（→DeleteError::Protected）＋active children 存在（→DeleteError::HasActiveChildren）；slim enum→handler 2222。**批次逐項獨立驗證、整批拒（spec Clarification）**：批內任一 protected/has-active-child（即使子同批被選）→整批拒、無 partial（不做批內排序/cascade）。
7. **★ 回收桶統一（R6、spec Clarification）**：getMenuList/v2 回 `list_all`（find 含 soft-deleted）+`deleted` flag→tree（含已刪節點）；getDeletedMenus 端點 drop；restore（孤兒→parent_id=None re-parent、RESTORE op-log）。getUserRoutes/getMenuTree 仍 `list_active`（側欄/父選擇器無已刪）。
8. **★ wire id 兩域（R7、⚠️r）**：getUserRoutes 的 MenuRoute.id→string（to_string）；getMenuList/v2 的 Menu.id→number（CommonRecord）；parentId→number（0=頂層、rust parent_id None）；component 字串 `layout.base$view.xxx`（transform 對齊、R-cr/B④⑥）。
9. **★ getConstantRoutes 相容（R-cr）**：回 sys_menu constant=true（現空→`[]`）；login/404/403＝前端 builtin（router 建立時掛載、非 store constant 機制）→ `[]` 相容、**route store 不動**；CDP 確認 dynamic 下 login 可達。
10. **★ AuditOperation::Restore（R9、首 consumer）**：restore op-log `operation=RESTORE`、entity_id=Some(id)、before=已刪 Model、after=復原 Model。
11. **lint（R10）**：endpoint_coverage_lint AS_BUILT bump [11→22]；`/route/getConstantRoutes`(public)/`getUserRoutes`/`isRouteExist`(auth-only) 入 AS_BUILT（Assertion B）但**非** policy-routes（Assertion A 不要求其 seed）；8 `/systemManage/*Menu*` policy-governed（m002 已 seed）。handler/route/main 零 path-root entity::（entity_access_lint 守恆）。
12. **Q2 retroactive gating（R11、user 拍 B）**：user 頁寫入鈕 hasAuth(user:add/edit/delete)（code 已 seed、零 migration）；**system-settings skip**（無 code＋super-only moot、本報告 surface）。menu 頁 hasAuth(menu:*)。
13. **base-web commit `--no-verify`**（§8.2.1）；rust serial／容器內／改 .rs 先 force-touch／live `--test-threads=1`＋DATABASE_URL；**逐單元兩段式 commit（worktree→pin、S9）**；**★ .env dynamic flip 為最後步**（getUserRoutes 先驗綠、避免全 app 掛在未驗端點）；全程不 push/merge（§I.4）；CDP 不 defer（動態側欄+modal、必 browser 軌）。
14. **零回歸（FR-012/SC-011）**：enforce_mw/require_policy/buttons_for_roles/From<DbErr>/audit_mw/login/getUserInfo/health/008/009 不變；零 migration/entity/schema；base-web 既有檔（route store/transform/system-manage.ts/.d.ts/auth.ts）不改（diff 核）；**.env flip 後既有 user/settings 頁本身不回歸**（僅選單可見性依角色變）。
