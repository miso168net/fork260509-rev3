# 004-soft-delete-infra — Phase 0 brainstorm（spec-design）

> 波 0 第四刀。對應 rev2 009（soft-delete）。**權威＝** DESIGN §5.1（soft-delete）／§1.5（依賴層 L2/L4）／§3.4（archetype）／§8.1（slice）／§5.0（aspect grid）／§9.4（RUSTAPI-SOURCE-ISOLATION 軌道）。
> 本檔為階段 0 brainstorm 產出的「spec-design」，交給手動 `/speckit-specify`（**不**接 superpowers:writing-plans）。

## 0. 一句話

建立 **soft-delete「面」地基 ＋ L2 entity 層 ＋ L4 facade 護欄**，一次設計、每 entity 逐格繼承（§5.0），徹底避開 rev2 把 soft-delete 攤成 009/018/019 多刀尾巴的 anti-pattern（DESIGN §9 line 812）。本刀**只建地基與護欄、不建任何業務 facade/endpoint**。

## 1. Phase 0 拍板（本 brainstorm 落定）

| # | 決策 | 結論 |
|---|---|---|
| D1 | **entity/ crate 範圍** | **A＝全 11 entity 一次建齊**（完成 L2 DATA 層；entity 是 frozen schema〔002〕的機械反射、非臆測；之後每個業務刀只加 facade、不再碰 entity 定義） |
| D2 | **facade 層範圍** | **B1＝純 trait ＋ lint ＋ entity ＋ `SoftDeletable` impl（給 3 個真 soft-delete entity）**，**零業務 facade 方法**（soft_delete 寫／CRUD／find_active_by_id 全留各業務刀、§8.1 一刀一 entity 自帶） |
| D3 | **sea_orm 落地時點** | 003 的 R7 延後之 `sea-orm` 於本刀加入 server crate —— 本刀＝**首個 DB 層切片**（entity/facade/SoftDeletable 需之）；非提前耦合 |
| D4 | **entity_access_lint** | 本刀**新建**（`server/tests/` 目前不存在）；為波 0 出口三守恆之一（DESIGN §8.4／CHECKLIST 波0 出口） |

## 2. Scope

### 2.1 IN（本刀交付）
- **新 workspace crate `rust-api/entity/`**：11 entity 模組（SeaORM `DeriveEntityModel`，反射 002 schema）：
  `sys_user` · `sys_role` · `sys_menu` · `system_settings` · `sys_user_role` · `sys_token` · `sys_operation_log` · `sys_access_log` · `sys_login_attempt` · `sys_casbin_policy_archive` · `casbin_rule`
  （`seaql_migrations`＝sea-orm 框架內部表、無 entity 模組；DESIGN §1.5 L2「11 entity 模組」）。
- **server 新增 deps**：`entity`（path）＋ `sea-orm`（workspace dep；給 `EntityTrait`/`Select`/`ColumnTrait`/`QueryFilter`）。
- **`server/src/model/`**：`mod.rs` ＋ `soft_delete.rs`（`SoftDeletable` trait）＋ `facade/`（impl 放此、lint 豁免路徑）。
- **`SoftDeletable` impl** 給 3 個真 soft-delete entity（sys_user/sys_role/sys_menu）。
- **`entity_access_lint`**（`server/tests/entity_access_lint.rs`，build-failing cargo test）＋其 scan fn 自測。
- **prod Dockerfile**（`deploy/Dockerfile.rust-api.txt`）補 entity crate 的 Manifest＋Source COPY 兩行。

### 2.2 OUT（明確延後、各歸其刀）
- 業務 facade 方法（`soft_delete`/`soft_delete_in_txn`/`update_*`/CRUD/`find_active_by_id`）→ 各業務刀（§8.1）。
- `AppState.db` / `infra/db.rs` runtime DB 接線 → 首個查 DB 的端點刀（本刀 live smoke **自連** DATABASE_URL、`main.rs` 不動）。
- `mutate_in_txn`（audit 面、`model/audit.rs`）→ audit 刀（DESIGN §5.2、不同 aspect）。
- `system_settings` 的 `SoftDeletable` impl → **永不**（例外：有 `deleted_at` 欄但無刪除路徑、PK=`setting_key` 無 partial-uniq、DESIGN §3.2／§5.1；其 facade 之後直讀）。
- `endpoint_coverage_lint` → 波 1（⚠️x 已決豁免）。
- 新 migration → **無**（schema 002 已建、`deleted_at` 欄已在）。

## 3. 架構

### 3.1 `SoftDeletable` trait（`server/src/model/soft_delete.rs`）
純 sea_orm 泛型、**不含 `entity::` 路徑** → 本檔 lint-clean（非 facade 也合規）：
```rust
pub trait SoftDeletable: EntityTrait {
    fn deleted_at_column() -> Self::Column;
    fn find_active() -> Select<Self> {
        Self::find().filter(Self::deleted_at_column().is_null())
    }
}
```
- 只封 `deleted_at_column()`＋`find_active()`（active base query）——DESIGN §5.1。
- impl（含 `entity::sys_user` 等路徑）放 `server/src/model/facade/`（lint 豁免）：
  ```rust
  impl SoftDeletable for sys_user::Entity { fn deleted_at_column() -> Self::Column { sys_user::Column::DeletedAt } }
  ```
  （orphan rule：trait 在 server crate-local，impl 合法在 server；置於 facade/ 滿足 lint）。

### 3.2 `entity_access_lint`（`server/tests/entity_access_lint.rs`）
- build-failing `#[test]`：掃 `server/src/**/*.rs`，兩階段——
  1. **抹白**註解（`//`、`/* */`）＋字串字面（避免 `entity::` 出現在註解/字串造成假陽性）。
  2. 抓 **token-boundary 的 path-root `entity::`**（前界非 ident 字元 → 不誤殺 `sea_orm::entity::` 子路徑）。
- **豁免**：路徑落在 `server/src/model/facade/` 之檔。
- **不禁** bare `Model`／`Column` 轉手（只禁 `entity::` 路徑根；facade 回 `sys_user::Model`、handler 持有它＝合規）。
- **自測**（scan fn 單元測、免動樹）：`entity::Foo`→flagged；`sea_orm::entity::Bar`→not；`// entity::X` 註解／`"entity::Y"` 字串→not；facade/ 路徑→exempt。

### 3.3 entity crate 型對映紀律
- jsonb（`sys_menu.query`/`buttons`）→ `serde_json::Value`（`Json`）。
- timestamptz（`*_at` 審計欄、`deleted_at`）→ 依 002 既有 feature-gate 慣例（消費 crate 加 `with-chrono`、見 sea-orm entity DateTimeWithTimeZone feature-gate 教訓；非 `with-time`）。
- 全**新寫**（RUSTAPI-SOURCE-ISOLATION、research 不准 grep rev1 source；DESIGN §9.4）。

### 3.4 prod Dockerfile（`deploy/Dockerfile.rust-api.txt`）
- Manifest 段（≈line 34 後）：`COPY rust-api/entity/Cargo.toml ./entity/`
- Source 段（≈line 39 後）：`COPY rust-api/entity/src ./entity/src`
- runtime 段不變（entity 是 lib、編進 server binary、無獨立 runtime COPY）。
- 依據：Dockerfile line 10 已明文「★ 後刀新增 workspace crate 時必須補對應 COPY 行(Manifest 段 + Source 段各一)」。

## 4. 測試／驗收（C-V 草案；正式收於 plan 期 contracts/verification-commands.md）

| C-V | 內容 | 紀律 |
|---|---|---|
| C-V-0 | 容器內 `cargo build`（entity＋server）綠 | 改 .rs 先 force-touch 防 stale-mtime 假綠；rust serial |
| C-V-1 | `cargo test -p server --test entity_access_lint` 綠（lint 通過＋scan fn 自測證明擋違規/不誤殺） | 整支 binary 用 `--test <name>`、警覺「0 passed/N filtered」假綠 |
| C-V-2 | `SoftDeletable::find_active` **live smoke**——in-crate `#[ignore]`＋DATABASE_URL＋`--test-threads=1`：txn 內對 sys_user 一列設 `deleted_at`→斷言 `find_active()` 排除、`find()` 含→**rollback**（不動 002 seed） | live 一律 `--ignored --test-threads=1`（005 audit live serial 教訓） |
| C-V-3 | **prod target image build**：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 成功 | **新 workspace crate ⇒ 必跑 prod build**（防 dev bind-mount 遮 COPY 缺口、rev2 教訓） |

## 5. 出口條件
- C-V-0~3 全綠 → soft-delete「面」地基成立。
- `entity_access_lint` 守恆綠（波 0 出口三守恆之一、DESIGN §8.4）。
- L2 entity 層完成（11 entity）、後續業務刀只加 facade（§5.0 逐格繼承）。

## 6. Constitution / 軌道
- **RUSTAPI-SOURCE-ISOLATION**（DESIGN §9.4、§I.5）：rust-api 全新寫、設計繼承 rev1、code 不拷貝；research 不准 grep rev1 source。
- **新 workspace crate ⇒ acceptance 必含 prod target build**（CLAUDE.md §3 Phase 1 紀律）。
- 無 base-web 改動 → 不觸 ⚠️aa／MODAL-WIRING 等 ★ 軌道。
- 無 schema 變更／無建表 → 不觸 constitution §I 建表題。

## 7. 風險 / 已知坑（移交 plan Phase 0 research）
- entity crate 為**新 workspace member** → plan 的 `verification-commands.md` 必含 prod image build（§4 C-V-3）。
- timestamptz 欄 feature-gate：新 entity Model 帶 `DateTimeWithTimeZone` 撞 E0412，消費 crate 須加 `with-chrono`（既有教訓）。
- `entity_access_lint` 自身為 build-failing test：設計需「真綠＋自測擋得住」雙證，避免空護欄（vacuous pass）。
- live smoke 須 txn-rollback、勿污染 002 seed；`--test-threads=1` 防偽失敗。
- `server` 為 bin-only crate（無 lib.rs）：lint test 只**讀檔**、不 `use server::`（沿既有 lint 模式）；需 crate 內部 API 的測試（find_active live）放 **in-crate `#[cfg(test)]`＋`#[ignore]`＋env-gate**。
