# Quickstart: 005-audit-op-log 驗證指南

> 從零驗證本刀（op-log 同 txn 原子審計機制＋單一 proof）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型/接線＝[data-model.md](data-model.md)；不變式＝[contracts/audit-op-log-contract.md](contracts/audit-op-log-contract.md)。

## 前置
- dev stack 可起並全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 002 seed：sys_user Super/Admin/User id=1/2/3）。
- rust 一律容器內跑（host 無 toolchain）；改 `.rs` 先 force-touch；rust serial。

## 驗證流程（4 步）

1. **建置綠**（C-V-0）：容器內 `cargo build -p server`（先 force-touch）→ `mod audit`＋op-log facade＋sys_user `AuditSerialize`/`soft_delete` 編譯綠；`IpNetwork` import 解析；`never constructed`（Insert/Update/Restore）warning 可接受。

2. **redact 純測**（C-V-1）：`cargo test -p server redact` → sys_user `audit_json()` 的 `password`==`"<redacted>"`、其餘欄保留（無 DB、test-first）。

3. **原子 live smoke**（C-V-2）：stack healthy 後 `DATABASE_URL="$(cat /run/secrets/database_url)" cargo test -p server -- --ignored --test-threads=1 op_log_atomic` → 外層 txn 內 `sys_user::soft_delete(Super)` → 同 txn 查 op-log（commit 路徑寫入、rollback 路徑雙不留）→ 外層 rollback 不污染 seed。**必看 N passed**（非 0 filtered）。

4. **lint 守恆**（C-V-3）：`cargo test -p server --test entity_access_lint` → 既有 004 守恆續綠（`audit.rs` 無 path-root `entity::`、op-log 構造在 facade 豁免）。

## 預期結果（對應 SC）

| 步 | 對應 SC | 通過 |
|---|---|---|
| 1 | SC-007 | server 編譯綠、既有服務不回歸（無 router 改動）|
| 2 | SC-003 | 敏感欄遮蔽 |
| 3 | SC-001/002 | 同 txn 原子審計（commit 寫入／rollback 雙不留）|
| 4 | SC-004/FR-007 | append-only＋facade 唯一管道守恆 |

> SC-005（零端點/零 migration）＋SC-006（表中立）由 diff／設計審查核（無新端點、無 migration、`audit.rs` 無表名硬編、單一 proof 即證可重用）。**無 prod build**（本刀無新 workspace crate）。

## 不在本刀（各歸其刀）
- overlay 刀：access-log/login-attempt facade＋audit_ctx 中介層＋xdb＋trusted-proxy＋op-log INET 回填。
- operator 自動來源（RequestContext）→ audit_ctx/Auth 島刀；op-log 讀端 → ⚠️b 波2；其餘寫路徑 → 各消費刀；`DbErr→AppError` → Auth 刀。
- 無 endpoint/wire/migration/新 crate。
