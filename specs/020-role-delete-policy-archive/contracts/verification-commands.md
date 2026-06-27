# Contracts / Verification Commands: 020-role-delete-policy-archive

**Branch**: `020-role-delete-policy-archive` | **Date**: 2026-06-27

> 無新 wire endpoint（沿用 deleteRole/batchDeleteRole/getArchivedPolicies/restorePolicy）→ 無新 contract schema。本檔＝C-V 活體驗收命令（curl `/api` + psql + CDP），對映 spec FR/SC。
> 共通：`TOK=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")`；`PSQL(){ docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres psql -U soybean -d soybean_admin_rust "$@"; }`；唯一 throwaway code `zz020_<rand>`；rust build/test 在 rust-api 容器內（§3、`--test-threads=1`）。

## C-V-0 — 前置
- stack healthy、CDP:9229 活、Super 登入 0000、IP 未鎖。記錄 baseline：`PSQL -c "SELECT count(*) FROM sys_casbin_policy_archive;"`。

## C-V-1 — US1/SC-001 核心：刪角色清授權、重建同 code 不繼承（getMenu 路徑）
1. addRole code=`zz020_x` → 0000；getRoleList 得其 id=R1。
2. `updateRoleMenu`(R1,[home,manage_role])／`updateRoleButton`(R1,[某 code])／`updateRoleEndpoints`(R1,[某 path,method]) → 各 0000；psql `casbin_rule WHERE v0='zz020_x'` 三維列存在。
3. `deleteRole`(R1) → 0000。
4. addRole code=`zz020_x`（同 code）→ 0000；得新 id=R2。
5. **斷言**：`getRoleMenu?roleId=R2`→**[]**、`getRoleButton?roleId=R2`→**[]**、`getRoleEndpoints?roleId=R2`→**[]**（0 繼承）；psql `casbin_rule WHERE v0='zz020_x'`＝**0 列**（active 授權全消）。

## C-V-2 — SC-002/FR-002：角色刪除歸檔（reason=role_soft_delete、casbin 移除、原子）
- 步驟 C-V-1.3 刪除後：psql `sys_casbin_policy_archive WHERE v0='zz020_x' AND archive_reason='role_soft_delete'` ＝ 該角色刪前 active 授權數（三維全進）；對應 `casbin_rule WHERE v0='zz020_x'`＝0。歸檔列 `archived_by`=1、`created_at/by` 攜原 grant。

## C-V-3 — FR-003 原子性
- 軟刪與 casbin archive 同 txn：正常路徑驗「角色 deleted_at 已設 ⇔ casbin 已清 ⇔ archive 已增」三者一致（C-V-1/2 已涵蓋）。失敗回滾路徑＝facade live 測以注入 error 驗（in-crate `#[ignore]`、見 quickstart）；handler 層 curl 無法安全注入失敗，標 contract 由 live 測覆蓋。

## C-V-4 — FR-004/FR-006/SC-002：回收桶含 role_soft_delete 列、restorable 旗標正確
- `getArchivedPolicies?roleCode=zz020_x`（刪後）→ 0000；records 含 role_soft_delete 列、每列 `restorable=false`。
- 對照：對一個 **live** 角色手動撤銷一條（updateRoleMenu 移除一項）→ 該 archive 列 `restorable=true`（C-V-7 詳）。

## C-V-5 — ★ FR-012/SC-007：既有手動撤銷列於角色刪除/重用後不可復原（restore-path 封閉）
1. addRole code=`zz020_y` → R1；updateRoleMenu(R1,[home,function]) → 0000。
2. updateRoleMenu(R1,[home])（撤 function）→ 0000；psql archive 得 `v0='zz020_y' archive_reason='role_dimension_revoke'` 一列 A1；`getArchivedPolicies?roleCode=zz020_y` → A1 `restorable=true`（此時 R1 live、created_at<A1.archived_at）。
3. `deleteRole`(R1) → 0000。**斷言**：`getArchivedPolicies?roleCode=zz020_y` → A1 `restorable=false`（角色已刪、無 active）。
4. addRole code=`zz020_y`（重用）→ R2。**斷言**：A1 仍 `restorable=false`（R2.created_at > A1.archived_at、屬舊實例）。
5. `restorePolicy`(A1.id) → **2222 `biz.policy.notRestorable`**；psql `casbin_rule WHERE v0='zz020_y' AND v1='function'`＝0（未被裝回新角色）。

## C-V-6 — FR-005：restorePolicy 對 role_soft_delete 列 → 2222
- 取 C-V-2 的某 role_soft_delete archive id → `restorePolicy`(id) → **2222 `biz.policy.notRestorable`**、零變更。

## C-V-7 — FR-007 零回歸：live 角色手動撤銷→復原仍可用
- live 角色（未刪）updateRoleMenu 撤一條 → archive 列 restorable=true → `restorePolicy`(id) → 0000（Applied）、casbin 列復原、archive 列消費（硬刪）。確認既有 015/016 流程不變。

## C-V-8 — FR-010：reload/publish
- C-V-1.3 刪除（archived>0）後：rust-api log 見 enforcer reload；被刪角色（若曾有 user——但守門擋 in-use，故以 enforce 直驗）授權於 enforce 即不放行。archived==0 角色（無授權）刪除 → 不 reload（log 無）。

## C-V-9 — CDP 回收桶 UI（FR-004/FR-005/FR-006/FR-011）
- 製造 ≥1 role_soft_delete 列（C-V-1）+ ≥1 不可復原既有撤銷列（C-V-5）後，CDP authed 探 `http://127.0.0.1:31080/manage/policy-archive`（reload+settle）：
  - 列顯示、`archiveReason`/來源欄為**在地化譯文**（非 raw key）；role_soft_delete 列來源顯「角色刪除」。
  - `restorable=false` 列：operate 欄顯「不可復原」停用態、**無**可點復原鈕；`restorable=true` 列：有復原鈕。
  - 嘗試對不可復原列復原（若 UI 容許繞道）→ toast 在地化 `biz.policy.notRestorable`（非 raw key）。
  - zh-cn／en-us 雙語驗（restart base-web 防 vite stale-locale）。

## C-V-10 — batch 變體
- batchDeleteRole 含多個 throwaway 角色（各有授權）→ 每角色授權各自歸檔（role_soft_delete）、casbin 各清；守門（含 protected/in-use/self 任一）→ 整批 2222 零變更（含零歸檔）。

## C-V-11 — lint + prod build gate
- 容器內：`cargo test -p server --test entity_access_lint` 綠（casbin 存取走 facade）／`cargo test -p server --test endpoint_coverage_lint` 綠（無新 route）。
- prod image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（無新 crate、驗 multi-stage 無破口）。

## C-V-12 — ★ 並發 lock-then-redecide（C1、analyze HIGH）
- **rust live 測（容器內、首選驗證）**：模擬 restore-during-delete 交錯——對一個有可復原撤銷歸檔列的 throwaway 角色，令 `restore_policy` 與 `delete_role` 並發（或以 `FOR UPDATE` 鎖等待序強制 restore 在 delete 後重判）→ 斷言 restore 重判得「無 active 角色」→ 拒（NotRestorable/2222）→ psql `casbin_rule WHERE v0=code`＝**0**（無 orphan live 授權）。對稱 grant-during-delete 同理（晚到 grant 不留 live 列）。
- **碼面驗**：`delete_role`/`batch`/`restore_policy`/`soft_delete` 的 `sys_role` 讀皆 `lock_exclusive()`（FOR UPDATE）；grep 確認無非鎖 active-role 讀於這些寫端決策路徑。
- **真並發交錯**（多 client 同微秒）難於 curl 穩定復現 → 以「鎖序 live 測 + 碼面 FOR UPDATE 斷言」覆蓋；純壓力交錯 defer（rationale：lock-then-redecide 由 DB 列鎖保證、非靠時序）。

## 清理
- 所有 throwaway 角色 soft-delete／psql 清其 casbin_rule + archive 列；archive 回 baseline；無殘留 active 角色/casbin/user_role。
