# Implementation Plan: soft-delete 基建（SoftDeletable＋facade 唯一管道＋entity_access_lint）

**Branch**: `004-soft-delete-infra` | **Date**: 2026-06-16 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/004-soft-delete-infra.md`（D1 全 11 entity 一次建齊／D2 B1 純 trait+lint+entity 零業務 facade／D3 sea_orm 在此落地／D4 entity_access_lint 新建）

## Summary

L2 **entity 層**（新 workspace crate `entity`、11 entity 機械反射 002 凍結 schema）＋L4 **soft-delete 面地基**（`SoftDeletable` trait〔`deleted_at_column`＋`find_active`〕、impl 3 個 partial-uniq soft-delete entity）＋**facade 唯一管道守恆**（`entity_access_lint` build-failing cargo test、`model/facade/` 豁免、scan fn 自測可證有效）。本刀**只建地基/護欄**：零業務 facade 方法、零 endpoint/wire、零 migration（schema 已凍於 002）。003 的 R7 延後之 `sea-orm` 於本刀（首個 DB 層切片）落地。**新 workspace crate ⇒ acceptance 必含 prod target build**。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-toolchain pin）

**Primary Dependencies**: 新增 `entity` crate（`sea-orm` features `macros`＋`with-chrono`〔timestamptz〕＋`with-json`〔jsonb〕＋`with-ipnetwork`〔INET〕）；`server` `[dependencies]` 加 `sea-orm = { workspace = true }`＋`entity = { path = "../entity" }`；既有 axum 0.7.9／tokio／tracing。**不動 sea-orm-adapter**（§I.5 例外、已隨 002 vendored）。

**Storage**: PostgreSQL（既有 dev stack、002 schema＋seed）。**本刀無 migration、無建表、無 schema 變更**；live smoke 自連 DATABASE_URL（main.rs 不接 runtime DB）。

**Testing**: rust in-crate `#[cfg(test)]`（lint scan fn 自測、純函式無 DB → 一般 `cargo test`）＋in-crate `#[ignore]` live（`find_active`、DATABASE_URL＋`--test-threads=1`）＋`server/tests/entity_access_lint.rs`（build-failing、讀檔不 `use server::`）＋prod target image build。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。

**Target Platform**: 001 交付 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內）。

**Project Type**: backend（rust-api workspace）——L2 entity 層＋L4 soft-delete/facade 基建。

**Performance Goals**: N/A（base query／序列化層、無 endpoint SLA）。

**Constraints**: RUSTAPI-SOURCE-ISOLATION（entity 全新寫、§I.5）；**無 migration**（schema 002 凍）；**零業務 facade/endpoint**（D2 B1）；entity 一次到位最終型、永不 retrofit（D1）；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: `entity` crate 11 模組＋`server/src/model/{soft_delete.rs,facade/×3 impl,mod.rs}`＋`server/tests/entity_access_lint.rs`＋`deploy/Dockerfile.rust-api.txt` +2 COPY；deps＝server +sea-orm/+entity、entity +sea-orm(with-chrono/json/ipnetwork)。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 為權威？rust-api 缺對應 endpoint？ | **PASS（未觸）**——本刀無 endpoint、無 base-web 改動；建 base-web wire 所依賴的 L2 entity／L4 facade 地基，不縮減設計範圍 |
| 2 | 動 base-web inline？ | **PASS（未觸）**——零 base-web 改動 |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（未觸）**——無 menu／route |
| 4 | wire 對齊 §I.3 typings 權威序與不變式？ | **PASS（未觸）**——本刀無 wire／endpoint／序列化出口；entity 為內部 L2（DB i64）；§I.3 id 序列化轉換在 rust-api 序列化邊界、屬消費端業務刀 |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——entity 全新寫（RUSTAPI-SOURCE-ISOLATION、§I.5）；sea-orm-adapter（§I.5 例外、已 vendored 於 002）不再拷貝/不動；防回歸條款：無帶回已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——無拍板需改；soft-delete／facade／lint 為 DESIGN §5.1 既定基建 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸 ★）**——rust-api 側走 RUSTAPI-SOURCE-ISOLATION（§III.1 預設可動、非 ★）；無 base-web ★ 軌道（MODAL-WIRING／I18N-WIRING） |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——本刀無 migration、不建表（schema 002 已建；FR-008／SC-005）；§I.6「建表即帶審計欄」N/A（無建表）；entity 反射既有 archetype（A/B/C/D） |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸行為）**——entity 層含 sys_token／casbin_rule entity（純結構反射），**無行為邏輯**（token rotation／policy governance／single-session 狀態機接線皆不動）；invariants 不動 |

**Gate 結論：9/9 PASS；無 violation 待 justify、Complexity Tracking 不適用。**

## Project Structure

### Documentation (this feature)

```text
specs/004-soft-delete-infra/
├── spec.md              # /speckit-specify ✅（16/16 checklist、NEEDS CLARIFICATION=0）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R8；INET→IpNetwork 決議；三-grep 多 N/A）
├── data-model.md        # Phase 1 ✅（11 entity 反射 m001＋型對映＋SoftDeletable＋facade＋lint）
├── quickstart.md        # Phase 1 ✅（4 步驗證）
├── contracts/
│   ├── verification-commands.md      # C-V-0~3（build／lint＋自測／find_active live／prod build）
│   └── soft-delete-lint-contract.md  # SoftDeletable＋entity_access_lint＋entity 層 不變式
└── checklists/requirements.md        # 16/16 ✅
```

### Source Code (repository root)

```text
rust-api/
├── Cargo.toml                  # [workspace] members +"entity"（sea-orm workspace dep 已在）
├── entity/                     # ★ 新 workspace crate（lib；L2 DATA）
│   ├── Cargo.toml              # sea-orm: macros + with-chrono + with-json + with-ipnetwork
│   └── src/
│       ├── lib.rs              # pub mod 各 entity
│       └── *.rs                # 11 entity（sys_user/sys_role/sys_menu/system_settings/sys_user_role/
│                               #   sys_token/sys_operation_log/sys_access_log/sys_login_attempt/
│                               #   casbin_rule/sys_casbin_policy_archive）；欄權威＝m001
├── server/
│   ├── Cargo.toml              # +sea-orm(workspace) +entity(path)
│   └── src/
│       ├── main.rs             # +mod model;（router 不變、無新 endpoint）
│       └── model/
│           ├── mod.rs          # pub mod soft_delete; pub mod facade;
│           ├── soft_delete.rs  # SoftDeletable trait（純 sea_orm、無 entity::、lint-clean）
│           └── facade/         # SoftDeletable impl ×3（sys_user/sys_role/sys_menu；lint 豁免路徑）
│   └── tests/
│       └── entity_access_lint.rs   # build-failing lint + scan fn 自測（讀檔、不 use server::）
└── deploy/Dockerfile.rust-api.txt  # Manifest 段 +COPY entity/Cargo.toml；Source 段 +COPY entity/src
```

**Structure Decision**：backend（rust-api workspace）。新增 L2 `entity` crate（11 模組機械反射 m001）＋server L4 `model/`（`soft_delete.rs` trait＋`facade/` 3 impl）＋`server/tests/` lint。**無 base-web／frontend 改動**。tests：lint scan 自測（純函式 `cargo test`）＋find_active live（in-crate `#[ignore]`、bin-only 約束）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks）

1. **順序**：entity crate（Cargo.toml +features → 11 entity 模組、欄對 m001）→ server deps（+sea-orm/+entity）→ `model/soft_delete.rs`（trait）→ `model/facade/` 3 impl → `main.rs` +mod model → `entity_access_lint.rs`（lint＋自測）→ prod Dockerfile +2 COPY → C-V（build／lint／live／prod build）→ **兩段式 commit**（rust-api worktree → outer pin、逐單元不延後）。
2. **型對映（R2）**：tstz→`DateTimeWithTimeZone`（with-chrono）／jsonb→`Json`（with-json）／INET→`IpNetwork`（with-ipnetwork）；`sys_menu.order` 加 `#[sea_orm(column_name="order")]`；nullability 逐欄對 m001。**with-ipnetwork build 須驗**（撞 1.86 MSRV／lock churn 則退 String+cast、登 follow-up）。
3. **SoftDeletable（R3）**：trait 在 `soft_delete.rs`（無 entity::）；impl 在 `facade/`（有 entity::、豁免）；僅 sys_user/sys_role/sys_menu；system_settings 不 impl。
4. **lint（R4）**：兩階段掃描、path-root entity::、facade/ 豁免、不誤殺 sea_orm::entity::／不禁 bare Model；scan fn 自測雙證（FR-006）；server bin-only → test 只讀檔。
5. **live smoke（R5）**：in-crate `#[ignore]`＋env-gate＋txn-rollback（sys_user id=1）＋`--test-threads=1`；容器內帶 DATABASE_URL。
6. **prod build（R7）**：新 crate 必補 Dockerfile Manifest＋Source COPY、acceptance 跑 prod build（防 COPY 缺口）。
7. **無 migration（R6）／push 凍結**：本刀無 migration；實作期 commit only、tasks.md 不得出現 push／merge。
