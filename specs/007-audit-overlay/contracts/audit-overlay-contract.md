# Contract: Audit Overlay（007 落定、跨 feature 權威）

> 本刀建立的不變式，後續 audit 讀端刀（波2 ⚠️b）、login lockout（波3 ⚠️w）、首個 mutating 端點（波1+）、observability（波4）繼承。權威＝DESIGN §5.2／§3.1/§3.3／§10.4／§I.5/§I.6＋constitution §I.5/§I.6。

## 1. audit 三 sink / append-only 不變式
1. **三 sink**：`sys_operation_log`（資料異動、005）／`sys_access_log`（已認證 HTTP、007）／`sys_login_attempt`（登入事件、007）。
2. **archetype B append-only**（§I.6/§3.1）：facade **只暴露 write**（`write` / `write_in_txn`），**無** update/delete 路徑、不可竄改。三表無 read 端點（讀端＝波2）。
3. **無 migration**：三表＋索引 m001 已建（007 零 schema 變更）。

## 2. RequestContext / audit_ctx 不變式
1. **全域 audit_ctx 中介層**（L7、最外層）：每請求**無條件**建 `RequestContext{operator_id, client_ip, x_forwarded_for, region, trace_id}` 塞 extensions（handler 前可讀）。
2. **永不 reject**：audit_ctx 不回 Result、不擋任何請求；獨立寬鬆 bearer（operator_id Some/None）與 006 `enforce_mw`（strict、3333）**各自獨立 verify、不共用 Claims、enforce_mw 不動**。
3. **best-effort 寫**（FR-012）：audit 寫失敗 → `tracing::warn` 吞、**絕不**失敗/擋業務請求。

## 3. access-log operator-gate 不變式（§3.3/§10.4）
1. **單一 operator gate**：access-log **僅** `operator_id.is_some()`（已認證）寫一列；未認證（無/壞/過期 bearer、login、health、public）**不**落列。**無 sentinel(0)、無 path 排除清單**。
2. access-log `operator_id` **NOT NULL**（未認證刻意不落列）；每已認證請求**恰一列**（FR-001）。

## 4. login-attempt 不變式
1. **每登入終端結果恰一列**（FR-004）：成功＋每失敗路徑各 exactly-one；由 `login_inner→Result`＋outer 單一記點**建構保證**（非逐點散記）。
2. **operator_id 規則**：pre-identity 失敗（查無/lookup-DbErr/密碼錯）＝NULL；post-identity 失敗（roles/簽章/timestamp/txn）＋成功＝Some(uid)。
3. **未認證亦帶 IP**（FR-011）：失敗登入（含未認證）仍記真實 client IP。`attempted_user_name` 成敗皆記。

## 5. 真實 client IP / trusted-proxy 不變式（FR-006/007、推進 §5.9）
1. **resolve_client_ip**：peer-gate（直連不可信→peer）→ rightmost-untrusted（XFF 右→左跳 trusted、第一個不可信＝client）→ fail-safe（全 trusted/空→peer）。
2. **只信顯式配置的 trusted-proxy**（`TRUSTED_PROXY_CIDRS`、fail-safe 預設空）；**絕不盲信** forwarded（防偽造規避 lockout/嫁禍/污染稽核）。CF 段入 trusted、零 CF code。
3. **原始 XFF 逐字保存**（`x_forwarded_for`、與解析後 `client_ip` 分欄、鑑識）。
4. **§5.9 推進**：client_ip 由「直連」推進為「forwarded trusted-proxy 解析」；DESIGN-detail（非 constitution/DECISIONS）、無 Amendment、下次 DESIGN 重鑄摺合。

## 6. INET / region 不變式
1. **INET 真值寫入**：`IpNetwork::from(IpAddr)`（V4→/32 V6→/128）在 facade seam、native binding、無 PG 42804。codebase 首個寫真值 INET 路徑。
2. **region best-effort**（FR-009）：由 client_ip 經 xdb 解；私有/內網→非空「內網」類；**xdb 不可用/缺檔→region NULL、稽核仍成立、不崩潰**。
3. **xdb boot-guard**：缺檔不 panic——boot `Path::exists` 守門＋`xdb_ready` flag；`search_by_ip` 僅 ready 時呼叫。

## 7. trace_id 不變式
1. 每請求附 `trace_id`：honor 入站 `x-request-id`（trim≤64 UTF-8-safe）否則生成 uuid v4。

## 8. op-log operator 歸屬 seam 不變式（R7、誠實範圍）
1. **seam ready**：`mutate_in_txn`/`soft_delete` 已收 `operator:AuditOperator{id,ip:Option<IpNetwork>}`＋`trace_id`；007 立 `RequestContext→AuditOperator` threading helper。
2. **本刀無 live mutating handler**（唯一 consumer test-only）→ FR-013 由 test-only live smoke 證；**production threading 自波1+ 首個 operator-attributed mutating 端點起生效**。

## 9. 本刀邊界（OUT）
- 無 audit 讀端/查詢端點＋UI（波2 ⚠️b）；無 login lockout 本體（波3 ⚠️w、本刀備真實 IP＋既有 2 索引）；無 retention/cleanup（波4 ⚠️n）；無 op-log live handler 回填（波1+）；無全流量 obs 日誌（波4 tracing→loki）；無 cleanup-job crate（波3）。
- **§I.5 拷貝**：`xdb` 整檔拷貝（例外、零改）；`audit_ctx`/facade/`resolve_client_ip` 全新寫。
- 無 migration/entity/型遷移/base-web/i18n/nginx 變動。
