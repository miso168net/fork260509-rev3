# Contract: Menu 動態路由＋CRUD＋回收桶（010 落定、跨 feature 權威）

> 本刀建立的不變式，後續 Role 刀（getRoleMenu/updateRoleMenu/getRoleHome/getMenuTree/getAllPages 消費）、未來樹型 entity CRUD 繼承。權威＝constitution §I.2/§I.3/§I.6/§III＋DESIGN §3.3/§5.0/§6.1/§8.2＋DECISIONS ⚠️o/⚠️p/⚠️r/⚠️y/#7。

## 1. 動態路由＋menu-Casbin-enforce（§I.2 首立、全專案首兌現）
1. **getUserRoutes auth-only＋後端過濾＋前端零過濾**：`/route/getUserRoutes` 掛 `enforce_mw`（**不** require_policy）；handler 取 DB-fresh `roles_of_user(claims.uid)`→`menu_routes_for_roles`（Casbin `v2='menu'` 過濾、鏡像 `buttons_for_roles`）→過濾 `sys_menu::list_active`→flat→tree→`{routes, home}`。前端零過濾（§I.2）；`home`＝`sys_role.home`。
2. **getConstantRoutes public**：回 `sys_menu constant=true`（現空→`[]`）；login/404/403＝前端 builtin（router 建立掛載、非 store constant／非此端點）→ `[]` 相容。
3. **menu_routes_for_roles 形**：`get_filtered_policy(0,[role])` 濾 `rule[2]=="menu"`→收 `rule[1]`(route_name) union 去重；`enforce_mw`/`require_policy`/`buttons_for_roles` 本體不動。
4. **demo ⚠️p**：demo 全 seed、初始僅 R_SUPER；`hideInMenu`/`pageExcludePatterns` 隱藏機制不啟用、可見性全由 v2='menu' policy 治理。

## 2. tree entity reparent 3+1 guard（⚠️o facade 自驗、全專案首立）
1. **slim error enum 下沉 facade**：`sys_menu::reparent_check`→`ReparentError{Db,TargetMissing,NotDirectory,WouldCycle,ProtectedFixed}`（**不依賴 AppError**、無層級倒置）；handler match→biz 2222。
2. **3+1 guard**：①目標父存在且 active（find_active_by_id）②目標 `menu_type==1`（目錄；非→NotDirectory）③非自身後代（防環、遞迴 descendant set；`parent_id=None` 搬頂層合法）④本選單 `protected`→父固定（ProtectedFixed）。
3. **跨 facade／需 context／restore-skip 留 handler**（⚠️o）：本刀 reparent 為 intra-entity 純 ref→下沉 facade；restore re-parent（孤兒→頂層）由 facade orchestrate（不依賴外部驗）。後續樹型 entity reparent 沿此 pattern。

## 3. delete guard＋批次語意（⚠️o facade、§3.3 spirit）
1. **delete guard 下沉 facade**：`DeleteError{Db,Protected,HasActiveChildren}`；handler match→2222。protected→拒；有 active children（`find_active filter parent_id`)→拒。
2. **批次逐項獨立驗證、整批拒**（spec Clarification）：批內任一選單 protected 或 has-active-child（**即使子同批被選**）→整批拒、無 partial；**不做批內深度排序/cascade**；刪子樹須先刪葉分次。active 樹（getUserRoutes）恆無孤兒。

## 4. 回收桶統一清單＋restore（§5.1 soft-delete 延伸）
1. **統一清單**：`getMenuList/v2` 回 `list_all`（`find` 含 soft-deleted）→tree（含已刪節點）+每節點 `deleted:bool`；已刪除與未刪除同列、就地 restore。getUserRoutes/getMenuTree 仍 `list_active`（側欄/父選擇器無已刪）。
2. **getDeletedMenus 端點 drop**（統一清單取代；其 seeded policy 留 unused、lint Assertion A 非反向允許）。
3. **restore 孤兒→頂層**：restore 時若父已刪/不存在→`parent_id=None`（頂層、admin 再搬）；`AuditOperation::Restore` op-log（**首個 Restore consumer**、entity_id+before/after）。

## 5. wire／i18n 不變式（§I.3 typings 權威＋§III 軌道）
1. **wire id 兩域（⚠️r）**：路由域 `Api.Route.MenuRoute.id`＝**string**（to_string）／管理域 `Api.SystemManage.Menu.id`〔CommonRecord〕＝**number**；同 sys_menu.id 兩端點不同序列化（逐欄忠實 typings）。`parentId`＝number（0=頂層、rust None）；`menuType`/`iconType`/`status` i16→`'1'/'2'`；`component` 字串 `layout.base$view.xxx`（transform.ts split `$` 對齊、key 不符 throw）；`deleted` flag 經 rev3 ADAPT（不改既有 Menu）。2^53 fail-loud guard。
2. **23505 route_name→2222**：`partial-unique sys_menu_route_name_active_uniq` catch、寫端 `sql_err()→UniqueConstraintViolation→Biz("biz.menu.duplicateRouteName")`（沿 009 ⚠️o、blanket From 不改、禁裸 ?）；isRouteExist＝前端 UX 前驗、非後端唯一性保證。
3. **軌道（皆既授）**：`.env VITE_AUTH_ROUTE_MODE dynamic`（BASE-WEB-ADAPT、#7）／rev3-* wrapper（WRAPPER）／deleted flag/MenuUpsertModel typings（ADAPT）／MODAL-WIRING **(a)** mgmt 接線+已刪除列+restore＋**(b)** hasAuth gating（menu＋retroactive user）／`backend.biz.menu.*`（I18N-WIRING、⚠️y）。**route store/transform/builtin/system-manage.ts/.d.ts/auth.ts 不改**（既有檔守恆）。

## 6. endpoint_coverage_lint 漸增（⚠️x、三守恆之三）
1. `AS_BUILT_ROUTES` 逐刀漸增（本刀 [11→22]、dedup by distinct path、陣列長度型註記手動 bump、與註冊同 commit S9）。
2. **三分類**：public（getConstantRoutes、無 mw）／auth-only（getUserRoutes、isRouteExist、enforce_mw 無 require_policy）／policy-governed（8 /systemManage/*Menu*、require_policy）。Assertion B registered==as-built（含全三類）；Assertion A 僅 policy-governed⊆m002 seed（public/auth-only 不要求 seed）。

## 7. 動態路由模式切換（#7、高 stakes）
1. **`.env` static→dynamic 為 base-web 單元最後一步**（getUserRoutes/getConstantRoutes 後端先驗綠才翻）；翻後全 app 路由依賴 getUserRoutes、`isStaticSuper`/client `filterAuthRoutesByRoles` 失效（後端過濾）。
2. **失敗安全回退**：`initDynamicAuthRoute` error→`authStore.resetStore()`（導回登入、不白屏）；既有 store 機制、不改。

## 8. 本刀邊界（OUT／MOOT）
- **MOOT（已 done）**：sys_menu 表+28 欄+protected+partial-unique+10 baseline+66 demo+menu-visibility policy(17+66)+13 endpoint policy+button code（m001/m002/m004）／enforce_mw·require_policy·buttons_for_roles·roles_of_user·mutate_in_txn·SoftDeletable·AuditOperation::Restore·to_audit_operator·blanket From·envelope·sql_err（004-009）／base-web route store·transform·builtin·hasAuth hook·menu mgmt mock·Api.Route/Menu typings（既有）。
- **OUT（遞延）**：Role×Menu 授權＋角色首頁維護（getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome+menu-auth-modal＝Role 刀；**消費本刀 getMenuTree/getAllPages**）／getDeletedMenus 端點（統一清單取代）／iframe 內嵌復原／filter_routes 遞迴化／system-settings button gating（moot skip）／R_ADMIN user:edit button vs super-only endpoint seed 不對齊（follow-up）／casbin_rule 治理欄（波 3）。
- 無 migration／無 schema/entity 變更／無新 crate／enforce_mw·require_policy·buttons_for_roles·From<DbErr> 不動／base-web 既有檔（route store/transform/system-manage 等）不改。
