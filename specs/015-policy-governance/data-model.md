# Phase 1 Data Model: Policy 治理島（授權規則回收桶）

> 接地 pin `7ec8fc3`。**本刀零 migration**——下列 schema 全已存在（`casbin_rule` + `sys_casbin_policy_archive` 在 m001、policy/menu seed 在 m002）；新增者僅 in-memory 解析型（`RestoreOutcome`）、wire DTO（honest）、Redis channel（無 key/表）。

## 1. 既有持久化 schema（零變更、讀寫）

### casbin_rule（archetype D 治理變體、§I.6）— 既有，本刀讀寫
`entity/src/casbin_rule.rs:9-22`：`id:i64` / `ptype:String` / `v0-v5:String` / `protected:bool`(NN、adapter 隱形) / `created_at:DateTimeWithTimeZone`(NN) / `created_by:Option<i64>`。
- 本刀：revoke 改 archive-move（SELECT to-revoke 列 → archive → DELETE）；restore INSERT（自 archive 移回、`created_at` coerce）。

### sys_casbin_policy_archive（archetype D archive 變體、13 欄、`m001:665`）— 既有，本刀首消費
`entity/src/sys_casbin_policy_archive.rs:8-23`：`id:i64` / `ptype:String` / `v0-v5:String` / **`created_at:Option<DateTimeWithTimeZone>`（NULLABLE、`m001:718`）** / `created_by:Option<i64>` / **`archived_at:DateTimeWithTimeZone`（NN、default now）** / `archived_by:Option<i64>` / **`archive_reason:String`（NN、32 char、`m001:738`）**。索引：`archived_at`、`(v0,v2)`。**無 update/delete 欄**（restore＝硬刪移回）。
- ★ **跨表型不對稱**：`archive.created_at:Option` vs `casbin_rule.created_at:NN` → restore 須 `created_at.unwrap_or(now)`。

### sys_role_policy / sys_operation_log — 既有
- endpoint policy seed（`m002:356-358`：getArchivedPolicies/restorePolicy/menu）；op-log（restore 審計、archive-move 審計——經 `mutate_in_txn`）。

## 2. in-memory 解析型（本刀新）

```rust
// model/facade/sys_casbin_policy_archive.rs
enum RestoreOutcome { Applied, NoOp, NotFound }
// restore(conn, archive_id, meta) -> Result<RestoreOutcome, DbErr>:
//   archive 查無               → NotFound
//   live 7-col 已存在(ptype/v0-v5 match) → NoOp（DELETE archive、不 INSERT、不審計）
//   else                       → Applied（INSERT casbin_rule[created_at coerce] + DELETE archive + 審計{role,target,dimension}）
```
- **archive-move（D1）非新純函式**（txn 序列）；由 acceptance（C-V）覆蓋、`tasks.md` 明示「無單元測試、acceptance 覆蓋」。
- restore 三態映對外碼：Applied/NoOp→`0000`、NotFound→`2222`。

## 3. reload gate（PolicyMutated、§4.2 ③）

```
reload_and_publish(state): enforcer.write().load_policy() + redis.publish("casbin:policy:invalidate")  // best-effort, fail-OPEN
gate:
  set_role_dimension Ok(Applied)    → reload_and_publish   // 含空-diff（§4.2「不優化」、調整 011 reload-on-changed）
  set_role_dimension Err(Rejected)  → skip
  restorePolicy Applied             → reload_and_publish
  restorePolicy NoOp / NotFound     → skip
```

## 4. Redis channel（本刀新、無 key/表、守零 migration）

| channel | 型 | 語意 |
|---|---|---|
| `casbin:policy:invalidate` | pub-sub | `reload_and_publish` PUBLISH；`spawn_policy_watcher` SUBSCRIBE → `enforcer.load_policy()`（跨副本收斂、⑤） |

> 全 fail-OPEN：Redis 不可達 → publish best-effort 略過、watcher 30s backoff 重訂閱（本機 reload 已落地、唯一真相 DB）。

## 5. AppState（本刀零擴充）

既有 AppState（`db` / `jwt` / `enforcer:Arc<RwLock<Enforcer>>` / `redis:Arc<Option<RedisHandle>>` / `single_session_default` …、014 已備）**無新欄**。boot 加 `spawn_policy_watcher(redis, enforcer)` task（鏡像 `spawn_settings_watcher`）。

## 6. wire DTO（honest、§I.3 對齊、無新碼）

- **GET `/systemManage/getArchivedPolicies`**（R_SUPER、m002 seed）回 `PageRes<ArchivedPolicy>`：
  `ArchivedPolicy{ id:number, roleCode:string(v0), target:string(v1), dimension:string(v2), archivedTime:string(archived_at), archivedBy:number|null, archiveReason:string, createdTime:string|null }`。
  `SearchParams{ roleCode?, dimension?, current, size }`（`pruneNullParams` 空字串守門）。
- **POST `/systemManage/restorePolicy`**（R_SUPER、m002 seed）`{id:String}`：Applied/NoOp→`0000`、NotFound→`2222`（信封 §7.3）。
- id 型 `number`（§I.3、wire `String(id)`）；無新碼（`0000`/`2222` 凍結 13 碼矩陣）。

## 7. Validation rules（自 FR）

- **FR-1/6**：revoke→archive snapshot+INSERT+DELETE **同 txn**（原子）；`archive_reason` NN 填（`"role_dimension_revoke"`）。
- **FR-3/4**：restore 三態（Applied/NoOp/NotFound）；`created_at` coerce None→now；審計 `{role,target,dimension}`。
- **FR-5**：protected-reject BEFORE 任何寫（011 零回歸）。
- **FR-7**：gate——Applied reload+publish（含空-diff）、Rejected/NoOp/NotFound skip。
- **FR-8**：watcher SUBSCRIBE→`load_policy`（跨副本）；斷線重訂閱；fail-OPEN。
- **FR-9**：endpoint R_SUPER（m002 seed、`require_policy`）。
- **FR-10/SC-7**：`role_menu_loop` 零回歸（teardown +archive 清）；現役授權終態不變。
- **FR-11/SC-8**：zero migration（`git diff migration/` 空；archive 表/seed 全波0）。
