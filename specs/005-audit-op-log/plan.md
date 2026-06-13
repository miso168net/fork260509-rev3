# Implementation Plan: audit-op-log（mutate_in_txn 同 txn 原子審計＋sys_operation_log sink＋soft_delete proof）

**Branch**: `005-audit-op-log` | **Date**: 2026-06-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-audit-op-log/spec.md`＋brainstorm `docs/superpowers/005-audit-op-log.md`（刀界 A 機制+proof／proof 單一 soft_delete／operator 顯式 param／AuditOperation 全 4／驗證 ii commit+rollback／無 migration／擴 entity crate +with-json）

## Summary

把 rust-api 的「mutation → op-log 同 txn 原子審計」機制一次立起：`model/audit.rs`（`mutate_in_txn` 泛型 wrapper〔業務寫＋審計寫綁同一 `DatabaseTransaction`、同 commit／同 rollback〕＋`AuditOperation` 全 4／`AuditOperator`／`AuditEvent`／`AuditSerialize` trait，純資料層、零 `entity::`、守 lint ③）＋`sys_operation_log` entity（擴現有 entity crate、逐欄鏡像 m001 10 欄、含 JSONB／INET）＋`facade/sys_operation_log.rs`（append-only `write_in_txn`＋`audit_active_model` 純映射 seam）＋`facade/sys_user.rs` 的 `impl AuditSerialize`（redact `password`）＋單一寫路徑 proof `soft_delete`。驗證 ii：純測（`audit_json` redact ＋ `audit_active_model` SQL-build，零 DB、test-first）＋bounded 实机 smoke（`#[ignore]`、3 場景：commit 寫恰好 1 筆 redacted／no-op 不寫／審計 INSERT 失敗整 txn 回滾）。**無 migration**（`sys_operation_log` 已在 m001）；**擴 entity crate +`with-json`**（非新 crate、serde_json 已在 lock、無新外部 crate）。⚠️ **operator_ip INET 寫入用 `NotSet`**（None 時略過欄、避 PG 42804 隱式轉型錯；真實 INET 值寫入 defer 第二 audit 刀）。第二 audit 軌／operator 自動抽取／讀端／其餘寫路徑／`DbErr→AppError` 皆 defer 後續刀。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-toolchain.toml`、001 落值）

**Primary Dependencies**: 既有 `entity` crate（004 建、path dep）擴 `sys_operation_log` Model ＋ sea-orm features `["with-chrono"]`→`["with-chrono","with-json"]`（JSONB `payload_*` 需 with-json；**serde_json 已在 Cargo.lock〔003/sea-orm〕、chrono 已在 lock〔004〕＝無新外部 crate 下載**）；server crate `model/audit.rs` 用 `serde_json`（003 已在 deps）。axum/tokio/sea-orm（workspace）不動。

**Storage**: PostgreSQL（`sys_operation_log` archetype B append-only 寫入＋`sys_user` soft_delete 寫；schema＝m001〔002 落地〕、`sys_operation_log` 10 欄已存在、**本刀無 migration、無 schema 變動**）。

**Testing**: `cargo test`——**test-first**（純函式：`sys_user::Model::audit_json()` redact〔password→`"<redacted>"`〕＋`audit_active_model` SQL-build〔INSERT 目標表/核心欄/operator_ip None→欄略過〕，**零 DB**）＋**bounded 实机 smoke**（`#[ignore]`、`DATABASE_URL`、`postgres+migrate`；拋棄式 user〔id 9xxxxx〕＋hard_clean 隔離；3 場景 commit/no-op/rollback 證原子）。

**Target Platform**: 004 交付 entity crate＋server `model/`（soft_delete 讀側）；本刀擴 entity（+sys_operation_log Model）＋server `model/audit.rs`＋`facade/sys_operation_log.rs`＋`facade/sys_user.rs`（+impl AuditSerialize +soft_delete），不改 stack 拓撲。

**Project Type**: backend infra（擴既有 `entity` crate ＋ server crate `model/audit` 層＋op-log facade＋首個寫路徑）

**Performance Goals**: N/A（⚠️a 效能數字屬波 1）

**Constraints**: `mutate_in_txn` 業務寫＋審計寫同一 txn（commit/rollback 原子、guard 核心）／`audit.rs` 零 `entity::`（純泛型、守 lint ③）／op-log facade append-only（僅 `write_in_txn` insert、archetype B §3.2/§I.6）／**operator_ip None→`NotSet`**（避 PG 42804）／`soft_delete` 寫 `deleted_at`+`deleted_by`（§I.6 成對）、`payload_after=None`、回 `Result<bool,DbErr>`／`AuditSerialize` redact `password`、15 欄〔排除 `current_session_id`〕／facade 回 raw `Model`/`DbErr`、不 re-export `Entity`、不碰 envelope（FR-009）／rust-api 全新寫、rev2 受控參照讀允許拷貝禁止（⚠️g／§I.5；audit/facade 不在拷貝例外清單）／無 migration／第二 audit 軌+operator 自動抽取+讀端 defer／**擴 entity crate +with-json（非新 crate ⇒ 無 mandatory prod build、但跑一次 C-V build 驗 with-json）**。

**Scale/Scope**: `model/audit.rs`（4 型＋trait＋`mutate_in_txn`）＋`entity/src/sys_operation_log.rs`（10 欄 Model）＋`facade/sys_operation_log.rs`（`audit_active_model`＋`write_in_txn`＋SQL-build 純測）＋`facade/sys_user.rs`（+`impl AuditSerialize` +`soft_delete` +`soft_delete_query` helper +redact 純測）＋3 live smoke（`#[ignore]`）＋`model/mod.rs`/`facade/mod.rs`/`entity/lib.rs` +mod ＋ `entity/Cargo.toml` +with-json。

## Constitution Check

*constitution-rev3 v1.0.0 §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威／缺 endpoint？ | **PASS（未觸）**——audit 為資料寫入基建、所有未來寫端刀的審計前提；無業務 endpoint；op-log 讀端 wire 屬後續刀 |
| 2 | 動 base-web inline？ | **PASS（未觸）**——全在 rust-api；base-web 零接觸 |
| 3 | menu 走 Casbin enforce？ | **PASS（N/A）**——無 menu／無 enforce |
| 4 | wire 對齊 §I.3 不變式？ | **PASS（未觸/wire 之下）**——audit/facade 在 handler 之下、回 raw `Model`/`DbErr`、不映射 wire；無 wire 變動 |
| 5 | 拷 rev2 source？ | **PASS（全新寫合規）**——`audit`/`facade` **不在 §I.5 拷貝例外清單**（唯 sea-orm-adapter/xdb）、屬受控參照重寫（⚠️g 讀允許拷貝禁止）✓；防回歸：rev2 op-log facade 終態的其他寫端（`update`/`create`/`reset_password`/`restore`）**未照拷**（本刀只取 `soft_delete` proof＋mutate_in_txn＋op-log sink）✓ |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——archetype B append-only（§3.2/§I.6）＋審計欄成對（`deleted_at`+`deleted_by`、§I.6）直接落實；⚠️g 承接；無拍板需改變 |
| 7 | 觸 §III ★ 軌道？ | **PASS（在授權邊界內）**——僅觸 `RUSTAPI-SOURCE-ISOLATION` 軌道（rust-api 全新寫、本檔已授權）；不動 `views/manage/**`、無 MODAL-WIRING ★ |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——**無 migration、無新表**（`sys_operation_log` 已在 m001；本刀純 Rust 層 audit/entity/facade） |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸）**——audit 為資料寫入基建、非行為島；`soft_delete` 只寫 `deleted_at`/`deleted_by`、**不**碰 `sys_user` 的 `session_policy`/`current_session_id` 狀態機（token rotation／single-session 屬波 3） |

**Gate 結論：9/9 PASS，無需 amendment、無 violation 待 justify。**

## Project Structure

### Documentation (this feature)

```text
specs/005-audit-op-log/
├── spec.md              # /speckit-specify ✅（US1 原子 P1/US2 redact P2/US3 完整+append-only P3＋12 FR＋7 SC）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 m001 10 欄／R2 rev2 011 受控參照〔含 42804 INET 坑〕／R3 deps+with-json／R4 INET 型／R5 facade 返回型+soft_delete 校正／R6 test 策略）
├── data-model.md        # Phase 1 ✅（audit 4 型＋trait＋mutate_in_txn／sys_operation_log Model／facade 簽名／排除）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── audit-contract.md             # mutate_in_txn 原子＋AuditSerialize redact＋audit_active_model SQL-build＋3 live smoke 斷言
│   └── verification-commands.md      # C-V-1~6（build／純測／with-json build／实机 smoke／殘留 grep／/health）
├── checklists/requirements.md        # 16/16 ✅
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
├── rust-api/                          # worktree（兩段式 commit）
│   ├── entity/
│   │   ├── Cargo.toml                 # sea-orm features +"with-json"
│   │   └── src/
│   │       ├── lib.rs                 # ＋pub mod sys_operation_log;
│   │       └── sys_operation_log.rs   # ★ 新 Model（10 欄 archetype B；operator_ip Option<String>、payload_* Option<Json>）
│   └── server/
│       └── src/
│           └── model/
│               ├── mod.rs             # ＋pub mod audit;
│               ├── audit.rs           # ★ 新（AuditOperation/Operator/Event/Serialize trait＋mutate_in_txn；純、零 entity::）
│               └── facade/
│                   ├── mod.rs         # ＋pub mod sys_operation_log;
│                   ├── sys_operation_log.rs  # ★ 新（audit_active_model 純映射＋write_in_txn append-only＋SQL-build 純測）
│                   └── sys_user.rs    # ＋impl AuditSerialize（redact password）＋soft_delete＋soft_delete_query＋redact 純測＋3 live smoke
└── （無 migration、無 Dockerfile 改動——非新 crate、無新 workspace member）
```

**Structure Decision**: 擴既有 `entity` crate（+`sys_operation_log` Model、+`with-json` feature；**非新 crate ⇒ CLAUDE.md §3「新 crate ⇒ prod build」紀律不觸發**，異於 004；但 verification-commands C-V 仍跑一次 build 驗 with-json 不破壞編譯）＋server crate `model/audit.rs`（純資料＋txn wrapper）＋`facade/sys_operation_log.rs`（append-only sink）＋`facade/sys_user.rs` 加寫側（`impl AuditSerialize`＋`soft_delete`）。lint ③（004 既立）守護：`audit.rs` 零 `entity::`、新 facade 路徑豁免。

## Phase 0：研究結論

見 [research.md](research.md)——R1 m001 `sys_operation_log` 10 欄逐欄 grep（INET `operator_ip`／JSONB `payload_*`／型對照）／R2 rev2 011 受控參照（`audit.rs` 89 行 mutate_in_txn＋4 型／`facade/sys_operation_log.rs` 的 `audit_active_model`〔**operator_ip None→NotSet 避 PG 42804**〕＋write_in_txn＋SQL-build 純測／`facade/sys_user.rs` 的 `soft_delete`〔`(db,id,operator:i64)->Result<bool,DbErr>`、寫 deleted_at+deleted_by、payload_after=None〕＋`impl AuditSerialize`〔redact password、15 欄排除 current_session_id〕＋3 live smoke 形；**只取讀+soft_delete proof、其餘寫端不照拷**）／R3 依賴增量（entity +with-json、serde_json 已在 lock、無新下載）／R4 INET 型（Option<String>、None→NotSet）／R5 facade 返回型＋soft_delete 簽名校正（act on actual code、非 brainstorm 猜形）／R6 test 策略（2 純測 seam＋3 live smoke、test-first）。NEEDS CLARIFICATION＝0。

## Phase 1：設計產物

- [data-model.md](data-model.md)：`audit.rs` 4 型＋`AuditSerialize` trait＋`mutate_in_txn` 簽名／`sys_operation_log` Model 逐欄形／facade 簽名（`write_in_txn`／`soft_delete`／`impl AuditSerialize`）＋排除聲明。
- [contracts/audit-contract.md](contracts/audit-contract.md)：`mutate_in_txn` 原子契約＋`audit_json` redact＋`audit_active_model` SQL-build＋3 live smoke 斷言（commit/no-op/rollback）。
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V-1~6——build（+with-json）／純測（redact+SQL-build，零 DB）／实机 smoke（postgres+migrate、拋棄式 user）／殘留 grep／/health 不退化。
- [quickstart.md](quickstart.md)：從零驗證指南。

## 實作注意（移交 tasks）

1. **順序**：deps（entity Cargo.toml +with-json／entity/lib.rs +mod）→ `sys_operation_log` Model（逐欄對 m001 grep）→ `model/audit.rs`（4 型＋trait＋mutate_in_txn、純）→ test-first（先寫 `audit_json` redact 純測＋`audit_active_model` SQL-build 純測＝red）→ `facade/sys_operation_log.rs`（audit_active_model＋write_in_txn、green SQL-build）→ `facade/sys_user.rs`（impl AuditSerialize green redact＋soft_delete＋soft_delete_query）→ `mod` 掛載 → live smoke（`#[ignore]` 3 場景）→ C-V（build／純測／实机 smoke／殘留 grep）→ **兩段式 commit（worktree 逐 task、outer pin 隨同 bump——001/002/003/004 教訓）**。
2. **⚠️ operator_ip INET / PG 42804**：`audit_active_model` 內 operator_ip `None→NotSet`（略過欄、DB 填 NULL）；本刀 operator 永遠 `ip:None`、不觸 `Some(ip)` 的 text-binding 路徑（真實 INET 值寫入 defer 第二 audit 刀、需 Expr cast 或 ipnetwork custom type）。
3. **⚠️g 全新寫紀律**：`audit`/`facade` 對 rev2 **讀允許、code 不拷**；rev2 op-log facade 終態的其他寫端（`update`/`create`/`reset_password`/`restore`/`replace_roles`）**不帶回**；只取 `mutate_in_txn`＋op-log sink＋`soft_delete` proof＋`impl AuditSerialize`。
4. **結構保證**：`audit.rs` 零 `entity::`（守 lint ③）；op-log facade append-only（僅 `write_in_txn`）；`soft_delete` 經 `mutate_in_txn`（業務寫＋審計寫同 txn）。
5. **非新 crate**：擴 entity crate（+sys_operation_log Model、+with-json）⇒ 無 Dockerfile COPY 改動、**無 mandatory prod build**（異於 004）；但 C-V 跑一次 `cargo build`/`cargo test -p server` 驗 with-json 編譯綠。
6. **push/merge 全凍結（§I.4/⚠️u）**：實作期 commit only；tasks.md 不得出現 push／merge 步驟。
7. **失敗處置**：redact 純測紅＝對 R2 校 `audit_json` 欄；SQL-build 純測紅＝對 R2 校 `audit_active_model`（operator_ip NotSet）；live rollback 測紅＝對 contract §4 校 mutate_in_txn txn 邊界；Model 漂移＝對 m001 grep 校欄（不調 contract 遷就實作）。
