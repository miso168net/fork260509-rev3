# Data Model: 020-role-delete-policy-archive

**Branch**: `020-role-delete-policy-archive` | **Date**: 2026-06-27

> **零 schema 變更**（無新表/欄/migration）。本刀＝既有 entity 的新【行為】＋讀時衍生欄。下列為涉及的既有 entity 與其在本刀的角色，以及 ★ restorability 衍生規則（安全核心邏輯）。

## 涉及 Entity（皆既有、本刀不改 schema）

### casbin_rule（授權列）
- p-policy：`ptype='p'`、`v0`=role **code**、`v1`=target（route_name／button code／endpoint path）、`v2`=維度（`menu`／`button`／HTTP method＝endpoint）、`protected` bool。
- 本刀：角色刪除時，該 code 的**全部** p-policy（全 v2、含 protected）被 archive-move 移除。
- 不變式：rev3 僅 p-policy、無 g-policy（已驗）→ 範圍＝`ptype='p' AND v0=code` 即完整。

### sys_casbin_policy_archive（授權歸檔）— archetype D
- 13 欄：`id, ptype, v0, v1, v2, v3-5, created_at(nullable), created_by, archived_at(NN), archived_by, archive_reason(varchar32 NN)`。
- **archetype D 不變式（§I.6）**：archive＝insert＋restore 硬刪移回；**無 update/delete 審計欄**；本刀**不 in-place mutate 既有列**（D4 衍生判定即為此）。
- `archive_reason` 取值（本刀後全集、**C3 接地校正**）：`role_dimension_revoke`（menu **與 button** 手動撤銷——016 button reuse set_role_dimension）／`role_endpoint_revoke`（endpoint 手動撤銷）／**`role_soft_delete`（本刀新增＝角色刪除歸檔其 active 授權）**。**無 `role_button_revoke`**（codebase 從未發出）。
- 角色刪除歸檔的列：reason=`role_soft_delete`、`archived_at`=刪除時刻、`archived_by`=operator、原 `created_at/by` 自被移除的 casbin 列攜入。

### sys_role（角色）
- 本刀讀用欄：`code`（唯一識別、partial-uniq `WHERE deleted_at IS NULL`、可重用）、`created_at`（NN、★ restorability 衍生關鍵）、`deleted_at`（軟刪、單向）。
- 不變式：軟刪單向（無 role restore）；code 可於刪除後重用（index 不動）。

## ★ Restorability 衍生規則（FR-005 + FR-012 統一、安全核心）

`restorable(archiveRow)` 為**讀時計算**（不落庫、不 mutate）：

```
restorable(r) :=                                    -- denylist 形（C3）
    r.archive_reason != "role_soft_delete"
    AND  ∃ role ∈ sys_role : role.code = r.v0
                              AND role.deleted_at IS NULL          (active 角色存在)
                              AND role.created_at < r.archived_at  (歸檔屬【當前】角色實例)
```

- 條件一（denylist `!= role_soft_delete`）：role_soft_delete＝本刀唯一不可復原 reason；其餘（撤銷類）皆候選可復原。免列舉撤銷 reason（**C3**：實際撤銷 reason 僅 `role_dimension_revoke`〔menu+button〕／`role_endpoint_revoke`〔endpoint〕、**無 role_button_revoke**；denylist 對未來新撤銷 reason 自動正確）。
- 條件二（active 角色存在）：角色已刪（無 active）→ 不可復原。
- 條件三（`created_at < archived_at`）：重用同 code 的**新**角色 `created_at` 晚於**舊**歸檔 → 不可復原（歸檔屬舊實例、非當前實例）。
- **★ C1 並發**：條件二/三的 `sys_role` 讀須在**列鎖**下（restore 與 delete 同 `sys_role` 列 `FOR UPDATE` lock-then-redecide）；否則 restore-during-delete TOCTOU 留 orphan live 授權（見 research D9）。
- **★ C2=A 時鐘假設**：條件三依 `created_at`/`archived_at` 牆鐘、假設 delete→recreate 間單調；archive 不存 role_id、無序列 tiebreak（spec Assumptions 已記）。同-µs strict `<` errs closed（安全向）。

### Edge-case 真值表（驗收依據）

| 情境 | reason | active 角色(code) | created_at vs archived_at | restorable |
|---|---|---|---|---|
| live 角色被手動撤銷一條授權（正常 015/016） | revoke | 存在（同實例） | role.created < archive.archived | **true** ✓（零回歸） |
| 角色刪除歸檔其 active 授權 | role_soft_delete | （刪後無） | — | **false** ✓（FR-005） |
| 角色刪除前既有的手動撤銷列、角色已刪未重用 | revoke | 無 active | — | **false** ✓（FR-012） |
| 同上、code 已重用（新角色） | revoke | 存在（新實例） | new.created > old.archived → 條件三 false | **false** ✓（FR-012、restore-path 封閉） |
| 重用後新角色自己被手動撤銷一條 | revoke | 存在（新實例） | new.created < new-archive.archived | **true** ✓（屬新實例、可復原） |

> 關鍵：created_at 比較天然分辨「歸檔屬舊角色實例 vs 當前實例」，免 mutate 既有列、免 schema。新角色 `created_at` 必晚於任何舊實例（舊實例已刪）的歸檔 `archived_at` → 舊列對新實例恆不可復原。

## 操作（state transitions）

### deleteRole / batchDeleteRole（擴充）
0. （★ C1）txn 起手 `SELECT … FOR UPDATE` 該 role 列（lock-then-redecide、序列化 restore/grant-during-delete）。
1. 守門（seeded/in-use/self）— **任何寫之前**、不過則 2222 整筆/整批拒、零變更（既有、不變）。
2. （同一 `mutate_in_txn`、持鎖）soft_delete 角色：設 `deleted_at/by` + SoftDelete op-log（既有）。
3. （同 txn、新）`archive_all_role_policies(txn, role_code, op_id)`：讀 `casbin_rule ptype='p' AND v0=code`（全維）→ `insert_archived(reason="role_soft_delete")` → `delete_many`；回 archived 數。
4. （txn commit 後）archived>0 → `reload_and_publish`（PolicyMutated gate）。
- 原子性：步驟 2+3 同一 txn＝全成或全回滾（FR-003）；batch＝單 txn 逐角色 2+3。

### getArchivedPolicies（擴充）
- 既有 list（純 SELECT、order archived_at desc、分頁）→ 逐列補 `restorable`（D4 規則；批次查 page 的 v0 codes 對應 active sys_role created_at）→ `PageRes<ArchivedPolicyItem{...,restorable}>`。不過濾 role_soft_delete。

### restorePolicy（擴充守門）
- 載目標 archive 列 → （★ C1）對該列 `v0` 的 active `sys_role` 列 `SELECT … FOR UPDATE`（lock-then-redecide）→ 持鎖套 restorability 規則：不可復原 → **2222 `biz.policy.notRestorable`**（新增 `RestoreOutcome::NotRestorable`）；可復原 → 持鎖走既有 Applied/NoOp/NotFound 流程（insert 回 casbin_rule + 硬刪 archive 列）。

## 不涉及 / 非目標
- 無 schema migration、無新 entity/欄、無新 crate、無新 route。
- 不 mutate 既有 archive 列（D4 衍生取代）。
- 不禁 code 重用（index 不動）；不做既有孤兒清理（現 0）；無 role restore。
