# 004-soft-delete-infra — Phase 0 Brainstorm（spec-design）

> 波 0 第四刀（001 infra-deploy → 002 rev2-schema-baseline → 003 envelope → **004 soft-delete-infra**）。
> 對應 rev2 009「soft-delete 基建」。本檔為 brainstorm 定稿的 spec-design，作為 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §5.1（soft-delete triple-guard）＋§1.5 L4（FACADE 層）為設計本體；⚠️o（application-RI 驗證層位＝handler 層、已決 DECISIONS §1）、⚠️g（受控參照 rev2 source 讀允許拷貝禁止）為邊界。本檔不得與三者衝突（衝突以 DECISIONS §1 ＞ DESIGN ＞ 本檔為序）。

---

## 1. 目標一句話

把後端「entity 存取唯一管道＝facade」的存取控制基建一次立起來：新建 `entity` crate＋`SoftDeletable` trait（soft-delete 過濾 base query）＋`model/facade/` 首批 facade（getUserInfo 讀叢集 `sys_user`/`sys_role`/`sys_user_role`）＋`entity_access_lint`（build-failing 守恆 test），讓後續所有 handler 刀都站在「entity 只能經 facade 取、soft-deleted 列預設不可見」的前提上——機制就位＋三表 proof，其餘 entity/facade 隨各自消費刀逐一加。

## 2. Context（B1 蒐集）

### 2.1 rev2 009 參考形（受控參照重寫、非照拷——⚠️g）
- **`SoftDeletable` trait**（`server/src/model/soft_delete.rs`）：`deleted_at_column() -> Self::Column` ＋ `find_active() -> Select<Self>`（default impl＝`Self::find().filter(deleted_at_column().is_null())`）。**minimal**：無 `restore`/`update_active`（D5 YAGNI）。
- **facade**（`server/src/model/facade/sys_user.rs`）：proof on `sys_user` only；`find_active_by_name`/`find_active_by_id`/`list_active_paginated`；**不 re-export `Entity`**、回傳 sea-orm raw `Model`；local `impl SoftDeletable for Entity`（不對外）。
- **`entity_access_lint`**（`server/tests/entity_access_lint.rs`）：build-failing cargo test，掃 `src` strip 註解/字串後找 facade 目錄外的 root-level `entity::`、`panic!`+file:line；含 ~15 個 false-positive regression（`identity`/`my_entity`/註解/字串/lifetime/char-literal 安全）。
- **rev2 009 = 「立機制 + 只套 sys_user proof」**；entity crate 由 009 首建；其餘 entity/facade 隨後續 feature 逐一加。
- **rev2 用 migration 加 `deleted_at`**（009 含 `m..._softdelete_sys_user.rs`：加欄＋drop column-uniq＋建 partial-unique `WHERE deleted_at IS NULL`）。

### 2.2 凍結權威
- **DESIGN §5.1 soft-delete triple-guard**：① `SoftDeletable` trait（`model/soft_delete.rs`）；② `model/facade/` 不 re-export `Entity`；③ lint＝`server/tests/entity_access_lint.rs` build-failing cargo test。套用對象＝archetype A（`sys_user`/`sys_role`/`sys_menu`，`system_settings` 例外：有 `deleted_at` 但無 partial-uniq，PK=`setting_key` 已唯一）。
- **DESIGN §1.5 L4 FACADE 層**：`model/facade/*`（唯一 entity 存取閘）＋同層 `model/soft_delete.rs`＋`model/audit.rs`（`mutate_in_txn`，**本刀不做**）。
- **⚠️o（DECISIONS §1）已決**：application-RI／組裝驗證**維持 handler 層**、下沉 facade 屬設計變更須明示。⇒ getUserInfo 的 user→roles 組裝＋DTO 映射屬 **Auth 島 handler 邏輯、不在本刀**。
- **⚠️g**：rev2 source 為受控參照（讀允許、拷貝禁止）；soft-delete/facade/lint **不在 §I.5 拷貝例外清單**（唯 sea-orm-adapter/xdb）⇒ 全新寫，rev2 僅作參照（同 envelope 形）。

### 2.3 rust-api 現況
- workspace members＝`server`/`migration`/`sea-orm-adapter`；**無 `entity` crate、無 `server/src/model/`**。
- `server/src/`＝`main.rs`（`mod envelope; mod error;`＋`/health`）＋`envelope.rs`＋`error.rs`（003 落地）；server deps 無 `sea-orm`。
- **m001 已含 4 archetype-A 表的 `deleted_at` 欄**（002 把 rev2 终態 schema squash 入庫）⇒ **本刀無 migration、無 schema 變動**（與 rev2 009 關鍵差異）。
- m002 seed 有 `sys_user`（Super/Admin/User）＋`sys_user_role`（1→R_SUPER、2→R_ADMIN、3→R_USER_COMMON）＋`sys_role`（R_SUPER/R_ADMIN/R_USER_COMMON）⇒ 实机 smoke 有真資料可驗。

### 2.4 消費者（決定 proof set 與 facade fn 面）
- **Auth 島最小段（波 0、本刀之後）的 getUserInfo** 讀叢集：`sys_user`（by_id）→ `sys_user_role`（role_ids by user_id）→ `sys_role`（active roles by ids）→ 組裝 `UserInfo{...,roles[code]}`＋`User→User01` alias。login 另需 `sys_user`（by_name）。
- 三表＝本刀 proof set（option 3）；getUserInfo 的**組裝**留 Auth 島（⚠️o handler 層）。

## 3. Scope（B2 拍板）

**本刀做（option A 機制 + option 3 proof set）：**
- 新 `entity` crate（`sys_user`/`sys_role`/`sys_user_role` 三 Model、逐欄鏡像 m001）。
- `model/soft_delete.rs`：`SoftDeletable` trait（minimal）。
- `model/facade/`：`sys_user.rs`（SoftDeletable）＋`sys_role.rs`（SoftDeletable）＋`sys_user_role.rs`（**plain、無 SoftDeletable**，硬刪 join）。
- `server/tests/entity_access_lint.rs`：build-failing 守恆 lint（全新寫＋regression＋meta-test）。
- 依賴/接線（server 加 `sea-orm`＋`entity`）＋Dockerfile COPY＋contract test（純 cargo test ＋ bounded 实机 smoke）。

**Deferred（不在本刀）：**
- **寫路徑**（`soft_delete`/`soft_delete_in_txn`/`update_*`）＋`model/audit.rs`（`mutate_in_txn`）→ **下一刀 audit**（首個寫路徑消費者）。
- **getUserInfo 組裝＋Model→DTO＋`User→User01` alias** → Auth 島 handler（⚠️o）。
- **其餘 archetype-A facade**（`sys_menu` 波2、`system_settings` 波1/2）＋其餘 entity（`sys_token` 波3、log 三表 audit 刀、casbin 經 adapter）→ 各自消費刀（首個消費者紀律；提前定義＝lint 鎖死的 dead struct＋形狀易猜錯）。
- **`DbErr → AppError` 的 `From` impl**（供 handler `?` 傳播）→ Auth 島刀（§3.6 已登）。
- **migration**：無（`deleted_at` 已在 m001）。

## 4. brainstorm 拍板

| # | 決策 | 結論 |
|---|---|---|
| 刀界 scope | 純機制+proof（A）vs 全4A（B）vs 全11（C） | **A：機制 + proof**（最小刀紀律＋envelope「機制先行、消費者隨後」前例；B/C 過早＋dead code） |
| proof set | sys_user only / +sys_role / **+sys_user_role** / 全4A / 全11 | **option 3：`{sys_user, sys_role, sys_user_role}`**（getUserInfo 讀叢集全 facade 化；證 `SoftDeletable`×2 soft-deletable A 表 ＋ plain facade×1 硬刪 join＝facade pattern 不綁 soft-delete；三表皆波0 Auth 真消費者、dead-code 窗最短） |
| 驗證策略 | 純 cargo test（i） / **+bounded 实机 smoke（ii）** / 完整实机（iii） | **(ii)**：純函式（lint＋query-shape）test-first；DB 端只用一條有界 smoke 證「soft-delete 過濾真生效」此核心點（compile 證不了），其餘留消費刀 |
| 寫路徑/audit.rs | 納入 vs defer | **defer 給 audit 刀**（rev2 009 亦讀側 only；`mutate_in_txn` 隨首個寫路徑消費者） |
| migration | 需要 vs 不需要 | **不需要**（`deleted_at` 已在 m001、純 Rust 層） |
| 实机 smoke gating | — | **`#[ignore]` 整合測試 ＋ `postgres+migrate`**（非全 stack）；`cargo test -- --ignored` 起著 DB 才跑、純 cargo test 不含它 |

## 5. Design

### 5.1 架構洞察（option 3 凸顯）
**`facade` = 通用 entity 存取閘**（lint 強制、所有表都要）；**`SoftDeletable` = optional mixin**（只 archetype-A 表 impl）。本刀同時證兩條路：soft-deletable facade（`sys_user`/`sys_role` impl trait、`find_active*` 過濾）＋ plain facade（`sys_user_role` 硬刪 join、無 trait、無過濾）。universality 由 **lint** 保證（禁所有 facade 外 `entity::`），非靠「每個 facade 都 soft-delete」。

### 5.2 結構與檔案
- **新 crate `rust-api/entity/`**（workspace member）：`entity/src/{sys_user,sys_role,sys_user_role}.rs`（sea-orm `DeriveEntityModel`、逐欄鏡像 m001、含 `deleted_at`〔A 表〕；**無跨表 Relation**〔sea-orm 空 `Relation` enum 樣板照舊保留、僅不展開 FK 關聯〕——facade 全單表、join 組裝在 handler）＋`entity/src/lib.rs`（`pub mod` 三表）＋`entity/Cargo.toml`（`sea-orm = { workspace = true }`）。
- **`server/src/model/`**（新）：`model/mod.rs`（`pub mod soft_delete; pub mod facade;`）＋`model/soft_delete.rs`＋`model/facade/{mod,sys_user,sys_role,sys_user_role}.rs`；`main.rs` 加 `mod model;`。
- **`server/tests/entity_access_lint.rs`**：build-failing 守恆 lint。
- **`server/Cargo.toml`**：加 `sea-orm = { workspace = true }`＋`entity = { path = "../entity" }`（sea-orm 已在 lock〔002〕、**無新 crate 下載**；server binary 變大但 `main.rs` 不連 DB＝infra ahead of consumer）。
- **`deploy/Dockerfile.rust-api.txt`**：補 `entity` 的 Manifest 段（`COPY rust-api/entity/Cargo.toml ./entity/`）＋Source 段（`COPY rust-api/entity/src ./entity/src`）。
- **無 migration、無 `model/audit.rs`**。

### 5.3 `SoftDeletable` trait（guard ①, `model/soft_delete.rs`，全新寫⚠️g）
```rust
pub trait SoftDeletable: EntityTrait {
    fn deleted_at_column() -> Self::Column;
    fn find_active() -> Select<Self> {
        Self::find().filter(Self::deleted_at_column().is_null())
    }
}
```
minimal（無 restore/update，DESIGN §5.1／rev2 009 D5 凍結形）。

### 5.4 facade（guard ②：唯一 entity 存取閘；回 sea-orm raw `Model`、不 re-export `Entity`）

| facade | archetype | impl `SoftDeletable`? | fn（波0 getUserInfo／login 驅動） |
|---|---|---|---|
| `facade/sys_user.rs` | A（soft-del） | ✅ `deleted_at_column → Column::DeletedAt` | `find_active_by_name(db,&str) -> Result<Option<Model>,DbErr>`（login）／`find_active_by_id(db,id) -> Result<Option<Model>,DbErr>`（getUserInfo） |
| `facade/sys_role.rs` | A（soft-del） | ✅ | `find_active_by_ids(db,&[id]) -> Result<Vec<Model>,DbErr>`（getUserInfo 角色組裝、回含 `code` 的 active 角色） |
| `facade/sys_user_role.rs` | C（硬刪 join） | ❌ **plain** | `find_role_ids_by_user_id(db,user_id) -> Result<Vec<role_id>,DbErr>`（join 表讀；無 `find_active` 過濾、硬刪無 `deleted_at`） |

- 每 facade **單表**；getUserInfo 的 `by_id → role_ids → by_ids → 組裝 UserInfo DTO` 跨表組裝＝**Auth 島 handler**（⚠️o）、不在本刀。
- `list_active_paginated`（`sys_user`／`sys_role` 列表）留波 2 User/Role 刀（無波0 消費者）。

### 5.5 `entity_access_lint`（guard ③, `server/tests/`，全新寫⚠️g）
- build-failing cargo test：掃 `server/src/**`、strip 註解/字串/char-literal，找 `server/src/model/facade/` 以外的 root-level `entity::`（`use entity::*`／`entity::sys_*::Entity`）→ `panic!`＋file:line。
- 含 false-positive regression（`identity`/`my_entity`／註解內／字串內／lifetime／char-literal 安全）。
- **meta-test**：植入一筆違規樣本斷言 lint 真的抓到（證守恆會 fail build、非空跑）。

### 5.6 錯誤處理
- facade 回 `Result<_, sea_orm::DbErr>`（原生）；**不碰 envelope/`AppError`**（facade 在 handler 之下）。`DbErr → AppError` 的 `From` impl 在 Auth 島刀做（§3.6 已登）。

### 5.7 驗證（ii）
- **純 cargo test（零 DB、test-first）**：
  - `entity_access_lint` ＋ regression ＋ meta-test。
  - `SoftDeletable::find_active()` **query-shape**：`Entity::find_active().build(DbBackend::Postgres).to_string()` 斷言含 `"deleted_at" IS NULL`（render 不執行、無 DB）。
- **bounded 实机 smoke（`#[ignore]` 整合測試、`DATABASE_URL` 指 `docker compose up -d postgres migrate`、m002 seed）**：
  - `sys_user::find_active_by_name("Super")` 命中；手動 stamp 一列 `deleted_at=now()` 後 `find_active_by_id` 排除它（**證 soft-delete 過濾真生效**）。
  - `sys_user_role::find_role_ids_by_user_id(1)` 非空（Super→R_SUPER）。
  - `sys_role::find_active_by_ids([role_id])` 得 `R_SUPER`（含 `code`）。

## 6. Out of scope / Deferred / Backlog

- **寫路徑＋`model/audit.rs`（`mutate_in_txn`）** → audit 刀（首個寫路徑消費者）。
- **getUserInfo 組裝＋Model→DTO＋`User→User01` alias** → Auth 島 handler（⚠️o handler 層）。
- **其餘 facade/entity**（menu／settings／token／log×3／casbin）→ 各自消費刀（首個消費者紀律）。
- **`DbErr → AppError` From impl** → Auth 島刀（CHECKLIST §3.6 已登）。
- **migration** → 無（`deleted_at` 已在 m001）。

## 7. 驗收方向（交 /speckit-specify 形式化）

- SC：`entity_access_lint` 純 cargo test 綠＋regression 全綠＋**meta-test 證植入違規確實 fail build**。
- SC：`SoftDeletable::find_active()` query-shape 斷言含 `"deleted_at" IS NULL`（純 render、無 DB）。
- SC：bounded 实机 smoke 綠——soft-delete 過濾排除 stamped 列、getUserInfo 三表讀鏈對 m002 seed 命中。
- SC：facade **不 re-export `Entity`**（lint 自驗）＋三 facade 回 `Result<_,DbErr>` raw `Model`。
- SC：**新 `entity` crate ⇒ prod target image build 綠**（Dockerfile COPY 補齊、multi-stage 不退化——CLAUDE.md §3 新 crate 紀律 mandatory）。
- SC：`cargo build` 綠（server 加 sea-orm/entity 後）＋`/health` 不退化。
- SC：殘留 grep——部署層零 rev2、`entity`/`facade`/`soft_delete`/lint 內容零 rev2 token（用「前代」描述）。

## 8. Phase 0 research 待辦（交 /speckit-plan 期 research.md；CLAUDE.md §3 三 grep 紀律）

- **entity Model ↔ m001 schema 對齊 grep**：`sys_user`/`sys_role`/`sys_user_role` 的 `DeriveEntityModel` 逐欄對 m001 DDL（欄名/型/nullable/PK；A 表的 `deleted_at TIMESTAMPTZ` nullable→`Option<DateTimeWithTimeZone>`；join 表 m003 FK 不展開為 sea-orm `Relation`〔空 `Relation` enum、本刀單表 facade〕）。**不信 brainstorm 命名假設、act on m001 actual**。
- **rev2 009 受控參照 grep**：`model/soft_delete.rs`／`model/facade/sys_user.rs`／`tests/entity_access_lint.rs` 真實形（讀允許、拷貝禁止——全新寫）；trait 簽名與 lint 兩相掃描法為參照。
- **facade 返回型對齊**：三 facade fn 真實返回型（raw `Model` vs 過濾形）對齊本檔 §5.4；getUserInfo 消費端（Auth 島）的 UserInfo 形為下游、本刀不定。
- **依賴增量複驗**：server 加 `sea-orm`（workspace 繼承、已在 lock）＋`entity` path dep 後 `cargo build` 綠；確認不引入非預期重依賴（sea-orm 已隨 migration/adapter 編譯過）。
- **新 crate prod build 紀律**：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 必含於 acceptance（dev bind-mount 會遮 Dockerfile COPY 缺口、必 prod target build 才暴露）。

---

**brainstorm 定稿 2026-06-14；拍板（刀界 A 機制+proof／proof set option 3＝sys_user+sys_role+sys_user_role／驗證 ii 純測+bounded 实机 smoke／寫路徑+audit.rs defer audit 刀／無 migration）＋DESIGN §5.1 triple-guard ＋⚠️o/⚠️g 承接。下一步：手動 `/speckit-specify`（input＝本檔）。**
