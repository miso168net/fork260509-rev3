# 009-user-management — Phase 0 Brainstorm（spec-design）

> **波 2 第一刀**（資料島首刀；波 1 008 system_settings 以最輕 KV 打通 §8.1 9-step 全管線＋三個全專案首次後 → 波 2 上最重的 **User 刀**）。承 DESIGN §8.2 縱切清單 `User（rev2 016* 017）`。
> **本檔來歷**：借**前代 rev2 016（read：getUserList/getAllRoles）＋017（write：add/update/delete/batchDelete＋停用登入 gate＋argon2 預設密碼）**為設計參照、對齊**當前 lineage**（rust-api worktree `028289a`／base-web worktree `223bc83e`）；只借設計、**code 全新寫**（§I.5／⚠️g 受控參照：讀允許、拷貝禁止、防回歸）。本檔為 brainstorm 定稿 spec-design，作 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN **§8.2**（User 列覆蓋面＝`§5.1+§5.2〔含 password redact〕+§5.3+§5.4+§5.8 全套 + M:N join〔replace_roles_in_txn〕+ argon2 預設密碼 + 停用登入 gate + ★L4 MODAL-WIRING`，**權威 scope 句**）＋**§5.8**（Search/Filter/Pagination 橫切；**超範圍頁回空 `records`＋真實 `total`**）＋**§5.0** 矩陣 `sys_user` 列（soft-del✓／op-log✓CRUD／enforce✓`/systemManage/*User*`／search✓getUserList／xdb—／archetype A）＋**§5.3** RBAC＋**§3.4**（`enforce_mw` 本體不改、授權 subject＝DB-fresh roles 非 `claims.roles`）＋**§3.3** 單一 operator gate＋**§5.2／§5.7**（mutation 同 txn op-log＋6 審計欄成對）＋**§I.5** rust 全新寫＋**§I.6** archetype A 全 6 審計欄·facade 唯一管道＋**§7.1** wire 三端對齊＋**§7.4** `/api` strip＋**§8.6**（User-read 與 Role-read 拆兩刀；**getAllRoles 本刀僅下拉用、非完整 Role 刀**）。
> **相關拍板（DECISIONS §1）**：**⚠️r**（id 序列化＝逐欄忠實 typings：`CommonRecord.id`／`Role.id`／write `ids`→**number**、`userId`→string；2^53 fail-loud；**rev2 `Number()` 補丁移植時還原刪除**）／**⚠️o**（application-RI hybrid：**DB 能擋者〔unique〕續走 `DbErr`→handler `sql_err()` 映碼**＝23505 dup-userName 走此、**不做 app pre-check**）／**⚠️a**（perf：list 讀 p95<300ms／寫含同 txn 審計 p95<500ms；波 1 起驗收目標）／**⚠️x**（`endpoint_coverage_lint` 008 已立；本刀逐單元 bump `AS_BUILT_ROUTES`）／**⚠️y**（biz-msg 載穩定 i18n key、後端語言無關、文法 `biz.<entity>.<condition>`）／**⚠️aa**（BASE-WEB-I18N-WIRING ★ 軌道；本刀加 `backend.biz.user.*` locale＝scope (ii)）／**⚠️g**（受控參照）／**⚠️p**（demo `/plugin/excel` 用既有 `getUserList`、治理注意：日後下放非 Super 須同勾 endpoint policy）。
> **衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（引用一律用穩定 §錨、不用揮發行號；本檔不引用本機 memory）。

---

## 1. 目標一句話

把 `/manage/user` 從 mock 切到真 rust-api：補完使用者 **6 端點 CRUD**（getUserList／getAllRoles／addUser／updateUser／deleteUser／batchDeleteUser）＋角色 M:N join，並完成 base-web **MODAL-WIRING 重刀**（既有頁 stub handler 接真 fn）。沿 008 已立的 `require_policy`／op-log threading／envelope／`endpoint_coverage_lint` 骨架，**首次 exercise** §5.8 分頁·filter（含**空字串守門**＋**模糊查詢**、curl≠modal）、M:N join 寫（`replace_roles_in_txn`）、prod argon2、23505→2222 映射（⚠️o 首落地）、停用登入 gate。**零 migration／零 schema／零 entity 改／無新 crate**。

## 2. Context（探索蒐集、act-on-code 親驗）

### 2.1 前代 rev2 016（read）／017（write）參照（借設計、§I.5／⚠️g、不照拷）
- rev2 016 `getUserList`（`UserSearchParams`→`PageRes`）＋`getAllRoles`（`AllRole[]` 下拉）；017 `addUser`／`updateUser`（**userName immutable、password 不動**、id 在 body）／`deleteUser{id}`／`batchDeleteUser{ids}`、argon2 預設密碼 `123456`、停用登入 gate、**cannot-delete-self**。
- 借：端點形／facade 形／前端 drawer+index.vue 接法。**code 全新寫**。**replicate-list**（rev2 已踩過、rev3 沿正解）：roles 批次（`roles_for_users(&[i64])→HashMap`，固定 3 query/頁、無 N+1）／空字串 filter PRE-EMPT（skip `.filter`）／`replace_roles_in_txn`（delete-all+insert-all、未知/soft-deleted code 靜默丟）／停用登入 `status==2→code 1000`（**非 8889**——8889 在 base-web LOGOUT_CODES、吞訊息+洩枚舉）／write handler id `String→i64`（fail→2222）。
- **不照拷的 rev3 偏離**：rev2 017 op-log `ip:None` workaround → rev3 已 live 真 `operator_ip` INET（007/008、**不可帶回**）；rev2 id-as-string → rev3 ⚠️r number（**刪 rev2 `Number()` 補丁**）。

### 2.2 ★ 當前 lineage 已落地（不重做、MOOT）
- **`sys_user`(16 欄)／`sys_user_role`(複合 PK)／兩 FK／partial-unique `sys_user_user_name_active_uniq`（`WHERE deleted_at IS NULL`）／全部相關 casbin p-policy 均 002 baseline 已建**（m001 schema＋m002 seed＋m003 FK）→ **本刀零 migration**（不像 rev2 017 背 9 欄補完＋BIGSERIAL；`sys_user.id` 已 BIGSERIAL、無 setval）。
- casbin p-policy 已 seed：getUserList GET（R_SUPER＋**R_ADMIN**）／getAllRoles GET（R_SUPER＋R_ADMIN＋**R_USER_COMMON**）／addUser·updateUser POST R_SUPER／deleteUser·batchDeleteUser DELETE R_SUPER（**註冊路由＋掛 `require_policy` 即滿足 `endpoint_coverage_lint`、零 seed 變更**；User list **非 super-only**、R_ADMIN 可見）。
- 三 entity（`sys_user`／`sys_role`／`sys_user_role`）`Relation` enum **全空** → 無 `find_with_related`、user↔role join **一律手動兩步**。
- 008 已立可復用：`require_policy(path,method)` per-route layer（DB-fresh `roles_of_user`、5003→403 live）／op-log threading（`ctx.to_audit_operator(claims.uid)`→真 operator/IP/trace）／`PageRes<T>`（`{records,current,size,total}`、camelCase、**008 後仍零 list 消費者、User 首用**）／`endpoint_coverage_lint`（⚠️x）／envelope `Res<T>`＋`biz.<entity>.<cond>`→2222。

### 2.3 rust-api facade GAPS（`028289a` 親驗、本刀 BUILD）
- `facade/sys_user.rs` 現僅：`soft_delete`／`find_by_user_name`（active、含 password、login 用）／`find_by_id`（**含 soft-deleted**、getUserInfo 用）／`set_pointer`／`current_session_id_of`。**缺：`list_active`（分頁+filter）／`create`／`update`／`find_active_by_id`**。
- `facade/sys_user_role.rs` 現僅 `roles_of_user(uid)→Vec<String>`（回 **code**）。**缺：role-id reader（`Vec<i64>`、與 code 版並存）＋`replace_roles_in_txn`**。
- `facade/sys_role.rs` 現零查詢 fn（僅 `impl SoftDeletable`）。**缺：`find_active` list fn**（getAllRoles 用）。
- **prod argon2 `hash_password` 不存在**：`auth/password.rs` 僅 `verify()`；現有 `hash()` 是 `#[cfg(test)]` 測試專用（固定 salt、非 OsRng）。**缺：prod `hash_password`**（`Argon2::default()`＋`SaltString::generate(OsRng)`、對齊 m002 seed 配方）。
- `error.rs`：所有 `DbErr`→Internal(5000)；**23505→2222 尚未落地**（error.rs 註明延「波 2 CRUD」）＝本刀首落地（⚠️o）。
- workspace members 不變（**無新 crate** → 免 prod-image-build mandate、CLAUDE.md §3）。

### 2.4 base-web 現況（§I.1 權威、`223bc83e` 親驗）— 既有頁、stub handler
- **頁/型已存在**（不像 008 net-new）：`views/manage/user/{index.vue, modules/{user-operate-drawer,user-search,user-session-policy-modal}.vue}`；`typings/api/system-manage.d.ts` 已宣告 `UserSearchParams`（`{current,size}`＋nullable `userName/userGender('1'|'2')/nickName/userPhone/userEmail/status('1'|'2')`）／`User`／`AllRole`。
- **active stack＝axios `@/service/api/system-manage.ts`**（6 GET、**無 CRUD**）；`index.vue` 只 import `fetchGetUserList`。
- **★ CRUD 全 stub（假綠陷阱）**：`index.vue` `handleDelete`/`handleBatchDelete`＝console.log；`operate-drawer` `handleSubmit`＝validate+toast+close+emit、**零 HTTP**。drawer `Model`＝7 欄 `UserModel`（`userName/userGender/nickName/userPhone/userEmail/userRoles/status`、**無 id、無 password**），驗證僅 `userName`+`status` required。
- 角色下拉＝`NSelect multiple`、option `{label:roleName, value:roleCode}`、綁 `model.userRoles`（string[] of **code**）；`getRoleOptions` 有 **mock-only workaround**（self-inject userRoles 為 options）、**真 getAllRoles 上線後移除**。
- naive-ui 元件（NSelect/NDrawer/NRadioGroup/NDataTable/NPopconfirm/NTag）皆已在 `components.d.ts`（**無新元件、無 `components.d.ts` 重生**）。
- **MODAL-WIRING 授權已備**（constitution §III.2、**零 amendment**）：(a) 既授 `operate-drawer` create/update + **`index.vue` 的 delete/batchDelete handler**（v1.0.0）／(b) 既授 `user/index.vue` `hasAuth` gating（v1.3.0）——rev2 當年需 v1.2.0 amendment、rev3 ⚠️i-1 一次全授。

### 2.5 §5.0 矩陣對 `sys_user` 的面（DESIGN §5.0 親查）
`| sys_user | soft-del ✓ | op-log ✓(CRUD) | enforce ✓(/systemManage/*User*) | search ✓(getUserList) | xdb — | archetype A |`
- **Exercise（全套）**：§5.1 soft-delete（delete/batch + list `find_active` 排除）／§5.2 審計同 txn（**含 password redact**：讀端 DTO 不出 password）／§5.3 RBAC（list R_SUPER+R_ADMIN、寫 R_SUPER）／§5.4 envelope／§5.8 分頁·filter（**首 exercise**、含空字串守門＋模糊）／M:N join 寫（`replace_roles_in_txn`）。
- **N/A**：§5.6 熱 KV／§5.9 region·xdb／§5.10 AES 磁碟層（皆不套用 sys_user）。

### 2.6 三端 wire shapes（rust ↔ base-web ↔ mock、§7.1 對齊）
- **GET getUserList** → `PageRes<UserListItem>`：`{data:{records,current,size,total}, code:"0000", msg}`。record key（mock 親驗）：`id`(**number**)／`userName`／`userGender`("1"/"2")／`nickName`／`userPhone`／`userEmail`／`status`("1"/"2")／`userRoles`(**string[] of role code**)／`createBy/createTime/updateBy/updateTime`。**捕獲請求實證空字串序列化**：`?current=1&size=10&status=&userName=&userGender=&nickName=&userPhone=&userEmail=`（serde→`Some("")` 非 `None`）。
- **GET getAllRoles** → flat `AllRole[]`（無分頁），`{id:**number**, roleName, roleCode}`；`roleCode` 即下拉 option value、對齊 `userRoles[]`。**mock 回 `id` 為 string("1")＝mock 缺陷**（§7 權威序：typings 優先、mock 字串不對齊）→ rust 出 **number**（⚠️r）。
- **POST add/updateUser → null；DELETE delete{id}/batchDelete{ids} → null**（mock 無捕獲、alova-only）。payload `UserModel`＝7 欄 Pick（**無 id、無 password**）；updateUser 的 id 由 wrapper 補進 body（`{...model, id: rowData.id}`、parse `String→i64` fail→2222）。

### 2.7 消費者
- **直接**：admin 後台使用者管理（列表/搜尋/新增/改/刪/批刪/指派角色）。
- **下游**：波 2 後續 Role 刀（借 getAllRoles 薄讀外的完整 Role CRUD＋三權限 modal）／Menu 刀（D 區 follow-up：getUserRoutes＋menu policy）／波 3 Auth·Token·Session 合刀（接 `updateUserSessionPolicy`＋即時 token 撤銷、本刀 defer）。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | CRUD scope 邊界 | **6 端點含 batchDeleteUser；`updateUserSessionPolicy`＋`user-session-policy-modal.vue` 延波 3**（user 拍） | batch 幾乎免費（複用 soft_delete＋cannot-delete-self、UI 已有按鈕）；updateUserSessionPolicy lineage＝rev2 029 session-policy（DESIGN §6.1 列於 /manage/user view、但屬 §4.3 單一 session 行為島）、硬拉進來＝行為島耦合進資料島刀。否決「也含 session-policy」（提前耦合波 3）／「最小只單筆 delete」（留 console.log batch stub＋seeded 未註冊 policy、狀態尷尬） |
| D2 | 停用即時性 | **接受已發 token ≤1h staleness；僅登入入口 gate `status==Some(2)→code 1000`**（user 拍） | 對齊 rev2 017；不在每請求熱路徑（`enforce_mw`/getUserInfo）加 status 查詢（守 ⚠️a perf）；即時撤銷屬波 3 行為島、**不前拉**。新登入被擋、已發 token 自然到期。code **1000 非 8889**（D 見 §2.1）。security-adjacent、已向 user 明示並核可 |
| D3 | migration＋filter 語意 | **零 migration；getUserList 字串 filter 模糊（`userName`/`nickName`/`userEmail`＝`ILIKE '%term%'` 大小寫不敏感、input wildcard escape）＋`userPhone`/`userGender`/`status`＝精確；空字串一律跳過該 filter（§5.8）**（user 拍欄位選擇） | 表/約束/policy 002 已備（§2.2）；btree 對 leading-wildcard 模糊無用、不加；小 admin 表 seq-scan 可接受、`pg_trgm` GIN＝**未來選項**（屆時才一條 migration、本刀不做、登 backlog）。`Migrator::up delta == 0` |
| D4 | 23505 dup-userName | **靠 partial-unique 約束 catch、`DbErr::sql_err()→UniqueConstraintViolation→biz 2222`（`biz.user.duplicateUserName`）、不做 app pre-check**（依 ⚠️o、工程） | ⚠️o 明定「DB 能擋者（unique）續走 DbErr→handler sql_err() 映碼」→ 避 TOCTOU pre-check；首落地 23505→2222（error.rs 延此刀）；generic `From<DbErr>→Internal(5000)` 對非 unique 不動。僅 addUser 相關（updateUser userName immutable、無 dup 風險） |
| D5 | id 序列化 | **`id`/`AllRole.id`/write `ids`→JSON number；2^53 fail-loud；刪 rev2 `Number()` 補丁**（依 ⚠️r、工程） | ⚠️r 逐欄忠實 typings（`common.d.ts id:number`）；**不抄 auth 的 `to_string()`**（那是 `userId`/`MenuRoute.id`）；mock `AllRole.id` string＝缺陷不對齊（§7 權威序） |
| D6 | MODAL-WIRING 授權 | **既有頁 inline 接線走 MW (a)（drawer create/update＋index.vue delete/batchDelete）＋MW (b)（hasAuth gating）、零 constitution amendment**（依 constitution §III.2、工程確認） | §III.2 (a)(b) 明文涵蓋本刀全部 inline 觸點、rev3 ⚠️i-1 一次全授；每處依 fork-delta 紀律標 `rev3-inline MW(a/b)`（修改型原行註解保留）。驗收**斷言真發 request**（非 toast、stub 假綠） |
| D7 | feature 粒度 | **單一 feature branch（read+write 併一刀）、~4 Workflow 單元**（工程） | rev2 016/017 拆因 017 背 schema weight（9 欄+BIGSERIAL）；rev3 002 已完備、拆無理由。CHECKLIST 波 2 框「User 首刀」單刀。單元見 §12 |
| D8 | 預設密碼＋argon2 | **addUser 預設 `123456`、新 prod `hash_password`（`Argon2::default()`+`SaltString::generate(OsRng)`、對齊 m002 配方）；updateUser 不動 password、表單不收 password**（工程） | 對齊 rev2 017＋m002 seed 驗得過；改密碼＝獨立未來刀。非 default 參數會讓新 user 與 seed 漂移 |
| D9 | op-log threading | **addUser＝首個 INSERT op-log consumer（`entity_id=Some(new_id)` insert 後回填、同 txn）；updateUser 沿 008 UPDATE 形（`entity_id=Some(id)`）；delete/batch 復用已證 SOFT_DELETE；真 operator_ip INET（不抄 rev2 `ip:None`）**（工程） | replace_roles 與 user 寫入**同一 `mutate_in_txn`**（否則 roles/op-log desync）；007/008 threading 既證 |
| D10 | password redact | **list/讀端 DTO 不含 password；`find_by_user_name`（含 password）僅 login verify 用**（依 §5.2、工程） | DESIGN §8.2 User 列明列「§5.2 含 password redact」；`list_active` 投影排除 password 欄 |
| D11 | getAllRoles 範圍 | **`sys_role::find_active` 薄讀、下拉用；非完整 Role 刀**（依 §8.6、工程） | §8.6 User-read 與 Role-read 拆兩刀；getAllRoles 只供 user 表單角色 option、Role CRUD/三權限 modal 另刀 |
| D12 | cannot-delete-self | **單筆或批次含操作者自身 id → 整筆/整批 2222 拒絕、無部分執行（`biz.user.cannotDeleteSelf`）**（rev2 lesson、工程） | handler 層比對 `id == ctx.operator_id`；防自鎖；批次 whole-reject 非 partial |

## 4. 元件設計（act-on-code、當前 lineage seam 名）

### 4.1 `facade/sys_user.rs`（改：加 4 fn、archetype A、entity:: 合法）
- `list_active(conn, page, size, filters) -> Result<(Vec<Model>, u64), DbErr>`：`SoftDeletable::find_active()`＋filter（D3：字串模糊 `ILIKE`／enum 精確／空字串 skip）＋`PaginatorTrait`（`.paginate(size).fetch_page(page-1)`＋`.num_items()` 取 filtered `total`；**超範圍頁回空 records＋真 total**、§5.8）；sort `id DESC`。**total 與 fetch 套同 filter**。
- `create(conn, fields, password_hash, operator, trace) -> ...`／`update(conn, id, fields, operator, trace) -> Result<Option<Model>, DbErr>`：經 `mutate_in_txn`、6 審計欄成對（§5.7）、同 txn op-log（D9）；update 查無 id→`Ok(None)`（handler→2222）。`create` 不接 plaintext（hash 在 handler 算好傳入、見 4.4）。
- `find_active_by_id(conn, id)`：CRUD list/update 用（**非** `find_by_id` 含 soft-deleted 版）。
- `build_*_active_model` 純測 seam（欄映射、updated_at/by·deleted_at/by Set）。**lint**：entity:: 僅 facade 合法。

### 4.2 `facade/sys_user_role.rs`（改：加 role-id reader＋replace 寫）
- `role_ids_of_user(conn, uid) -> Result<Vec<i64>, DbErr>`：與既有 `roles_of_user`（code 版）並存、不動既有。
- `replace_roles_in_txn(txn, uid, role_codes: &[String], operator, trace) -> ...`：delete-all+insert-all、**未知/soft-deleted code 靜默丟棄**；**必在 user 寫入同一 `mutate_in_txn`**（D9）。code→role_id 解析經 `sys_role`。
- `roles_for_users(conn, uids: &[i64]) -> HashMap<i64, Vec<String>>`：list 批次組裝（**無 N+1**、固定 3 query/頁）。

### 4.3 `facade/sys_role.rs`（改：加 find_active list fn）
- `find_active(conn) -> Result<Vec<Model>, DbErr>`：getAllRoles 薄讀（D11）。

### 4.4 `auth/password.rs`（改：加 prod hash_password）
- `hash_password(plain: &str) -> Result<String, _>`：`Argon2::default()`＋`SaltString::generate(&mut OsRng)`、對齊 m002 seed＋既有 `verify()`（D8）；現有 `#[cfg(test)] hash()` 不動。

### 4.5 `handler/system_manage.rs`（新；user 6 端點、/systemManage/* 家族）
- `get_user_list(State, Extension<Claims>, Query<UserSearchParams>) -> Res<PageRes<UserListItem>>`：filter normalize（D3、空字串→None、模糊/精確分流）＋page normalize（current 默 1、size 默 10 clamp[1,100]）→ `list_active`＋`roles_for_users` 組裝（**DTO 不含 password**、D10、`id`=number D5）。
- `add_user(...)`：hash（4.4）→ `create`＋`replace_roles_in_txn` 同 txn（D9）→ 23505 經 `sql_err()`→2222（D4）。
- `update_user(...Json<UpdateReq{...UserModel,id}>)`：id `String→i64`（fail→2222）→ `find_active_by_id`（查無→2222）→ `update`＋`replace_roles_in_txn` 同 txn（**userName/password 不動**、D8）。
- `delete_user{id}`／`batch_delete_user{ids}`：cannot-delete-self（D12、`id==ctx.operator_id`→2222 whole-reject）→ `soft_delete`（批次同 txn loop）。
- `get_all_roles(...)`：`sys_role::find_active`→`AllRole[]`（D11、`id`=number）。
- DTO inline、`#[serde(rename_all="camelCase")]`、零 path-root `entity::`（走 facade）。

### 4.6 `main.rs`（改：註冊 6 路由；復用 008 `require_policy`、enforce.rs 不動）
- **`require_policy` 不改**（008 已建、enforce.rs 零改）；6 路由各掛 `enforce_mw`→`require_policy(path,method)`（per-route `route_layer`）；`audit_mw` 最外層自動覆蓋。`mod handler::system_manage;`。
- p-policy m002 已 seed（§2.2）→ **零 seed migration**。

### 4.7 `error.rs`（改：23505→2222 首落地、⚠️o）
- 寫端 `DbErr::sql_err()→SqlErr::UniqueConstraintViolation→AppError::Biz("biz.user.duplicateUserName")`（2222）；其餘 `From<DbErr>→Internal(5000)` 不動（D4）。確切落點（handler-local match vs facade 返 typed err）plan 定（⚠️o「handler sql_err() 映碼」）。

### 4.8 login handler（改：停用 gate、D2）
- 既有 login 流程 `find_by_user_name`→verify password 後加 `status==Some(2)→code 1000`（**入口 only**、不入 enforce_mw/getUserInfo 熱路徑）。

### 4.9 `server/tests/endpoint_coverage_lint.rs`（改：bump AS_BUILT_ROUTES）
- 每註冊 user 路由的單元**同 commit** bump `AS_BUILT_ROUTES`（+6 條 route literal、registered==as-built＋policy-governed⊆m002 seed、⚠️x/S9）；route literal 與 seed 字串逐字對齊（typo→panic）。

### 4.10 base-web wire＋frontend（既有頁 MODAL-WIRING、D6）
- **L3 WRAPPER**：新 `service/api/rev3-system-manage.ts`（**direct-path import、非 barrel**、避 vite stale-export）：`fetchAddUser`/`fetchUpdateUser`(補 id)/`fetchDeleteUser`/`fetchBatchDeleteUser`/`fetchGetUserList`；write-model inline（§7.1）。
- **L4 MODAL-WIRING (a)**：`operate-drawer` `handleSubmit`（add→addUser／edit→updateUser 帶 id）、`index.vue` `handleDelete`/`handleBatchDelete`→真 fn（標 `rev3-inline MW(a)` 原行註解保留）；移除 `getRoleOptions` mock workaround（真 getAllRoles 上線後）。
- **L4 MODAL-WIRING (b)**：`user:add/edit/delete` 等 `hasAuth` gating（標 `rev3-inline MW(b)`）。
- **BASE-WEB-I18N-WIRING ★（⚠️aa scope (ii)）**：locale `backend.biz.user.*`（`duplicateUserName`/`cannotDeleteSelf`/`notFound`、zh-cn/en-us）。
- typings `UserSearchParams`/`User`/`AllRole` **已存在**（§2.4）→ 無新 typings 檔；plan 確認三端對齊、若有 gap 才 ADAPT。

## 5. wire / 碼 / INET / i18n
- **wire 端點 ×6**（§I.1 兩端俱在、§7.1 對齊 typings；`/api` strip §7.4）；`id`=number（D5/⚠️r）。
- 碼：成功→`0000`；biz（dup-userName/cannot-delete-self/notFound/invalid id）→`2222`、wire `msg`＝`biz.user.<condition>`（locale `backend.biz.user.<condition>`、⚠️y 文法／⚠️aa 接線）；policy deny→`5003`/403；停用登入→`1000`（D2、復用既有 auth key、非新 biz）。
- **INET**：add/update/delete op-log `operator_ip` 真 INET round-trip（D9、007/008 threading）；**add＝首個 INSERT op-log consumer**。

## 6. 範圍邊界

**IN**：facade `sys_user`(list_active/create/update/find_active_by_id)＋`sys_user_role`(role_ids_of_user/replace_roles_in_txn/roles_for_users)＋`sys_role`(find_active)／`auth/password` prod hash_password／handler 6 端點（filter 空字串守門＋模糊 D3、cannot-delete-self、password redact）／23505→2222（⚠️o 首落地）／停用登入 gate／main 6 路由分層＋`endpoint_coverage_lint` bump／base-web rev3-system-manage.ts wrapper＋MODAL-WIRING (a)(b)＋`backend.biz.user.*` i18n／純測＋live（op-log INET、23505 dup、cannot-delete-self、filter 空字串/模糊）＋CDP 全鏈（**刻意帶空 param＋模糊關鍵字**）。

**OUT（遞延）**：`updateUserSessionPolicy`＋`user-session-policy-modal.vue`（**波 3** Auth·Token·Session 合刀、D1）／即時 token 撤銷（接受 ≤1h staleness、D2）／完整 Role 刀（getRoleList/addRole/三權限 modal、§8.6）／Menu 刀（getUserRoutes＋menu policy、D 區 follow-up）／改密碼（updateUser 不動 password、D8）／`pg_trgm` GIN index（D3 未來選項）／User→User01 alias（**006 已建** getUserInfo、無 action）。

**MOOT（lineage already-done、不重做）**：`sys_user`/`sys_user_role` schema＋seed＋FK＋partial-unique＋casbin p-policy（m001/m002/m003）／`require_policy`·op-log threading·`PageRes`·`endpoint_coverage_lint`·envelope（008）／`mutate_in_txn`·`From<DbErr>`·`soft_delete`·`find_by_user_name`（004/005/006）。

## 7. enforce/track pattern 留痕（`/speckit-plan` Constitution Check 對齊用）
- **無 constitution amendment**：軌道 RUSTAPI-SOURCE-ISOLATION／BASE-WEB-WRAPPER（rev3-system-manage.ts）／**MODAL-WIRING (a)(b) 既授**（§III.2、D6、rev3 ⚠️i-1 一次全授；rev2 當年 v1.2.0 amendment 在 rev3 不需要）／BASE-WEB-I18N-WIRING ★（⚠️aa、加 `backend.biz.user.*`＝scope (ii)）皆既授；典型 ADAPT 不觸（typings 已存在）。
- 授權 subject＝DB-fresh roles（§3.4、復用 008 `require_policy`、不信 `claims.roles`）；`enforce_mw`·`audit_mw` 本體不動。
- 23505→2222 首落地守 ⚠️o（DB-blockable unique→sql_err() 映碼）。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）
- **FR-001** R_SUPER+R_ADMIN 可分頁查使用者列表（filter：userName/nickName/userEmail 模糊、userPhone/userGender/status 精確、**空字串跳過**；超範圍頁回空 records+真 total）。**FR-002** 列表/讀端**不回 password**（§5.2 redact）。**FR-003** roles 批次組裝無 N+1。
- **FR-004** R_SUPER 可新增使用者（預設密碼 123456 argon2、指派角色 replace_roles 同 txn、INSERT op-log 真 operator/IP/trace）；**重複 userName→2222**（`biz.user.duplicateUserName`、⚠️o）。**FR-005** R_SUPER 可改使用者（**userName/password 不動**、id 在 body、查無→2222、UPDATE op-log+replace_roles 同 txn）。
- **FR-006** R_SUPER 可單筆/批次 soft-delete；**含自身 id→整筆/批 2222 拒絕**（`biz.user.cannotDeleteSelf`、無 partial）。**FR-007** R_SUPER+R_ADMIN+R_USER_COMMON 可取啟用角色全量（getAllRoles 下拉、`id`/`roleCode`）。
- **FR-008** 所有端點 `require_policy` per-route（DB-fresh roles、§3.4）；非授權→5003/403 不洩值。**FR-009** 停用使用者（status==2）**登入入口**被擋（code 1000、非 8889）；已發 token ≤1h 自然到期（D2）。
- **FR-010** wire `id`=number（⚠️r）、envelope 不破 003 契約、biz msg 載 i18n key（⚠️y）。**FR-011** base-web 既有頁 stub handler 接真 fn（drawer submit＋index.vue delete/batch **真發 request**）、`hasAuth` gating；getRoleOptions mock workaround 移除。**FR-012** 零 migration/schema/entity 改、無新 crate、`enforce_mw`/`audit_mw`/既有 base-web 檔（除 MW 授權 inline）零回歸。
- **SC**：SC-001 list 分頁+模糊/精確 filter+空字串跳過正確（純測+live+CDP 帶空 param）。SC-002 list/讀端零 password（live）。SC-003 addUser→DB 列+roles+INSERT op-log(真 INET)；dup userName→2222（live）。SC-004 updateUser userName/password 不變、roles 替換、UPDATE op-log（live）。SC-005 delete/batch soft-delete；含自身→2222 whole-reject（live）。SC-006 非授權→5003/403（live+CDP）。SC-007 停用→登入 1000（live）。SC-008 三端 wire 對齊零型謊（id=number）+ i18n toast 經 `$t`+寫入真發 request（CDP）。SC-009 三守恆全綠（含 bump 後 endpoint_coverage_lint）。SC-010 零回歸（FR-012）。

## 9. C-V 驗收（草案、live 一律 `--test-threads=1` serial+DATABASE_URL；rust 容器內 `docker exec`）
- **C-V-1** filter normalize 純測（空字串→None／模糊 ILIKE pattern+wildcard escape／enum '1'/'2'→i16／page normalize clamp）→ FR-001。
- **C-V-2** `build_*_active_model` 純測（6 審計欄成對 Set）→ FR-004/005。
- **C-V-3** id 序列化 2^53 fail-loud 純測 → FR-010。
- **C-V-4** live addUser→psql `sys_user`(列+hash 驗得過)+`sys_user_role`(roles)+`sys_operation_log` 末列(INSERT、entity_id=新 id、operator_ip 真 INET)；dup userName→2222 → SC-003。
- **C-V-5** live updateUser→userName/password 不變、roles 替換、UPDATE op-log → SC-004。
- **C-V-6** live delete/batch→soft-delete(deleted_at/by)；含操作者自身→2222 whole-reject(無 partial) → SC-005。
- **C-V-7** live list→分頁+模糊(userName 子字串)+精確(userPhone)+空字串跳過(回全量非 0 列)+超範圍頁(空 records+真 total)+讀端零 password → SC-001/002。
- **C-V-8** live 非授權(Admin POST/DELETE、User GET 等)→5003/403 → SC-006；停用 user 登入→1000 → SC-007。
- **C-V-9** `endpoint_coverage_lint`（`cargo test -p server --test endpoint_coverage_lint`）→ SC-009：registered==as-built(含 +6)＋policy-governed⊆seed。
- **C-V-10** CDP 經 front-nginx 真 `/api`：Super 登入→user 頁→搜尋(**刻意空 param＋模糊關鍵字**、抓空字串陷阱)→新增/改(角色 chip 真 code)/刪→真發 request+toast 經 `$t`+DB 變；非 Super→403 → SC-008。
- **C-V-11** 零回歸（/health、login/getUserInfo/008 settings/enforce 不變、`entity_access_lint` 綠、diff 零 schema/entity、base-web 既有檔除 MW 授權 inline 外不動）→ SC-010。
- **C-V-12** prod image build（無新 crate、確認新 handler/facade/lint 編入 prod target）→ build 面。

## 10. Files（當前 lineage、BUILD vs ALREADY）
**BUILD（改/新）**：`rust-api/server/src/model/facade/{sys_user.rs(改),sys_user_role.rs(改),sys_role.rs(改)}`／`auth/password.rs`(改 hash_password)／`server/src/handler/system_manage.rs`(新)＋`handler/mod.rs`／login handler 所在檔(停用 gate、plan 接地④定、改)／`main.rs`(6 路由+分層+mod)／`error.rs`(23505→2222)／`server/tests/endpoint_coverage_lint.rs`(bump)／base-web `src/service/api/rev3-system-manage.ts`(新)＋`src/views/manage/user/{index.vue, modules/user-operate-drawer.vue}`(MW (a)(b) inline)＋`src/locales/langs/{zh-cn,en-us}.ts`(`backend.biz.user.*`、⚠️aa/⚠️y)。
**ALREADY（不動）**：`entity/src/{sys_user,sys_role,sys_user_role}.rs`／schema+seed+FK+partial-unique+casbin p-policy（m001/m002/m003）／`require_policy`·op-log threading·`PageRes`·envelope·`endpoint_coverage_lint` 骨架（008）／`mutate_in_txn`·`From<DbErr>`·`soft_delete`·`find_by_user_name`（004/005/006）／`typings/api/system-manage.d.ts`（User/UserSearchParams/AllRole 已宣告）。

## 11. forward-compat / 下游 + plan-phase 接地清單
- **波 2 後續**：Role 刀（完整 getRoleList/addRole/三權限 modal、借 getAllRoles 外的 sys_role CRUD）／Menu 刀（getUserRoutes＋menu policy、收 008 留的 system-settings 選單可見性 D 區 follow-up）。
- **波 3**（Auth·Token·Session 合刀）：`updateUserSessionPolicy`＋session-policy-modal（§4.3 單一 session 機）＋即時 token 撤銷（停用即踢）。
- **plan-phase 須 act-on-code 接地**（不臆測）：① wire 三端對齊逐欄 grep（rust DTO ↔ `typings/api/system-manage.d.ts` ↔ component state；含 `userRoles` code[] 與 getAllRoles `roleCode` 對齊）／② 23505→2222 確切落點（handler match vs facade typed err、⚠️o）／③ MODAL-WIRING (a)(b) 逐觸點 file:line＋upstream 衝突評估＋`rev3-inline` 標記（§III fork-delta）／④ login handler 所在檔與停用 gate 插點／⑤ `AuditOperation::Insert` entity_id 回填 threading（add 首用）／⑥ filter wildcard escape + SeaORM `ILIKE` 構式（`Expr::col(...).ilike()` vs `Column::contains` 大小寫）／⑦ `endpoint_coverage_lint` 確切斷言碼形（+6 route literal、對齊 008 方向）。

## 12. Workflow 單元分解（預想、階段 2 依實際相依定）
- **U1 reads**：`sys_user::list_active`（分頁+filter D3）＋`sys_user_role::roles_for_users`（批次）＋`sys_role::find_active`＋handler get_user_list/get_all_roles＋main 2 路由＋lint bump。純測：filter normalize/page normalize/id 序列化。
- **U2 create/update**：`sys_user::create/update/find_active_by_id`＋`auth::hash_password`＋`sys_user_role::replace_roles_in_txn`＋23505→2222（error.rs）＋handler add_user/update_user（op-log INSERT/UPDATE 同 txn）＋main 2 路由＋lint bump。
- **U3 delete + gate**：`delete_user`/`batch_delete_user`（cannot-delete-self）＋停用登入 gate（status==2→1000）＋main 2 路由＋lint bump。
- **U4 base-web MODAL-WIRING**：rev3-system-manage.ts wrapper＋operate-drawer/index.vue 接線（MW (a)(b)）＋移除 getRoleOptions workaround＋`backend.biz.user.*` i18n。
> rust 全程 serial（共用 target）；每單元邊界主線復核＋`git show --stat HEAD`＋load-bearing 容器內自驗＋bump submodule pin（S9 逐單元、不延末刀）；base-web commit `--no-verify`；★ 絕不 push/merge（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
