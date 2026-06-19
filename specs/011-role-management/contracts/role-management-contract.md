# Contract: Role 管理＋角色×選單授權＋角色首頁（011 落定、跨 feature 權威）

> 本刀建立的不變式，後續波3（Button/Endpoint policy 縱切復用 set_role_*_policies pattern；policy-governance 治理本刀寫入的 v2='menu' policy）繼承。權威＝constitution §I.2/§I.3/§I.6/§III＋DESIGN §4.2/§8.2＋DECISIONS ⚠️o/⚠️r/⚠️y＋本刀 brainstorm D1-D10。

## 1. Role CRUD（沿 009 sys_user pattern、§5.8）
1. **getRoleList**：§5.8 分頁/filter（roleName/roleCode 模糊 `LOWER(col) LIKE ESCAPE`、status 精確、空字串守門 `Some("")→None`〔009 ILIKE 校正繼承〕）+`PageRes`；require_policy **R_SUPER+R_ADMIN**（m002 seed）。
2. **addRole/updateRole**：entity 寫經 `mutate_in_txn`+INSERT/UPDATE op-log（原子、§I.6 成對審計欄）；**roleCode 唯一**：`partial-unique`〔若 schema 有〕或 23505 catch、寫端 `map_write_err`→`sql_err()→UniqueConstraintViolation→Biz("biz.role.duplicateRoleCode")`（沿 009 ⚠️o、blanket From 不改、禁裸 `?`）。update no-op（find None→Ok(None)→handler `biz.role.notFound`）。
3. **soft_delete/batch**：`SoftDeletable`（濾 deleted_at、**不濾 status**）；**無 restore**（角色頁無回收桶、軟刪單向；可刪角色必無人用、殘留 policy 無害、波3 清）。

## 2. delete guards（seeded+in-use+self、handler 前置、跨 entity ⚠️o）
1. **三守門**（任一觸→2222、整筆/整批拒、DB 無變）：① `role.code ∈ {R_SUPER,R_ADMIN,R_USER_COMMON}`（**hardcode** seeded、sys_role 無 protected 欄→零 migration）→`biz.role.seededProtected`；② `count_users_by_role_id(id)>0`→`biz.role.inUse`；③ operator 當前角色（`roles_of_user(uid)` codes contains `role.code`）→`biz.role.cannotDeleteSelfRole`。
2. **批次逐項獨立驗證、整批拒 no-partial**（沿 010 menu batch 紀律）：批內任一觸守門→整批拒、無 partial。
3. id↔code：deleteRole 收 role **id**、guards 需 code（seeded/self 比對）→ `find_active_by_id(id).code`；roles_of_user 回 codes。

## 3. 角色×選單授權＝casbin policy WRITE（★ 全專案首次、§I.2 寫端、⚠️o facade/auth 層）
1. **set_role_menu_policies（auth 層）**：`enforcer.write().await` → `remove_filtered_policy("","p",0,vec![role_code,"","menu"])`（移除該 role 全部 v2='menu'、v1 wildcard）→ `add_policies("","p",[[role_code,route_name,"menu"]...])`。casbin **2.20.0** MgmtApi、async、**auto-persist**（vendored adapter 直寫 casbin_rule＋更新 in-memory model、**無 save_policy**）；`casbin::Error`→`AppError::Internal`（手動、無 From）。
2. **讀寫閉環**：updateRoleMenu（寫 v2='menu'）＝010 getUserRoutes `menu_routes_for_roles`（讀 v2='menu'）的**寫端對手**；改某角色選單後、該角色 getUserRoutes 側欄即反映（§I.2 menu-Casbin-enforce 的指派來源）。getRoleMenu 讀復用 `menu_routes_for_roles([role_code])`→route_names→sys_menu id 映射（menu ids `number[]`、orphan skip）。
3. **★ 非原子 + 治理留波3（D2）**：casbin 寫經 adapter **自有連線**（≠ AppState.db）→ **與 op-log `mutate_in_txn` 非同交易** → updateRoleMenu op-log **best-effort**（policy 寫成功後記 sys_role UPDATE、不保證原子；FR-008）。**protected 不強制**（本刀允許移除受保護基線 v2='menu'、super 可重指派恢復）；archive/protected 強制/restore/PolicyMutated＝**波3 policy-governance 行為島**（DESIGN §4.2、本刀只 data-island 指派、不建治理三態機）。新 policy row 治理欄 default（protected=false/created_by=NULL、波3 補）。

## 4. 角色首頁（entity 寫、原子）
1. **getRoleHome/updateRoleHome**：`sys_role.home` entity 讀/寫（**非 policy**）→ 走 `mutate_in_txn`、**原子 op-log 正常**（有別於 §3 policy 寫的 best-effort）。home 選項來自 010 getAllPages。
2. 與 010 `home_of_roles`（讀端、getUserRoutes home）對齊：updateRoleHome 提供寫端（多角色 home tie-break follow-up 之寫端）。

## 5. wire／i18n 不變式（§I.3 typings 權威＋§III 軌道、⚠️r）
1. **wire id 域＝number（⚠️r）**：`Role.id`＝number（CommonRecord）；`getRoleMenu`→`number[]`（menu ids）；`roleId`／`menuIds`＝number/number[]（**獨立參數、不轉 String**、與單 body `id`→`String(id)` 慣例非對稱、刻意）；`RoleUpsertModel.id`（updateRole body）→ wrapper `String(id)`（沿 009/010）。2^53 fail-loud guard。
2. **roleCode 23505→2222**：寫端 `sql_err()→UniqueConstraintViolation→Biz("biz.role.duplicateRoleCode")`（沿 009 ⚠️o、blanket From 不改）。
3. **軌道（皆既授）**：rev3-* wrapper（WRAPPER 8 role fn）／RoleUpsertModel typings（ADAPT）／MODAL-WIRING **(a)** role/index.vue+role-operate-drawer+menu-auth-modal 接線＋**(b)** role hasAuth gating（`role:*` R_SUPER seed）／`backend.biz.role.*`（I18N-WIRING、⚠️y）。**route store/transform/system-manage.ts/auth.ts/request/button-auth-modal〔留 mock〕不改**（既有檔守恆）；**無 .env flip**（010 已 dynamic）。

## 6. endpoint_coverage_lint 漸增（⚠️x、三守恆之三）
1. `AS_BUILT_ROUTES` 逐刀漸增（本刀 `[22→31]`、+9 role 端點、與註冊同 commit S9）。
2. 9 端點皆 **policy-governed**（require_policy；getRoleList R_SUPER+R_ADMIN、其餘 R_SUPER、getRoleMenu/updateRoleMenu protected=true）→ Assertion A（policy-routes⊆m002 seed）自動過；Assertion B registered==as-built。handler/auth 零 path-root entity::（entity_access_lint）。

## 7. 本刀邊界（OUT／MOOT）
- **MOOT（已 done）**：sys_role/sys_user_role/casbin_rule schema＋3 角色＋9 端點 policy＋`role:*` button code（m001/m002）／enforce_mw·require_policy·menu_routes_for_roles·buttons_for_roles·roles_of_user·mutate_in_txn·SoftDeletable·to_audit_operator·blanket From·envelope·sql_err·PageRes·endpoint_coverage_lint（004-010）／casbin Enforcer init·load_policy·MgmtApi auto-persist／base-web route store·transform·system-manage.ts·auth.ts·role-search·menu-auth-modal getTree·hasAuth hook·Role/RoleList typings／010 getMenuTree/getAllPages/getUserRoutes。
- **OUT（遞延）**：button-auth（getAllButtons/getRoleButton/updateRoleButton＋button-auth-modal＝波3 Button policy 縱切；消費本刀 set_role_*_policies pattern〔v2='button'〕）／endpoint-auth（getRoleEndpoints/...＋endpoint-auth-modal net-new＝波3）／policy-governance（archive/protected 強制/restore/PolicyMutated＝波3 行為島；治理本刀寫入的 v2='menu' policy）／role g-policy 角色繼承／casbin_rule 治理欄寫入／role restore（無、軟刪單向）／role status 作存取閘（metadata、加固另案）。
- 無 migration／無 schema/entity 變更／無新 crate／enforce_mw·require_policy·menu_routes_for_roles·From<DbErr> 不動／base-web 既有檔（route store/transform/system-manage 等）不改／無 .env flip。
