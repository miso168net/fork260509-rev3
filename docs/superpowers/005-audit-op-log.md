# 005-audit-op-log — Phase 0 Brainstorm（spec-design）

> 波 0 第五刀（001 infra-deploy → 002 rev2-schema-baseline → 003 envelope → 004 soft-delete-infra → **005 audit-op-log**）。audit 刀 ×2 之首。
> 對應 rev2 011「op-log 同 txn before/after 審計」。本檔為 brainstorm 定稿的 spec-design，作為 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §5.2（mutation→op-log `mutate_in_txn` 同 txn 審計）＋§1.5 L4（FACADE 層含 `model/audit.rs`）＋§3.2（`sys_operation_log` archetype B append-only）為設計本體；⚠️g（受控參照 rev2 source 讀允許拷貝禁止）為邊界。本檔不得與之衝突（衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔）。

---

## 1. 目標一句話

把後端「mutation → op-log **同 txn 原子審計**」的機制一次立起：`model/audit.rs`（`mutate_in_txn` 泛型 wrapper＋`AuditEvent`/`AuditSerialize`，純資料層、不碰 `entity::`、守 lint ③）＋`sys_operation_log` entity/facade（append-only 審計 sink）＋**單一寫路徑 proof `sys_user::soft_delete`**（經 mutate_in_txn、redact `password`）——讓後續所有寫端刀都站在「業務寫＋審計寫不可分割（同 txn commit／rollback）」的前提上；機制就位＋一條寫路徑 proof，其餘寫路徑（update/restore/create、其餘表寫側）隨各自消費刀逐一加。

## 2. Context（探索蒐集）

### 2.1 rev2 011 參考形（受控參照重寫、非照拷——⚠️g）
- **`model/audit.rs`（rev2、89 行、純資料層）**：
  - `AuditOperation`（`Insert`/`Update`/`SoftDelete`/`Restore`）＋`as_str()`（→ `"INSERT"`/`"UPDATE"`/`"SOFT_DELETE"`/`"RESTORE"`，operation 欄 DB 字串契約）。
  - `AuditOperator { id: i64, ip: Option<String> }`。
  - `AuditEvent { operation, entity_table: String, entity_id: Option<i64>, payload_before: Option<serde_json::Value>, payload_after: Option<serde_json::Value>, operator: Option<AuditOperator>, trace_id: Option<String> }`。
  - `AuditSerialize` trait（`fn audit_json(&self) -> serde_json::Value`）——**宣告在 audit.rs、impl 由各 entity facade 提供**（redact 敏感欄）。
  - **`mutate_in_txn<R, F, Fut>(db, f) -> Result<R, DbErr>`**：`F: FnOnce(DatabaseTransaction) -> Fut`、`Fut::Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>`。閉包收 txn（by value）、在同 txn 做 SELECT(before)+UPDATE(after)+建 `AuditEvent`、回 `(txn, result, Option<event>)`；wrapper `begin → f → if Some(event){facade::sys_operation_log::write_in_txn(&txn, event)} → commit`。**業務寫＋審計寫同一 txn**；`Ok(...,None)`＝no-op（查無目標、不寫審計）、`Err`＝整 txn 回滾不寫審計。`audit.rs` **不含任何 `entity::` 路徑**（守 lint ③）。
- **`facade/sys_operation_log.rs`（rev2）**：唯一能構造 `entity::sys_operation_log::ActiveModel` 之處（lint 豁免）；`write_in_txn(txn, AuditEvent)`——append-only insert（archetype B、無 update/delete 路徑）。
- **rev2 011 = 「立 audit 機制 + 隨首個寫端套用」**；rev3 005 取機制＋單一 proof，**只讀側 rev2 形、code 全新寫**（⚠️g；audit/facade 不在 §I.5 拷貝例外清單〔唯 sea-orm-adapter／xdb〕）。
- ⚠️ **xdb 不在本刀**：xdb（client_ip→region）服務 `sys_access_log` 的 region 欄（§5.9）、隨**第二 audit 刀（rev2 015）** 拷入（⚠️v 拍板、注意 Dockerfile [[bench]] COPY 坑）；op-log 軌不需要。

### 2.2 凍結權威
- **DESIGN §5.2**：mutation → `sys_operation_log`：`audit::mutate_in_txn`（`model/audit.rs`）泛型 wrapper **同 txn** 寫 before/after 快照＋operator＋trace；`AuditSerialize` 對敏感欄（password）redact 成 `"<redacted>"`；`audit.rs` 本身不 import entity（守 lint）。**HTTP/region 軌另走 `sys_access_log`（audit_ctx 中介層＋xdb）——audit 軌三 sink（op-log／access-log／login_attempt）縱切兩刀**（後兩 sink 同刀）。
- **DESIGN §1.5 L4 FACADE 層**：`model/facade/*`（唯一 entity 存取閘）＋同層 `model/soft_delete.rs`（004 落地）＋`model/audit.rs`（`mutate_in_txn`，**本刀做**）。
- **DESIGN §3.2 / line 703**：三 log append-only（archetype B）——`sys_operation_log`／`sys_access_log`／`sys_login_attempt`，無 update/delete 路徑、facade 只暴露 insert（各表僅此一個 pub fn）、不可竄改。
- **DESIGN line 704**：操作審計鏈原子性——mutation 必經 `audit::mutate_in_txn`：業務寫＋before/after 快照＋operator＋trace_id **同 txn**；敏感欄經 `AuditSerialize` redact。
- **DESIGN line 197**：operator/actor 寫入時取自 `RequestContext.operator_id`（`Option<i64>`，自 bearer verify 後 claims.user_id 解；無/壞 token → None）。`sys_operation_log.operator_id` 可 null（容忍 system/seed actor、不驗存在；§3.3 義務零 FK）。
- **⚠️g**：rev2 source 受控參照（讀允許拷貝禁止）；audit/facade 全新寫，rev2 僅作參照（同 envelope/004 形）。

### 2.3 rust-api 現況（004 後）
- workspace members＝`server`/`migration`/`sea-orm-adapter`/**`entity`**（004 新建）；`entity` crate sea-orm 已啟 `with-chrono`（004、time 不入圖）。
- `server/src/model/`（004 落地）＝`mod.rs`（`pub mod soft_delete; pub mod facade;`）＋`soft_delete.rs`（`SoftDeletable` trait minimal）＋`facade/{mod,sys_user,sys_role,sys_user_role,live_smoke}.rs`；`server/tests/entity_access_lint.rs`（build-failing 守恆 ③）。
- `facade/sys_user.rs` 已有 `impl SoftDeletable`＋`find_active`＋`find_active_by_name`/`find_active_by_id`（004 讀側）——本刀**復用 `find_active_by_id` 驗 soft-delete 生效**。
- **m001 已含 `sys_operation_log`（10 欄）**（002 squash 入庫）⇒ **本刀無 migration、無 schema 變動**（與 rev2 011 關鍵差異：rev2 011 含建表 migration）。
- m002 seed 有 `sys_user`（Super/Admin/User）⇒ 实机 smoke 有真資料（soft_delete Super 後驗）。

### 2.4 消費者（決定 proof 與 facade fn 面）
- **本刀無波 0 真寫側消費者**（Auth 島最小段 login/getUserInfo/enforce 全唯讀）；`sys_user::soft_delete` 純為 proof（首個真消費者＝波 2 User 刀的刪除端）。
- ⇒ 寫路徑本質是 proof、多建即 dead code（同 004 facade「infra ahead of consumer」）；故 proof set 取**單一 `sys_user::soft_delete`**。

## 3. Scope（拍板）

**本刀做（機制 + 單一寫路徑 proof）：**
- `entity/src/sys_operation_log.rs`（**擴現有 entity crate**、`DeriveEntityModel` 逐欄鏡像 m001 10 欄；含 JSONB `payload_before/after` ⇒ **entity crate sea-orm 加 `with-json` feature**〔同 004 with-chrono gotcha、§3.7 已預言〕）＋`entity/src/lib.rs` 加 `pub mod sys_operation_log;`。
- `model/audit.rs`：`AuditOperation`（**全 4**）／`AuditOperator`／`AuditEvent`／`AuditSerialize` trait＋`mutate_in_txn` 泛型 wrapper（純、不碰 `entity::`、全新寫⚠️g）。
- `model/facade/sys_operation_log.rs`：`write_in_txn(txn, AuditEvent)`（append-only、唯一構造 ActiveModel 處、lint 豁免）。
- `model/facade/sys_user.rs` 加：`impl AuditSerialize for Model`（redact `password`→`"<redacted>"`）＋`soft_delete(db, id, AuditOperator) -> Result<Option<Model>, DbErr>`（包 mutate_in_txn 的單一寫路徑 proof）。
- `model/mod.rs` 加 `pub mod audit;`；`facade/mod.rs` 加 `pub mod sys_operation_log;`。
- 依賴/接線（entity crate sea-orm +`with-json`；audit.rs／facade 用 `serde_json`）＋驗證（純測 redact ＋ bounded 实机 smoke commit/rollback）。

**Deferred（不在本刀）：**
- **第二 audit 刀（rev2 015）**：`sys_access_log`＋`sys_login_attempt` entity/facade＋`audit_ctx` 全域中介層（`RequestContext` 自動抽取）＋**xdb**（client_ip→region）。
- **operator 自動來源**：bearer verify → `RequestContext.operator_id`/`trace_id` → audit_ctx 刀＋Auth 島；本刀 `mutate_in_txn`／`soft_delete` 收**顯式 `AuditOperator` 參數**（proof 傳合成 operator）。
- **op-log 讀端**（Super-only 查詢端點、DESIGN line 281 標 ⚠️「rev3 補、rev2 無」）→ Auth 島/波2（需 enforce＋handler＋讀索引）。
- **其餘寫路徑**（`update_*`/`restore`/`create`、`sys_role`/`sys_menu`/`system_settings` 寫側）→ User/Role/Menu/settings 刀（各自首個消費者）。
- **`DbErr → AppError` From impl**（供 handler `?` 傳播）→ Auth 島刀（CHECKLIST §3.6 已登）。
- **migration**：無（`sys_operation_log` 已在 m001）。

## 4. brainstorm 拍板

| # | 決策 | options | 結論 |
|---|---|---|---|
| 刀界 scope | 機制+proof（A）vs 機制+多寫端（B） | A（同 004 envelope「機制先行、消費者隨後」） | **A：`mutate_in_txn`＋op-log sink＋單一寫路徑 proof** |
| proof set | 單一 sys_user::soft_delete / +sys_role / +update | 單一（user 拍板） | **單一 `sys_user::soft_delete`**（mutate_in_txn table-agnostic、一條即證；無波0 真消費者⇒多建 dead code） |
| operator context | 顯式 param vs RequestContext 自動抽取 | 顯式（RequestContext 屬第二刀） | **顯式 `AuditOperator{id,ip}` 參數**（auto 抽取 defer audit_ctx 刀＋Auth 島） |
| `AuditOperation` 範圍 | 全 4（Insert/Update/SoftDelete/Restore）vs 只 SoftDelete | 全 4（user 拍板） | **全 4**（封閉小詞彙、`as_str()` 為 operation 欄 DB 契約、定義一次免每刀 churn、對齊 rev2/DESIGN；本刀只用 SoftDelete、其餘 3 種＝infra-ahead-of-consumer〔同 envelope 保留碼〕） |
| 驗證策略 | 純 cargo test（i） / **+bounded 实机 smoke（ii）** / 完整实機（iii） | ii（同 004） | **(ii)**：純測（`AuditSerialize` redact，test-first）＋ bounded 实机 smoke（**commit＋rollback 原子**，compile/render 證不了的核心） |
| migration / 新 crate | — | — | **無 migration**（在 m001）；**擴現有 entity crate**（非新 crate）⇒ **無 mandatory prod build**（異於 004；但 +`with-json` 仍跑 C-V build 驗） |
| 实机 smoke gating | — | — | `#[ignore]` 整合測試（`src/` cfg(test)、bin-only crate）＋`postgres+migrate`；`cargo test -- --ignored` 起 DB 才跑（同 004） |

## 5. Design

### 5.1 架構洞察
- **三層職責分離**（守 lint ③）：`model/audit.rs`＝**純資料＋txn 生命週期**（泛型、零 `entity::`）；`facade/sys_operation_log.rs`＝**唯一構造 op-log entity 之處**（append-only sink）；`facade/sys_user.rs`＝**業務寫路徑＋AuditSerialize**（entity:: 在 facade 內合法）。閉包把 before/after 與 AuditEvent 內容權交給 facade（它做 SELECT+UPDATE），`mutate_in_txn` 只管 txn 與呼叫 op-log 寫——**audit.rs 對所有 entity 中立、不需隨新表改**。
- **原子性是核心交付**：業務 mutation 與 op-log insert 綁同一 `DatabaseTransaction`，commit 一起成功、任一失敗一起回滾。這是 compile/render 證不了、必由实机 rollback smoke 釘死的點。

### 5.2 結構與檔案
- **`entity/src/sys_operation_log.rs`**（擴 entity crate、archetype B）：`DeriveEntityModel` 逐欄鏡像 m001 10 欄（`id` i64 PK／`operation` String／`entity_table` String／`entity_id` Option\<i64\>／`payload_before` Option\<Json\>／`payload_after` Option\<Json\>／`operator_id` Option\<i64\>／`operator_ip` Option\<String\>〔INET、型待 grep〕／`trace_id` Option\<String\>／`created_at` DateTimeWithTimeZone）；空 `Relation`（不展開 FK、append-only 無關聯需求）。`entity/src/lib.rs` 加 `pub mod sys_operation_log;`。
- **`entity/Cargo.toml`**：sea-orm features `["with-chrono"]` → `["with-chrono", "with-json"]`（JSONB 欄需 with-json；同 with-chrono 政策、chrono/serde_json 應已在 lock⟨002/003⟩、無新外部 crate——待 grep 確認）。
- **`server/src/model/audit.rs`**（新、純）：`AuditOperation`／`AuditOperator`／`AuditEvent`／`AuditSerialize` trait＋`mutate_in_txn`（簽名見 §5.3）。
- **`server/src/model/facade/sys_operation_log.rs`**（新）：`write_in_txn(txn, AuditEvent)`。
- **`server/src/model/facade/sys_user.rs`**（004 既有、加 fn）：`impl AuditSerialize for Model`＋`soft_delete`。
- **`server/src/model/mod.rs`**：加 `pub mod audit;`；**`facade/mod.rs`**：加 `pub mod sys_operation_log;`。
- **`server/Cargo.toml`**：確認 `serde_json`（003 已有）；audit.rs 用 `serde_json::Value`。
- **無 migration、無新 crate**。

### 5.3 `model/audit.rs`（全新寫⚠️g、不碰 `entity::`）
```rust
pub enum AuditOperation { Insert, Update, SoftDelete, Restore }   // as_str() → DB 字串
pub struct AuditOperator { pub id: i64, pub ip: Option<String> }
pub struct AuditEvent {
    pub operation: AuditOperation,
    pub entity_table: String,
    pub entity_id: Option<i64>,
    pub payload_before: Option<serde_json::Value>,
    pub payload_after: Option<serde_json::Value>,
    pub operator: Option<AuditOperator>,
    pub trace_id: Option<String>,
}
pub trait AuditSerialize { fn audit_json(&self) -> serde_json::Value; }   // impl 在各 facade

pub async fn mutate_in_txn<R, F, Fut>(db: &DatabaseConnection, f: F) -> Result<R, DbErr>
where
    F: FnOnce(DatabaseTransaction) -> Fut,
    Fut: Future<Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>>,
{ /* begin → f → if Some(event){facade::sys_operation_log::write_in_txn(&txn,event)} → commit */ }
```
- **全 4 `AuditOperation`**：本刀只構造 `SoftDelete`；`Insert`/`Update`/`Restore` 為 infra-ahead-of-consumer（`never constructed` warning、benign、隨消費刀漸用、**不抑制**——同 004/envelope 紀律）。

### 5.4 facade（guard ②／③；回 raw `Model`、不 re-export `Entity`）
| facade | fn |
|---|---|
| `facade/sys_operation_log.rs`（新、append-only sink） | `write_in_txn(txn: &DatabaseTransaction, event: AuditEvent) -> Result<(), DbErr>`（由 `AuditEvent` 構 `ActiveModel` insert；唯一 entity:: 構造處） |
| `facade/sys_user.rs`（加） | `impl AuditSerialize for Model`（`audit_json()` redact `password`→`"<redacted>"`、其餘欄保留）／`soft_delete(db, id: i64, operator: AuditOperator) -> Result<Option<Model>, DbErr>` |

- **`sys_user::soft_delete` 流程**（包 mutate_in_txn）：閉包內 `Entity::find_by_id(id).one(&txn)`（before；entity:: 在 facade 合法）→ 查無回 `(txn, None, None)`（no-op、不寫審計）→ 查有則 `ActiveModel { deleted_at: Set(Some(now)), ..before.into() }.update(&txn)`（after）→ 建 `AuditEvent{ SoftDelete, "sys_user", Some(id), Some(before.audit_json()), Some(after.audit_json()), Some(operator), trace_id }` → 回 `(txn, Some(after), Some(event))`。
- facade 回 `sea_orm::DbErr`（原生）、**不碰 envelope/AppError**（FR-009 同 004）。

### 5.5 `entity_access_lint`（守恆 ③、004 已立）
- `audit.rs` 純泛型、**不 import entity**（守 ③）；新 `facade/sys_operation_log.rs` 在 `src/model/facade/` 下、path-豁免 ⇒ `no_raw_entity_outside_facade` 仍綠。本刀**不改 lint**、只新增受其守護的 facade。

### 5.6 驗證（ii）
- **純 cargo test（零 DB、test-first）**：
  - `AuditSerialize for sys_user::Model`：建一 Model（含 `password`）→ `audit_json()` 斷言 `password == "<redacted>"`、`user_name` 等非敏感欄在。（red→green：先寫測、後 impl redact）
  - （可選）`AuditOperation::as_str()` 4 種對映斷言（DB 字串契約）。
- **bounded 实机 smoke（`#[ignore]`、`src/` cfg(test)、`postgres+migrate` m002 seed）**：
  - **① commit 原子**：`sys_user::soft_delete(db, super_id, operator{id:1})` → (a) `find_active_by_id(super_id)` 回 `None`（**復用 004 facade**、證 soft-del 生效）；(b) 查 `sys_operation_log` 有一列 `operation="SOFT_DELETE"`／`entity_table="sys_user"`／`entity_id=super_id`／`operator_id=1`／`payload_before` 內 `password=="<redacted>"`（**redact 真落 DB**）。
  - **② rollback 原子**：以「閉包 UPDATE 後回 `Err`」變體呼 mutate_in_txn → 斷言 Super **未**軟刪（`find_active_by_id` 仍命中）＋`sys_operation_log` **無**新列（證業務寫＋審計寫同生同滅）。
  - **teardown**：還原 seed（un-stamp Super `deleted_at=NULL`、刪測試 op-log 列），或用拋棄式 user。
- **C-V build**：`cargo build`/`cargo test -p server`（+with-json 後 entity 編譯綠、lint 綠）；雖非新 crate，仍跑一次 `docker compose ... prod build rust-api` 確認 with-json 不破壞 release（保險、非 mandatory）。

## 6. Out of scope / Deferred / Backlog

- **第二 audit 刀（rev2 015）**：access-log＋login-attempt＋xdb＋audit_ctx 中介層。
- **operator 自動來源**（bearer→RequestContext）＋op-log 讀端 → Auth 島/波2。
- **其餘寫路徑**（update/restore/create、其餘表寫側）→ 各自消費刀。
- **`DbErr→AppError` From** → Auth 島刀（§3.6）。
- **migration** → 無。

## 7. 驗收方向（交 /speckit-specify 形式化）

- SC：`AuditSerialize` redact 純測綠——`sys_user` audit_json `password=="<redacted>"`、非敏感欄保留（test-first）。
- SC：bounded 实机 smoke 綠——**commit 原子**（soft_delete → soft-del 生效＋op-log 列正確含 redacted before）＋**rollback 原子**（閉包 Err → 業務寫＋審計寫皆零）。
- SC：`mutate_in_txn` 業務寫與 op-log 寫同一 txn（rollback smoke 為其證）。
- SC：`audit.rs` 零 `entity::`（守 ③）＋`entity_access_lint` 仍綠（facade 外無 root-level entity::）。
- SC：facade 回 raw `Model`/`DbErr`、不 re-export `Entity`、不映射 envelope。
- SC：`cargo build`/`cargo test -p server` 綠（entity +with-json 後）＋`/health` 不退化。
- SC：殘留 grep——部署層零前代 token、`entity`/`facade`/`audit.rs` 內容零 rev2 token（用「前代」描述）。

## 8. Phase 0 research 待辦（交 /speckit-plan 期 research.md；CLAUDE.md §3 三 grep 紀律）

- **m001 `sys_operation_log` 10 欄逐欄對齊 grep**（`migration/src/m001_rev2_schema.rs` SysOperationLog enum :129-142／create :485-544）：`DeriveEntityModel` 逐欄對 DDL（欄名/型/nullable/PK）。**不信本檔命名假設、act on m001 actual**。
- **★ sea-orm `with-json` feature 確認**：`payload_before/after` 為 `json_binary`（JSONB）⇒ Model 用 `serde_json::Value`／`sea_orm::JsonValue` 需 `with-json`（同 004 `with-chrono` gotcha、§3.7 follow-up 已預言）；entity crate sea-orm features 加 `with-json`；確認 serde_json 已在 Cargo.lock（003/sea-orm 引入）、**無新外部 crate 下載**。
- **★ INET 欄型確認**：`operator_ip` 為 m001 `.custom(Alias::new("INET"))` ⇒ sea-orm Model 型（`Option<String>`? 對齊 rev2 sys_operation_log Model 實際）——grep rev2 `entity::sys_operation_log` Model 的 `operator_ip` 型。
- **rev2 011 受控參照 grep**（讀允許拷貝禁止、全新寫）：`model/audit.rs`（`mutate_in_txn` 簽名、AuditEvent/AuditSerialize 形）／`facade/sys_operation_log.rs`（`write_in_txn` 由 AuditEvent 構 ActiveModel）／`facade/sys_user.rs`（`soft_delete` 閉包 before/after capture＋`impl AuditSerialize` redact）。
- **依賴增量複驗**：entity crate +`with-json`、server/audit.rs 用 `serde_json` 後 `cargo build` 綠；確認不引入非預期重依賴。
- **rollback smoke 形 grep**：rev2 是否有 mutate_in_txn rollback 測（`#[ignore]` live）作參照形；無則本刀自設（閉包回 Err 變體）。

---

**brainstorm 定稿 2026-06-14；拍板（刀界 A 機制+proof／proof 單一 `sys_user::soft_delete`／operator 顯式 param／`AuditOperation` 全 4／驗證 ii commit+rollback／無 migration／擴 entity crate +with-json）＋DESIGN §5.2 同 txn 審計 ＋⚠️g 承接。下一步：手動 `/speckit-specify`（input＝本檔）。**
