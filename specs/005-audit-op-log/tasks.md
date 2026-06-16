# Tasks: 操作審計 op-log 機制（mutate_in_txn 同 txn 原子審計＋op-log sink）

**Input**: Design documents from `/specs/005-audit-op-log/`

**Prerequisites**: plan.md ✅、spec.md ✅（US1~US3、16/16 checklist、NEEDS CLARIFICATION=0）、research.md（R1~R8、R-A~R-D 全 ground-truth grep sea-orm 1.1.20）✅、data-model.md（audit.rs 型＋mutate_in_txn 簽名＋facade＋redact＋原子流程）✅、contracts/（verification-commands＋audit-op-log-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS）

**Tests**: 本 feature **有契約/純測/活體測**（spec FR-003/006/007＋C-V）。redact 純測＝in-crate `#[cfg(test)]`（無 DB、test-first）；mutate_in_txn 原子＝in-crate `#[cfg(test)] #[ignore]`＋外層 txn-savepoint 隔離＋DATABASE_URL＋`--test-threads=1`；lint 守恆＝既有 `entity_access_lint`（C-V-3）。

**Organization**: 依 user story 分 phase。**rust 全程 serial**（共用 target、即使 [P] 不平行 cargo）、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime 假綠）；**兩段式 commit**（rust-api worktree→outer pin、不延後）；**§I.4：全程不 push 不 merge**。**無 prod build**（本刀無新 workspace crate）。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（rust-api worktree、blocking 全 US）

**Purpose**: model/ 模組串接就位。⚠️ 動 rust-api worktree——兩段式 commit。

- [ ] T001 `rust-api/server/src/model/mod.rs` 加 `pub mod audit;`（並更新檔頭註解：soft_delete 寫 proof 已落本刀）＋`rust-api/server/src/model/facade/mod.rs` 加 `pub mod sys_operation_log;`（檔頭註解更新：加 op-log append-only sink）

**Checkpoint**: 模組宣告就位（待 T002~ 填內容才編譯綠）

## Phase 2: Foundational（audit 機制核心＋redact impl＋sink；blocking 全 US）

**Purpose**: 表中立的 audit 機制（純資料層）＋op-log append-only sink＋sys_user redact impl——US1/US2/US3 共享前置。

- [ ] T002 `rust-api/server/src/model/audit.rs`（新建、純資料層、**零 `entity::`**）：`AuditOperation`（全 4 `Insert`/`Update`/`SoftDelete`/`Restore`＋`as_str()`→`"INSERT"`/`"UPDATE"`/`"SOFT_DELETE"`/`"RESTORE"`）＋`AuditOperator{ id: i64, ip: Option<IpNetwork> }`＋`AuditEvent{ operation, entity_table:String, entity_id:Option<i64>, payload_before/after:Option<serde_json::Value>, operator:Option<AuditOperator>, trace_id:Option<String> }`＋`pub trait AuditSerialize { fn audit_json(&self)->serde_json::Value; }`。`IpNetwork` 由 `use sea_orm::entity::prelude::IpNetwork`（R-B、colon-preceded lint-safe）。本刀只構造 `SoftDelete`、其餘 3 種 `never constructed` warning **不抑制**（infra-ahead-of-consumer）（依 T001）
- [ ] T003 `rust-api/server/src/model/audit.rs` 加 `mutate_in_txn<C, R, F, Fut>(conn:&C, f:F)`（泛型 `C: TransactionTrait`、R-A）：`conn.begin()` → `f(txn)` 回 `(txn, R, Option<AuditEvent>)` → `if Some(ev){ facade::sys_operation_log::write_in_txn(&txn, ev).await? }` → `txn.commit()`。`Ok(_,None)`=no-op（不寫審計、commit、無副作用）；`Err`=整 txn rollback（業務寫＋op-log 寫一起不留）（依 T002、T004）
- [ ] T004 `rust-api/server/src/model/facade/sys_operation_log.rs`（新建、append-only sink）：`write_in_txn(txn:&DatabaseTransaction, event:AuditEvent)->Result<(),DbErr>`——由 `AuditEvent` 構 `entity::sys_operation_log::ActiveModel` insert（`operation`=event.operation.as_str()、`operator_id`/`operator_ip` 拆自 `event.operator`、`payload_before/after`=Json、`entity_table`/`entity_id`/`trace_id`；`id`/`created_at` 不 Set〔DB 生成〕）。**唯一構造 op-log entity 處、無 update/delete fn**（archetype B、§I.6）（依 T002）
- [ ] T005 `rust-api/server/src/model/facade/sys_user.rs`（004 既有、加）：`impl AuditSerialize for entity::sys_user::Model`——`audit_json()` **手構** `serde_json::json!({...})`（逐欄、`password`→`"<redacted>"`、其餘原值；R-C：Model 無 Serialize derive、**不**加）。供 US1 proof 快照＋US2 redact 測共用（依 T002）
- [ ] T006 C-V-0 build：容器內 force-touch `server/src` → `cargo build -p server` 綠（mod audit＋sink＋AuditSerialize 編譯、`IpNetwork` 解析；`never constructed` warning 可接受）（依 T002~T005）

**Checkpoint**: 機制核心＋sink＋redact impl 編譯綠

## Phase 3: US1 — 統一 mutation 原子審計（P1）🎯 MVP

**Goal**: mutate_in_txn 業務寫＋op-log 寫同 txn 原子（commit 一起、失敗一起滾）。
**Independent Test**: C-V-2 atomic live（外層 txn 內 soft_delete → 同 txn 見 op-log；注入失敗 → 雙不留）；不依賴 US2/US3。

- [ ] T007 [US1] `rust-api/server/src/model/facade/sys_user.rs` 加 `soft_delete<C: TransactionTrait>(conn:&C, id:i64, operator:AuditOperator, trace_id:Option<String>)->Result<Option<Model>,DbErr>`（包 `mutate_in_txn`、R-D）：閉包內 `Entity::find_by_id(id).one(&txn)`（before）→ 查無回 `(txn,None,None)`（no-op）→ 查有則 `before.clone().into_active_model()`＋`deleted_at=Set(Some(now))`＋`deleted_by=Set(Some(operator.id))`（§I.6 成對）→ `.update(&txn)`（after）→ `AuditEvent{ SoftDelete, "sys_user", Some(id), Some(before.audit_json()), Some(after.audit_json()), Some(operator), trace_id }` → 回 `(txn, Some(after), Some(event))`（依 T003~T005）
- [ ] T008 [US1] `rust-api/server/src/model/facade/sys_user.rs` in-crate `#[cfg(test)] #[ignore]` atomic live smoke（C-V-2、fn 名含 `op_log_atomic`）：開**外層** `db.begin()` → `soft_delete(&outer, Super id=1, operator, None)`（mutate_in_txn 內 nested begin＝savepoint）→ 同 outer 查 `sys_operation_log`：**commit 路徑**斷言恰一列（`operation=SOFT_DELETE`/`entity_table=sys_user`/`entity_id=1`/`payload_before.password=<redacted>`/`payload_after.deleted_at` 非空/`operator_id`）＋sys_user.deleted_at 已 set；**rollback 路徑**注入失敗（不存在 id 或閉包 Err）斷言 op-log 不留、業務不改（原子釘死、非 vacuous）→ `outer.rollback()`（不污染 seed）。容器內 force-touch → `DATABASE_URL="$(cat /run/secrets/database_url)" cargo test -p server -- --ignored --test-threads=1 op_log_atomic`（警覺「0 passed/N filtered」假綠）（依 T007）

**Checkpoint**: US1 全綠＝MVP（SC-001/002；同 txn 原子審計成立）→ **雙段 commit**（worktree→outer pin）

## Phase 4: US2 — 敏感欄遮蔽（P2）

**Goal**: 審計快照敏感欄遮蔽、可證生效。
**Independent Test**: C-V-1 redact 純測（無 DB）；需 T005 AuditSerialize impl（Foundational）、不依賴 US1/US3。

- [ ] T009 [US2] `rust-api/server/src/model/facade/sys_user.rs` in-crate `#[cfg(test)]` redact 純測（**非** `#[ignore]`、無 DB、test-first 精神、fn 名含 `redact`）：對 `sys_user::Model{ password:"secret".into(), user_name:"X".into(), ..預設 }` 取 `audit_json()` → 斷言 `["password"]=="<redacted>"` ＋ `["user_name"]=="X"`（其餘欄保留）。容器內 force-touch → `cargo test -p server redact`（警覺「0 passed/N filtered」）（依 T005）

**Checkpoint**: US2 全綠（SC-003；遮蔽生效）→ **雙段 commit**（或併 US1 段）

## Phase 5: US3 — append-only 完整性 ＋ facade 守恆（P3）

**Goal**: op-log append-only（無 update/delete）＋ audit.rs lint-clean（facade 唯一管道守恆）。
**Independent Test**: C-V-3 lint green ＋ sink insert-only；需 audit.rs/facade 存在（Foundational/US1 後）、不依賴 US2。

- [ ] T010 [US3] C-V-3 lint 守恆：容器內 force-touch `server/src server/tests` → `cargo test -p server --test entity_access_lint` 綠（既有 004 守恆續綠；`audit.rs` 零 path-root `entity::`〔`sea_orm::entity::prelude::IpNetwork` 為 colon-preceded 豁免〕；op-log 構造在 `facade/` 豁免）＋**設計審查**確認 `facade/sys_operation_log.rs` 僅 `write_in_txn`（無 update/delete fn、archetype B、§I.6）（依 T002~T004）

**Checkpoint**: US3 全綠（SC-004/FR-007；append-only＋facade 守恆 enforced）→ **雙段 commit**

## Phase 6: Polish & Cross-Cutting

- [ ] T011 收口驗證（**commit only——push/merge 凍結至 finishing、§I.4**）：rust-api worktree 全 task commit 齊＋outer pin == worktree HEAD（pin 隨 task bump 紀律回顧）＋specs/005 外層檔收；`git submodule status` rust-api 行首空格；**C-V-0~3 全綠彙整**（build／redact 純測／atomic live smoke／lint 守恆）；**SC-007 零回歸實證**：dev stack `up -d --wait` 全 healthy ＋ `curl -fsS http://127.0.0.1:31081/health` 回 `ok`（無 router 改動、新碼編入執行中服務）；**SC-005/006 範圍核**：diff 確認零端點/零 migration/零 Cargo.toml 變動/零新 crate、`audit.rs` 無表名硬編（表中立）；quickstart 4 步逐步對照綠。**無 prod build**（無新 workspace crate）

## Dependencies

```
Setup (T001) ─→ Foundational (T002→{T003,T004,T005}→T006)  [rust-api worktree、serial]
   T002（型/trait）blocks T003（mutate_in_txn 用型）/T004（sink 用 AuditEvent）/T005（impl 用 trait）
   T003 依 T004（mutate_in_txn 呼叫 write_in_txn）；T006 build 依 T002~T005
Foundational ──┬─→ US1 (T007→T008)        [proof 用 mutate_in_txn+sink+AuditSerialize impl]
               ├─→ US2 (T009)              [redact 測用 T005 impl]
               └─→ US3 (T010)              [lint 掃 audit.rs/facade]
US1+US2+US3 ──→ Polish (T011 殿後)
US1 ∥ US2 ∥ US3（概念上不同驗證面可並行；單實作者則序：US1 MVP 先 → US2 → US3）
```

## Parallel Execution Examples

- **概念並行**：US2（redact 純測）∥ US3（lint 守恆）——不同驗證面、皆依 Foundational。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔/邏輯可並行」。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T008）＝Setup＋Foundational（機制核心＋sink＋redact impl）＋US1（proof＋atomic live smoke）即最小價值（同 txn 原子審計成立）。US2 redact 純測（T009）＋US3 lint 守恆（T010）緊接；Polish 收口（C-V 彙整／零回歸／範圍核）。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進。**rust serial、容器內 build/test、改 .rs 先 force-touch；live smoke 外層 txn-savepoint 隔離不污染 seed；兩段式 commit（worktree→outer pin）；全程不 push/merge；無 prod build（無新 crate）**。
