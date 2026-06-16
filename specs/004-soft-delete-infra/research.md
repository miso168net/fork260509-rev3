# Phase 0 Research: 004-soft-delete-infra

> 接地源＝m001 schema 親讀（11 表逐欄、`rust-api/migration/src/m001_rev2_schema.rs`）＋DESIGN §5.1/§1.5/§3.4＋constitution §I.5/§I.6＋brainstorm `docs/superpowers/004-soft-delete-infra.md`（D1~D4 拍板）。**NEEDS CLARIFICATION = 0**（4 拍板＋IN/OUT 邊界於 brainstorm 全決）。

## R1 — scaffold：新 workspace crate `entity` ＋ server deps

**Decision**：新增 workspace member `rust-api/entity/`（lib crate、11 entity 模組）；`rust-api/Cargo.toml` `[workspace]` members 加 `"entity"`、`[workspace.dependencies]` 視需要無新增（sea-orm 已在）。server `[dependencies]` 加 `entity = { path = "../entity" }` ＋ `sea-orm = { workspace = true }`（給 `EntityTrait`/`Select`/`ColumnTrait`/`QueryFilter`／live test 的 `Database::connect`）。
**Rationale**（grep）：`rust-api/Cargo.toml` members 現＝`["server","migration","sea-orm-adapter"]`、無 entity crate；`server/Cargo.toml` deps 現＝axum/serde/serde_json/tokio/tracing（**無 sea-orm**）。003 R7 延後之 sea-orm 於本刀（首個 DB 層切片）落地。
**Alternatives**：把 entity 放 server crate 內模組——否決（DESIGN §1.5 L2「entity/ crate」獨立層、與 migration/server 分離；facade lint 掃 server/src，entity 在獨立 crate 天然在掃描範圍外）。

## R2 — entity 型對映（特殊欄：timestamptz／jsonb／INET）

**Decision**：entity crate 的 sea-orm 啟 `with-chrono`＋`with-json`＋`with-ipnetwork` 三 feature，逐欄忠實對映：
- **timestamptz**（`*_at`／`deleted_at`／`issued_at`／`expires_at`／`used_at`／`archived_at`）→ `DateTimeWithTimeZone`（`with-chrono`）。
- **jsonb**（`sys_menu.query`/`buttons`、`sys_operation_log.payload_before`/`payload_after`）→ `Json`（`serde_json::Value`、`with-json`）。
- **INET**（`sys_operation_log.operator_ip`、`sys_access_log.client_ip`、`sys_login_attempt.client_ip`）→ `IpNetwork`（`with-ipnetwork`）。
**Rationale**：m001 親讀確認三型分布；workspace sea-orm `default-features=false`、無 date-time/json/inet backend → 帶這些欄的 entity Model 不加 feature 會撞 E0412（既有教訓：sea-orm entity DateTimeWithTimeZone feature-gate）。**D1「機械反射、永不改動實體定義」⇒ INET 一次對到最終型 `IpNetwork`、不用 `String` 佔位**（避免 audit 刀日後改型＝D1 要防的 retrofit；亦免 type-lie）。三 INET 欄全在 append-only log 表（archetype B）、本刀不查、僅須編譯綠。
**Alternatives**：INET→`String`＋facade `::text` cast——否決（D1 防 retrofit、user 對 type-lie 敏感；雖省 ipnetwork dep 但留 cast 慣例債）。**風險自覺**：`with-ipnetwork` 為標準 sea-orm feature（ipnetwork crate 小、穩定），實作須驗其於 1.86 toolchain build 綠（沿 with-chrono 同款驗法）；若撞 MSRV／lock churn，退而 `String`＋註明 audit 刀 cast（移交 plan contracts 標記）。

## R3 — `SoftDeletable` trait 設計（§5.1）

**Decision**：`server/src/model/soft_delete.rs` 定義 `pub trait SoftDeletable: EntityTrait { fn deleted_at_column() -> Self::Column; fn find_active() -> Select<Self> { Self::find().filter(Self::deleted_at_column().is_null()) } }`——**純 sea_orm 泛型、無 `entity::` 路徑** → 本檔非 facade 仍 lint-clean。impl（含 `entity::sys_user` 等路徑）置 `server/src/model/facade/`（lint 豁免）；impl 僅 3 個真 soft-delete entity（sys_user/sys_role/sys_menu）。
**Rationale**（schema）：3 表帶 `deleted_at` tstz null ＋ partial-uniq `WHERE deleted_at IS NULL`（m001 `sys_user_user_name_active_uniq`/`sys_role_code_active_uniq`/`sys_menu_route_name_active_uniq`）；`find_active` 即 active base query。soft_delete 寫路徑／`update_*`／CRUD＝各業務刀自有 fn（D2 B1、不在本刀）。
**Alternatives**：trait 內直接 impl 各 entity——否決（trait def 一旦 import `entity::` 即須整檔進 facade/；分離 trait-def〔soft_delete.rs〕與 impl〔facade/〕較清、lint 邊界自然）。

## R4 — `entity_access_lint` 演算法（§5.1）

**Decision**：`server/tests/entity_access_lint.rs`（新建——現無 `server/tests/`）build-failing `#[test]`：掃 `server/src/**/*.rs`、兩階段——(1) 抹白註解（`//`、`/* */`）＋字串字面 (2) regex/token 掃 path-root `entity::`（前界須非 ident 字元 → 不誤殺 `sea_orm::entity::`）；路徑落 `server/src/model/facade/` 之檔豁免；命中非豁免檔 → panic 列違規處。scan fn 另含**單元自測**：`entity::Foo`→flagged／`sea_orm::entity::Bar`→not／`// entity::X`、`"entity::Y"`→not／facade/ 路徑→exempt——免動樹即證護欄有效（FR-006、防 vacuous pass）。
**Rationale**（grep）：`server/src` 現＝envelope/error/main.rs（無 entity:: 使用）；新增 model/soft_delete.rs（無 entity::）＋model/facade/*（有 entity::、豁免）→ lint 掃描後綠。CLAUDE.md §8.2.1「既有 lint」措辭為 template／aspirational（實際 `server/tests/` 不存在、本刀首建）。
**Alternatives**：clippy custom lint／build.rs——否決（cargo test 內讀檔掃描最簡、無額外 toolchain；`server` bin-only〔無 lib.rs〕、`server/tests/` 整合測**只讀檔不 `use server::`**、沿既有 lint 模式）。

## R5 — `find_active` live smoke（txn-rollback）

**Decision**：in-crate `#[cfg(test)] #[ignore]`＋env-gate（DATABASE_URL）＋`--test-threads=1`：開 txn → 對 sys_user 既有 seed 一列（如 id=1）`UPDATE deleted_at=now()` → 斷言 `SysUser::find_active()` **不**含該列、`SysUser::find()` **含** → **rollback**（不持久變更 002 seed）。
**Rationale**：002 seed 有 sys_user id=1/2/3（Super/Admin/User）；txn-rollback 隔離、不污染。host 無 toolchain → 容器內 `docker compose … exec -T rust-api`（DATABASE_URL 帶）。`--test-threads=1`＝live serial 教訓（避免偽失敗）。
**Alternatives**：插臨時列再刪——可，但 txn-rollback 更乾淨（零殘留、零 seq 漂移）。

## R6 — 無 migration（schema 已凍）

**Decision**：本刀**不**新增 migration、不建表、不改 schema。`deleted_at` 欄與 partial-uniq 已於 002（m001）建。
**Rationale**（schema）：m001 已建 `deleted_at` ×4 表（sys_user/role/menu/system_settings）＋partial-uniq ×3；entity 只反射既有 schema。constitution §I.6「建表即帶審計欄、無 retrofit」於本刀 N/A（無建表）。
**Alternatives**：無。

## R7 — prod Dockerfile（新 crate COPY）

**Decision**：`deploy/Dockerfile.rust-api.txt` Manifest 段加 `COPY rust-api/entity/Cargo.toml ./entity/`、Source 段加 `COPY rust-api/entity/src ./entity/src`；runtime 段不變（entity 是 lib、編進 server binary、無獨立 runtime COPY）。
**Rationale**（grep）：Dockerfile line 10 明文「★ 後刀新增 workspace crate 時必須補對應 COPY 行(Manifest 段 + Source 段各一)」；現 Manifest 段 COPY server/migration/sea-orm-adapter 三 Cargo.toml（:32-34）、Source 段 COPY 三 src（:37-39）；runtime（:92）`COPY --from=builder /out/server /out/migration`。
**Alternatives**：無——紀律強制（防 dev bind-mount 遮 COPY 缺口、rev2 教訓）。

## R8 — RUSTAPI-SOURCE-ISOLATION ＋ 三-grep 紀律

**Decision**：entity 全**新寫**（constitution §I.5 / §III.1 RUSTAPI-SOURCE-ISOLATION、預設可動軌道、無 ★ 授權需求）；research 不 grep rev1 source。`sea-orm-adapter`（§I.5 例外、已隨 002 vendored）本刀**不**再拷貝、不動。
**三-grep 落地**：
- **facade/entity 返回型 grep**：N/A（本刀無 facade 返回；entity 為新建、欄定義權威＝m001 親讀）。
- **wire 3 端對齊**：N/A（本刀無 endpoint／wire／base-web 改動）。
- **命名對照 grep**：entity 欄名／型逐欄對 m001（親讀 line 23-198 enum 定義＋200-744 ColumnDef）；data-model 逐 entity 註 m001 來源。
- **CDP smoke defer**：N/A（無 UI／endpoint；唯一活體＝find_active live smoke、非 CDP）。
