# Tasks: XFF → real_ip 鑑識

**Branch**: `013-xff-real-ip-forensics` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

**Input**: spec.md（5 User Stories）/ plan.md（10 實作單元 L1–L10）/ data-model.md / contracts/verification-commands.md（C-V-0~9）/ research.md（9 Decisions）

## Format: `[ID] [P?] [Story] Description with file path`
- **[P]**：不同檔、無未完成相依、可平行（**但 rust 一律 serial 跑 cargo、共用 target**）。
- **[Story]**：US1~US5（Setup/Foundational/Polish 無 Story label）。
- 測試紀律：**純函式邏輯 test-first（TDD red→green）**；wiring/形狀對映類由 acceptance（C-V live/CDP/curl/psql）覆蓋（constitution §I.4 / CLAUDE.md §3）。
- 紀律：rust 容器內 `docker exec` build/test、live `--test-threads=1`；base-web commit `--no-verify`；base-web 改動循 §III `rev3-inline` fork-delta 紀律；★ 絕不 push/merge until finishing。

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 新增 `toml` workspace dep（`rust-api/Cargo.toml` `[workspace.dependencies]` `toml = { version="0.8", default-features=false, features=["parse"] }` + `server/Cargo.toml` `toml={workspace=true}` + `Cargo.lock` 釘版），容器內驗 1.86 編得過（C-V-0）
- [ ] T002 [P] 建 `deploy/trust-model.toml` 範本（quickstart 範例）+ `docker-compose.dev.yml`/`docker-compose.prod.yml` 加 `TRUST_MODEL_FILE` env + bind-mount 進 rust-api 容器（L10）
- [ ] T003 建 m006 migration 檔骨架 `rust-api/migration/src/m006_audit_ip_forensics.rs`（`DeriveMigrationName`、空 up/down）+ `rust-api/migration/src/lib.rs` append `mod m006_audit_ip_forensics;` + `Box::new(...)` 入 `migrations()`（L5）

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ 所有 User Story 都依賴本階段（schema + 信任 config + state）**

- [ ] T004 m006 UP/DOWN DDL（data-model §2）：access/login `client_ip→real_ip` + add `peer_ip`/`ip_confidence`；operation `operator_ip→operator_real_ip` + add `operator_peer_ip`/`operator_x_forwarded_for`/`operator_ip_confidence`；down 嚴格反序；`rust-api/migration/src/m006_audit_ip_forensics.rs`（m001 凍結不改）
- [ ] T005 entity Model 三檔與 m006 同步（data-model §3、`DeriveEntityModel` 欄名須一致）：`rust-api/entity/src/sys_access_log.rs`、`sys_login_attempt.rs`、`sys_operation_log.rs`（rename + add Option 欄）
- [ ] T006 [P] `TrustModel` 結構 + `load_trust_model()` in `rust-api/server/src/config.rs`（data-model §5：CdnEntry/MyPublicEntry/Binding、CIDR 欄 String 收 + post-load `parse::<IpNetwork>()`、`TRUST_MODEL_FILE` 讀檔、缺檔 fallback flat `TRUSTED_PROXY_CIDRS`、誤配 fail-safe）
- [ ] T007 `AppState.trusted_proxy_cidrs`→`trust_model:Arc<TrustModel>` in `rust-api/server/src/state.rs` + `main.rs`（建構傳 `Arc::new(cfg.trust_model)`；ConnectInfo 不動）（L3；依 T006）

## Phase 3: User Story 1 — 跨拓樸正確解析 + 四欄記錄 (P1) 🎯 MVP

**Goal**：任何拓樸（直連/CDN/多反代/Tunnel/IIS）解析出真實 client IP（忽略注入假 IP）+ 四欄鑑識寫入三審計表。
**Independent Test**：12 案例純測 `(real_ip,confidence)` 符合 + live psql 三表四欄真寫入。

### Tests for US1（TDD、test-first、純函式）⚠️ 先寫、先紅

- [ ] T008 [US1] 純測 `normalize_xff_tokens`（split `[\s,+]`、剝 v4 `:port`/v6 `%zone`/`[..]:port`、garbage drop、空輸入）in `rust-api/server/src/audit_ctx.rs`（#[cfg(test)]）
- [ ] T009 [US1] 純測 `resolve` 四分支（peer-gate/CDN-anchor/Tier-2/fallback）+ dual_role 軟降 + **重映射 8 個既有測**到 `(IpAddr,Confidence)` in `rust-api/server/src/audit_ctx.rs`
- [ ] T010 [US1] 純測 `apply_cf_overlay`（verified×cip×base 矩陣→CDN_VERIFIED/CDN_MISMATCH/原樣）in `rust-api/server/src/audit_ctx.rs`
- [ ] T011 [US1] 純測 **12 解析案例**（research §4）→ `(real_ip,confidence)` in `rust-api/server/src/audit_ctx.rs`（C-V-2）

### Implementation for US1

- [ ] T012 [US1] `enum Confidence`（7 態 + `as_str()`）+ `struct IpForensics{peer,real,xff,confidence}` in `rust-api/server/src/audit_ctx.rs`（data-model §4）
- [ ] T013 [US1] `normalize_xff_tokens(&str)->Vec<IpAddr>` in `rust-api/server/src/audit_ctx.rs`（L1；令 T008 綠）
- [ ] T014 [US1] 改寫 `resolve_client_ip`→`(IpAddr,Confidence)`、兩層 + 對 `&TrustModel` 分類（classify_ip / is_cdn / is_my_public / is_internal）in `rust-api/server/src/audit_ctx.rs`（L1；依 T006,T012,T013；令 T009/T011 綠）
- [ ] T015 [US1] `apply_cf_overlay(base,cip,verified,real)->Confidence` top-level overlay in `rust-api/server/src/audit_ctx.rs`（L1；依 T012,T014；令 T010 綠）
- [ ] T016 [US1] `RequestContext` +`peer_ip:IpAddr` +`ip_confidence:Confidence`；`audit_mw` 前段讀 `cf-connecting-ip`+`x-cf-verified` header、呼叫 resolve+overlay、留 `peer.ip()`、建 `IpForensics` in `rust-api/server/src/audit_ctx.rs`（L6；依 T014,T015）
- [ ] T017 [US1] `AuditOperator` 維持 `#[derive(Copy)]`（只帶 peer/real）+ `AuditEvent` 帶 xff/confidence + `to_audit_operator` 組裝 in `rust-api/server/src/model/audit.rs` + `audit_ctx.rs`（L6；依 T016；**不動 16 facade 簽名**）
- [ ] T018 [US1] 三 sink 寫端映四欄 in `rust-api/server/src/model/facade/sys_{access_log,login_attempt,operation_log}.rs`（`write_in_txn` / `AccessLogEvent` / `LoginAttemptEvent` 加 peer/confidence；operation 映 `operator_*`）（L6；依 T005,T017）
- [ ] T019 [US1] login sink 構造帶四欄 in `rust-api/server/src/handler/auth.rs`（L6；依 T018）
- [ ] T020 [US1] xdb region 續跑 `real_ip`（取 resolve `.0` 餵 xdb、別誤餵 peer）in `rust-api/server/src/audit_ctx.rs::audit_mw`（FR-8；依 T016）

### Live verification for US1

- [ ] T021 [US1] live smoke（容器內、`DATABASE_URL`、`--test-threads=1`）：psql 證三表四欄真寫入（C-V-4/5；best-effort warn-drop、不只看 HTTP 200、trace_id/delta 隔離）

**Checkpoint**：US1 完成＝解析正確 + 四欄入庫，獨立可驗（MVP 可交付）。

---

## Phase 4: User Story 2 — 審計中心四欄顯示 (P2)

**Goal**：審計中心三分頁每列依序顯示四欄、可信度著色。**Independent Test**：CDP 見四欄按序 + NTag。

- [ ] T022 [US2] 三 wire DTO 改名+加欄（honest wire）in `rust-api/server/src/handler/system_manage.rs`（`OperationLogItem`/`AccessLogItem`/`LoginAttemptItem`：`client_ip→realIp`/`operator_ip→operatorRealIp` + `peerIp`/`ipConfidence`/`(operator_)xForwardedFor`；nullable 顯 null 不 skip；IP `.ip().to_string()`）（L7；依 T018）
- [ ] T023 [US2] facade list Filter struct 改名 + `ip_host_like` 字面 col 改名（`real_ip`/`operator_real_ip`）in `rust-api/server/src/model/facade/sys_{access_log,login_attempt,operation_log}.rs`（L7）
- [ ] T024 [US2] base-web `rev3-system-manage.d.ts` 三 Item + SearchParams 改名+加欄（`ipConfidence` literal union、`string|null`）in `base-web/src/typings/api/rev3-system-manage.d.ts`（L8；依 T022；honest wire）
- [ ] T025 [US2] base-web audit 三分頁四欄顯示（序 `ip_confidence`(NTag) → `peer_ip` → `real_ip` → `x_forwarded_for`；operation `operator_*`）+ `app.d.ts` Schema 先擴 + 雙 locale `page.manage.audit.*` 同 commit in `base-web/src/views/manage/audit/{index.vue,modules/*}` + `typings/app.d.ts` + `locales/langs/{zh-cn,en-us}.ts`（L8；依 T024；`rev3-inline` 紀律、scroll-x 上調）
- [ ] T026 [US2] CDP 驗四欄按序顯示 + `ip_confidence` NTag 著色（C-V-6）

---

## Phase 5: User Story 3 — 依 IP 與可信度篩選 (P2)

**Goal**：三模糊篩（real_ip/peer_ip/x_forwarded_for）+ 一下拉篩（ip_confidence）。**Independent Test**：CDP 篩選正確 + 空 param 守門。

- [ ] T027 [US3] facade 篩選：`real_ip`/`peer_ip` 模糊（`ip_host_like`）+ `x_forwarded_for` 文字 `LOWER LIKE` + `ip_confidence` 精確 `eq` in `rust-api/server/src/model/facade/sys_{access_log,login_attempt,operation_log}.rs`（L7；依 T023）
- [ ] T028 [US3] handler SearchParams 改名 + 加 `peerIp`(模糊)/`ipConfidence`(下拉)/`xForwardedFor`(模糊) filter + 空字串守門 in `rust-api/server/src/handler/system_manage.rs`（L7；依 T027）
- [ ] T029 [US3] base-web 篩選 UI：三模糊 NInput + `ip_confidence` NSelect 下拉 + SearchParams in `base-web/src/views/manage/audit/{index.vue,modules/*}`（L8；依 T025,T028）
- [ ] T030 [US3] CDP 驗三模糊+一下拉篩運作 + curl 帶空 param 抓守門回歸（C-V-6）

---

## Phase 6: User Story 4 — Cloudflare 驗證提升/標記可信度 (P2)

**Goal**：經 CF 的請求 → CDN_VERIFIED；不符 → CDN_MISMATCH。**Independent Test**：CF-path 請求 → CDN_VERIFIED。

- [ ] T031 [US4] nginx `geo $remote_addr $x_cf_verified`（CF 邊緣段）+ `map $x_cf_verified $cf_cip_safe` strip 非 CF 源 + `proxy_set_header X-CF-Verified`/`CF-Connecting-IP` in `deploy/nginx/nginx.conf` + `deploy/nginx/conf.d/_locations.inc`（L9；**不啟 realip**；既有 header 不 regress）
- [ ] T032 [US4] compose CF 設定確認（`TRUST_MODEL_FILE` 掛載 + cdn `connecting_ip_header` 範本）in `deploy/trust-model.toml` + compose（L10；多由 T002 涵蓋）
- [ ] T033 [US4] 驗 CF 端到端：`nginx -t` + `up -d --force-recreate front-nginx`；模擬 `X-CF-Verified:1`+`CF-Connecting-IP` → 相符 CDN_VERIFIED / 不符 CDN_MISMATCH（live/curl；C-V-9）

---

## Phase 7: User Story 5 — Cloudflare Tunnel 部署支援 (P3)

**Goal**：鏈無 CDN 邊緣 IP（cloudflared 本機入口）仍正確解析。**Independent Test**：tunnel 鏈 → 正確 real_ip + CDN_VERIFIED。

- [ ] T034 [US5] nginx `geo` 命中集加 cloudflared ingress（`127.0.0.1/32`/`::1/128`/docker bridge 段）in `deploy/nginx/nginx.conf` + 確認 `internal_default` 含 loopback in `deploy/trust-model.toml`（L9 + config）
- [ ] T035 [US5] 驗 Tunnel 鏈（`visitor, 127.0.0.1, my_internal` + X-CF-Verified:1）→ real_ip=visitor + CDN_VERIFIED（live；research §13 案例）

---

## Final Phase: Polish & Cross-Cutting Concerns

- [ ] T036 lint 綠：`cargo test -p server --test entity_access_lint --test endpoint_coverage_lint`（C-V-3）
- [ ] T037 migration `up→down→up` 可逆 + fresh DB 全鏈 `m001..m006`（C-V-3）
- [ ] T038 prod target image build（新 `toml` workspace dep、multi-stage COPY 無缺口）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`（C-V-8）
- [ ] T039 零回歸：既有 nginx header / 007 audit live path / `ip_host_like` / 012 既有行為 / `/health`（C-V-9）
- [ ] T040 final holistic review（fresh-agent 冷讀）：5 US / 10 FR / 7 SC 全覆蓋 + cross-unit 接縫一致（wire/filter/欄序/biz/lint）

---

## Dependencies（User Story 完成順序）

```
Setup(T001-T003) → Foundational(T004-T007) → US1(T008-T021, MVP)
                                                 ├→ US2(T022-T026)   依 US1 資料 + wire
                                                 ├→ US3(T027-T030)   依 US2 wire
                                                 ├→ US4(T031-T033)   依 US1 overlay code
                                                 └→ US5(T034-T035)   依 US1 Tier-2 + US4 nginx geo
                                              → Polish(T036-T040)
```
- **Foundational 阻塞全 US**（schema + config + state）。
- US2→US3（filter 依 display wire）；US5→US4（Tunnel 依 CF nginx geo）。
- US1 即可獨立交付（MVP）。

## Parallel execution（受 rust-serial 限制、僅標可平行檔）
- T002（deploy/compose）可與 T001/T003（rust）平行（不同檔）。
- T006（config.rs）可與 T004/T005（migration/entity）平行（不同檔、無相依）。
- **rust cargo build/test 一律 serial**（共用 target）；base-web 任務（T024/T025/T029）與 rust 任務不同 repo 可錯開，但 base-web 依 rust wire 完成。

## Implementation Strategy（MVP first）
1. **MVP = Setup + Foundational + US1**（T001–T021）：解析正確 + 四欄入庫，可獨立 demo/驗收。
2. 增量交付 US2（顯示）→ US3（篩選）→ US4（CF 驗證）→ US5（Tunnel）。
3. Polish 收尾（lint/migration 可逆/prod build/零回歸/holistic）。
4. 階段 2 由 `superpowers:executing-plans` 依**實際相依**把 tasks 重組執行單元（Workflow 驅動）、不綁定本檔編號。
