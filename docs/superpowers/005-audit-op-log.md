# 005-audit-op-log — Phase 0 Brainstorm（spec-design）

> 波 0 第五刀（001 infra-deploy → 002 rev2-schema-baseline → 003 envelope → 004 soft-delete-infra → **005 audit-op-log**）。**audit 刀 ×2 之首**（次刀＝overlay：access-log＋login-attempt＋xdb，延到 Auth 島之後）。
> 對應前代 011「op-log 同 txn before/after 審計」。本檔為 brainstorm 定稿的 spec-design，作 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §5.2（mutation→op-log `mutate_in_txn` 同 txn 審計＋operator 取自 `RequestContext.operator_id`）＋§1.5 L4（FACADE 層含 `model/audit.rs`）＋§3.2（`sys_operation_log` archetype B append-only）＋§3.3（義務零 FK、`operator_id` 不驗存在）＋§10.4（審計 trail 原子性）；⚠️g（受控參照前代 source：讀允許、拷貝禁止）為邊界。**衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（引用一律用穩定 §錨、不用揮發行號）。

---

## 1. 目標一句話

把後端「mutation → op-log **同 txn 原子審計**」機制一次立起：`model/audit.rs`（`mutate_in_txn` 泛型 wrapper＋`AuditEvent`/`AuditSerialize`，純資料層、不碰 `entity::`、守 entity_access_lint）＋`facade/sys_operation_log.rs`（append-only 審計 sink）＋**單一寫路徑 proof `sys_user::soft_delete`**（經 mutate_in_txn、redact `password`）——讓後續所有寫端刀站在「業務寫＋審計寫不可分割（同 txn commit／rollback）」之上；機制就位＋一條寫路徑 proof，其餘寫路徑（update/restore/create、其餘表寫側）隨各消費刀逐一加。

## 2. Context（探索蒐集）

### 2.1 前代 011 參考形（受控參照重寫、非照拷——⚠️g）
- **`model/audit.rs`（前代、純資料層）**：`AuditOperation`（Insert/Update/SoftDelete/Restore）＋`as_str()`（→ `"INSERT"`/`"UPDATE"`/`"SOFT_DELETE"`/`"RESTORE"`，operation 欄 DB 字串契約）；`AuditOperator{id, ip}`；`AuditEvent{operation, entity_table, entity_id, payload_before, payload_after, operator, trace_id}`；`AuditSerialize` trait（`audit_json(&self)->Value`、**宣告在 audit.rs、impl 由各 entity facade 提供**、redact 敏感欄）；`mutate_in_txn` 泛型 wrapper（業務寫＋審計寫同 txn）。
- **`facade/sys_operation_log.rs`（前代）**：唯一構造 `entity::sys_operation_log::ActiveModel` 處（lint 豁免）；`write_in_txn(txn, AuditEvent)`——append-only insert（archetype B、無 update/delete）。
- **audit/facade 不在 §I.5 拷貝例外清單**（唯 `sea-orm-adapter`／`xdb`）→ **全新寫**、前代僅作參照（同 envelope/004 形）。
- ⚠️ **xdb 不在本刀**：xdb（client_ip→region）服務 overlay 刀的 `sys_access_log`/`sys_login_attempt` region 欄（§5.9）、隨**第二 audit 刀（前代 015）** 帶入（⚠️v 拍板、注意 Dockerfile [[bench]] COPY 坑）；op-log 軌不需要。

### 2.2 凍結權威
- **DESIGN §5.2**：mutation → `sys_operation_log`：`audit::mutate_in_txn`（`model/audit.rs`）泛型 wrapper **同 txn** 寫 before/after 快照＋operator＋trace；`AuditSerialize` 對敏感欄（password）redact 成 `"<redacted>"`；`audit.rs` 本身不 import entity（守 lint）。**審計軌三 sink（op-log／access-log／login_attempt）縱切兩刀**（後兩 sink 同刀）。
- **DESIGN §1.5 L4 FACADE**：`model/facade/*`（唯一 entity 存取閘）＋同層 `model/soft_delete.rs`（004 落地）＋`model/audit.rs`（`mutate_in_txn`，**本刀做**）。
- **DESIGN §3.2**：三 log append-only（archetype B）——`sys_operation_log`／`sys_access_log`／`sys_login_attempt`、無 update/delete 路徑、facade 只暴露 insert、不可竄改。
- **DESIGN §10.4（＋§5.2）**：操作審計鏈原子性——mutation 必經 `audit::mutate_in_txn`：業務寫＋before/after 快照＋operator＋trace_id **同 txn**；敏感欄經 `AuditSerialize` redact。
- **DESIGN §5.2／§3.3**：operator 寫入時取自 `RequestContext.operator_id`（`Option<i64>`、自 bearer verify 後 claims.user_id 解；無/壞 token→None）；`sys_operation_log.operator_id` 可 null（容忍 system/seed actor、§3.3 義務零 FK）。
- **⚠️g**：前代 source 受控參照（讀允許、拷貝禁止）；audit/facade 全新寫。

### 2.3 rust-api 現況（rev3 004 後——親驗，非 OLD 線）
- workspace members＝`server`／`migration`／`sea-orm-adapter`／**`entity`**（004 建）；**`entity` crate sea-orm features 已含 `with-chrono`＋`with-json`＋`with-ipnetwork`**（004 U1，全早驗綠、time inert 不入圖）。
- **`entity/src/sys_operation_log.rs` 已存在**（004 U2，10 欄機械反射 m001）：`id` i64／`operation` String／`entity_table` String／`entity_id` Option\<i64\>／`payload_before` Option\<Json\>／`payload_after` Option\<Json\>／`operator_id` Option\<i64\>／**`operator_ip` Option\<IpNetwork\>**／`trace_id` Option\<String\>／`created_at` DateTimeWithTimeZone。
- `server/src/model/`（004）＝`mod.rs`（`pub mod facade; pub mod soft_delete;`）＋`soft_delete.rs`（`SoftDeletable` trait minimal）＋`facade/{mod,sys_user,sys_role,sys_menu}.rs`；`server/tests/entity_access_lint.rs`（build-failing 守恆）。
- **`facade/sys_user.rs` 現僅 `impl SoftDeletable`＋`#[cfg(test)] live_tests`**（無 `soft_delete`／`find_active_by_id`）→ 本刀加 `impl AuditSerialize`＋`soft_delete`。
- `server` deps 已含 `sea-orm`(workspace、含 with-ipnetwork via 聯集)＋`serde_json`(003)＋`entity`(path) → **本刀無 Cargo.toml 變動**。
- **m001 已含 `sys_operation_log`**（002 squash 入庫）⇒ **本刀無 migration、無 schema 變動**。
- m002 seed 有 `sys_user`（Super/Admin/User id=1/2/3）⇒ 实机 smoke 有真資料。

### 2.4 消費者（決定 proof 與 facade fn 面）
- **本刀無波 0 真寫側消費者**（Auth 島最小段 login/getUserInfo/enforce 全唯讀）；`sys_user::soft_delete` 為 mutate_in_txn proof（首個真消費者＝波 2 User 刀的刪除端、屆時直接復用此 facade fn）。
- ⇒ 寫路徑本質是 proof＋可復用 facade fn、多建即 dead code（同 004「infra ahead of consumer」）；故 proof set 取**單一 `sys_user::soft_delete`**。

## 3. Scope（拍板）

**本刀做（機制 + 單一寫路徑 proof；全為 `server/src/model/` 新增）：**
- `server/src/model/audit.rs`（新、純）：`AuditOperation`（全 4）／`AuditOperator`／`AuditEvent`／`AuditSerialize` trait＋`mutate_in_txn` 泛型 wrapper（不碰 `entity::`、全新寫 ⚠️g）。
- `server/src/model/facade/sys_operation_log.rs`（新、append-only sink）：`write_in_txn(txn, AuditEvent)`（由 `AuditEvent` 構 `entity::sys_operation_log::ActiveModel` insert；唯一構造處、lint 豁免）。
- `server/src/model/facade/sys_user.rs`（004 既有、加）：`impl AuditSerialize for Model`（redact `password`→`"<redacted>"`）＋`soft_delete(conn, id, operator, trace_id) -> Result<Option<Model>, DbErr>`（包 mutate_in_txn 的單一寫路徑 proof；proof 傳 `trace_id=None`、波2 User 刀復用時傳真值、免簽名 retrofit）。
- `server/src/model/mod.rs` 加 `pub mod audit;`；`facade/mod.rs` 加 `pub mod sys_operation_log;`。

**Deferred（各歸其刀）：**
- **overlay 刀（前代 015）**：`sys_access_log`＋`sys_login_attempt` facade＋`audit_ctx` 全域中介層（`RequestContext` 自動抽取 trace_id/client_ip→region）＋**xdb**＋trusted-proxy XFF 鏈＋**op-log `operator_ip` INET 回填**（本刀 proof 傳 `ip=None`）。
- **operator 自動來源**：bearer verify → `RequestContext.operator_id`/`trace_id` → audit_ctx 刀＋Auth 島；本刀 `mutate_in_txn`/`soft_delete` 收**顯式 `AuditOperator` 參數**。
- **op-log 讀端**（Super-only 查詢端點）→ ⚠️b 波2 殿後刀。
- **其餘寫路徑**（update/create/restore、`sys_role`/`sys_menu`/`system_settings` 寫側）→ User/Role/Menu/settings 刀。
- **`DbErr → AppError` From impl**（供 handler `?` 傳播）→ Auth 島刀（CHECKLIST §3.6 已登）。
- **migration / 新 crate / Cargo.toml 變動**：全無。

## 4. brainstorm 拍板

| # | 決策 | 結論 | 理由 |
|---|---|---|---|
| 刀界 scope | 機制+proof（A）vs 機制+多寫端（B） | **A：mutate_in_txn＋op-log sink＋單一寫路徑 proof** | 同 004「機制先行、消費者隨後」；波0 無真寫側消費者⇒多建 dead code |
| proof set | 單一／+sys_role／+update | **單一 `sys_user::soft_delete`** | mutate_in_txn table-agnostic、一條即證原子性 |
| operator context | 顯式 param vs RequestContext 自動 | **顯式 `AuditOperator` 參數** | auto 抽取屬 audit_ctx 刀＋Auth 島 |
| `AuditOperation` 範圍 | 全 4 vs 只 SoftDelete | **全 4**（本刀只用 SoftDelete、其餘 3＝infra-ahead-of-consumer、benign `never constructed` warning **不抑制**） | `as_str()` 為 operation 欄 DB 字串契約、定義一次免每刀 churn、對齊前代/DESIGN |
| **`AuditOperator.ip` 型（rev3 變數）** | 前代 `Option<String>` → **`Option<IpNetwork>`** | **`Option<IpNetwork>`** | 004 已把 op-log `operator_ip` 建為 `IpNetwork`；String 會留 String→INET 轉換債（違 D1「一次對最終型」＋type-lie）。本刀 proof 傳 `None`、overlay 刀填真 IP。`audit.rs` 用 `sea_orm` 匯出的 `IpNetwork`（非 entity::、守 lint） |
| **entity/migration/with-json（rev3 變數）** | 前代 005 要建 entity＋加 with-json | **全免**（004 已建齊 entity＋with-json）⇒ **無新 crate、無 mandatory prod build、無 Cargo.toml 變動** | rev3 D1「11 entity 一次建齊」之果；本刀比 004 更輕、純 model/ 新增 |
| 驗證策略 | 純 test（i）／+bounded 实机 smoke（ii）／完整實機（iii） | **(ii)**：純測 redact（test-first）＋bounded 实机 smoke（commit＋rollback 原子，compile 證不了的核心） | 同 004 |
| 实机 smoke gating | — | `#[ignore]`＋env-gate DATABASE_URL＋`--test-threads=1`（同 004／[[live-ignore-tests-need-serial]]） | bin-only crate、in-crate `#[cfg(test)]` |

## 5. Design

### 5.1 架構洞察
- **三層職責分離**（守 entity_access_lint）：`model/audit.rs`＝**純資料＋txn 生命週期**（泛型、零 `entity::`、對所有 entity 中立、**不隨新表改**）；`facade/sys_operation_log.rs`＝**唯一構造 op-log entity 之處**（append-only sink）；`facade/sys_user.rs`＝**業務寫路徑＋AuditSerialize**（entity:: 在 facade 內合法）。閉包把 before/after 與 AuditEvent 內容權交給 facade（它做 find+update），`mutate_in_txn` 只管 txn 與呼叫 op-log 寫。
- **原子性是核心交付**：業務 mutation 與 op-log insert 綁同一 `DatabaseTransaction`，commit 一起成功、任一失敗一起回滾——compile/render 證不了、必由实机 rollback smoke 釘死。

### 5.2 結構與檔案
- `server/src/model/audit.rs`（新）：見 §5.3。
- `server/src/model/facade/sys_operation_log.rs`（新）：`write_in_txn(txn, AuditEvent)`。
- `server/src/model/facade/sys_user.rs`（加）：`impl AuditSerialize for Model`＋`soft_delete`。
- `server/src/model/mod.rs` +`pub mod audit;`（並更新檔頭註解：soft_delete 寫已落 proof 於本刀）；`facade/mod.rs` +`pub mod sys_operation_log;`。
- **無 entity／migration／Cargo.toml 變動**。

### 5.3 `model/audit.rs`（全新寫 ⚠️g、不碰 `entity::`）
```rust
pub enum AuditOperation { Insert, Update, SoftDelete, Restore }   // as_str() → DB 字串
pub struct AuditOperator { pub id: i64, pub ip: Option<IpNetwork> }   // IpNetwork 自 sea_orm 匯出
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

pub async fn mutate_in_txn<…, R, F, Fut>(conn, f) -> Result<R, DbErr>
where F: FnOnce(DatabaseTransaction) -> Fut,
      Fut: Future<Output = Result<(DatabaseTransaction, R, Option<AuditEvent>), DbErr>>;
  // begin → f(txn) → if Some(event){ facade::sys_operation_log::write_in_txn(&txn,event) } → commit
  // Ok(..,None)=no-op（查無目標）不寫審計；Err=整 txn 回滾不寫審計
```
- **全 4 `AuditOperation`**：本刀只構造 `SoftDelete`；其餘 3＝infra-ahead-of-consumer、不抑制 warning（同 004/envelope 紀律）。

### 5.4 facade（回 raw `Model`、不 re-export `Entity`）
| facade | fn |
|---|---|
| `facade/sys_operation_log.rs`（新 sink） | `write_in_txn(txn:&DatabaseTransaction, event:AuditEvent)->Result<(),DbErr>`——由 `AuditEvent` 構 `ActiveModel` insert（`operation`=event.operation.as_str()、`operator_id`/`operator_ip` 拆自 event.operator）。唯一 entity:: 構造處 |
| `facade/sys_user.rs`（加） | `impl AuditSerialize for Model`（serialize→override `password`=`"<redacted>"`、其餘保留）／`soft_delete(conn, id:i64, operator:AuditOperator, trace_id:Option<String>)->Result<Option<Model>,DbErr>`（包 mutate_in_txn） |

### 5.5 data flow — `sys_user::soft_delete`（mutate_in_txn proof）
閉包內：`Entity::find_by_id(id).one(&txn)`（before；entity:: 在 facade 合法）→ 查無回 `(txn, None, None)`（no-op、不寫審計）→ 查有則 `ActiveModel{ deleted_at:Set(Some(now)), ..before.clone().into() }.update(&txn)`（after）→ 建 `AuditEvent{ SoftDelete, "sys_user", Some(id), Some(before.audit_json()), Some(after.audit_json()), Some(operator), trace_id }` → 回 `(txn, Some(after), Some(event))`。

### 5.6 error handling
- `mutate_in_txn`/facade fn 回 `Result<_, DbErr>`；本刀**不**加 `DbErr→AppError`（Auth 刀帶入、§3.6）⇒ 無 handler、無 endpoint、不接信封。
- no-op（find 查無）≠ error：回 `Ok(None)`、不寫審計、txn commit（無副作用）。
- 任一 DB 失敗 → `Err(DbErr)` → mutate_in_txn 整 txn rollback（業務寫＋op-log 寫一起不留）。

### 5.7 testing / 驗證（C-V）
- **C-V-0 build**：容器內 `cargo build -p server` 綠（mod audit＋facade＋AuditSerialize 編譯）。
- **C-V-1 redact 純測**（test-first、無 DB）：sys_user `Model{password:"secret",..}.audit_json()` → 斷言 `["password"]=="<redacted>"`、其餘欄保留（如 user_name 原值）。
- **C-V-2 atomicity live smoke**（`#[ignore]`、DATABASE_URL via `$(cat /run/secrets/database_url)`、`--test-threads=1`）：核心＝**業務寫＋op-log 寫同 txn 原子**——
  - commit 路徑：`sys_user::soft_delete(Super)` → op-log 同 txn 寫入一列（`operation=SOFT_DELETE`/`entity_table=sys_user`/`entity_id=1`/`payload_before.password=<redacted>`/`payload_after.deleted_at` 非空/`operator_id`）。
  - rollback 路徑：注入失敗 → 業務 deleted_at 與 op-log 列**一起不留**（原子釘死）。
  - **不污染 002 seed**：smoke 須 txn 隔離（mechanism 見 §6 research）。
- **C-V-3 lint 守恆**：`cargo test -p server --test entity_access_lint` 綠（`audit.rs` 無 path-root `entity::`；facade 內 entity:: 豁免）。
- 無 mandatory prod build（無新 crate）。

## 6. Phase 0 research 待辦（移交 `/speckit-plan`）
- **R-A `mutate_in_txn` 簽名 ＋ live smoke 不污染 seed 機制**：grep sea-orm txn/savepoint API——`mutate_in_txn` 內部 `begin→commit`，smoke 端如何隔離不污染（候選：(a) 簽名泛型 `C: ConnectionTrait+TransactionTrait`、smoke 開外層 txn 傳入→savepoint、外層 rollback；(b) commit 後 cleanup；(c) temp user）。定 `conn` 型（`&DatabaseConnection` vs 泛型）。
- **R-B `IpNetwork` import 路徑**：grep `audit.rs` 能否 `use sea_orm::…::IpNetwork`（with-ipnetwork 經 workspace feature 聯集；同 004 entity 解法）；確認非 entity:: 路徑、守 lint。
- **R-C `AuditSerialize` redact 機制**：serde_json serialize Model 後 override `password` vs 手構 Value；確認 sys_user Model `Serialize` 可用（DeriveEntityModel Model 是否 derive Serialize——grep；若否，facade 手構 audit_json）。
- **R-D `before.clone().into()` ActiveModel 形**：grep sea-orm `Model::into ActiveModel` / `IntoActiveModel`，確認 update 形（保留 before 欄、只改 deleted_at）。
- **三-grep 紀律**：facade/entity 返回型（sys_operation_log Model 已親驗 §2.3）／wire 對齊 N/A（無 endpoint）／命名對照（m001 op-log 欄已親驗）。
- **CDP defer**：N/A（無 UI/endpoint；唯一活體＝atomicity live smoke、非 CDP）。

## 7. 風險 / 注意
- **lint 守恆**：`audit.rs` 一旦誤帶 `entity::`（如 import op-log Model 型）即破 lint——`AuditEvent` 用 `serde_json::Value`/`IpNetwork`（sea_orm）等中立型、不碰 entity；op-log 構造全在 facade。
- **原子性偽證**：smoke 若只測 commit 路徑＝vacuous——**必含 rollback 路徑**（注入失敗驗業務+審計一起不留）。
- **seed 污染**：mutate_in_txn 內部 commit，smoke 不隔離會持久軟刪 Super＋留 op-log 列（見 §6 R-A）。
- **operator_ip 型**：本刀 `AuditOperator.ip=Option<IpNetwork>` 傳 `None`；overlay 刀填真 IP（避免 retrofit，§4 決策）。
- **無回歸**：本刀無 endpoint/router 改動 → `/health` 零回歸（同 004 SC-007）。
</content>
