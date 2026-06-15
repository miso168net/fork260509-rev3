# Data Model: User Management（008）— Phase 1

> **既有 schema（m001–m004、零 migration）、entity 不改**。本檔定 wire DTO、facade 新 fn 簽名、handler-layer RI、wire 逐欄映射、audit payload。簽名為設計草案、implementer act-on-code（見 research.md discrepancies）。

## 1. Entities（既有、本刀不改）

| entity | archetype | 關鍵欄 |
|---|---|---|
| `sys_user` | A（6 審計欄、soft-delete partial-uniq） | `id i64 PK`／`user_name String`（partial-uniq `WHERE deleted_at IS NULL`、**可變**）／`password String`（argon2id PHC）／`nick_name Opt<String>`／`user_gender Opt<i16>`／`user_phone Opt<String>`／`user_email Opt<String>`／`status Opt<i16>`／`current_session_id Opt<String>`／`session_policy String`／審計 6：`created_at`(NN)·`created_by`·`updated_at`·`updated_by`·`deleted_at`·`deleted_by` |
| `sys_role` | A | `id i64`／`code String`（uniq active）／`name String`／`role_desc`／`status Opt<i16>`／`home`／審計 6 |
| `sys_user_role` | C join（零審計、硬刪、m003 雙 FK RESTRICT） | `user_id i64`、`role_id i64`〔composite PK；entity 實為 i64，與 `sys_role.id` 對齊〕 |

`audit_json()`（既有、`AuditSerialize`）＝ 15 user 欄、redact `password`→`"<redacted>"`、**排除 `current_session_id`**、**不含 roles**。

## 2. Wire DTO（新、co-located 於 `handler/system_manage.rs`、`#[serde(rename_all="camelCase")]`）

- **`UserSearchParams`**（Query）：`current u64`／`size u64`／`userName Opt<String>`／`userGender Opt<String>`(`"1"|"2"`)／`nickName Opt<String>`／`userPhone Opt<String>`／`userEmail Opt<String>`／`status Opt<String>`(`"1"|"2"`)。null/空欄略過該 filter。
- **`UserListItem`**（resp record）：`id`(number)／`userName`／`nickName`／`userGender`(`"1"|"2"|null`)／`userPhone`／`userEmail`／`status`(`"1"|"2"|null`)／`userRoles`(string[] **roleCodes**)／`createBy`／`createTime`／`updateBy`／`updateTime`。
- **`UserUpsertReq`**（body）：`id Opt<i64>`（update 帶〔自 drawer model.id、R3〕、create 無）／`userName`／`userGender`／`nickName`／`userPhone`／`userEmail`／`status`／`userRoles`(string[] roleCodes)。**無 `password`**（addUser 用 default、§5.3）。
- **`AllRoleItem`**（resp）：`id`(number)／`roleName`／`roleCode`。
- `PageRes<T>`＝`{current,size,total,records}`（camelCase、無 `pages`/`success`、空頁 `records:[]`）。

> **型轉換邊界（rust serde）**：`i64→JSON number`（含 getAllRoles `id`、**不跟 mock string**、⚠️r、2^53 fail-loud guard）；DB `Option<i16>`（`user_gender`/`status`：`1`=enabled/male、`2`=disabled/female、`NULL`=unset）↔ wire `"1"`/`"2"`/`null`（**`None`→JSON `null`、非省略 key**）；snake→camel（`created_at→createTime`、`created_by→createBy`…）；`userRoles`←join `sys_user_role→sys_role.code`（**非 entity 直欄**）。

## 3. 新 facade fn 簽名（7、草案；Column 存取留 facade）

```rust
// sys_user.rs
pub async fn search_active(db, params: &UserSearchParams) -> Result<(Vec<Model>, u64), DbErr>;
//   find_active() + nullable filters（user_name/nick_name/user_email LIKE %x%；user_phone/status/user_gender eq；null 略過）+ id ASC + paginate(current,size) → (rows,total)
pub async fn create(db, fields: NewUser, role_ids: &[i64], operator: AuditOperator, trace_id: Option<String>) -> Result<Model, DbErr>;
//   mutate_in_txn：INSERT（password = argon2id("123456") host-gen）+ replace_roles_in_txn + AuditEvent{Insert, payload_after: composite}
pub async fn update(db, id: i64, fields: UpdateUser, role_ids: &[i64], operator: AuditOperator, trace_id: Option<String>) -> Result<Model, DbErr>;
//   mutate_in_txn：snapshot 舊 composite → UPDATE + replace_roles_in_txn → AuditEvent{Update, before+after composite}

// sys_role.rs
pub async fn all_active(db) -> Result<Vec<Model>, DbErr>;                       // find_active().all() — getAllRoles
pub async fn find_active_by_codes(db, codes: &[String]) -> Result<Vec<Model>, DbErr>;  // active + Code.is_in(codes), empty-guard Ok(vec![])

// sys_user_role.rs
pub async fn replace_roles_in_txn(txn: &DatabaseTransaction, user_id: i64, role_ids: &[i64]) -> Result<(), DbErr>;  // 硬刪舊 + 插新（archetype C、跑在 create/update 的 mutate_in_txn 內）
pub async fn roles_for_users(db, user_ids: &[i64]) -> Result<Vec<(i64, Vec<String>)>, DbErr>;  // batch 避 N+1：find_role_ids_by_user_ids[1q]（★ 需新增）+ find_active_by_ids[1q]
```

## 4. Handler-layer application-RI（⚠️o；**漏一條＝髒資料進 DB**）

| RI | 做法 | 失敗 |
|---|---|---|
| 撞名唯一 | add／update 改名時呼既有 `find_active_by_name(new)`，命中且非本人 | `biz(2222)`「用户名已存在」 ★ **不可靠 DbErr（Q3）** |
| role code→id 解析 | `find_active_by_codes(userRoles)`、解出數 ≠ 提交數（任一 code 缺/停用） | `biz(2222)`、**整批拒、不靜默 skip**（FR-010） |
| 值域 | `status∈{1,2}`／`userGender∈{1,2}` 或 null（i16） | `biz(2222)` |
| soft-deleted 拒更 | update 先 `find_active_by_id(id)` 查無 | `biz(2222)` |
| **種子保護** | delete／batchDelete 對 `id∈{1,2,3}` ★ **無既有碼、handler 加** | `biz(2222)` |

`AuditOperator{id: ctx.operator_id, ip: Some(ctx.client_ip)}`、`trace_id: ctx.trace_id`（自 `Extension<RequestContext>`、007 as-built）。enforce 失敗 `5003`（`route_layer(enforce_mw)`）。

## 5. Audit payload（composite、Q1=B／Q2=A 已實碼確認）

- **addUser**（INSERT）：`payload_after = { …audit_json()(15 欄,redact), "roles":[新 codes] }`、`before=None`（composite 於 call site 組、`AuditEvent.payload` 收任意 `serde_json::Value`）。
- **updateUser**（UPDATE）：`before = {舊 audit_json, "roles":[舊 codes]}`（mutate 前 snapshot、舊 codes 自 `roles_for_user(id)`）、`after = {新, "roles":[新 codes]}`。
- **deleteUser/batchDelete**（SOFT_DELETE）：**複用既有 `soft_delete()` 不改**；`payload_before = audit_json`（15 欄、**無 roles**、Q1=B）、`after=None`；roles M:N 不刪。
- **已軟刪 no-op**：`Ok(false)`、**零 audit**（Q2=A）。

## 6. 種子保護謂詞

`id ∈ {1,2,3}`（m002 sequence-driven、BIGSERIAL **不可變**）。**因 user_name 可變、保護鍵必用 id**（非 name）。

## 7. batch 刪除語意（brainstorm §4／§5.2）

前置全量校驗 `ids` 有無種子（id∈{1,2,3}）→ 有則整批拒 `2222`（不進 txn、一筆不刪）；否則逐筆 `soft_delete()`（各自獨立 txn 寫 SOFT_DELETE 審計）；已軟刪筆 no-op；通過後罕見 infra error 中斷 → 接受半套（admin 重試、soft_delete 冪等）。

## 8. State transitions（sys_user）

`active → soft-deleted`（`deleted_at`+`deleted_by` 成對寫）；soft-deleted username 釋放可重用（partial-uniq）；**本刀無 restore**（回收桶為後續 feature）。
