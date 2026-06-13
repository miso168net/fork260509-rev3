# Contract: entity-access-contract（facade 唯一閘＋SoftDeletable＋守恆 lint；test 權威）

> 守恆 lint＋query-shape 為**純函式 test-first**（先紅後綠）；实机 smoke 證「過濾真生效」。形狀對齊 R1/R2 grep 與 data-model；紅了校實作、不調 contract 遷就實作（⚠️g 全新寫、但 trait/lint 形對齊 rev2 參照）。

## 1. `SoftDeletable` trait 契約（guard ①）

- `deleted_at_column() -> Self::Column`：A 表 impl 回各自 `Column::DeletedAt`。
- `find_active() -> Select<Self>`：default＝`Self::find().filter(Self::deleted_at_column().is_null())`。
- **query-shape 斷言（純 render、無 DB）**：對每個 impl 的 entity，
  `<Entity as SoftDeletable>::find_active().build(DbBackend::Postgres).to_string()` **MUST contain** `"deleted_at" IS NULL`。
  - `sys_user`：含 `"sys_user"."deleted_at" IS NULL`。
  - `sys_role`：含 `"sys_role"."deleted_at" IS NULL`。

## 2. facade 契約（guard ②；回 raw `Model`、不 re-export `Entity`）

| facade fn | 簽名 | 行為契約 |
|---|---|---|
| `sys_user::find_active_by_name` | `(db, &str) -> Result<Option<Model>, DbErr>` | active 過濾＋`UserName.eq`；查無 `Ok(None)` |
| `sys_user::find_active_by_id` | `(db, i64) -> Result<Option<Model>, DbErr>` | active 過濾＋`Id.eq`；查無 `Ok(None)` |
| `sys_role::find_active_by_ids` | `(db, &[i64]) -> Result<Vec<Model>, DbErr>` | active 過濾＋`Id.is_in(ids)`；空 ids → `Ok(vec![])` |
| `sys_user_role::find_role_ids_by_user_id` | `(db, i64) -> Result<Vec<i64>, DbErr>` | `UserId.eq`、取 `role_id`；**無** active 過濾（硬刪） |

- **結構斷言（由 guard ③ lint 保證）**：模組外無 `entity::sys_*::Entity` 直存取；facade module **不** `pub use Entity`。
- facade 回 `sea_orm::DbErr`、**不**映射 envelope/AppError（FR-009）。

## 3. `entity_access_lint` 契約（guard ③；build-failing cargo test）

- **擋**（facade 目錄外的 root-level `entity::`）：`use entity::*`、`use entity::sys_user::Entity`、`entity::sys_role::Entity::find()` 等 → 建置失敗、`panic!` 列 file:line。
- **放**：`src/model/facade/**` 內任何 `entity::`（path-prefix 豁免）；非 root 的 `sea_orm::entity::*`；含 `entity` 子字串但非 `entity::` 路徑的識別字（`identity`/`my_entity`）；註解/字串/char-literal 內的 `entity::`。
- **斷言**：
  - ① 對 facade 內存取 → pass（不誤擋）。
  - ② false-positive 樣本（`identity`/`my_entity`／`// entity::x`／`"entity::x"`／`'e'` char）→ 0 誤報。
  - ③ **meta-test**：餵一段含 facade 外 `entity::sys_user::Entity` 的樣本字串給掃描函式 → 回報 ≥1 violation（證守恆會擋、非空跑）。

## 4. bounded 实机 smoke 契約（`#[ignore]`、`DATABASE_URL`、`postgres+migrate` m002 seed）

對 m002 seed（user 1=`Super`／`sys_user_role` 1→R_SUPER role_id／`sys_role` R_SUPER）：
1. `sys_user::find_active_by_name("Super")` → `Some(model)`、`model.user_name=="Super"`。
2. 對該 user stamp `deleted_at=now()`（测试内 raw update 或經未來寫路徑模擬）後 → `sys_user::find_active_by_id(super_id)` 回 `None`（**證 active 過濾排除已刪列**）。
3. `sys_user_role::find_role_ids_by_user_id(super_id)` → 非空 `Vec<i64>`（含 R_SUPER 的 role_id）。
4. `sys_role::find_active_by_ids([r_super_id])` → `Vec<Model>` 含 `code=="R_SUPER"`。

> 測試隔離：smoke 對 seed 列 stamp `deleted_at` 後須 teardown 還原（或用拋棄式列），避免污染 seed。run：`cargo test -p server -- --ignored --test-threads=1`（DB 起著時）；常規 `cargo test -p server` 不含 `#[ignore]`。
