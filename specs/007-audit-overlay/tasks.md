# Tasks: 007-audit-overlay（audit overlay＝access-log＋login-attempt＋真實 client IP＋region）

**Input**: Design documents from `/specs/007-audit-overlay/`

**Prerequisites**: plan.md ✅、spec.md ✅（5 US／16 FR／9 SC／16-16 checklist／NEEDS CLARIFICATION=0）、research.md（R1~R9 全 grep ground-truth）✅、data-model.md（RequestContext／resolve_client_ip／2 facade／login inner-outer／op-log seam／xdb boot）✅、contracts/（verification-commands C-V-0~9＋audit-overlay-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS、§5.9 推進＝DESIGN-detail 對齊）

**Tests**: 本 feature **有純函式測＋活體測**。純測＝in-crate `#[cfg(test)]`（resolve_client_ip〔trusted-proxy/anti-spoof/fail-safe〕／facade `*_active_model`〔IpAddr→IpNetwork〕／extract_trace_id、test-first 精神）；活體＝live psql/curl（access-log operator-gate／login-attempt 成敗各列／INET no-42804＋region／op-log threading test-only smoke）；lint＝既有 `entity_access_lint`。

**Organization**: 依 user story 分 phase。**rust 全程 serial**、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime 假綠）；**live `#[ignore]` 一律 `--test-threads=1`**；**兩段式 commit**（rust-api worktree→outer pin、不延後）；**§I.4：全程不 push/merge**。**含 prod build**（新 crate xdb、C-V-8、R9）。**地基已 provisioned**：entity Model／with-ipnetwork／operator_ip INET〔004/005〕／nginx XFF 轉發〔001〕。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（xdb crate 拷入＋dep、blocking 全 US）

**Purpose**: §I.5/⚠️v 整檔拷貝 xdb、workspace 接線。⚠️ 動 rust-api worktree——兩段式 commit。

- [ ] T001 [P] `rust-api/xdb/`（新 crate）整檔拷入：`git show rev2-admin-rust-api-rebase260531:xdb/<檔>` 自 `fork260509-rev2-anew-rust-api` 取 `Cargo.toml`（含 `[[bench]] name=search harness=false`）／`src/{lib,searcher,ip_value}.rs`／`benches/search.rs`／`resources/{ip2region.xdb(~10.5MB), ip.test.txt}`（整檔零改、§I.5）。`rust-api/Cargo.toml` workspace members 加 `"xdb"`＋暴露 `once_cell = "1"`（或對應版）為 workspace dep（research R1）
- [ ] T002 `rust-api/server/Cargo.toml` 加 `xdb = { path = "../xdb" }`；容器內 `cargo build -p server --locked` 解析綠（xdb 連結、`ipnetwork` 走 `sea_orm::entity::prelude::IpNetwork` re-export 不顯式加、R1/R3）

**Checkpoint**: xdb crate 解析、build 可繼續（待 T011 build 全綠驗）

## Phase 2: Foundational（audit_ctx 機制＋resolver＋state/config＋main 接線；blocking 全 US）

**Purpose**: 全域 audit overlay 機制本體（每請求建 RequestContext＋已認證寫 access-log）＋真實 IP 解析＋xdb boot——US1~US5 共享前置。

- [ ] T003 [P] `rust-api/server/src/audit_ctx.rs`（新）`resolve_client_ip(peer:IpAddr, xff:Option<&str>, trusted:&[IpNetwork])->IpAddr`（test-first：先寫 `#[cfg(test)]` 純測〔rightmost-untrusted／多 hop 跳 trusted〔含 CF 段〕／IPv4·IPv6／畸形 token 略過／直連 peer 不可信→回 peer〔anti-spoof〕／全 trusted·空 XFF→peer〕再 impl：①peer-gate ②rightmost-untrusted ③fail-safe；`is_trusted` 用 `IpNetwork::contains`）（data-model §2、C-V-1、SC-003）
- [ ] T004 [P] `rust-api/server/src/audit_ctx.rs` `extract_trace_id(&HeaderMap)->String`（test-first：honor `x-request-id`〔trim、chars().take(64) UTF-8-safe、非空〕否則 `Uuid::new_v4`；純測）（data-model §3、C-V-3、FR-010/SC-005）
- [ ] T005 `rust-api/server/src/{state,config}.rs`（改）：`AppState` 加 `trusted_proxy_cidrs: Vec<IpNetwork>`＋`xdb_ready: bool`（保 derive Clone）；`config.rs` 載 `TRUSTED_PROXY_CIDRS`（comma CIDR→`Vec<IpNetwork>`、parse 失敗/未設→空 fail-safe）＋`XDB_FILEPATH`（沿 `_FILE`/env 模式、default `resources/ip2region.xdb`）（data-model §9、R4）
- [ ] T006 `rust-api/server/src/model/facade/sys_access_log.rs`（新）＋`facade/mod.rs` 加 `pub mod sys_access_log;`：`AccessLogEvent{operator_id:i64,method,path,http_status:i32,client_ip:IpAddr,x_forwarded_for,region,trace_id}`＋`access_log_active_model(&Event)->ActiveModel`（**IpAddr→`IpNetwork::from` seam、純測** C-V-2）＋`write(&db,&Event)->Result<(),DbErr>`（單 INSERT、append-only、entity:: 合法）（data-model §5.1、FR-003）
- [ ] T007 `rust-api/server/src/audit_ctx.rs` `RequestContext`＋`audit_mw(State,ConnectInfo<SocketAddr>,Request,Next)->Response`（無 Result）：前段無條件建 ctx〔client_ip via T003、raw xff、region via `xdb::search_by_ip` **僅 `state.xdb_ready` 時**否則 None、trace via T004、operator_id via 寬鬆 bearer `enforce::bearer(headers,&state.jwt).ok().map(|c|c.uid)`〕塞 extensions；後段取 http_status、**gate=`operator_id.is_some()`** 才 `best_effort_audit(sys_access_log::write(...))`〔吞 DbErr via tracing::warn〕。**enforce_mw 一行不動**、不得 path-root `entity::`（data-model §4、R5、FR-001/002/008/009/011/012）
- [ ] T008 `rust-api/server/src/main.rs`（改）：`mod audit_ctx;`＋xdb dep；boot **`Path::exists(xdb_path)` 守門→`xdb_ready`→`xdb::searcher_init(Some(path))`**（缺檔不呼、warn 降級、R1 PANIC gotcha）；`axum::serve(listener, app.layer(from_fn_with_state(state, audit_mw)).into_make_service_with_connect_info::<SocketAddr>())`（audit_mw **最外層**）（data-model §8、R5）
- [ ] T009 `docker-compose.dev.yml`／`docker-compose.prod.yml`（改）：rust-api env 加 `TRUSTED_PROXY_CIDRS`（dev 空＝peer／prod 內網+CF 段）＋`XDB_FILEPATH`（指 xdb resources）（R6）
- [ ] T010 op-log threading helper **於 `rust-api/server/src/audit_ctx.rs`**（`RequestContext` 上的 method，如 `to_audit_operator(&self, uid:i64) -> (AuditOperator, Option<String>)`：回 `AuditOperator{id:uid, ip:Some(IpNetwork::from(self.client_ip))}`＋`trace_id:Some(self.trace_id.clone())`；`use crate::model::audit::AuditOperator`〔非 path-root entity::、lint-safe〕）→ 餵既有 `mutate_in_txn`；**無 live mutating handler、僅立 helper**、波1+ 用（data-model §7、R7、FR-013）
- [ ] T011 C-V-0 build＋C-V-1/2/3 純測＋C-V-9 lint：容器內 force-touch→`cargo build -p server --locked` 綠／`cargo test -p server resolve_client_ip active_model trace_id`（警覺「0 passed/N filtered」假綠）／`cargo test -p server --test entity_access_lint`（audit_ctx/handler/config/state 零 path-root `entity::`）（依 T003~T010）

**Checkpoint**: 機制核心＋build 綠＋純測綠（resolver/active_model/trace_id）＋lint 綠 → **雙段 commit**（worktree→pin）

## Phase 3: US1 — 登入事件稽核軌（含真實來源 IP）(P1) 🎯 MVP

**Goal**: login 每終端結果 exactly-one login-attempt（成敗皆記、失敗帶 IP）。
**Independent Test**: C-V-5 錯密碼＋`Super/123456` 各打→psql 成敗各一列；不依賴 US2~US5。

- [ ] T012 [US1] `rust-api/server/src/model/facade/sys_login_attempt.rs`（新）＋`facade/mod.rs` 加 `pub mod sys_login_attempt;`：`LoginAttemptEvent{attempted_user_name,success:bool,operator_id:Option<i64>,client_ip:IpAddr,x_forwarded_for,region,trace_id}`＋`login_attempt_active_model`（`IpNetwork::from`＋operator_id Set(None)/Set(Some)、純測 C-V-2）＋`write`（append-only）（data-model §5.2、FR-004/005）
- [ ] T013 [US1] `rust-api/server/src/handler/auth.rs`（改）login inner/outer split：`login_inner(...)->Result<Success,(Option<i64> operator, AppError)>`（沿 006 流程、各 `?` 映射：pre-identity〔not-found/lookup-DbErr/password-wrong〕→`(None,_)`；post-identity〔roles/sign/timestamp/txn〕→`(Some(uid),_)`）；outer `login(State,Extension<RequestContext>,Json<LoginReq>)` 對結果**記 exactly-one** login_attempt（Ok→success+Some(uid)／Err→fail+operator）再回 AppError；client_ip/region/xff/trace 取 ctx（data-model §6、R2、FR-004/005/011）
- [ ] T014 [US1] C-V-5 live（stack healthy、`--test-threads=1` 若走 #[ignore]）：錯密碼+`Super/123456` 各打→psql `sys_login_attempt` 末 2 列〔失敗 success=false/operator_id=NULL/has_ip=true；成功 success=true/operator_id=1〕、每終端結果恰一列。對應 SC-002（依 T012/T013/T007）

**Checkpoint**: US1 全綠＝MVP（SC-002；login-attempt 成立）→ **雙段 commit**

## Phase 4: US2 — 已認證請求稽核軌（P2）

**Goal**: access-log operator-gate（已認證 1 列／未認證 0 列）。
**Independent Test**: C-V-6 authed getUserInfo→1 列、未認證/health/login→0 列；機制在 T006/T007 已落、本 phase 為 acceptance。

- [ ] T015 [US2] C-V-6 live：login→token→getUserInfo 帶 bearer（→1 列 operator 非空/method=GET/path/http_status=200）／不帶 bearer＋/health＋login（→0 列）；psql `sys_access_log`。對應 SC-001（依 T007/T008）

**Checkpoint**: US2 全綠（SC-001）→ **雙段 commit**（或併前段）

## Phase 5: US3 — 反代後方的可信來源 IP（防偽造）(P2)

**Goal**: 真實 client IP trusted-proxy 解析（C-V-1 純測已證、本 phase 補 live behind-proxy）。
**Independent Test**: C-V-1（T003 純測：anti-spoof/fail-safe）＋ live：設 `TRUSTED_PROXY_CIDRS`、經 front-nginx 帶 XFF。

- [ ] T016 [US3] live behind-proxy：dev 設 `TRUSTED_PROXY_CIDRS=<docker/nginx 段>`、經 front-nginx（:31080）帶 `X-Forwarded-For: <真client>, <nginx>` 打請求 → psql `sys_access_log`/`sys_login_attempt` `client_ip`＝真 client（跳 trusted hop）；直連 :31081 帶偽造 XFF（peer∉trusted）→ 採直連 peer、偽造忽略。對應 SC-003（依 T003/T007/T013、C-V-1 為主證）

**Checkpoint**: US3 全綠（SC-003）→ **雙段 commit**（或併前段）

## Phase 6: US4 — 地區標註與優雅降級（P3）

**Goal**: region 由 client_ip 解（私有→内网IP）＋xdb 缺檔優雅降級。
**Independent Test**: C-V-4 psql region；缺檔啟動驗降級。

- [ ] T017 [US4] C-V-4 live：觸認證請求→psql `sys_access_log` 末列 `client_ip`（真 INET、**無 PG 42804**）／`region`（私有/內網→非空「内网IP」類）；**降級驗**：移走/誤設 `.xdb` 啟動→boot warn＋`xdb_ready=false`＋請求仍成、region NULL、**不崩潰**。對應 SC-004/SC-007（依 T007/T008）

**Checkpoint**: US4 全綠（SC-004/007）→ **雙段 commit**

## Phase 7: US5 — 操作日誌的操作者歸屬就緒（P3）

**Goal**: op-log operator/operator_ip/trace threading seam（test-only smoke、live 回填波1+）。
**Independent Test**: C-V-7 test-only live smoke。

- [ ] T018 [US5] C-V-7 test-only live smoke（in-crate `#[cfg(test)] #[ignore]` **置 `rust-api/server/src/model/facade/sys_user.rs`**〔既有 `soft_delete` live smoke 旁〕、fn 名含 `oplog_threading`〔對齊 C-V-7 filter〕、`--test-threads=1`、`DATABASE_URL=$(cat /run/secrets/database_url)`）：顯式構造 `AuditOperator{id,ip:Some(IpNetwork::from(client_ip))}`＋trace 餵 `soft_delete`/`mutate_in_txn`→psql op-log 末列 `operator_id`/`operator_ip`/`trace_id` 由恆 None→真值（INET round-trip）。對應 SC-006（依 T010）

**Checkpoint**: US5 全綠（SC-006）→ **雙段 commit**

## Phase 8: Polish & Cross-Cutting

- [ ] T019 `deploy/Dockerfile.rust-api.txt`（改）：xdb COPY（Manifest `xdb/Cargo.toml`＋Source `xdb/src`＋`xdb/benches`＋`xdb/resources`）；保 `--bins`（跳 `[[bench]]` 編譯）；builder `cargo build` `--locked`（R9）
- [ ] T020 C-V-8 **prod target image build**（★新 crate 紀律、R9）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（含 xdb、`[[bench]]` 不撞、`--locked`）；驗 `.xdb` 在 image 內、prod boot log `xdb_ready=true`。對應 SC-008（依 T019）
- [ ] T021 C-V-9 收口驗證（**commit only——push/merge 凍結至 finishing、§I.4**）：rust-api worktree 全 task commit 齊＋outer pin == worktree HEAD（pin 隨 task bump 紀律）＋specs/007 外層檔收；`git submodule status` rust-api 行首空格；**C-V-0~9 全綠彙整**（build／3 純測／lint／live login-attempt·access-log·trusted-IP·region·op-log-smoke／prod build）；**SC-009 零回歸實證**：`curl -fsS http://127.0.0.1:31081/health` 回 `ok`；**範圍核**：diff 確認零 migration/entity/型遷移/base-web/i18n/nginx 變動、無 audit 讀端/lockout/retention；quickstart 10 步逐步對照綠

## Dependencies

```
Setup (T001~T002) ─→ Foundational (T003~T011)  [rust-api worktree、serial]
   T001（xdb crate+member）→ T002（server dep）→ build 可續
   T003/T004（resolver/trace_id 純函式 [P]）／T005（state/config）／T006（access_log facade）→ T007（audit_mw 用 resolver/facade/state）→ T008（main 掛 audit_mw+xdb boot）／T009（compose env）／T010（op-log seam）→ T011（build綠+純測+lint）
Foundational ──┬─→ US1 (T012→T013→T014)   [login-attempt：facade→login split→live]
               ├─→ US2 (T015)              [access-log live acceptance（機制 T006/T007）]
               ├─→ US3 (T016)              [trusted-IP live（純證 C-V-1=T003）]
               ├─→ US4 (T017)              [region live+降級（xdb T001/T008）]
               └─→ US5 (T018)              [op-log threading smoke（seam T010）]
US1~US5 ──→ Polish (T019→T020→T021)        [Dockerfile→prod build→收口]
```

## Parallel Execution Examples

- **概念並行**：T003（resolve_client_ip）∥ T004（extract_trace_id）——同檔不同純函式、可並行撰寫。facade T006（access_log）／T012（login_attempt）不同檔可並行撰寫。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔/邏輯可並行撰寫」、cargo build/test 一次一個。
- **US2/US3/US4/US5 多為 acceptance phase**（機制在 Foundational）、可緊接 US1 後驗、彈性併段 commit。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T014）＝Setup（xdb）＋Foundational（audit_ctx 機制＋resolver＋state/config＋main 接線）＋US1（login-attempt proof）即最小價值（登入事件稽核成立）。US2 access-log（T015）／US3 trusted-IP（T016）／US4 region（T017）／US5 op-log seam（T018）緊接；Polish 收口（**prod build**／零回歸／範圍核）。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進。**★ 實作第一步＝xdb crate 拷入＋boot 缺檔 `Path::exists` 守門**（searcher_init 缺檔 panic、R1）。**rust serial、容器內 build/test、改 .rs 先 force-touch、live `--test-threads=1`；兩段式 commit（worktree→pin）；全程不 push/merge；新 crate→必跑 prod build（C-V-8）**。

> **階段 2 交棒注記**（CLAUDE.md §3）：實作以 `superpowers:executing-plans` 起手、**Workflow 驅動**，依**實際相依/獨立可審邊界**重分執行單元（不綁本檔編號）——預期 Foundational（T003~T011）為一大 load-bearing 單元（build 綠前不可分），US1 facade+split 為一單元，其餘 acceptance 可併。
