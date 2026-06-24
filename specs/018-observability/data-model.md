# Phase 1 Data Model: 018-observability

> obs **零 DB schema／零 migration**。本檔記「資料模型」＝觀測訊號（signal）實體 ＋ 配置產物 ＋ rust 整合觸點（act-on-code `file:line`）。穩定訊號契約另見 [contracts/observability-signals.md](contracts/observability-signals.md)。

## 1. 訊號實體（signal entities）

### 1.1 Metric（6，U2）
| metric | 型 | label | 來源 | 備註 |
|---|---|---|---|---|
| `axum_http_requests_total` | counter | method／status／endpoint(=matched-path) | axum-prometheus 自動 | endpoint=低基數 matched path（FR-009） |
| `axum_http_requests_duration_seconds` | histogram | （bucket le） | axum-prometheus 自動 | p50/p95/p99 由 histogram_quantile |
| `axum_http_requests_pending` | gauge | — | axum-prometheus 自動 | in-flight |
| `casbin_enforce_total` | counter | **decision(=allow\|deny)** | 自埋 enforce.rs | ★ 唯一 label、勿加高基數；fail-closed DB-error（require_policy `?` 早退）**不計入**（research R3(a) 取捨、勿在 `?` 處補 counter 而誤改控制流） |
| `cleanup_job_last_success_timestamp` | gauge | — | cleanup-job push | unix epoch 秒；dry-run 也算成功 |
| `cleanup_job_rows_deleted` | gauge | — | cleanup-job push | dry-run=0／execute=實刪數 |

### 1.2 Log JSON 欄位（U1）
subscriber `.json()` 後每行為合法 JSON；request span 帶 structured field：
- `fields_trace_id`（巢狀於 `fields`、非 top-level）＝ trace_id（honor `x-request-id` trim≤64 else uuid-v4），**log↔DB 審計列關聯鍵**（join `sys_access_log.trace_id`／`sys_operation_log.trace_id`）。
- 本刀 request span 實放欄位＝`trace_id`／`method`／`path`（T005）。`http_status`（回應狀態、`next.run().await` 回來後才有、`.instrument()` 進入點放不進）／`ip_confidence`／`client_ip`／`peer_ip` **非本 entry-span field、仍只進 `sys_access_log`**（勿嘗試塞進進入點 span）。

### 1.3 Alert rule（3，U2、rules-only D3）
| uid | expr | for | severity |
|---|---|---|---|
| `obsfull-rustapi-down` | `up{job="rust-api"}` < 1 | 2m | critical |
| `obsfull-infra-exporter-down` | `up{job=~"postgres\|redis"}` < 1 | 2m | critical |
| `obsfull-rustapi-high-5xx` | `sum(rate(axum_http_requests_total{status=~"5.."}[5m])) / clamp_min(sum(rate(axum_http_requests_total[5m])),1)` > 0.05 | 5m | warning |

> job 名（`rust-api`/`postgres`/`redis`）＝ prometheus.yml `job_name`，**不可漂**（up selector rot）。

### 1.4 Dashboard（6，U3）
| json | title | uid | 主要消費訊號 |
|---|---|---|---|
| `master-overview.json` | 全域總覽 | `obs-master-overview` | up{}/cleanup age/跨源 |
| `rust-api.json` | 後端應用 | `obs-rust-api` | axum_http_*／casbin_enforce_total |
| `audit-log.json` | log pipeline | `obs-audit-log` | loki LogQL（含 trace_id drill-down、U1 log 消費端） |
| `cleanup-job.json` | 維運 job | `obs-cleanup-job` | cleanup_job_*／pushgateway up |
| `postgres.json` | Postgres | `obs-postgres` | postgres_exporter（community pin @v0.19.1） |
| `redis.json` | Redis | `obs-redis` | redis_exporter（grafana 763 rev6 pin） |

## 2. 配置產物（compose／deploy、皆 profile-gated）

### 2.1 compose service（新增至 `docker-compose.yml`）
| service | image（pin） | profile | host port（dev）／內網 |
|---|---|---|---|
| loki | `grafana/loki:3.7.2` | `obs` | 33100／:3100、retention 72h |
| alloy | `grafana/alloy:v1.16.1` | `obs` | 無／:12345，user:root 讀 docker.sock |
| grafana | `grafana/grafana:13.0.2` | `obs,metrics` | 33000／:3000 |
| prometheus | `prom/prometheus:v3.12.0` | `metrics` | 33090／:9090、retention 15d |
| postgres_exporter | `prometheuscommunity/postgres-exporter:v0.19.1` | `metrics` | 無／:9187，`DATA_SOURCE_PASS_FILE` reuse postgres_password |
| redis_exporter | `oliver006/redis_exporter:v1.85.0-alpine` ★ | `metrics` | 無／:9121，sh-wrapper 讀 redis_password |
| pushgateway | `prom/pushgateway:v1.11.3` | `metrics` | 39091／:9091，in-memory |

> ★ **每個新 obs service MUST `networks: [rev3_net]`**（rev3 全 service 顯式 join `rev3_net`、無 default network；漏接＝service DNS 不通、scrape/datasource 全靜默 down、容器卻起得來）。★ `redis_exporter` 須 `REDIS_ADDR=redis://redis-stack:6379`（redis 服務名＝`redis-stack` 非 `redis`）。★ `postgres_exporter` `DATA_SOURCE_URI=postgres:5432/soybean_admin_rust?sslmode=disable`（DB 名＝`soybean_admin_rust`、`DATA_SOURCE_USER=soybean`）。

### 2.2 卷（正典命名、CLAUDE.md §8.2.2）
`loki_data`／`grafana_data`／`alloy_data`（`obs`）；`prometheus_data`（`metrics`）。exporter/pushgateway 無持久卷。

### 2.3 secret
**新增 1**：`grafana_admin_password`（generate-secrets leaf ＋ compose `secrets:` ＋ grafana `_FILE`）。exporter **reuse** `postgres_password`／`redis_password`（零其他新 secret）。

### 2.4 deploy/ 配置檔（全新建、rev3 目前無）
`deploy/loki-config.yml`（顯式 retention 72h）／`deploy/alloy-config.alloy`（docker-SD、relabel keep `rev3-admin`）／`deploy/prometheus/prometheus.yml`（4 scrape job、retention 15d）／`deploy/grafana-provisioning/`（`datasources/{loki.yml uid=loki+deleteDatasources guard, prometheus.yml uid=prometheus}`、`alerting/rules.yml`、`dashboards/{provider.yaml, json/×6}`）。

## 3. dep 變更（compat ceiling、R1）
- `server/Cargo.toml`：+`axum-prometheus = "0.7.0"`（含載重註解：axum-0.7 相容最後版、勿升 0.8）、+`metrics = "0.23"`（須對齊 0.23 transitive、否則 recorder 不一致靜默消失）。
- `cleanup-job/Cargo.toml`：+`metrics = "0.23"`、+`metrics-exporter-prometheus = { version="0.15", default-features=false }`、+`ureq = { version="2", default-features=false }`。
- workspace `tracing-subscriber`：開 `json` feature（U1）。
- **無新 workspace crate**（§3 四處 COPY 不觸發）。

## 4. base-web／DB
**零改**（FR-004）：base-web 不動、無 migration、無 entity 變更。

## 5. nginx
**不需動**：`/api/metrics` 404（`_locations.inc:12` exact-match）＋ **nginx access log** JSON（`json_combined`）＋ X-Request-Id 皆 001 已落地。★ 此「JSON log」指 **nginx** access log；**rust-api subscriber 仍純文字 `fmt()`、由 U1 T006 改 `.json()`**（兩者不同主體、勿因 nginx 已 JSON 而跳過 T006）。

## 6. rust 整合觸點（act-on-code `file:line`、U1/U2）
| 單元 | 檔:行 | 動作 |
|---|---|---|
| U1 | `server/src/audit_ctx.rs:364`（audit_mw、trace_id 已於 :348） | 包 `.instrument(info_span!("request", trace_id=%…))` 於 `next.run(req).await` |
| U1 | `server/src/main.rs:55-59` | subscriber `fmt()` → `fmt().json()`（+ tracing-subscriber json feature） |
| U2 | `server/src/main.rs:~555`（router build 前） | `let (prometheus_layer, metric_handle) = PrometheusMetricLayer::pair();`（無 OnceLock guard、main 唯一呼叫者） |
| U2 | `server/src/main.rs:~556`（public route 群） | `.route("/metrics", get(move \|\| async move { metric_handle.render() }))` |
| U2 | `server/src/main.rs:~574`（audit_mw layer 之後、with_state 前） | `.layer(prometheus_layer)`（更外層、endpoint=matched path 低基數） |
| U2 | `server/src/auth/enforce.rs` ~L123 `return true`（allow、迴圈內命中即計）／~L126 `false`（deny、全 role 落空後一次） | `metrics::counter!("casbin_enforce_total","decision"=>…).increment(1)`（helper 2 site；揮發行號、以 `return true`/`false` 兩點為準） |
| U2 | `cleanup-job/src/main.rs:41-63`（execute/dry-run **互斥 if/else、無現成匯流點**） | 先 hoist `let deleted:u64`（execute=`rows_affected`／dry-run=0）出兩分支，於匯流後單點呼叫新 `fn push_metrics(now_epoch, deleted)`（ureq PUT `pushgateway:9091`、best-effort、std SystemTime 取秒、不引 chrono） |

## 7. 狀態轉移（alert）
alert rule：`Normal`→（條件持續 ≥ `for` 門檻）→`Alerting`（critical/warning）；v1 **不投遞**（無 contact point）。其餘訊號無狀態機。
