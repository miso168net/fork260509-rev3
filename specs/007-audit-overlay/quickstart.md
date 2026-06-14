# Quickstart: 007-audit-overlay 驗證導引

**Date**: 2026-06-15 | **Branch**: `007-audit-overlay`

> 證「audit overlay 端到端可運作」的可跑步驟。完整斷言見 [contracts/verification-commands.md](contracts/verification-commands.md)；型/欄見 [data-model.md](data-model.md)。本檔不含實作 code。

## 前置

- rev3 dev stack 可起（001 infra）；m001 已含三 log 表（002 baseline）；006 auth 島就位（login/getUserInfo/enforce）。
- 工具：`docker compose`、`curl`、`psql`、`cargo`（容器內）。
- env：`PG_URL`（dev `postgres://...@127.0.0.1:35432/...`）；`TRUSTED_PROXY_CIDRS`（dev 可不設＝fail-safe 空→用 peer；經 nginx 測真實解析時設內網段，如 `127.0.0.1/32,172.16.0.0/12`）。

## A. 純測（test-first、零 DB/HTTP；最快回饋）

```bash
cd rust-api && cargo test -p server resolve_client_ip active_model trace_id
cargo test -p server entity_access_lint
```
**預期**：resolver 7 類案綠（含直連偽造防護 + fail-safe）、active_model IpAddr→IpNetwork 綠、trace honor/mint 綠、lint 續綠。對映 C-V-1/2/3/9。

## B. 起 dev stack

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
curl -fsS http://127.0.0.1:31080/health     # front-nginx → 200
```

## C. login-attempt（成功+失敗各一列）

依 [C-V-5](contracts/verification-commands.md#c-v-5)：打一次錯密碼 + 一次 `Super/123456`，psql 查 `sys_login_attempt` 末兩列。
**預期**：失敗列 `success=false / operator_id=NULL / client_ip 非空`；成功列 `success=true / operator_id=1`。

## D. access-log operator-gate

依 [C-V-6](contracts/verification-commands.md#c-v-6)：已認證 getUserInfo（帶 bearer）、未認證 getUserInfo、`/health` 各打一次，psql 查 `sys_access_log`。
**預期**：只有已認證 getUserInfo 產生一列（operator_id 非空）；未認證/health/login **零列**。

## E. 真 INET + region（live smoke，serial）

```bash
cd rust-api && cargo test -p server -- --ignored --test-threads=1 live_smoke_audit_inet live_smoke_oplog_backfill
```
依 [C-V-4](contracts/verification-commands.md#c-v-4)/[C-V-7](contracts/verification-commands.md#c-v-7)：psql 查 `client_ip`/`region`/`operator_ip`。
**預期**：`client_ip` 真 INET 無 42804；私有 IP `region` 非 NULL（內網類）；op-log 末列 `operator_id`/`operator_ip`/`trace_id` 全非空（005 恆 None 已補）。

## F. best-effort 不阻請求（SC-005）

停 PG（或斷 audit 寫）後打一個已認證請求 → 請求仍正常回應（200/業務碼），audit 列丟棄、log 有 warn。對映 FR-012。

## G. prod image build（mandatory，xdb 新 crate）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
依 [C-V-8](contracts/verification-commands.md#c-v-8)：builder 含 xdb 全套 COPY（缺則 RED）、`--locked`、`--bin server` 跳 [[bench]]。
**預期**：image build 綠、`.xdb` 在、ipnetwork 未靜默 un-pin。

## 驗收對映

| 步驟 | C-V | SC |
|---|---|---|
| A | C-V-1/2/3/9 | SC-003 |
| C | C-V-5 | SC-002 |
| D | C-V-6 | SC-001 |
| E | C-V-4/7 | SC-003/006/007 |
| F | （best-effort）| SC-005 |
| G | C-V-8 | （新 crate prod build）|
