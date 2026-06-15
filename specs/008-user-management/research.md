# Research: User Management（008）— Phase 0

> Phase 0 output（/speckit-plan）。**CLAUDE.md §3 紀律：act on actual code、不信 brainstorm 假設**。
> 本檔結論由 7-agent 平行 grep 真實 `rust-api`／`base-web` 實碼產出（非 brainstorm 推測）；每條附 grep 實證；**★ 標 implementer 必須處置的實碼缺口**。

## R1 — facade 簽名（既有 vs 新增）

- **Decision**: 9 個既有 facade fn 原樣複用；**新增 7 個**。
  - 既有（grep 確認）：`sys_user`＝`find_active()→Select<Entity>`／`find_active_by_name(db,&str)→Option<Model>`／`find_active_by_id(db,i64)→Option<Model>`／`soft_delete(db,id,operator:AuditOperator,trace_id:Option<String>)→bool`／`impl AuditSerialize::audit_json()`（15 欄、redact password、**不含 current_session_id**）；`sys_role`＝`find_active()`／`find_active_by_ids(db,&[i64])→Vec<Model>`（empty-ids guard 回 `Ok(vec![])`）；`sys_user_role`＝`find_role_ids_by_user_id(db,i64)→Vec<i64>`／`roles_for_user(db,i64)→Vec<String>`（role **codes**）。
  - 新增 7：`sys_user::{search_active, create, update}`、`sys_role::{all_active, find_active_by_codes}`、`sys_user_role::{replace_roles_in_txn, roles_for_users(batch)}`（簽名見 data-model.md）。
- **Rationale**: facade-only archetype（`model/mod.rs:2`「entity 存取唯一管道為 facade」）；`entity_access_lint`（`server/tests/entity_access_lint.rs`）為 build-failing guard、禁 facade 外裸 `entity::`。
- **Alternatives**: handler 內聯 filter/list — 被 §I.5 + entity_access_lint 否決。

## R2 — wire 三端型映射（entity ↔ wire ↔ base-web）

- **Decision**: User/Role 鏈**一致、association 走 `roleCode`（string）非 role id**。entity `sys_user.id:i64`、`sys_role.{id:i64, code:String}`；wire id → JSON **number**（⚠️r：`CommonRecord.id`／`Role.id`）、`getUserInfo.userId` → string（as-built 已如此）；base-web `User.userRoles:string[]`、`AllRole=Pick<Role,'id'|'roleName'|'roleCode'>`、NSelect 綁 `value:item.roleCode`。
- **Rationale**: `system-manage.d.ts:29,52`＋`common.d.ts:37`＋`user-operate-drawer.vue:76-79`；`roles_for_user→Vec<String>`(role.code)。
- **Alternatives**: 用數字 role id 關聯 — 否決（base-web 寫死 roleCode 為 NSelect value-field、不對齊＝runtime bug）。

## R3 — component state（Model／NSelect／stub）

- **Decision**: drawer Model＝`Pick<User,'userName'|'userGender'|'nickName'|'userPhone'|'userEmail'|'userRoles'|'status'>`（**排除 id**），但 `handleInitModel` 在 edit 把 `rowData` 拷進 model → **edit 模式 model 帶 id**（wrapper updateUser 從 `model.id` 取）。`handleSubmit`（L105-111）是 stub（validate→toast→close→emit、無 request）。`index.vue` `handleDelete(id:number)`（L154-158）＋`handleBatchDelete`（L147-152）stub（`console.log` + `// request`）；row-key=`row.id`（numeric）、`checkedRowKeys` via `useTableOperate(data,'id',getData)`。
- **★ R3 裁定**：userRoles NSelect value-field ＝ **`roleCode`**（推翻 brainstorm「先按 roleCode、待 grep 釘死」的不確定 → 現確認）。
- **Rationale**: 實讀 `user-operate-drawer.vue:43-60,93-111`、`index.vue:140-159,189`。

## R4 — handler／error 結構慣例

- **Decision**: handler＝`pub async fn`（`handler/<mod>.rs`、`handler/mod.rs` `pub mod` 註冊、`main.rs` route）；006 範式＝`State(AppState)+Extension(RequestContext)+Json/Query → Result<Res<T>,AppError>`；**DTO co-located 於 handler 模組**＋`#[serde(rename_all="camelCase")]`（沿 LoginReq/UserInfo、**無 `model/dto/` 資料夾**）；`Res<T>` via `envelope::{Res::ok, ok_msg, err, err_msg}`；`AppError` 8 個可發 constructor（含 `biz`→`2222`、`permission_denied`→`5003`、`internal`→`5000`）、4 保留碼不可構造（private code、⚠️f）；**`From<DbErr>→AppError::internal(5000)`**。`enforce_mw`（`auth/enforce.rs`）已存在但波 0 未用（dead_code）→ 波 1 首批 gated route 用 `.route_layer(from_fn_with_state(state, enforce_mw))`。
- **Rationale**: 實讀 `handler/auth.rs:10-21,60-82,152-208`、`error.rs:28-101`、`main.rs:88-101`。

## R5 — seed／policy／status 前提

- **Decision**: 6 端點 casbin policy **全在 m002**（`m002_rev2_seeds.rs:97-116`）：getUserList(R_SUPER+R_ADMIN)、getAllRoles(三角色)、addUser/updateUser(R_SUPER POST)、deleteUser/batchDeleteUser(R_SUPER DELETE)。sys_user seed **sequence-driven**（不寫 id、BIGSERIAL→1/2/3＝Super/Admin/User）。停用登入 gate（`STATUS_DISABLED:i16=2`）在 `login_inner`（`auth.rs:99`）— getUserInfo **刻意不** gate status。
- **Rationale**: m002 grep＋`auth.rs:23-24,98-101,180`。→ 本刀 wiring 只掛 route、**零新 seed**。

## R6 — endpoint_coverage_lint 現況

- **Decision**: ★ **endpoint_coverage_lint 尚未存在**（只有 entity_access_lint）。⚠️x（DECISIONS §1、2026-06-14）波 0 出口豁免、明訂**首個 gated 業務端點 wiring 時 stand up**。008＝波 1 第一刀 → **008 須建 endpoint_coverage_lint**（正向：每掛 enforce 的 route 有 ≥1 casbin policy、容忍 seeded-but-unimplemented）。
- **Rationale**: `server/tests/entity_access_lint.rs` 在、無 endpoint_coverage_lint 檔；`enforce_mw` 現 dead_code。
- **Alternatives**: defer 到後刀 — 否決（008 掛首批 enforce_mw route、自然 stand-up 點）。`EXPECTED_ROUTE_COUNT=35` 是 DESIGN target（§7.1/§8.4）、wiring 時驗實際數、別盲 assert 35。

## R7 — list userRoles N+1

- **Decision**: 現 `roles_for_user`＝2q/user；page≤10 naive loop ≤20q、≤50 admin 可接受。**建議新 batch `roles_for_users(db,&[i64])→Vec<(i64,Vec<String>)>`**（`find_role_ids_by_user_ids`[1q]＋`find_active_by_ids`[1q]＝O(1)）。`sys_role::find_active_by_ids` 已 batch-ready（`.is_in()`）。
- **Rationale**: `sys_user_role.rs:20-24`、`sys_role.rs:23-28`。
- **★ gap**: `find_role_ids_by_user_ids`（多 user）尚不存在、需新增；`sys_user_role` btree(user_id) index **未在 DDL 確認**（batch perf load-bearing、implementer 須在 m001 驗）。

## R8 — base-web wrapper／MODAL-WIRING

- **Decision**: **新建** `base-web/src/service/api/rev3-system-manage.ts`（rev3- 前綴、WRAPPER §III.1）放 4 寫端；既有 `system-manage.ts` **只有讀端**（fetchGetUserList/fetchGetRoleList/fetchGetAllRoles）、**不可改**。接 3 stub：index.vue（MODAL-WIRING **(a)**）、drawer handleSubmit（**(c)**），`rev3-inline` 標記（修改型保留原行註解）。create/update 由 `operateType` 分支。
- **Rationale**: 實讀 `system-manage.ts:1-56`、§III.1／§III.2／§III ⚠️s。

## ★★ Q3（CRITICAL GAP）— unique-violation → 2222 映射缺失

- **Decision**: ★ **目前缺**：`error.rs` `From<DbErr>`（L73-77）把**所有** DbErr → `5000` internal。`sys_user_user_name_active_uniq`（user_name WHERE deleted_at IS NULL）違反會浮成 **5000、非業務 2222**。008 create/update **必須**處理撞名 → `AppError::biz('用户名已存在')` → `2222`。**建議**：insert 前用既有 `find_active_by_name` pre-check（race-tolerant for ≤50 admin）＋ DB partial-uniq 約束當 backstop；**必加一個 dup→2222 測試**。**不可依賴 DbErr 自動映射**。
- **Rationale**: `error.rs:73-77`（blanket internal）；m001 partial-unique index 在；`find_active_by_name`(sys_user.rs:24) 可用。§I.3：業務驗證 error＝2222、5xxx 段非業務。

## Q1（DELETE 審計不含 roles）— ✅ 實碼確認

- **Decision**: **Q1=B 實碼確認**：`soft_delete` payload_before＝`model.audit_json()`＝15 user 欄、**無 roles**。DELETE 不改既有 soft_delete；M:N roles 軟刪時不刪、不入 audit。
- **Rationale**: `sys_user.rs:54`（before=audit_json）＋`:85-105`（15 欄無 roles）。**僅 code-path 驗、未 live 驗（gap）→ live_smoke 應 assert**。

## Q2（已軟刪 no-op 不寫審計）— ✅ 實碼確認

- **Decision**: **Q2=A 實碼確認**：對已 `deleted_at≠null` 帳戶 soft_delete → `find_active().filter(...).one()` 回 None → `Ok((txn,false,None))` → mutate_in_txn **不寫 audit**（event None）→ 回 `Ok(false)`。冪等 no-op、零 audit 列。
- **Rationale**: `sys_user.rs:50-52,56-66`＋`audit.rs:74-77`。**code-path 驗、concurrent-delete txn rollback 邊界未 live 驗（gap）**。

## ★ Discrepancies / implementer act-on-code（必讀）

1. **Q3 critical**：dup user_name 目前→`5000`、非 `2222`；必加 `find_active_by_name` pre-check → `biz(2222)` ＋測試。
2. **brainstorm §5.3 的 7 個 facade fn 全是設計文字、實碼零實作**（實 facade 只有 9 既有 fn）；implementer 全建。
3. **base-web 4 寫端 fn 不存在**（system-manage.ts 只 3 讀）；必在**新** rev3-system-manage.ts 建。
4. **Q1/Q2 僅 code-path 驗、未 live 驗** → live_smoke 應 assert（create→Insert 列、update→Update 列、delete→SOFT_DELETE 列、already-deleted no-op）。
5. **roles_for_users batch 回形 `Vec<(i64,Vec<String>)>` 是推測**、需新 `find_role_ids_by_user_ids`；`sys_user_role` btree(user_id) index 未確認、verify m001。
6. **endpoint_coverage_lint 不存在、008 建**；`EXPECTED_ROUTE_COUNT` 用實際 gated route 數、別盲 assert 35。
7. **C-V-1~9（001-007）無 perf curl -w**；008 首加 p95 量測（新 C-V 類別、server-side、Q4）。
8. **seed 保護（id∈{1,2,3}→拒刪→2222）無既有碼**；soft_delete 不查 seed id、必在 handler/facade 加。
9. **User→User01 alias 是 getUserInfo display 概念**（且 as-built 尚未實作 alias、`auth.rs:196` 用 nick_name fallback）；**getUserList 回真 user_name、不套 alias**。別混淆。
10. **getUserInfo 不 gate status**；list 回停用 user（帶 status 欄、不過濾）。

---

**所有 NEEDS CLARIFICATION 已解**（Q1/Q2/Q3 實碼驗證、R1-R8 grep 確認）。Phase 1（data-model.md／contracts/）見同目錄。
