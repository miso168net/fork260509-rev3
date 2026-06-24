# Contract: Observability Signals（穩定訊號介面）

> obs 對外暴露的穩定介面＝metric 名/label、log JSON 欄位、alert expr、dashboard uid／scrape job 名。下游（prometheus scrape／loki/alloy LogQL／grafana provisioning）依賴此契約；**改名即破契約**（alert/dashboard rot）。

## 1. `/metrics` 端點契約（envelope 例外）
- path：rust-api 內網 `:31081/metrics`（容器內 bind 0.0.0.0:31081）。
- 認證：**無**（似 /health；無 JWT、無 enforce）。
- 格式：**Prometheus text exposition**（constitution §I.3 envelope universal 例外、**不**走 `{data,code,msg}` 信封）。
- 對外：front-nginx `location = /api/metrics { return 404; }`（已落地）擋公網路徑；prometheus 內網直 scrape `rust-api:31081/metrics`、不經 nginx。

## 2. Metric 契約（名／型／label）
| metric | 型 | label | 穩定值 |
|---|---|---|---|
| `axum_http_requests_total` | counter | `method`／`status`／`endpoint` | endpoint=matched-path（低基數） |
| `axum_http_requests_duration_seconds` | histogram | `le` | — |
| `axum_http_requests_pending` | gauge | — | — |
| `casbin_enforce_total` | counter | `decision` | `allow`／`deny`（★ 唯一 label） |
| `cleanup_job_last_success_timestamp` | gauge | — | unix epoch 秒 |
| `cleanup_job_rows_deleted` | gauge | — | 整數 |

## 3. Log JSON 契約（U1）
- subscriber `.json()` 後 rust-api stdout **每行為合法 JSON**。
- 關聯鍵 `trace_id` 以 structured span field 出現（巢狀 `fields.trace_id`，LogQL `| json | fields_trace_id=…`）。
- 值等於同請求的 `sys_access_log.trace_id`／`sys_operation_log.trace_id`（join 契約）。

## 4. Scrape job 契約（prometheus.yml、job 名不可改）
| job_name | target（內網） | 備註 |
|---|---|---|
| `rust-api` | `rust-api:31081`（metrics_path `/metrics`） | ★ 唯一 port 改寫 21081→31081 |
| `postgres` | `postgres_exporter:9187` | — |
| `redis` | `redis_exporter:9121` | — |
| `pushgateway` | `pushgateway:9091` | `honor_labels: true`（★ 必留） |

## 5. Alert expr 契約（rules-only、見 data-model §1.3）
3 rule：`obsfull-rustapi-down`／`obsfull-infra-exporter-down`／`obsfull-rustapi-high-5xx`；引用 job 名 ＋ `axum_http_requests_total`，故 §2/§4 名一漂即 rot。

## 6. Datasource／Dashboard 契約（grafana provisioning）
- datasource uid：`loki`（isDefault、+`deleteDatasources` guard 免 uid crash-loop）／`prometheus`。
- dashboard uid（6）：`obs-master-overview`／`obs-rust-api`／`obs-audit-log`／`obs-cleanup-job`／`obs-postgres`／`obs-redis`。
- audit-log.json LogQL `compose_project="rev3-admin"`（relabel 對齊、漂則板全空）。

## 7. relabel 契約（alloy、runtime 行為）
alloy docker-SD relabel keep `__meta_docker_container_label_com_docker_compose_project == "rev3-admin"`（漏改＝採不到 log）；compose-service→`service`、container→`container`、project→`compose_project`。
