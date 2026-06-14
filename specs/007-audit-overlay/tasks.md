---
description: "Task list for 007-audit-overlay implementation"
---

# Tasks: 007-audit-overlay（存取審計 + 登入嘗試 + 真實 client IP）

**Input**: Design documents from `/specs/007-audit-overlay/`
**Prerequisites**: [plan.md](plan.md)、[spec.md](spec.md)、[research.md](research.md)、[data-model.md](data-model.md)、[contracts/verification-commands.md](contracts/verification-commands.md)

**Tests**: 本專案 TDD（constitution §I.4 / CLAUDE.md §3）—— **純函式 test-first**（resolver / active_model / trace）；**wiring 類無新單元測試、由 live smoke + C-V 覆蓋**（tasks 內明示理由）。live smoke 一律 `--test-threads=1`（serial、memory `live-ignore-tests-need-serial`）。

**Organization**: 依 spec.md 4 user story（US1/US2 = P1；US3/US4 = P2）。**實作交 `superpowers:executing-plans`（非 /speckit-implement、§I.4）**。

**路徑慣例**：rust-api monorepo — `rust-api/{xdb,entity,server,migration}/`、`deploy/`、workspace root `docker-compose*.yml`。

---

## Phase 1: Setup（共享基建）

**Purpose**: 帶入 xdb crate、deps、MSRV pin、deploy 接點。

- [ ] T001 [P] 自 rev2 **整檔原樣拷貝**（§I.5 例外、**不改**）`xdb` crate 進 `rust-api/xdb/`（`Cargo.toml`〔含 `[[bench]]`〕＋`src/{lib,searcher,ip_value}.rs`＋`benches/search.rs`＋`resources/ip2region.xdb`〔~10.5MB〕），並在 `rust-api/Cargo.toml` workspace `members` 加 `"xdb"`。來源：`fork260509-rev2-anew-rust-api`@`rev2-admin-rust-api-rebase260531`:`xdb/`（research.md R4）。
- [ ] T002 加依賴並驗 MSRV：`rust-api/Cargo.toml` workspace 加 `ipnetwork = "0.20"`、sea-orm 啟 `with-ipnetwork` feature；`entity/Cargo.toml`＋`server/Cargo.toml` 啟 `with-ipnetwork`；`server/Cargo.toml` 加 `xdb`（path dep）。`cargo update -p ipnetwork --precise <1.86-safe>` 釘 Cargo.lock，`cargo build --locked` 驗 MSRV ≤1.86（超標→降 0.19 或 Expr cast、research.md R3）。（依 T001）
- [ ] T003 [P] 補 `deploy/Dockerfile.rust-api.txt` builder 的 xdb COPY：Manifest 段 `COPY rust-api/xdb/Cargo.toml ./xdb/`、Source 段 `COPY rust-api/xdb/src ./xdb/src` ＋ `COPY rust-api/xdb/benches ./xdb/benches` ＋ `COPY rust-api/xdb/resources ./xdb/resources`；確認 build 帶 `--locked`、`--bin server`（不編 `[[bench]]`）。（research.md R4）
- [ ] T004 [P] 在 `docker-compose.dev.yml` 與 `docker-compose.prod.yml` 的 rust-api service `environment` 加 `TRUSTED_PROXY_CIDRS`（**fail-safe 預設空**；dev 可留空＝用 peer；prod 依拓撲填內網段＋CF 段）＋ `XDB_FILEPATH`（容器內 `.xdb` 路徑）。prod 檔無 environment 段需新增。（research.md R7）

---

## Phase 2: Foundational（阻塞所有 user story）

**Purpose**: 共享 audit_ctx 機制 —— entity Models、真實 IP resolver、RequestContext、全域中介層、main.rs 接線。**⚠️ 此階段完成前任何 user story 不能開工**。

- [ ] T005 [P] entity `sys_access_log` Model 於 `rust-api/entity/src/sys_access_log.rs`（10 欄逐欄鏡像 m001、`client_ip: ipnetwork::IpNetwork`、`operator_id: i64` NOT NULL）＋ `entity/src/lib.rs` 註冊 module。（data-model.md §1.1、research.md R2）（依 T002）
- [ ] T006 [P] entity `sys_login_attempt` Model 於 `rust-api/entity/src/sys_login_attempt.rs`（9 欄鏡像 m001、`operator_id: Option<i64>` NULL）＋ lib.rs 註冊。（data-model.md §1.2）（依 T002）
- [ ] T007 [P] **（test-first、MUST FAIL）** `resolve_client_ip` 純函式單元測試於 `rust-api/server/src/audit_ctx.rs`（或 `client_ip.rs`）tests：rightmost-untrusted 命中／多 hop 跳 trusted〔含 CF 段〕／IPv4·IPv6／畸形 XFF token 略過／**直連 peer 不可信→回 peer 不信 header（防偽造）**／全 trusted→fail-safe peer／空 XFF／`TRUSTED_PROXY_CIDRS` 未設→空集合→peer。（C-V-1、SC-003）（依 T002）
- [ ] T008 `resolve_client_ip(peer, xff, trusted) -> IpAddr` 純函式 impl（rightmost-untrusted＋peer-gate＋fail-safe、`ipnetwork::contains`＋`IpAddr::from_str`）＋ `TRUSTED_PROXY_CIDRS` 解析為 `Vec<IpNetwork>`（fail-safe 空）於 `rust-api/server/src/state.rs`。跑 T007 轉綠。（data-model.md §2.3、research.md R7）（依 T007）
- [ ] T009 `RequestContext` struct ＋ `audit_mw` 中介層於 `rust-api/server/src/audit_ctx.rs`：**無條件**對每請求建 ctx〔`client_ip` via T008 resolver、raw xff 原文、`region` via `xdb::search_by_ip` best-effort、`trace_id` honor `x-request-id`(≤64)/mint uuid、`operator_id` via **獨立寬鬆 bearer verify**(Some/None 永不 reject)〕塞 request extensions；`best_effort_audit` helper 吞 DbErr。**無新單元測試**（中介層 wiring、由 US1/US2 live smoke 覆蓋）。（research.md R1、data-model.md §2.1）（依 T008、T005、T006）
- [ ] T010 `main.rs` 接線於 `rust-api/server/src/main.rs`：`into_make_service_with_connect_info::<SocketAddr>()` ＋ `audit_mw` 掛 **outermost** layer（包全部含 /health、/auth/login）＋ boot `xdb::searcher_init(XDB_FILEPATH)`。**006 `enforce_mw` 一行不動**。（research.md R5）（依 T009）

**Checkpoint**: 每請求都有 RequestContext（含解析後真實 client_ip）；sink 寫入待 US1/US2。

---

## Phase 3: User Story 1 - 已認證請求的存取審計 (P1) 🎯 MVP

**Goal**: 每已認證請求記一筆 access-log（operator-gate conform DESIGN）；未認證不記。

**Independent Test**: 帶 bearer 打受保護端點→恰一列 access-log（operator 正確）；未認證/health/login→零列。

- [ ] T011 [P] [US1] **（test-first、MUST FAIL）** `access_log_active_model` 純測於 `rust-api/server/src/model/facade/sys_access_log.rs` tests：`IpAddr→IpNetwork`（/32·/128、V4/V6）、9 欄落對 ActiveModel。（C-V-2、SC-003/004）
- [ ] T012 [US1] facade `sys_access_log` 於 `rust-api/server/src/model/facade/sys_access_log.rs`：`AccessLogEvent` 結構 ＋ `access_log_active_model(&AccessLogEvent)->ActiveModel`（純 seam）＋ `write(&db, &AccessLogEvent)->Result<(),DbErr>`（單 INSERT）。跑 T011 轉綠。（data-model.md §2.2）（依 T011、T005）
- [ ] T013 [US1] access-log **operator-gate 寫入** 於 `rust-api/server/src/audit_ctx.rs` after-phase：`next.run()` 後取 `response.status()`；**`operator_id.is_some()` 才**建 `AccessLogEvent`＋`write` best-effort（`best_effort_audit` 吞錯）。**無新單元測試**（wiring、C-V-6 live 覆蓋）。（research.md R1、FR-001/002/012）（依 T012、T010）
- [ ] T014 [US1] live smoke C-V-6 於 `rust-api/server/src/model/facade/live_smoke.rs`（或新測檔、`#[ignore]`、`--test-threads=1`）：已認證 getUserInfo→一列〔operator_id 非空〕；未認證 getUserInfo／health／login→**零列**。（SC-001、FR-001/002）（依 T013）

**Checkpoint**: US1 可獨立驗（access-log operator-gate 端到端）。

---

## Phase 4: User Story 2 - 登入嘗試審計 (P1)

**Goal**: 每登入終端路徑（成敗）記一筆 login-attempt（含真實 client IP）。

**Independent Test**: 錯密碼登入→一列〔fail/無 operator/帶 IP〕；對的→一列〔success/帶 operator〕。

- [ ] T015 [P] [US2] **（test-first、MUST FAIL）** `login_attempt_active_model` 純測於 `rust-api/server/src/model/facade/sys_login_attempt.rs` tests：`IpAddr→IpNetwork`、`operator_id: Option<i64>` Set(None)/Set(Some)、各欄映射。（C-V-2）
- [ ] T016 [US2] facade `sys_login_attempt` 於 `rust-api/server/src/model/facade/sys_login_attempt.rs`：`LoginAttemptEvent` ＋ `login_attempt_active_model` ＋ `write`（單 INSERT）。跑 T015 轉綠。（data-model.md §2.2）（依 T015、T006）
- [ ] T017 [US2] login **inner/outer split** 於 `rust-api/server/src/handler/auth.rs`：outer 讀 `Extension(ctx)`，**6 個 `record_login_attempt` 呼叫點**〔5 失敗：user-not-found／password-wrong／role-lookup-error／access-token-sign-error／refresh-token-sign-error ＋1 成功 `operator_id=Some(user.id)`〕，client_ip 取自 ctx、皆 best-effort。**無新單元測試**（wiring、C-V-5 live 覆蓋）。（research.md R1、FR-004/005/011）（依 T016、T009）
- [ ] T018 [US2] live smoke C-V-5（`#[ignore]`、serial）：錯密碼 + `Super/123456` 各打→恰兩列〔fail：success=false/operator_id=NULL/client_ip 非空；success：success=true/operator_id=1〕。（SC-002）（依 T017）

**Checkpoint**: US1 ＋ US2 各自可獨立驗。

---

## Phase 5: User Story 3 - 反向代理後方的真實 client IP (P2)

**Goal**: 代理鏈後方記下的 client IP 為真實終端 IP（非代理）；偽造 forwarded 不採信。

**Independent Test**: 經可信代理鏈（設 `TRUSTED_PROXY_CIDRS`、帶 XFF）→ client_ip = 真實 client；不可信來源偽造→忽略。

> 核心 resolver impl ＋ 純測在 Foundational（T007/T008、audit_ctx 依賴）；本 story = config 接線 ＋ 端到端真實 IP/防偽造 live 驗收。

- [ ] T019 [US3] trusted-proxy config 接線驗證：確認 `TRUSTED_PROXY_CIDRS`（compose T004）→ `state.rs`（T008）→ resolver 全鏈通；在 `deploy/` 或 plan 補 prod CF IP 段填寫指引（線上維護）。（research.md R7、FR-006/007）（依 T004、T008）
- [ ] T020 [US3] live smoke（`#[ignore]`、serial）：設 `TRUSTED_PROXY_CIDRS=<內網段>`，經 front-nginx 帶 XFF 打請求 → psql 查 `sys_access_log.client_ip` = 真實 client（跳代理 hop）；直連帶偽造 XFF → 採直連、偽造被忽略。（SC-003、FR-006/007）（依 T013 或 T017）

**Checkpoint**: 真實 IP 端到端可驗（含防偽造）。

---

## Phase 6: User Story 4 - 操作審計的 operator/trace/IP 補全 (P2)

**Goal**: 既有 op-log 帶真 operator/trace/operator_ip（解 005 §3.8 42804 defer）。

**Independent Test**: 已認證操作者執行可審計異動→op-log 末列 operator_id/operator_ip/trace_id 全非空。

- [ ] T021 [P] [US4] **（test-first、MUST FAIL）** op-log `audit_active_model` 的 `Some(ip)` 分支純測於 `rust-api/server/src/model/facade/sys_operation_log.rs` tests：`Some(ip)`→真 INET（IpNetwork）、`None`→NotSet（保留 005 既有斷言 `!sql.contains("operator_ip")`）。（C-V-2、FR-013）
- [ ] T022 [US4] 型遷移：`rust-api/entity/src/sys_operation_log.rs` `operator_ip: Option<String>`→`Option<ipnetwork::IpNetwork>`；`rust-api/server/src/model/audit.rs` `AuditOperator.ip: Option<String>`→`Option<std::net::IpAddr>`。（research.md R6、data-model.md §1.3）（依 T002）
- [ ] T023 [US4] facade `sys_operation_log` 啟用現 defer 的 `Some(ip)` 分支於 `rust-api/server/src/model/facade/sys_operation_log.rs`：`Some(ip)`→`Set(Some(IpNetwork::from(ip)))`（真 INET、解 42804）、`None`→`NotSet` 保留。跑 T021 轉綠。（research.md R6）（依 T021、T022）
- [ ] T024 [US4] op-log **operator/trace 回填** 於 handler 寫路徑：把 `RequestContext` 的 `operator_id`/`trace_id`/`client_ip` 餵進 005 `mutate_in_txn` 的 `AuditEvent`（operator/trace 由恆 None→真值）。**無新單元測試**（wiring、C-V-7 live 覆蓋）。（FR-013、research.md R1/R6）（依 T023、T009）
- [ ] T025 [US4] 回歸 + 新增 live：005 既有 None-path 單元（`audit_active_model...omits_operator_ip`）＋ 3 live smoke（commit/no-op/rollback、`--test-threads=1`）**續綠**；新增 C-V-7 live：已認證異動→op-log 末列 operator_id/operator_ip/trace_id 全非空。（SC-006）（依 T024）

**Checkpoint**: 四 user story 各自可獨立驗。

---

## Phase 7: Polish & Cross-Cutting

- [ ] T026 [P] `entity_access_lint` 續綠（C-V-9）：新增 audit_ctx/facade/resolver 走 facade、不碰 raw `entity::`（004 lint 不退）。`cargo test -p server entity_access_lint`。
- [ ] T027 [P] best-effort 不阻請求驗證（SC-005、FR-012）：停 PG（或斷 audit 寫）後打已認證請求 → 仍正常回應、audit 列丟棄＋`tracing::warn`。
- [ ] T028 **prod image build（mandatory、xdb 新 crate、CLAUDE.md §3）** C-V-8：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（xdb COPY 全在〔缺則 RED→GREEN 證 gate〕、`--locked` 防 ipnetwork un-pin、`--bin server` 跳 bench）。（依 T003、T002）
- [ ] T029 [P] 跑 `quickstart.md` 端到端驗證（A 純測 → G prod build 全綠）。
- [ ] T030 [P] 收尾文件殘留檢查：auth/audit 內容零 rev2 token（以「前代」描述、§I.5/⚠️g）；deploy CF 段指引就位。

---

## Dependencies & Execution Order

### Phase 依賴
- **Setup (P1)**：無依賴、即起。
- **Foundational (P2)**：依 Setup；**阻塞所有 user story**。
- **US1/US2/US3/US4 (P3–6)**：皆依 Foundational 完成；之後可並行（或依優先序 US1→US2→US3→US4）。
- **Polish (P7)**：依所有 user story 完成。

### User Story 依賴
- **US1（P1、MVP）**：依 Foundational；獨立可測。
- **US2（P1）**：依 Foundational（共用 audit_ctx ctx/login outer 讀 ctx）；獨立可測。
- **US3（P2）**：核心 resolver 在 Foundational；本 story 為 config＋live 驗收；獨立可測。
- **US4（P2）**：依 Foundational（餵 ctx 進 005 mutate_in_txn）；含 entity 型遷移、與 005 回歸綁。

### Story 內順序
- test-first 純測（resolver/active_model）先寫且 FAIL → impl 轉綠 → wiring → live smoke。
- entity Model 先於 facade；facade 先於 audit_ctx 寫入/handler 接線。

---

## Parallel Opportunities

- **Setup**：T001 後，T003/T004 可 [P]（不同檔）。
- **Foundational**：T005/T006/T007 可 [P]（不同檔；T007 為 resolver 純測、與 entity 無關）。
- **跨 story**：Foundational 完成後 US1/US2/US3/US4 可並行（不同檔為主；注意 T013 與 T017 都動 audit_ctx/handler 不同段、T024 動 handler 寫路徑——同檔者勿並行）。
- **Polish**：T026/T029/T030 可 [P]。

### Parallel Example: Foundational
```bash
# 同時起（不同檔）：
Task: "T005 entity sys_access_log Model"
Task: "T006 entity sys_login_attempt Model"
Task: "T007 resolve_client_ip 純測（test-first）"
```

---

## Implementation Strategy

### MVP First（US1 only）
1. Phase 1 Setup → 2. Phase 2 Foundational（CRITICAL、阻塞）→ 3. Phase 3 US1 → **STOP & VALIDATE**（C-V-6：access-log operator-gate 端到端）→ MVP 可 demo。

### Incremental
Setup+Foundational → US1（access-log、MVP）→ US2（login-attempt）→ US3（真實 IP 驗收）→ US4（op-log 回填）→ Polish（prod build C-V-8、lint、best-effort、quickstart）。每 story 加值不破前者。

---

## Notes

- [P]＝不同檔、無未完依賴；[US#] 對映 spec user story。
- **純函式 test-first**（T007/T011/T015/T021）：先寫測、FAIL、再 impl 轉綠。
- **wiring 無新單元測試**（T009/T013/T017/T024）：理由＝中介層/handler 接線、由 live smoke（C-V-5/6/7）＋ curl 覆蓋（CLAUDE.md §3 明示）。
- live smoke 一律 `--test-threads=1`（serial）。
- **新 crate xdb → C-V-8 prod build 為 acceptance 硬條件**（不可只靠 dev bind-mount）。
- 收尾走 `superpowers:finishing-a-development-branch`（多段式 commit → `merge --no-ff` 回 rev3-admin-root、保留 feature branch）；**push/merge 不得出現在 finishing 之前**（§I.4）。
