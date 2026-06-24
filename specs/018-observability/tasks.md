---
description: "Task list — 018-observability"
---

# Tasks: Observability（波 4）

**Input**: 設計文件於 `specs/018-observability/`（[plan.md](plan.md)／[spec.md](spec.md)／[research.md](research.md)／[data-model.md](data-model.md)／[contracts/](contracts/)／[quickstart.md](quickstart.md)）

**Tests**: 本刀 **不採 test-first**——obs 以 compose/YAML/JSON config + rust **wiring** 為主、無新純函式邏輯（plan §測試策略明示「無單元測試及理由」）；驗證由 **acceptance C-V**（[contracts/verification-commands.md](contracts/verification-commands.md)）覆蓋，列於各 story checkpoint。

**Organization**: 按 user story 組織。執行單元對映：**US1→U1 obs-min ｜ US2→U2 obs-full(metrics) ｜ US3→U2(alerts) ｜ US4→U3 dashboard**（漸進序 constitution #8）。

> **★ 紀律（烤進每個實作單元、constitution §I.4／CLAUDE.md §3-4）**：rust 全程 **serial**（共用 target、勿平行 cargo）；rust build/test 在 rust-api 容器內 `docker exec`（live `--test-threads=1`）；**rust 改動（`rust-api/**`）走 worktree commit→bump submodule pin（§4.1、逐單元邊界、不延末刀）**；deploy/compose 改動為 outer（feature branch）單段 commit；base-web 零改；**★ 絕不 `git push`／`git merge`**（留 finishing-a-development-branch）。

## Format: `[ID] [P?] [Story] Description（含檔路徑）`
- **[P]**：可平行（不同檔、無未完相依）；rust 任務即使跨 story 亦 **不[P]**（serial）。

---

## Phase 1: Setup（共享基建）

- [ ] T001 [P] 新增 `grafana_admin_password` secret：`deploy/generate-secrets.sh` 加 `gen_leaf grafana_admin_password`（4→5 leaf）＋新 `deploy/secrets/grafana_admin_password.txt.example`；跑 `bash deploy/generate-secrets.sh` 重生（research R6／DESIGN:706 落差）
- [ ] T002 加 obs rust dep（compat ceiling、research R1）：`rust-api/server/Cargo.toml` +`axum-prometheus = "0.7.0"` +`metrics = "0.23"`（rev2 載重註解逐字帶入：axum-0.7 相容最後版／metrics 須對齊 0.23 transitive）；`rust-api/cleanup-job/Cargo.toml` +`metrics = "0.23"` +`metrics-exporter-prometheus = { version = "0.15", default-features = false }` +`ureq = { version = "2", default-features = false }`；workspace `tracing-subscriber` 開 `json` feature；以 rev2 known-good 版 seed `rust-api/Cargo.lock`

---

## Phase 2: Foundational（阻塞前置）

**⚠️ CRITICAL**：T003 MSRV gate 未過、任何 rust 埋点不得續；T004 compose 宣告區為各服務引用前置。

- [ ] T003 ★ MSRV gate（research R1、最高風險、容器內）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api sh -c 'cd /app && cargo build -p server -p cleanup-job'` 綠 ＋ `cargo tree -i time`（**僅** simple_asn1→jsonwebtoken path、obs 未引 time edge）＋ `cargo tree -i portable-atomic && cargo tree -i quanta && cargo tree -i zerofrom`（對齊 1.86-known-good）；任一報 `requires rustc 1.8x` → pin 至 rev2 known-good 重 build（[C-V-MSRV](contracts/verification-commands.md)）
- [ ] T004 `docker-compose.yml` top-level：`secrets:` 加 `grafana_admin_password`（file 指 `./deploy/secrets/grafana_admin_password.txt`）；`volumes:` 加 `loki_data`／`grafana_data`／`alloy_data`／`prometheus_data`（無顯式 name、profile-gated、正典命名 §8.2.2）

**Checkpoint**: deps 解析 ＋ MSRV 確證 ＋ compose 宣告就緒 → user story 可開始

---

## Phase 3: User Story 1 — 集中日誌＋審計關聯 (Priority: P1) 🎯 MVP ｜ U1 obs-min

**Goal**: 全容器 stdout 集中可查，且 log 行可經 `trace_id` join DB 審計列。
**Independent Test**: `--profile obs` 起，發請求 → loki LogQL `{compose_project="rev3-admin"}` 查到 log；`| json | fields_trace_id="<x>"` 與 `sys_access_log.trace_id` 同值。

- [ ] T005 [US1] rust log span：`rust-api/server/src/audit_ctx.rs` audit_mw 於 `next.run(req).await`（~L364）改 `.instrument(info_span!("request", trace_id = %trace_id, method = %method, path = %path))`（async-aware、trace_id 已於 ~L348 算出；勿用 sync `_enter` 跨 await）
- [ ] T006 [US1] rust json subscriber：`rust-api/server/src/main.rs`（~L55-59）`fmt()` 鏈於 `.with_env_filter(...)` 與 `.init()` 間插 `.json()`（tracing-subscriber json feature 已於 T002；event 欄位巢狀 `fields.trace_id`）→ worktree commit（U1 rust）＋ **bump rust-api pin**（§4.1）
- [ ] T007 [P] [US1] 新建 `deploy/loki-config.yml`（filesystem TSDB schema v13、`retention 72h`、`auth_enabled: false`、http :3100）
- [ ] T008 [P] [US1] 新建 `deploy/alloy-config.alloy`（`discovery.docker` 讀 docker.sock、★ relabel **keep `__meta_docker_container_label_com_docker_compose_project == "rev3-admin"`**、compose-service→`service`／container→`container`／project→`compose_project`、`loki.write` → loki:3100）
- [ ] T009 [US1] `docker-compose.yml` services 加 `loki`(grafana/loki:3.7.2,`profiles:[obs]`)／`alloy`(grafana/alloy:v1.16.1,`[obs]`,`user:root`,docker.sock RO)／`grafana`(grafana/grafana:13.0.2,`profiles:[obs,metrics]`,`GF_SECURITY_ADMIN_PASSWORD__FILE`,`GF_AUTH_ANONYMOUS_ENABLED=false`)；depends_on `alloy`→loki、`grafana`→loki `{condition:service_started,required:false}`；卷 loki_data/grafana_data/alloy_data
- [ ] T010 [P] [US1] 新建 `deploy/grafana-provisioning/datasources/loki.yml`（uid `loki`、isDefault、editable:false、★ +`deleteDatasources: [{name: Loki, orgId: 1}]` guard 免 grafana uid crash-loop）
- [ ] T011 [US1] `docker-compose.dev.yml` obs override：grafana host `33000:3000`、loki host `33100:3100`；bind-mount loki-config.yml／alloy-config.alloy／grafana-provisioning（:ro）

**Checkpoint US1**: 跑 [C-V-1](contracts/verification-commands.md)（log 採集）＋ [C-V-2](contracts/verification-commands.md)（★ log↔audit trace_id 關聯）→ U1 worktree commit + outer commit + bump pin 完成

---

## Phase 4: User Story 2 — 指標可觀測＋依賴健康 (Priority: P2) ｜ U2 obs-full(metrics)

**Goal**: rust-api/PG/redis/job 指標可 scrape 查詢。
**Independent Test**: `--profile metrics` 起，`/metrics` 含 axum_http_*／casbin_enforce_total{decision}；pushgateway 含 cleanup_job_*；prometheus 4 target up。
**Depends**: US1（grafana service 已在；本 story 擴 prometheus datasource）。

- [ ] T012 [US2] rust `/metrics`：`rust-api/server/src/main.rs` router build（~L555）前 `let (prometheus_layer, metric_handle) = axum_prometheus::PrometheusMetricLayer::pair();`（main 唯一呼叫者、無 OnceLock guard）；~L556 public route `.route("/metrics", get(move || async move { metric_handle.render() }))`（無 JWT/enforce）；~L574 audit_mw `.layer()` 後插 `.layer(prometheus_layer)`（更外層、endpoint=matched-path 低基數）
- [ ] T013 [US2] rust enforce counter：`rust-api/server/src/auth/enforce.rs` `enforce_role_path_method` allow site(~L124) `metrics::counter!("casbin_enforce_total","decision"=>"allow").increment(1)`、deny site(~L126/127) `…"deny"…`（★ 唯一 label decision、勿加 path/method/role；fail-closed DB-error 走 require_policy `?` 不計、research R3 取捨）
- [ ] T014 [US2] rust cleanup push：`rust-api/cleanup-job/src/main.rs` 加 `fn push_metrics(now_epoch:i64, deleted:u64)`（`PrometheusBuilder::new().install_recorder()` + `metrics::gauge!("cleanup_job_last_success_timestamp").set(...)`/`cleanup_job_rows_deleted` + `ureq::put("http://pushgateway:9091/metrics/job/cleanup_job").send_string(render)`、best-effort 只 warn 不改 exit；★ now_epoch 用 `std::time::SystemTime`（不引 chrono）；execute=rows_affected/dry-run=0）；於 main 匯流點(~L63)呼叫 → worktree commit（U2 rust）＋ **bump rust-api pin**（§4.1）
- [ ] T015 [P] [US2] 新建 `deploy/prometheus/prometheus.yml`（global scrape_interval 15s、4 job：`rust-api`→`rust-api:31081` metrics_path /metrics／`postgres`→`postgres_exporter:9187`／`redis`→`redis_exporter:9121`／`pushgateway`→`pushgateway:9091` `honor_labels:true`；★ job 名不可改＝alert selector；retention 15d via command flag）
- [ ] T016 [US2] `docker-compose.yml` services 加 `prometheus`(prom/prometheus:v3.12.0,`[metrics]`,卷 prometheus_data)／`postgres_exporter`(prometheuscommunity/postgres-exporter:v0.19.1,`[metrics]`,`DATA_SOURCE_PASS_FILE=/run/secrets/postgres_password` reuse、DATA_SOURCE_URI 核 rev3 DB 名)／`redis_exporter`(oliver006/redis_exporter:**v1.85.0-alpine** ★,`[metrics]`,sh-wrapper `export REDIS_PASSWORD=$(cat /run/secrets/redis_password); exec /redis_exporter`)／`pushgateway`(prom/pushgateway:v1.11.3,`[metrics]`)
- [ ] T017 [P] [US2] 新建 `deploy/grafana-provisioning/datasources/prometheus.yml`（uid `prometheus`、httpMethod POST、timeInterval 15s）
- [ ] T018 [US2] `docker-compose.dev.yml` metrics override：prometheus host `33090:9090`、pushgateway host `39091:9091`；bind-mount prometheus.yml

**Checkpoint US2**: 跑 [C-V-3](contracts/verification-commands.md)（metrics 全類別＋enforce allow/deny＋cleanup gauge）→ U2 worktree commit + outer commit + bump pin 完成

---

## Phase 5: User Story 3 — 基線告警 (Priority: P3) ｜ U2(alerts)

**Goal**: 3 baseline 規則 provision、條件成立轉告警中（v1 不投遞）。
**Independent Test**: prometheus/grafana 見 3 rule；停 postgres_exporter → infra-exporter-down 經 2m Alerting。
**Depends**: US2（指標 + prometheus datasource）。

- [ ] T019 [US3] 新建 `deploy/grafana-provisioning/alerting/rules.yml`（group `obs-full-baseline`、interval 1m、datasourceUid prometheus、noData/execErr=Alerting）：`obsfull-rustapi-down`(`up{job="rust-api"}`<1,for 2m,critical)／`obsfull-infra-exporter-down`(`up{job=~"postgres|redis"}`<1,2m,critical)／`obsfull-rustapi-high-5xx`(`sum(rate(axum_http_requests_total{status=~"5.."}[5m]))/clamp_min(sum(rate(axum_http_requests_total[5m])),1)`>0.05,5m,warning)；**不** provision contact point/notification policy（D3）

**Checkpoint US3**: 跑 [C-V-4](contracts/verification-commands.md)（3 rule + 模擬 down 轉 Alerting）

---

## Phase 6: User Story 4 — 預配置觀測儀表板 (Priority: P3) ｜ U3 dashboard

**Goal**: 6 dashboard 預配置、datasource 自動接、無手動設定。
**Independent Test**: 打開 grafana → 6 dashboard 載入、datasource 接妥、audit-log 顯本工作區 log。
**Depends**: US1（loki ds）+ US2（prometheus ds）。

- [ ] T020 [US4] 新建 `deploy/grafana-provisioning/dashboards/provider.yaml`（file provider、disableDeletion/allowUiUpdates:false、updateIntervalSeconds 30、foldersFromFilesStructure:false、options.path 指 json/）
- [ ] T021 [P] [US4] 4 greenfield dashboard json（`deploy/grafana-provisioning/dashboards/json/`、staging+atomic-mv 防半成品 orphan）：`master-overview.json`(uid obs-master-overview)／`rust-api.json`(obs-rust-api、含 casbin_enforce_total{decision}+axum_http_* panel)／`cleanup-job.json`(obs-cleanup-job、cleanup_job_*+pushgateway up)／`audit-log.json`(obs-audit-log、loki LogQL ★ `compose_project="rev3-admin"`、★ trace_id 巢狀 `fields_trace_id`、★ 3 rust-api panel 補 `` |~ `^{` `` JSON guard)
- [ ] T022 [P] [US4] 2 community pin dashboard json：`postgres.json`(uid obs-postgres、postgres_mixin @exporter v0.19.1、`$datasource`→hardcode prometheus uid)／`redis.json`(uid obs-redis、grafana.com 763 rev6、`${DS_PROM}`→prometheus uid、刪 __inputs/__elements/__requires)

**Checkpoint US4**: 跑 [C-V-5](contracts/verification-commands.md)（provisioning 冪等無 crash-loop）＋ [C-V-6](contracts/verification-commands.md)（6 dashboard 載入、CDP UI）

---

## Phase 7: Polish & Cross-Cutting

- [ ] T023 [P] `docker-compose.prod.yml` obs internal-only override（不映 host port、評估 prod 對外暴露細節）
- [ ] T024 [P] [C-V-0](contracts/verification-commands.md) opt-in 隔離：一般 `up` → 0 obs 容器/0 obs 卷（FR-001/SC-001）
- [ ] T025 [P] [C-V-7](contracts/verification-commands.md) `/api/metrics` 公網路徑 404 ＋ 內網 `rust-api:31081/metrics` 可 scrape（SC-008）
- [ ] T026 [C-V-8](contracts/verification-commands.md) 零回歸：容器內 `cargo test -p server --test entity_access_lint --test endpoint_coverage_lint` ＋ 既有 audit/auth/menu/role 端點 200 信封不變 ＋ base-web 既有頁可載（enforce decision 邏輯未變、counter observe-only）
- [ ] T027 [C-V-prod](contracts/verification-commands.md) prod target image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`（dep+埋点動 build、防 dev bind-mount 遮蓋）
- [ ] T028 [P] 跑 [quickstart.md](quickstart.md) 全 6 場景驗收

---

## Dependencies & Execution Order

- **Setup(P1)** → **Foundational(P2、T003 MSRV gate 阻塞所有 rust 埋点)** → **US1 → US2 → US3 → US4**（obs 為**分層相依**、非獨立：US3 需 US2 指標、US4 需 US1+US2 datasource；漸進序 #8）→ **Polish**。
- US1 為 MVP（obs-min 可獨立交付）。

## Parallel Opportunities

- T001（deploy secret）與 T002（rust dep）不同檔 → [P]。
- 各 story 內 deploy config 任務（不同檔）[P]：T007/T008/T010（US1）、T015/T017（US2）、T021/T022（US4）。
- ★ **rust 任務全 serial**（T005→T006、T012→T013→T014 共用 target、即使跨 story 亦不平行 cargo）。
- ★ 同一檔（`docker-compose.yml` T004/T009/T016、`docker-compose.dev.yml` T011/T018）serial、不 [P]。

## Implementation Strategy（交棒 階段 2）

- 以 `superpowers:executing-plans` 起手讀本檔 + 批判審查、依**實際相依/獨立可審邊界**編執行單元（U1=T005-T011／U2=T012-T018＋T019／U3=T020-T022／polish），**Workflow 工具驅動**（每單元一支：implementer TDD→spec-compliance review→fix loop→code-quality review→fix loop；agent prompt 烤進不可違反項，見頂部紀律）。
- **逐單元邊界**：主線復核 + load-bearing 自驗（容器內 cargo build/test、`/metrics` scrape、LogQL）+ **獨立 `git show --stat HEAD` 核 commit 範圍**（implementer 自報不可信）+ **bump 該單元 rust-api submodule pin**（§4.1）→ 啟下一支。
- 全單元完成 → 整體 holistic review → `superpowers:finishing-a-development-branch`（多段式 commit → `git merge --no-ff` 回 rev3-admin-root；**push/merge 需 user 同意**）→ 回填 MILESTONES/CHECKLIST/§6 marker（merge 後）。
- **不使用 `/speckit-implement`**。
