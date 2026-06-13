# Contract: audit-contract（mutate_in_txn 原子＋AuditSerialize redact＋audit_active_model SQL-build＋实机 smoke；test 權威）

> redact＋SQL-build 為**純函式 test-first**（先紅後綠）；实机 smoke 證「業務寫＋審計寫原子（commit/no-op/rollback）」。形狀對齊 R1/R2 grep 與 data-model；紅了校實作、不調 contract 遷就實作（⚠️g 全新寫、但形對齊 rev2 011 參照）。

## 1. `mutate_in_txn` 原子契約（guard 核心）

- `mutate_in_txn<R,F,Fut>(db, f) -> Result<R, DbErr>`：閉包 `f` 收 `DatabaseTransaction`、回 `(txn, R, Option<AuditEvent>)`。
- 行為契約：
  - `Ok((txn, r, Some(event)))` → `write_in_txn(&txn, event)` 後 `commit` → 回 `Ok(r)`；**業務寫＋審計寫同 txn 落庫**。
  - `Ok((txn, r, None))` → `commit`（不寫審計）→ 回 `Ok(r)`；**no-op**（查無目標）。
  - 閉包回 `Err(e)` **或** `write_in_txn` 回 `Err(e)` → txn **未 commit**（drop 即 rollback）→ 回 `Err(e)`；**業務寫＋審計寫皆不存在**（原子回滾）。
- `audit.rs` 零 `entity::`（守 lint ③）。

## 2. facade 契約（guard ②／③；回 raw `Model`/`DbErr`、不 re-export `Entity`）

| facade fn | 簽名 | 行為契約 |
|---|---|---|
| `sys_operation_log::write_in_txn` | `(txn: &DatabaseTransaction, event: AuditEvent) -> Result<(), DbErr>` | `audit_active_model(event).insert(txn)`；append-only（唯一寫 fn） |
| `sys_operation_log::audit_active_model` | `(event: AuditEvent) -> ActiveModel`（純、無 DB） | `id`/`created_at`=NotSet；`operation`=`as_str()`；**`operator_ip` None→`NotSet`**（避 PG 42804） |
| `sys_user::soft_delete` | `(db, id: i64, operator: i64) -> Result<bool, DbErr>` | 經 `mutate_in_txn`；active 命中→寫 deleted_at+deleted_by+審計、回 `Ok(true)`；查無/已刪→`Ok(false)` no-op 不寫審計 |
| `sys_user::impl AuditSerialize` | `audit_json(&self) -> serde_json::Value` | redact `password`→`"<redacted>"`；15 欄〔排除 `current_session_id`〕；timestamps `.to_rfc3339()` |

- **結構斷言（由 guard ③ lint 保證）**：`audit.rs` 無 `entity::`；facade 不 `pub use Entity`。
- facade 回 `sea_orm::DbErr`、**不**映射 envelope/AppError（FR-009）。

## 3. 純測契約（test-first、零 DB）

- **① `audit_json` redact**（`facade/sys_user.rs` `#[cfg(test)]`）：建 `sys_user::Model`（password 設值）→ `audit_json()` **MUST**：
  - `json["password"] == "<redacted>"`（FR-005）；
  - `json["user_name"]` 等非敏感欄保留（不過度遮蔽）。
- **② `audit_active_model` SQL-build**（`facade/sys_operation_log.rs` `#[cfg(test)]`）：建 `AuditEvent{SoftDelete,"sys_user",Some(7),Some(json),None,None〔operator〕,None}` → `Entity::insert(audit_active_model(event)).build(DbBackend::Postgres).to_string()` **MUST**：
  - 含 `INSERT INTO "sys_operation_log"`；
  - 含 `"operation"`／`"entity_table"`／`"entity_id"`／`"payload_before"`／`"payload_after"` 欄；
  - **`operator:None` 時 NOT 含 `"operator_ip"` 欄**（NotSet 略過、證避 42804）。
- red→green：先寫 ①② 測（red：fn/impl 未實作）後實作（green）。

## 4. bounded 实机 smoke 契約（`#[ignore]`、`DATABASE_URL`、`postgres+migrate`；拋棄式 user＋hard_clean）

> 隔離：拋棄式 user（id 9xxxxx）、測前後 `hard_clean`（delete op-log rows by entity_id ＋ delete user）；不碰 m002 seed。run：`cargo test -p server -- --ignored --test-threads=1`（DB 起著）；常規 `cargo test -p server` 不含 `#[ignore]`。

1. **commit 原子（SC-001/003/004）**：插 active user（id=900001、password=原雜湊）→ `soft_delete(db, 900001, 1)` → `Ok(true)`；
   - `sys_operation_log` WHERE entity_id=900001 **恰好 1 列**；`operation=="SOFT_DELETE"`／`entity_table=="sys_user"`／`entity_id==Some(900001)`／`payload_after.is_none()`／`payload_before["password"]=="<redacted>"`（redact 真落 DB）／`payload_before["user_name"]` 保留；
   - `sys_user` id=900001 `deleted_at.is_some()`（軟刪生效）。
2. **no-op 不寫（SC-004）**：(a) 不存在 user → `soft_delete` `Ok(false)`、審計 0 列；(b) 已軟刪 user 再 `soft_delete` → `Ok(false)`、審計筆數不增（仍 1）。
3. **rollback 原子（SC-002 核心）**：插 active user（id=900003）→ 經 `mutate_in_txn` 閉包內先 UPDATE 軟刪、再構造 `entity_table` 超長（>VARCHAR(64)）的 `AuditEvent` 致 `write_in_txn` INSERT 失敗 → `mutate_in_txn` 回 `Err`；
   - `sys_user` id=900003 `deleted_at.is_none()`（UPDATE 已回滾）；
   - `sys_operation_log` WHERE entity_id=900003 **0 列**（審計未寫）。
   - **證業務寫＋審計寫同生同滅**。
