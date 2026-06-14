# Research: 005-audit-op-log（Phase 0）

**Date**: 2026-06-14 ｜ **Input**: spec.md＋brainstorm `docs/superpowers/005-audit-op-log.md`＋plan 期實 grep（R1 m001 schema／R2 rev2 011 源碼，受控參照 ⚠️g）

> CLAUDE.md §3 Phase 0 三 grep 紀律：① facade 真實返回型（R3／R5）② wire 3 端對齊（N/A——audit 在 wire 之下、無新 endpoint；op-log 讀端屬後續刀）③ data-model file:line 對照（R1/R2 已執行）。**所有 brainstorm 命名/簽名假設已對 actual code 校正**（見 R5）。NEEDS CLARIFICATION＝0。

## R1 · m001 `sys_operation_log` 10 欄逐欄 grep（entity Model 對齊權威）

座標：`rust-api/migration/src/m001_rev2_schema.rs`（SysOperationLog enum :129-142／create :485-544）。型對照：`big_integer`→`i64`／`string_len(n)`→`String`／`json_binary`→`Json`（=serde_json::Value、需 with-json）／`custom(INET)`→`String`（見 R4）／`timestamp_with_time_zone`→`DateTimeWithTimeZone`／`null`→`Option<_>`。

- **`sys_operation_log`**（10 欄、archetype B append-only）：
  `id`(PK i64 auto)／`operation` String(len20, NN)／`entity_table` String(len64, NN)／`entity_id` Option\<i64\>／`payload_before` Option\<Json\>(json_binary)／`payload_after` Option\<Json\>(json_binary)／`operator_id` Option\<i64\>／`operator_ip` Option\<String\>(INET、見 R4)／`trace_id` Option\<String\>(len64)／`created_at` DateTimeWithTimeZone(NN default current)。
- **Decision**：`entity/src/sys_operation_log.rs` `DeriveEntityModel` 逐欄鏡像上表；空 `Relation`（append-only、不展開 FK）。**Rationale**：Model 與 DB schema 漂移＝執行期解析失敗或型別謊言（FR-011）。

## R2 · rev2 011 受控參照 grep（讀允許、拷貝禁止——⚠️g／§I.5；audit/facade 不在拷貝例外清單）

座標：`../fork260509-rev2/rust-api/server/src/model/`＋`entity/src/`。

### R2.1 `model/audit.rs`（rev2、89 行純資料層）
- `AuditOperation { Insert, Update, SoftDelete, Restore }`＋`as_str()`→`"INSERT"`/`"UPDATE"`/`"SOFT_DELETE"`/`"RESTORE"`（operation 欄 DB 字串契約）。
- `AuditOperator { id: i64, ip: Option<String> }`。
- `AuditEvent { operation, entity_table: String, entity_id: Option<i64>, payload_before: Option<serde_json::Value>, payload_after: Option<serde_json::Value>, operator: Option<AuditOperator>, trace_id: Option<String> }`。
- `pub trait AuditSerialize { fn audit_json(&self) -> serde_json::Value; }`（宣告於 audit.rs、impl 在各 facade）。
- `mutate_in_txn<R, F, Fut>(db, f) -> Result<R, DbErr>` where `F: FnOnce(DatabaseTransaction)->Fut`、`Fut::Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>`：`begin → f → if Some(event){facade::sys_operation_log::write_in_txn(&txn, event)} → commit`。**業務寫＋審計寫同 txn**；`Ok(..,None)`=no-op、`Err`=整 txn 回滾。**零 `entity::`**（守 lint ③）。
- rev3 005 **逐形重寫**（非拷貝）。

### R2.2 `facade/sys_operation_log.rs`（rev2；唯一構造 ActiveModel 處、lint 豁免）
- **`fn audit_active_model(event) -> ActiveModel`（純映射 seam、無 DB I/O）**：`AuditEvent`→`sys_operation_log::ActiveModel`；`id`/`created_at`=NotSet（DB 填）；`operation`=`event.operation.as_str()`；其餘對映。
- **⚠️ 關鍵 gotcha：`operator_ip` None→`NotSet`（避 PG 42804）**：`Set(None)` 會送 `NULL::text`、postgres 無法隱式轉型 INET（error code 42804）⇒ None 時用 `NotSet`（略過欄、DB 填 NULL）。`Some(ip)` 分支也會送 text-binding 觸 42804、**真實 INET 值寫入 defer 第二 audit 刀**（需 Expr cast 或 ipnetwork）；本刀 operator 永遠 `ip:None`、不觸 Some 路徑。
- `write_in_txn(txn, event) -> Result<(), DbErr>`：`audit_active_model(event).insert(txn).await`。append-only（僅此一 pub 寫 fn、archetype B）。
- **純 SQL-build 單測**（rev2、no-DB）：`Entity::insert(audit_active_model(event)).build(Postgres).to_string()` 斷言 INSERT 目標表`"sys_operation_log"`＋核心欄出現＋`operator:None`時`"operator_ip"`欄**不出現**（NotSet 證）。**rev3 005 沿此純測形。**

### R2.3 `facade/sys_user.rs`（rev2；soft_delete proof＋AuditSerialize）
- **`soft_delete(db, id: i64, operator: i64) -> Result<bool, DbErr>`**：`mutate_in_txn(db, |txn| async move { find_active().filter(Id.eq(id)).one(&txn) → None: (txn,false,None)〔no-op〕; Some(model): before=model.audit_json(); soft_delete_query(id,operator).exec(&txn)〔寫 deleted_at+deleted_by=operator、§I.6 成對〕; event=AuditEvent{SoftDelete,"sys_user",Some(id),Some(before),None〔payload_after〕,Some(AuditOperator{id:operator,ip:None}),None〔trace〕}; (txn,true,Some(event)) })`。
- `fn soft_delete_query(id, operator) -> UpdateMany<Entity>`：`Entity::update_many().col_expr(DeletedAt, now()).col_expr(DeletedBy, operator).filter(Id.eq(id))`（helper）。
- **`impl AuditSerialize for Model { fn audit_json() }`**：`serde_json::json!({...,"password":"<redacted>",...})`——redact password；含 **15 欄**（id/user_name/password〔redacted〕/nick_name/user_gender/user_phone/user_email/status/session_policy/created_at〔.to_rfc3339()〕/created_by/updated_at/updated_by/deleted_at/deleted_by），**排除 `current_session_id`**（session 狀態欄、不入審計）。
- **redact 純測**（rev2 T009、no-DB）：建 Model→`audit_json()` 斷言 `["password"]=="<redacted>"`＋其餘欄保留。**rev3 005 沿此純測形。**
- ⚠️ **rev2 此檔終態含其他寫端**（`update`/`create`/`reset_password`/`restore`/各審計）——rev3 005 **只取 `soft_delete` proof＋`impl AuditSerialize`**；其餘寫路徑屬各消費刀（User 刀 波2 等），本刀不帶（防回歸 §I.5）。

### R2.4 live smoke 形（rev2 facade/sys_operation_log.rs `mod live_tests`、`#[ignore]`）
- 隔離：**拋棄式 user（id 9xxxxx）＋hard_clean**（delete op-log rows by entity_id ＋ delete user）——非 stamp seed（更乾淨）。
- 3 測：①`soft_delete` 寫**恰好 1 筆** redacted 審計（operation/entity_table/entity_id/payload_before.password=`"<redacted>"`/user 已軟刪）②no-op（不存在 or 已刪）**不寫**審計（Ok(false)、筆數不增）③審計 INSERT 失敗（`entity_table` 超長 >VARCHAR(64)）→ `mutate_in_txn` 回 Err、**user UPDATE 回滾**（deleted_at 仍 None）、審計**無**列。**rev3 005 沿此 3 場景。**

## R3 · 依賴增量

- **entity crate**：sea-orm features `["with-chrono"]`→`["with-chrono","with-json"]`（JSONB `payload_*` 的 `Json`/`serde_json::Value` 需 with-json）。**serde_json 已在 Cargo.lock**（003 envelope/sea-orm 引入、workspace deps `serde_json="1"`）、chrono 已在 lock（004）⇒ **with-json 無新外部 crate 下載**（feature flag 啟用既有 lock 內 crate）。
- **server crate**：`model/audit.rs` 用 `serde_json::Value`（serde_json 已在 server deps〔003〕）；無新 dep。
- **dev-dependencies**：SQL-build 純測用 `sea_orm::{DbBackend, QueryTrait, EntityTrait}`（已含）；live smoke 用 `sea_orm::Database::connect`＋`tokio::test`（已含）＋`serde_json::json!`（已含）。無額外 dev-dep。
- **義務**：`cargo build`/`cargo test -p server` 綠＝entity +with-json 編譯（JSONB Model 欄解析）。**非新 crate ⇒ 無 Dockerfile COPY 改動、無 mandatory prod build**（異於 004）；C-V 跑一次 build 驗 with-json 不破壞編譯即可。

## R4 · `operator_ip` INET 欄型（act on actual code）

- m001 `operator_ip` = `.custom(Alias::new("INET"))` nullable。rev2 entity Model 宣告 **`operator_ip: Option<String>`**（INET 欄、sea-orm 以 text 讀）。
- **寫入坑（PG 42804）**：`Set(None)`→`NULL::text`、INET 無法隱式轉 ⇒ **None 用 `NotSet`**（見 R2.2）。`Some(ip)` text-binding 同觸 42804、真實值寫入 defer。
- **Decision**：rev3 Model `operator_ip: Option<String>`；facade `audit_active_model` None→NotSet。本刀 operator `ip` 恆 None（無 middleware）⇒ 永不寫實值、不觸 42804。**Rationale**：忠實 rev2 驗證形＋避隱式轉型錯。

## R5 · facade 返回型＋`soft_delete` 簽名校正（不信 brainstorm 猜形、act on actual code）

- **brainstorm 猜**：`soft_delete(db, id, AuditOperator) -> Result<Option<Model>, DbErr>`。**actual rev2**：`soft_delete(db, id, operator: i64) -> Result<bool, DbErr>`。**校正採 actual**：operator 收 `i64`（內部 wrap `AuditOperator{id, ip:None}`）、回 `bool`（true=軟刪、false=no-op）。理由：`bool` 足證 proof（live 另查 DB 驗）、`operator:i64` 較 `AuditOperator{ip:None}` 精簡。
- **`payload_after` 校正**：brainstorm 說 before+after；actual soft_delete `payload_after=None`（軟刪只 before 快照、after 即 deleted_at set 無意義快照）。採 actual。
- **`deleted_by` 校正**：actual soft_delete 寫 `deleted_at`+`deleted_by`(operator)（§I.6 成對）；brainstorm 只提 deleted_at。採 actual（含 deleted_by）。
- `write_in_txn(txn: &DatabaseTransaction, event: AuditEvent) -> Result<(), DbErr>`；`audit_active_model(event) -> ActiveModel`（純）。三者皆 facade 內、entity:: 合法。
- **Decision**：data-model §4 採 actual 形（見 data-model.md）。**Alternatives**：brainstorm 猜形（被否：與 rev2 驗證形不符、Option<Model>/AuditOperator 多餘）。

## R6 · contract test 策略（驗證 ii、test-first）

- **純 cargo test（零 DB、2 seam）**：① `sys_user::Model::audit_json()` redact（password→`"<redacted>"`、其餘欄保留）② `audit_active_model(event)` SQL-build（`Entity::insert(am).build(Postgres).to_string()` 含 `INSERT INTO "sys_operation_log"`＋核心欄＋`operator:None`時 operator_ip 欄略過）。test-first：先寫測（red：fn 未實作）後實作（green）。
- **bounded 实机 smoke（`#[ignore]`、`DATABASE_URL`、`postgres+migrate`）**：拋棄式 user＋hard_clean；3 場景（commit 恰好 1 筆 redacted／no-op 不寫／審計 INSERT 失敗整 txn 回滾——對應 SC-001/003/004 + SC-002 rollback）。`cargo test -- --ignored` 起 DB 才跑。
- **Decision**：test-first（2 純測先紅後綠）；DB 端 3 場景證原子（commit/no-op/rollback 是 compile/render 證不了的核心）。**Rationale**：純函式驗收為主；txn 原子（尤其 rollback）必由实机釘死。NEEDS CLARIFICATION＝0。

## 移交 tasks 期紀律

- 第二 audit 軌（`sys_access_log`/`sys_login_attempt`/xdb/`audit_ctx` 中介層）→ 第二 audit 刀（rev2 015）。
- operator 自動來源（bearer→RequestContext）＋op-log 讀端 → Auth 島/波2。
- 其餘寫路徑（`update`/`create`/`restore`/其餘表）→ 各自消費刀；`DbErr→AppError` → Auth 島刀（§3.6）。
- 真實 INET `operator_ip` 寫入（Expr cast/ipnetwork）→ 第二 audit 刀（middleware 帶 operator_ip 時）。
