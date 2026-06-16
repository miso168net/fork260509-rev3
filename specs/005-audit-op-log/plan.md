# Implementation Plan: 操作審計 op-log 機制（mutate_in_txn 同 txn 原子審計＋op-log sink）

**Branch**: `005-audit-op-log` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/005-audit-op-log.md`（audit ×2 之首；§4 五拍板：機制+單一 proof／顯式 operator／AuditOperation 全4／AuditOperator.ip→IpNetwork／redact 純測+原子 live smoke）

## Summary

L4 **audit 機制地基**：`server/src/model/audit.rs`（`mutate_in_txn` 泛型 wrapper〔業務寫＋op-log 寫**同 txn 原子**〕＋`AuditOperation`/`AuditOperator`/`AuditEvent`/`AuditSerialize`、純資料層零 `entity::`）＋`facade/sys_operation_log.rs`（append-only sink `write_in_txn`）＋`facade/sys_user.rs` 加 `impl AuditSerialize`（redact `password`）＋`soft_delete` 單一寫路徑 proof。本刀**只建機制＋一條 proof**：零業務端點、零其餘寫路徑、零 migration、**零新 crate、零 Cargo.toml 變動**（004 已建齊 entity＋with-json）。對應前代 011。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-toolchain pin）

**Primary Dependencies**: **無新增**——`server` deps 已含 `sea-orm`(workspace、with-ipnetwork via feature 聯集)＋`serde_json`(003)＋`entity`(path、004)。audit.rs 用 `serde_json::Value`＋sea_orm txn 型（`TransactionTrait`/`DatabaseTransaction`/`DbErr`）＋`sea_orm::entity::prelude::IpNetwork`（R-B）。

**Storage**: PostgreSQL（既有 dev stack、002 schema＋seed）。**本刀無 migration、無建表、無 schema 變更**（`sys_operation_log` 已於 m001/002 建、004 反射 entity）；live smoke 自連 DATABASE_URL（main.rs 不接 runtime DB）。

**Testing**: rust in-crate `#[cfg(test)]`（redact 純測、無 DB→一般 `cargo test`）＋in-crate `#[ignore]` live（mutate_in_txn 原子、DATABASE_URL＋`--test-threads=1`＋外層 txn-savepoint 隔離）＋既有 `entity_access_lint`（守 audit.rs lint-clean）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。**無 prod build**（無新 crate）。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內）。

**Project Type**: backend（rust-api workspace）——L4 audit 機制＋op-log facade。

**Performance Goals**: N/A（本 infra 刀無端點；⚠️a「寫含同 txn 審計 p95<500ms」為波1+ 有端點時驗收目標）。

**Constraints**: RUSTAPI-SOURCE-ISOLATION（audit/facade 全新寫、§I.5、不在拷貝例外）；**無 migration**（schema 002 凍）；archetype B append-only（§I.6）；audit.rs **零 `entity::`** 守 lint；**零業務端點/其餘寫路徑/新 crate**；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: `server/src/model/audit.rs`（~80-100 行）＋`facade/sys_operation_log.rs`（write_in_txn）＋`facade/sys_user.rs` +impl AuditSerialize +soft_delete＋in-crate 測（redact 純測＋原子 live smoke）＋`mod.rs` ×2 串接。deps＝零變動。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 為權威？rust-api 缺對應 endpoint？ | **PASS（未觸）**——本刀無 endpoint、無 base-web 改動；建後續寫端刀所依賴的 audit 機制地基，不縮減設計範圍 |
| 2 | 動 base-web inline？ | **PASS（未觸）**——零 base-web 改動 |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（未觸）**——無 menu／route |
| 4 | wire 對齊 §I.3 typings？ | **PASS（未觸）**——本刀無 wire／endpoint／序列化出口；audit 為內部 L4 機制 |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——audit/facade 全新寫（§I.5；不在拷貝例外清單〔唯 sea-orm-adapter/xdb〕）；前代 011 受控參照（讀允許、拷貝禁止）；防回歸：無帶回已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——無拍板需改；mutate_in_txn/op-log 為 DESIGN §5.2 既定 audit 面地基 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸 ★）**——rust-api 走 RUSTAPI-SOURCE-ISOLATION（§III.1 預設可動、非 ★）；無 base-web ★ 軌道 |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——本刀無 migration、不建表（schema 002 已建；FR-009／SC-005）；§I.6「建表即帶審計欄」N/A（無建表）；op-log＝archetype B append-only（facade 只 insert、守 §I.6「MUST NOT 加 updated_*/deleted_*」） |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸行為）**——op-log 為純 mutation 審計機制，**無行為邏輯**（token rotation／policy governance／single-session 皆不動）；invariants 不動 |

**Gate 結論：9/9 PASS；無 violation 待 justify、Complexity Tracking 不適用。**

> **新 workspace crate ⇒ prod build 紀律 N/A**：本刀**無**新 crate（異於 004）；故 acceptance **不含** prod target build（C-V-0~3 無 prod build）。

## Project Structure

### Documentation (this feature)

```text
specs/005-audit-op-log/
├── spec.md              # /speckit-specify ✅（US1~US3、16/16 checklist、NEEDS CLARIFICATION=0）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R8；R-A~R-D 全 ground-truth grep sea-orm 1.1.20）
├── data-model.md        # Phase 1 ✅（audit.rs 型＋mutate_in_txn 簽名＋facade＋redact＋原子流程）
├── quickstart.md        # Phase 1 ✅（4 步驗證）
├── contracts/
│   ├── verification-commands.md      # C-V-0~3（build／redact 純測／原子 live smoke／lint 守恆）
│   └── audit-op-log-contract.md      # mutate_in_txn 原子／redact／append-only／operator 不變式
└── checklists/requirements.md        # 16/16 ✅
```

### Source Code (repository root)

```text
rust-api/server/src/model/
├── mod.rs                    # +pub mod audit;（檔頭註解更新：soft_delete 寫 proof 已落本刀）
├── audit.rs                  # ★ 新：AuditOperation/Operator/Event/Serialize + mutate_in_txn（純、零 entity::）
├── soft_delete.rs            # 004 既有（不動）
└── facade/
    ├── mod.rs                # +pub mod sys_operation_log;
    ├── sys_operation_log.rs  # ★ 新：write_in_txn（append-only sink、唯一構造 op-log ActiveModel）
    ├── sys_user.rs           # 004 既有、加：impl AuditSerialize（redact password）+ soft_delete proof + in-crate 測
    ├── sys_role.rs           # 004 既有（不動）
    └── sys_menu.rs           # 004 既有（不動）

# 不動：entity/（004 已建齊）、migration/、deploy/、所有 Cargo.toml、server/tests/entity_access_lint.rs（既有、續綠）
```

**Structure Decision**：backend（rust-api workspace）。L4 `model/audit.rs`（機制）＋`facade/sys_operation_log.rs`（sink）＋`facade/sys_user.rs`（proof）。**無 entity／migration／Cargo.toml／deploy 改動**。tests：redact 純測（一般 `cargo test`）＋原子 live smoke（in-crate `#[ignore]`、txn-savepoint 隔離）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks）

1. **順序**：`audit.rs`（型＋trait＋mutate_in_txn〔泛型 C: TransactionTrait〕）→ `facade/sys_operation_log.rs`（write_in_txn）→ `facade/sys_user.rs`（impl AuditSerialize 手構 redact ＋ soft_delete 包 mutate_in_txn）→ `mod.rs` ×2 串接 → redact 純測（test-first）→ 原子 live smoke（`#[ignore]`、外層 txn-savepoint）→ C-V（build／redact／live／lint）→ **兩段式 commit**（rust-api worktree → outer pin）。
2. **R-A mutate_in_txn 泛型**：`C: TransactionTrait`（吃 `&DatabaseConnection` production／`&DatabaseTransaction` test-savepoint）；閉包 `FnOnce(DatabaseTransaction)->Fut`、回 `(txn, R, Option<AuditEvent>)`；`Ok(_,None)`=no-op、`Err`=整滾。
3. **R-B IpNetwork**：`use sea_orm::entity::prelude::IpNetwork`（colon-preceded、lint-safe）；build error 若指引別路徑採可編譯者、注記。
4. **R-C redact**：sys_user Model 無 Serialize → facade `audit_json` **手構** `serde_json::json!`（逐欄、password→`<redacted>`）；**不**加 entity Serialize derive（守無 entity 變動）。
5. **R-D update 形**：`before.clone().into_active_model()`→`am.deleted_at=Set(Some(now))`＋`am.deleted_by=Set(Some(operator.id))`（§I.6 成對）→`am.update(&txn)`。
6. **live smoke 隔離（核心）**：test 開外層 `db.begin()`→傳 `&outer` 給 soft_delete（mutate_in_txn 內 nested begin＝savepoint）→ 同 outer 查 op-log → `outer.rollback()` 不污染 seed；**必含 rollback 路徑**（注入失敗驗業務+審計雙不留、防 vacuous）；`--test-threads=1`。
7. **lint 守恆**：`audit.rs` 零 path-root `entity::`；op-log 構造全在 facade；既有 `entity_access_lint` 續綠（C-V-3）。
8. **無 migration／無新 crate／push 凍結**：本刀無 migration、無 prod build；實作期 commit only、tasks.md 不得出現 push／merge（§I.4）。
