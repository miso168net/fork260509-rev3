# Phase 0 Research: Button-Endpoint 授權治理（三維 RBAC runtime 編輯）

> 接地自 pin rust-api `2ad2029` / base-web `0adfd12d`（2-agent 平行 act-on-code grounding、2026-06-22）。**本刀零 migration、零新 crate**——皆讀寫既有 schema（`casbin_rule` 三維 ⇄ `sys_casbin_policy_archive`）＋既有 Redis pub-sub（015 建）。

## ★ 接地關鍵發現（決定本刀規模與正確性）

1. **casbin_rule 三維結構**（`m002:96-169`、72 筆）：menu（v2='menu'、v1=route_name、17 筆、4 protected）／button（v2='button'、v1=button_code、16 筆、**0 protected**）／**endpoint（v2=HTTP method、v1=path、39 筆、15 protected）**。endpoint 是 require_policy enforce 用的真實列（casbin `r=sub,obj,act`=(role,path,method)）。
2. **★★ endpoint 編碼正確性（最高優先）**：endpoint 編輯**必須動真實 (v0=role, v1=path, v2=method) 列**（require_policy enforce 查的就是這些）。**不可**另用 v2='endpoint'/v1='path:method' 編碼——那會建出不驅動 enforce 的平行列＝功能假性。因 v2=method 會變、**`set_role_dimension`（固定-v2 模型）套不上** → 需新 `set_role_endpoints`（(path,method) 雙鍵 diff）。
3. **6 編輯端點全 m002 已 seed**（`m002:148-153`、全 protected=true、R_SUPER）：getAllButtons/getRoleButton/updateRoleButton/getAllEndpoints/getRoleEndpoints/updateRoleEndpoints。**route 未註冊、handler 未實作** → 本刀只【註冊＋實作＋bump AS_BUILT 37→43】。**零 migration**。
4. **15 protected endpoint 涵蓋恢復路徑**（`getRole/updateRoleEndpoints`、`getRole/updateRoleMenu`、`getAllButtons/getRoleButton/updateRoleButton`、`getArchivedPolicies/restorePolicy`、`getSystemSettings/updateSystemSetting`、`getDeletedMenus/restoreMenu`、`updateUserSessionPolicy`）→ set_role_endpoints 接 protected-reject＝**無硬鎖出守門**。
5. **button JSON registry 源**：`sys_menu.buttons:Option<Json>`（`entity/src/sys_menu.rs:31`）、seed 形 `[{"code":"user:add","desc":"新增用户"},…]`（`m002:209-240`）。getAllButtons 自所有 menu.buttons 萃取 `{code, label:=desc}` 字典序。
6. **治理 helper 全維度無關、可復用**（015）：`insert_archived(txn, rows:&[casbin_rule::Model], archived_by, reason)`（`sys_casbin_policy_archive.rs:32-59`）／`mutate_in_txn`（`audit.rs:84-97`）／`reload_and_publish(&state)`（`system_manage.rs:699-712`）／`spawn_policy_watcher`（main.rs、015）／protected-reject（set_role_dimension 內）。archive list/restore 按 v2 filter（維度無關）。

## D1 — button 寫側（撿現成、復用 011＋015）

**接地**：`set_role_dimension<C:TransactionTrait>(conn, role_code, dimension, desired_objs:&[String], meta, role_id) -> Result<SetDimensionOutcome{changed}, SetDimensionError{Db,Rejected(Vec<String>)}>`（`sys_casbin_rule.rs:47-170`、dimension-agnostic）。`buttons_for_roles(enforcer, roles)`（`enforce.rs:132-146`、讀 v2='button' 的 v1 去重）。getUserInfo（`auth.rs:441-467`）回 UserInfo{…, buttons:Vec<String>}。

**Decision**：
- `getAllButtons` → 新 `all_buttons(db)`（讀全 active sys_menu 的 buttons JSON、解析 `{code,desc}`、彙整 `Vec<Button{code,label}>` 字典序去重）；handler 回 `Vec<Button>`。
- `getRoleButton` → 新 `button_codes_for_role(enforcer, &role.code)`（鏡像 buttons_for_roles 單角色）；handler Query(RoleIdQuery)→role.code→codes→`Vec<String>`。
- `updateRoleButton` → handler Json{role_id, button_codes:Vec<String>}→`set_role_dimension(&db, &role.code, "button", &button_codes, meta, role_id)`→Ok(Applied)→`reload_and_publish`；Rejected（button 0 protected、實務不觸）→2222；Db→5000。**archive/回收桶免費繼承**（archive_reason 沿 "role_dimension_revoke"、回收桶維度由 v2='button' 推導）。
**Rationale**：button 結構同 menu（固定 v2、diff v1 集）→ set_role_dimension 零改直接套；015 治理島維度無關。
**Alternatives**：button registry 改 DB-union（distinct v2='button' v1）——漏「定義了但無人授」之按鈕、且 revoke 後消失；棄（用 sys_menu.buttons 權威源）。

## D2 — endpoint 寫側（新 `set_role_endpoints`、(path,method) 雙鍵 diff）

**接地**：endpoint policy=(v0=role, v1=path, v2=method)（`m002:96-169`）。set_role_dimension 6-step（read-current→diff→protected-reject→revoke〔archive-move〕→grant→op-log）為鏡像範式。`require_policy(path,method)`（`enforce.rs`、enforce 查 (role,path,method)）。

**Decision**：新 `set_role_endpoints<C:TransactionTrait>(conn, role_code, desired:&[(String,String)]/*（path,method）*/, meta, role_id) -> Result<SetEndpointsOutcome{changed}, SetEndpointsError{Db, Rejected(Vec<(String,String)>)}>`，於單一 `mutate_in_txn`：
- (a) read current＝`casbin_rule WHERE ptype='p' AND v0=role_code AND v2 IN (<HTTP methods 白名單>)`（endpoint 列辨識＝v2∈{GET,POST,PUT,DELETE,PATCH}）。
- (b) diff：current 的 (v1,v2) 集 vs desired (path,method) 集 → to_revoke／to_grant 配對。
- (c) protected-reject：to_revoke 含 protected=true 列→`Rejected(被擋 (path,method))`、零變更（任何寫之前）。
- (d) revoke：to_revoke 完整列→`insert_archived(&txn, rows, Some(operator.id), "role_endpoint_revoke")`→DELETE（同 txn 原子）。
- (e) grant：逐 (path,method) insert `casbin_rule ActiveModel{ptype:'p',v0:role,v1:path,v2:method,v3-5:'',protected:false,created_at:now,created_by}`。
- (f) op-log：changed 時 emit `AuditEvent{Update, entity_table:"casbin_rule", entity_id:role_id, before/after=(path,method) 集 JSON}`。
- handler `updateRoleEndpoints`：Json{role_id, endpoints:Vec<Endpoint>}→set_role_endpoints→Ok(Applied〔含空-diff〕)→`reload_and_publish`；Rejected→2222 `biz.role.endpointProtected`（帶被擋 (path,method)、§3.6 menuProtected 訊息泛化 fold-in）；Db→5000。
**Rationale**：endpoint 雙鍵（path,method）不套固定-v2 模型；新 facade 僅 diff 改雙鍵、治理 helper 全復用 015（archive-move/protected-reject/同 txn 審計/gate）→ §4.2 invariants 維度無關沿用。protected-reject＝鎖出守門（15 protected 涵蓋恢復路徑）。
**Alternatives**：v2='endpoint'/v1='path:method' 單鍵編碼（套 set_role_dimension）——建出不驅動 enforce 的平行列、功能假性、棄（接地關鍵 #2）。泛化 `set_role_policies(filter, desired_rows)`——過度抽象、改動 011 set_role_dimension 風險、棄（dedicated facade 最小觸碰）。

## D3 — endpoint 讀端 registry + 回收桶三維 + route/lint

**接地**：getRoleMenu（`system_manage.rs:1102-1125`、in-memory enforce 讀 route_names）為讀端鏡像。AS_BUILT_ROUTES `[&str;37]`（`endpoint_coverage_lint.rs:87`）+ Assertion A（policy-governed ⊆ migration seed glob）+ Assertion B（main.rs registered==AS_BUILT）。archive list（`sys_casbin_policy_archive.rs`、apply_if v2 filter）。

**Decision**：
- `getRoleEndpoints` → 新 `endpoint_pairs_for_role(enforcer, &role.code)`（讀該 role 的 (v1,v2) where v2∈methods）；handler 回 `Vec<Endpoint{path,method}>`。
- `getAllEndpoints` registry → **prod const `ALL_ENDPOINT_POLICIES:&[(&str,&str)]`**（列全部可授權 (path,method)、含本刀 6 個；置 `enforce.rs` 或 facade）；handler map→`Vec<Endpoint{path,method,label?}>`。**endpoint_coverage_lint 加 assertion**：`ALL_ENDPOINT_POLICIES` ⊇ main.rs registered policy-governed endpoint（防漂移、單一事實源精神）。
- **回收桶三維**：archive list `dimension` 回應**由 v2 推導**（`match v2 {"menu"|"button"=>原值, _=>"endpoint"}`）；`?dimension=endpoint` filter→`v2 IN (<HTTP methods>)`（list facade endpoint 特例）。**不改 archive_reason**（不破 015 測試、拍板 #3）。
- main.rs：新 route group（或併 roles group）註冊 6 route（require_policy、enforce_mw 兩層、m002 seed）；`AS_BUILT_ROUTES` 37→43（+6 path）。
**Rationale**：const registry 完整穩定（revoke 後不消失、優於 DB-union）；lint 防漂移補 const 維護缺口；v2-推導維度＝零 churn 不破 015。
**Alternatives**：getAllEndpoints DB-union（distinct v2∈methods 的 (v1,v2)）——revoke R_SUPER 非保護端點後該端點自 registry 消失、不可再授；棄。archive_reason 帶維度（§3.19 原案）——改 set_role_dimension 簽名＋破 015 archive_reason 斷言；棄（v2-推導更乾淨）。

## D4 — base-web 三維編輯 UI（MODAL-WIRING (c)）

**接地**：button-auth-modal.vue（mock：getAllButtons/getChecks/handleSubmit 全假）vs menu-auth-modal.vue（真：fetchGetRoleMenu/fetchUpdateRoleMenu+watch visible+NTree、`role/modules/`）。role-operate-drawer.vue（useBoolean+footer 鈕+modal 掛載、`:38-39/:129-134`，已有 menuAuth/buttonAuth 兩鈕）。rev3-system-manage.ts（8 role wrapper、pruneNullParams `:280-293`、String(id)、request<T>）。rev3-system-manage.d.ts（declaration-merge 加法）。app.d.ts I18n.Schema page.manage.role（`:744-767`、有 menuAuth/buttonAuth）+ locales（zh-cn `:534-549`）。

**Decision**：
- **typings**（rev3-system-manage.d.ts、rev3-inline）：`Button{code:string, label:string}`／`Endpoint{path:string, method:string, label?:string}`／`RoleButtonUpdate{roleId:number, buttonCodes:string[]}`／`RoleEndpointsUpdate{roleId:number, endpoints:Endpoint[]}`。
- **service**（rev3-system-manage.ts、WRAPPER 6 fn）：fetchGetAllButtons()→`Button[]`／fetchGetRoleButton(roleId)→`string[]`／fetchUpdateRoleButton(roleId,buttonCodes)→`null`／fetchGetAllEndpoints()→`Endpoint[]`／fetchGetRoleEndpoints(roleId)→`Endpoint[]`／fetchUpdateRoleEndpoints(roleId,endpoints)→`null`（roleId 維 number ⚠️r、無 String(id) 因非單 body-id）。
- **button-auth-modal un-mock**（鏡像 menu-auth-modal）：watch visible→init→fetchGetAllButtons+fetchGetRoleButton→NTree checkable（key=code）→handleSubmit fetchUpdateRoleButton→reload。
- **endpoint-auth-modal 新建**（MODAL-WIRING (c)、鏡像 button-auth）：fetchGetAllEndpoints（registry）+fetchGetRoleEndpoints（已授權）→樹狀/列表顯 (path,method)〔可按 path 群組〕→hard-replace fetchUpdateRoleEndpoints。
- **role-operate-drawer**：加第三 useBoolean+`<NButton @click=openEndpointAuthModal>{{$t('page.manage.role.endpointAuth')}}</NButton>`+`<EndpointAuthModal>`。
- **i18n**：app.d.ts Schema page.manage.role 加 endpointAuth＋（modal 標籤）；zh-cn/en-us locale 同；endpoint protected 業務錯誤→`backend.biz.role.endpointProtected`（BASE-WEB-I18N-WIRING (ii)/(iii)）。先 Schema 後 locale。
**Rationale**：嚴格鏡像既有（MODAL-WIRING (c) 明文授權「角色×權限維度編輯」）；un-mock 接真治理。
**Risk（R）**：① i18n 改後 restart base-web 才能 CDP 驗（vite locale cache、016 memory）；② NTree key（button=code string／endpoint=path+method 合成 key）；③ vite 熱載新 service fn（views 直路徑 import）；④ components.d.ts auto-gen（新 naive-ui 元件首用、§4.1）。

## D5 — typings 收斂 fold-in（最低優先、可拆）

**接地**：roleDesc（`system-manage.d.ts:17`、`roleDesc:string` non-null）vs rust `RoleListItem.role_desc:Option<String>`（後端回 null）；User nickName/userPhone/userEmail（`:46/48/50`、non-null）vs rust Option。declaration-merge 加法、**不能覆寫既有欄型**→須 Omit+intersection rev3-owned 讀型（同 UserListItemRev3 範式）。**§3.13 Menu.buttons 接地證實已對齊（`buttons?:MenuButton[]|null` vs rust Option<Json>）＝no-op、不做**。

**Decision**：rev3-system-manage.d.ts 加 `RoleListItemRev3 = Omit<Role,'roleDesc'>&{roleDesc:string|null}`；User 三欄擴 `UserListItemRev3`（已存在 for sessionPolicy）或新讀型；service getRoleList/getUserList 回型改用 rev3 讀型。**列最低優先單元（D5）、可拆為獨立 typings-收斂刀**（讀端型謊、runtime 已容忍 null）。
**Rationale**：消 wire↔typing type-lie（§3.12/§3.14）；user opt-in fold。
**Alternatives**：改 frozen system-manage.d.ts roleDesc→string|null——違 §III frozen 紀律；棄。不做——type-lie 殘留（現狀、低危）；列可拆選項。

## D6 — 零回歸 + 2-instance + lints + CDP

**接地**：015 2-instance（rust-api-2 :31082、profiles:[multi]）已備。entity_access_lint（facade 豁免、handler 零 path-root entity::）。endpoint_coverage_lint（AS_BUILT、Assertion A/B）。role_menu_loop/archive_restore live（零回歸基準）。

**Decision**：
- 零回歸：既有 menu 維度（011 role_menu_loop／015 archive_restore）+button/endpoint 新測全綠；archive_reason "role_dimension_revoke"（menu/button）/"role_endpoint_revoke"（endpoint）並存、回收桶 v2-推導不破基線。
- 2-instance（C-V）：副本 A updateRoleButton/Endpoints→psql 證 casbin_rule 改＋archive→副本 B enforce 依最新（getUserInfo buttons／require_policy endpoint）收斂；CLIENT KILL pubsub→重訂閱韌性。
- lints：新 facade 在 model/facade/（entity_access 豁免）；AS_BUILT 37→43；registry 防漂移 assertion。
- CDP：role drawer 三 modal（menu/button/endpoint）真打＋三維編輯閉環（★ 先 restart base-web 驗 i18n）。
**Risk（R）**：op-log/archive teardown 清理（trace 隔離）；endpoint live 含鎖出（撤 protected→Rejected）；新 endpoint cargo test bare-filter 偽綠坑（用 `--test <name>`／in-crate `-- --ignored --test-threads=1`、§8.2）。

## 收掉的 plan-level opens（非 user 拍板）
- endpoint registry＝prod const `ALL_ENDPOINT_POLICIES`＋lint 防漂移（非 DB-union）——工程決定。
- button registry＝sys_menu.buttons JSON 萃取（非 casbin union）——工程決定。
- endpoint 列辨識＝v2∈HTTP method 白名單（非 NOT IN menu/button）——工程決定（穩健）。
- archive_reason endpoint＝"role_endpoint_revoke"（diagnostic、回收桶不靠它、v2-推導）——非拍板。
- typings 收斂＝rev3-owned Omit+intersection、最低優先可拆——工程決定（user opt-in fold）。
- **user 拍板（已決、brainstorm）**：scope C（button+endpoint 完整編輯）／un-protect 不做（延續 015 A、endpoint 15 protected 不可 UI 撤）／回收桶 v2-推導／endpoint 鎖出靠既有 15 protected seed（零 migration）。
