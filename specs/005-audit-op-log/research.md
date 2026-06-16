# Phase 0 Research: 005-audit-op-log

> 接地源＝sea-orm 1.1.20 source 親 grep（容器內 registry）＋rust-api 004 後現況親讀＋DESIGN §5.2/§1.5 L4/§3.2/§3.3/§10.4＋constitution §I.5/§I.6＋brainstorm `docs/superpowers/005-audit-op-log.md`（§6 R-A~R-D）。**NEEDS CLARIFICATION = 0**（brainstorm 全決；clarify 0 問題）。

## R1 — scaffold：純 server/src/model/ 新增、零依賴變動

**Decision**：本刀不新增 workspace crate、不改任何 `Cargo.toml`、不加 migration。全為 `server/src/model/` 新增（`audit.rs`＋`facade/sys_operation_log.rs`＋`facade/sys_user.rs` 加 fn）＋`mod.rs` 串接。
**Rationale**（親讀）：`server` deps 已含 `sea-orm`(workspace、含 with-ipnetwork via feature 聯集)＋`serde_json`(003)＋`entity`(path)；`entity/src/sys_operation_log.rs` 已於 004 建（10 欄、payload `Json`、operator_ip `Option<IpNetwork>`）；`entity` crate sea-orm features 已含 with-json/with-chrono/with-ipnetwork。⇒ audit.rs 用 `serde_json::Value`＋sea_orm txn 型、facade 用 entity::sys_operation_log，皆現成。
**Alternatives**：擴 entity crate／加 with-json——N/A（004 已做、rev3 D1「11 entity 一次建齊」之果）。
**⇒ 無 mandatory prod build**（無新 crate；異於 004）；C-V 仍跑 server build 驗編譯。

## R2 — `mutate_in_txn` 簽名（R-A）＋ live smoke seed 隔離

**Decision**：`mutate_in_txn` 泛型於 `C: TransactionTrait`、`conn: &C`；閉包收 `DatabaseTransaction`：
```
pub async fn mutate_in_txn<C, R, F, Fut>(conn: &C, f: F) -> Result<R, DbErr>
where C: TransactionTrait, F: FnOnce(DatabaseTransaction) -> Fut,
      Fut: Future<Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>>
{ let txn = conn.begin().await?; let (txn, r, ev) = f(txn).await?;
  if let Some(ev)=ev { facade::sys_operation_log::write_in_txn(&txn, ev).await?; }
  txn.commit().await?; Ok(r) }
```
**Rationale**（sea-orm grep）：`impl TransactionTrait for DatabaseConnection`(db_connection.rs:246)＋`impl TransactionTrait for DatabaseTransaction`(transaction.rs:453)——兩者皆有 `begin()->DatabaseTransaction`；`DatabaseTransaction` 亦 `impl ConnectionTrait`(transaction.rs:241)。⇒ 泛型 `C: TransactionTrait` 同時吃 production 的 `&DatabaseConnection` 與 test 的 `&DatabaseTransaction`（後者 `begin()`＝**savepoint**、sea-orm 用 `SAVEPOINT`/`ROLLBACK TO SAVEPOINT` 實作 nested txn）。
**live smoke seed 隔離**：test 開**外層** `let outer = db.begin()` → `mutate_in_txn(&outer, …)`（內部 begin＝savepoint、commit＝release savepoint）→ 在 outer 內查 op-log 驗證 → `outer.rollback()` 全還原。**零 seed 污染**且真測原子（savepoint commit/rollback 與 production txn 同語意）。
**Alternatives**：(b) 具體 `&DatabaseConnection`＋commit 後 cleanup——否決（cleanup 脆弱、test 中途失敗污染 seed）；(c) temp user——否決（仍 commit、且引入 seed 外資料）。泛型 `C: TransactionTrait` 一招同時解 production 與 test，最乾淨。

## R3 — 三層職責 ＋ lint 守恆（DESIGN §5.2/§1.5 L4）

**Decision**：`audit.rs`＝純資料＋txn 生命週期（`AuditOperation`/`AuditOperator`/`AuditEvent`/`AuditSerialize`＋`mutate_in_txn`、**零 `entity::`**）；`facade/sys_operation_log.rs`＝唯一構造 op-log `ActiveModel`（append-only insert）；`facade/sys_user.rs`＝業務寫＋`AuditSerialize`（entity:: 在 facade 合法）。
**Rationale**：004 已立 `entity_access_lint`（facade 外 path-root `entity::` 即 build-fail）；audit.rs 為機制本體、不得碰 entity 型；op-log 構造全交 facade。`mutate_in_txn` 對所有 entity 中立（不隨新表改）＝§5.2「audit.rs 不 import entity」。
**Alternatives**：trait/wrapper 直接構造 op-log——否決（破 lint＋耦合表）。

## R4 — `IpNetwork` import 路徑（R-B、lint-safe）

**Decision**：`audit.rs` 用 `use sea_orm::entity::prelude::IpNetwork;`（`AuditOperator.ip: Option<IpNetwork>`）。
**Rationale**（grep）：`pub use ipnetwork::IpNetwork;` @ `sea-orm/src/entity/prelude.rs:91`（with-ipnetwork 經 workspace feature 聯集對 server crate 可見）。此路徑 `entity` 前界為 `:`（`sea_orm::entity::`）→ `entity_access_lint` **不誤判**（同 004 soft_delete.rs `sea_orm::entity::prelude::*` 之 colon-preceded 豁免；非 entity crate root）。
**Alternatives**：`use ipnetwork::IpNetwork`——否決（ipnetwork 非 server 直接 dep、僅經 sea-orm）。實作 build error 若指引別路徑（如 `sea_orm::prelude::IpNetwork`）則採可編譯者、注記。

## R5 — `AuditSerialize` redact 機制（R-C、守「無 entity 變動」）

**Decision**：`facade/sys_user.rs` 的 `impl AuditSerialize for entity::sys_user::Model` **手構** `audit_json`（`serde_json::json!({...})` 逐欄、`password`→`"<redacted>"`、其餘原值）；**不**對 entity 加 `Serialize` derive。
**Rationale**（grep）：sys_user Model derive＝`Clone, Debug, PartialEq, DeriveEntityModel, Eq`（**無 Serialize**）。加 Serialize＝entity 變動（違 brainstorm「純 model/ 新增」＋D1 凍結）；且 serialize-all 對「未來新增敏感欄忘記 redact」不安全。手構在 facade＝遮蔽**顯式**（看得到 password 被遮）、entity 凍結、且 entity:: 在 facade 合法。
**Alternatives**：對 sys_user 加 `Serialize` derive 後 serialize→override password——否決（entity 變動＋未來欄洩漏風險）。

## R6 — `Model → ActiveModel` update 形（R-D）

**Decision**：soft_delete 閉包內 `let mut am = before.clone().into_active_model(); am.deleted_at = Set(Some(now)); let after = am.update(&txn).await?;`（或 struct-update `ActiveModel { deleted_at: Set(...), ..before.clone().into_active_model() }`）。
**Rationale**（grep）：`trait IntoActiveModel { fn into_active_model(self)->A }`(active_model.rs:644-656)；DeriveEntityModel 生成 `Model: IntoActiveModel<ActiveModel>`（全欄 `Unchanged`）→ 改 `deleted_at=Set`、其餘保留 → `.update()` 回更新後 Model（after 快照）。
**Alternatives**：手構 ActiveModel 全欄——否決（冗長易漏欄）。

## R7 — 無 migration／archetype B append-only（DESIGN §3.2、constitution §I.6）

**Decision**：本刀**無** migration、不建表、不改 schema；`sys_operation_log` 已於 002（m001 squash）建、004 反射 entity。facade 對 op-log **只暴露 insert（`write_in_txn`）、無 update/delete**（archetype B、§I.6「append-only、MUST NOT 加 updated_*/deleted_*」、不可竄改）。
**Rationale**：§I.6 archetype B 明定三 log 表 append-only；op-log facade 守此＝US3／FR-004。
**Alternatives**：無。

## R8 — RUSTAPI-SOURCE-ISOLATION（§I.5）＋ 三-grep 紀律

**Decision**：audit.rs／facade **全新寫**（§I.5；audit/facade 不在拷貝例外清單〔唯 sea-orm-adapter/xdb〕）；rev2 011 僅受控參照（讀允許、拷貝禁止、防回歸）。
**三-grep 落地**：
- **facade/entity 返回型 grep**：`sys_operation_log` Model 10 欄已親驗（§2.3、R7）；`sys_user` Model（soft_delete 回 raw Model）已親驗。
- **wire 3 端對齊**：N/A（本刀無 endpoint／wire／base-web 改動）。
- **命名對照**：op-log 欄名／型逐欄對 m001（已親驗）；operation 欄 DB 字串＝`as_str()` 契約（INSERT/UPDATE/SOFT_DELETE/RESTORE）。
- **CDP smoke defer**：N/A（無 UI／endpoint；唯一活體＝atomicity live smoke、非 CDP）。
