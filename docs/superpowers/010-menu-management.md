# 010-menu-management — Phase 0 Brainstorm（spec-design）

> **波 2 第二刀**（資料島；波 2 首刀 009 User 已收〔merge `07b67d2`〕後上 Menu 刀）。承 DESIGN §8.2 縱切清單 `Menu（rev2 014〔runtime 讀〕 019 020 021 025）`。
> **本檔來歷**：借**前代 rev2 014（runtime read：getUserRoutes/getConstantRoutes）＋019/020/021（menu CRUD＋reparent＋回收桶 restore）＋025**為設計參照、對齊**當前 lineage**（rust-api worktree `8ccea9d`／base-web worktree `c1806680`，皆 009 收刀後）；只借設計、**code 全新寫**（§I.5／⚠️g 受控參照：讀允許、拷貝禁止、防回歸）。本檔為 brainstorm 定稿 spec-design，作 `/speckit-specify` 的 input。
> **★ scope 拍板（本次 brainstorm、user 親決）**：**一刀整包 Menu**（選單 CRUD＋統一回收桶＋動態路由 getUserRoutes/getConstantRoutes＋`.env` static→dynamic＋D1〔選單可見性＋前端 hasAuth gating〕）；**Role×Menu 授權（getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋menu-auth-modal）留 Role 刀**（DESIGN §8.2 列於 /manage/role）。實作（階段 2）仍 generous 拆多 Workflow 單元、逐單元 bump pin 抵消單刀粗粒度。
> **凍結權威**：DESIGN **§8.2**（Menu 列覆蓋面、權威 scope 句；Menu/Role 拆刀）＋**§I.2**（menu 由 Casbin RBAC enforce、有權才顯示；業務 menu 走 `/route/getUserRoutes`→後端過濾→前端**零過濾**；constantRoutes login/404/403 前端寫死不動）＋**§3.3**（`sys_menu.parent_id` reparent **3+1 道 guard**）＋**§5.0** 矩陣 `sys_menu` 列（soft-del✓／op-log✓CRUD／enforce✓／archetype A）＋**§5.3** RBAC＋**§3.4**（`enforce_mw` 本體不改、授權 subject＝DB-fresh roles）＋**§5.2／§5.7**（mutation 同 txn op-log＋6 審計欄成對）＋**§6.1**（登入→動態路由掛載流程：`initConstantRoute`＋`initAuthRoute`→`fetchGetUserRoutes`→vue-router 動態掛載）＋**§I.5** rust 全新寫＋**§I.6** archetype A·facade 唯一管道＋**§7.1** wire 三端對齊＋**§7.4** `/api` strip＋**§8.6**（Menu 與 Role 拆兩刀）。
> **相關拍板（DECISIONS §1）**：**⚠️o**（application-RI hybrid：intra-entity 純 ref 檢查〔`sys_menu` reparent 3+1 guard〕**下沉 facade 自驗**、slim model-層 error enum、不依賴 AppError、handler 映 2222；跨 facade／restore-skip 留 handler；DB 能擋者〔unique route_name〕續走 `DbErr`→`sql_err()` 映碼）／**⚠️p**（demo view **全進 sys_menu seed、初始僅勾 R_SUPER**；`hideInMenu`/`pageExcludePatterns` 隱藏機制**皆不啟用**、可見性由 Casbin menu 維度治理、推翻 rev2 §11.5）／**#7**（auth route mode＝**dynamic**、`.env VITE_AUTH_ROUTE_MODE=dynamic`、BASE-WEB-ADAPT 軌道）／**⚠️r**（id 逐欄忠實 typings：`Api.Route.MenuRoute.id`→**string**、`Api.SystemManage.Menu.id`〔CommonRecord〕→**number**；2^53 fail-loud）／**⚠️x**（`endpoint_coverage_lint` 逐單元 bump `AS_BUILT_ROUTES`）／**⚠️y**（biz-msg 載穩定 i18n key、文法 `biz.<entity>.<condition>`）／**⚠️aa**（BASE-WEB-I18N-WIRING ★；本刀加 `backend.biz.menu.*`＝scope (ii)＋(iii) Schema）／**⚠️i**（MODAL-WIRING 五用途全授：本刀用 (a) 接線＋(b) hasAuth gating）／**⚠️s**（fork-delta 雙模式：原行註解保留＋`rev3-inline` 標記）／**⚠️a**（perf 保守預設）／**⚠️g**（受控參照 rev2 source）。
> **衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（引用一律用穩定 §錨、不用揮發行號；本檔不引用本機 memory）。

---

## 1. 目標一句話

把 `/manage/menu` 從 mock 切到真 rust-api（**選單 CRUD＋統一回收桶**），並把後台側欄選單從 **static 本地路由切到 DB-driven dynamic**（`/route/getUserRoutes` 經 Casbin `v2='menu'` 過濾、§I.2）：11 端點（getUserRoutes／getConstantRoutes／isRouteExist／getMenuList(v2)／getMenuTree／getAllPages／addMenu／updateMenu／deleteMenu／batchDeleteMenu／restoreMenu）＋`.env static→dynamic`＋D1（選單可見性自動達成＋前端 hasAuth button gating）。**三個全專案首立**：Casbin `v2='menu'` 選單可見性 enforce（§I.2 兌現）／reparent 3+1 guard facade 自驗（⚠️o 主消費者）／menu flat→tree 序列化（RouteMeta D2-D4）。沿 008/009 已立 `require_policy`／op-log threading／envelope／`sql_err`→2222／`endpoint_coverage_lint`。**零 migration／零 schema／零 entity 改／無新 crate**（sys_menu 表＋seed＋policy 皆 m001/m002/m004 已備）。

## 2. Context（探索蒐集、act-on-code 親驗）

### 2.1 前代 rev2 014（runtime 讀）／019-021（CRUD）/025 參照（借設計、§I.5／⚠️g、不照拷）
- rev2 014＝runtime `/route/getUserRoutes`（角色過濾動態路由）＋`/route/getConstantRoutes`＋`/route/isRouteExist`；019/020/021＝menu CRUD（getMenuList/v2／getMenuTree／getAllPages／addMenu／updateMenu／deleteMenu／batchDeleteMenu）＋reparent＋回收桶 restore；025 相關接線。
- 借：端點形／facade 形／前端 route store dynamic 路徑＋mgmt 頁 modal 接法。**code 全新寫**。
- **不照拷的 rev3 偏離（推翻 rev2）**：rev2 §11.5 `hideInMenu`／`pageExcludePatterns` 隱藏 demo → rev3 **⚠️p 全 demo 進 seed、僅勾 R_SUPER、隱藏機制不啟用**、可見性改由 Casbin menu 維度治理；rev2 menu wire id-as-string → rev3 **⚠️r 逐欄忠實 typings**（`MenuRoute.id` string／`Menu.id` number 兩域不同、見 §2.6）；op-log `ip:None` → rev3 真 `operator_ip` INET（007/008/009、不帶回）。

### 2.2 ★ 當前 lineage 已落地（不重做、MOOT）
- **`sys_menu`(28 欄、archetype A＋`protected`)／partial-unique `sys_menu_route_name_active_uniq`（`WHERE deleted_at IS NULL`）／無 FK（parent_id self-ref）** 均 m001 已建；**10 baseline menu（id 1-10：home／manage／manage_user·role·menu·user-detail·system-settings·policy-archive／function／function_toggle-auth；前 8 個 `protected=true`）m002 seed＋66 demo menu m004 seed**（4 層樹）→ **本刀零 migration**。
- **★ 全部 menu 相關 casbin policy 已 seed**：(a) **menu-visibility `v2='menu'`**：m002 17 baseline（home/manage_user/function 等含 R_ADMIN／R_USER_COMMON 分配；manage_role/menu/system-settings/policy-archive 僅 R_SUPER）＋m004 66 demo（全 R_SUPER、⚠️p）；(b) **13 menu endpoint p-policy**（getMenuList/v2·getMenuTree·getAllPages·addMenu·updateMenu·deleteMenu·batchDeleteMenu·getDeletedMenus·restoreMenu·getRoleMenu·updateRoleMenu·getRoleHome·updateRoleHome、全 R_SUPER）；(c) **button code**：`menu:add`／`menu:edit`／`menu:delete`（v2='button'）→ **註冊路由＋掛 require_policy 即滿足 `endpoint_coverage_lint`、零 seed 變更**（policy-governed⊆seed）。
- `sys_role.home` m002 seed=`'home'`、**目前零消費**（getUserRoutes 的 `home` 取此、本刀首用）。
- 008/009 已立可復用：`require_policy(path,method)`／op-log threading（`ctx.to_audit_operator`）／`PageRes<T>`（**本刀 menu 多用 tree、非 PageRes**）／`endpoint_coverage_lint`（⚠️x、現 `[&str;11]`）／envelope＋`biz.<entity>.<cond>`→2222／23505 `sql_err()`→2222（009 首落、本刀 route_name 沿用）／`AuditOperation::{Insert,Update,SoftDelete}`（009 已用 Insert/Update、`SoftDelete` 用於 soft_delete）。

### 2.3 rust-api GAPS（`8ccea9d` 親驗、本刀 BUILD）
- `facade/sys_menu.rs` 現僅 `impl SoftDeletable`（零 query/CRUD fn）。**缺：active tree 讀（getUserRoutes/getMenuTree 用）／all tree 讀含 soft-deleted（getMenuList/v2 統一清單用、D3）／create／update（含 reparent guard）／soft_delete（含 protected＋has-active-children guard）／restore（re-parent 孤兒）／distinct pages（getAllPages 用）／route_name exists（isRouteExist 用）**。
- `auth/enforce.rs` 現有 `buttons_for_roles`（濾 `v2=='button'`）＋`enforce_role_path_method`。**缺：`menu_routes_for_roles`（濾 `v2=='menu'`→route_name set、鏡像 buttons_for_roles、getUserRoutes 用）**。
- **無 `/route/*` handler**（getUserRoutes/getConstantRoutes/isRouteExist 皆缺）；handler/system_manage.rs 現僅 user/role 端點（009）、缺全部 menu 端點。
- workspace members 不變（**無新 crate** → 免 prod-image-build mandate；C-V 仍跑 prod build 確認新碼編入）。

### 2.4 base-web 現況（§I.1 權威、`c1806680` 親驗）— dynamic 機制已備、mgmt 頁 mock
- **`.env VITE_AUTH_ROUTE_MODE=static`**；route store（`store/modules/route/index.ts`）**雙路徑已接好**：`initStaticAuthRoute`（local `createStaticRoutes`＋`filterAuthRoutesByRoles` client 過濾）／`initDynamicAuthRoute`（`fetchGetUserRoutes`→`{routes,home}`→`addAuthRoutes`→動態掛載；error→`authStore.resetStore()`）。**翻 `.env`→dynamic 即走後者**、store 碼基本不需改。
- **service fn 已存在**（打非實作後端）：`service/api/route.ts`（`fetchGetConstantRoutes` `/route/getConstantRoutes`／`fetchGetUserRoutes` `/route/getUserRoutes`／`fetchIsRouteExist` `/route/isRouteExist`）；`service/api/system-manage.ts`（`fetchGetMenuList` `/systemManage/getMenuList/v2`／`fetchGetAllPages`／`fetchGetMenuTree`）。
- **★ menu mgmt 頁＝functional mock（假綠陷阱）**：`views/manage/menu/{index.vue, modules/{menu-operate-modal.vue, shared.ts}}`。index.vue tree-table（欄 id/menuType/menuName/icon/routeName/routePath/status/hideInMenu/parentId/order/operate、**無「已刪除」欄**）；`fetchGetMenuList()` 已呼叫；add/edit/addChild 經 modal、**delete/batchDelete＝console.log stub、modal submit 未接 HTTP**。modal 收全 28 欄（含 layout$view component 轉換 shared.ts、buttons 內嵌編輯、parentId===0=頂層）。
- `hooks/business/auth.ts` `useAuth().hasAuth(codes)`＝查 `authStore.userInfo.buttons`；demo `function/toggle-auth` 用（`hasAuth('B_CODE1')`）、**manage/ 全頁未用**（grep 空）。
- typings `Api.Route.{MenuRoute(=ElegantConstRoute＋`id:string`),UserRoute{routes,home}}`／`Api.SystemManage.Menu`（CommonRecord〔`id:number`〕＋parentId:number/menuType/menuName/routeName/routePath/component/icon/iconType/buttons/children＋RouteMeta 子集）**皆已宣告**。
- naive-ui 元件（NDataTable tree／NModal／NSelect 等）皆已在 `components.d.ts`（**無新元件**；若 mgmt 頁加新 naive-ui 元件才會觸發 `components.d.ts` 重生、commit 須連帶）。

### 2.5 §5.0 矩陣對 `sys_menu` 的面（DESIGN §5.0 親查）
`| sys_menu | soft-del ✓ | op-log ✓(CRUD) | enforce ✓(/systemManage/*Menu* + /route/getUserRoutes v2='menu') | search — | xdb — | archetype A(+protected) |`
- **Exercise**：§5.1 soft-delete（delete/batch＋統一清單 all-tree＋restore 回收桶）／§5.2 審計同 txn／§5.3 RBAC（CRUD R_SUPER、getUserRoutes auth-only＋Casbin menu 過濾）／tree（parent_id self-ref、本刀首個樹型 entity）／**Casbin `v2='menu'` 可見性 enforce（§I.2 首 exercise）**。
- **首立機制**：`menu_routes_for_roles`（v2='menu' 過濾）／reparent 3+1 guard facade 自驗（⚠️o）／menu flat→tree 序列化（RouteMeta D2-D4）／動態路由模式（#7）。
- **N/A**：§5.6 熱 KV／§5.8 分頁 search（menu 用 tree 非分頁；009 已 exercise §5.8）／§5.9 xdb／§5.10 AES。

### 2.6 三端 wire shapes（rust ↔ base-web ↔ §I.2、§7.1 對齊）
- **★ id 兩域不同（⚠️r 逐欄忠實 typings、本刀關鍵）**：路由域 `Api.Route.MenuRoute.id`→**string**（`to_string()`、同 auth `userId`/`MenuRoute`）；管理域 `Api.SystemManage.Menu.id`（CommonRecord）→**number**（同 009 User.id）。同一 `sys_menu.id`(i64) 兩端點不同序列化。`parentId`（管理域）→number、`0`=頂層（rust `parent_id:Option<i64>` None）。
- **GET /route/getUserRoutes**（auth-only）→ `UserRoute{routes:MenuRoute[], home:string}`：Casbin `v2='menu'` 過濾使用者 DB-fresh roles 可見 route_name→組巢狀 `MenuRoute`（`id`string／`name`=route_name／`path`／`component`〔"layout.base$view.xxx"〕／`meta`{title=menuName i18n、i18nKey、icon/localIcon〔iconType〕、order、hideInMenu、keepAlive、constant、multiTab、href、activeMenu、query、roles?}／`children`）；`home`←使用者主要 role 的 `sys_role.home`（默 `'home'`）。**前端零過濾**（§I.2）。
- **GET /route/getConstantRoutes**（public）→ `MenuRoute[]`：`constant=true` 的 sys_menu（多半 `[]`；login/404/403 前端寫死、§I.2）。**plan 接地**：與「常數前端寫死」相容方式（回 `[]` 且 route store dynamic 分支仍保 local 常數 vs 鏡像）見 §11 ⑤。
- **GET /route/isRouteExist?routeName=** → `boolean`（addMenu 唯一性前驗）。
- **GET /systemManage/getMenuList/v2**（R_SUPER）→ `Menu[]`（**完整 active＋soft-deleted 樹**、D3；每節點 `Menu` 欄＋**`deleted` flag**〔rev3 ADAPT 加、見 §4.7〕；`id`number、`children` 巢狀）。**非 PageRes**（選單量小、tree-table）。
- **GET /systemManage/getMenuTree**（R_SUPER）→ 精簡樹（parent 選擇器；active only）。**GET /systemManage/getAllPages**（R_SUPER）→ `string[]`（page component key、來源見 D6）。
- **POST addMenu／updateMenu → null；DELETE deleteMenu{id}／batchDeleteMenu{ids} → null；POST restoreMenu{id} → null**（write payload＝Menu 子集、parentId number、id 寫端 `String|number→i64`、plan 對齊 §11 ①）。

### 2.7 消費者
- **直接**：admin 後台選單管理（樹列表/新增/改/reparent/刪/批刪/復原）。**全體使用者**：登入後側欄選單＝getUserRoutes Casbin 過濾結果（dynamic）。
- **下游**：波 2 Role 刀（getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋menu-auth-modal、**消費本刀 getMenuTree/getAllPages**）／波 3（policy governance、casbin_rule 治理欄）。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | scope 切法 | **一刀整包 Menu**（CRUD＋回收桶＋動態路由＋.env dynamic＋D1）；實作仍多 Workflow 單元（§12）（**user 拍**） | user 選整包匹配 roadmap「Menu 刀」；否決「拆兩刀（動態+D1／CRUD）」與「拆三刀」。單刀粗粒度風險由階段 2 generous 單元拆解＋逐單元 bump pin 抵消 |
| D2 | Role×Menu 邊界 | **getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋menu-auth-modal 留 Role 刀**（DESIGN §8.2、**user 拍**） | 4 端點住 /manage/role、與 Role CRUD 同頁；拆進本刀＝先做半個 role 頁、與 Role 刀職責重疊。動態選單＋可見性本身不需這 4 端點（靠既 seed 的 v2='menu' policy 已足） |
| D3 | 回收桶 UI＋getMenuList 語意 | **已刪除與未刪除同列於 /manage/menu 統一 tree-table、多一「已刪除」狀態欄**；`getMenuList/v2` 回 `find`（全列含 soft-deleted）+`deleted` flag；**`getDeletedMenus` 端點 drop**（統一清單取代、seeded policy 留作 unused）（**user 拍**） | 一個心智模型、就地 restore；getUserRoutes 仍 `find_active`（側欄永不含已刪、§3.7 活體於此覆蓋）。lint 允許未註冊的 seeded policy（非反向） |
| D4 | 刪「有子選單」父 | **有 active 子選單→拒刪 2222（`biz.menu.hasActiveChildren`）；要先處理子選單**（**user 拍**） | 每節點獨立軟刪/復原、active 樹（getUserRoutes）永無孤兒、復原語意單純。否決 cascade（復原語意複雜＋與 ⚠️o restore-reparent 交互多＋blast radius 大）。此 guard＝intra-entity ref 檢查→下沉 facade（⚠️o 同模式） |
| D5 | restore 孤兒 | **restore「父已刪」節點→re-parent 到頂層（parent_id=None）**、admin 再自行搬移（**我定、veto-able**） | ⚠️o「restore-skip／re-parent 留 handler orchestrate」；避免復原出孤兒；最小驚訝（頂層可見可搬） |
| D6 | getAllPages 來源 | **取 sys_menu 內 distinct `(route_name, component)`**（**我定、veto-able**） | demo 76 選單已涵蓋頁面宇宙；要加全新頁本就需前端 view＋seed、非本刀。簡潔、免另維護 page 清單。否決「另 seed page 清單」（維護負擔） |
| D7 | migration | **零 migration**（schema＋10 baseline＋66 demo＋menu-visibility policy＋13 endpoint policy＋button code 全 m001/m002/m004 已備、§2.2） | act-on-code 親驗全備；`Migrator::up delta == 0` |
| D8 | 選單可見性 enforce | **getUserRoutes 經 `menu_routes_for_roles`（Casbin `v2='menu'` 過濾 DB-fresh roles）→過濾 sys_menu→組樹；前端零過濾**（依 §I.2/⚠️p、§I.2 首兌現） | §I.2 明定 menu 走 Casbin enforce；鏡像既有 `buttons_for_roles`（v2='button'）形。D1「選單可見性」自動達成（非 super 不拿 admin 選單路由）、無額外前端碼 |
| D9 | reparent 3+1 guard | **`sys_menu::reparent` 回 slim `ReparentError{Db,TargetMissing,NotDirectory,WouldCycle,ProtectedFixed}`（facade 自驗、不依賴 AppError）、handler match→2222**（依 ⚠️o、§3.3） | ⚠️o intra-entity 純 ref 下沉 facade；3+1＝目標存在+active／目標目录型(menu_type==1)／非自身後代(防環)／protected 種子父固定。集中、繞不過、避層級倒置 |
| D10 | 動態路由模式切換 | **`.env VITE_AUTH_ROUTE_MODE` static→dynamic（BASE-WEB-ADAPT、#7）；★ 此 flip 為 base-web 單元【最後一步】**（getUserRoutes 後端先驗綠才翻）（依 #7、工程） | #7 拍 dynamic；翻後全 app 路由依賴 getUserRoutes（高 stakes、非 009 那種純 additive）→ de-risk：getUserRoutes 三角色測綠＋getConstantRoutes 就緒後才翻；store 已有 error→resetStore fallback |
| D11 | route_name 唯一 | **partial-unique catch、`DbErr::sql_err()→UniqueConstraintViolation→biz 2222`（`biz.menu.duplicateRouteName`）、不做 app pre-check**（依 ⚠️o、沿 009 pattern） | 沿 009 寫端 `map_write_err`；isRouteExist 為前端 UX 前驗、非授權後端唯一性保證（仍靠約束 catch、避 TOCTOU） |
| D12 | D1 前端 hasAuth gating | **menu 頁寫入鈕掛 `hasAuth('menu:add'/'menu:edit'/'menu:delete')`（button code 已 seed）；retroactive user(009)/system-settings(008) gating＝待 Phase 0 確認其 button code 有無 seed、有則一起、無則受零-migration 限制延後**（MODAL-WIRING (b)、工程） | D1 為 008/009 同家族 follow-up；menu 頁確定可做；user/settings 視 seed 狀況（不為 gating 加 migration） |

## 4. 元件設計（act-on-code、當前 lineage seam 名）

### 4.1 `facade/sys_menu.rs`（改：加多 fn、archetype A、entity:: 合法）
- **讀**：`list_active(conn)->Vec<Model>`（`find_active` 全 active，供 getUserRoutes/getMenuTree 組樹）／`list_all(conn)->Vec<Model>`（`find` 含 soft-deleted，供 getMenuList/v2 統一清單、D3）／`find_active_by_id`／`route_name_exists(conn,&str)->bool`（isRouteExist）／`distinct_pages(conn)->Vec<(route_name,component)>`（getAllPages、D6）。
- **寫**（經 `mutate_in_txn`、6 審計欄成對、同 txn op-log）：`create(conn,fields,operator,trace)`（INSERT op-log）／`update(conn,id,fields,operator,trace)->Result<Option<Model>,DbErr>`（含 reparent；UPDATE op-log）／`soft_delete(conn,id,operator,trace)`＋`batch`（SOFT_DELETE op-log）／`restore(conn,id,operator,trace)`（restore；re-parent 孤兒 D5、RESTORE op-log）。
- **★ reparent 3+1 guard（⚠️o、D9）**：`fn reparent_check(conn,id,new_parent)->Result<(),ReparentError>`（slim enum `{Db(DbErr),TargetMissing,NotDirectory,WouldCycle,ProtectedFixed}`、不依賴 AppError）；update/restore 內呼叫。
- **★ delete guard（D4、⚠️o）**：soft_delete 前查 `protected`（→`DeleteError::Protected`）＋ active children 存在（→`DeleteError::HasActiveChildren`）；slim enum、handler 映 2222。
- `build_*_active_model` 純測 seam。**lint**：entity:: 僅 facade。

### 4.2 `auth/enforce.rs`（改：加 menu_routes_for_roles、D8、§I.2）
- `menu_routes_for_roles(enforcer,&[role])->Vec<String>`（route_name set）：鏡像 `buttons_for_roles`、`get_filtered_policy(0,[role])` 濾 `v2=='menu'`→收 v1（route_name）union。`enforce_role_path_method`/`buttons_for_roles`/`enforce_mw`/`require_policy` 本體不動。

### 4.3 `handler/route.rs`（新；/route/* 家族）＋`handler/system_manage.rs`（改：加 menu 端點）
- **route.rs**（新 mod）：`get_user_routes(State,Extension<Claims>)->Res<UserRoute>`（DB-fresh roles→`menu_routes_for_roles`→`list_active` 過濾→flat→tree 序列化〔§4.5〕→`{routes,home}`、home 取 role.home）／`get_constant_routes()->Res<Vec<MenuRoute>>`（public、constant=true）／`is_route_exist(Query)->Res<bool>`。
- **system_manage.rs**（沿 009 檔加）：`get_menu_list_v2`（R_SUPER、`list_all`→tree＋deleted flag、D3）／`get_menu_tree`／`get_all_pages`／`add_menu`（route_name 23505→2222 D11）／`update_menu`（reparent ReparentError→2222 D9）／`delete_menu`／`batch_delete_menu`（DeleteError→2222 D4）／`restore_menu`（D5）。DTO inline camelCase、id 兩域序列化（§2.6）、零 path-root `entity::`。

### 4.4 `main.rs`（改：註冊 ~12 路由；復用 enforce 骨架、enforce.rs/require_policy 不動）
- `/route/getConstantRoutes`（**public**、不掛 enforce）／`/route/getUserRoutes`／`/route/isRouteExist`（**auth-only**、掛 `enforce_mw`、**不掛 require_policy**＝任何登入者、過濾在 handler 內）；`/systemManage/{getMenuList/v2,getMenuTree,getAllPages,addMenu,updateMenu,deleteMenu,batchDeleteMenu,restoreMenu}`（各掛 `enforce_mw`→`require_policy`、R_SUPER）。`mod handler::route;`。p-policy m002 已 seed→**零 seed migration**。

### 4.5 menu flat→tree 序列化（首立、RouteMeta D2-D4 carry-in）
- flat `Vec<Model>`（parent_id）→巢狀（getUserRoutes＝`MenuRoute`／getMenuList＝`Menu`）；序列化邊界處理：`icon_type`→icon vs localIcon（D2、icon_type==2＝local）／`multi_tab`／`href`（document 8 頁外開、D2）／`query`/`buttons` jsonb／`i18n_key`／`constant`／`order` 排序／`hide_in_menu`／`active_menu`／`keep_alive`；id 兩域（§2.6）。**plan 接地**：與前端 elegant transform component-key 對齊（§11 ②）／iframe props 內嵌復原評估（D2、現 href 外開、**本刀沿現狀、內嵌延後**）／`filter_routes` 遞迴化（D3、現 demo 全覆蓋兩層足、遞迴化登 backlog）。

### 4.6 `error.rs` 消費（沿 009、不改 blanket）
- route_name 23505→`biz.menu.duplicateRouteName`（寫端 `sql_err()` map、D11、沿 009 `map_write_err`）；ReparentError/DeleteError handler match→`biz.menu.{reparentTargetMissing,notDirectory,wouldCycle,protectedFixed,protectedNoDelete,hasActiveChildren}`（2222）；update/delete/restore 查無→`biz.menu.notFound`。blanket `From<DbErr>→Internal` 不動。

### 4.7 base-web wire＋frontend（D3/D10/D12、MODAL-WIRING (a)(b)）
- **`.env`**：`VITE_AUTH_ROUTE_MODE` static→dynamic（D10、**base-web 單元最後一步**）。
- **L3 WRAPPER**：`service/api/rev3-system-manage.ts`（沿 009 檔加、direct-path）：`fetchAddMenu`/`fetchUpdateMenu`/`fetchDeleteMenu`/`fetchBatchDeleteMenu`/`fetchRestoreMenu`（getMenuList/v2·getMenuTree·getAllPages·route.ts 既有可續用）。
- **L1/L2 ADAPT**：rev3 typings 加 menu write DTO＋`deleted` flag（declaration-merge、不改既有 `Menu`/`Api.Route`）。
- **L4 MODAL-WIRING (a)**：`views/manage/menu/index.vue` handleDelete/handleBatchDelete→真 fn＋**新增「已刪除」欄＋restore action**（D3）；`menu-operate-modal.vue` submit→addMenu/updateMenu／父選擇 getMenuTree／page 下拉 getAllPages／route_name isRouteExist 前驗（標 `rev3-inline MW(a)`）。
- **L4 MODAL-WIRING (b)**：menu 頁寫入鈕 `hasAuth('menu:add'/'menu:edit'/'menu:delete')`（D12；retroactive user/settings 視 seed）。
- **BASE-WEB-I18N-WIRING ★**：`backend.biz.menu.*`（duplicateRouteName/notFound/reparent*/protected*/hasActiveChildren、zh-cn 简体＋en-us）＋`app.d.ts` Schema（先 Schema 後 locale、⚠️aa (iii)、沿 009）。

### 4.8 `server/tests/endpoint_coverage_lint.rs`（改：bump AS_BUILT_ROUTES）
- 每註冊 menu 路由的單元**同 commit** bump（`[&str;11]`→`[&str;22]`、**+11**＝3 `/route/*`〔getConstantRoutes/getUserRoutes/isRouteExist〕＋8 `/systemManage/*Menu*`〔getMenuList/v2·getMenuTree·getAllPages·addMenu·updateMenu·deleteMenu·batchDeleteMenu·restoreMenu〕；registered==as-built＋policy-governed⊆seed、⚠️x/S9）。**注意**：`/route/getConstantRoutes`/`getUserRoutes`/`isRouteExist` 為 public/auth-only 非 policy-governed→入 AS_BUILT 但 Assertion A 不要求其 seed（分類 public/auth-only、沿 008 三分類）。

## 5. wire / 碼 / INET / i18n
- **wire 端點 ~12**（§I.1 兩端俱在、§7.1 對齊 typings、`/api` strip §7.4）；**id 兩域：MenuRoute.id=string／Menu.id=number（⚠️r、本刀關鍵 type-lie 消解點）**；parentId=number（0=頂層）。
- 碼：成功→`0000`；biz（duplicateRouteName/notFound/reparent*/protected*/hasActiveChildren）→`2222`、wire `msg`＝`biz.menu.<condition>`（locale `backend.biz.menu.*`、⚠️y/⚠️aa）；policy deny→`5003`/403。
- **INET**：add/update/delete/restore op-log `operator_ip` 真 INET round-trip（沿 007/008/009 threading；menu 寫＝Insert/Update/SoftDelete/**Restore**〔Restore 首個 consumer〕op-log）。

## 6. 範圍邊界

**IN**：facade `sys_menu`（list_active/list_all/find_active_by_id/route_name_exists/distinct_pages/create/update〔reparent guard〕/soft_delete〔protected+has-children guard〕/batch/restore〔re-parent 孤兒〕）＋`enforce::menu_routes_for_roles`（v2='menu'）／handler `/route/*`（getUserRoutes Casbin 過濾+getConstantRoutes+isRouteExist）＋`/systemManage/*Menu*`（CRUD+回收桶）／menu flat→tree 序列化（RouteMeta D2-D4 核心欄）／reparent ReparentError＋delete DeleteError→2222（⚠️o）／route_name 23505→2222（沿 009）／main ~12 路由分層＋`endpoint_coverage_lint` bump／**`.env` static→dynamic**／base-web rev3 wrapper＋ADAPT deleted flag＋MODAL-WIRING (a)〔mgmt 接線+已刪除欄+restore〕(b)〔menu hasAuth gating〕＋`backend.biz.menu.*` i18n／純測（tree build/reparent guard/delete guard/序列化/wire）＋live（getUserRoutes 三角色過濾、CRUD round-trip、reparent/delete guard、23505、op-log INET）＋CDP 全鏈（三角色側欄差異、mgmt CRUD 真發+已刪除列+restore、D1 非 super 無寫入鈕）。

**OUT（遞延）**：Role×Menu 授權（getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋menu-auth-modal＝**Role 刀**、D2／§8.6）／iframe props 內嵌復原（D2、現 href 外開沿現狀）／`filter_routes` 遞迴化（D3、登 backlog）／`pg_trgm`/menu search（menu 用 tree、無）／retroactive user/settings hasAuth gating（D12、視 button code seed）／casbin_rule 治理欄（波 3）。

**MOOT（lineage already-done、不重做）**：`sys_menu` schema＋10 baseline＋66 demo＋partial-unique＋menu-visibility policy（17+66）＋13 endpoint policy＋button code（m001/m002/m004）／`require_policy`·op-log threading·envelope·`endpoint_coverage_lint`·`sql_err`→2222·`mutate_in_txn`·`soft_delete` trait·`buttons_for_roles`（008/009/004-006）／route store dynamic 路徑·service/api route.ts·menu mgmt 頁 mock·hasAuth hook·Api.Route/Menu typings（base-web 既有）。

## 7. enforce/track pattern 留痕（`/speckit-plan` Constitution Check 對齊用）
- **無 constitution amendment**：軌道 RUSTAPI-SOURCE-ISOLATION／BASE-WEB-ADAPT（`.env` dynamic #7＋typings ADAPT deleted flag）／BASE-WEB-WRAPPER（rev3-system-manage.ts menu fn）／**MODAL-WIRING (a)(b) 既授**（§III.2、⚠️i、D12）／BASE-WEB-I18N-WIRING ★（⚠️aa、`backend.biz.menu.*`）皆既授。
- **§I.2 menu Casbin enforce 首兌現**：getUserRoutes `menu_routes_for_roles`（v2='menu'、DB-fresh roles）；前端零過濾。**⚠️p**：demo 全 seed R_SUPER、隱藏機制不啟用（本刀沿）。
- **⚠️o reparent/delete guard 首個主消費者**：intra-entity 純 ref→facade slim error enum→handler 2222；跨 facade/restore-skip 留 handler（restore re-parent D5）。
- 授權 subject＝DB-fresh roles（§3.4、復用 require_policy/enforce_mw、本體不動）；23505→2222 沿 009 ⚠️o。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）
- **FR-001** 登入後側欄選單＝`getUserRoutes` 依 DB-fresh roles 經 Casbin `v2='menu'` 過濾（前端零過濾、§I.2）；非授權角色不獲對應選單路由。**FR-002** `getConstantRoutes` 回常數選單（public）；login/404/403 前端寫死不動。
- **FR-003** R_SUPER 可於統一清單瀏覽全部選單（active＋soft-deleted、「已刪除」狀態欄；tree）。**FR-004** R_SUPER 可新增選單（route_name 唯一、重複→2222；INSERT op-log 真 INET）。**FR-005** R_SUPER 可修改選單（含 reparent：目標存在+active／目录型／非自身後代／protected 父固定，違反→2222；UPDATE op-log）。
- **FR-006** R_SUPER 可單筆/批次 soft-delete（**protected 拒刪／有 active 子拒刪→2222**、無 partial）；可 restore（父已刪→re-parent 頂層）；皆 op-log。**FR-007** 所有 `/systemManage/*Menu*` `require_policy` R_SUPER；`/route/getUserRoutes` auth-only（過濾在 handler）；非授權→5003/403。
- **FR-008** `.env` dynamic：app 路由 DB-driven；getUserRoutes 失敗→既有 resetStore fallback（不白屏）。**FR-009** menu 寫入鈕 hasAuth gating（menu:add/edit/delete）。**FR-010** wire id 兩域忠實 typings（MenuRoute string/Menu number、⚠️r）、biz msg 載 i18n key（⚠️y）、envelope 不破 003。**FR-011** base-web mgmt 頁 stub 接真 fn（**真發 request**）＋統一已刪除欄＋restore。**FR-012** 零 migration/schema/entity、無新 crate、enforce_mw/require_policy/既有 base-web 檔（除授權 inline/.env/新檔）零回歸；user/role/settings/login/getUserInfo/health 不變。
- **SC**：SC-001 三角色 getUserRoutes 過濾差異正確（super 全/admin 子集/common 最小、live+CDP）。SC-002 sel單 CRUD round-trip 正確（add/update/delete/restore 反映、live+CDP）。SC-003 reparent 3+1 guard 四情境擋（live）。SC-004 delete protected/有子拒（live）。SC-005 route_name dup→2222（live）。SC-006 非授權→5003/403（live+CDP）。SC-007 統一清單已刪除列＋restore（CDP）。SC-008 .env dynamic 後 app 正常、三角色側欄差異（CDP）。SC-009 三守恆全綠（含 bump 後 lint）。SC-010 零回歸（FR-012）。SC-011 wire id 兩域零型謊（CDP+typecheck）。

## 9. C-V 驗收（草案、live 一律 `--test-threads=1` serial+DATABASE_URL；rust 容器內 `docker exec`、改 .rs 先 force-touch）
- **C-V-1** 純測：flat→tree 建樹／reparent guard 四情境／delete guard（protected/has-children）／menu→route 序列化（icon_type/href/multiTab/query）／id 兩域 wire（2^53 guard）。
- **C-V-2** `build_*_active_model` 純測（6 審計欄成對）。
- **C-V-3** live getUserRoutes：Super/Admin/User 三角色經 Casbin v2='menu' 過濾差異（super 含 manage_menu、admin 不含、common 僅 home/function）；home 取 role.home → SC-001。
- **C-V-4** live menu CRUD round-trip：add（route_name 唯一、INSERT op-log INET）→update（reparent 合法）→soft_delete→restore；dup route_name→2222 → SC-002/005。
- **C-V-5** live reparent guard：目標不存在/非目录/成環/protected 父→各 2222 → SC-003；delete protected/有 active 子→2222 → SC-004。
- **C-V-6** live getMenuList/v2 統一清單（active＋deleted＋deleted flag）／getMenuTree／getAllPages → SC-007。
- **C-V-7** live 非授權（Admin/User CRUD→403）→ SC-006。
- **C-V-8** `endpoint_coverage_lint`（bump）＋`entity_access_lint` → SC-009。
- **C-V-9** base-web typecheck（rev3 wrapper＋deleted flag ADAPT 對齊）→ SC-011。
- **C-V-10** CDP 經 front-nginx：★ **.env dynamic 後**三角色登入側欄差異（非 super 不見 admin 選單）／Super→/manage/menu→新增/改/reparent/刪/restore 真發 request＋已刪除列＋toast `$t`／非 super 無 menu 寫入鈕（hasAuth）→ SC-001/002/006/007/008。
- **C-V-11** 零回歸（/health、login/getUserInfo/008/009 不變、`entity_access_lint`、diff 零 schema/entity、既有 base-web 檔除授權 inline/.env/新檔不動、**user/role 頁仍正常**）→ SC-010。
- **C-V-12** prod image build（無新 crate、確認新 handler/facade/enforce/lint 編入）→ build 面。

## 10. Files（當前 lineage、BUILD vs ALREADY）
**BUILD（改/新）**：`rust-api/server/src/model/facade/sys_menu.rs`(改：多 fn＋reparent/delete guard)／`auth/enforce.rs`(改：menu_routes_for_roles)／`server/src/handler/route.rs`(新)＋`handler/mod.rs`(加 mod)／`handler/system_manage.rs`(改：menu 端點)／`main.rs`(~12 路由＋分層＋mod)／`error.rs`(menu biz 映射、沿 009 pattern)／`server/tests/endpoint_coverage_lint.rs`(bump)／base-web `src/.env`(VITE_AUTH_ROUTE_MODE dynamic)＋`src/service/api/rev3-system-manage.ts`(加 menu write fn)＋rev3 typings(menu write DTO＋deleted flag ADAPT)＋`src/views/manage/menu/{index.vue, modules/menu-operate-modal.vue}`(MW (a)(b)＋已刪除欄＋restore)＋`src/locales/langs/{zh-cn,en-us}.ts`＋`src/typings/app.d.ts`(`backend.biz.menu.*` Schema+locale)。
**ALREADY（不動）**：`entity/src/sys_menu.rs`／schema＋10 baseline＋66 demo＋partial-unique＋menu-visibility policy＋13 endpoint policy＋button code（m001/m002/m004）／`require_policy`·`enforce_mw`·`buttons_for_roles`·op-log threading·`PageRes`·envelope·`endpoint_coverage_lint`·`sql_err`→2222·`mutate_in_txn`·`soft_delete` trait（004-009）／base-web route store 雙路徑·service/api/route.ts·menu mgmt 頁 mock·hasAuth hook·Api.Route/Menu typings／login/getUserInfo/user/role/settings 端點（006/008/009）。

## 11. forward-compat / 下游 + plan-phase 接地清單
- **波 2 後續**：Role 刀（getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋menu-auth-modal、消費本刀 getMenuTree/getAllPages、D2）。**波 3**：policy governance／casbin_rule 治理欄／即時 token 撤銷。
- **plan-phase 須 act-on-code 接地**（不臆測）：① write payload id 型（`String` vs `number`→i64、parentId 0→None）逐欄 grep（menu-operate-modal submit ↔ rust DTO）／② menu→route 序列化與前端 elegant transform component-key 對齊（"layout.base$view.xxx"）／③ **`menu_routes_for_roles` 構式**（casbin `get_filtered_policy` 濾 v2='menu'、鏡像 buttons_for_roles file:line）／④ reparent 3+1 guard 確切 facade error enum 形＋handler match（⚠️o、§3.3）／⑤ **getConstantRoutes ↔ §I.2「常數前端寫死」相容**（route store dynamic 分支 initConstantRoute 回 [] 行為、login/404/403 是否仍 local；可能小 rev3-inline 調 store）／⑥ `.env` dynamic flip 對既有 008/009 頁的回歸（manage 選單在 dynamic 下對非 super 隱藏＝D1 兌現、確認 user/settings 頁本身不回歸）／⑦ `AuditOperation::Restore` 首個 op-log consumer threading／⑧ `endpoint_coverage_lint` public/auth-only/policy-governed 三分類對 `/route/*`（Assertion A 不要求 public/auth-only seed）／⑨ D12 user/settings button code seed 親驗（決定 retroactive gating 範圍）／⑩ getUserRoutes `home` 解析（多 role 時取哪個 `sys_role.home`：第一個有 home 者 vs 主要 role vs 默 'home'；對齊前端 `home` 消費 `handleUpdateRootRouteRedirect`）。

## 12. Workflow 單元分解（預想、階段 2 依實際相依定；rust 全程 serial）
- **U1 動態路由讀**：`enforce::menu_routes_for_roles`＋`sys_menu::list_active`＋menu→tree 序列化＋handler/route.rs（getUserRoutes/getConstantRoutes/isRouteExist）＋main `/route/*`＋lint bump。純測：tree build／序列化／id 兩域。live：三角色 getUserRoutes 過濾（C-V-3）。
- **U2 選單寫 CRUD**：`sys_menu::create/update`＋reparent ReparentError(⚠️o)＋route_name 23505 map＋op-log Insert/Update＋handler add_menu/update_menu＋getMenuTree/getAllPages＋main＋lint bump。live：CRUD round-trip＋reparent guard＋dup（C-V-4/5）。
- **U3 刪除＋回收桶**：`sys_menu::soft_delete`（protected+has-children DeleteError）＋batch＋`restore`（re-parent 孤兒、RESTORE op-log）＋`list_all`（統一清單）＋handler delete/batch/restore/getMenuList(v2)＋main＋lint bump。live：delete guard＋restore＋統一清單（C-V-5/6）。
- **U4 base-web**：rev3 wrapper＋ADAPT deleted flag＋mgmt 頁接線(MW a：CRUD+已刪除欄+restore)＋hasAuth gating(MW b)＋`backend.biz.menu.*` i18n＋**最後翻 `.env` dynamic**＋CDP（三角色側欄+CRUD 真發+restore）。（可能再拆 U4a 動態消費/.env／U4b mgmt 頁接線。）
> rust 全程 serial（共用 target）；每單元邊界主線復核＋`git show --stat HEAD`＋load-bearing 容器內自驗＋bump submodule pin（S9 逐單元）；base-web commit `--no-verify`；**★ `.env` dynamic flip 為最後步（getUserRoutes 先驗綠）**；★ 絕不 push/merge（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
