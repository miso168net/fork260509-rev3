# 011-role-management — Phase 0 Brainstorm（spec-design）

> **波 2 第三刀＝Role**（資料島群 User→Menu→**Role**）。本檔＝階段 0 brainstorm 產出，作為階段 1 `/speckit-specify` 的 input。
> act-on-code 接地源＝當前 lineage（rust-api `c377444`／base-web `a59c2738`、皆 010 收刀後）親 grep＋psql ground-truth；rev2 設計借鏡不照拷（§I.5／RUSTAPI-SOURCE-ISOLATION：design 繼承、code 全新寫、不 grep rev1/rev2 source）。
> 3 拍板已於 brainstorm 對話定（user 親決）：**D1 scope＝menu-auth only**／**D2 治理姿態（★ B1 校正後）＝DB-first 合規寫入**〔直寫 casbin_rule＋與審計同交易原子＋寫後 load_policy reload；②受保護移除→整批拒〕、僅 archive/restore/PolicyMutated-優化/publish-watcher 治理機留波3／**D3 delete guards＝seeded+in-use+self**。
>
> **★ B1 校正（2026-06-19 /speckit-analyze 抓出、user 拍板 option 1）**：本檔 §3 D2/D4・§4.2・§7 Q9 原描述「經 enforcer MgmtApi `remove_filtered_policy`+`add_policies` auto-persist、與 op-log 非原子、protected 不強制」**違反 constitution §I.7 §4.2 ①DB-first／④原子審計／⑤reload 凍結不變式**（rev2-034 被推翻的舊路徑、§V.3 MAJOR-protected）。已改 **DB-first `set_role_dimension`**：diff(current vs desired)→revoke(DELETE)+grant(INSERT) **直寫 `casbin_rule`**（經 11-col governance entity）於 `mutate_in_txn` **同交易**寫 op-log（原子）、②讀 `protected` 拒移除、寫後 `enforcer.write().await.load_policy()` 全量重載。權威 DB-first 設計見 spec/plan/research/data-model/contracts（已 regen）；本檔下方 §3 D2/D4・§4.2・§7 Q9 之 MgmtApi 字樣**以此校正為準**（史料、不逐段重寫）。

---

## 1. 目標一句話

把 `/manage/role` 從 mock 接到真 rust-api：**角色 CRUD**（list/新增/修改/刪除/批次刪）＋**Role×Menu 授權**（menu-auth-modal：getRoleMenu/updateRoleMenu，全專案首次 **casbin policy WRITE**，與 010 getUserRoutes 形成 v2='menu' policy 的讀/寫閉環）＋**Role home**（getRoleHome/updateRoleHome、sys_role.home entity 寫）＋前端 hasAuth gating（`role:*`）。**零 migration**；button-auth/endpoint-auth 留波 3。

## 2. Context（探索蒐集、act-on-code 親驗）

### 2.1 前代 rev2 013/016/018（CRUD）／021（menu-auth modal）參照（借設計、§I.5／不照拷）
rev2 把 user+role 揉一 feature（016）、權限 modal 散 021-024；rev3 拆刀紀律（DESIGN §8.6 對照表）→ Role 獨立一刀。設計繼承「role 頁＝CRUD＋授權 modal 系列」，code 全新寫。

### 2.2 ★ 當前 lineage 已落地（不重做、MOOT）
- **entity**（002 baseline、`entity` crate）：`sys_role`（12 欄：id/code/name/role_desc/home/status/deleted_at/deleted_by/created_at/created_by/updated_at/updated_by；**無 protected 欄**）／`sys_user_role`（複合 PK user_id+role_id、無 audit 欄）／`casbin_rule`（8 adapter 基底 ptype/v0-v5＋3 治理欄 protected/created_at/created_by；**adapter Model 只見 8 基底、治理欄隱形**）。
- **facade**：`sys_role::find_active`／`sys_role::home_of_roles`（010 建）；`sys_user_role::roles_of_user`／`roles_for_users`／`replace_roles_in_txn`（006/009 建）。
- **seed（m002 ground-truth psql）**：3 角色（1 R_SUPER 超级管理员／2 R_ADMIN 管理员／3 R_USER_COMMON 普通用户，皆 home='home'、status=1）；sys_user_role：1→1、2→2、3→3、12-21→3（R_USER_COMMON 11 users、R_SUPER/R_ADMIN 各 1 user → **3 角色皆 in-use**）。casbin role 端點 policy + `role:*` button code 皆已 seed（見 §2.3 表）。
- **infra 復用**：`require_policy`（008）／`mutate_in_txn`＋op-log（005/007）／`soft_delete` trait＋`find_active`（004）／`PageRes`（009）／`map_write_err`（23505→2222、009）／`endpoint_coverage_lint`（現 AS_BUILT `[&str;22]`）＋`entity_access_lint`／`enforce_mw`＋DB-fresh `roles_of_user`（006）。
- **010 被消費端點**：`getMenuTree`（{id:number,label,pId:number,children}）／`getAllPages`（裸 page 名 `string[]`）／`getUserRoutes`（讀 v2='menu' policy → 與本刀寫端閉環）。

### 2.3 rust-api GAPS（`c377444` 親驗、本刀 BUILD）— 9 net-new 端點，policy 皆 m002 已 seed
| 端點 | method | seed v0 | protected | 性質 |
|---|---|---|---|---|
| `/systemManage/getRoleList` | GET | **R_SUPER + R_ADMIN** | f | sys_role 讀（分頁/filter、PageRes） |
| `/systemManage/addRole` / `updateRole` | POST | R_SUPER | f | sys_role 寫（entity、mutate_in_txn op-log） |
| `/systemManage/deleteRole` / `batchDeleteRole` | DELETE | R_SUPER | f | sys_role 軟刪（delete guards、batch 整批拒） |
| `/systemManage/getRoleMenu` | GET | R_SUPER | **t** | 讀 role 的 v2='menu' policy → menu ids |
| `/systemManage/updateRoleMenu` | POST | R_SUPER | **t** | ★ **casbin policy WRITE**（v2='menu' replace） |
| `/systemManage/getRoleHome` / `updateRoleHome` | GET/POST | R_SUPER | f | sys_role.home entity 讀/寫 |

> **★ casbin WRITE＝全專案首次**（親驗 `enforce.rs`：production 只 `get_filtered_policy` 讀，無 runtime policy 寫；`add_policy` 僅單測 MemoryAdapter）。enforcer 持為 `state.enforcer: Arc<RwLock<casbin::Enforcer>>`、`main.rs` boot `SeaOrmAdapter::new(db)`＋`load_policy()`。runtime 寫經 `enforcer.write().await` + MgmtApi（`remove_filtered_policy`/`add_policy`）。**adapter `add_policy` 只寫 8 基底欄、治理欄（protected/created_at/created_by）不設**（→ 新 policy protected=default false、created_by NULL；波 2 可接受、治理波 3 補）。

### 2.4 base-web 現況（§I.1 權威、`a59c2738` 親驗）— role 頁 mock、menu-auth-modal 三步待接
- `views/manage/role/index.vue`：CRUD **全 mock**（console.log stub）；real＝`fetchGetRoleList`（分頁）＋`fetchGetAllRoles`（009 已用於 user 表單角色下拉）。表欄：roleName/roleCode/roleDesc/status/operate。**無 hasAuth gating**。
- `modules/`：`menu-auth-modal.vue`／`button-auth-modal.vue`（留波3）／`role-operate-drawer.vue`（add/edit form）／`role-search.vue`。**無 endpoint-auth-modal**（v1.4.0 net-new、不在本刀）。
- **menu-auth-modal 三步**（crux contract）：(a) `fetchGetMenuTree()`（010 real）→ 全菜單樹；(b) `getChecks()` **mock** → 期待 `fetchGetRoleMenu(roleId)` 回 **menu ids `number[]`**（NTree `checked-keys`、`key-field=id`）；(c) `handleSubmit()` **mock** → 期待 `fetchUpdateRoleMenu(roleId, menuIds)`。**home 內嵌此 modal**：`getHome/updateHome` mock → 期待 `fetchGetRoleHome/fetchUpdateRoleHome`（home 選項來自 `fetchGetAllPages` 010 real）。
- **typings**：`Role = CommonRecord<{roleName,roleCode,roleDesc}>`（id:number/status/createBy.../updateBy...）；`RoleList=PaginatingQueryRecord<Role>`；`AllRole=Pick<Role,'id'|'roleName'|'roleCode'>`。`RoleUpsertModel`／role-menu/home DTO **待加**（rev3-system-manage.d.ts ADAPT）。
- **frozen（不改）**：route store／transform／`service/api/system-manage.ts`（read）／`service/api/auth.ts`／`service/request`。**★ 無 .env flip**（010 已翻 dynamic）。

### 2.5 DESIGN §8.2／§4.2 對 role/policy 的面
- DESIGN §8.2：User/Role CRUD＋授權 modal「沿用、縱切重排」；Button/Endpoint policy＝**純 policy 縱切、非行為島**、與 policy-governance 行為島同排**波 3**（DESIGN §8.2 縱切清單＋波次表）。
- DESIGN §4.2：casbin_rule 是行為島（protected/archive/restore/PolicyMutated）→**波 3** 第一輪用 state-machine 鏡頭設計。本刀 Role×Menu 寫＝對該島持久層做 grant/revoke、**治理機制留波 3**（D2）。
- DESIGN §3.3/⚠️o（application-RI hybrid）：intra-entity ref 下沉 facade。Role delete guards（in-use 查 sys_user_role）＝跨 entity ref → 留 handler 驗（同 ⚠️o「跨 facade 留 handler」）。

### 2.6 三端 wire shapes（rust ↔ base-web ↔ §I.3、⚠️r 逐欄忠實）
| wire | base-web typing | rust 來源 | 映射 |
|---|---|---|---|
| `Role.id`（管理域 CommonRecord） | number | sys_role.id i64 | number（⚠️r 同 User.id） |
| `getRoleMenu` 回 | `number[]`（menu ids） | role v2='menu' route_names | route_name → sys_menu.id 映射、orphan skip |
| `updateRoleMenu` body | `{roleId, menuIds:number[]}` | — | menuIds → sys_menu route_names → 寫 policy |
| `getRoleHome` 回／`updateRoleHome` body | `string`／`{roleId, home}` | sys_role.home | 直 |
| roleName/roleCode/roleDesc | string | Option/String | 沿 009 CommonRecord 映射 |
> roleId/menuIds 域＝number（⚠️r 管理域）；wrapper id→String 慣例僅對單 `id` body 欄（plan-phase grep 3 端對齊）。

### 2.7 消費者／被消費
- **本刀消費 010**：getMenuTree（菜單樹 UI）／getAllPages（home 下拉）。
- **本刀被未來消費**：Role 是 user 表單角色下拉（getAllRoles 009 已用）的真實來源；Role×Menu 寫端與 010 getUserRoutes 讀端閉環。
- **波 3 延伸**：button-auth/endpoint-auth（policy 縱切）＋policy-governance（archive/protected/restore）治理本刀寫入的 policy。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | scope 邊界 | **menu-auth only**：Role CRUD＋Role×Menu（getRoleMenu/updateRoleMenu）＋home（getRoleHome/updateRoleHome）；**button-auth/endpoint-auth 留波 3**（**user 拍**） | DESIGN §8.2 把 Button/Endpoint policy 歸純 policy 縱切、與 policy-governance 同波 3；波 2 聚焦、波界乾淨。否決「併 button-auth」（提前波 3 button-policy-write＋需定 getAllButtons 來源）／「只做 Role CRUD」（Role×Menu 是 D2 從 010 延來、010 讀端已備、此刀正主） |
| D2 | Role×Menu 治理姿態 | **最小、治理留波 3**（**user 拍**）：updateRoleMenu 乾淨 replace role 的 v2='menu' policy set（MgmtApi remove_filtered+add）；op-log **best-effort**（casbin adapter txn 與 op-log txn 無法同 txn、文件化非原子 gap）；**protected 不強制**（波 3） | 治理（protected 強制/archive/restore/PolicyMutated）＝波 3 行為島，最貼 DESIGN §4.2 不提前。protected-removal foot-gun（super 取消勾 manage_menu 等 protected baseline 會移除、可重勾恢復、super-only 低風險）→ 登 follow-up、波 3 closes。否決 B（guarded 保留 protected：UX 不一致或需擴 wire）／C（entity facade 寫+reload enforcer 達原子：最複雜、繞 adapter、drift 風險、提前波 3） |
| D3 | role delete guards | **seeded + in-use + self**（**user 拍**、零 migration）：拒刪 ① seeded 3 角色（hardcode `R_SUPER/R_ADMIN/R_USER_COMMON`）→`biz.role.seededProtected`；② role-in-use（sys_user_role 有指派）→`biz.role.inUse`；③ self-role（operator 當前角色）→`biz.role.cannotDeleteSelfRole` | sys_role 無 protected 欄 → hardcode seeded codes 守（零 migration、不加欄）。in-use 防孤兒指派（同 009 referential 精神）；self 防自鎖（同 009 self-lock 精神）。3 seeded 角色實測皆 in-use（雙重守）。否決「只守 in-use」（無人用的 seeded 角色仍可刪）／「加 protected 欄」（破零 migration） |
| D4 | casbin WRITE 機制 | **enforcer write-lock + MgmtApi**（`enforcer.write().await` → `remove_filtered_policy(0,[role,_, "menu"])` → 逐 `add_policy([role, route_name, "menu"])`）；可抽 facade `auth::set_role_menu_policies(enforcer, role_code, &[route_name])`（plan 定位 enforce.rs 或新 auth/policy.rs）（工程） | 全專案首次 runtime policy 寫；標準 casbin 寫法、adapter 自動持久化 casbin_rule。新 policy 治理欄 default（protected=false/created_by=NULL）波 2 可接受。getRoleMenu 讀復用 `menu_routes_for_roles(&[role_code])`（010）→ route_names |
| D5 | id ↔ route_name 映射 | **handler 經 sys_menu 轉**：getRoleMenu route_names→ids（list_all/route_name→id lookup、orphan route_name skip）；updateRoleMenu ids→route_names（find by ids；不存在 id skip 或 2222、plan 定）（工程） | menu-auth-modal 用 menu id（number[]）、casbin 用 route_name → 必轉。沿 010 facade entity:: 合法處做 lookup |
| D6 | home 寫 vs policy 寫 | **getRoleHome/updateRoleHome＝sys_role.home entity 讀/寫**（走 mutate_in_txn、**原子 op-log 正常**）；只有 updateRoleMenu 是 policy 寫（非原子 D2）（工程） | home 是 entity 欄非 policy → 沿 008/009 entity 寫 pattern；與 010 home_of_roles 讀端對齊（多角色 tie-break follow-up 由本刀 updateRoleHome 提供寫端） |
| D7 | getRoleList 授權 | **R_SUPER + R_ADMIN（忠實 seed）**；寫端（add/update/delete/batch）R_SUPER；getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome R_SUPER（工程） | m002 ground-truth：getRoleList seeded R_SUPER+R_ADMIN。註：R_ADMIN 無 manage_role menu（psql 證）→ 實務到不了 /manage/role、getRoleList R_ADMIN access moot；忠實 seed 不收窄 |
| D8 | batch delete 語意 | **逐項獨立驗證、整批拒 no-partial**（同 010 menu batch；批內任一觸 seeded/in-use/self → 整批拒、DB 無變）（工程） | 沿 010 spec Clarification batch 紀律；一致心智模型 |
| D9 | migration | **零 migration**（sys_role/sys_user_role/casbin_rule＋role seed＋9 端點 policy＋`role:*` button code 皆 002/m002 已備、§2.2/§2.3）（工程） | act-on-code 親驗全備；`Migrator::up delta == 0` |
| D10 | 前端 hasAuth gating | **role 頁寫入鈕掛 `hasAuth('role:add'/'role:edit'/'role:delete')`**（`role:*` button code R_SUPER 已 seed）（MODAL-WIRING (b)、工程） | 同 010 menu/user gating；只 R_SUPER 有 role:* → 只 super 見 role 寫鈕（與寫端 R_SUPER-only 一致、無 009 那種 button↔endpoint 不對齊） |

## 4. 元件設計（act-on-code、當前 lineage seam 名）

### 4.1 `facade/sys_role.rs`（改：加 CRUD fn、archetype A、entity:: 合法）
既有 `find_active`／`home_of_roles` 不動。加：`list`（§5.8 分頁/filter roleName·roleCode·status；PageRes）／`find_active_by_id`／`create`（mutate_in_txn＋INSERT op-log、roleCode 23505 由 handler map）／`update`（含 home 寫、no-op Ok(None)、UPDATE op-log）／`soft_delete`（delete guards 前置、SOFT_DELETE op-log、成對 deleted_at/by）／`batch_soft_delete`（整批拒 no-partial）。delete guards 之 in-use 查＝`sys_user_role` count by role_id（跨 entity、留 handler 或 facade orchestrate、plan 定）。`build_*_active_model` 純測 seam（沿 009）。

### 4.2 casbin policy WRITE（★ 新；D4）`auth/enforce.rs`（或新 `auth/policy.rs`）
`set_role_menu_policies(enforcer, role_code, route_names: &[String]) -> Result<(), AppError>`：`enforcer.write().await` → `remove_filtered_policy(0, vec![role_code, String::new(), "menu"])`〔精確過濾 v0=role∧v2=menu〕→ 逐 `add_policy(vec![role_code, route_name, "menu"])`。`enforce_mw`/`require_policy`/`menu_routes_for_roles`/`buttons_for_roles` 本體不動。getRoleMenu 讀復用 `menu_routes_for_roles(&*enforcer.read().await, &[role_code])`。

### 4.3 `handler/system_manage.rs`（改：加 role 9 端點、沿 009/010 檔）
DTO `RoleUpsertReq`（serde camelCase：id?/roleName/roleCode/roleDesc?/status）／`RoleMenuReq{roleId, menuIds:Vec<i64>}`／`RoleHomeReq{roleId, home}`。handler：`get_role_list`（§5.8 filter＋PageRes）／`add_role`／`update_role`（`map_write_err`→roleCode 23505→`biz.role.duplicateRoleCode`、禁裸 `?`）／`delete_role`／`batch_delete_role`（delete guards→2222 seededProtected/inUse/cannotDeleteSelfRole）／`get_role_menu`（解 role code→menu_routes_for_roles→route_name→id）／`update_role_menu`（id parse→find_active_by_id role None→`biz.role.notFound`→ids→route_names→set_role_menu_policies；op-log best-effort）／`get_role_home`／`update_role_home`（sys_role.home entity 寫、原子 op-log）。`(op,trace)=ctx.to_audit_operator(claims.uid)`；回型 `Result<Json<Res<Value>>, AppError>`；零 path-root entity::。

### 4.4 `main.rs`（改：註冊 9 路由；復用 enforce 骨架、enforce.rs/require_policy 不動）
入 `systemManage` 群：getRoleList（GET、require_policy R_SUPER+R_ADMIN 由 seed 決、route_layer 仍逐 path）／addRole·updateRole（POST）／deleteRole·batchDeleteRole（DELETE）／getRoleMenu·getRoleHome（GET）／updateRoleMenu·updateRoleHome（POST），各 `route_layer(require_policy(path, method))`＋外層 enforce_mw。

### 4.5 `error.rs` 消費（沿 009、不改 blanket）
role biz 2222 於 handler match：`map_write_err`（沿 009、roleCode 23505→`biz.role.duplicateRoleCode`）；delete guards→`AppError::Biz("biz.role.{seededProtected,inUse,cannotDeleteSelfRole}")`；role notFound→`biz.role.notFound`。blanket `From<DbErr>` 不改。

### 4.6 base-web wire＋frontend（D1/D2/D10、MODAL-WIRING (a)(b)）
- **WRAPPER** `service/api/rev3-system-manage.ts`：+`fetchAddRole`/`fetchUpdateRole`（id→String）/`fetchDeleteRole`/`fetchBatchDeleteRole`/`fetchGetRoleMenu(roleId)`/`fetchUpdateRoleMenu(roleId,menuIds)`/`fetchGetRoleHome(roleId)`/`fetchUpdateRoleHome(roleId,home)`。
- **ADAPT** `typings/api/rev3-system-manage.d.ts`：`RoleUpsertModel`（Pick<Role,'roleName'|'roleCode'|'roleDesc'|'status'>&{id?:number}）。
- **MODAL-WIRING (a)** `role/index.vue`（handleDelete/handleBatchDelete→真 fn、去 stub）＋`role-operate-drawer.vue`（handleSubmit→add/updateRole）＋`menu-auth-modal.vue`（getChecks→getRoleMenu／handleSubmit→updateRoleMenu／getHome→getRoleHome／updateHome→updateRoleHome）。
- **MODAL-WIRING (b)** hasAuth gating：role/index.vue 寫入鈕 `hasAuth('role:add'/'role:edit'/'role:delete')`。
- **i18n** `app.d.ts` Schema＋`langs/{zh-cn,en-us}` `backend.biz.role.*`（先 Schema 後 locale）。
- **button-auth-modal.vue 留 mock（波 3）**；frozen 既有檔不動；無 .env flip。

### 4.7 `server/tests/endpoint_coverage_lint.rs`（改：bump AS_BUILT_ROUTES `[&str;22]→[&str;31]`）
加 9 path；9 皆 policy-governed（require_policy）→ Assertion A 要在 m002 seed（已 seed、自動過）；Assertion B registered==as-built。與註冊同 commit。

## 5. wire / 碼 / INET / i18n
- wire id：`Role.id` number（⚠️r）；getRoleMenu→`number[]`、updateRoleMenu `{roleId:number, menuIds:number[]}`、updateRoleHome `{roleId:number, home:string}`；roleCode/roleName/roleDesc string（CommonRecord createBy/updateBy/createTime/updateTime 沿 009）。
- biz key（`backend.biz.role.*`、⚠️y）：`duplicateRoleCode`／`notFound`／`seededProtected`／`inUse`／`cannotDeleteSelfRole`（+menu 更新失敗類待 plan）。攔截器 `$t('backend.'+msg)` 自動。
- op-log：role CRUD＋updateRoleHome＝INET round-trip 原子（沿 008/009）；**updateRoleMenu op-log best-effort、非原子**（D2、entity_table='sys_role'、entity_id=roleId、operation=UPDATE、before/after=route_name 集）。

## 6. 範圍邊界

**IN**：sys_role facade（list §5.8／find_active_by_id／create／update〔含 home〕／soft_delete〔delete guards〕／batch〔整批拒〕）＋casbin `set_role_menu_policies`（v2='menu' WRITE、首次）／handler 9 端點（CRUD 5＋Role×Menu 2＋home 2）＋id↔route_name 映射／delete guards（seeded+in-use+self）／roleCode 23505→2222／main 9 路由＋`endpoint_coverage_lint` bump [22→31]／base-web rev3 wrapper（8 fn）＋ADAPT RoleUpsertModel＋MODAL-WIRING (a)〔CRUD＋menu-auth-modal getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome〕(b)〔role hasAuth gating〕＋`backend.biz.role.*` i18n／純測（delete guard／id↔route_name／build_active_model）＋live（role CRUD round-trip／23505 dup→2222／delete guards／**updateRoleMenu→getUserRoutes 讀寫閉環**／updateRoleHome→home_of_roles 反映／op-log）＋CDP（role 頁 CRUD 真發、menu-auth-modal 指派菜單真發 updateRoleMenu→換角色登入側欄變化、hasAuth gating）。

**OUT（遞延）**：button-auth（getAllButtons/getRoleButton/updateRoleButton＝波 3 Button policy 縱切、button-auth-modal 留 mock）／endpoint-auth（getRoleEndpoints/... + endpoint-auth-modal net-new＝波 3）／policy-governance（protected 強制/archive/restore/PolicyMutated＝波 3 行為島、本刀 policy 寫不受治理）／role g-policy 角色繼承（無 seed、不引入）／casbin_rule 治理欄寫入（adapter 不設、波 3）。

**MOOT（lineage already-done、不重做）**：sys_role/sys_user_role/casbin_rule schema＋3 role seed＋9 端點 policy＋`role:*` button code（m001/m002）／`require_policy`·`enforce_mw`·`menu_routes_for_roles`·`buttons_for_roles`·op-log threading·`PageRes`·envelope·`sql_err`→2222·`mutate_in_txn`·`soft_delete` trait·`find_active`·`endpoint_coverage_lint`（004-010）／010 getMenuTree·getAllPages·getUserRoutes·base-web menu-auth-modal getTree·role 頁 getRoleList/getAllRoles·Role/RoleList typings·hasAuth hook（既有）。

## 7. enforce/track pattern 留痕（`/speckit-plan` Constitution Check 對齊用）
- **§I.1 base-web 權威**：role 頁＋menu-auth-modal 既有（mock）→ rust 補 9 對應端點；兩端俱在。
- **§I.2 menu-Casbin-enforce**：updateRoleMenu 寫 v2='menu' policy＝010 getUserRoutes 讀端的寫端對手（讀寫閉環）。
- **§I.3 typings 權威／⚠️r**：Role.id number、getRoleMenu number[]（id↔route_name 映射消型謊）。
- **§I.6 審計欄**：role CRUD/updateRoleHome 成對審計欄＋op-log；updateRoleMenu op-log best-effort（D2 例外、文件化）。
- **§III 軌道**：MODAL-WIRING (a)〔role/index.vue·role-operate-drawer·menu-auth-modal 接線〕(b)〔role hasAuth gating〕／BASE-WEB-WRAPPER〔rev3-system-manage.ts role fn〕／BASE-WEB-ADAPT〔RoleUpsertModel typings〕／BASE-WEB-I18N-WIRING〔backend.biz.role.*〕皆既授；route store/transform/system-manage.ts/auth.ts 不動。
- **★ casbin policy WRITE＝全專案首次**：plan Constitution Check 須評估是否觸 §I.7 行為島（policy island）——本刀只 grant/revoke v2='menu'、不碰 archive/protected/PolicyMutated 三態（波 3）；DESIGN §4.2「行為島波 3 設計」與本刀「波 2 寫 policy」的 sequencing 須在 plan 明示（D2 治理留波 3）。
- **零 migration**（D9）／無新 crate。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）
**FR（草案）**：FR-1 super 可分頁/filter 瀏覽角色（getRoleList、R_SUPER+R_ADMIN）。FR-2 super 可新增角色（roleCode 唯一、撞名→可讀 biz 2222 非 5000）。FR-3 super 可修改角色。FR-4 super 可軟刪/批次軟刪角色；seeded/in-use/self 角色拒刪（整批拒 no-partial）。FR-5 super 可指派角色可見菜單（updateRoleMenu 寫 v2='menu' policy）、即時反映於該角色 getUserRoutes 側欄。FR-6 super 可設定角色 home。FR-7 越權：role 管理限授權角色（CRUD per seed、Role×Menu/home R_SUPER）、非授權 403 不洩資料、授權依系統當下角色。FR-8 role 異動原子審計（CRUD/home entity 寫同 txn op-log；updateRoleMenu policy 寫 best-effort op-log、文件化非原子）。FR-9 寫入鈕 hasAuth(`role:*`) 顯隱（後端仍強制）。FR-10 零 schema 變更、零回歸（getUserRoutes/getUserInfo/user/menu/login 不變）。
**SC（草案）**：SC-1 角色 CRUD 全鏈真發 request 反映（無假成功）、訊息在地化。SC-2 roleCode 重複 100% 拒且不建、非 5000。SC-3 delete guards 三情境（seeded/in-use/self）100% 擋、批次整批拒 DB 無變。SC-4 **updateRoleMenu→getUserRoutes 讀寫閉環**：改某角色菜單後該角色側欄 100% 反映（活體＋CDP 換角色登入）。SC-5 updateRoleHome 後 home_of_roles/getUserRoutes home 反映。SC-6 越權 403、授權依當下角色。SC-7 端點授權守恆（endpoint_coverage_lint [31]＋entity_access_lint）。SC-8 零 migration、零回歸（010/009/008 行為不變）。

## 9. C-V 驗收（草案、live 一律 `--test-threads=1` serial+DATABASE_URL；rust 容器內 `docker exec`、改 .rs 先 force-touch）
C-V-0 build `--locked`（無新 crate）。C-V-1 純測（delete guard 三情境／id↔route_name 映射／build_active_model）。C-V-2 lint（endpoint_coverage_lint [31]＋entity_access_lint）。C-V-3 live role CRUD round-trip＋23505 dup→2222。C-V-4 live delete guards（seeded/in-use/self＋batch 整批拒 DB 無變）。C-V-5 ★ live **Role×Menu 讀寫閉環**（updateRoleMenu 寫 v2='menu' → getRoleMenu 回新集 → getUserRoutes 該角色側欄反映；含 remove+add）。C-V-6 live updateRoleHome→home_of_roles 反映。C-V-7 live policy-gate（非 super 寫 role→403；getRoleList R_ADMIN→200）。C-V-8 base-web typecheck。C-V-9 CDP（role 頁 CRUD 真發、menu-auth-modal 指派→真發 updateRoleMenu→換角色登入側欄變、role hasAuth gating）。C-V-10 零回歸（diff 零 migration/entity；enforce_mw/require_policy/menu_routes_for_roles/blanket From 未改；base-web frozen 未改；getUserRoutes/getUserInfo/menu/user 不變）。C-V-11 prod target image build。

## 10. Files（當前 lineage、BUILD vs ALREADY）
**BUILD（改/新）**：`rust-api/server/src/model/facade/sys_role.rs`（改：CRUD fn＋delete guards）／`auth/enforce.rs`〔或新 `auth/policy.rs`〕（加 set_role_menu_policies）／`handler/system_manage.rs`（改：role 9 端點＋DTO＋biz map）／`main.rs`（9 路由＋分層）／`error.rs`（role biz 映射、沿 009）／`server/tests/endpoint_coverage_lint.rs`（bump [22→31]）／base-web `src/service/api/rev3-system-manage.ts`（8 role fn）＋`src/typings/api/rev3-system-manage.d.ts`（RoleUpsertModel）＋`src/views/manage/role/{index.vue, modules/role-operate-drawer.vue, modules/menu-auth-modal.vue}`（MW (a)(b)）＋`src/locales/langs/{zh-cn,en-us}.ts`＋`src/typings/app.d.ts`（`backend.biz.role.*`）。
**ALREADY（不動）**：`entity/src/{sys_role,sys_user_role,casbin_rule}.rs`／schema＋3 role seed＋9 端點 policy＋`role:*` button code（m001/m002）／`require_policy`·`enforce_mw`·`menu_routes_for_roles`·`buttons_for_roles`·op-log·`PageRes`·envelope·`sql_err`→2222·`mutate_in_txn`·`soft_delete`·`endpoint_coverage_lint`（004-010）／base-web route store·transform·`service/api/system-manage.ts`〔getRoleList/getAllRoles/getMenuTree/getAllPages〕·auth.ts·request·menu-auth-modal getTree·button-auth-modal〔留 mock〕·role-search·Role/RoleList typings·hasAuth hook／010 getMenuTree·getAllPages·getUserRoutes／login/getUserInfo/user/menu/settings 端點。

## 11. forward-compat / 下游 + plan-phase 接地清單
- **plan Phase 0 research 必 grep**：(a) casbin `Enforcer` MgmtApi 確切簽名（`remove_filtered_policy`/`add_policy` 回型、是否需 `save_policy`／adapter auto-persist）＋ enforcer write-lock 用法；(b) `sys_role` facade 真實返回型（對齊 009 sys_user pattern）；(c) wire 3 端 roleId/menuIds 型（base-web fetchGetRoleMenu/updateRoleMenu inline 型 ↔ rust DTO ↔ menu-auth-modal state）；(d) m002 9 role 端點 path/method 逐字（require_policy 對齊）；(e) sys_user_role count-by-role 查法（in-use guard）。
- **新 crate ⇒ prod build**：本刀無新 crate；C-V 仍跑 prod target build。
- **CDP 不 defer**：role 頁 CRUD＋menu-auth-modal 真發＋換角色側欄變＝必 browser 軌（curl≠modal）。
- **下游**：波 3 Button/Endpoint policy 縱切復用本刀 set_role_*_policies pattern（v2='button'/HTTP-method）＋policy-governance 治理本刀寫入的 v2='menu' policy（protected/archive/restore）。本刀 updateRoleHome 提供 010 home_of_roles 多角色 tie-break follow-up 的寫端。
- **follow-up 預期**：updateRoleMenu op-log 非原子（D2、波 3 archive 收）／protected baseline 可被 super 移除（D2 foot-gun、波 3 protected 強制收）／casbin_rule 治理欄 adapter 不設（波 3）。

## 12. Workflow 單元分解（預想、階段 2 依實際相依定；rust 全程 serial）
- **U1 Role CRUD**：sys_role facade（list/find_active_by_id/create/update/soft_delete〔delete guards〕/batch）＋handler 5 端點＋main＋lint bump〔部分〕＋純測（delete guard/active_model）＋live（CRUD round-trip/23505/delete guards）。
- **U2 Role×Menu + home**：casbin set_role_menu_policies（首次 policy WRITE）＋id↔route_name 映射＋handler getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome＋main＋lint〔補齊 31〕＋live（★讀寫閉環 updateRoleMenu→getUserRoutes／updateRoleHome→home_of_roles／policy-gate）。
- **U3 base-web**：rev3 wrapper 8 fn＋RoleUpsertModel＋MODAL-WIRING (a)〔index/drawer/menu-auth-modal〕(b)〔hasAuth〕＋i18n＋typecheck＋CDP（CRUD 真發＋指派菜單換角色側欄變＋gating）。button-auth-modal 留 mock。
- US「越權」acceptance（policy-gate live＋lint）散入各 rust 單元邊界自驗；零回歸＋prod build 收口。
