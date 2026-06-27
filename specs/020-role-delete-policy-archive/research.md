# Phase 0 Research: 020-role-delete-policy-archive

**Branch**: `020-role-delete-policy-archive` | **Date**: 2026-06-27 | 接地自 Phase 0 act-on-code 研究（4 線 Workflow，as-built 為準）

> 固化 brainstorm §8「研究待固化」+ Q1（FR-012）的實作接地。所有 file:line 為 worktree as-built。

---

## D1 — 原子整合姿態：extend `soft_delete` / `batch_soft_delete`（Option a）

- **Decision**：在 `sys_role::soft_delete` / `batch_soft_delete` 既有 `mutate_in_txn` closure 內，於設 `deleted_at/by` 後、return 前，呼叫新 casbin-archive helper（同 txn）。簽名擴充傳入 `role_code`（soft_delete 目前只收 `id`；需先 load 到 code，或 caller 傳）。
- **Rationale**：facade 已是 `<C: TransactionTrait>` 泛型、closure 已擁有該 txn；archive 是 role 軟刪的 side-effect、共用同一交易即天然原子（FR-003）；op-log 仍每角色一筆 SoftDelete。
- **Alternatives**：(b) 新協調 facade 開 `mutate_in_txn` 同做兩者 → 需複製 soft_delete 內部、較繁；(c) handler 開 txn 呼兩 facade（`soft_delete<C>` 可收 `&txn`）→ 可行但把交易範圍責任上移 handler、破封裝。**選 (a)**。
- **接地**：`soft_delete` `rust-api/server/src/model/facade/sys_role.rs:302-338`（closure→`(txn, Option<Model>, Option<AuditEvent>)`）；`batch_soft_delete:344-383`（**單一 txn 迴圈全 ids**、per-id SoftDelete op-log）；`mutate_in_txn` `model/audit.rs:84-97`；handler `delete_role:1208-1234`（守門 seeded/in-use/self **後**才 soft_delete）／`batch_delete_role:1239-1267`（Phase1 全守門→Phase2 batch_soft_delete）。

## D2 — 新 facade helper `archive_all_role_policies`（復用 `insert_archived`）

- **Decision**：`sys_casbin_rule`（或 `sys_casbin_policy_archive`）新增 `archive_all_role_policies(txn, role_code, operator_id) -> Result<usize, DbErr>`：讀 `casbin_rule WHERE ptype='p' AND v0=role_code`（**全 v2 維度**、含 protected）→ `sys_casbin_policy_archive::insert_archived(txn, &rows, Some(op_id), "role_soft_delete")` → `casbin_rule::delete_many` 同條件 → 回 archived 列數。
- **Rationale**：`set_role_dimension` 既有 archive-move 範本只讀 per-`(v0,v2)`；角色刪除需 **全維度** v0=code，故需新 helper（讀無 v2 filter）；`insert_archived` 直接復用、只換 reason。`entity_access_lint` 要求 casbin entity 存取走 facade → helper 落 facade。
- **接地**：`insert_archived` `sys_casbin_policy_archive.rs:32-37`＝`(txn:&DatabaseTransaction, rows:&[casbin_rule::Model], archived_by:Option<i64>, reason:&str) -> Result<(),DbErr>`；`set_role_dimension` archive-move 範本 `sys_casbin_rule.rs:51+`（read current→insert_archived→delete_many 同 txn）。casbin 現況：僅 `ptype='p'`、無 g-policy、0 孤兒。

## D3 — reload + publish：復用 `reload_and_publish(&state)`

- **Decision**：`delete_role` / `batch_delete_role` 在 txn commit **後**、若 archived 總數 > 0 → `reload_and_publish(&state).await?`（本地 enforcer reload ＋ best-effort PUBLISH `casbin:policy:invalidate`、跨副本 watcher 收斂）；archived==0 則 skip（§I.7 §4.2 PolicyMutated gate）。
- **接地**：`reload_and_publish` `handler/system_manage.rs:874`（pub(crate)、收 `&AppState`）；channel const `main.rs:41`；enforce `auth/enforce.rs:69 reload_enforcer_preserving`；watcher `main.rs:694+`。restorePolicy Applied 亦走此（`system_manage.rs:1906`）＝既有範式。

## D4 — ★ FR-005 + FR-012 restorability：`created_at` 衍生判定（零 mutation、零 migration）

> 本刀最關鍵設計點。FR-012（Q1 拍板「完整封閉 restore-path」）撞 constitution §I.6 archetype D（archive＝insert＋restore 硬刪移回、**不 mutate**）。

- **Decision**：**不**在刪除時 mutate 任何 archive 列；改以**讀時衍生** `restorable`（**denylist 形、C3 校正**）：
  > `restorable(row)` = `row.archive_reason != "role_soft_delete"` **AND** `∃ active sys_role（code = row.v0）其 created_at < row.archived_at`
  - 撤銷類列（`role_soft_delete` 以外）且其 code 當前對應的 active 角色實例「早於該歸檔」→ 可復原（屬當前角色實例的撤銷）。
  - 角色已刪（無 active 角色）→ 不可復原；重用同 code（新角色 created_at 晚於舊歸檔）→ 不可復原（屬舊角色實例）。
  - `role_soft_delete` 列 → 永不可復原（denylist；亦由 created_at 檢查獨立成立——其 archived_at=刪除時刻、重用後新角色 created_at 必晚之）。
- **★ C3 reason-set 接地校正**：實際 codebase 只發出 **2** 種撤銷 reason —— `role_dimension_revoke`（menu **與 button**：016 button reuse `set_role_dimension`，`sys_casbin_rule.rs:125`）／`role_endpoint_revoke`（endpoint：`set_role_endpoints`，`sys_casbin_rule.rs:343`）。**`role_button_revoke` 全 codebase 不存在**（原假設誤）。採 denylist `!= role_soft_delete` 即免列舉撤銷 reason、未來新增撤銷 reason 自動正確、且消 C3 風險。
- **★ C2=A 時鐘假設（user 拍板 A、明記）**：唯一角色實例判別子＝`created_at < archived_at`（皆 `Utc::now()`）。**假設 delete→recreate 之間時鐘單調**；archive 列存 `v0=code` **不存 `role_id`** → 無序列 tiebreak（除非動 schema、本刀不做）。極窄風險窗：NTP 向後跳錶 > delete→recreate 間隔 **且** 同時有人工復原舊撤銷列才中（spec Assumptions 已記）。同-µs `created_at==archived_at` strict `<` errs **closed**（安全向）。
- **★ C1 並發安全（見 D9）**：本衍生 + 刪除路徑須在 `sys_role` 列鎖下重判（lock-then-redecide），否則 restore-during-delete TOCTOU 可留 orphan live 授權。
- **此規則同時滿足 FR-005（role_soft_delete 不可復原）與 FR-012（既有撤銷列於角色刪除/重用後不可復原）——刪除時【無需】mutate 既有列**（衍生自然成立：刪後無 active 角色、重用後 created_at 不符）。
- **Rationale**：(1) 完全遵守 §I.6 archetype D——archive 列維持 write-once（只 insert／restore-硬刪），無 in-place UPDATE；(2) 零 migration（用既有 `sys_role.created_at` + `archive.archived_at`）；(3) forensically honest——不竄改既有撤銷列的 reason；(4) 把 FR-005+FR-012 統一為單一可測規則。
- **Alternatives（已評估、否決）**：
  - **(i) 刪除時 UPDATE 既有列 archive_reason→非撤銷值**：零 migration 但**對 archive 列 in-place mutation**＝§I.6 archetype D「insert+硬刪」模型外的新操作（archive_reason 雖非審計欄、但 archetype 隱含 write-once）＋竄改原 reason 喪失 forensic。否決。
  - **(ii) 加 `restorable`/`superseded_at` 欄**：需 migration＋改 archetype D 欄集＝違 brainstorm「零 migration」＋ §I.6 凍結。否決。
  - **(iv) role_soft_delete watermark + 「同 code 有更晚 role_soft_delete 列?」**：無 active 角色授權時不會產生 watermark 列（0-active 漏洞）、需寫 sentinel 列（hack）。否決。
- **代價**：`getArchivedPolicies` 與 `restorePolicy` 需查 active 角色 `created_at`（per page 的 v0 codes 批次查 `sys_role` active → code→created_at map；restore 單列查）。純讀、可測。

## D5 — `getArchivedPolicies` 加 `restorable`（DTO + 衍生）

- **Decision**：`ArchivedPolicyItem`（`handler/system_manage.rs:387-396`）加 `restorable: bool`；建列時依 D4 規則計算（批次取 page rows 的 distinct v0 → `sys_role` active code→created_at map → per row 套規則）。**不過濾** role_soft_delete 列（FR-004 透明顯示）。
- **接地**：`get_archived_policies:1844-1880`（facade `list` → 逐列 push ArchivedPolicyItem；`dimension_display(v2)` 既有）。base-web `ArchivedPolicy` 型 `typings/api/rev3-system-manage.d.ts:285-294` 加 `restorable: boolean`（rev3 wrapper 型、ADAPT 軌、非 frozen）。

## D6 — `restorePolicy` 守門 → 2222 `biz.policy.notRestorable`

- **Decision**：`restore_policy`（`handler/system_manage.rs:1888-1914`）在呼 facade restore **前/中**加守門：載目標 archive 列、套 D4 規則，若不可復原 → `AppError::Biz("biz.policy.notRestorable")`（2222）。實作姿態：facade `restore` 加 `RestoreOutcome::NotRestorable`（讀列後判 restorability、不 mutate）→ handler map 2222（鏡像既有 NotFound→2222 範式）。**縱深防禦**：後端守門為安全邊界、不只靠前端隱藏。
- **接地**：restore 三態 `RestoreOutcome{Applied,NoOp,NotFound}`（`system_manage.rs:1894-1913`）；既有 `biz.policy.notFound`＝2222（`AppError::Biz(Cow::Borrowed)`）；新增 `biz.policy.notRestorable` 同範式。restore＝insert 回 casbin_rule + 硬刪 archive 列（§I.6 D、確認）。

## D7 — base-web 回收桶 UI + i18n（MODAL-WIRING + ⚠️aa I18N-WIRING）

- **Decision**：`views/manage/policy-archive/modules/policy-archive-table.vue`——
  - `archiveReason` 欄（render @73-79）改 i18n 友善 label map（實際 3 值：`role_dimension_revoke`/`role_endpoint_revoke`/`role_soft_delete` → 各譯文；C3：無 role_button_revoke）。
  - `operate` 欄（render @80-100，現 NPopconfirm+`复原` NButton）條件化：`row.restorable===false` → 顯「不可復原」停用態（無復原鈕）；`true` → 維持現有復原鈕。
- **i18n**：`backend.biz.policy.notRestorable`（toast key、攔截器自動 `$t('backend.'+msg)`）＋ `page.manage.policyArchive.*`（reason 標籤 + 「不可復原」指示）；同步擴 `app.d.ts` `App.I18n.Schema`（`backend.biz.policy` @329 區 + `page.manage.policyArchive` @963 區）＋ `locales/langs/{zh-cn,en-us}.ts` 雙語（先 Schema 後 locale、同 commit、memory gotcha）。
- **接地**：app.d.ts backend.biz @329（已有 user/menu/role、加 policy.notRestorable）；policyArchive locale @963；restore 鈕現呼 `fetchRestorePolicy`（`service/api/rev3-system-manage.ts:401`）、2222 經既有 request 攔截器 i18n 出 toast（⚠️aa／3.G 已備）。

## D8 — schema/crate/route

- **零 migration**（D4 用既有欄、無新欄/表）、**零新 crate**、**零新 route**（沿用 deleteRole/batchDeleteRole/getArchivedPolicies/restorePolicy）。
- prod build gate 仍跑（無新 crate、但驗 multi-stage 無破口）。`entity_access_lint`／`endpoint_coverage_lint` 預期綠（無新 route、casbin 存取走新 facade helper）。

---

## D9 — ★ 並發安全：lock-then-redecide（C1、analyze HIGH）

- **Decision**：`restore_policy` 的 restorability 重判與 `delete_role`/`batch_delete_role` 的「移除 active 授權」須在**同一把 `sys_role` 列鎖**下重判（鏡像 memory 014 U2 SC-002 lock-then-redecide）：
  - `delete_role`/`batch_delete_role` txn **起手** `SELECT … FOR UPDATE` 該 role 列（既有 `find_active_by_id` 改鎖讀／或新增鎖讀），守門與 archive-move 全程持鎖。
  - `restore_policy` txn 內、判 restorability 前，對該 archive 列 `v0` 的 active `sys_role` 列 `SELECT … FOR UPDATE`（無 active→不可復原）；持鎖再 insert 回 casbin_rule。
- **Rationale（不做的後果）**：restore re-check 以**非鎖** SELECT 讀 `sys_role` active，與 delete 交錯（restore 讀到 active → delete commit〔soft-delete+archive-all+delete casbin v0=code〕→ restore insert casbin v0=code commit）→ **已刪角色殘留 live 授權** → 重用 code → getMenu 繼承（破 SC-001/SC-007）。對稱 grant-during-delete 窗同理（delete 的 delete_many 讀 vs 晚到的 `set_role_dimension` insert）。FR-012 要殺的漏洞經並發窗回滲。
- **接地**：`mutate_in_txn`（`audit.rs:84`）READ COMMITTED；`find_active_by_id`（`sys_role.rs:121`）目前非鎖讀；sea-orm `lock_exclusive()` 加 `FOR UPDATE`。
- **驗收**：live 測注入交錯（或以鎖等待序證 restore 在 delete 後重判得「無 active→拒」）；C-V 加並發註記。

## D10 — active-role created_at 讀法（C4）

- **Decision**：新 facade 讀 `sys_role::active_created_at_by_codes(conn, &[code]) -> HashMap<String, DateTimeWithTimeZone>`（鏡像 `home_of_roles` 的 `find_active().filter(Code.is_in(codes))` 範式、`sys_role.rs:32-40`），供 `get_archived_policies` 批次套衍生；`restore_policy` 單列以 `find_active().filter(Code.eq(v0)).lock_exclusive().one()`（C1 同列鎖、回 created_at 或 None）。
- **接地**：`sys_role` facade 既有 `find_active`(20)／`home_of_roles`(32，Code.is_in 範式)／`find_active_by_id`(121)；**無**現成 created_at-by-code 讀 → 本刀新增（落 facade、不破 entity_access_lint）。

## 接地事實速查（file:line）

| 主題 | 位置 | 事實 |
|---|---|---|
| role soft_delete | `sys_role.rs:302-338` | `<C:TransactionTrait>(conn,id,meta)→Result<Option<Model>,DbErr>`；closure→`(txn,Option<Model>,Option<AuditEvent>)` |
| role batch_soft_delete | `sys_role.rs:344-383` | 單 txn 迴圈、per-id SoftDelete op-log、missing/deleted skip |
| mutate_in_txn | `audit.rs:84-97` | begin→closure→write op-log if event→commit |
| delete_role handler | `system_manage.rs:1208-1234` | 守門後 soft_delete、無 casbin、無 reload |
| batch_delete_role | `system_manage.rs:1239-1267` | Phase1 全守門→Phase2 batch_soft_delete |
| insert_archived | `sys_casbin_policy_archive.rs:32-37` | `(txn,rows:&[casbin_rule::Model],archived_by:Option<i64>,reason:&str)→Result<(),DbErr>` |
| set_role_dimension archive-move | `sys_casbin_rule.rs:51+` | read per-(v0,v2)→insert_archived(role_dimension_revoke)→delete_many |
| reload_and_publish | `system_manage.rs:874` | pub(crate)(&AppState)；load_policy+PUBLISH |
| ArchivedPolicyItem DTO | `system_manage.rs:387-396` | id/roleCode/target/dimension/archivedTime/archivedBy/archiveReason/createdTime（加 restorable） |
| get_archived_policies | `system_manage.rs:1844-1880` | facade list→逐列 push；dimension_display(v2) |
| restore_policy | `system_manage.rs:1888-1914` | 三態 Applied/NoOp/NotFound（加 NotRestorable） |
| archive entity | `entity/src/sys_casbin_policy_archive.rs` | 13 欄、archive_reason String NN、無 update/delete 欄（archetype D） |
| ArchivedPolicy 型 | `base-web rev3-system-manage.d.ts:285-294` | 加 `restorable: boolean` |
| 回收桶表 | `base-web policy-archive-table.vue:73-79（reason）/80-100（operate）` | reason label map + operate 條件渲染 |
| i18n Schema | `base-web app.d.ts:329（backend.biz）/963（policyArchive）` | 加 policy.notRestorable + labels |
