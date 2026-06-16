# Contract: soft-delete ＋ facade-access 護欄（004 落定、跨 feature 權威）

> 本刀建立的不變式，後續每個業務切片繼承（§5.0 逐格）。權威＝DESIGN §5.1／§1.5 L2-L4／constitution §I.5-§I.6。

## 1. SoftDeletable 不變式

1. **active base query**：`find_active() == find().filter(deleted_at IS NULL)`——soft-delete 實體的預設讀取**恆**經此（不含被標記列）。
2. **適用集**：恰 3 個 partial-uniq soft-delete 實體（`sys_user`/`sys_role`/`sys_menu`）impl `SoftDeletable`；`system_settings` 例外（有 `deleted_at` 欄、**不** impl、facade 直讀）；其餘 7 實體不 impl。
3. **trait 定義 lint-clean**：`model/soft_delete.rs` 純 sea_orm 泛型、**無 `entity::`**；impl 落 `model/facade/`（豁免）。
4. **後續切片擴充**：新 soft-delete 實體 → 於 facade/ 加一行 `impl SoftDeletable`（`deleted_at_column`）即繼承 `find_active`；soft_delete 寫路徑（設 `deleted_at`＋`deleted_by` 成對、§I.6）＋CRUD 為該切片自有 fn、以 `find_active` 為基底。

## 2. entity_access_lint 不變式（守恆）

1. **唯一存取閘**：`server/src` 任何檔對 entity 的 path-root `entity::` 存取，**僅** `server/src/model/facade/` 路徑下豁免；他處出現＝**build-failing**。
2. **不誤殺**：`sea_orm::entity::` 子路徑（前界 ident）／註解／字串字面內的 `entity::` **不**觸發。
3. **不過殺**：bare `Model`／`Column` 值在層間傳遞（如 facade 回 `sys_user::Model`、handler 持有）**允許**——只禁 `entity::` 路徑根、非禁型轉手。
4. **可證有效**：scan fn 自測證明「綠＋抓得住違規＋不誤殺」雙向（非 vacuous pass）。
5. **波 0 出口守恆**：本 lint 為三守恆之一（`entity_access_lint`／`endpoint_coverage_lint`〔波1〕／`migration up→down→up`〔002 達成〕，DESIGN §8.4）。

## 3. entity 層不變式（L2）

1. **完整反射**：11 entity 模組 1:1 對 002 凍結 schema（欄/型/nullability/PK 對 m001）；型對映＝tstz→DateTimeWithTimeZone、jsonb→Json、INET→IpNetwork（with-chrono/json/ipnetwork）。
2. **永不 retrofit**：entity 定義一次到位（含未本刀消費的 log/casbin/archive/token entity 的最終型）；後續切片**只加 facade**、不改 entity 定義（D1）。
3. **archetype 對齊**（§I.6）：A 業務（6 審計欄、soft-delete ×3＋例外 ×1）／B append-only（3 log、僅 created_at）／C join·狀態機（user_role 零審計、token status）／D 治理（casbin_rule adapter-invisible 3 欄、archive）。

## 4. 本刀邊界（OUT）
- 無業務 facade 方法、無 endpoint/wire、無 migration、無 runtime DB 接線、無 audit `mutate_in_txn`（各歸其刀）。
- INET 型對映風險：with-ipnetwork 須 build 驗（撞 MSRV 退 String+cast、移交實作）。
