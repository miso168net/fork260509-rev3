# C-V Contract: verification-commands（005-audit-op-log）

> 實機驗收命令全集。rust 一律**容器內**跑（host 無 toolchain）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**（共用 target）。**無 mandatory prod build**（本刀無新 workspace crate）。

## C-V-0 · server 建置綠

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo build -p server'
```
- `mod audit`（`AuditOperation`/`AuditOperator`/`AuditEvent`/`AuditSerialize`/`mutate_in_txn`）＋`facade/sys_operation_log.rs`＋`facade/sys_user.rs`（`impl AuditSerialize`＋`soft_delete`）編譯綠。
- `IpNetwork` import（`sea_orm::entity::prelude::IpNetwork`）解析綠（with-ipnetwork feature 聯集就位）。
- `never constructed`（Insert/Update/Restore）warning **可接受、不抑制**（infra-ahead-of-consumer）。

## C-V-1 · AuditSerialize redact 純測（test-first、無 DB）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server redact'
```
- 純單元測（非 `#[ignore]`、無 DB）：對 `sys_user::Model{ password:"secret", user_name:"X", .. }` 取 `audit_json()` → 斷言 `["password"]=="<redacted>"` ＋ `["user_name"]=="X"`（其餘欄保留）。對應 SC-003。
> ⚠️ 看到「0 passed; N filtered out」＝filter `redact` 沒命中、非綠。

## C-V-2 · mutate_in_txn 原子 live smoke（txn-savepoint 隔離）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && \
    DATABASE_URL="$(cat /run/secrets/database_url)" cargo test -p server -- --ignored --test-threads=1 op_log_atomic'
```
（DATABASE_URL 由 secret 帶——容器 env 未設；live stack 須 `up -d --wait` 全 healthy、postgres 有 002 seed。）
- in-crate `#[ignore]`：開**外層 txn**（`db.begin()`）→ `sys_user::soft_delete(&outer, Super id=1, operator, None)`（內部 nested begin＝savepoint）→ 同 outer 內查 `sys_operation_log`：
  - **commit 路徑**：恰一列新 op-log（`operation=SOFT_DELETE`／`entity_table=sys_user`／`entity_id=1`／`payload_before.password=<redacted>`／`payload_after.deleted_at` 非空／`operator_id`=operator.id），且 sys_user.deleted_at 已 set。
  - **rollback 路徑**：對「注入失敗」情境（如 soft_delete 不存在 id 或閉包回 `Err`）→ op-log **不留**、業務不改（原子釘死、非 vacuous）。
- `outer.rollback()` 全還原 → **不污染 002 seed**。對應 SC-001（同 txn 寫入）／SC-002（失敗雙不留）。
> ⚠️ 必看「N passed」（非「0 passed; N filtered out」）；filter `op_log_atomic` 命中 live 測。`--test-threads=1` 防 live serial 偽失敗。

## C-V-3 · entity_access_lint 守恆綠（audit.rs lint-clean）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test entity_access_lint'
```
- 既有 004 守恆續綠：`audit.rs` 無 path-root `entity::`（`sea_orm::entity::prelude::IpNetwork` 為 colon-preceded 豁免）；op-log 構造在 `facade/`（豁免）。對應 US3／FR-007。
> ⚠️ 整支 binary 用 `--test entity_access_lint`；「0 passed; N filtered out」＝非綠。

## 出口
C-V-0~3 全綠＝本刀 acceptance 通過；對應 spec SC-001~007（SC-004 append-only＝facade 無 update/delete fn 由 diff/設計審查核；SC-005 零端點/零 migration 由 diff 核；SC-006 表中立＝單一 proof＋audit.rs 無表名硬編；SC-007 既有 /health 不回歸＝無 router 改動、stack 仍 healthy）。**無 prod build**（無新 crate）。
