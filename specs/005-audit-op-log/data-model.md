# Data Model: 005-audit-op-log

> 本刀＝**L4 audit 機制（`model/audit.rs`）＋op-log facade sink＋單一 proof**。**無持久實體變更、無 migration**——`sys_operation_log` 為 002 凍結 schema（m001）、004 已反射 entity。本檔定義的是 **audit 機制層的型與接線**（純資料型、facade 方法、redact 規則、原子流程）；欄級權威＝m001／004 entity（不重抄）。

## 1. `model/audit.rs`（純資料層、零 `entity::`、守 entity_access_lint）

### 1.1 型
```rust
use sea_orm::entity::prelude::IpNetwork;   // R-B：colon-preceded、lint-safe（非 entity crate）
use sea_orm::{DatabaseTransaction, DbErr, TransactionTrait};

pub enum AuditOperation { Insert, Update, SoftDelete, Restore }
// as_str() → DB 字串契約："INSERT"/"UPDATE"/"SOFT_DELETE"/"RESTORE"（operation 欄）

pub struct AuditOperator { pub id: i64, pub ip: Option<IpNetwork> }

pub struct AuditEvent {
    pub operation: AuditOperation,
    pub entity_table: String,
    pub entity_id: Option<i64>,
    pub payload_before: Option<serde_json::Value>,
    pub payload_after: Option<serde_json::Value>,
    pub operator: Option<AuditOperator>,
    pub trace_id: Option<String>,
}

pub trait AuditSerialize { fn audit_json(&self) -> serde_json::Value; }  // impl 在各 facade
```
- **全 4 `AuditOperation`**：本刀只構造 `SoftDelete`；`Insert`/`Update`/`Restore`＝infra-ahead-of-consumer（`never constructed` warning、benign、**不抑制**、隨消費刀漸用）。
- `as_str()` 為封閉詞彙 DB 契約（定義一次、各刀免 churn）。
- `AuditOperator.ip: Option<IpNetwork>`（R-B；本刀 proof 傳 `None`、overlay 刀填真 IP——一次對最終型、避免 retrofit）。

### 1.2 `mutate_in_txn`（R-A、泛型 `C: TransactionTrait`）
```rust
pub async fn mutate_in_txn<C, R, F, Fut>(conn: &C, f: F) -> Result<R, DbErr>
where C: TransactionTrait,
      F: FnOnce(DatabaseTransaction) -> Fut,
      Fut: Future<Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>>;
```
- 流程：`conn.begin()` → `f(txn)` → `if Some(event){ facade::sys_operation_log::write_in_txn(&txn,event) }` → `txn.commit()`。
- `Ok(_, None)`＝no-op（查無目標）不寫審計、commit（無副作用）；`Err`＝整 txn rollback、業務寫＋op-log 寫一起不留。
- 泛型 `C` 使 production 傳 `&DatabaseConnection`、live smoke 傳外層 `&DatabaseTransaction`（nested begin＝savepoint、外層 rollback 隔離不污染 seed）。

## 2. facade（`model/facade/`、entity:: 合法、回 raw `Model`）

| facade 檔 | fn | 說明 |
|---|---|---|
| `sys_operation_log.rs`（新、sink）| `write_in_txn(txn: &DatabaseTransaction, event: AuditEvent) -> Result<(), DbErr>` | 唯一構造 `entity::sys_operation_log::ActiveModel` insert（append-only）；`operation`=`event.operation.as_str()`、`operator_id`/`operator_ip` 拆自 `event.operator`（`Option<AuditOperator>` → `(Option<i64>, Option<IpNetwork>)`）、`created_at` 走 DB default（不 Set）。**無 update/delete fn**（archetype B、§I.6）|
| `sys_user.rs`（004 既有、加）| `impl AuditSerialize for Model`：`audit_json()` **手構** `json!({ "id":m.id, "user_name":m.user_name, "password":"<redacted>", "nick_name":…, … })`（R-C；逐欄、`password` 遮蔽、其餘原值；不加 Serialize derive）| 遮蔽顯式 |
| `sys_user.rs`（加）| `soft_delete(conn: &C, id: i64, operator: AuditOperator, trace_id: Option<String>) -> Result<Option<Model>, DbErr>`（泛型 `C: TransactionTrait`）| 包 `mutate_in_txn` 的單一寫路徑 proof |

### 2.1 `sys_user::soft_delete` 原子流程（mutate_in_txn proof、R-D）
```
mutate_in_txn(conn, |txn| async {
  let before = Entity::find_by_id(id).one(&txn).await?;      // entity:: 在 facade 合法
  match before {
    None => Ok((txn, None, None)),                            // no-op：查無、不寫審計
    Some(before) => {
      let mut am = before.clone().into_active_model();        // R-D
      am.deleted_at = Set(Some(now));                         // （deleted_by 成對 §I.6 → operator.id；本刀 proof 視需要 set）
      let after = am.update(&txn).await?;
      let event = AuditEvent { SoftDelete, "sys_user".into(), Some(id),
        Some(before.audit_json()), Some(after.audit_json()), Some(operator), trace_id };
      Ok((txn, Some(after), Some(event)))
    }
  }
})
```
> **§I.6 成對紀律**：`deleted_at` 與 `deleted_by` 成對寫——proof 的 soft_delete 同時 set `deleted_by = operator.id`（sys_user 有 deleted_by 欄、004 已建）；overlay/業務刀沿用。

## 3. op-log entity 對映（已存、本刀不動；參照用）
`entity::sys_operation_log::Model`（004、10 欄、archetype B）：`id` i64 PK／`operation` String／`entity_table` String／`entity_id` Option<i64>／`payload_before` Option<Json>／`payload_after` Option<Json>／`operator_id` Option<i64>／`operator_ip` Option<IpNetwork>／`trace_id` Option<String>／`created_at` DateTimeWithTimeZone（DB default now）。
- `write_in_txn` 由 `AuditEvent` 映射：operation→as_str()、entity_table、entity_id、payload_before/after（Json）、operator.id→operator_id、operator.ip→operator_ip、trace_id；`id`/`created_at` 不 Set（DB 生成）。

## 4. 模組串接
- `model/mod.rs`：加 `pub mod audit;`（檔頭註解更新：soft_delete 寫 proof 已落本刀）。
- `model/facade/mod.rs`：加 `pub mod sys_operation_log;`。

## 5. 排除聲明（OUT、各歸其刀）
- overlay 刀：`sys_access_log`/`sys_login_attempt` facade＋`audit_ctx` 中介層＋xdb＋trusted-proxy＋op-log `operator_ip` INET 回填。
- operator 自動來源（`RequestContext`）→ audit_ctx／Auth 島刀；本刀顯式參數。
- op-log 讀端（Super-only 查詢）→ ⚠️b 波2。
- 其餘寫路徑（update/create/restore、其他表）→ 各消費刀。
- `DbErr→AppError`→ Auth 刀（§3.6）。無 endpoint／runtime DB 接線／migration。
