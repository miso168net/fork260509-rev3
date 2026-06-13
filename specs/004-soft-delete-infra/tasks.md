# Tasks: soft-delete-infra（entity 存取 facade 基建＋SoftDeletable＋entity_access_lint）

**Input**: Design documents from `/specs/004-soft-delete-infra/`

**Prerequisites**: plan.md ✅、spec.md ✅、research.md（R1~R6）✅、data-model.md ✅、contracts/（entity-access-contract＋verification-commands）✅、quickstart.md ✅

**Tests**: 本 feature **test-first TDD**（plan Testing 明示——純函式：`entity_access_lint` 守恆＋false-positive regression＋meta-test／`SoftDeletable::find_active()` query-shape，**零 DB**；inline `#[cfg(test)]` 於 facade／tests）＋**bounded 实机 smoke**（`#[ignore]`、postgres+migrate、m002 seed 證過濾真生效）。同 003、與 002「靠實機」混合：純函式 red→green，DB 行為一條有界 smoke。

**Organization**: 依 user story 分 phase。**build 序＝Setup(entity+trait)→US1(lint)→US2(SoftDeletable+query-shape)→US3(facade fn+smoke)→Polish**——本刀 build 序與 spec 優先序一致（US1 P1 lint 先建＝後續 facade 即受守恆保護）。**兩段式 commit 紀律（001/002/003 教訓）**：worktree task 完成即 worktree commit＋outer pin 隨同 bump（不延後收口）。**§I.4／⚠️u：全程不 push 不 merge**。**⚠️g：trait/facade/lint 對前代 source 讀允許、code 全新寫**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（依賴＋entity crate＋model 掛載——blocking 全部 US）

- [ ] T001 [P] 依賴增量：`rust-api/Cargo.toml` workspace members 加 `"entity"`；`rust-api/server/Cargo.toml` 加 `sea-orm = { workspace = true }`＋`entity = { path = "../entity" }`；新建 `rust-api/entity/Cargo.toml`（`[package] name="entity"`＋`sea-orm = { workspace = true }`）。sea-orm 已在 lock〔002〕、無新下載。
- [ ] T002 新 `entity` crate Models：`rust-api/entity/src/lib.rs`（`pub mod sys_user; pub mod sys_role; pub mod sys_user_role;`）＋三檔 `DeriveEntityModel`——`sys_user.rs`（16 欄）／`sys_role.rs`（12 欄）／`sys_user_role.rs`（2 欄、**複合 PK 兩欄皆 `#[sea_orm(primary_key, auto_increment = false)]`**、無 deleted_at）；**逐欄對 m001 grep（research R1／data-model §2、型對照）、不信假設**；三 Model 皆空 `Relation` enum（不展開 FK）。
- [ ] T003 server model 層掛載：`rust-api/server/src/main.rs` 加 `mod model;`（`/health` 不動）＋`model/mod.rs`（`pub mod soft_delete; pub mod facade;`）＋`model/soft_delete.rs`（`SoftDeletable` trait minimal：`deleted_at_column()`＋`find_active()` default＝`Self::find().filter(deleted_at_column().is_null())`；全新寫⚠️g、對 R2 rev2 17 行參照）＋`model/facade/mod.rs`（`pub mod sys_user; pub mod sys_role; pub mod sys_user_role;`）＋三空 facade 檔（stub，後續 task 填）。
- [ ] T004 建置驗（C-V-1）：容器 `cargo build --bins`（host 無 cargo、rust:1.86、warm cargo cache、卷 cv004-target、`--offline`）；`grep '^members' rust-api/Cargo.toml` 含 entity、`grep -c 'name = "sea-orm"' Cargo.lock ≥1`；綠＝entity+server 編譯、sea-orm 連結。worktree commit＋outer pin bump。

**Checkpoint**: entity crate 入 members、3 Model 對齊 m001、SoftDeletable trait 掛載、server 連結 sea-orm、`/health` 不動、build 綠。

## Phase 2: Foundational

**無獨立 foundational 項**——`SoftDeletable` trait（US2 機制骨幹）＋entity Models 已隨 Setup（T002/T003）掛載；Setup 已涵蓋全部前置。

## Phase 3: US1 — facade 唯一閘＋守恆 lint（P1）🎯 MVP

**Goal**: entity 存取只能經 facade、`entity_access_lint` 結構強制（guard ③）
**Independent Test**: lint 對 facade 外植入的 `entity::` 樣本 fail（meta-test）、facade 內 pass、false-positive（`identity`/`my_entity`/註解/字串/char）0 誤報

- [ ] T005 [US1] `entity_access_lint`（全新寫⚠️g、對 R2 rev2 兩段掃描參照）：`rust-api/server/tests/entity_access_lint.rs`——build-failing cargo test：掃 `CARGO_MANIFEST_DIR/src/**.rs`、strip 註解/字串/char-literal → 找 `src/model/facade/` 以外的 **root-level** `entity::`（`use entity::*`／`entity::sys_*::Entity`）→ `panic!`＋file:line；豁免 facade path-prefix＋非 root 的 `sea_orm::entity::*`。含 **meta-test**（餵含 facade 外 `entity::` 的樣本字串給 scan fn、斷言 ≥1 violation）＋false-positive regression（`identity`/`my_entity`／`// entity::x`／`"entity::x"`／char-literal）。容器 `cargo test -p server`（lint＋meta＋regression 全綠；此時 facade 空、無真違規）；worktree commit＋pin bump。

**Checkpoint**: US1 全綠＝守恆 lint 鎖定（後續 facade 即受保護；SC-001 達成）。

## Phase 4: US2 — soft-deleted 預設不可見（P2；依賴 SoftDeletable trait〔T003〕）

**Goal**: `SoftDeletable::find_active()` 過濾 `deleted_at IS NULL`（guard ①）
**Independent Test**: `find_active()` query-shape SQL 含 `"deleted_at" IS NULL`（純 render、無 DB）

- [ ] T006 [US2] test-first：`rust-api/server/src/model/facade/sys_user.rs`＋`sys_role.rs` 的 `#[cfg(test)]` 寫 query-shape 測（red；`<Entity as SoftDeletable>::find_active().build(DbBackend::Postgres).to_string()` 斷言含 `"deleted_at" IS NULL`——對 contracts/entity-access-contract.md §1；red 因 `impl SoftDeletable for Entity` 未實作）。
- [ ] T007 [US2] 實作：`facade/sys_user.rs`＋`facade/sys_role.rs` 加 `use entity::sys_*::{Column, Entity}`＋`use crate::model::soft_delete::SoftDeletable`＋`impl SoftDeletable for Entity { deleted_at_column() -> Column { Column::DeletedAt } }`＋`pub fn find_active() -> Select<Entity>`（委派 trait default）（green T006；**不 re-export Entity**）；容器 `cargo test -p server` 綠（query-shape＋既有 lint/meta 全綠）；worktree commit＋pin bump。

**Checkpoint**: US2 全綠＝soft-delete 過濾形鎖定（SC-002 達成）。

## Phase 5: US3 — getUserInfo 讀叢集 facade（P3；依賴 US2 SoftDeletable impl）

**Goal**: 三 facade 讀閘（user/role soft-deletable、user_role plain）＋实机證讀鏈
**Independent Test**: 实机 smoke——3 表讀鏈對 m002 seed 命中＋soft-delete 排除 stamped 列

- [ ] T008 [US3] facade 讀 fn：`facade/sys_user.rs` 加 `find_active_by_name(db,&str)->Result<Option<Model>,DbErr>`＋`find_active_by_id(db,i64)->Result<Option<Model>,DbErr>`；`facade/sys_role.rs` 加 `find_active_by_ids(db,&[i64])->Result<Vec<Model>,DbErr>`（`find_active().filter(Column::Id.is_in(ids))`）；`facade/sys_user_role.rs`（**plain、無 SoftDeletable**）加 `find_role_ids_by_user_id(db,i64)->Result<Vec<i64>,DbErr>`（`Entity::find().filter(Column::UserId.eq(uid))` 取 role_id）——對 contracts §2／data-model §4、回 raw `Model`、不 re-export Entity。容器 `cargo build -p server` 綠（facade 編譯、`entity_access_lint` 仍綠＝entity:: 全在 facade/ 內）；worktree commit＋pin bump。
- [ ] T009 [US3] test-first 实机 smoke（C-V-4）：`facade` 或 `server/tests` 的 `#[cfg(test)] mod live_tests`、`#[tokio::test] #[ignore]`、`DATABASE_URL` connect（對 contracts §4／R2 rev2 live_tests 形）——`find_active_by_name("Super")` 命中／對該列 stamp `deleted_at=now()` 後 `find_active_by_id` 回 None（過濾真生效）／`find_role_ids_by_user_id(super_id)` 非空／`find_active_by_ids([r_super_id])` 得 `code=="R_SUPER"`；**teardown 還原 seed**。起 `docker compose ... up -d --wait postgres migrate`、`cargo test -p server -- --ignored --test-threads=1` 綠；**純 `cargo test` 不含**（`#[ignore]`）。worktree commit＋pin bump。

**Checkpoint**: US3 全綠＝讀叢集 facade 就位＋soft-delete 实机證（SC-003 達成）。

## Phase 6: Polish & Cross-Cutting

- [ ] T010 C-V-3 prod target image build（**新 entity crate ⇒ mandatory**、CLAUDE.md §3／R5）：`deploy/Dockerfile.rust-api.txt` builder 段補 entity COPY——Manifest 段 `COPY rust-api/entity/Cargo.toml ./entity/`＋Source 段 `COPY rust-api/entity/src ./entity/src`（對齊既有 server/migration/sea-orm-adapter 三行）；`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（multi-stage release 不退化；缺 COPY 行只在此暴露——dev bind-mount 遮）。worktree commit（Dockerfile 屬 deploy/、外層檔；entity COPY 在 worktree Dockerfile？**注意**：Dockerfile.rust-api.txt 在 `deploy/`＝**外層 repo 檔、非 worktree**——此 task 改外層、單段 commit、無 pin bump）。
- [ ] T011 C-V-5 殘留 grep（部署層零 rev2／rust-api 新寫零 rev2 token）：`grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/` 零命中＋`grep -rinE "rev2" rust-api/entity/src/ rust-api/server/src/model/ rust-api/server/tests/entity_access_lint.rs` 零命中（用「前代」描述）＋quickstart.md 流程逐步對照＋拋棄式卷清理（`docker volume rm cv004-target`、停 smoke stack）。
- [ ] T012 收口驗證（**commit only——push／merge 凍結至 finishing，§I.4／⚠️u**）：worktree 全 task commit 齊＋outer pin==worktree HEAD（隨 task bump 紀律回顧）＋specs/004 外層檔全收＋Dockerfile.rust-api.txt 外層 commit 落地；`git submodule status` 行首空格。

## Dependencies

```
Phase 1 (T001→T002→T003→T004) ──→ US1 (T005) ──→ US2 (T006→T007) ──→ US3 (T008→T009) ──→ Polish (T010→T011→T012)
build 依賴：entity Models〔T002〕＋SoftDeletable trait〔T003〕＝foundational；lint〔US1/T005〕獨立、先建以守護後續 facade；US2 SoftDeletable impl〔T007〕← US3 facade 讀 fn〔T008 用 find_active〕；US3 实机 smoke〔T009〕需 postgres+migrate。
build 序＝spec 優先序（US1→US2→US3）——本刀無倒序（異於 003）。
test-first：US1 lint（含 meta red→green）／US2 query-shape（T006 red→T007 green）；US3 实机 smoke（T009、#[ignore]）。
```

## Parallel Execution Examples

- Phase 1：T001 可獨立（deps 編輯）；T002→T003→T004 序列（Model→掛載→build）。
- US1 lint（T005）與 US2/US3 facade 檔不同檔（`tests/entity_access_lint.rs` vs `model/facade/`）、file-wise 可並行，但**序列先建 lint** 以守護後續 facade（單 implementer、build 依賴序列）。
- story 內 test→impl 嚴格序列（red→green）；story 間因型別/守護依賴序列、**無跨 story 並行**。

## Implementation Strategy

**MVP first**：Phase 1→3（Setup＋US1 守恆 lint）＝「entity 存取唯一閘由結構強制」的最小可用價值（lint 機制就位、meta-test 證守恆生效）；US2（soft-delete 過濾）＋US3（讀叢集 facade＋实机）緊接、Polish 完成全刀。每 phase checkpoint 過了才前進；test-first 嚴格 red→green；**新 entity crate ⇒ T010 prod image build 為 mandatory acceptance**（dev bind-mount 遮 Dockerfile COPY 缺口、必 prod build 暴露）。任一 `cargo test` fail＝對 contracts/research grep 座標校形、不調測試遷就實作。
