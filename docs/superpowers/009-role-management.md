# 009-role-management — Phase 0 Brainstorm（spec-design）

> 波 2 **第一刀**（Role 直刀、user 拍序 Role 先 2026-06-15）；波 1（008 User 直刀）收官後首個 data-island 刀。
> **scope = (i) 純 sys_role CRUD**（user 親決 brainstorm Q1）：5 端點 CRUD，**授權指派（menu/button/endpoint 三維 casbin）明確 OUT**——因其 menu tree 需 `getMenuTree`/`getAllPages`（零 entity/facade/handler），會 net-new 整個 `sys_menu` 維度、遠超本刀，留 Menu 刀後再做。
> **零 migration／零新 crate**：schema（m001 `sys_role`）／角色 seed（m002 3 角色）／casbin policy（m002 已 seed 5 端點）全在波 0。本刀純 rust handler/facade/DTO ＋ base-web `rev3-system-manage.ts` wrapper（接 stub）。**絕不動 m002**（破 sequence-driven id 基線，同 008 §0）。
> 本檔交手動 `/speckit-specify` 形式化（**非 writing-plans**；CLAUDE.md §3 覆寫 brainstorming 技能終態）。
> **與 008 同構**：本刀大部分鏡像 008 User 刀（facade-only、⚠️o handler-RI、mutate_in_txn 審計、MODAL-WIRING、enforce、CDP cutover）；Role-specific delta 見 §2.5。008 carry-forward（空字串 filter／--no-verify／CDP 強制／serial rust／EXPECTED bump）全帶（§5.8、§6）。
> **凍結權威**：DESIGN §8.2（data-island 縱切）／§5.1（soft-delete）／§5.2（mutate_in_txn 審計）／§5.3（RBAC enforce）／§5.4（envelope）／§5.8（SearchParams／PageRes／**filter 模糊語意**）／§7.1（Role endpoint 全集）／§7.2（id wire number、⚠️r）／§3.1（archetype A）／§3.3（RI handler 層）／§4.2（治理島邊界——本刀不碰）。DECISIONS §1：⚠️a（保守 SLA）／⚠️o（RI handler 層）／⚠️r（id 逐欄 typings）／⚠️x（endpoint_coverage_lint）／⚠️b（審計讀端＝波 2 殿後刀、與本刀無關）。衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔。

---

## 0. 刀界決策前情

- **波 2 排序＝Role 先（user 親決 2026-06-15）**：覆寫 dossier 的 Menu-first 建議；Role-first 在 scope (i) 下乾淨成立（純 sys_role CRUD 無 Menu 依賴）。
- **scope (i) 純 sys_role CRUD（user 親決 brainstorm Q1 2026-06-15）**：否決 (ii)＋授權指派。grounding 實證 (ii) 的 menu-auth modal 需 `getMenuTree`/`getAllPages`——這兩端 m002 已 seed policy 但**零 entity／零 facade／零 handler**（連 `sys_menu` 表的 entity 都未建）→ (ii) 須 net-new 整個 sys_menu 讀端維度＋三維 casbin 指派＋endpoint-auth modal 前端整檔，遠超本刀且把 Menu 拖進來。授權指派延後（Menu 刀後、或 Menu 刀一個面）。
- **零 migration**：本刀不新增/修改任何 migration。**絕不加 casbin 列**（同 008 §0：m002 casbin 72 列 INSERT 序＝rev2 pristine 重放庫 `ORDER BY id`，亂插位移 id 破基線，memory `seed-squash-rowid-drift`）。5 端點 policy 在 m002 已齊（§2.3）。
- **endpoint_coverage_lint EXPECTED bump**：008 立此 lint（`EXPECTED_ROUTE_COUNT=6`、SC-009 硬 gate）；本刀 +5 gated route → **bump 6→11**，逐 route 補 assert（hard gate、每新 gated route 必同步 +policy +EXPECTED）。

## 1. 目標一句話

把 role 管理閉環（純 CRUD 層）：5 端點（`getRoleList` 分頁/**模糊** filter／`addRole`／`updateRole`／`deleteRole`／`batchDeleteRole`）的 rust handler/facade/DTO ＋ base-web `rev3-system-manage.ts` 4 wrapper（MODAL-WIRING 接 role 頁 stub）；RI 在 handler 層（⚠️o、撞碼/值域/種子保護/soft-deleted 拒更）、enforce 既有 m002 policy、寫端審計（leaf entity、無 password、無 composite）、wire 防 type-lie（id number），全程零 migration。**授權指派 OUT**。

## 2. Context（探索蒐集；act-on-code grounded 2026-06-15）

### 2.1 rev2 013*/016*/018 參考形（⚠️g／§I.5 受控參照重寫、非照拷）

- rev2 role 管理散在 013（schema+seed）/016*（user+role 同 feature）/018（role-permission）。rev3 縱切：**本刀只取 sys_role CRUD 半**（純 §5.1-5.4+§5.8）；role-permission（三維授權）屬另刀（需 sys_menu）。
- 參照讀允許、code 零拷貝（§I.5）；⚠️r 廢除的 id-string、⚠️e 廢除的 Internal→500 補丁絕不回帶。

### 2.2 凍結權威 + 本刀關係

- **§8.2 data-island／§5.1-5.4／§5.8**：本刀 **conform**（鏡像 008、無偏離）。
- **§7.2 id wire number（⚠️r）**：`Role.id`／write `ids` 皆 JSON number；serializer 2^53 fail-loud。
- **§3.3 RI handler 層（⚠️o）**：handler 解碼/驗值再呼 facade；facade 收已驗值不驗。
- **§3.1 archetype**：`sys_role`＝A（6 審計欄、`code` partial-uniq `WHERE deleted_at IS NULL`）。
- **§4.2 治理島邊界**：本刀**不碰**——archive/restore/protected policy 狀態機屬波 3；本刀連 casbin 都不動（scope (i) 純 CRUD）。

### 2.3 rust-api 現況（波 0 + 008 後）

- **sys_role facade 既有**（query-only、複用）：`find_active()`（Select builder）／`find_active_by_ids(db,&[i64])→Vec<Model>`／`find_active_by_codes(db,&[String])→Vec<Model>`（008 加）／`all_active(db)→Vec<Model>`（008 加）。
- **sys_role facade 缺**（net-new、§5.3）：`find_active_by_id`／`find_active_by_code`（dup-check 精確）／`search_active`（分頁+模糊 filter）／`create`／`update`／`soft_delete`（皆走 `mutate_in_txn`；batch 由 handler 迴圈 `soft_delete`，鏡像 008 `batch_delete_user`）。`impl AuditSerialize for sys_role::Model`（net-new、無敏感欄不需 redact）。
- **審計機制（005，008 已實戰）**：`mutate_in_txn(db,f)` 閉包回 `(txn,R,Option<AuditEvent>)`、同 txn 寫 op-log 原子；`AuditEvent{operation,entity_table,entity_id,payload_before,payload_after,operator,trace_id}`。Role 為 **leaf entity**：payload＝`audit_json()`（role 自身欄）、**無 composite roles**（role 側不觸 sys_user_role join、DESIGN line 279）。
- **handler 共用 helper（008 已建）**：`wire_to_i16`（"1"/"2"/""→None/Err）、`blank_to_none`（空字串→None）、`serialize_id_guarded`（2^53）、`audit_operator(&ctx)`、`ensure_*`/`check_name_collision` 形（撞名判定）；**plan 期 grep 可見性**（同檔 `system_manage.rs` 或抽 pub(crate)、§8 R4）。
- **enforce（006）**：`enforce_mw` per-route、DB-fresh role code；本刀 5 route 逐條 `route_layer(enforce_mw)`。
- **m002 已 seed 5 端點 policy**：`getRoleList`＝R_SUPER+R_ADMIN／`addRole`·`updateRole`·`deleteRole`·`batchDeleteRole`＝R_SUPER only（seeded-but-unimplemented、本刀補 handler）。
- **endpoint_coverage_lint（008 立）**：`server/tests/endpoint_coverage_lint.rs` `EXPECTED_ROUTE_COUNT=6`；本刀 bump 11。

### 2.4 消費者（決定本刀面；base-web grounding）

- **`service/api/system-manage.ts`**：只有 `fetchGetRoleList`／`fetchGetAllRoles` 2 個**讀** fn；`addRole`/`updateRole`/`deleteRole`/`batchDeleteRole` 4 寫端 **不存在**（前端 stub）。
- **`role/index.vue`**：`handleDelete(id)`＝`console.log(id)`／`handleBatchDelete()`＝`console.log(checkedRowKeys.value)`；id 全程 number；有 search bar。
- **`role/modules/role-operate-drawer.vue`**：`handleSubmit` 現 `// request` stub（add/update 共用）；Model＝Pick<Role,'roleName'|'roleCode'|'roleDesc'|'status'>（edit 帶 id 自 rowData，wrapper 併 id，同 008）；roleCode 欄 edit 時禁改（immutable）。
- **`role-search`**：filter 欄＝`roleName`／`roleCode`／`status`（3 欄、初始 null→空字串、**必中招 008 空字串 filter bug**）。
- **授權 modal（menu-auth/button-auth）**：存在但 **OUT of scope**（本刀不接、需 sys_menu）。

### 2.5 Role vs 008 User 的 delta（本刀 specific）

| 面 | 008 User | 009 Role |
|---|---|---|
| 敏感欄 | password（argon2 hash + redact） | **無**（無 redact、無 argon2、無預設密碼） |
| 不可變識別欄 | userName **可變**（FR-008 改名） | **roleCode 不可變**（= casbin subject v0；update 不入該欄） |
| M:N / composite 審計 | userRoles（sys_user_role）→ composite role-delta | **無**（role 為 leaf、role 側不觸 join → 審計只記 role 自身欄、無 composite） |
| 種子保護 | id∈{1,2,3} 拒刪 | id∈{1,2,3}（R_SUPER/R_ADMIN/R_USER_COMMON）拒刪（同形） |
| filter 欄 | userName/nick/email 模糊·phone/status/gender 精確 | **roleName/roleCode 模糊·status 精確**（§5.3） |
| 端點數 | 6（含 getAllRoles） | 5（純 CRUD） |

## 3. Scope

- **IN**：sys_role 5 端點 handler（`handler/system_manage*`）＋ wire DTO（`RoleListItem`/`RoleSearchParams`/`RoleUpsertReq`）；facade 增補（§2.3 缺項 6 fn + `impl AuditSerialize`）；handler 層 RI（⚠️o：撞碼/值域/soft-deleted 拒更/種子保護）；寫端審計（Insert/Update before-after/SoftDelete、leaf、無 composite）；5 route 逐條 `route_layer(enforce_mw)` 驗既有 m002 policy；**endpoint_coverage_lint bump 6→11**；base-web `rev3-system-manage.ts` +4 wrapper ＋ 接 2 處 stub（index.vue delete、drawer submit、MODAL-WIRING ★L4）；wire type-lie 防線（id number、snake→camel、status i16↔enum）；**空字串 filter→blank_to_none**（roleName/roleCode/status）；**CDP 驗收 cutover**（沿 008 §6、限 `/manage/role`、見 §6）。
- **無 migration／無新表／無新 seed／不動 m002**。
- **OUT**：**授權指派（menu/button/endpoint 三維 casbin、`updateRoleMenu`/`updateRoleButton`/`updateRoleEndpoints` + `getRoleMenu`/`getMenuTree`/`getAllPages`/`getAllButtons`/`getAllEndpoints`）**——需 net-new `sys_menu` entity/facade/handler，遠超本刀；留 Menu 刀後（或 Menu 刀一個面）。／**roleCode 變更**（不可變）／**delete cascade**（只 soft-delete sys_role、不動 casbin/join）／**治理島**（archive/restore/protected policy 狀態機、波 3）／getAllRoles（008 已做、唯讀下拉）／回收桶 restore（§5.0 Role 列無 restore、後續）。

## 4. brainstorm 拍板（user 親決 2026-06-15）

| # | 決策 | options | 結論 |
|---|---|---|---|
| 波2 排序 | Role 先／Menu 先／settings 先 | Role 先（user 選） | **Role 先**（覆寫 dossier Menu-first；scope (i) 下 Role-first 乾淨；序 Role→Menu→settings→審計殿後） |
| Q1 scope | (i) 純 CRUD／(ii) ＋授權指派／(iii) 改回 Menu 先 | (i)（user 選） | **(i) 純 sys_role CRUD**：5 端、零新 entity、同構 008；(ii) 否決（需 net-new sys_menu、遠超本刀、把 Menu 拖入）；授權指派延後 Menu 刀後 |
| Q2 delete 連帶 | 只 soft-delete sys_role／+清 casbin／+清 casbin+join | 只 soft-delete（user 選） | **只 soft-delete sys_role、不動 casbin/join**：安全性自動成立（enforce_mw 的 roles_for_user 走 find_active_by_ids active 過濾 → soft-deleted role 自動不計入 user 有效角色、grants 即 inert，無需刪 casbin 列）；殘留 casbin/join 列無害、留波 3 治理島清 |
| search filter 語意 | 全精確／文字模糊+enum 精確 | 文字模糊+enum 精確（沿 008） | **`roleName`/`roleCode` LIKE `%x%`（模糊）；`status` 精確 eq；null/空字串略過該 filter；預設 `id ASC`**（鏡像 008 §5.3；search 模糊 ≠ dup-check 精確） |
| roleCode 可變性 + 種子保護 | 不可變/可變；id-key/code-key 保護 | 不可變 ＋ id-key 拒刪（沿 008 形） | **roleCode 不可變**（= casbin v0；update 不入該欄、前端 edit 禁改、handler 不動該欄）；**種子保護＝id∈{1,2,3} 僅拒刪**（deleteRole/batchDeleteRole→2222、單+批 all-or-nothing）、不擋 update |
| audit 形 | leaf（role 自身欄）／composite | leaf（role 為 leaf entity） | **leaf 審計**：Insert/Update(before-after)/SoftDelete 只記 role 自身欄（無 password redact、無 composite role-delta；role 側不觸 join、DESIGN line 279） |
| dup roleCode | pre-check 2222／靠 DB uniq | pre-check（沿 008 Q3） | **addRole `find_active_by_code` 精確 pre-check 命中→biz 2222**（同構 008 dup user_name；非靠 `From<DbErr>→5000` 自動映射）；partial-uniq 為 DB 第二道 |
| batch 種子中斷 | 前置全量校驗／單 txn rollback／逐筆 skip | 前置全量校驗（沿 008） | **前置全量校驗 id∈{1,2,3}→整批拒 2222（不進 txn）；否則逐筆 soft_delete（各自 txn、接受 infra 半套、admin 重試冪等）**（鏡像 008 batch_delete_user、⚠️a） |
| CDP cutover | 必 cutover 打真 rust-api／驗 mock | 必 cutover（沿 008 §6） | **沿 008 §6**：gitignored `.env.test.local`→rust-api:31081、重啟 base-web、`/manage/role` 限定、static mode、curl+CDP 雙軌（見 §6）；**008 已建此檔可複用** |
| RI 驗層位 + SLA | — | handler 層（⚠️o）／保守（⚠️a） | **conform ⚠️o/⚠️a**（同 008） |

## 5. Design

### 5.1 架構（鏡像 008、守 §I.6 facade-only ＋ ⚠️o handler-RI 分層）

`handler/system_manage*`（L6：DTO 映射＋application-RI＋orchestration）→ `facade/sys_role`（L6：`Column` 存取、`mutate_in_txn` 包寫）→ `entity`（L4）。`Column`/查詢組裝（含模糊 filter）留 facade（守 entity_access_lint）；跨檢查（撞碼、種子保護、值域、soft-deleted）在 handler（⚠️o）。

### 5.2 rust handler（5 fn、全回 `Result<Res<T>, AppError>`）

- `get_role_list(Query<RoleSearchParams>)` → `Res<PageRes<RoleListItem>>`：`RoleSearchParams`→`blank_to_none` 正規化→`sys_role::search_active`（分頁+模糊 filter）→ Model→DTO。
- `add_role(Json<RoleUpsertReq>)` → `Res<()>`：RI（§5.4）→ `sys_role::create`（mutate_in_txn、Insert 審計）。
- `update_role(Json<RoleUpsertReq>)` → `Res<()>`：RI（soft-deleted 拒更）→ `sys_role::update`（roleCode 不入 UPDATE、before/after 審計）。
- `delete_role(Query<{id:i64}>)` → `Res<()>`：種子保護（id∈{1,2,3}→2222）→ `soft_delete`。
- `batch_delete_role(Query<{ids:String}>)` → `Res<()>`：comma-parse（沿 008、惡形→2222）→ 前置全量種子校驗（任一 id∈{1,2,3}→整批 2222）→ 逐筆 `soft_delete`（各自 txn）。

### 5.3 facade 增補（sys_role.rs、Column/查詢在此）

- `search_active(db,&RoleFilter,current,size)→(Vec<Model>,u64)`：`find_active()` 基 + `roleName`/`roleCode` `.contains`（LIKE %x%）+ `status` `.eq` + null 略過 + `id ASC` + paginate。**model 層 RoleFilter struct（status: Option<i16>）、不收 wire DTO**（沿 008 ActiveUserFilter 避層級倒置）。
- `find_active_by_id(db,i64)→Option<Model>`（update/delete pre-check）。
- `find_active_by_code(db,&str)→Option<Model>`（**精確** dup-check → 2222）。
- `create(db,fields,operator,trace)→Model`：mutate_in_txn INSERT + `AuditEvent{Insert, after:Some(audit_json)}`（無 roles、無 password）。
- `update(db,id,fields,operator,trace)→Model`：mutate_in_txn snapshot 舊 audit_json → UPDATE（roleName/roleDesc/status；**roleCode 不入**、updated_at/by 成對 §I.6）→ `AuditEvent{Update, before/after}`。
- `soft_delete`：沿 008 形（mutate_in_txn、SOFT_DELETE 審計、Ok(false) no-op）；batch 由 handler 迴圈。
- `impl AuditSerialize for Model`：role 自身欄（id/roleName/roleCode/roleDesc/status/審計 6 欄；**無敏感欄、不需 redact**）。

### 5.4 handler 層 RI（⚠️o；漏一條＝髒資料）

- **撞碼唯一**：addRole `find_active_by_code(roleCode)` 命中→`2222`（partial-uniq 第二道）。updateRole 因 roleCode 不可變、無 rename-collision。
- **值域**：`status`∈{1,2} 或 null（i16、`wire_to_i16`）→ 違反 `2222`。
- **soft-deleted 拒更**：updateRole 先 `find_active_by_id(id)` 查無→`2222`。
- **種子保護**：delete/batchDelete id∈{1,2,3}→`2222`（僅拒刪、不擋 update）。

### 5.5 wire DTO 映射（type-lie 防線、§7.2 ⚠️r；鏡像 008）

| wire 欄 | entity 源 | 轉換 |
|---|---|---|
| `id` | `id:i64` | → JSON **number**；2^53 fail-loud 守衛 |
| `roleName`/`roleCode`/`roleDesc` | `name`/`code`/`role_desc` | rename（name→roleName、code→roleCode、role_desc→roleDesc） |
| `status` | `status:i16` | i16→string-enum `'1'|'2'`（null 保留；唯一 i16↔enum 欄、無 gender） |
| `createTime`/`createBy`/`updateTime`/`updateBy` | `created_at`/`created_by`/… | snake→camel ＋ at→Time/by→By；createBy/updateBy = operator id-string（008 follow-up 同形、非人名） |

DTO 手寫 serde struct（rename + i16↔enum 自訂 ser、純可測）；handler `Model→DTO`、facade 回 raw Model。`RoleUpsertReq{id:Option<i64>,roleName,roleCode,roleDesc,status}`（create 無 id、update wrapper 併 id）。

### 5.6 base-web wrapper（★L4 MODAL-WIRING、§III）

- **`rev3-system-manage.ts` +4**：`fetchAddRole(model)`／`fetchUpdateRole({...model,id})`／`fetchDeleteRole(id)`／`fetchBatchDeleteRole(ids:number[])`（同 008 形、`// [rev3-inline WRAPPER]`）；`fetchGetRoleList`/`fetchGetAllRoles` 既有不動。
- **接 stub**：`role/index.vue` handleDelete→fetchDeleteRole／handleBatchDelete→fetchBatchDeleteRole〔MW(a)〕；`role-operate-drawer.vue` handleSubmit→add/update（operateType 分支）〔MW(c)〕。原行 `console.log`/`// request` 保留為 `// [rev3-inline MW(a)/(c)] 原行:` 註解。
- **`system-manage.ts`/`auth.ts`/`route.ts` 零改**（§III ⚠️s、grep 稽核）。

### 5.7 enforce + endpoint_coverage_lint

- 5 route 逐條 `route_layer(enforce_mw)`；subject＝DB-fresh role code、驗既有 m002 policy（§2.3）。
- **endpoint_coverage_lint bump**：`EXPECTED_ROUTE_COUNT` 6→**11**；逐 route 補 assert（每掛 enforce 的 route 有 ≥1 policy）。controller sanity-bite 複驗（破 policy→lint 失敗指名）。

### 5.8 錯誤碼 + 008 carry-forward

- 碼（§I.3 凍結）：`0000` 成功；`2222` 業務拒（撞碼/值域/soft-deleted 更新/種子刪/batch 含種子/惡形 ids）；`enforce` 失敗 `5003`。除 auth 外 HTTP 200。不新增碼。
- **008 carry-forward（必帶）**：①空字串 filter→`blank_to_none`（roleName/roleCode/status；**可順手評估前端 axios `skipNulls` 一行根治** base-web `packages/axios/src/options.ts`、覆蓋 role/user/未來所有 search、見 §8 R3）②base-web commit **`--no-verify`**＋自驗 typecheck（hook 在 alpine 壞、memory `base-web-precommit-hook-broken-in-alpine`）③**CDP modal smoke 強制**（§6）④rust implementer subagent **串行**（共用 target 平行 build 交叉污染）⑤EXPECTED bump＋sanity-bite ⑥live `#[ignore]` `--test-threads=1`（共表）⑦`From<DbErr>→5000` 沿用。

### 5.9 結構與檔案

| 檔 | 動 | 職責 |
|---|---|---|
| `server/src/handler/system_manage*.rs` | 新/改 | 5 role handler（§5.2）＋RoleListItem/RoleSearchParams/RoleUpsertReq DTO；handler 放哪 §8 R4 grep 後定（傾向新檔避動 008） |
| `server/src/model/facade/sys_role.rs` | 改 | 6 facade fn（§5.3）＋`impl AuditSerialize` |
| `server/src/main.rs` | 改 | 5 route ＋ `route_layer(enforce_mw)` |
| `server/tests/endpoint_coverage_lint.rs` | 改 | EXPECTED 6→11 |
| `base-web/src/service/api/rev3-system-manage.ts` | 改 | +4 role wrapper |
| `base-web/.../role/index.vue` | 改 | 接 handleDelete/handleBatchDelete |
| `base-web/.../role/modules/role-operate-drawer.vue` | 改 | 接 handleSubmit |
| `base-web/src/typings/api/*` | 改? | RoleUpsertReq 寫型（§8 R2） |

### 5.10 資料流（addRole 為例）

```
base-web drawer handleSubmit → rev3-system-manage.fetchAddRole(model)
  → POST /systemManage/addRole {roleName,roleCode,roleDesc,status}
  → [enforce_mw] DB-fresh role code 驗 policy（非 R_SUPER→5003）
  → handler::add_role
      ├─ RI：wire_to_i16(status) 值域→2222；find_active_by_code(roleCode) 命中→2222
      ├─ facade::sys_role::create（mutate_in_txn）
      │     ├─ INSERT active_model（created_by=operator）
      │     └─ AuditEvent{Insert, after:audit_json}  ← 同 txn 寫 op-log
      └─ Res(()) → {data:null, code:"0000"}
```

## 6. 驗證（純測 + live + CDP modal；交 /speckit-specify 形式化）

- **純測**（test-first、零 DB/HTTP）：DTO serde（i16↔string-enum status/null、snake→camel、2^53 id guard）／`search_active` filter SQL-shape（roleName/roleCode LIKE %x%、status eq、null/blank 略過、id ASC）／`blank_to_none`／種子謂詞 id∈{1,2,3}／dup-code 判定→2222。
- **live smoke**（#[ignore]、真 PG、**`--test-threads=1`**、facade-level `src/.../live_smoke.rs`、bracketed cleanup）：addRole→op-log Insert（audit_json、無 password/roles）；updateRole→Update before/after（roleName/desc/status 變、roleCode 不變）；deleteRole soft-delete＋種子 id∈{1,2,3}→2222（handler RI 由 curl 覆蓋）；batchDelete 前置校驗 all-or-nothing；getRoleList **模糊** filter（roleName/roleCode 部分字串命中）＋分頁；已軟刪 no-op 零 audit。
- **CDP modal smoke（沿 008 §6、必先 cutover、否則驗到 mock 非 rust-api）**：
  - **問題**：base-web 全域預設打 Apifox mock（`VITE_HTTP_PROXY=Y`＋`.env.test` `VITE_SERVICE_BASE_URL=apifox`）；不 cutover 的 CDP **沒驗到 rust-api**。
  - **cutover（沿 008、gitignored、BASE-WEB-ADAPT）**：`base-web/.env.test.local`（`VITE_SERVICE_BASE_URL=http://rust-api:31081`）→ vite（`pnpm dev`=`vite --mode test`）loadEnv `.local` 優先序 shadow mock → vite dev proxy 轉 rust-api；committed `.env.test` 不動。**008 已建此檔且 gitignored 留存**（CHECKLIST §3.11）→ **複用**；不在則重建。**改 env 後重啟 base-web 容器**（vite 啟動讀 env）+ 待 healthy。
  - **CDP 流程**：quick-login(Super) → 導航 **`/manage/role`** → 驗表格 envelope `code:0000`（rust-api 真 getRoleList、非 mock faker）→ 開 role CRUD modal、`Runtime.evaluate` 填表單 → 提交 add/update → 驗 modal 關+列表刷新 → 刪除/批量刪除 → 驗。**不導航 `/manage/menu`**（未實作、404）。
  - **static route mode**（`.env` 出廠 `VITE_AUTH_ROUTE_MODE=static`）→ 不呼 getUserRoutes、避動態選單依賴（Menu 刀）。
  - **複用 008 CDP driver**（9229、login/nav/SOY_token/envelope 驗、`tests/000/scripts` + 008 `/tmp/cdp-*` 腳本）、改選擇器對 role 頁。
  - **curl + CDP 雙軌**（curl 直送驗 envelope+psql；CDP 驗 base-web interceptor/modal）—— 兩者皆要。
  - **★ Role 尤其關鍵**：role 頁有 search（roleName/roleCode/status），**會中招 008 同款空字串 filter bug**（curl 乾淨 query 掩蓋、cutover 後 CDP `/manage/role` list-load 才現形）。**驗證紀律**：cutover 後 CDP 表格能載出真 3 角色＝空字串 filter 已處理；2222/空列＝漏 blank_to_none。008 的 bug 正是這樣抓到的。
- **p95 SLA（⚠️a）**：list<300ms／write<500ms 納 C-V。
- **無新 crate**（members 固定 5）→「新 crate 必跑 prod build」不觸發；dev build 綠＋live smoke 即可。

### SC 候選

getRoleList 分頁+**模糊** filter（roleName/roleCode 模糊·status 精確·null 略過·id ASC）／addRole dup-code 拒（2222）+審計／updateRole before/after 審計+roleCode 不變+soft-deleted 拒更／deleteRole soft-delete+種子拒刪／batchDelete 前置校驗 all-or-nothing／RI 四項（撞碼/值域/soft-deleted/種子）／enforce 既有 policy（R_ADMIN 讀 ok、寫 5003）／endpoint_coverage_lint 綠（EXPECTED=11）／wire 零 type-lie（id number）／p95 達標／MODAL-WIRING 兩 stub 接線／CDP 經 `.env.test.local` cutover **真打 rust-api（非 mock）**、`/manage/role` modal 全鏈綠。

## 7. Out of scope / Deferred / Backlog

- **授權指派（menu/button/endpoint 三維 casbin）**：需 net-new `sys_menu` entity/facade/handler（getMenuTree/getAllPages 零後端）＋三維 grant/revoke＋endpoint-auth modal 前端整檔 → 留 **Menu 刀後**（或 Menu 刀一個面）；casbin runtime hard-replace 機制 grounding 已證可行（enforce.rs add/remove_policy write-through、不需 reload）但本刀不做。
- **roleCode 變更**（不可變）／**delete cascade**（只 soft-delete sys_role）／**治理島**（archive/restore/protected policy 狀態機、波 3）。
- getAllRoles（008 已做、唯讀下拉）／回收桶 restore（後續）／⚠️b 審計查詢讀端（波 2 殿後刀、與本刀無關）。

## 8. Phase 0 research 待辦（交 /speckit-plan research.md；CLAUDE.md §3 三 grep）

- **R1** facade 真實簽名 grep：`sys_role` 既有 4 query helper 確切形（`find_active`/`find_active_by_ids`/`find_active_by_codes`/`all_active`）＋ 008 `sys_user` 寫路徑（`create`/`update`/`soft_delete`/`mutate_in_txn`/`AuditEvent`/`AuditSerialize`）為 Role 對映樣板（⚠️g 參照讀允許/拷貝禁止）；確認 `sys_role::Model` 欄（entity/src/sys_role.rs：name/code/role_desc/status:Option<i16>/6 審計欄/home?）。
- **R2** wire 三端逐欄對齊（每端點：rust handler return type ↔ base-web `service/api` inline type＋`typings/api/system-manage.d.ts` 宣告 ↔ component state）。重點：`Role`/`RoleList`/`RoleSearchParams`/`AllRole` typings 欄與 `EnableStatus`；RoleUpsertReq 寫型（drawer Model 無 id、wrapper 帶 id）；createBy/updateBy 型（string、operator id-string）。
- **R3 ⚠️ 空字串 filter 根治位置**：(a) per-handler `blank_to_none`（同 008、保險）vs (b) base-web axios `packages/axios/src/options.ts` `stringify(params,{skipNulls:true})` 一行根治（覆蓋 role/user/未來所有 search）——grep 確認 axios option 位置+影響面，plan 拍板採哪個（或兩者）。
- **R4** rust 結構真實命名 grep：008 共用 helper（`wire_to_i16`/`blank_to_none`/`serialize_id_guarded`/`audit_operator`/撞名判定）的可見性（同檔 `system_manage.rs` private vs 可 pub(crate) 給 role handler）；**Role handler 放哪**（新檔 `system_manage_role.rs` vs 既有檔長大）；`handler/mod.rs` 註冊法；`Res<T>`/`AppError` 碼映射；`RequestContext`+operator 取法。
- **R5** 種子保護謂詞確認：role id∈{1,2,3}（R_SUPER/R_ADMIN/R_USER_COMMON）sequence-driven 確定（m002 不寫 id、空表 INSERT 序 1/2/3）；roleCode 不可變佐證（casbin v0 = code）。
- **R6** soft-deleted role inert 佐證：`roles_for_user`/`roles_for_users` 走 `find_active_by_ids`（active 過濾）→ soft-deleted role 不計入 user 有效角色、其 casbin grants 自動 inert（確認 deleteRole 不需動 casbin/join）。
- **R7** endpoint_coverage_lint bump：EXPECTED 6→11 改法、逐 route assert block（sanity-bite 複驗）。
- **R8** CDP modal smoke 接法＋cutover 驗證（沿 008 §6/R8）：(a) `base-web/.env.test.local`（指 rust-api:31081）複用/重建+重啟 base-web 容器+vite proxy 驗轉發；(b) `tests/000/scripts` + 008 CDP 腳本沿用、改 `/manage/role` 選擇器；(c) 新增 drawer 填值+modal 等待（`[role=dialog]`）+刪除 smoke；(d) static mode 驗收；(e) p95 量測法；(f) **list-load 即空字串 filter 守門**（載出真 3 角色 = blank_to_none 正確）。

---

**brainstorm 定稿 2026-06-15；拍板見 §4（波2 Role 先／scope (i) 純 CRUD／delete 只 soft-delete sys_role／search roleName·roleCode 模糊·status 精確／roleCode 不可變＋種子 id 僅拒刪／leaf 審計無 composite／dup-code pre-check 2222／batch 前置校驗 all-or-nothing／CDP cutover 沿 008）＋既有權威 DESIGN §8.2·§5.1-5.4·§5.8·§7.1·§7.2·§3.1·§3.3·§4.2 ＋ DECISIONS ⚠️a·⚠️o·⚠️r·⚠️x。零 migration／零新 crate。008 carry-forward 全帶（§5.8）。下一步：手動 `/speckit-specify`（input＝本檔；`before_specify` pre-hook 建 `009-role-management` feature branch；不排進 brainstorm 流程觸發）。**
