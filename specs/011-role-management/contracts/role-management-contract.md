# Contract: Role 管理＋角色×選單授權（DB-first）＋角色首頁（011 落定、跨 feature 權威）

> 本刀建立的不變式，後續波3（policy-governance 治理刀復用 set_role_dimension／補 archive/restore/protected 管理/PolicyMutated 優化/publish-watcher；Button/Endpoint policy 縱切復用 set_role_dimension pattern）繼承。權威＝constitution §I.7 §4.2／§I.2/§I.3/§I.6/§III＋DESIGN §4.2/§8.2＋DECISIONS ⚠️o/⚠️r/⚠️y＋brainstorm D1-D3（**B1 校正後 DB-first**）。

## 1. Role CRUD（沿 009 sys_user pattern、§5.8）
1. **getRoleList**：§5.8 分頁/filter（roleName/roleCode 模糊 `LOWER(col) LIKE ESCAPE`、status 精確、空字串守門 `Some("")→None`〔009 ILIKE 校正繼承〕）+`PageRes`；require_policy **R_SUPER+R_ADMIN**（m002 seed）。
2. **addRole/updateRole**：entity 寫經 `mutate_in_txn`+INSERT/UPDATE op-log（原子、§I.6 成對審計欄）；**roleCode 唯一**：23505 catch、寫端 `map_write_err`→`sql_err()→UniqueConstraintViolation→Biz("biz.role.duplicateRoleCode")`（沿 009 ⚠️o、blanket From 不改、禁裸 `?`）。update no-op（find None→handler `biz.role.notFound`）。
3. **soft_delete/batch**：`SoftDeletable`（濾 deleted_at、**不濾 status**）；**無 restore**（角色頁無回收桶、軟刪單向）。

## 2. delete guards（seeded+in-use+self、handler 前置、跨 entity ⚠️o）
1. **三守門**（任一觸→2222、整筆/整批拒、DB 無變）：① `role.code ∈ {R_SUPER,R_ADMIN,R_USER_COMMON}`（hardcode、零 migration）→`biz.role.seededProtected`；② `count_users_by_role_id(id)>0`→`biz.role.inUse`；③ operator 當前角色（`roles_of_user(uid)` codes contains `role.code`，id→code via find_active_by_id）→`biz.role.cannotDeleteSelfRole`。
2. **批次逐項獨立驗證、整批拒 no-partial**（沿 010）。

## 3. ★ 角色×選單授權＝casbin policy WRITE（**DB-first**、constitution §I.7 §4.2、B1 校正後）
1. **DB-first set_role_dimension（L4 facade `sys_casbin_rule`）**：於 `mutate_in_txn`（AppState.db 同 txn）：read current `entity::casbin_rule`（**11-col**、filter `ptype='p'∧v0=role_code∧v2='menu'`、見 protected）→diff→**②protected-reject**（to_revoke 任一 `protected=true`→`SetDimensionError::Rejected`→handler `biz.role.menuProtected` 2222、整批拒零變更）→revoke=`Entity::delete_many().filter().exec`、grant=`ActiveModel.insert`（set v0/v1/v2+created_at/created_by+protected=false）→op-log（`entity_table="casbin_rule"`、entity_id=role_id、before/after route_name 集、**同 txn 原子**）。handler 在 commit 後且 `outcome.changed`→`state.enforcer.write().await.load_policy().await`（⑤ 全量 reload、本地）。**★ 絕不用 enforcer MgmtApi 寫（`remove_filtered_policy`/`add_policies`）——該路徑觸 in-memory＋adapter auto_save 旁路＋非原子＝違 §I.7 §4.2 ①④（rev2-034 anti-pattern、B1）。**
2. **§4.2 凍結 invariant 對應**：①DB-first〔facade 直寫 casbin_rule〕✅／②protected-reject ✅／④原子審計〔casbin_rule 寫+op-log 同 mutate_in_txn〕✅／⑤reload〔load_policy〕✅；③PolicyMutated-gate 優化／archive/restore/protected 管理/跨實例 publish-watcher＝**波3 治理刀**（DESIGN §8.2、功能交付排序、非 invariant 反轉）。
3. **讀寫閉環**：updateRoleMenu（DB-first 寫 v2='menu'+reload）＝010 getUserRoutes `menu_routes_for_roles`（讀 in-memory）寫端對手；改某角色選單→該角色 getUserRoutes 側欄即反映。getRoleMenu 讀復用 `menu_routes_for_roles([code])`（in-memory 讀、合規）→route_names→sys_menu id 映射（orphan skip）。
4. **★ 測試 cleanup（非 txn 隔離）**：set_role_dimension 經 mutate_in_txn **commit**（讀寫閉環需 committed 寫供 load_policy 見）→ live/CDP 測 updateRoleMenu **必 snapshot+restore**＋psql 驗 casbin_rule 回原狀（勿污染 seed）。

## 4. 角色首頁（entity 寫、原子）
1. **getRoleHome/updateRoleHome**：`sys_role.home` entity 讀/寫（非 policy）→`mutate_in_txn`、**原子 op-log**。home 選項來自 010 getAllPages。
2. 與 010 `home_of_roles`（讀端、getUserRoutes home）對齊：updateRoleHome 提供寫端。

## 5. wire／i18n 不變式（§I.3 typings 權威＋§III 軌道、⚠️r）
1. **wire id 域＝number（⚠️r）**：`Role.id`＝number；`getRoleMenu`→`number[]`；`roleId`／`menuIds`＝number/number[]（**獨立參數、不轉 String**、與單 body `id`→`String(id)` 非對稱、刻意）；`RoleUpsertModel.id`（updateRole body）→wrapper `String(id)`。2^53 fail-loud guard。
2. **roleCode 23505→2222**：寫端 sql_err map（沿 009、blanket From 不改）。
3. **軌道（皆既授）**：rev3-* wrapper（WRAPPER 8 role fn）／RoleUpsertModel（ADAPT）／MODAL-WIRING **(a)** role/index.vue+role-operate-drawer+menu-auth-modal 接線＋**(b)** role hasAuth gating（`role:*`）／`backend.biz.role.*`（I18N-WIRING **6 鍵**、含 menuProtected）。**route store/transform/system-manage.ts/auth.ts/request/button-auth-modal〔mock〕不改**；**無 .env flip**。

## 6. endpoint_coverage_lint 漸增（⚠️x）
1. `AS_BUILT_ROUTES [22→31]`（+9 role 端點、與註冊同 commit S9）。
2. 9 端點皆 policy-governed（require_policy；getRoleList R_SUPER+R_ADMIN、getRoleMenu/updateRoleMenu protected=true）→Assertion A m002 seed 自動過；Assertion B registered==as-built。handler/main 零 path-root entity::（casbin 寫在 sys_casbin_rule facade）。

## 7. 本刀邊界（OUT／MOOT）
- **MOOT（已 done）**：sys_role/sys_user_role/casbin_rule（11-col entity）/sys_casbin_policy_archive（13-col、本刀不消費）schema＋3 角色＋9 端點 policy＋`role:*` button code（m001/m002）／enforce_mw·require_policy·menu_routes_for_roles·buttons_for_roles·roles_of_user·mutate_in_txn〔任意 entity_table〕·SoftDeletable·to_audit_operator·blanket From·envelope·sql_err·PageRes·endpoint_coverage_lint（004-010）／casbin Enforcer init·`load_policy()`（reload 用）／base-web route store·transform·system-manage.ts·auth.ts·role-search·menu-auth-modal getTree·Role/RoleList typings·hasAuth／010 getMenuTree/getAllPages/getUserRoutes。
- **OUT（遞延、波3 policy-governance 治理刀）**：archive（revoke→`sys_casbin_policy_archive`；本刀 revoke=hard DELETE）／restore（←archive）／protected 策略**管理**（un-protect/re-protect；本刀僅 ②enforce「移除受保護→拒」）／③PolicyMutated-gate 優化／跨實例 `casbin:policy:invalidate` publish-watcher（本刀單實例本地 load_policy）／回收桶 UI／button-auth（+button-auth-modal）／endpoint-auth（+endpoint-auth-modal）／role g-policy 角色繼承／role restore／role status 作存取閘。
- 無 migration／無 schema/entity 變更／無新 crate／enforce_mw·require_policy·menu_routes_for_roles·From<DbErr> 不動／base-web 既有檔不改／無 .env flip／**★ 絕不用 casbin MgmtApi 寫（DB-first only）**。
