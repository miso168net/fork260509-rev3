# Quickstart: 007-audit-overlay 驗證指南

> 從零驗證本刀（audit overlay）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型/接線＝[data-model.md](data-model.md)；不變式＝[contracts/audit-overlay-contract.md](contracts/audit-overlay-contract.md)；ground-truth＝[research.md](research.md)。

## 前置
- dev stack 全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 m001 audit 表＋m002 seed `Super`/`Admin`/`User`/`123456`）。
- xdb：`xdb/resources/ip2region.xdb`（~10.5MB git-tracked）就位；dev `XDB_FILEPATH` 指向之；`TRUSTED_PROXY_CIDRS` dev 預設空（fail-safe＝採直連 peer）。
- nginx 已轉發 XFF/X-Real-IP/X-Request-Id（R6、零改）。
- rust 一律容器內跑；改 `.rs` 先 force-touch；rust serial；live `--test-threads=1`。

## 驗證流程（10 步、對應 C-V-0~9）

1. **build 綠**（C-V-0）：force-touch → `cargo build -p server --locked`（xdb 連結、ipnetwork sea-orm re-export、1.86 不撞）。
2. **resolve_client_ip 純測**（C-V-1）：`cargo test -p server resolve_client_ip` → rightmost-untrusted／peer-gate anti-spoof／IPv4·IPv6／畸形 token／fail-safe。
3. **facade active_model 純測**（C-V-2）：`cargo test -p server active_model` → IpAddr→IpNetwork /32·/128、access/login 對稱。
4. **trace_id 純測**（C-V-3）：`cargo test -p server trace_id` → x-request-id honor／生成。
5. **live INET no-42804 ＋ region**（C-V-4）：觸認證請求後 psql 查 `sys_access_log` 末列 `client_ip`(真 INET)／`region`(私有→「内网IP」非 NULL)。
6. **live login-attempt 成敗各列**（C-V-5）：錯密碼＋`Super/123456` 各打 → psql 查 `sys_login_attempt` 末 2 列（失敗 success=false/operator_id=NULL/has_ip=true；成功 success=true/operator_id=1）。
7. **live access-log operator-gate**（C-V-6）：認證 getUserInfo → 1 列；未認證 getUserInfo／health／login → 0 列。
8. **live op-log threading（test-only smoke）**（C-V-7）：`cargo test -p server -- --ignored --test-threads=1 oplog_threading` → op-log 末列 operator_id/operator_ip/trace_id 由恆 None→真值。
9. **prod image build**（C-V-8、★新 crate 紀律）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` → xdb COPY＋`[[bench]]` 跳＋`--locked` 綠、`.xdb` 在 image、prod boot `xdb_ready=true`。
10. **lint 守恆＋零回歸**（C-V-9）：`cargo test -p server --test entity_access_lint` 綠；`/health` 回 `ok`；diff 零 migration/entity/base-web/i18n/nginx。

## 預期結果（對應 SC）

| 步 | 對應 SC | 通過 |
|---|---|---|
| 1 | SC-008（建置面） | server 編譯綠、xdb 連結 |
| 2 | SC-003 | resolve_client_ip trusted-proxy 正確、防偽造 |
| 3 | SC-004 | IpAddr→IpNetwork 對映 |
| 4 | SC-005 | trace_id honor/生成 |
| 5 | SC-004/007 | 真 INET no-42804、region 內網非 NULL |
| 6 | SC-002 | login-attempt 成敗各一列、失敗帶 IP |
| 7 | SC-001 | access-log operator-gate（認證 1/未認證 0） |
| 8 | SC-006 | op-log operator/IP/trace 歸屬 seam 通 |
| 9 | SC-008 | prod image 含 xdb、xdb_ready |
| 10 | SC-009 | lint 續綠、/health 零回歸、零 schema 變更 |

> SC-007 降級面（xdb 缺檔→region NULL 不崩潰）可另以「移走 .xdb 啟動」驗（boot warn＋xdb_ready=false＋請求仍成、region NULL）。

## 不在本刀（各歸其刀）
- 波2：audit 讀端/查詢端點＋UI（⚠️b）。
- 波3：login lockout 本體（⚠️w；本刀備真實 IP＋既有索引）／cleanup-job。
- 波1+：op-log operator_ip live handler 回填（首個 mutating 端點）。
- 波4：retention/cleanup（⚠️n）／全流量 obs（tracing→loki）。
