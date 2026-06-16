# Contracts: 007-audit-overlay — Verification Commands (C-V)

**Date**: 2026-06-15 | **Branch**: `007-audit-overlay`

> 本刀**無新 wire/業務端點**（audit 為透明中介層 + 內部表）→ 無 HTTP API contract。Contract ＝專案 **C-V（command-verification）**：純測 + live smoke + prod image build。每條對映 spec SC/FR。**無 CDP**（純後端、無信封/前端消費面，異於 006）。
> live smoke 一律 `--test-threads=1`（serial，見 memory `live-ignore-tests-need-serial`、005 共用 op-log 表非 parallel-safe）。

---

## C-V-1 — `resolve_client_ip` 純函式（test-first、零 DB）→ SC-003

```bash
cd rust-api && cargo test -p server resolve_client_ip
```
**斷言**（純測案）：
- rightmost-untrusted 命中：`peer∈trusted, XFF="real, cf_edge"`（cf_edge∈trusted）→ `real`。
- 多 hop 跳 trusted（含 CF 段命中）。
- IPv4 與 IPv6 來源皆正確。
- 畸形 XFF token 略過、繼續解析。
- **直連 peer ∉ trusted（偽造防護）**：`peer∉trusted, XFF 帶偽造` → 回 `peer`（不信 header）。
- 全 trusted / 空 XFF → fail-safe 回 `peer`。
- `TRUSTED_PROXY_CIDRS` 未設→空集合→回 peer。

## C-V-2 — facade `*_active_model` 純映射（零 DB）→ SC-003/SC-004

```bash
cd rust-api && cargo test -p server active_model
```
**斷言**：`IpAddr→IpNetwork`（/32·/128、V4/V6）正確；event 各欄落對 ActiveModel 欄；access-log/login-attempt 對稱。

## C-V-3 — `trace_id` honor / mint 純函式 → FR-010

```bash
cd rust-api && cargo test -p server trace_id
```
**斷言**：有 `x-request-id`→沿用（trim、≤64 char、UTF-8 邊界安全）；無→產生非空 uuid。

## C-V-4 — live：真 INET 寫入無 42804 + region 內網非空 → SC-003/SC-007/FR-009

```bash
cd rust-api && cargo test -p server --test '*' -- --ignored --test-threads=1 live_smoke_audit_inet
psql "$PG_URL" -c "SELECT client_ip, region FROM sys_access_log ORDER BY id DESC LIMIT 1;"
```
**斷言**：`client_ip` 為真 INET 值（無 PG 42804）；私有/內網 IP → `region` 非 NULL（「内网IP」類）。

## C-V-5 — live：login-attempt 成功+失敗各一列（失敗列帶 client_ip）→ SC-002/FR-004/FR-005/FR-011

```bash
# 失敗（錯密碼）+ 成功（Super/123456）各打一次，經 front-nginx /api
curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"wrong"}'  >/dev/null
curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' >/dev/null
psql "$PG_URL" -c "SELECT attempted_user_name, success, operator_id, client_ip IS NOT NULL AS has_ip FROM sys_login_attempt ORDER BY id DESC LIMIT 2;"
```
**斷言**：恰兩列——失敗列 `success=false, operator_id=NULL, has_ip=true`；成功列 `success=true, operator_id=1`。

## C-V-6 — live：access-log operator-gate（已認證寫一列、未認證不寫）→ SC-001/FR-001/FR-002

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s http://127.0.0.1:31080/api/auth/getUserInfo -H "Authorization: Bearer $TOKEN" >/dev/null   # 已認證
curl -s http://127.0.0.1:31080/api/auth/getUserInfo >/dev/null                                       # 未認證（無 bearer）
curl -s http://127.0.0.1:31080/health >/dev/null                                                     # public
psql "$PG_URL" -c "SELECT count(*) FILTER (WHERE path LIKE '%getUserInfo') AS authed, operator_id IS NOT NULL AS has_op FROM sys_access_log GROUP BY has_op;"
```
**斷言**：已認證 getUserInfo → 一列（operator_id 非空）；未認證 getUserInfo／health／login **不產生** access-log 列。

## C-V-7 — live：op-log operator/trace/operator_ip 回填 → SC-006/FR-013

```bash
# 由已認證操作者執行一個可審計異動（如 soft-delete proof），再查 op-log 末列
cd rust-api && cargo test -p server --test '*' -- --ignored --test-threads=1 live_smoke_oplog_backfill
psql "$PG_URL" -c "SELECT operator_id, operator_ip, trace_id FROM sys_operation_log ORDER BY id DESC LIMIT 1;"
```
**斷言**：末列 `operator_id` 非空、`operator_ip` 為真 INET 非空、`trace_id` 非空（005 恆 None 的欄已補全）。

## C-V-8 — **prod image build（mandatory：xdb 為新 workspace crate、CLAUDE.md §3）**→ Assumptions/§3.4

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
**斷言**：builder COPY 含 `xdb/{Cargo.toml,src,benches,resources/ip2region.xdb}`（缺則 manifest parse 失敗——RED→GREEN 證 gate）；`cargo build --locked`（防 ipnetwork 靜默 un-pin 炸 MSRV）；`--bin server` 不編 `[[bench]]`；image 自足、`.xdb` 在。

## C-V-9 — 守恆：`entity_access_lint` 續綠 → §I.5

```bash
cd rust-api && cargo test -p server --test entity_access_lint   # --test 必要：bare filter→0 passed 假綠
```
**斷言**：新增 audit_ctx/facade/resolver 走 facade、不碰 raw `entity::`（004 lint 不退）。

---

## 對映表

| C-V | SC | FR |
|---|---|---|
| C-V-1 | SC-003 | FR-006/007 |
| C-V-2 | SC-003/004 | FR-003/005/008 |
| C-V-3 | — | FR-010 |
| C-V-4 | SC-003/007 | FR-006/009 |
| C-V-5 | SC-002 | FR-004/005/011 |
| C-V-6 | SC-001 | FR-001/002 |
| C-V-7 | SC-006 | FR-013 |
| C-V-8 | — | Assumptions（新 crate prod build）|
| C-V-9 | — | §I.5 守恆 |

> SC-005（審計失敗不阻請求）由 C-V-4~7 的 best-effort 路徑覆蓋 + 純測 `best_effort_audit` 吞錯斷言（FR-012）；可在 live 以「停 PG 後打請求仍 200」補強（plan→tasks 定）。
