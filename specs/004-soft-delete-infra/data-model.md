# Data Model: 004-soft-delete-infra

> 本刀＝**L2 entity 層（新 crate）＋L4 soft-delete/facade 護欄基建**。**無持久實體變更、無 migration**——entity 為 002 凍結 schema（`rust-api/migration/src/m001_rev2_schema.rs`）的機械反射。**欄級權威＝m001**（逐欄/型/約束以 m001 為準、本檔註 line 範圍、不重抄以免漂移）；本檔定義的是 entity-crate 的**設計決策**（型對映、SoftDeletable、lint、特殊欄處理）。

## 1. entity crate 結構（`rust-api/entity/`、新 workspace member）

`lib.rs`（`pub mod` 各 entity）＋ 11 entity 模組（SeaORM `DeriveEntityModel`）。sea-orm features：`macros`＋`with-chrono`＋`with-json`＋`with-ipnetwork`（R2）。

### 1.1 11 entity 一覽（欄定義權威＝m001）

| # | entity 模組 | 表 | m001 enum / CREATE | 欄數 | PK | soft-delete | 特殊型欄 |
|---|---|---|---|---|---|---|---|
| 1 | `sys_user` | sys_user | :23 / :206 | 16 | `id` i64 auto | **✅**（partial-uniq `user_name`）| tstz: deleted_at/created_at/updated_at |
| 2 | `sys_role` | sys_role | :44 / :261 | 12 | `id` i64 auto | **✅**（partial-uniq `code`）| tstz: deleted_at/created_at/updated_at |
| 3 | `sys_menu` | sys_menu | :61 / :303 | 28 | `id` i64 auto | **✅**（partial-uniq `route_name`）| tstz ×3；**jsonb: query/buttons**；**reserved word: `order`** |
| 4 | `system_settings` | system_settings | :94 / :366 | 10 | `setting_key` String(64) | ❌ **例外**（有 deleted_at 欄、無 partial-uniq、無刪除路徑）| tstz: created_at/updated_at/deleted_at |
| 5 | `sys_user_role` | sys_user_role | :109 / :414 | 2 | 複合 `(user_id, role_id)` | ❌ | —（零審計）|
| 6 | `sys_token` | sys_token | :116 / :433 | 9 | `id` i64 auto | ❌ | tstz: issued_at/expires_at/used_at/created_at；token_hash UNIQUE |
| 7 | `sys_operation_log` | sys_operation_log | :130 / :485 | 10 | `id` i64 auto | ❌（append-only）| **jsonb: payload_before/after**；**INET: operator_ip**；tstz: created_at |
| 8 | `sys_access_log` | sys_access_log | :145 / :549 | 10 | `id` i64 auto | ❌（append-only）| **INET: client_ip (NN)**；text: method/path |
| 9 | `sys_login_attempt` | sys_login_attempt | :160 / :593 | 9 | `id` i64 auto | ❌（append-only）| **INET: client_ip (NN)** |
| 10 | `casbin_rule` | casbin_rule | m001:193（治理 3 欄 ALTER :643）；adapter `entity.rs`/`migration.rs`（親驗）| 11 | `id` i64 auto | ❌（治理）| **8 adapter-base**（親驗）：`id` i64／`ptype` String(18) NN／`v0..v5` String(125) NN ＋**3 治理 ALTER**：`protected` bool NN(def false)／`created_at` tstz NN／`created_by` Option<i64>。**entity crate 自定 11 欄**（含治理欄）、**勿複用 adapter 自身 8 欄 Model**（其對治理欄隱形、§I.6 D）|
| 11 | `sys_casbin_policy_archive` | sys_casbin_policy_archive | :174 / :667 | 13 | `id` i64 auto | ❌（治理緩衝）| v0..v5 String(125)；tstz: created_at/archived_at |

（`seaql_migrations`＝框架表、無 entity 模組。）

### 1.2 型對映規則（R2）

| PG 型 | Rust（entity Model） | feature |
|---|---|---|
| `bigint`（id/`*_by`/`*_id`）| `i64` / `Option<i64>` | core |
| `smallint`（gender/status/menu_type/icon_type）| `i16` / `Option<i16>` | core |
| `integer`（`order`/fixed_index_in_tab/http_status）| `i32` / `Option<i32>` | core |
| `varchar`/`text` | `String` / `Option<String>` | core |
| `boolean` | `bool` / `Option<bool>` | core |
| **`timestamptz`** | `DateTimeWithTimeZone` / `Option<…>` | **with-chrono** |
| **`jsonb`** | `Json`（`serde_json::Value`）/ `Option<…>` | **with-json** |
| **`INET`** | `IpNetwork` / `Option<…>` | **with-ipnetwork** |

- nullability：逐欄對 m001 的 `.null()` / `.not_null()`（如 sys_user.deleted_at=Option、created_at=NN）。
- `sys_menu.order`：PG 保留字、m001 以雙引號建 → entity 加 `#[sea_orm(column_name = "order")]`、Rust 欄名 `order`（或 `r#order`）。
- INET 風險自覺見 R2（with-ipnetwork build 須驗；撞 MSRV 退 String+cast）。

## 2. `SoftDeletable` trait（`server/src/model/soft_delete.rs`）

```
pub trait SoftDeletable: EntityTrait {
    fn deleted_at_column() -> Self::Column;
    fn find_active() -> Select<Self> { Self::find().filter(Self::deleted_at_column().is_null()) }
}
```
- 純 sea_orm 泛型、**無 `entity::`** → 本檔 lint-clean（非 facade 仍合規）。
- **impl 僅 3 個**（`server/src/model/facade/`、lint 豁免）：`sys_user`/`sys_role`/`sys_menu`，各 `fn deleted_at_column() -> Self::Column { <entity>::Column::DeletedAt }`。
- `system_settings` **不** impl（例外、§3.2）；其餘 7 非 soft-delete entity 不 impl。
- soft_delete 寫／`update_*`／CRUD／`find_active_by_id`＝各業務刀自有（D2 B1、不在本刀）。

## 3. facade 模組（`server/src/model/facade/`）

- 本刀僅放 SoftDeletable **impl**（含 `entity::` 路徑、走 lint 豁免）；無業務 facade 方法。
- 檔案佈局實作自決（如 `facade/sys_user.rs`/`sys_role.rs`/`sys_menu.rs` 各放 impl，或單一 `facade/soft_delete_impls.rs`）；唯一硬約束＝impl 落在 `server/src/model/facade/` 路徑下（lint 豁免）。
- `model/mod.rs` 串 `pub mod soft_delete; pub mod facade;`；`main.rs` 加 `mod model;`。

## 4. `entity_access_lint`（`server/tests/entity_access_lint.rs`、新建）

- build-failing `#[test]`：掃 `server/src/**/*.rs`、兩階段（抹白註解/字串 → 抓 path-root `entity::`、前界非 ident）；`server/src/model/facade/` 路徑豁免；命中非豁免 → panic。
- **不誤殺** `sea_orm::entity::`（前界檢查）；**不禁** bare `Model`/`Column` 轉手。
- **scan fn 自測**（同檔 `#[test]`，免動樹）：`entity::Foo`→flagged｜`sea_orm::entity::Bar`→not｜`// entity::X`／`"entity::Y"`→not｜facade/ 路徑→exempt（FR-006、防 vacuous）。
- `server` bin-only（無 lib.rs）→ 本 test **只讀檔、不 `use server::`**（沿既有 lint 模式）。

## 5. 排除聲明（OUT、各歸其刀）
- 無業務 facade 方法（soft_delete 寫/CRUD/find_active_by_id）→ 各業務刀。
- 無 `AppState.db`/`infra/db.rs` runtime 接線 → 首個查 DB 端點刀（live smoke 自連、main.rs 不動）。
- 無 `mutate_in_txn`（audit）→ audit 刀；無 endpoint/wire；無 migration。
- INET 欄（3 log entity）型已對 `IpNetwork`、但 log facade（讀寫）屬 audit 刀；本刀僅須 entity 編譯綠。
- casbin_rule 8 adapter-base 欄型**已親驗**（`sea-orm-adapter/src/entity.rs` Model＋`migration.rs` DDL：`id` i64／`ptype` String(18)／`v0..v5` String(125)）；entity crate 自定 11 欄（+治理 3）、與 adapter 自身 8 欄 Model distinct（治理欄 adapter-invisible、§I.6 D）；其 facade 屬 policy 刀。
