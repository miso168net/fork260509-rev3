# Quickstart: 018-observability 驗證指南

> obs 為 **profile-gated、預設不啟**。本檔為「起停＋驗證」run guide；完整 C-V 命令見 [contracts/verification-commands.md](contracts/verification-commands.md)，訊號契約見 [contracts/observability-signals.md](contracts/observability-signals.md)。
> `DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"`

## 前置
- rev3 dev stack 可起（核心 5 service healthy）。
- **新 secret**：`bash deploy/generate-secrets.sh` 重生後含 `deploy/secrets/grafana_admin_password.txt`（U1 加 leaf；exporter reuse postgres/redis secret 無新增）。
- rust 埋点已 build（`C-V-MSRV` 綠）。

## 場景 1 — opt-in 隔離（FR-001 / SC-001）
```bash
$DC up -d --wait            # 一般啟動
$DC ps                      # 不應出現 loki/alloy/grafana/prometheus/exporter/pushgateway
```
✅ 通過＝零 obs 容器、零 obs 卷。

## 場景 2 — 日誌軌（U1 / US1 / SC-002,003）
```bash
$DC --profile obs up -d --wait                 # loki+alloy+grafana
$DC exec -T rust-api sh -c 'curl -s localhost:31081/health'    # 製造 log
```
- grafana Explore（`localhost:33000`、admin / grafana_admin_password.txt）→ loki datasource → `{compose_project="rev3-admin"}` 查得多 service log。
- **log↔audit**：對已認證端點發請求 → `{…} | json | fields_trace_id="<trace>"` 的 log 行與 `sys_access_log.trace_id` 同值（C-V-2）。

## 場景 3 — 指標軌（U2 / US2 / SC-004）
```bash
$DC --profile metrics up -d --wait             # prometheus+2 exporter+pushgateway(+grafana)
$DC exec -T rust-api sh -c 'curl -s localhost:31081/metrics' | grep -E 'axum_http_requests_total|casbin_enforce_total'
```
- prometheus（`localhost:33090`）→ 4 target（rust-api/postgres/redis/pushgateway）皆 `up`。
- 觸發 allow＋deny 後 `casbin_enforce_total{decision}` 兩值皆增；cleanup-job 跑後 pushgateway 有 `cleanup_job_*`。

## 場景 4 — 告警（US3 / SC-005、rules-only）
- prometheus/grafana → 見 3 baseline rule；停 `postgres_exporter` → `obsfull-infra-exporter-down` 經 2m 轉 Alerting（v1 不投遞、僅狀態）。

## 場景 5 — 儀表板（U3 / US4 / SC-006,007）
```bash
$DC --profile obs --profile metrics up -d --wait
$DC restart grafana                            # provisioning 冪等、無 crash-loop
```
- grafana → 6 dashboard（master-overview/rust-api/audit-log/cleanup-job/postgres/redis）皆載入、datasource 自動接。

## 場景 6 — /metrics 不對外（SC-008）
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:31080/api/metrics   # 404
```

## 收尾
```bash
$DC --profile obs --profile metrics down       # 停 obs（核心 stack 不受影響）
```

## 已知 v1 邊界（Out-of-Scope）
告警不投遞通知／alloy 非-root 硬化／DB log 表 retention purge（⚠️n）／pg_trgm／prod internal-only 落實／多副本——皆延後。
