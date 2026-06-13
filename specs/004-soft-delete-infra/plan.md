# Implementation Plan: soft-delete-infra（entity 存取 facade 基建＋SoftDeletable＋entity_access_lint）

**Branch**: `004-soft-delete-infra` | **Date**: 2026-06-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-soft-delete-infra/spec.md`＋brainstorm `docs/superpowers/004-soft-delete-infra.md`（刀界 A／proof set option 3／驗證 ii／承接 DESIGN §5.1 triple-guard＋⚠️o＋⚠️g）

## Summary

把 rust-api 的「entity 存取唯一管道＝facade」存取控制基建一次立起：新 `entity` crate（`sys_user`/`sys_role`/`sys_user_role` 三 Model 逐欄鏡像 m001）＋`SoftDeletable` trait（`find_active()` 過濾 `deleted_at IS NULL`、minimal）＋`model/facade/` 三 facade（user/role soft-deletable、user_role plain 硬刪 join）＋`entity_access_lint`（build-failing 守恆 test、facade 外 `entity::` 擋下＋meta-test）。facade=通用閘（lint 強制）／SoftDeletable=optional mixin（A 表）；同證 soft-deletable 與 plain 兩條 facade 路。test-first（lint＋`find_active` query-shape 純測）＋bounded 实机 smoke（`#[ignore]`、postgres+migrate、m002 seed 證過濾真生效）。**非新業務表、無 migration**（`deleted_at` 已在 m001）；**新 `entity` workspace crate** ⇒ Dockerfile COPY＋prod image build mandatory acceptance。寫路徑/`audit.rs`/getUserInfo 組裝/`DbErr→AppError` 皆 defer 後續刀。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-toolchain.toml`、001 落值）

**Primary Dependencies**: **新 `entity` crate**（path dep）＋server crate 新消費 `sea-orm`（workspace、002 已落＝`default-features=false` features `macros`/`sqlx-postgres`/`runtime-tokio-rustls`）；**無新外部 crate**（sea-orm 已在 Cargo.lock＋warm cache）。既有 axum/tokio/serde/thiserror（003）不動。

**Storage**: PostgreSQL（**唯讀 facade 存取**；schema＝m001〔002 落地〕、`deleted_at` 欄已存在、**本刀無 migration、無 schema 變動**）。

**Testing**: `cargo test`——**test-first**（純函式：`entity_access_lint` 守恆＋false-positive regression＋meta-test／`SoftDeletable::find_active()` query-shape，**零 DB**）＋**bounded 实机 smoke**（`#[ignore]`、`DATABASE_URL`、`postgres+migrate` m002 seed 證 soft-delete 過濾真生效）。

**Target Platform**: 001 交付 server crate（dev/prod stack）；本刀新增 `entity` crate＋server `model/` 層，不改 stack 拓撲。

**Project Type**: backend infra（**新 workspace crate** `entity` ＋ server crate `model/` 層）

**Performance Goals**: N/A（⚠️a 效能數字屬波 1）

**Constraints**: facade 為唯一 entity 存取閘（lint 結構強制、guard ③）／`SoftDeletable` minimal（無 restore/update）／entity Model 逐欄對齊 m001（不漂移）／facade 不 re-export `Entity`、回 raw `Model`／組裝/RI 維持 handler 層（⚠️o）／rust-api 全新寫、rev2 受控參照讀允許拷貝禁止（⚠️g／§I.5）／無 migration／寫路徑+`audit.rs` defer／**新 crate ⇒ Dockerfile COPY＋prod build mandatory**。

**Scale/Scope**: `entity` crate（3 Model＋lib.rs＋Cargo.toml）＋`model/soft_delete.rs`（trait）＋`model/facade/`（3 facade＋mod）＋`tests/entity_access_lint.rs`（lint＋regression＋meta）＋`main.rs` +mod＋server/entity Cargo.toml deps＋Dockerfile COPY ×2 行；contract test（lint＋query-shape 純測＋实机 smoke）。

## Constitution Check

*constitution-rev3 v1.0.0 §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威／缺 endpoint？ | **PASS（未觸）**——無業務 endpoint；facade/entity 為資料存取基建、所有未來 handler 的讀閘前提；getUserInfo wire 屬 Auth 島 |
| 2 | 動 base-web inline？ | **PASS（未觸）**——全在 rust-api；base-web 零接觸 |
| 3 | menu 走 Casbin enforce？ | **PASS（N/A）**——無 menu／無 enforce |
| 4 | wire 對齊 §I.3 不變式？ | **PASS（未觸/wire 之下）**——facade 在 handler 之下、回 raw `Model`、不映射 wire；無 wire 變動；getUserInfo wire 形屬 Auth 島 |
| 5 | 拷 rev2 source？ | **PASS（全新寫合規）**——`soft_delete`/`facade`/`entity_access_lint` **不在 §I.5 拷貝例外清單**（唯 sea-orm-adapter/xdb）、屬受控參照重寫（⚠️g 讀允許拷貝禁止）✓；防回歸：rev2 facade 終態的 write/audit/session **未照拷**（本刀只取讀側三 fn）✓ |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——⚠️o（application-RI／組裝維持 handler 層）直接承接（getUserInfo 組裝 defer Auth 島）；⚠️g 承接；無拍板需改變 |
| 7 | 觸 §III ★ 軌道？ | **PASS（在授權邊界內）**——僅觸 `RUSTAPI-SOURCE-ISOLATION` 軌道（rust-api 整棵樹全新寫、本檔已授權）；不動 `views/manage/**`、無 MODAL-WIRING ★ |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——**無 migration、無新表**（`deleted_at` 已在 m001；本刀純 Rust 層 entity/facade/lint） |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸）**——soft-delete 為資料存取基建、非行為島；`sys_user` 的 `session_policy`/`current_session_id` 欄存在但本刀**不**碰其狀態機（token rotation／single-session 屬波 3 Auth/Token/Session 刀） |

**Gate 結論：9/9 PASS，無需 amendment、無 violation 待 justify。**

## Project Structure

### Documentation (this feature)

```text
specs/004-soft-delete-infra/
├── spec.md              # /speckit-specify ✅（US1/2/3＋11 FR＋7 SC）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 m001 三表 grep／R2 rev2 009 受控參照／R3 facade 返回型／R4 deps／R5 新 crate prod build／R6 驗證 ii）
├── data-model.md        # Phase 1 ✅（3 entity Model＋trait＋3 facade＋lint＋排除）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── entity-access-contract.md     # trait query-shape＋facade 簽名＋lint 守恆＋实机 smoke 斷言
│   └── verification-commands.md      # C-V-1~5（build／純測／prod build mandatory／实机 smoke／殘留 grep）
├── checklists/requirements.md        # 16/16 ✅
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
├── rust-api/                          # worktree（兩段式 commit）
│   ├── Cargo.toml                     # workspace members ＋ "entity"
│   ├── entity/                        # ★ 新 crate
│   │   ├── Cargo.toml                 # sea-orm = { workspace = true }
│   │   └── src/
│   │       ├── lib.rs                 # pub mod sys_user; sys_role; sys_user_role;
│   │       ├── sys_user.rs            # DeriveEntityModel（16 欄、archetype A）
│   │       ├── sys_role.rs            # DeriveEntityModel（12 欄、archetype A）
│   │       └── sys_user_role.rs       # DeriveEntityModel（2 欄、複合 PK、硬刪）
│   └── server/
│       ├── Cargo.toml                 # ＋sea-orm（workspace）＋entity（path）
│       ├── src/
│       │   ├── main.rs                # ＋mod model;（/health 不動）
│       │   └── model/                 # ★ 新層
│       │       ├── mod.rs             # pub mod soft_delete; pub mod facade;
│       │       ├── soft_delete.rs     # SoftDeletable trait（minimal）
│       │       └── facade/
│       │           ├── mod.rs         # pub mod sys_user; sys_role; sys_user_role;
│       │           ├── sys_user.rs    # SoftDeletable＋find_active_by_name/by_id
│       │           ├── sys_role.rs    # SoftDeletable＋find_active_by_ids
│       │           └── sys_user_role.rs  # plain＋find_role_ids_by_user_id
│       └── tests/
│           └── entity_access_lint.rs  # ★ build-failing 守恆＋regression＋meta-test
└── deploy/Dockerfile.rust-api.txt     # ＋entity COPY（Manifest 段＋Source 段）
```

**Structure Decision**: 新 `entity` workspace crate（鏡像 rev2 layout、DESIGN §1.5 L4＋§5.1 triple-guard）＋server crate `model/` 層（`soft_delete.rs` trait＋`facade/` 三檔）＋`tests/entity_access_lint.rs`（build-failing 守恆）。**新 workspace crate ⇒ CLAUDE.md §3「新 crate ⇒ acceptance 必含 prod build」紀律觸發**（異於 003 非新 crate）——verification-commands C-V-3 為 mandatory prod target image build＋Dockerfile COPY 補齊（R5）。非新業務表、無 migration（待決①sys_user_role 複合 PK 沿 m001、無 surrogate id）。

## Phase 0：研究結論

見 [research.md](research.md)——R1 m001 三表逐欄 grep（sys_user 16／sys_role 12／sys_user_role 2 複合 PK；型對照）／R2 rev2 009 受控參照（SoftDeletable trait 17 行／facade 讀側模式／query-shape 測／live_tests `#[ignore]` 形／lint 兩段掃描；**rev2 facade 終態大、只取讀側**）／R3 facade 返回型（raw Model、單表、兩步非 join）／R4 依賴增量（server +sea-orm/entity、無新下載）／R5 新 crate prod build 紀律／R6 contract test 策略（ii、test-first）。NEEDS CLARIFICATION＝0。

## Phase 1：設計產物

- [data-model.md](data-model.md)：3 entity Model 逐欄形（m001 鏡像）＋`SoftDeletable` trait＋3 facade 簽名/返回型＋lint＋排除聲明。
- [contracts/entity-access-contract.md](contracts/entity-access-contract.md)：trait query-shape（`"deleted_at" IS NULL`）＋facade fn 契約＋lint 守恆（擋/放/meta）＋实机 smoke 斷言。
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V-1~5——build／純測（lint+query-shape，零 DB）／**prod target image build（新 crate mandatory）**／bounded 实机 smoke（postgres+migrate）／殘留 grep。
- [quickstart.md](quickstart.md)：從零驗證指南。

## 實作注意（移交 tasks）

1. **順序**：deps（workspace members +entity／server +sea-orm +entity／entity Cargo.toml）→ entity 3 Model（逐欄對 m001 grep）→ `SoftDeletable` trait → test-first（先寫 lint＋`find_active` query-shape＝red）→ facade ×3（green）→ `entity_access_lint` 實作（green）→ `main.rs` +mod → **Dockerfile COPY ×2 行** → C-V（build／純測／prod build／实机 smoke）→ **兩段式 commit（worktree 逐 task、outer pin 隨同 bump——001/002/003 教訓**）。
2. **⚠️g 全新寫紀律**：trait/facade/lint 對 rev2 **讀允許、code 不拷**；rev2 facade 終態的 write/audit/session **不帶回**（防回歸條款）；只取讀側三 fn。
3. **結構保證**：`entity_access_lint` build-failing＋meta-test（證守恆會擋）；facade 不 re-export `Entity`；sys_user_role 複合 PK 兩欄 `auto_increment=false`（坑）。
4. **新 crate prod build mandatory**：Dockerfile COPY 補齊＋C-V-3 prod image build 為 acceptance 門（dev bind-mount 遮 COPY 缺口、必 prod build 暴露——R5）。
5. **push/merge 全凍結（§I.4/⚠️u）**：實作期 commit only；tasks.md 不得出現 push／merge 步驟。
6. **失敗處置**：query-shape 紅＝對 R2 rev2 校 `find_active` 形；lint 紅＝對 contract §3 校掃描/豁免；entity Model 漂移＝對 m001 grep 校欄（不調 contract 遷就實作）。
