# 020-role-delete-policy-archive — spec-design（Phase 0 brainstorm）

> CLAUDE.md §3 階段 0 產物。交棒 → 手動 `/speckit-specify`（input＝本檔）起 `020-role-delete-policy-archive` feature branch。
> 日期：2026-06-27。來源：[CHECKLIST §3.K](../INTEGRATION-CHECKLIST.md)（P-011-1，2026-06-26 CDP 第2輪全測 HIGH 發現、待拍板）／[011-role-management brainstorm](011-role-management.md)＋`specs/011-role-management/data-model.md`（deferral 出處）／[015-policy-governance](015-policy-governance.md)＋[016-button-endpoint-policy](016-button-endpoint-policy.md)（archive-move 機制承接）。

---

## 1. 背景與目標

**問題（P-011-1、HIGH）**：`deleteRole`／`batchDeleteRole` 只軟刪 `sys_role` 列、**不清該 role code 的 casbin 授權**；partial unique index `sys_role_code_active_uniq (code) WHERE deleted_at IS NULL` 允許**重用 code**；casbin 以 role **code（v0）** 為 key → 重建同 code 的新角色**靜默繼承**舊（軟刪）角色的選單/按鈕/端點授權（016 維度＝API 存取權繼承）。實測：建 code X 授 `[home,manage_role]`→軟刪→重建同 code→`getRoleMenu` 回該選單集而非空。

**deferral 前提被推翻**：`specs/011-role-management/data-model.md` 將「軟刪角色殘留 v2='menu' policy」列為波3 治理清理、理由「**可刪角色必無人用**」——此前提在 **code 重用路徑**下不成立（重建的 active 角色可指派 user）。

**目標**：角色軟刪即移除其所有 **active** 授權，重建同 code 必為**乾淨白板**、不繼承；資料不丟（forensic 可查）；回收桶透明顯示但這批不可誤復原。

**範圍**：role 軟刪（單筆＋批次）的 casbin 授權處置 ＋ 回收桶顯示/復原語意。**非**：role restore（單向、不做）、禁止 code 重用、既有孤兒清理（現為 0）。

---

## 2. 拍板紀錄（user 親決 2026-06-27 brainstorm）

- **修法方向＝刪時 archive 授權**（root-cause、資料不丟）：`deleteRole`/`batchDeleteRole` 軟刪的**同一交易**內，把該 role code 的**所有** casbin p-policy（menu/button/endpoint 各維、不論 protected）archive-move（snapshot→archive→delete），**復用 015/016 既有 `insert_archived` 機制**。否決：硬刪（丟 forensic）／重建時才清（治標、留 dormant 殘留）／禁止 code 重用（侵入、需 migration、改 UX）。
- **回收桶顯示 + 欄位標示 + 不可手動復原**：被 archive 的 role-delete 列**要出現在回收桶**（透明可查）、用**欄位**標示其來源（角色刪除）、且**不可手動復原**（防誤復原 + 重用再繼承的 footgun）。否決：全隱藏（失去透明性）。

**工程拍板（我決、記錄；非 user 拍板級）**：
- `archive_reason = "role_soft_delete"`（distinct，與 `role_dimension_revoke`/`role_button_revoke`/`role_endpoint_revoke` 區分；驅動欄位標示 + 不可復原守門）。
- DTO 加 `restorable: bool`（後端單一真相，由 reason 推導：`role_soft_delete`→false、其餘撤銷→true）；前端不硬編 reason。
- archive **全維度全列**（含 protected）：角色將被刪除、protected-reject（防 live 角色 UI 撤核心）不適用；防禦性 archive 所有 `v0=code` 列。
- **原子性**（⚠️o 跨 facade）：role 軟刪 + casbin archive 走**單一 txn**、全成或全回滾。
- **reload + publish**：txn commit 後若 archived>0，`load_policy` reload + publish `casbin:policy:invalidate`（鏡像 `set_role_dimension` reload-on-changed + 跨實例，015/016）；archived=0 則 skip。
- partial unique index **不動**、code 重用維持支援且現在安全。
- **fix-forward only**：現有孤兒＝0（已驗）→ 不做 cleanup migration。
- archiveReason 欄改 **i18n 友善標示**（小 label map、各 reason 一致友善化）。

---

## 3. Phase 0 研究實證（act-on-code 接地 @ 2026-06-27）

> ★ 以 as-built 為準。以下已核（exact 行號於 `/speckit-plan` research.md 再固化）：

- **`sys_role::soft_delete`（`model/facade/sys_role.rs:302`）**：僅 `find_active_by_id`→設 `deleted_at/deleted_by`→SOFT_DELETE op-log；**無任何 casbin 處置**。批次 `batch_soft_delete`（同檔 ~340）同理。
- **handler**：`add_role`（`handler/system_manage.rs:1158`、僅 `sys_role::create`、不碰 casbin）／`delete_role`（1208、守門 seeded/in-use/self **後**→`soft_delete`）／`batch_delete_role`（1239、批次先全守門→`batch_soft_delete`）。
- **`set_role_dimension`（`model/facade/sys_casbin_rule.rs:51`）＝archive-move 範本**：read current（`ptype='p' AND v0=code AND v2=dim`）→diff→**revoke 走 `sys_casbin_policy_archive::insert_archived(&txn, rows, Some(operator.id), "role_dimension_revoke")`→delete_many**（同 txn 原子）。`insert_archived` 即可復用、改 reason 即可。
- **casbin 現況（psql）**：142 列**全 `ptype='p'`、無 g-policy**；`v0 ∈ {R_SUPER, R_ADMIN, R_USER_COMMON}`；**孤兒（v0∉active code）＝0 列**。→ 範圍僅 p-policy 即完整；無既有地雷。
- **partial unique index**：`sys_menu... ` 同族；role 為 `sys_role_code_active_uniq ON sys_role (code) WHERE deleted_at IS NULL`。
- **role 軟刪單向**（`data-model.md:105`「role restore 無、軟刪單向」）→ archive-on-delete 無 role-restore 衝突。
- **回收桶讀/寫**：`getArchivedPolicies`/`restorePolicy`（`handler/system_manage.rs:1836+`）；前端表 `base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue` 欄＝roleCode/target/dimension/archivedTime/createdTime/archivedBy/**archiveReason**/operate（復原鈕）。archiveReason 欄已存在（現顯 raw）。

---

## 4. 設計細節

> 一刀 `020-role-delete-policy-archive`、規模中。**執行單元（待 `/speckit-tasks` firm）**：U1 rust（archive-on-delete + 回收桶後端語意）｜U2 base-web（回收桶顯示/不可復原 + i18n）。

### 4.1 U1 — rust archive-on-delete + 回收桶後端（RUSTAPI-SOURCE-ISOLATION 軌）

- **新 facade helper**（`sys_casbin_rule`，復用 `insert_archived`）：`archive_all_role_policies(txn, role_code, operator) -> Result<usize, DbErr>` — 讀 `ptype='p' AND v0=code` **全列** → `insert_archived(..., "role_soft_delete")` → `delete_many`；回 archived 列數。
- **原子整合**：role 軟刪 + `archive_all_role_policies` 共用**單一 txn**。實作姿態（extend `sys_role::soft_delete`／`batch_soft_delete` 接受並傳遞 txn 內呼叫 vs 新協調 facade）於 `/speckit-plan` 對齊 facade 簽名後 firm；鐵律＝同交易、全成或全回滾、`entity_access_lint` 不破（casbin 存取走 facade）。
- **handler `delete_role`／`batch_delete_role`**：守門（seeded/in-use/self）**之後**才走 archive-on-delete 路徑；批次在批次 txn 內逐角色 archive；txn commit 後 archived>0 → reload + publish（鏡像現有）。
- **`getArchivedPolicies`**：**不過濾** `role_soft_delete`；DTO 每列加 `restorable`（`reason=='role_soft_delete'`→false、否則 true）。
- **`restorePolicy`**：對 `reason='role_soft_delete'` 列拒絕 → 2222 新 biz key `biz.policy.notRestorable`（縱深防禦、不只靠前端隱藏）。

### 4.2 U2 — base-web 回收桶顯示/不可復原 + i18n（MODAL-WIRING + ⚠️aa BASE-WEB-I18N-WIRING 軌）

- **`policy-archive-table.vue`**：
  - **archiveReason 欄** → i18n 友善 label map（`role_soft_delete`→「角色刪除」/「Role deleted」，既有 revoke reason 同步友善化）。
  - **operate 欄條件渲染**：`row.restorable===false` → 顯示「不可復原」停用態（無 `复原` 按鈕）；`true` → 維持現有 `复原` 按鈕。
- **i18n**：新增 reason label 鍵 ／「不可復原」鍵 ／ `backend.biz.policy.notRestorable` ＋ **同步擴 `app.d.ts` App.I18n.Schema**（memory 既知 gotcha：先 Schema 後 locale、同 commit、zh-cn+en-us 雙語）。

### 4.3 nginx／schema
零改：無新 route（沿用既有 deleteRole/batchDeleteRole/getArchivedPolicies/restorePolicy）、**零 migration**（archive 表＋casbin_rule 波0 已備）、零新 crate。

---

## 5. v1 不做（defer）

- 禁止 code 重用（移 partial 條件／改名 code）——否決、侵入。
- 既有孤兒 cleanup migration——現 0 列、不需；若日後出現再評。
- role restore（軟刪單向、無）。
- 回收桶**依 reason 過濾/分頁器**（本刀只做欄位標示 + 不可復原；filter 為 future、可選）。
- restorePolicy 之外的其他 archive 來源語意調整（僅新增 role_soft_delete 不可復原一類）。

---

## 6. 出口條件

- [ ] 重建同 code 的新角色 `getRoleMenu`/`getRoleButton`/`getRoleEndpoints` 皆回**空**（不繼承）。
- [ ] 軟刪角色後 psql：該 code 的 `casbin_rule` p-列＝0；`sys_casbin_policy_archive` 對應列存在、reason=`role_soft_delete`；與軟刪同 txn（全成/全回滾）。
- [ ] `getArchivedPolicies` **含** role_soft_delete 列且 `restorable=false`；`restorePolicy` 打該列→2222 `biz.policy.notRestorable`。
- [ ] CDP：回收桶顯示該列 + 來源欄文字（非 raw key）+ 復原鈕停用/不可點；雙語在地化。
- [ ] enforcer reload/publish 於 archived>0 時發生；archived=0 skip。
- [ ] `entity_access_lint`／`endpoint_coverage_lint` 綠（無新 route）；prod image build 綠（無新 crate）。
- [ ] 零回歸：既有 015/016 revoke→archive→restore（restorable=true）流程不變。

---

## 7. 測試／驗收策略（TDD）

- **facade live 測**（in-crate `#[ignore]`+env-gate、`--test-threads=1`）：建角色→grant menu+button+endpoint→`soft_delete`→斷言 casbin v0=code 全消 + archive 列 reason=`role_soft_delete` + reload 後 enforce 拒；**batch 變體**；無授權角色軟刪＝archive no-op（archived=0、不 reload）。
- **純函式測**（test-first）：`restorable` 由 reason 推導（`role_soft_delete`→false、其餘→true）。
- **acceptance（curl/psql）**：完整重現 — 建 code X grant→deleteRole→重建同 code→`getRoleMenu`→**[]**；`getArchivedPolicies` 含該列 restorable=false；`restorePolicy` 打該列→2222。
- **CDP（browser smoke）**：回收桶顯示 role_soft_delete 列 + 來源欄譯文 + 復原鈕停用；雙語切換 toast/欄位在地化（restart base-web 防 vite stale-locale）。
- **prod build gate**：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠。

---

## 8. Phase 0 research 待固化（交 `/speckit-plan` research.md）

- `sys_role::soft_delete`／`batch_soft_delete` 確切簽名與 txn 邊界（決定原子整合姿態：extend vs 協調 facade）。
- `insert_archived` 確切簽名 + `sys_casbin_policy_archive` 欄位（reason 長度 ≤32 `varchar(32)`、`role_soft_delete`=16 字、OK）。
- `getArchivedPolicies` DTO struct + `restorePolicy` 三態 handler 確切行號，加 `restorable` 與 notRestorable 守門插點。
- `policy-archive-table.vue` 欄定義行 + `app.d.ts` Schema 路徑（reason label / notRestorable 鍵）。
- reload+publish helper 名（`set_role_dimension`/restorePolicy 用的同一個）以復用。

---

## 9. DESIGN／data-model 落差紀錄（act-on-code 接住、供勘誤評估）

- `specs/011-role-management/data-model.md:87`「軟刪角色殘留 v2='menu' policy **無害**（可刪角色必無人用；波3 治理清）」——前提被 P-011-1 推翻（code 重用路徑）。本刀落地後該行屬 **stale 勘誤候選**（spec 快照、as-built 權威在本刀；`/speckit-plan` 時評估是否最小 patch 或標 as-built）。
- CHECKLIST §3.K 待拍板項：本刀收刀後 → 拍板登 DECISIONS §1 + §3.K 勾掉/歸檔 MILESTONES。
