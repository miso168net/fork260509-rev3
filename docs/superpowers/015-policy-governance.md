# 015 · Policy-governance — spec-design（Phase 0 brainstorm）

> **性質**：spec-kit feature **015** 的 Phase 0 brainstorm spec-design（CLAUDE.md §3 階段 0 產物）。聚焦**需求 / 範圍 / 驗收 / 治理島形狀 / 實作單元 / 已拍板選擇**；§4.2 治理狀態機的 states/transitions/invariants/對外碼 **權威設計**見 `docs/INTEGRATION-DESIGN.md` §4.2（本檔**照搬、不重新設計**）。
> **下一步**：手動跑 `/speckit-specify`（階段 1；`before_specify` pre-hook 建 feature branch `015-policy-governance`）。**勿**把 `/speckit-specify` 排進 brainstorm 流程觸發（會漏跑 `speckit.git.feature`）。
> **接地 pin**：rust-api `7ec8fc3`／base-web `f3b2bf07`（014 全收 + op_log 測試債修後）。**接地揭露**：`sys_casbin_policy_archive` 波0 m001 **已備**（零 migration）；011 `set_role_dimension` 寫側已建；014 Redis 基建/watcher 已建（pub-sub 範式可復用）；policy-archive UI **種子佔位但 view/endpoint 全缺**。

---

## 1. Feature 一句話

把 011 鋪的 casbin policy 寫側（`set_role_dimension` DB-first + protected-reject + reload-on-`changed`）補成 **DESIGN §4.2 完整治理島狀態機**：revoke 改 **archive-move**、加 **restore**、加 **PolicyMutated gate（完整版）**、加 **跨實例 `casbin:policy:invalidate` pub-sub 收斂**、加 **policy-archive 回收桶 UI**。**零 migration**（archive 表波0已備）。對應 DESIGN §4 三台行為島狀態機之**第三台**（§4.2 治理；§4.1 token + §4.3 single-session 已由 014 收）。

## 2. 問題 / 動機

011 Role 刀建了 §4.2 治理機的**寫側一半**（接地 pin `7ec8fc3`、`sys_casbin_rule::set_role_dimension`）：
- **DB-first**（直寫 `casbin_rule`、不碰 enforcer MgmtApi）+ **②protected-reject**（`to_revoke` 含 `protected=true`→整批 `Rejected`）+ 寫後 `load_policy` reload（**local-only**）。
- **但**：revoke 是 **HARD DELETE**（無 archive、撤了不可復原）；reload 是 **reload-on-`changed`**（local、無 cross-instance publish）；**無 restore、無完整 PolicyMutated gate、無回收桶 UI**。

§4.2 治理島是 **rev2 唯一 behavior-heavy 狀態機**（rev2 痛點＝把它當「又一張 casbin 表」排到最後，rev2 034/035 才發現要重弄）。rev3 用 §4 state-machine 鏡頭**第一輪就設計它**（DESIGN §4.2 已凍）；本刀把缺的三塊補完整：(1) revoke→archive 可復原 (2) PolicyMutated gate 完整 + cross-instance 收斂 (3) 回收桶 UI（§4.4「治理獨立一刀」）。

## 3. Scope

### 3.1 In scope

| 區 | 內容 |
|---|---|
| **revoke→archive** | `set_role_dimension` 的 revoke 從 HARD DELETE 改 **archive-move**（快照 INSERT `sys_casbin_policy_archive` + DELETE `casbin_rule` live、**同 txn 原子**）；archive facade（insert/query） |
| **restore** | `getArchivedPolicies`（list archive、鏡像 012 分頁）+ `restorePolicy`（archive→live 反向 move、restore 審計記 `{role,target,dimension}`、已 live→**NoOp 0000**、假 archive id→2222） |
| **PolicyMutated gate** | reload 觸發改完整 §4.2 ③：Applied〔含空-diff、刻意〕→reload+publish；Rejected/restore NoOp/NotFound/menu 查無→跳 |
| **跨實例 pub-sub** | reload = 全量 `load_policy()` + `PUBLISH casbin:policy:invalidate`；watcher `SUBSCRIBE casbin:policy:invalidate` → reload `Arc<RwLock<Enforcer>>`（**復用 014 settings watcher 範式**） |
| **回收桶 UI** | `views/manage/policy-archive` 新頁（list archived + restore；**MODAL-WIRING ★ (e)**；menu 種子已備〔`m002:253`、`/manage/policy-archive`、icon `mdi:recycle`、R_SUPER〕、建好順帶消解 §3.13 console error） |

### 3.2 Out of scope / deferred

- **un-protect/re-protect（改 protected flag）⚠️ A 拍板（user 親決 2026-06-22）= 不做**：protected 維持**硬守門**（種子核心〔casbin_rule 19 列 protected=true + 核心 menus〕、API 不可撤是 by-design 防 lock-out；**custom 角色 grant 的 policy 全 `protected=false`、可自由治理**）。做它須 §V.2 amend §4.2（凍結 transitions 不含此操作）+ lock-out 風險 + scope/UI，YAGNI（protected 只鎖「你永遠不會 legit 想撤的種子核心」、真有極端 edge 走 DB）。
- **button/endpoint dimension 編輯**：波3 第三刀（Button-Endpoint policy 縱切）；本刀的 archive/restore **dimension-agnostic**、revoke→archive 改在 `set_role_dimension`，button/endpoint 日後復用即自動 archive。
- **archive 永久清除（purge old archive）**：未列、未來 maintenance（archive **無 update/delete 欄**、restore = 硬刪移回；purge 是另一回事）。
- **casbin policy 真實水平擴展部署（prod ≥2 副本/nginx LB）**：本刀只 2-instance **驗證**跨副本收斂（沿 014 C1 B-驗證版、dev 預設仍 1）。

## 4. 設計綱要（states/transitions/invariants/對外碼 權威＝DESIGN §4.2 frozen，本刀照搬不重設計）

**state**：policy 列的所在 = `live in casbin_rule` ⇄ `archived in sys_casbin_policy_archive`。

**transitions（本刀補的）**：
- **revoke(→archive)**：非 protected 列 → 快照 INSERT archive + DELETE live（**同 txn**）。protected → 整批 `Rejected`（②、011 已有）。
- **restore(←archive)**：反向 move 回 `casbin_rule` live、archive 列刪；已 live→**NoOp**（archive 列仍消費、無審計、0000）；假 archive id→2222。
- **reload**：全量 `load_policy()` 重讀 casbin_rule + `PUBLISH casbin:policy:invalidate`（跨實例收斂）。

**invariants（DESIGN §4.2 ①~⑤）**：
① **DB-first**（寫側只動 DB casbin_rule/archive、**不碰 in-memory enforcer MgmtApi**）② **protected-reject**（protected 列拒撤→整批 Rejected、零變更〔011 已有〕）③ **PolicyMutated gate**（commit 後**只有結構性真變更**才 `reload_and_publish`：Rejected/restore NoOp/NotFound/menu 查無→跳；**惟空-diff Applied 與 menu-found-但-無-policy 仍 reload**〔刻意、不優化、rev2 035 FR-006〕）④ revoke/restore 與審計**同 txn 原子**；restore 審計記 `{role,target,dimension}`（非懸空 archive_id）⑤ reload = 全量 `load_policy()` + `PUBLISH casbin:policy:invalidate`。

**對外碼**：Applied→`0000`；restore NoOp（policy 已 live）→`0000`（no-op、archive 列仍消費、無審計）；Rejected/非法/假 archive id→`2222`。**沿凍結 13 碼矩陣、無新碼**。

## 5. Functional Requirements

- **FR-1 revoke→archive**：`set_role_dimension` 的 revoke 改 archive-move（快照 archive + DELETE live、同 txn）；protected→整批 Rejected〔011 已有、零回歸〕。
- **FR-2 archive facade**：`sys_casbin_policy_archive` insert（快照 `ptype/v0-v5/原 created_at·by/archived_at·by/archive_reason`）+ query（list、by role/dimension）。
- **FR-3 restore**：`restorePolicy` archive→live 反向 move（live 7-col 重複 pre-check、restore 審計 `{role,target,dimension}`）；已 live→NoOp 0000；假 archive id→2222。
- **FR-4 getArchivedPolicies**：list archived（分頁、鏡像 012 `PageRes`）；honest wire（id number、欄逐欄對齊 entity）。
- **FR-5 PolicyMutated gate**：完整 §4.2 ③（Applied〔含空-diff〕→reload+publish；Rejected/restore NoOp/NotFound/menu-not-found→skip）；**可能調整 011 的 reload-on-`changed`**（空-diff 現 skip→§4.2 刻意 reload；plan 接地 reconcile）。
- **FR-6 跨實例 pub-sub**：reload `PUBLISH casbin:policy:invalidate`；watcher `SUBSCRIBE`→reload `Arc<RwLock<Enforcer>>`（復用 014 Redis 基建/watcher）。
- **FR-7 回收桶 UI**：`views/manage/policy-archive`（list archived + restore；MODAL-WIRING (e)；i18n 先 Schema 後 locale；rev3 service wrapper）。
- **FR-8 零回歸**：011 role-menu loop（`updateRoleMenu`）不破（revoke 改 archive 後 casbin_rule **live state 不變**、+archive 列；011 測的 byte-restore **要連 archive 殘留一起清**）；010 動態選單、enforce 既有行為不破。
- **FR-9 零 migration**：archive 表 m001 已備、**無新表/欄/migration**。

## 6. Success Criteria（DoD：§4.2 5 invariants 逐條自動化驗證、DESIGN §8.8）

- **SC-1 archive-move**：revoke 非 protected→psql 證 archive 列寫入（含原 created_at·by + archived_at·by + reason）+ casbin_rule live 列消失（同 txn）。
- **SC-2 restore**：archive→live 回復 + archive 列刪 + 審計 `{role,target,dimension}`；已 live→NoOp 0000 無審計；假 archive id→2222。
- **SC-3 protected-reject 零回歸**：`to_revoke` 含 protected→整批 Rejected 2222、零變更〔011 已有〕。
- **SC-4 PolicyMutated gate**：Rejected/restore NoOp/NotFound→**不 reload**；Applied〔含空-diff〕→reload（純測 or live 證 reload 觸發）。
- **SC-5 跨實例**：rust-api-2（profiles:[multi]）改 policy→另副本經 `casbin:policy:invalidate` watcher 收斂（enforce 結果跨副本一致）+ watcher 斷線重訂閱韌性。
- **SC-6 回收桶 UI CDP**：經 `:31080` list archived + restore 真打 + psql 證 live/archive 移動 + Super-only 可達。
- **SC-7 011 role-menu loop 零回歸 + archive 殘留清**。
- **SC-8 零 migration**（`git diff <base>..HEAD migration/` 空）+ **prod target image build**。

## 7. 實作單元（rough、階段 2 由 `superpowers:executing-plans` + Workflow 重組、不綁本清單）

`L1` archive facade + revoke→archive（`sys_casbin_policy_archive` facade insert/query；`set_role_dimension` revoke: DELETE→archive-move 同 txn）｜`L2` restore（`getArchivedPolicies` list + `restorePolicy` move-back + restore 審計 + NoOp/假 id）｜`L3` PolicyMutated gate（reload 觸發改完整 §4.2 ③、reconcile 011 reload-on-`changed`）｜`L4` 跨實例 pub-sub（reload publish + watcher subscribe→reload enforcer、復用 014）｜`L5` base-web policy-archive 回收桶 UI（view + service + i18n、MODAL-WIRING (e)）｜`L6` 2-instance 驗證 + holistic（復用 rust-api-2 驗 ⑤；011 零回歸 + archive 清）。

> **相依**：L1→L2（restore 依 archive facade）；L3 依 L1（gate 在寫後）；L4 依 L3（publish 在 reload）+ 014 Redis 基建；L5 依 L1/L2/L4 wire（getArchivedPolicies/restorePolicy）；L6 依全部。實際執行單元由階段 2 `executing-plans` 依 tasks.md 真實相依重組。

## 8. 已拍板的設計選擇

- **A（user 親決 2026-06-22）：un-protect/re-protect 不做**（protected 硬守門、§4.2-faithful；理由見 §3.2）。
- **零 migration**（`sys_casbin_policy_archive` 波0 m001:665 已備、13 欄）。
- **復用 014 Redis 基建/watcher**（casbin pub-sub 套 settings watcher 範式；`casbin:policy:invalidate` channel）。
- **跨實例驗證 = 復用 014 rust-api-2**（profiles:[multi]）驗 ⑤ invariant（§8.8 DoD 要求每 invariant 自動化驗證；非新拋棄式 spike）。
- **回收桶 UI = MODAL-WIRING ★ (e) 新管理頁**（嚴格鏡像 010 menu 回收桶 / 012 audit 範式；menu 種子已備）。

## 9. 留待 plan/impl 階段定（非 feature-shaping、無 user 拍板級）

- **PolicyMutated gate vs 011 reload-on-`changed` reconcile**：011 現以 `changed = !to_revoke.is_empty() || !to_grant.is_empty()` gate reload（**空-diff skip**）；§4.2 ③ 說**空-diff Applied 仍 reload**〔刻意、不優化〕→ plan 接地 011 actual reload trigger + 決定是否調整（grep `set_role_dimension` reload 觸發 + `updateRoleMenu` handler）。
- **archive_reason 寫什麼**：revoke→archive 的 reason（e.g. `"set_role_dimension revoke"` 或操作 context）。
- **restore 的 live 重複 pre-check**：restore 移回前驗 live 7-col 是否已存在（已 live→NoOp、archive 列仍消費）。
- **watcher 形狀**：casbin watcher 是**獨立 spawn**（如 014 settings watcher）vs **擴充既有 watcher 多 channel**（一連線 SUBSCRIBE 兩 channel `settings:invalidate`+`casbin:policy:invalidate`、dispatch by channel）；reload enforcer = `enforcer.write().await.load_policy()`、fail-OPEN（沿 014）。
- **getArchivedPolicies wire/分頁/filter**：鏡像 012（`PageRes`、by role/dimension filter、空字串守門 §5.8）；honest typing（payload 任意 JSON、IP/id 沿 §I.3）。
- **011 role-menu loop 測 archive 清理**：revoke 改 archive 後 `sys_casbin_rule.rs role_menu_loop` teardown byte-restore 要連 archive 殘留清（sys_casbin_policy_archive）。
- **Phase 0 research 紀律 grep**（plan 階段必跑）：`set_role_dimension`/`SetDimensionOutcome`/`SetDimensionError` 真實簽名 + `sys_casbin_policy_archive` entity 13 欄 + `updateRoleMenu` handler reload + 014 `spawn_settings_watcher` 形狀（不信本檔抽象命名、act-on actual code）。

## 10. Constitution / 紀律對齊

- **§I.7 §4.2 行為島**：用 state-machine 鏡頭、5 invariants 逐條自動化驗證（§8.8 DoD）；不混進 §5 CRUD 格子（§4.4）。
- **§I.7 §4.2 ① DB-first**：寫側只動 DB（casbin_rule/archive）、**絕無 enforcer MgmtApi**（`remove_filtered_policy`/`add_policies`）—— 沿 011 `set_role_dimension` DB-first、constitution §4.2 禁的 rev2-034 anti-pattern。
- **零 migration**：`sys_casbin_policy_archive` m001 已備（⚠️t 波0全建兌現）；Constitution Check item 8 = 無新表/ALTER。
- **動 base-web（MODAL-WIRING (e) 新管理頁）**：授權軌道內；每處記 file:line + upstream 風險；i18n 先 Schema 後 locale。
- **跨實例 = §8.5 de-risk「治理島跨實例」做進 acceptance**（沿 014 C1 B-驗證、復用 rust-api-2、非拋棄式 spike）。
- **復用 011（set_role_dimension）+ 014（Redis/watcher）**：受控參照既有 in-tree code（§I.5、非 rev2 拷貝）。

## 11. References

- **DESIGN**：§4.2（policy governance 狀態機 — states/transitions/invariants/對外碼 **權威**）/ §4.4（行為島紀律 2+1 合刀）/ §8.2（縱切清單 policy 治理＝rev2 034/035、回收桶 UI 刀位）/ §8.5（風險序治理島跨實例 spike）/ §8.8（DoD）/ §I.6 §193（archive 治理欄）/ §I.7 §4.2（凍結 invariants）。
- **接地（pin `7ec8fc3`/`f3b2bf07`）**：`server/src/model/facade/sys_casbin_rule.rs`（set_role_dimension DB-first + ②protected-reject + reload-on-changed）/ `entity/src/casbin_rule.rs`（protected 欄）/ `migration/src/m001_rev2_schema.rs:665`（sys_casbin_policy_archive 13 欄）/ `handler/system_manage.rs`（updateRoleMenu reload）/ 014 `server/src/redis.rs` + `main.rs spawn_settings_watcher`（pub-sub 範式）/ `m002:253`（manage_policy-archive menu 種子）/ base-web `views/manage/menu`（回收桶 pattern）/ `views/manage/audit`（list 範式）。
- **CHECKLIST**：§3.14（011 follow-up：casbin policy 治理機波3）/ DECISIONS §1（拍板現況、含 ⚠️m alt-login 延後）/ §8.2（policy-archive 刀位）。
