# Research: 004-soft-delete-infra（Phase 0）

**Date**: 2026-06-14 ｜ **Input**: spec.md＋brainstorm `docs/superpowers/004-soft-delete-infra.md`＋plan 期實 grep（R1 m001 schema／R2 rev2 009 源碼，受控參照 ⚠️g）

> CLAUDE.md §3 Phase 0 三 grep 紀律：① facade 真實返回型（R3）② wire 3 端對齊（N/A——facade 在 wire 之下、無新 endpoint；getUserInfo wire 屬 Auth 島）③ data-model file:line 對照（R1/R2 已執行）。NEEDS CLARIFICATION＝0。

## R1 · m001 schema 三表逐欄 grep（entity Model 對齊權威；不信 brainstorm 命名假設、act on m001 actual）

座標：`rust-api/migration/src/m001_rev2_schema.rs`。sea-orm `ColumnDef` → sea-orm Model 型對照（`big_integer`→`i64`／`small_integer`→`i16`／`string`/`string_len(n)`→`String`／`timestamp_with_time_zone`→`DateTimeWithTimeZone`／`null`→`Option<_>`）。

- **`sys_user`**（enum :23-41／create :208-256；**16 欄**，archetype A）：
  `id`(PK i64 auto)／`user_name` String／`password` String／`deleted_at` Option\<DateTimeWithTimeZone\>／`nick_name` Option\<String\>／`user_gender` Option\<i16\>／`user_phone` Option\<String\>／`user_email` Option\<String\>／`status` Option\<i16\>／`created_at` DateTimeWithTimeZone(NN default current)／`created_by` Option\<i64\>／`updated_by` Option\<i64\>／`deleted_by` Option\<i64\>／`updated_at` Option\<DateTimeWithTimeZone\>／`current_session_id` Option\<String\>(len36)／`session_policy` String(len20, NN default 'inherit')。
- **`sys_role`**（enum :44-58／create :261-298；**12 欄**，archetype A）：
  `id`(PK i64 auto)／`code` String／`name` String／`deleted_at` Option\<DateTimeWithTimeZone\>／`role_desc` Option\<String\>／`status` Option\<i16\>／`created_at` DateTimeWithTimeZone(NN default)／`created_by` Option\<i64\>／`updated_by` Option\<i64\>／`deleted_by` Option\<i64\>／`updated_at` Option\<DateTimeWithTimeZone\>／`home` Option\<String\>。
- **`sys_user_role`**（enum :109-113／create :414-428；**2 欄、複合 PK `(user_id, role_id)`**，archetype C 硬刪、**無 `deleted_at`**、零審計、無 FK〔m003 delta 才加〕）：
  `user_id` i64(PK 之一)／`role_id` i64(PK 之一)。
- **Decision**：3 entity Model 逐欄鏡像上表。`sys_user`/`sys_role` 的 `deleted_at` 為 soft-delete 標記欄。`sys_user_role` 用 **複合 PK**——sea-orm `DeriveEntityModel` 兩欄皆 `#[sea_orm(primary_key)]`＋`auto_increment = false`（**坑**：預設 auto_increment=true 對複合 PK 錯）。**Rationale**：Model 與 DB schema 漂移＝執行期解析失敗或型別謊言（FR-008）。

## R2 · rev2 009 受控參照 grep（讀允許、拷貝禁止——⚠️g／§I.5；soft-delete/facade/lint 不在拷貝例外清單）

座標：`../fork260509-rev2/rust-api/server/src/`。

- **`SoftDeletable` trait**（`model/soft_delete.rs:9-17`，全檔 17 行）：
  ```rust
  use sea_orm::{entity::prelude::*, Select};
  pub trait SoftDeletable: EntityTrait {
      fn deleted_at_column() -> Self::Column;
      fn find_active() -> Select<Self> { Self::find().filter(Self::deleted_at_column().is_null()) }
  }
  ```
  minimal（**無** restore/update）；rev3 004 逐形重寫。
- **facade 模式**（`model/facade/sys_user.rs`）：`impl SoftDeletable for Entity { deleted_at_column → Column::DeletedAt }`(:44-48)；`find_active()` 委派 trait default(:51-53)；`find_active_by_name`(:56-64)／`find_active_by_id`(:67-72) 回 `Result<Option<Model>, DbErr>`；**import `entity::sys_user::{Column, Entity, Model}` 但不 re-export `Entity`**、對外只暴露 `Model`／`find_active*`。
  - ⚠️ **rev2 此檔終態極大**（accreted rev2 016/017/028/029 的 create/update/soft_delete/session/audit）——rev3 004 **只取讀側三 fn**（`find_active`＋`by_name`＋`by_id`）；寫路徑/audit/session 屬 rev3 後續刀（audit/Auth 島），本刀不帶。
- **query-shape 純測**（`model/facade/sys_user.rs:467-474`，rev2 同形）：
  `find_active().build(DbBackend::Postgres).to_string()` 斷言 `contains("\"deleted_at\" IS NULL")`——**無 DB、test-first 可行**。rev3 004 沿此形。
- **bounded 实机 smoke 模式**（`model/facade/sys_user.rs:645+` `mod live_tests`）：`#[tokio::test] #[ignore]`＋`DATABASE_URL` env connect；`cargo test -- --ignored` 起 DB 才跑、常規 `cargo test` 不含。rev3 004 沿此形。
- **`entity_access_lint`**（`server/tests/entity_access_lint.rs`，rev2）：build-failing cargo test；兩段掃描（strip 註解/字串/char-literal → 找 `server/src/model/facade/` 外的 root-level `entity::`；`#[test] fn no_raw_entity_outside_facade()` `panic!`+file:line）；~15 個 false-positive regression（`identity`/`my_entity`/註解/字串/lifetime/char-literal）。rev3 004 全新重寫＋regression＋**meta-test**（植入違規樣本斷言會 fail）。
- **Decision**：trait／facade 讀側／query-shape 測／live_tests 形／lint 兩段掃描——**逐形重寫**（非拷貝）；13 碼...（N/A，本刀無碼）。**Rationale**：⚠️g 受控參照；rev2 經驗證的形狀降風險，但 code 全新寫（§I.5）。

## R3 · facade 返回型對齊（raw `Model`、單表、無 join）

- `sys_user` facade：`find_active_by_name(&DatabaseConnection, &str) -> Result<Option<Model>, DbErr>`／`find_active_by_id(&DatabaseConnection, i64) -> Result<Option<Model>, DbErr>`——回 raw `Model`（非過濾/DTO）。
- `sys_role` facade：`find_active_by_ids(&DatabaseConnection, &[i64]) -> Result<Vec<Model>, DbErr>`（`find_active().filter(Column::Id.is_in(ids))`；回含 `code` 的 active 角色 `Model`）。
- `sys_user_role` facade（**plain、無 SoftDeletable**）：`find_role_ids_by_user_id(&DatabaseConnection, i64) -> Result<Vec<i64>, DbErr>`（單表讀 `role_id`；硬刪無 `deleted_at` 過濾）。
- **Decision**：三 facade **皆單表**；getUserInfo 的 `user → role_ids → roles → codes` **組裝**＝Auth 島 handler（⚠️o handler 層、非 facade）。**rev2 用單一 join fn `roles_for_user`**（user_role⋈role 回 codes），**rev3 004 改兩步單表 facade ＋ handler 組裝**——facade-per-table 更純、組裝歸 handler（⚠️o）。soft-deleted 角色由 `sys_role::find_active_by_ids` 的 `find_active` 過濾排除（不洩漏已刪角色）。**Alternatives**：①rev2 join fn（被否：跨表 facade、組裝下沉違 ⚠️o）。

## R4 · 依賴增量

- **server crate** 加 `sea-orm = { workspace = true }`＋`entity = { path = "../entity" }`。**entity crate** 加 `sea-orm = { workspace = true }`。
- workspace `sea-orm`（002 落地）＝`default-features = false` features `["macros","sqlx-postgres","runtime-tokio-rustls"]`——facade 用 `EntityTrait`/`Select`/`ColumnTrait`/`QueryFilter`/`DatabaseConnection`/`DbErr`/`entity::prelude::*` 皆在內。**無新 crate 下載**（sea-orm 已隨 migration/sea-orm-adapter 在 lock＋warm cache 編譯過）。
- **義務**：`cargo build` 綠＝server 連結 sea-orm（binary 變大、但 `main.rs` 不連 DB、facade 不被 `main` 呼叫＝infra ahead of consumer）；確認不引入非預期重依賴。
- **dev-dependencies**：query-shape 測用 `sea_orm::{DbBackend, QueryTrait}`（runtime dep 已含）；live smoke 用 `sea_orm::Database::connect`（已含）＋`tokio::test`（server tokio 已含 macros）。無額外 dev-dep。

## R5 · 新 workspace crate prod build 紀律（mandatory）

- 新 `entity` crate ⇒ `deploy/Dockerfile.rust-api.txt` builder 段**必補 COPY**：Manifest 段 `COPY rust-api/entity/Cargo.toml ./entity/`＋Source 段 `COPY rust-api/entity/src ./entity/src`（對齊既有 server/migration/sea-orm-adapter 三行形；Dockerfile :30-39）。
- **acceptance 必含 prod target image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`）：dev bind-mount 整個 `rust-api/` 會遮 builder COPY 缺口、缺行逃過 dev 驗、拖到部署才爆（CLAUDE.md §3 紀律、Dockerfile :10-15 警示；rev2/002 sea-orm-adapter 為先例）。

## R6 · contract test 策略（驗證 ii、test-first）

- **純 cargo test（零 DB）**：① `entity_access_lint`＋false-positive regression＋meta-test（植入違規斷言 fail）② `SoftDeletable::find_active()` query-shape（`.build(DbBackend::Postgres).to_string()` 含 `"deleted_at" IS NULL`、render 不執行）。
- **bounded 实机 smoke（`#[ignore]`、`DATABASE_URL`、`postgres+migrate` m002 seed）**：`find_active_by_name("Super")` 命中／stamp `deleted_at` 後 `find_active_by_id` 排除／`find_role_ids_by_user_id(1)` 非空（Super→R_SUPER）／`find_active_by_ids([role_id])` 得 R_SUPER（含 code）。`cargo test -- --ignored` 起 DB 才跑。
- **Decision**：test-first（lint＋query-shape 先紅後綠）；DB 端只一條有界 smoke 證「過濾真生效」。**Rationale**：純函式驗收為主（守恆 lint＋query-shape 是 compile/render 可測）；facade DB 行為 compile 證不了「過濾真生效」、用最小 实机 釘死、其餘留消費刀。NEEDS CLARIFICATION＝0。

## 移交 tasks 期紀律

- 寫路徑（`soft_delete`/`update`）＋`model/audit.rs`（`mutate_in_txn`）→ audit 刀（首個寫路徑消費者）。
- getUserInfo 組裝＋Model→DTO＋`User→User01` alias＋`DbErr→AppError` From → Auth 島刀（⚠️o；§3.6 已登）。
- 其餘 entity/facade（menu/settings/token/log×3/casbin）→ 各自消費刀。
