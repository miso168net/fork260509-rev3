# 008-user-management — Phase 0 Brainstorm（spec-design）

> 波 1 **第一刀**（User 直刀、刀位③=A）；波 0 七刀全收（001-007）後首個**業務功能刀**。一刀逼出 §5.1-5.4＋§5.8 全套 ＋ M:N join（`sys_user_role` replace）＋ argon2 預設密碼 ＋ ★L4 MODAL-WIRING 前端軌；代價＝第一刀即最重（rev2 016+017 規模）。
> **零 migration**：schema（m001）／帳號·角色·casbin policy·選單（m002·m004）／FK（m003）全在波 0。本刀純 rust handler/facade/DTO ＋ base-web `rev3-system-manage.ts` wrapper。**絕不動 m002**（破 sequence-driven id 基線、見 §0）。
> 本檔交手動 `/speckit-specify` 形式化（**非 writing-plans**；CLAUDE.md §3）。
> **凍結權威**：DESIGN §8.3（User 刀定義/刀位③）／§5.1（soft-delete `find_active` 濾 deleted_at）／§5.2（統一審計 `mutate_in_txn`、redact password）／§5.3（RBAC Casbin per-route enforce、DB-fresh role code）／§5.4（envelope `{data,code,msg}`、business error HTTP 200）／§5.8（`*SearchParams`／`PageRes{current,size,total,records}`）／§7.1（endpoint 全集）／§7.2（id wire number、⚠️r）／§3.1（archetype A 業務表 6 審計欄／archetype C join 零審計硬刪）／§3.3（application-RI 在 handler 層）。DECISIONS：待決③=A（User 直刀）／⚠️a（保守 SLA）／⚠️o（RI handler 層驗）／⚠️u（不增 constitution 第 10 題）／⚠️x（endpoint_coverage_lint 移交波 1）／⚠️r（id 逐欄 typings）／⚠️p（seed 初始 R_SUPER）。本檔不得與之衝突（衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔）。

---

## 0. 刀界決策前情

- **待決③=A 拍板（2026-06-15）**：**User 直刀**（否決 B＝system_settings 打樣）。`sys_user` 為 login／`operator_id`／roles 根 entity、最早凍結收益最大；B 案「便宜排練 §8.1 全管線」價值已被波 0 七刀實戰驗證 7 次而縮水，換不回漏掉的 §5.8/join/id-number 暴露。代價接受＝第一刀即最重。
- **零 migration**：本刀不新增/不修改任何 migration。**絕不加 casbin 列**——m002 檔頭明言 casbin 72 列 INSERT 序＝rev2 pristine 重放庫 `ORDER BY id` 序，是 sequence-driven id 基線零差異的一部分；亂插會位移 id、破基線比對（memory `seed-squash-rowid-drift`）。6 端點 policy 在 m002 已齊（§2.3）。
- **endpoint_coverage_lint（⚠️x 波 0 換波豁免）移交本刀**：User 為**首個 gated endpoint**，補回此 lint（正向檢查：每掛 enforce 的 route 有 ≥1 policy；容忍尚無 handler 的 policy）並列波 1 出口條件。

## 1. 目標一句話

把 user 管理閉環：6 端點（`getUserList` 分頁/filter／`getAllRoles` 下拉／`addUser`／`updateUser`／`deleteUser`／`batchDeleteUser`）的 rust handler/facade/DTO ＋ base-web `rev3-system-manage.ts` wrapper（MODAL-WIRING 接 stub）；RI 在 handler 層（⚠️o）、enforce 既有 m002 policy、寫端 composite 審計含 **role-delta**、wire 防 type-lie（id 一律 number），全程零 migration。

## 2. Context（探索蒐集）

### 2.1 rev2 016+017 參考形（⚠️g／§I.5 受控參照重寫、非照拷）

- rev2 `016`（user 讀）＋`017`（user 寫）兩 feature 才閉環：分頁/filter list、M:N join replace、argon2 預設密碼、種子保護。rev3 縱切一刀涵蓋相當規模。
- 參照讀允許、code 零拷貝（§I.5 RUSTAPI-SOURCE-ISOLATION）；⚠️r 廢除的 id-string、⚠️e 廢除的 Internal→500/`Number()` 補丁**絕不回帶**。

### 2.2 凍結權威 + 本刀關係

- **§8.3（User 刀定義）／§5.1-5.4／§5.8**：本刀 **conform**（無偏離；異於 007 推進 §5.9）。
- **§7.2 id wire number（⚠️r）**：本刀 **conform** — `User.id`／`Role.id`／write payload `ids` 皆 JSON number；serializer 加 2^53 fail-loud 守衛；getAllRoles **回 number、不跟 mock 的 string**（§5.7、§8 R2）。
- **§3.3 application-RI 在 handler 層（⚠️o 拍板）**：本刀 **conform** — handler 解 role code→存活態（查無 2222）再呼 facade；facade 不驗、收已驗值。
- **§3.1 archetype**：`sys_user`＝A（6 審計欄全、soft-delete partial-uniq）；`sys_user_role`＝C（零審計、硬刪、m003 雙 FK RESTRICT）。當表即定稿、無 retrofit。

### 2.3 rust-api 現況（波 0 後）

- **facade 既有**（複用）：`sys_user`＝`find_active()`／`find_active_by_name(db,&str)→Option<Model>`／`find_active_by_id(db,i64)→Option<Model>`／`soft_delete(db,id,AuditOperator,Option<trace>)→bool`／`impl AuditSerialize::audit_json()`（redact password）；`sys_role`＝`find_active()`／`find_active_by_ids(db,&[i64])→Vec<Model>`；`sys_user_role`＝`find_role_ids_by_user_id`／`roles_for_user(db,i64)→Vec<String>`（回 role **codes**）。
- **facade 缺**（新增）：`sys_user::search_active`（分頁+filter）／`create`／`update`（皆走 `mutate_in_txn`）；`sys_role::all_active`／`find_active_by_codes`；`sys_user_role::replace_roles_in_txn`／`roles_for_users`（batch、避 list N+1）。
- **審計機制（005，confirmed 實讀）**：`mutate_in_txn(db,f)` 閉包回 `(txn,R,Option<AuditEvent>)`、同 txn 寫 op-log 再 commit（原子）；`AuditEvent{operation,entity_table,entity_id,payload_before:Option<Value>,payload_after:Option<Value>,operator,trace_id}`——**payload 為任意 `serde_json::Value`**（非綁 `audit_json`）→ composite role-delta 可行（§5.5）。`AuditOperation`＝Insert/Update/SoftDelete/Restore。
- **auth（006）**：`verify_bearer→Claims.user_id`（operator 源）／`enforce_mw`（per-route 嚴格驗證、DB-fresh role code）／argon2 hash+verify 已入圖。**本刀不動 enforce_mw**。
- **m002 已 seed 6 端點 policy**（行 97-116）：`getUserList`＝R_SUPER+R_ADMIN／`getAllRoles`＝R_SUPER+R_ADMIN+R_USER_COMMON／`addUser`·`updateUser`·`deleteUser`·`batchDeleteUser`＝R_SUPER only。3 帳號（Super/Admin/User、argon2id runtime hash 驗明文 `123456`、status=1、id3 nick=`User01`）／3 角色／3 user_role 關聯／`manage_user` 選單（含 user:add/edit/delete button jsonb）全在。
- **零 systemManage handler/router**：`main.rs` 現無任何 `/systemManage/*` route。

### 2.4 消費者（決定本刀面）

- **base-web `service/api/system-manage.ts`**：只有 `fetchGetUserList`／`fetchGetAllRoles`／`getRoleList` 3 個**讀** fn；`addUser`/`updateUser`/`deleteUser`/`batchDeleteUser` 4 寫端 **service fn 不存在**（前端 stub）。
- **`index.vue`**：`handleDelete(id)`／`handleBatchDelete()` 現 `console.log`＋樂觀 `onDeleted/onBatchDeleted`；id 全程 number。
- **`user-operate-drawer.vue`**：`handleSubmit` 現 `// request` stub；Model＝`Pick<User,'userName'|'userGender'|'nickName'|'userPhone'|'userEmail'|'userRoles'|'status'>`（**無 id**）；`userRoles` NSelect multiple 來源＝`fetchGetAllRoles`（值欄位 roleCode vs id → §8 R3）；表單**無 password 欄**。
- **`user-search.vue`**：filter 欄＝userName／userGender／nickName／userPhone／userEmail／status。
- **getUserInfo（`/auth/getUserInfo`）**：**已於 006 落地**（`handler::auth::get_user_info`、roles+buttons 組裝）、屬 auth 島；本刀**不重作**（DESIGN scope 將其列 User 刀為重疊誤標）。

## 3. Scope

- **IN**：`handler/system_manage.rs`（6 fn）＋ wire DTO（`UserListItem`/`UserSearchParams`/`UserUpsertReq`/`AllRoleItem`）；facade 增補（§2.3 缺項）；handler 層 RI（⚠️o：撞名/role-code 解析/值域/soft-deleted 拒更/種子保護）；寫端 **composite 審計含 role-delta**（§5.5）；argon2 預設密碼（addUser、§5.3 wire 無 password 欄）；6 route 逐條 `route_layer(enforce_mw)` 驗既有 m002 policy；**endpoint_coverage_lint 補回**（⚠️x 移交、波 1 出口）；base-web `rev3-system-manage.ts` wrapper ＋ 接 3 處 stub（MODAL-WIRING ★L4）；wire type-lie 防線（id number、snake→camel、i16→enum、userRoles join）；**CDP 驗收 cutover**（建 gitignored `.env.test.local` 指 rust-api、committed .env 不動、CDP 限 `/manage/user`、見 §6）。
- **無 migration／無新表／無新 seed／不動 m002**。
- **OUT**：`getUserInfo`（006 已做）／改密碼·重設密碼端點（base-web drawer 無 password 欄、無消費 UI、塞之違 §I.1；本刀 password 僅 addUser 預設值）／`system_settings`（§5.6、B 案否決）／審計查詢讀端+UI（⚠️b、波 2）／回收桶列表+restore（§5.0 User 列無 restore column、後續 feature）／policy 治理狀態機（§4.2 行為島、獨立刀）／alt-login·captcha·login lockout（⚠️m/⚠️w、與 user CRUD 無關）／role/menu 的 CRUD（本刀只做 user，getAllRoles 僅唯讀下拉）。

## 4. brainstorm 拍板（user 親決 2026-06-15）

| # | 決策 | options | 結論 |
|---|---|---|---|
| 刀位③ | User 直刀／system_settings 打樣 | A＝User（user 選） | **A：User 直刀**；sys_user 根 entity 最早凍結收益最大、否決 B（見 §0） |
| Scope 範圍 | 6 端點 ±getUserInfo/改密碼 | 6 端點（user 選） | **6 端點**（getUserList/getAllRoles/addUser/updateUser/deleteUser/batchDeleteUser）；排除 getUserInfo（006）/改密碼/system_settings；role 指派**內聯**於 add/update（drawer userRoles 隨表單提交、無獨立 UI） |
| update id 傳遞 | body 併 id／query param／userName 鍵 | body 併 id（user 選） | **wrapper `rev3-system-manage.ts` 把 id 併入 body（`{...model, id}`）**、handler 從 body 取；id＝穩定 BIGSERIAL PK；drawer Model 不必改、rev3-inline 只圈 wrapper。否決 userName 當鍵（soft-delete 後 partial-uniq 釋放、可撞名歧義） |
| batch 種子中斷 | 前置校驗/單一 txn rollback/逐筆 skip | 前置校驗（user 選） | **前置全量校驗有無種子（id∈{1,2,3}）→ 有則整批拒 2222（不進 txn、一筆不刪）；無則逐筆刪**。語意最清晰、避免半途 rollback 成本（⚠️a） |
| batch infra 失敗 | 接受半套（逐筆 txn）/嚴格原子（單一大 txn） | 接受半套（user 選） | **逐筆獨立 txn、複用既有 `soft_delete()`**；種子校驗過後、罕見 DB infra error 中斷 → 已刪留著未刪不動（半套）；admin 重試即可（soft_delete 冪等、對已刪再刪 no-op）。≤50 admin／⚠️a 下足夠 |
| list filter 語意 | 文字模糊+enum 精確/全精確/僅姓名模糊 | name/nick/email 模糊·phone 精確（user 選） | **`userName`/`nickName`/`userEmail` LIKE `%x%`；`userPhone`/`status`/`userGender` 精確 eq；null/空欄略過該 filter；預設 `id ASC`**。≤50 admin 全表掃可接受（⚠️a） |
| casbin seed | 補新 policy／繼承 baseline | 零新增（user 選） | **零新 seed、不動 m002**；6 端點 policy 已在 baseline（§2.3）；角色分級繼承（R_ADMIN 看列不能改、R_USER_COMMON 只抓 role 下拉）；改分級＝動 baseline＝不在本刀 |
| audit role-delta | 只記 user 欄／含 role 前後 | 含 role 前後（user 選） | **add/update 寫 composite payload 含 `roles` 前後快照**（§5.5）；審計看得到「角色 [R_USER_COMMON] → [R_USER_COMMON,R_ADMIN]」；delete 不改（複用 soft_delete） |
| user_name 可變性 + 種子保護 | 不可變/可變；name-key/id-key 保護 | 可變 ＋ id-key 拒刪（user 選） | **user_name 可變**（推翻 research「不可變」假設）、updateUser 可改名（含種子帳號）、handler 驗新名在 active 集唯一；**種子保護＝id∈{1,2,3} 僅拒刪**（deleteUser/batchDeleteUser→2222）、不擋 update。正因允許改名故保護鍵必用不可變 id |
| RI 驗層位 | handler 層／下沉 facade | handler 層（⚠️o） | **conform ⚠️o**：handler 解 role code→存活（查無 2222）再呼 facade；facade 收已驗值不驗 |
| SLA | 保守/嚴格 | 保守（⚠️a） | **conform ⚠️a**：list p95<300ms／write（含同 txn 審計）<500ms／login<1s；波 1 起 C-V 驗收門檻；no aggressive caching/batching |

## 5. Design

### 5.1 架構洞察（守 §I.6 facade-only ＋ ⚠️o handler-RI 分層）

`handler/system_manage`（L6 入口：DTO 映射＋application-RI＋orchestration） → `facade/sys_user·sys_role·sys_user_role`（L6 entity 唯一管道：`Column` 存取、`mutate_in_txn` 包寫） → `entity`（L4）。**分層鐵律**：`Column`/查詢組裝（含 filter）留 facade（守 entity_access_lint）；跨 entity RI（role 解析、撞名、種子保護、值域）在 handler（⚠️o）。兩者組合＝facade 暴露 typed 查詢 fn、handler 編排+驗證。

### 5.2 rust handler 模組（`handler/system_manage.rs`、6 fn）

全回 `Result<Res<T>, AppError>`（envelope 自動包、§5.10）。

- `get_user_list(params: Query<UserSearchParams>)` → `Res<PageRes<UserListItem>>`：呼 `sys_user::search_active`（分頁+filter）取 `(Vec<Model>, total)`，再 `roles_for_users(page_ids)` batch 組 userRoles，Model→DTO 映射（§5.7）。
- `get_all_roles()` → `Res<Vec<AllRoleItem>>`：`sys_role::all_active`→ DTO（id number/roleName/roleCode）。
- `add_user(body: Json<UserUpsertReq>)` → `Res<()>`：RI（§5.4）→ argon2 hash 預設密碼 → facade `create`（mutate_in_txn、§5.5 INSERT 審計）。
- `update_user(body: Json<UserUpsertReq>)` → `Res<()>`：RI（含 soft-deleted 拒更、改名唯一性）→ facade `update`（mutate_in_txn、§5.5 UPDATE 前後快照含 role-delta）。
- `delete_user(q: Query<{id:i64}>)` → `Res<()>`：種子保護（id∈{1,2,3}→2222）→ 既有 `soft_delete()`。
- `batch_delete_user(q: Query<{ids:Vec<i64>}>)` → `Res<()>`：前置種子校驗（任一 id∈{1,2,3}→整批 2222）→ 逐筆 `soft_delete()`（逐筆 txn、§4 接受半套）。

### 5.3 facade 增補（Column/查詢在此、守 facade-only）

- `sys_user::search_active(db,&UserSearchParams)→(Vec<Model>,u64)`：`find_active()` 為基（已濾 deleted_at）＋條件 filter（name/nick/email `like`、phone/status/gender `eq`、null 略過）＋ `id ASC` ＋ `paginate`；回 (records,total)。
- `sys_user::create(db, fields, role_ids:&[i64], operator, trace)→Model`：`mutate_in_txn` 閉包內 insert（password＝argon2id(`123456`) host-gen、wire 無 password 欄）＋ `replace_roles_in_txn(txn,new_id,role_ids)` ＋ 組 `AuditEvent{Insert, "sys_user", Some(id), before:None, after:Some(composite)}`（§5.5）。
- `sys_user::update(db,id,fields,role_ids,operator,trace)→Model`：閉包內先 snapshot（舊 Model.audit_json＋`roles_for_user(id)`）＋ update active_model ＋ `replace_roles_in_txn` ＋ 組 `AuditEvent{Update, before:Some(舊 composite), after:Some(新 composite)}`。
- `sys_role::all_active(db)→Vec<Model>`（執行 `find_active()`）；`find_active_by_codes(db,&[String])→Vec<Model>`（⚠️o role 解析用）。
- `sys_user_role::replace_roles_in_txn(txn,user_id,&[i64])`：硬刪該 user 既有 join 列＋插新（archetype C 零審計、m003 FK RESTRICT 保證 role_id 存活）；`roles_for_users(db,&[i64])→Vec<(i64,Vec<String>)>`（list batch、避 N+1）。

### 5.4 handler 層 RI（⚠️o；漏一條＝髒資料進 DB）

- **撞名唯一**：add 及 update 改名時呼 `find_active_by_name(new)`，命中且非本人→`2222`（partial-uniq `WHERE deleted_at IS NULL` 為 DB 層第二道）。
- **role code→id 解析**：`find_active_by_codes(userRoles)`，解出數 ≠ 提交數（有 code 解不到/已 soft-deleted）→`2222`；解出 ids 傳 facade。
- **值域**：`status`/`userGender` ∈ 合法 i16 集（status 1/2、gender 1/2 或 null）→ 違反 `2222`。
- **soft-deleted 拒更**：update 先 `find_active_by_id(id)`，查無→`2222`。
- **種子保護**：delete/batchDelete 對 id∈{1,2,3}→`2222`（**僅拒刪**、不擋 update；§4）。

### 5.5 composite role-delta 審計（payload 任意 JSON、§2.3 confirmed）

- 形：`payload = { …user.audit_json()(password→"<redacted>"), "roles": ["R_X",…] }`（flat ＋ `roles` key）。
- **addUser**（INSERT）：`before=None`、`after={…新 user, roles:[新 codes]}`。
- **updateUser**（UPDATE）：`before={…舊 user, roles:[舊 codes]}`、`after={…新 user, roles:[新 codes]}` → 審計含「角色 [舊] → [新]」delta。舊 codes＝`roles_for_user(id)`（mutate 前 snapshot）。
- **deleteUser**（SOFT_DELETE）：**不改**既有 `soft_delete()`（roles 刪除時不變、波 0 live_smoke 測試不動）。
- redact／operator_id／trace_id 沿 005 機制（operator 由 handler 顯式餵、對齊 SC-004）。

### 5.6 wire DTO 映射（type-lie 防線、§7.2 ⚠️r）

| wire 欄 | entity 源 | 轉換 |
|---|---|---|
| `id` | `id: i64` | → JSON **number**（含 getAllRoles，**不**跟 mock string）；2^53 fail-loud 守衛 |
| `userName`/`nickName`/`userPhone`/`userEmail` | `user_name`/`nick_name`/… | snake→camel |
| `createTime`/`createBy`/`updateTime`/`updateBy` | `created_at`/`created_by`/… | snake→camel ＋ at→Time/by→By rename |
| `userGender`/`status` | `user_gender:i16`/`status:i16` | i16→string-enum `'1'|'2'`（null 保留） |
| `userRoles` | join `sys_user_role→sys_role.code` | `Vec<String>`（非 entity 直欄） |
| `roleName`/`roleCode`（getAllRoles） | `name`/`code` | rename |

DTO＝**手寫 wire struct**（serde rename ＋ i16↔enum 自訂 ser、純可測）；handler 做 `Model→DTO`，facade 仍回 raw `Model`（沿 007 pattern）。

### 5.7 base-web wrapper（★L4 MODAL-WIRING、§II#3／§III）

- **新建** `src/service/api/rev3-system-manage.ts`：export `addUser(model)`／`updateUser({...model,id})`（wrapper 併 id）／`deleteUser({id})`／`batchDeleteUser({ids})`；`fetchGetUserList`/`fetchGetAllRoles` 既有不動。
- **接 stub**：`index.vue` `handleDelete`→`deleteUser`／`handleBatchDelete`→`batchDeleteUser`；`user-operate-drawer.vue` `handleSubmit`→ add/update（依 operateType）。
- **fork-delta**：原行 `// request`/`console.log` 註解保留＋`rev3-inline` token 圈界；新 wrapper 檔標記圈界；rebase 衝突時原行註解同步更新。grep `rev3-inline` 可定位全部改動點。

### 5.8 enforce ＋ endpoint_coverage_lint

- 6 route 逐條 `route_layer(enforce_mw)`（含 2 讀端）；subject＝DB-fresh role code、驗既有 m002 policy（§2.3 矩陣）。漏掛＝裸端點。
- **endpoint_coverage_lint（⚠️x 移交、補回）**：正向檢查每掛 enforce 的 gated route 有 ≥1 policy（v0=role、v1=path、v2=method）；**容忍** m002 中尚無 handler 的 policy（addRole/getMenuList/getSystemSettings… 未來刀）。波 1 出口條件。

### 5.9 錯誤碼（envelope 凍結、§5.4／§I.3）

`0000` 成功；`2222` 業務拒（撞名／role 解不到／值域／soft-deleted 更新／種子保護刪／batch 含種子）；`enforce` 失敗 `5003`（HTTP 403）。除 auth 外一律 HTTP 200。13 碼矩陣凍結（⚠️f）、不新增碼。

### 5.10 結構與檔案

| 檔 | 動 | 職責 |
|---|---|---|
| `server/src/handler/system_manage.rs` | 新 | 6 handler fn（§5.2）；DTO 映射＋RI＋orchestration |
| `server/src/handler/mod.rs` | 改 | 註冊 `system_manage` 模組 |
| `server/src/handler/dto`（或就近、R4 定位） | 新 | `UserListItem`/`UserSearchParams`/`UserUpsertReq`/`AllRoleItem`（serde rename＋i16↔enum） |
| `server/src/model/facade/sys_user.rs` | 改 | `search_active`／`create`／`update`（§5.3） |
| `server/src/model/facade/sys_role.rs` | 改 | `all_active`／`find_active_by_codes` |
| `server/src/model/facade/sys_user_role.rs` | 改 | `replace_roles_in_txn`／`roles_for_users` |
| `server/src/main.rs` | 改 | 6 route ＋ `route_layer(enforce_mw)` |
| endpoint_coverage_lint（位置 R6） | 新/改 | 正向 policy 覆蓋檢查（⚠️x 移交） |
| `base-web/src/service/api/rev3-system-manage.ts` | 新 | 4 寫端 wrapper（updateUser 併 id） |
| `base-web/.../user/index.vue` | 改 | 接 handleDelete/handleBatchDelete stub |
| `base-web/.../user/modules/user-operate-drawer.vue` | 改 | 接 handleSubmit stub |
| `base-web/src/typings/api/*`（R2/R3 確認） | 改? | UserModel/UserUpsertReq wire 型（drawer Model 無 id、wrapper 帶 id） |

### 5.11 資料流（updateUser 為例）

```
base-web drawer handleSubmit → rev3-system-manage.updateUser({...model, id})
  → POST /systemManage/updateUser {userName,...,userRoles:[codes], id}
  → [enforce_mw] DB-fresh role code 驗 policy（非 R_SUPER→5003）
  → handler::update_user
      ├─ RI：find_active_by_id(id) 查無→2222；改名→find_active_by_name 撞名→2222；
      │      find_active_by_codes(userRoles) 解不到→2222；值域→2222
      ├─ facade::sys_user::update（mutate_in_txn）
      │     ├─ snapshot 舊：Model.audit_json + roles_for_user(id)
      │     ├─ update active_model（user_name 可變）
      │     ├─ replace_roles_in_txn(txn, id, role_ids)
      │     └─ AuditEvent{Update, before:舊 composite, after:新 composite}  ← 同 txn 寫 op-log
      └─ Res(()) → {data:null, code:"0000", msg}
```

## 6. 驗證（純測 + live + CDP modal；交 /speckit-specify 形式化）

- **純測**（test-first、零 DB/HTTP → C-V-2）：
  - DTO 映射：i16↔string-enum（status/gender、null）／snake→camel＋at-by rename／2^53 id fail-loud 守衛。
  - `UserSearchParams`→filter 組裝邏輯（可抽出的純函式部分：哪些欄 like/eq/略過）。
  - 種子保護謂詞（id∈{1,2,3}）／role 解析 count-match 判定。
- **live smoke**（#[ignore]、真 PG、**`--test-threads=1`**〔共表、memory `live-ignore-tests-need-serial`〕）：addUser→op-log INSERT payload 含 redact password＋roles；updateUser→UPDATE before/after **role-delta** 可見＋改名生效＋撞名 2222；deleteUser soft-delete＋種子保護 2222；batchDelete 前置校驗整批拒 vs 逐筆刪；getUserList filter（name 模糊/phone 精確）＋分頁＋userRoles join；getAllRoles id=number；enforce（非 R_SUPER 寫端→5003、R_ADMIN 讀 getUserList ok）。
- **CDP modal smoke（MODAL-WIRING 軌、`tests/000` CDP scripts）—— 必先 cutover、否則驗到 mock 非 rust-api**：
  - **問題**：base-web 全域預設打 Apifox mock（`VITE_HTTP_PROXY=Y`＋`.env.test` 的 `VITE_SERVICE_BASE_URL=apifox`）；不 cutover 的 CDP 會驗 mock、**沒驗到 rust-api**。
  - **cutover（沿 006、gitignored）**：master dev stack base-web（**31079**）建 gitignored `.env.test.local`（`VITE_SERVICE_BASE_URL=http://rust-api:31081`）→ Vite loadEnv `.local` 優先序 shadow 掉 mock → vite proxy 轉 rust-api；committed `.env.test`/`.env.prod` **不動**（mock 維預設、BASE-WEB-ADAPT 軌道）。〔example 實例 31076 連 mock 是視覺參考、與此無關〕
  - **CDP 流程**：quick-login（Super）→ 導航 `/manage/user` → 驗表格 envelope `code:0000`（getUserList rust-api 真資料）→ 開 user CRUD modal、`Runtime.evaluate` 填表單（含角色下拉、`getAllRoles` 在本刀 scope）→ 提交 add/update → 驗 modal 關＋列表刷新 → 刪除/批量刪除按鈕 → 驗。**不導航 `/manage/role`／`/manage/menu`**（rust-api 未實作、404）。
  - **static route mode**：CDP 跑 static（`.env` 出廠 `VITE_AUTH_ROUTE_MODE=static`），不呼 `getUserRoutes`、避開動態選單依賴（Menu 刀責任）。
  - **006 可複用**：page-id 32-hex fetch、`.env.test.local` 機制、`VITE_HTTP_PROXY=Y`、SOY_token localStorage、envelope 驗證；**新增**：表單 input/select 填值、modal 等待（poll `[role=dialog]` 關）、enforce `5003` 錯誤路徑。
  - **curl+CDP 雙軌（CHECKLIST §3.6）**：curl 直送 rust-api 驗 envelope shape＋psql 驗 DB；CDP 驗 base-web interceptor/modal —— **兩者皆要、不可只 curl**（curl 直送 ≠ modal 對齊）。
- **p95 SLA（⚠️a）**：list<300ms／write<500ms 納 C-V。
- **無新 crate**（members 固定 5、僅加模組到既有 server crate）→「新 crate 必跑 prod build」紀律**不觸發**；C-V 含 dev build 綠＋live smoke 即可（plan 期確認 prod Dockerfile 對既有 server crate 無逐 crate COPY 缺口）。

### SC 候選

getUserList 分頁+filter（name 模糊/phone 精確/null 略過/id ASC）＋userRoles join／getAllRoles 回 number／addUser argon2 預設密碼+role 指派+審計 redact／updateUser 改名+role-delta 審計+撞名拒／deleteUser soft-delete+種子拒刪／batchDelete 前置校驗 all-or-nothing／RI 五項（撞名/role 解析/值域/soft-deleted/種子）／enforce 既有 policy（R_ADMIN 讀 ok、寫 403）／endpoint_coverage_lint 綠／wire 零 type-lie／p95 達標／MODAL-WIRING 三 stub 接線／CDP 經 `.env.test.local` cutover **真打 rust-api（非 mock）**、`/manage/user` modal 全鏈綠。

## 7. Out of scope / Deferred / Backlog

- `getUserInfo`（006 已落地）／改密碼·重設密碼端點（base-web 無 password 欄、無 UI、塞之違 §I.1；密碼僅 addUser 預設值）。
- `system_settings`（§5.6、B 案否決、獨立刀）／審計查詢讀端+UI（⚠️b、波 2）／回收桶 restore（後續 feature）／policy 治理（行為島、獨立刀）。
- role/menu 的 CRUD（本刀只 user；getAllRoles 唯讀下拉）。
- alt-login·captcha·login lockout（⚠️m/⚠️w）；種子帳號 status-protection（user 明示僅拒刪、停用 Super 屬 admin 自負行為、本刀不另設防）。
- **`VITE_AUTH_ROUTE_MODE` 實機 `static` vs constitution §II#7 宣稱 `dynamic`-locked 落差** → DESIGN/constitution errata 登記；dynamic-mode CDP（呼 `getUserRoutes`、動態選單）待 Menu 刀。

## 8. Phase 0 research 待辦（交 /speckit-plan research.md；CLAUDE.md §3 三 grep）

- **R1** facade 真實簽名逐項 grep（`sys_user`/`sys_role`/`sys_user_role` 既有 `pub (async )?fn`＋`Result<>`；`soft_delete`/`roles_for_user`/`find_active_by_*` 確切形；`mutate_in_txn`/`AuditEvent` consumer 慣例；⚠️g 參照讀允許拷貝禁止）。
- **R2** wire 三端逐欄對齊（每端點：rust handler return type ↔ base-web `service/api` inline type＋`typings/api/*.d.ts` 宣告 ↔ component 內部 state）。重點：`User`/`UserList`/`UserSearchParams`/`AllRole` typings 欄與 enum（UserGender/EnableStatus）；getAllRoles mock `id:STRING` 是 mock 缺陷、rust 回 number。
- **R3 ⚠️ `user-operate-drawer.vue` NSelect `:value-field`**（`userRoles` 綁 roleCode〔string〕還 id〔number〕）——決定 handler 解析鍵；先按 roleCode 設計、grep 釘死；連帶確認 updateUser body 的 id 併法（typings 是否需新 `UserUpsertReq` 型）。
- **R4** rust 結構真實命名 grep：`handler/mod.rs` 註冊法（006 auth 模式）／`Res<T>` envelope helper／`AppError` variant 與碼映射（2222/5003）／`RequestContext`+operator_id 取法（`Extension`）／argon2 hash 呼法（m002/006 既有）／DTO 既有放置慣例。
- **R5** 種子保護謂詞確認：id∈{1,2,3} 是否 sequence-driven 確定（m002 不寫 id、空表 INSERT 序落 1/2/3）；改名後 id 不變佐證（JWT sub 用 id 非 name）；login 對 status=停用 的拒絕已在 006/007（本刀只設 status 值、不建 gate）。
- **R6** endpoint_coverage_lint 既有 lint 模板（`entity_access_lint` 為樣板、lint 放哪、波 0 ⚠️x 如何豁免、如何補回正向覆蓋檢查並容忍未實作 policy）。
- **R7** list `userRoles` N+1：`roles_for_users` batch 形 vs page≤10 loop 可接受（⚠️a list<300ms）；getUserList 索引（user_name partial-uniq 不走模糊查、≤50 admin 全表掃符 ⚠️a）。
- **R8** CDP modal smoke 接法 ＋ **cutover 驗證**：(a) gitignored `.env.test.local`（`VITE_SERVICE_BASE_URL=http://rust-api:31081`）在 master dev stack base-web〔31079〕生效（vite proxy → rust-api、shadow mock、curl `/proxy-default/...` 驗轉發）；(b) `tests/000/scripts` 既有 CDP（9229 gotchas、`cdp-login`/`cdp-nav`/`cdp-clear-and-relogin`）寫死 `localhost:31079`＝cutover 標的、沿用；(c) 新增 drawer 表單填值＋modal 等待（`[role=dialog]`）＋刪除按鈕 smoke 腳本；(d) `.env` 實機 `VITE_AUTH_ROUTE_MODE=static`（與 constitution §II#7 dynamic-locked 落差、§7 backlog）確認、CDP 於 static 驗收；(e) p95 量測法。

---

**brainstorm 定稿 2026-06-15；拍板見 §4（User 直刀③=A／6 端點 scope／update body 併 id／batch 前置校驗 all-or-nothing＋接受 infra 半套／list name·nick·email 模糊·phone 精確／casbin 零新增繼承 baseline／audit 含 role-delta／user_name 可變＋種子 id 僅拒刪／RI handler 層⚠️o／⚠️a 保守 SLA）＋既有權威 DESIGN §8.3·§5.1-5.4·§5.8·§7.1·§7.2·§3.1·§3.3 ＋ DECISIONS 待決③·⚠️a·⚠️o·⚠️u·⚠️x·⚠️r·⚠️p。零 migration。下一步：手動 `/speckit-specify`（input＝本檔；`before_specify` pre-hook 建 `008-user-management` feature branch；CLAUDE.md §3 — 不排進 brainstorm 流程觸發）。**
