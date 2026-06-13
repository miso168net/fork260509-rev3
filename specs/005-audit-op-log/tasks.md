# Tasks: audit-op-log（mutate_in_txn 同 txn 原子審計＋sys_operation_log sink＋soft_delete proof）

**Input**: Design documents from `/specs/005-audit-op-log/`

**Prerequisites**: plan.md ✅、spec.md ✅、research.md（R1~R6）✅、data-model.md ✅、contracts/（audit-contract＋verification-commands）✅、quickstart.md ✅

**Tests**: 本 feature **test-first TDD**（plan Testing 明示——純函式：`audit_json` redact〔password→`"<redacted>"`〕＋`audit_active_model` SQL-build〔INSERT op-log＋operator_ip None→欄略過〕，**零 DB**；inline `#[cfg(test)]` 於 facade）＋**bounded 实机 smoke**（`#[ignore]`、postgres+migrate、拋棄式 user＋hard_clean，3 場景 commit/no-op/rollback 證原子）。同 004、與 002「靠實機」混合：純函式 red→green，DB 行為（尤 rollback）有界 smoke 釘死。

**Organization**: 依 user story 分 phase。**build 序＝Setup(deps+entity+audit 機制)→US3(op-log sink)→US2(redact)→US1(atomicity 整合 proof)→Polish**——⚠️ **build 序為依賴序、非 spec 優先序**（US1 atomicity 為 P1 MVP，但其 proof〔soft_delete live smoke〕**依賴 US2 audit_json＋US3 write_in_txn 元件**，故 US1 整合為最後 capstone；mutate_in_txn 機制核心本身在 Setup〔T003〕。同 003 倒序情形）。**兩段式 commit 紀律（001/002/003/004 教訓）**：worktree task 完成即 worktree commit＋outer pin 隨同 bump（不延後收口）。**§I.4／⚠️u：全程不 push 不 merge**。**⚠️g：audit/facade 對前代 source 讀允許、code 全新寫**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（deps＋entity Model＋audit 機制核心——blocking 全部 US）

- [ ] T001 [P] 依賴增量：`rust-api/entity/Cargo.toml` sea-orm features `["with-chrono"]`→`["with-chrono","with-json"]`（JSONB `payload_*` 需 with-json；serde_json 已在 lock〔003〕、無新外部 crate）；`rust-api/entity/src/lib.rs` 加 `pub mod sys_operation_log;`。
- [ ] T002 新 entity Model：`rust-api/entity/src/sys_operation_log.rs`（`DeriveEntityModel` 10 欄逐欄鏡像 m001——`id` i64 PK／`operation` String／`entity_table` String／`entity_id` Option\<i64\>／`payload_before` Option\<Json\>／`payload_after` Option\<Json\>／`operator_id` Option\<i64\>／`operator_ip` Option\<String\>〔INET〕／`trace_id` Option\<String\>／`created_at` DateTimeWithTimeZone；空 `Relation`）；**逐欄對 m001 grep（research R1／data-model §2）、不信假設**。
- [ ] T003 server `model/audit.rs`（全新寫⚠️g、**零 `entity::`** 守 lint③）：`AuditOperation`（**全 4** Insert/Update/SoftDelete/Restore＋`as_str()`）／`AuditOperator{id,ip}`／`AuditEvent`〔7 欄〕／`AuditSerialize` trait／`mutate_in_txn<R,F,Fut>` 泛型 wrapper（begin→f→Some(event)時 write_in_txn→commit；對 research R2.1／data-model §3）；`model/mod.rs` 加 `pub mod audit;`；`facade/mod.rs` 加 `pub mod sys_operation_log;`。
- [ ] T004 建置驗（C-V-1）：容器 `cargo build --bins`（host 無 cargo、rust:1.86、warm cargo cache、卷 cv005-target、`--offline`）；`grep with-json rust-api/entity/Cargo.toml` 含、`grep -c 'name = "serde_json"' Cargo.lock ≥1`；綠＝entity +with-json 編譯（JSONB Model 解析）、audit 連結。worktree commit＋outer pin bump。

**Checkpoint**: entity Model 對齊 m001、with-json 編譯、audit.rs 機制核心掛載（零 entity::）、build 綠。

## Phase 2: US3 — 審計 sink append-only＋事件完整（P3；依賴 audit.rs〔T003〕＋entity〔T002〕）🎯 op-log sink

**Goal**: op-log facade append-only 寫入閘、`AuditEvent`→`ActiveModel` 完整映射（含 42804 規避）
**Independent Test**: `audit_active_model` SQL-build——INSERT `"sys_operation_log"`＋核心欄＋`operator:None` 時 operator_ip 欄略過（純 render、無 DB）

- [ ] T005 [US3] test-first：`rust-api/server/src/model/facade/sys_operation_log.rs` 的 `#[cfg(test)]` 寫 SQL-build 測（red；`Entity::insert(audit_active_model(event)).build(DbBackend::Postgres).to_string()` 斷言含 `INSERT INTO "sys_operation_log"`＋`"operation"`/`"entity_table"`/`"entity_id"`/`"payload_before"`/`"payload_after"` 欄＋`operator:None` 時 NOT 含 `"operator_ip"`——對 contracts/audit-contract.md §3②；red 因 `audit_active_model` 未實作）。
- [ ] T006 [US3] 實作：`facade/sys_operation_log.rs` 加 `fn audit_active_model(event)->ActiveModel`（純映射；`id`/`created_at` NotSet；`operation`=`as_str()`；**`operator_ip` None→`NotSet` 避 PG 42804**、對 research R2.2/R4）＋`pub async fn write_in_txn(txn,event)->Result<(),DbErr>`（`audit_active_model(event).insert(txn)`、append-only）；容器 `cargo test -p server` 綠（SQL-build＋既有 004 lint③/query-shape 全綠）；worktree commit＋pin bump。

**Checkpoint**: US3 全綠＝op-log sink 就位（append-only、42804 規避、SQL-build 證；SC-003/004 部分達成）。

## Phase 3: US2 — 審計快照 redact（P2；依賴 AuditSerialize trait〔T003〕）

**Goal**: `sys_user::Model::audit_json()` redact `password`（guard：審計不洩漏敏感資料）
**Independent Test**: `audit_json` password=="<redacted>"、其餘非敏感欄保留（純函式、無 DB）

- [ ] T007 [US2] test-first：`rust-api/server/src/model/facade/sys_user.rs` 的 `#[cfg(test)]` 寫 redact 測（red；建 `sys_user::Model`〔password 設值〕→ `audit_json()` 斷言 `["password"]=="<redacted>"`＋`["user_name"]` 等保留——對 contracts/audit-contract.md §3①；red 因 `impl AuditSerialize` 未實作）。
- [ ] T008 [US2] 實作：`facade/sys_user.rs` 加 `impl crate::model::audit::AuditSerialize for Model { fn audit_json() }`（`serde_json::json!` redact `password`→`"<redacted>"`、**15 欄排除 `current_session_id`**、timestamps `.to_rfc3339()`、對 research R2.3）（green T007）；容器 `cargo test -p server` 綠（redact＋SQL-build＋lint 全綠）；worktree commit＋pin bump。

**Checkpoint**: US2 全綠＝審計快照 redact 鎖定（SC-002 純函式部分達成）。

## Phase 4: US1 — 業務寫＋審計寫原子（P1 MVP；依賴 US2 audit_json〔T008〕＋US3 write_in_txn〔T006〕）🎯 MVP capstone

**Goal**: `mutate_in_txn` 業務寫＋審計寫同 txn（commit／no-op／rollback 原子）——本刀 MVP 整合 proof
**Independent Test**: 实机 smoke——commit 寫恰好 1 筆 redacted 審計＋user 軟刪／no-op 不寫／審計 INSERT 失敗整 txn 回滾

- [ ] T009 [US1] facade 寫路徑 proof：`facade/sys_user.rs` 加 `pub async fn soft_delete(db, id:i64, operator:i64)->Result<bool,DbErr>`（包 `mutate_in_txn`：`find_active().filter(Id.eq(id)).one(&txn)` → None:`(txn,false,None)` no-op／Some(model):`before=model.audit_json()`＋`soft_delete_query(id,operator).exec(&txn)`〔寫 deleted_at+deleted_by〕＋`AuditEvent{SoftDelete,"sys_user",Some(id),Some(before),None,Some(AuditOperator{id:operator,ip:None}),None}`＋`(txn,true,Some(event))`）＋`fn soft_delete_query(id,operator)->UpdateMany<Entity>` helper（對 research R2.3／data-model §4）；容器 `cargo build -p server` 綠（facade 編譯、`entity_access_lint` 仍綠＝entity:: 全在 facade/）；worktree commit＋pin bump。
- [ ] T010 [US1] test-first 实机 smoke（C-V-4）：`facade/sys_operation_log.rs`（或 sys_user）的 `#[cfg(test)] mod live_tests`、`#[tokio::test] #[ignore]`、`DATABASE_URL` connect、**拋棄式 user（id 9xxxxx）＋hard_clean** 隔離（對 contracts/audit-contract.md §4／R2.4）——3 場景：① commit `soft_delete(900001,1)`→`Ok(true)`＋恰好 1 筆審計（operation/entity_table/entity_id/**operator_id==Some(1)〔操作者要素、SC-004、C1〕**/`payload_before["password"]=="<redacted>"`）＋user 軟刪；② no-op（不存在/已刪→`Ok(false)` 不寫）；③ rollback（閉包 UPDATE 後 `entity_table` 超長致 write_in_txn 失敗→`mutate_in_txn` Err＋user UPDATE 回滾〔deleted_at None〕＋審計 0 列）。起 `docker compose ... up -d --wait postgres migrate`、**網路 `rev3-admin_rev3_net` 實解（`docker network ls | grep rev3`、非 stale `_default`）**、`cargo test -p server -- --ignored --test-threads=1` 綠；**純 `cargo test` 不含**（`#[ignore]`）。worktree commit＋pin bump。

**Checkpoint**: US1 全綠＝原子審計機制实机證（commit/no-op/rollback；SC-001/002/003/004 全達成）。

## Phase 5: Polish & Cross-Cutting

- [ ] T011 C-V-5 殘留 grep（部署層零 rev2／rust-api 新寫零 rev2 token）：`grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/` 零命中＋`grep -rinE "rev2" rust-api/server/src/model/audit.rs rust-api/server/src/model/facade/sys_operation_log.rs rust-api/entity/src/sys_operation_log.rs` 零命中（用「前代」描述）＋C-V-6 `/health` 不退化（`grep -nE 'async fn health|"ok"' rust-api/server/src/main.rs` 確認不變）＋quickstart.md 流程逐步對照＋拋棄式卷清理（`docker volume rm cv005-target`、停 smoke stack）。
- [ ] T012 收口驗證（**commit only——push／merge 凍結至 finishing，§I.4／⚠️u**）：worktree 全 task commit 齊＋outer pin==worktree HEAD（隨 task bump 紀律回顧）＋specs/005 外層檔全收（已隨 speckit auto-commit）＋`git submodule status` 行首空格。**非新 crate ⇒ 無 Dockerfile 改動、無 prod build 收口項**（異於 004）。

## Dependencies

```
Phase 1 (T001→T002→T003→T004) ──→ US3 (T005→T006) ──→ US2 (T007→T008) ──→ US1 (T009→T010) ──→ Polish (T011→T012)
build 依賴：entity Model〔T002〕＋audit.rs 機制〔T003〕＝foundational；US3 op-log sink〔T006〕← US1 soft_delete〔T009 經 mutate_in_txn 呼 write_in_txn〕；US2 audit_json〔T008〕← US1 soft_delete〔T009 用 before=audit_json()〕；US1 实机 smoke〔T010〕需 postgres+migrate。
build 序＝依賴序（US3→US2→US1）、**非 spec 優先序**——US1 atomicity 為 P1 MVP 但其 proof 整合 US2/US3 元件、故 capstone 在最後（mutate_in_txn 機制核心在 Setup T003）。
test-first：US3 SQL-build（T005 red→T006 green）／US2 redact（T007 red→T008 green）；US1 实机 smoke（T010、#[ignore]）。
```

## Parallel Execution Examples

- Phase 1：T001 可獨立（deps 編輯）；T002→T003→T004 序列（Model→audit 機制→build）。
- US3〔T005-006〕與 US2〔T007-008〕**不同檔**（`facade/sys_operation_log.rs` vs `facade/sys_user.rs`）、file-wise 可並行；但 US1 soft_delete〔T009〕依賴兩者 ⇒ 單 implementer 序列先 US3 後 US2（順序可互換）再 US1。
- story 內 test→impl 嚴格序列（red→green）；US1 依賴 US2/US3 元件、序列在後。

## Implementation Strategy

**機制先行、proof 收尾**：Phase 1（Setup＝entity Model＋audit.rs `mutate_in_txn` 機制核心）＝「原子審計機制就位」的地基；US3（op-log sink）＋US2（redact）為支撐元件（各 test-first 純測）；US1（atomicity 整合 proof＝soft_delete＋3 場景 实机 smoke）為 MVP capstone、整合前述元件於最後實機釘死「commit/no-op/rollback 原子」。每 phase checkpoint 過了才前進；test-first 嚴格 red→green；**非新 crate ⇒ 無 mandatory prod build**（異於 004、C-V-1 build 即涵蓋 with-json）。任一 `cargo test` fail＝對 contracts/research grep 座標校形、不調測試遷就實作（redact 紅校 R2.3／SQL-build 紅校 R2.2／rollback 紅校 contract §4 txn 邊界）。
