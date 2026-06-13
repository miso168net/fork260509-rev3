# Data Model — 004-soft-delete-infra

> **權威序聲明**：①m001 schema（`rust-api/migration/src/m001_rev2_schema.rs`、002 落地）＝entity Model 對齊**唯一權威**（欄名/型/可空/PK）＞②rev2 009 參考形（`../fork260509-rev2/rust-api/server/src/model/`，受控參照讀允許拷貝禁止 ⚠️g）＞③本檔。implementer 寫 entity Model 時逐項對照 R1 grep 座標，不得只抄本檔。
> **漂移紀律**：Model 與 m001 不符 → 以 m001 grep 為準、回頭最小 patch 本檔（FR-008）。

## 1. 型別總覽

| 型別 | 檔 | 職責 | 來源/座標 |
|---|---|---|---|
| `sys_user::Model` 等 | `entity/src/sys_user.rs` | sea-orm `DeriveEntityModel`，archetype A | m001 :23-41/:208-256 |
| `sys_role::Model` 等 | `entity/src/sys_role.rs` | sea-orm `DeriveEntityModel`，archetype A | m001 :44-58/:261-298 |
| `sys_user_role::Model` 等 | `entity/src/sys_user_role.rs` | sea-orm `DeriveEntityModel`，archetype C 複合 PK | m001 :109-113/:414-428 |
| `SoftDeletable` trait | `server/src/model/soft_delete.rs` | active 基底查詢 mixin（A 表 impl） | rev2 soft_delete.rs（重寫） |
| `sys_user`/`sys_role`/`sys_user_role` facade | `server/src/model/facade/*.rs` | entity 存取唯一閘 | rev2 facade（讀側重寫） |
| `entity_access_lint` | `server/tests/entity_access_lint.rs` | build-failing 守恆 | rev2 lint（重寫） |

## 2. entity crate Models（逐欄鏡像 m001；型對照見 R1）

> sea-orm `#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]`＋`#[sea_orm(table_name = "...")]`；timestamptz＝`DateTimeWithTimeZone`。**snake_case 欄名**對 DB（sea-orm 預設）。

### 2.1 `sys_user::Model`（16 欄、archetype A）
`id` i64【`#[sea_orm(primary_key)]`】／`user_name` String／`password` String／`deleted_at` Option\<DateTimeWithTimeZone\>／`nick_name` Option\<String\>／`user_gender` Option\<i16\>／`user_phone` Option\<String\>／`user_email` Option\<String\>／`status` Option\<i16\>／`created_at` DateTimeWithTimeZone／`created_by` Option\<i64\>／`updated_by` Option\<i64\>／`deleted_by` Option\<i64\>／`updated_at` Option\<DateTimeWithTimeZone\>／`current_session_id` Option\<String\>／`session_policy` String。

### 2.2 `sys_role::Model`（12 欄、archetype A）
`id` i64【PK】／`code` String／`name` String／`deleted_at` Option\<DateTimeWithTimeZone\>／`role_desc` Option\<String\>／`status` Option\<i16\>／`created_at` DateTimeWithTimeZone／`created_by` Option\<i64\>／`updated_by` Option\<i64\>／`deleted_by` Option\<i64\>／`updated_at` Option\<DateTimeWithTimeZone\>／`home` Option\<String\>。

### 2.3 `sys_user_role::Model`（2 欄、archetype C、複合 PK、硬刪）
`user_id` i64【`#[sea_orm(primary_key, auto_increment = false)]`】／`role_id` i64【`#[sea_orm(primary_key, auto_increment = false)]`】。**無 `deleted_at`**（硬刪、不 impl SoftDeletable）。**坑**：兩 PK 欄皆須 `auto_increment = false`（預設 true 對複合 PK 錯）。

- **Relation**：三 Model 皆 `#[derive(...DeriveRelation)] pub enum Relation {}`（**空**——本刀 facade 全單表、不展開 FK 關聯；m003 的 user_role↔user/role FK 不入 sea-orm Relation）。
- `entity/src/lib.rs`：`pub mod sys_user; pub mod sys_role; pub mod sys_user_role;`。

## 3. `SoftDeletable` trait（`model/soft_delete.rs`，全新寫⚠️g）
```rust
use sea_orm::{entity::prelude::*, Select};
pub trait SoftDeletable: EntityTrait {
    fn deleted_at_column() -> Self::Column;
    fn find_active() -> Select<Self> { Self::find().filter(Self::deleted_at_column().is_null()) }
}
```
- minimal（**無** restore/update——rev2 009 D5、DESIGN §5.1 凍結形）。
- 僅 archetype A entity impl（`sys_user`/`sys_role`）；`sys_user_role`（C 硬刪）**不** impl。

## 4. facade（`model/facade/*.rs`，guard ②：唯一存取閘；不 re-export `Entity`、回 raw `Model`）

| facade | impl `SoftDeletable`? | 公開 fn（簽名） |
|---|---|---|
| `sys_user.rs` | ✅ `deleted_at_column → Column::DeletedAt` | `find_active() -> Select<Entity>`（委派 trait）／`find_active_by_name(db, &str) -> Result<Option<Model>, DbErr>`／`find_active_by_id(db, i64) -> Result<Option<Model>, DbErr>` |
| `sys_role.rs` | ✅ `deleted_at_column → Column::DeletedAt` | `find_active_by_ids(db, &[i64]) -> Result<Vec<Model>, DbErr>`（`find_active().filter(Column::Id.is_in(ids))`） |
| `sys_user_role.rs` | ❌ plain | `find_role_ids_by_user_id(db, i64) -> Result<Vec<i64>, DbErr>`（`Entity::find().filter(Column::UserId.eq(uid))`、取 `role_id`；硬刪無 active 過濾） |

- `db: &sea_orm::DatabaseConnection`；錯誤一律 `sea_orm::DbErr` 向上（**不碰 envelope/AppError**——FR-009）。
- facade `import entity::<table>::{Column, Entity, Model}`、`use crate::model::soft_delete::SoftDeletable`（A 表）；**module 不 re-export `Entity`**。
- `model/mod.rs`：`pub mod soft_delete; pub mod facade;`；`facade/mod.rs`：`pub mod sys_user; pub mod sys_role; pub mod sys_user_role;`；`main.rs` 加 `mod model;`。

## 5. getUserInfo 讀鏈組裝（**Auth 島 handler、非本刀**；⚠️o handler 層）
未來 Auth 島 getUserInfo：`sys_user::find_active_by_id(uid)` → `sys_user_role::find_role_ids_by_user_id(uid)` → `sys_role::find_active_by_ids(role_ids)` → 取 `code` 組 `UserInfo{...,roles:[code]}`＋`User→User01` alias。soft-deleted 角色由 `find_active_by_ids` 排除。**本刀只交付三 facade 讀閘、不做組裝/DTO**。

## 6. `entity_access_lint`（`server/tests/entity_access_lint.rs`，guard ③，全新寫⚠️g）
- build-failing cargo test：掃 `CARGO_MANIFEST_DIR/src/**.rs`、strip 註解/字串/char-literal → 找 `src/model/facade/` 以外的 root-level `entity::`（`use entity::*`／`entity::sys_*::Entity`）→ `panic!`＋file:line。
- 豁免：path-prefix `src/model/facade/`。允許子路徑 `sea_orm::entity::*`（非 root）。
- false-positive regression：`identity`／`my_entity`／註解內／字串內／lifetime／char-literal 安全。
- **meta-test**：植入一筆違規樣本（in-memory string 或固定 fixture）斷言 lint 偵出（證守恆會 fail、非空跑）。

## 7. 排除聲明（不在本刀）

- **寫路徑**（`soft_delete`/`soft_delete_in_txn`/`update_*`/`replace_roles_in_txn`）＋`model/audit.rs`（`mutate_in_txn`/`AuditEvent`）→ audit 刀（首個寫路徑消費者）。
- **getUserInfo 組裝／Model→DTO／`User→User01` alias** → Auth 島 handler（⚠️o）。
- **`DbErr → AppError` From impl** → Auth 島刀（CHECKLIST §3.6）。
- **其餘 entity/facade**（`sys_menu`/`system_settings`/`sys_token`/log×3/casbin）→ 各自消費刀（首個消費者紀律；提前定義＝lint 鎖死 dead struct）。
- **`list_active_paginated`**（user/role 列表）→ 波 2 User/Role 刀（無波 0 消費者）。
- **migration**：無（`deleted_at` 已在 m001）。
