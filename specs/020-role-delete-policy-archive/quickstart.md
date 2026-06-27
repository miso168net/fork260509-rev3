# Quickstart / Validation Guide: 020-role-delete-policy-archive

**Branch**: `020-role-delete-policy-archive` | **Date**: 2026-06-27

> 端到端驗證本刀（角色刪除歸檔授權、重建同 code 不繼承、回收桶顯示但不可復原）。完整命令見 [contracts/verification-commands.md](contracts/verification-commands.md)；資料規則見 [data-model.md](data-model.md)。

## 前置
- dev stack up + healthy（`docker compose -f docker-compose.yml -f docker-compose.dev.yml ps`）。
- CDP:9229 活；Super 登入 0000、測試 IP 未鎖。
- rust build/test 一律 rust-api 容器內（host 無 cargo）；live smoke 帶 `DATABASE_URL` + `--test-threads=1`（§3）。

## 核心驗證流程（happy path）
1. **不繼承（US1/SC-001、C-V-1）**：建角色 code X、授 menu+button+endpoint → deleteRole → 重建同 code → `getRoleMenu/Button/Endpoints` 皆 `[]`、psql `casbin_rule WHERE v0=X`＝0。
2. **歸檔（FR-002、C-V-2）**：刪後 psql `sys_casbin_policy_archive WHERE v0=X AND archive_reason='role_soft_delete'`＝刪前授權數；casbin 對應＝0。
3. **回收桶顯示+不可復原（US2、C-V-4/6/9）**：`getArchivedPolicies` 含該列 `restorable=false`；`restorePolicy` 打該列→2222 `biz.policy.notRestorable`；CDP 頁顯來源譯文 + 復原鈕停用。
4. **restore-path 封閉（FR-012/SC-007、C-V-5）**：live 角色撤一條（archive restorable=true）→ deleteRole → 該列 restorable=false → 重建同 code → 仍 false、restorePolicy→2222、未裝回新角色。
5. **零回歸（FR-007、C-V-7）**：live 角色撤一條→回收桶復原→0000 成功（既有 015/016 流程不變）。

## 自動化測試（TDD）
- **facade live 測**（in-crate `#[ignore]`+env-gate，rust-api 容器內 `cargo test -p server -- --ignored --test-threads=1`）：
  - `archive_all_role_policies` + soft_delete 整合：建角色 grant 三維 → soft_delete → 斷言 casbin v0=code 全消 + archive 列 reason=role_soft_delete + reload 反映；**batch 變體**；**0-授權角色** soft_delete＝archive no-op（archived=0、不 reload）。
  - **原子回滾**：注入 error 於 archive 步 → 角色 deleted_at 與 casbin 皆回滾（FR-003）。
  - restorability 衍生 + restorePolicy 守門：覆蓋 data-model 真值表 5 情境（尤其重用後 created_at 比較）。
- **純函式測**（test-first）：`restorable()` 衍生規則（reason 類別 + created_at 比較）逐情境。
- **acceptance/CDP**：見 contracts C-V-1~11。

## 出口
- spec.md 出口條件全綠（SC-001~007）；C-V-1~11 全綠；lint 綠；prod build 綠；零回歸（179+ rust 測 / 既有回收桶流程）。
