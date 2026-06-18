# Phase 0 Research: 010-menu-management

> 接地源＝當前 lineage（rust-api worktree `8ccea9d`／base-web worktree `c1806680`、皆 009 收刀後）親 grep＋3 平行 grounding dimension（rust backend／base-web wiring／m002-m004 seeds）＋主線親驗。**NEEDS CLARIFICATION = 0**（brainstorm＋specify＋clarify 已拍；plan-phase 親驗確認/校正見下）。
> 本刀借 rev2 014/019/020/021/025 設計、code 全新寫（§I.5／⚠️g）。grounding 確認 brainstorm 假設大致成立、校正/釘死 5 處（R1 Q2 zero-migration 可行・R-cr getConstantRoutes builtin・R3 home trivial・R4 menu_type・R11 seed nuance）。

## R1 — 零 migration：表＋seed＋policy＋button code 皆 m001/m002/m004 已備（親 grep 校正）
**Decision**：本刀**無 migration**——`sys_menu`(28 欄)/partial-unique/10 baseline/66 demo/menu-visibility policy/13 endpoint policy/button code 皆既存。
**Rationale（親 grep）**：`sys_menu`(entity 28 欄、archetype A＋`protected:bool`、`#[sea_orm(column_name="order")]`)＋`sys_menu_route_name_active_uniq WHERE deleted_at IS NULL`（m001）＋10 baseline（m002:186-254、id 1-10、前 10 皆 protected=true）＋66 demo（m004、皆 protected=false）＋menu-visibility `v2='menu'` policy（m002 17＋m004 66）＋13 endpoint p-policy（m002:121-131,160-161、全 R_SUPER）＋button code `menu:add/edit/delete`/`user:add/edit/delete`/`role:add/edit/delete`（m002:135-159、v2='button'）皆 seed。`require_policy` 直接對既存 policy 強制；`endpoint_coverage_lint` Assertion A（policy-governed⊆seeded）自動過。`Migrator::up delta == 0`。
**Alternatives**：加 menu_type/pg_trgm index（否決——小選單表 seq-scan 足、tree build in-memory）。

## R2 — menu_routes_for_roles（Casbin v2='menu' 過濾、§I.2 首兌現、鏡像 buttons_for_roles）
**Decision**：新增 `enforce::menu_routes_for_roles(enforcer,&[role])->Vec<String>`（route_name set）；getUserRoutes 用以過濾 `list_active` 後組樹。
**Rationale（親驗 enforce.rs:114-128）**：`buttons_for_roles` 形＝`for role { for rule in get_filtered_policy(0,[role]) { if rule.len()>=3 && rule[2]=="button" { collect rule[1] } } }` union 去重。menu 版**唯一差異＝`rule[2]=="menu"`**（收 rule[1]＝route_name）。`enforce_role_path_method`/`require_policy`/`enforce_mw`/`buttons_for_roles` 本體一行不動（§3.4）。casbin model v0=role/v1=obj/v2=act 通用、v2 區分 button/menu/HTTP-method 三類。
**Alternatives**：每 menu 逐筆 `enforce((role,route_name,"menu"))`（否決——N 次 enforce 慢；get_filtered_policy 一次取 role 全 policy 較省、同 buttons_for_roles）。

## R3 — getUserRoutes（auth-only、DB-fresh roles、home trivial、鏡像 getUserInfo）
**Decision**：`/route/getUserRoutes` auth-only（enforce_mw、**無 require_policy**）；handler 取 DB-fresh `roles_of_user(claims.uid)`→`menu_routes_for_roles`→過濾 `list_active`→flat→tree 序列化→`Res::ok(UserRoute{routes,home})`；`home`＝role.home。
**Rationale（親驗 handler/auth.rs:205-231 getUserInfo＋seeds R4）**：getUserInfo 已示範 DB-fresh roles（`roles_of_user`、claims.roles 僅 hint）＋`buttons_for_roles`＋`Res::ok`——getUserRoutes 同形。**home 解析 trivial**：`sys_role.home` 三角色（R_SUPER/R_ADMIN/R_USER_COMMON）皆 seed `'home'`（m002:64-67）→多 role 取首個有 home 者＝恆 'home'、無歧義（§11⑩ 解消）。前端 `initDynamicAuthRoute` 消費 `{routes,home}`→`setRouteHome(home)`＋`handleUpdateRootRouteRedirect(home)`（route store:211-230）。
**Alternatives**：getUserRoutes 掛 require_policy（否決——任何登入者皆可取自己的選單、過濾在 handler 內、非 per-path policy；auth-only 正確）。

## R4 — menu_type 語意＋reparent 3+1 guard（⚠️o、§3.3、facade slim enum）
**Decision**：`menu_type==1`＝目錄（layout.base、無 view component、可有 children）／`==2`＝頁（view.*）。reparent guard＝facade `ReparentError{Db(DbErr),TargetMissing,NotDirectory,WouldCycle,ProtectedFixed}`（不依賴 AppError）；handler match→biz 2222。
**Rationale（親驗 m004:12 註解＋m002 seed）**：m004 明文「menu_type（1=目錄 layout.base／無 component 有 children；2=頁 view.*）」；m002 `'manage',1,...,'layout.base'`（目錄）vs `'manage_user',2,...,'view.manage_user'`（頁）。3+1 guard：①目標父存在且 active（find_active_by_id）②目標 menu_type==1（非目錄→NotDirectory）③非自身後代（防環、遞迴查 descendant set；`parent_id=None` 搬頂層合法）④本選單 `protected`→父固定（ProtectedFixed）。⚠️o：intra-entity 純 ref→下沉 facade 自驗、slim enum、避層級倒置。**baseline 10 皆 protected=true**（home/manage/manage_*/function/function_toggle-auth）；demo 66 皆 false（可自由 reparent）。
**Alternatives**：全 handler 層驗（否決——⚠️o 推翻、intra-entity 集中 facade）。

## R5 — delete guard（protected＋has-active-children、facade slim enum、批次逐項整批拒）
**Decision**：soft_delete 前 facade 查 `protected`（→`DeleteError::Protected`）＋有 active children（→`DeleteError::HasActiveChildren`）；handler match→2222。批次（spec Clarification）**逐項獨立驗證、整批拒**：批內任一 protected 或 has-active-child（**即使子同批被選**）→整批拒、無 partial；不做批內深度排序/cascade。
**Rationale（親驗 sys_user::soft_delete:49-80 template＋spec Clarification 2026-06-19）**：soft_delete 沿 sys_user mutate_in_txn 形（find→None no-op／Some→set deleted_at+deleted_by 成對→SOFT_DELETE op-log）；前置 guard 為 sys_menu 內 ref 檢查（intra-entity、⚠️o 下沉 facade）。has-active-children＝`find_active().filter(ParentId.eq(id)).count()>0`。批次整批拒＝最一致單筆「有子父→擋」（D4）、active 樹恆無孤兒。
**Alternatives**：cascade soft-delete（否決——spec D4 拒、復原語意複雜）／批內深度排序（否決——spec Clarification 拒、重新引入部分執行複雜度）。

## R6 — 回收桶統一清單（getMenuList/v2 回 list_all+deleted flag；getDeletedMenus drop；restore 孤兒→頂層）
**Decision**：getMenuList/v2 回 `list_all`（`Entity::find()` 含 soft-deleted）→tree（含已刪節點）+每節點 `deleted:bool`；**getDeletedMenus 端點 drop**（統一清單取代、其 seeded policy 留 unused）；restore（孤兒→parent_id=None、RESTORE op-log）。getUserRoutes/getMenuTree 仍 `list_active`。
**Rationale（spec Clarification＋親驗 base-web index.vue B②）**：spec 拍板「已刪除與未刪除同列、多『已刪除』欄」；故 getMenuList/v2 不可 find_active。base-web index.vue tree-table 現 11 欄（無已刪除欄）+handleDelete/handleBatchDelete stub→本刀加「已刪除」欄+restore action+接真 fn。getDeletedMenus seeded policy（m002:160 protected=true）不註冊路由＝lint 允許（Assertion A 非反向、policy⊆seed 不要求 seed⊆registered）。
**Alternatives**：分離回收桶頁/getDeletedMenus（否決——spec 拍板統一清單）。

## R7 — wire id 兩域＋component 字串（⚠️r、§I.3、三端對齊）
**Decision**：**路由域 `Api.Route.MenuRoute.id`→string**（to_string）；**管理域 `Api.SystemManage.Menu.id`〔CommonRecord〕→number**；`parentId`→number（0=頂層、rust `parent_id:Option<i64>` None）；component 字串 `layout.base$view.xxx`（或 `layout.base`／`view.xxx`）。
**Rationale（親驗 typings/api/route.d.ts:10-12＋system-manage.d.ts:105-127＋shared.ts:25-42＋transform.ts:35-83）**：`MenuRoute extends ElegantConstRoute { id:string }`；`Menu = CommonRecord<{parentId:number,menuType:'1'|'2',...}> & MenuPropsOfRoute`（CommonRecord.id:number）。同 `sys_menu.id`(i64) 兩端點不同序列化（⚠️r 逐欄忠實 typings）。component：base-web `transformLayoutAndPageToComponent`（shared.ts）出 `layout.base$view.xxx`；rust 序列化 menu→route 須 emit 同格式（transform.ts `getSingleLevelRouteComponent` split `$`→`layouts[layout]`/`views[view]`、key 不符 throw）。menu→route meta：title(menuName i18n)/i18nKey/icon(iconType==2→localIcon)/order/hideInMenu/keepAlive/constant/multiTab/href/activeMenu/query。
**Alternatives**：兩域同 number（否決——typings 權威 MenuRoute.id=string、⚠️r 忠實）。

## R-cr — getConstantRoutes ↔ §I.2 常數前端寫死（builtin routes、route store 不動）
**Decision**：`/route/getConstantRoutes`（public）回 sys_menu `constant=true`（現 seed 無 constant 選單→`[]`）；login/404/403＝前端 **builtin routes**（router 建立時掛載、非經 store constant 機制／非經 getConstantRoutes）→ `[]` 相容、**route store 不改**（base-web 既有檔不動、contract §6.3）。
**Rationale（親驗 route store index.ts:152-175）**：`initConstantRoute` dynamic 分支：`fetchGetConstantRoutes` 成功→`addConstantRoutes(data)`（[] 則加空）、**error→fallback static constantRoutes**。login/404/403 為 soybean builtin（router base、與 store constantRoutes 機制分離、§I.2「前端寫死」）→ getConstantRoutes=[] 不影響其可達。**implementer 須 CDP 確認**：dynamic 模式下 login/404/403 可達（若意外不可達＝builtin 假設誤、才需最小 store rev3-inline 保留 local 常數、屆時 surface）。
**Alternatives**：getConstantRoutes 回 DB 鏡像常數（否決——login/404/403 非 sys_menu、§I.2 前端寫死）／改 store dynamic 分支 merge local（否決——除非 builtin 假設誤；避免動既有檔）。

## R8 — .env dynamic flip（#7、base-web 單元最後一步、高 stakes de-risk）
**Decision**：`.env VITE_AUTH_ROUTE_MODE` static→dynamic（BASE-WEB-ADAPT、#7）；**排 base-web 單元最後一步**（getUserRoutes/getConstantRoutes 後端先驗綠）。
**Rationale（親驗 .env:17＋route store:178-230＋auth store:32-36）**：翻 dynamic 後 `initAuthRoute`→`initDynamicAuthRoute`（fetchGetUserRoutes）、`isStaticSuper`（static-only bypass）失效、client `filterAuthRoutesByRoles` 不走（後端過濾）。翻後全 app 路由依賴 getUserRoutes（高 stakes、非 009 additive）→ store 已有 `initDynamicAuthRoute` error→`authStore.resetStore()` fallback（不白屏、導回登入、FR-002）。de-risk：U1 getUserRoutes 三角色 live 綠→U4 末才翻。
**Alternatives**：保 static＋dynamic 並存切換（否決——#7 拍 dynamic）。

## R9 — AuditOperation::Restore（首個 op-log consumer）
**Decision**：menu restore op-log `operation=AuditOperation::Restore`（"RESTORE"）、entity_id=Some(id)、payload_before=已刪 Model.audit_json()、payload_after=復原 Model；首個 Restore consumer。
**Rationale（親驗 audit.rs:16-32）**：`AuditOperation{Insert,Update,SoftDelete,Restore}` 皆在、`as_str()` "RESTORE" 已備；009 用 Insert/Update、soft_delete 用 SoftDelete、**menu restore 首用 Restore**。restore facade＝mutate_in_txn：find（含 soft-deleted）→若父已刪則 parent_id=None→clear deleted_at/deleted_by→update→RESTORE event。
**Alternatives**：restore 復用 SoftDelete reverse（否決——Restore 變體存在、語意明確）。

## R10 — endpoint_coverage_lint bump（11→22、public/auth-only 入 AS_BUILT 非 policy-routes）
**Decision**：`AS_BUILT_ROUTES [&str;11]→[&str;22]`，加 11 路由（3 `/route/*`＋8 `/systemManage/*Menu*`）。
**Rationale（親驗 endpoint_coverage_lint.rs:45-57,150-227）**：`extract_routes` 抓所有 `.route("<path>"`（BTreeSet dedup）；Assertion B `registered==AS_BUILT_ROUTES`（含 public/auth-only）；`extract_policy_routes` 抓 `require_policy("<path>","<method>")`；Assertion A 每 policy-route 須 m002 seed（policy⊆seeded、非反向）。`/route/getConstantRoutes`(public、無 mw)/`getUserRoutes`/`isRouteExist`(auth-only、enforce_mw 無 require_policy)→入 AS_BUILT（Assertion B）但**不在 policy-routes**（Assertion A 不要求其 seed）；8 `/systemManage/*Menu*`(require_policy)→policy-governed、m002 已 seed→Assertion A 過。陣列長度型註記手動 bump、與註冊同 commit（S9）。
**Alternatives**：把 /route/* 也掛 require_policy（否決——auth-only 正確、過濾在 handler）。

## R11 — Q2 retroactive button gating（user 可做零 migration／settings skip／seed nuance）
**Decision**：retroactive hasAuth gating——**user 頁可做**（`user:add/edit/delete` button code 已 m002 seed、零 migration）；**system-settings 頁 skip**（無 button code＋R_SUPER-only 選單已隱→moot）。menu 頁 `menu:add/edit/delete`（已 seed）。
**Rationale（親驗 m002:135-159 button codes＋user/settings 頁 grep）**：m002 有 `user:add/edit/delete`（R_SUPER 全；R_ADMIN 有 `user:edit`）、`menu:*`、`role:*`（R_SUPER）；**無 `system-settings:*`/`systemSettings:*`**；system-settings 選單 R_SUPER-only（m002:165）→非 super 連選單都不見、其 button gating moot。user/index.vue（B⑦）+system-settings/index.vue 現皆無 hasAuth。Q2「未 seed→surface」之解＝settings skip（不為 moot 加 migration）、plan 報告 surface。
**★ seed nuance（flag、非本刀修）**：R_ADMIN 有 `user:edit` button＋`manage_role` menu，但 user-write/role 端點 R_SUPER-only（009/Role 刀）→按鈕/選單可見但動作 403（既有 seed 與 endpoint policy 不對齊）；本刀 gating 忠實 seed、此不對齊登 follow-up backlog、不在本刀修。
**Alternatives**：為 settings 加 button-code seed（否決——migration＋moot；除非 user plan-review 指示）。

## R12 — per-role menu 可見性（getUserRoutes 三角色 test oracle、親驗 seeds）
**Decision／親驗（m002:99-168 v2='menu'）**：
- **R_SUPER**（9 menu）：home／manage_user／manage_user-detail／manage_role／**manage_menu**／function／function_toggle-auth／**manage_system-settings**／**manage_policy-archive**（4 protected）。
- **R_ADMIN**（6）：home／manage_user／manage_user-detail／manage_role／function／function_toggle-auth（**無** manage_menu／system-settings／policy-archive）。
- **R_USER_COMMON**（3）：home／function／function_toggle-auth。
**Rationale**：getUserRoutes live test oracle＝此三集（super 含 manage_menu、admin 不含、common 僅 home/function）。`manage_user-detail` hide_in_menu=true（路由掛載但側欄不顯、前端 getGlobalMenusByAuthRoutes 濾 hideInMenu）。demo 66 全 R_SUPER（admin/common getUserRoutes 不含 demo）。
**Alternatives**：無（直接 seed 事實）。
