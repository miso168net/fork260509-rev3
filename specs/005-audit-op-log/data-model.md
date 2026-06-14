# Data Model — 005-audit-op-log

> **權威序聲明**：①m001 schema（`rust-api/migration/src/m001_rev2_schema.rs`、002 落地）＝entity Model 對齊**唯一權威**（欄名/型/可空/PK）＞②rev2 011 參考形（`../fork260509-rev2/rust-api/server/src/model/`＋`entity/src/`，受控參照讀允許拷貝禁止 ⚠️g）＞③本檔。implementer 寫 Model/facade 時逐項對照 R1/R2 grep 座標，不得只抄本檔。
> **漂移紀律**：Model 與 m001 不符 → 以 m001 grep 為準、回頭最小 patch 本檔（FR-011）。

## 1. 型別總覽

| 型別 | 檔 | 職責 | 來源/座標 |
|---|---|---|---|
| `sys_operation_log::Model` 等 | `entity/src/sys_operation_log.rs` | sea-orm `DeriveEntityModel`、archetype B append-only | m001 :129-142/:485-544 |
| `AuditOperation`/`AuditOperator`/`AuditEvent`/`AuditSerialize` | `server/src/model/audit.rs` | 純資料＋trait（不碰 entity） | rev2 audit.rs（重寫） |
| `mutate_in_txn` | `server/src/model/audit.rs` | 業務寫＋審計寫同 txn 泛型 wrapper | rev2 audit.rs（重寫） |
| `sys_operation_log` facade | `server/src/model/facade/sys_operation_log.rs` | 審計 sink 唯一寫入閘（append-only） | rev2 facade（重寫） |
| `sys_user` facade 寫側 | `server/src/model/facade/sys_user.rs` | `impl AuditSerialize`＋`soft_delete` proof | rev2 facade（讀側重寫） |

## 2. `entity/src/sys_operation_log.rs`（10 欄、archetype B、逐欄鏡像 m001）

> sea-orm `#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]`＋`#[sea_orm(table_name = "sys_operation_log")]`；JSONB＝`Json`（=serde_json::Value、需 with-json）；timestamptz＝`DateTimeWithTimeZone`；INET＝`Option<String>`（見 R4）。

```
id          i64                          【#[sea_orm(primary_key)]】
operation   String
entity_table String
entity_id   Option<i64>
payload_before Option<Json>              （json_binary / JSONB）
payload_after  Option<Json>             （json_binary / JSONB）
operator_id Option<i64>
operator_ip Option<String>              （INET；寫入 None→NotSet，見 §4）
trace_id    Option<String>
created_at  DateTimeWithTimeZone
```
- 空 `Relation`（append-only、不展開 FK）。`entity/src/lib.rs` 加 `pub mod sys_operation_log;`。
- `entity/Cargo.toml`：sea-orm features `["with-chrono"]`→`["with-chrono","with-json"]`（serde_json 已在 lock、無新下載）。

## 3. `model/audit.rs`（全新寫⚠️g、不碰 `entity::`、守 lint ③）

```rust
pub enum AuditOperation { Insert, Update, SoftDelete, Restore }   // as_str() → "INSERT"/"UPDATE"/"SOFT_DELETE"/"RESTORE"
pub struct AuditOperator { pub id: i64, pub ip: Option<String> }
pub struct AuditEvent {
    pub operation: AuditOperation,
    pub entity_table: String,
    pub entity_id: Option<i64>,
    pub payload_before: Option<serde_json::Value>,
    pub payload_after: Option<serde_json::Value>,
    pub operator: Option<AuditOperator>,
    pub trace_id: Option<String>,
}
pub trait AuditSerialize { fn audit_json(&self) -> serde_json::Value; }   // impl 在各 facade

pub async fn mutate_in_txn<R, F, Fut>(db: &DatabaseConnection, f: F) -> Result<R, DbErr>
where
    F: FnOnce(DatabaseTransaction) -> Fut,
    Fut: std::future::Future<Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>>,
{
    // begin → f → if Some(event){ facade::sys_operation_log::write_in_txn(&txn, event).await? } → commit
}
```
- **全 4 `AuditOperation`**：本刀只構造 `SoftDelete`；`Insert`/`Update`/`Restore` 為 infra-ahead-of-consumer（`never constructed` warning、benign、**不抑制**——同 004/envelope 紀律）。
- `audit.rs` import 僅 `sea_orm::{DatabaseConnection, DatabaseTransaction, DbErr, TransactionTrait}`＋`serde_json`；**零 `entity::`**（守 ③）。

## 4. facade（guard ②／③；回 raw `Model`/`DbErr`、不 re-export `Entity`）

| facade | fn（actual 形、見 R5 校正） |
|---|---|
| `facade/sys_operation_log.rs`（新、append-only sink） | `fn audit_active_model(event: AuditEvent) -> sys_operation_log::ActiveModel`（純映射；`id`/`created_at` NotSet；**`operator_ip` None→`NotSet`、避 PG 42804**）／`pub async fn write_in_txn(txn: &DatabaseTransaction, event: AuditEvent) -> Result<(), DbErr>`（`audit_active_model(event).insert(txn)`） |
| `facade/sys_user.rs`（004 既有、加） | `impl AuditSerialize for Model`（`audit_json()`：redact `password`→`"<redacted>"`、15 欄〔排除 `current_session_id`〕、timestamps `.to_rfc3339()`）／`pub async fn soft_delete(db, id: i64, operator: i64) -> Result<bool, DbErr>`（包 mutate_in_txn）／`fn soft_delete_query(id, operator) -> UpdateMany<Entity>`（`update_many().col_expr(DeletedAt, now()).col_expr(DeletedBy, operator).filter(Id.eq(id))`、helper） |

- **`soft_delete` 流程**（包 mutate_in_txn）：閉包 `find_active().filter(Id.eq(id)).one(&txn)`（復用 004 find_active、已刪→None）→ None: `(txn,false,None)` no-op → Some(model): `before=model.audit_json()`；`soft_delete_query(id,operator).exec(&txn)`（寫 deleted_at+deleted_by）；`event=AuditEvent{SoftDelete,"sys_user",Some(id),Some(before),None,Some(AuditOperator{id:operator,ip:None}),None}`；`(txn,true,Some(event))`。
- facade 回 `sea_orm::DbErr`、**不**映射 envelope/AppError（FR-009 同 004）。`write_in_txn`/`audit_active_model` 在 facade 內（entity:: 合法）；`audit.rs` 在 facade 外（零 entity::）。

## 5. `entity_access_lint`（守恆 ③、004 已立、本刀不改）

- `audit.rs` 純泛型、**零 `entity::`**（守 ③）；`facade/sys_operation_log.rs`＋`facade/sys_user.rs` 在 `src/model/facade/` 下、path-豁免 ⇒ `no_raw_entity_outside_facade` 仍綠。本刀新增受其守護的 facade、不改 lint。

## 6. 排除聲明（不在本刀）

- **第二 audit 軌**（`sys_access_log`/`sys_login_attempt` entity/facade＋`audit_ctx` 中介層＋xdb region）→ 第二 audit 刀（rev2 015）。
- **operator 自動來源**（bearer→RequestContext.operator_id/trace_id）＋真實 INET `operator_ip` 寫入（Expr cast/ipnetwork）→ audit_ctx 刀＋Auth 島。
- **op-log 讀端**（Super-only 查詢端點）→ Auth 島/波2（需 enforce/handler/讀索引）。
- **其餘寫路徑**（`update_*`/`create`/`restore`/`reset_password`、`sys_role`/`sys_menu`/`system_settings` 寫側）→ 各自消費刀（首個消費者紀律）。
- **`DbErr → AppError` From impl** → Auth 島刀（CHECKLIST §3.6）。
- **migration**：無（`sys_operation_log` 已在 m001）。
