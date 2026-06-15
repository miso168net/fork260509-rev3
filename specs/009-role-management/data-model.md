# Data Model: Role Management（009）— Phase 1

> **既有 schema（m001–m004、零 migration）、entity 不改**。本檔定 wire DTO、facade 新 fn 簽名、handler-layer RI、wire 逐欄映射、leaf audit payload、seed 保護、batch 語意。簽名為設計草案、implementer act-on-code（見 research.md ★ discrepancies）。

## 1. Entities（既有、本刀不改）

| entity | archetype | 關鍵欄（grep 實證 `entity/src/sys_role.rs:8-22`） |
|---|---|---|
| `sys_role` | A（6 審計欄、soft-delete partial-uniq） | `id i64 PK`／`code String`（partial-uniq `WHERE deleted_at IS NULL`＝`sys_role_code_active_uniq`、**不可變**）／`name String`／`role_desc Option<String>`／`status Option<i16>`／`home Option<String>`／審計 6：`created_at`(DateTimeWithTimeZone NN)·`created_by`(Opt<i64>)·`updated_at`(Opt)·`updated_by`(Opt<i64>)·`deleted_at`(Opt)·`deleted_by`(Opt<i64>) |

- **無敏感欄**（無 password）→ `audit_json()` **不需 redact**、12 欄全 audit-safe。
- **Role 為 leaf entity**：role 側 CRUD **不觸** `sys_user_role` join（無 composite role-delta）。
- `sys_user_role`／`casbin_rule`／`sys_menu`：本刀**不讀不寫**（授權指派維度 OUT）。

## 2. Wire DTO（新、co-located 於 `handler/system_manage.rs`、`#[serde(rename_all="camelCase")]`）

- **`RoleSearchParams`**（Query）：`current u64`／`size u64`／`roleName Opt<String>`／`roleCode Opt<String>`／`status Opt<String>`(`"1"|"2"`)。null/空字串略過該 filter。
- **`RoleListItem`**（resp record）：`id`(number、`serialize_id_guarded` 2^53)／`roleName`／`roleCode`／`roleDesc`(`Opt<String>`)／`status`(`"1"|"2"|null`)／`createBy`／`createTime`／`updateBy`／`updateTime`。
- **`RoleUpsertReq`**（body）：`id Opt<i64>`（update 帶〔自 drawer model.id、R3〕、create 無）／`roleName`／`roleCode`／`roleDesc Opt<String>`／`status`。serde **不設 `deny_unknown_fields`**（drawer 灌入的多餘欄〔id/審計〕自動忽略、同 008）。
- `PageRes<T>`＝`{current,size,total,records}`（camelCase、無 `pages`/`success`、空頁 `records:[]`）。
- **getAllRoles 不在本刀**（008 已交付、`all_active` + `AllRole` typings）。

> **型轉換邊界（rust serde）**：`i64→JSON number`（`Role.id`、⚠️r、2^53 fail-loud guard）；DB `status Option<i16>`（`1`=enabled/`2`=disabled/`NULL`=unset）↔ wire `"1"`/`"2"`/`null`（`None`→JSON `null`、非省略 key、沿 008 `i16_to_wire`）；snake→camel（`name→roleName`、`code→roleCode`、`role_desc→roleDesc`、`created_at→createTime`、`created_by→createBy`…）；**無 gender／無 roles／無 password**（vs 008 的三處 delta）。`createBy`/`updateBy`＝operator id-string（008 follow-up 同形、非人名）。

## 3. 新 facade fn 簽名（sys_role.rs、6 fn ＋ 2 struct ＋ 1 impl ＋ 3 helper；草案）

```rust
// ── structs ──
pub struct NewRole { pub code: String, pub name: String, pub role_desc: Option<String>, pub status: Option<i16> }
//   home 不入本刀 upsert（drawer 無 home 欄）；create 用 entity default / None
pub struct RoleFilter { pub role_name: Option<String>, pub role_code: Option<String>, pub status: Option<i16> }
//   model 層 struct（不收 wire DTO、避層級倒置、沿 008 ActiveUserFilter）

// ── reads（net-new）──
pub async fn find_active_by_id(db, id: i64) -> Result<Option<Model>, DbErr>;        // update/delete pre-check
pub async fn find_active_by_code(db, code: &str) -> Result<Option<Model>, DbErr>;   // ★ singular、dup-check→2222
pub async fn search_active(db, filter: &RoleFilter, current: u64, size: u64) -> Result<(Vec<Model>, u64), DbErr>;
//   find_active() 基 + role_name/role_code .contains(LIKE %x%) + status .eq + null 略過 + id ASC + paginate → (rows,total)

// ── writes（net-new、皆走 mutate_in_txn、leaf：無 roles 參數）──
pub async fn create(db, fields: NewRole, operator: AuditOperator, trace_id: Option<String>) -> Result<Model, DbErr>;
//   mutate_in_txn：INSERT（created_by=operator.id）→ AuditEvent{Insert, after: Some(audit_json), before: None}
//   ★ 對 23505 unique-violation（sys_role_code_active_uniq）remap → 業務拒（見 §4 dup 處置）
pub async fn update(db, id: i64, fields: NewRole, operator: AuditOperator, trace_id: Option<String>) -> Result<Model, DbErr>;
//   mutate_in_txn：snapshot 舊 audit_json → UPDATE（name/role_desc/status；**code 不入**、updated_at/by 成對 §I.6）→ AuditEvent{Update, before/after}
pub async fn soft_delete(db, id: i64, operator: AuditOperator, trace_id: Option<String>) -> Result<bool, DbErr>;
//   沿 008 形：mutate_in_txn、SOFT_DELETE 審計、已軟刪→Ok((txn,false,None)) no-op 零 audit；batch 由 handler 迴圈

// ── query helpers（net-new、建 stmt、沿 008 sys_user）──
fn create_query(fields: NewRole, operator_id: i64) -> ActiveModel;
fn update_set_query(id: i64, fields: NewRole, operator_id: i64) -> UpdateMany<Entity>;  // code 不入 set
fn soft_delete_query(id: i64, operator_id: i64) -> UpdateMany<Entity>;

// ── impl ──
impl AuditSerialize for Model { fn audit_json(&self) -> serde_json::Value }  // 12 欄、★ 無 redaction
```

> **delta vs 008**：`create`/`update` **無 `roles: &[RoleModel]` 參數**（leaf）；`update` 的 `NewRole` 含 `code` 欄但 `update_set_query` **刻意不寫 code 欄**（roleCode 不可變、§5）；`audit_json` 無 redact。

## 4. Handler-layer application-RI（⚠️o；**漏一條＝髒資料進 DB**）

| RI | 做法 | 失敗 |
|---|---|---|
| 撞碼唯一（create） | addRole 呼 net-new `find_active_by_code(roleCode)` 命中 | `biz(2222)`「角色代码已存在」 ★ **不可靠 DbErr**（Q-DUP） |
| 並發 race backstop | create 對 pg `23505`（`sys_role_code_active_uniq`）unique-violation **targeted catch → `biz(2222)`** | `biz(2222)`（**兌現 spec clarify A：race 永不 5000**；default `From<DbErr>`→5000 須繞過） |
| 值域 | `status∈{1,2}` 或 null（i16、`wire_to_i16`） | `biz(2222)` |
| soft-deleted 拒更 | updateRole 先 `find_active_by_id(id)` 查無 | `biz(2222)` |
| roleCode 不可變 | updateRole **不入 code 欄**（`update_set_query` 跳過）；無 rename-collision（故 update 無撞碼檢查） | —（靜默忽略提交的 code 變更；前端 `:disabled` 防呆） |
| 種子保護 | deleteRole／batchDeleteRole 對 `id∈{1,2,3}` ★ **無既有碼、handler 加** `is_seed_role` | `biz(2222)` |

`AuditOperator{id: ctx.operator_id, ip: Some(ctx.client_ip)}`（`audit_operator(&ctx)`、operator_id None→`internal`5000）、`trace_id: ctx.trace_id`（自 `Extension<RequestContext>`、007 as-built）。enforce 失敗 `5003`（`route_layer(enforce_mw)`）。

> **dup 並發處置抉擇（act-on-code）**：spec clarify（user 選 A）要求 race「同業務拒 2222、永不系統失敗」。因 `From<DbErr>` blanket→5000（`error.rs:73-77`），**pre-check 單獨不足**。設計＝ **pre-check（常態）＋ create 內 23505 targeted catch（race 守門）** 雙線，保證任何撞碼路徑皆回 `2222`。implementer 須在 create 的 `?` 前攔 `DbErr`、辨識 `sys_role_code_active_uniq` 違反 → `biz(2222)`（其餘 DbErr 仍→5000）。

## 5. roleCode 不可變（FR-006）

- **後端**：`update_set_query` **不含 code 欄** → 任何提交的 roleCode 變更靜默不生效（DB code 不動）。
- **前端**：drawer roleCode `NInput` 加 `:disabled="isEdit"`（FR-006「edit 時 read-only」、最小 inline、MODAL-WIRING (a) 同元件、`rev3-inline` 標記）。
- **理由**：`roleCode = casbin subject(v0)`（m002 policy 主鍵）；可變會破授權對映。

## 6. Audit payload（leaf、無 composite、無 redaction）

- **addRole**（INSERT）：`payload_after = audit_json()`（role 12 欄）、`before=None`。**無 roles、無 redaction**。
- **updateRole**（UPDATE）：`before = 舊 audit_json`（mutate 前 snapshot）、`after = 新 audit_json`（name/role_desc/status 變、**code/created 不變**）。
- **deleteRole/batchDelete**（SOFT_DELETE）：`payload_before = audit_json`、`after=None`。
- **已軟刪 no-op**：`Ok(false)`、**零 audit**（沿 008 Q2 機制）。
- entity_table=`"sys_role"`、entity_id=role id。

## 7. 種子保護謂詞

`id ∈ {1,2,3}`（m002 sequence-driven、`m002:65-67` 不寫 id、BIGSERIAL→1/2/3＝R_SUPER/R_ADMIN/R_USER_COMMON、**不可變**）。**僅擋刪**（delete/batchDelete→2222）、**不擋 update**（FR-012 baseline 可改 name/desc/status）。`is_seed_role(id)→bool`（handler 純函式、可單測）。

## 8. batch 刪除語意（brainstorm §4／§5.2、鏡像 008 batch_delete_user）

前置全量校驗 `ids` 有無種子（任一 `id∈{1,2,3}`）→ 有則整批拒 `2222`（不進 txn、一筆不刪、FR-011）；否則逐筆 `soft_delete()`（各自獨立 txn 寫 SOFT_DELETE 審計）；已軟刪筆 no-op 零 audit；通過種子校驗後罕見 infra error 中斷 → 接受半套（admin 重試、soft_delete 冪等、⚠️a 保守 SLA）。`ids` comma-parse 惡形（非數字）→`2222`（沿 008）。

## 9. State transitions（sys_role）

`active → soft-deleted`（`deleted_at`+`deleted_by` 成對寫）；soft-deleted roleCode 釋放可重用（partial-uniq `WHERE deleted_at IS NULL`、`m001:759-760`）；**soft-deleted role 自動 inert**（`roles_for_user` 走 `find_active_by_ids`、不計入 user 有效角色 → grants 失效、無需動 casbin/join、R6）；**停用（status=2）≠ 撤權**（active filter 僅濾 deleted_at、R6）；**本刀無 restore**（回收桶為後續 feature）。
