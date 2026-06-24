# Contract: Verification Commands（C-V 驗收）

> 對映 spec Success Criteria（SC-001~009）＋ MSRV gate ＋ prod build。obs 低邏輯面 → 以 acceptance 為主（spec/plan 須明示「rust 埋点屬 wiring、無純函式單元測」）。
> dev 前綴：`DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"`。rust build/test 一律**容器內** `docker exec`（host 無 cargo）。
> ★ WSL host port-forward 慢非斷（memory）：host `:33xxx` curl 用 `localhost`（::1 快）/長 timeout，或 `$DC exec` 走容器內網繞過。

## C-V-MSRV ★（R1、最高風險、實作起手即跑）
```bash
# obs dep 加入後，容器內全 build = 真 MSRV gate（rust serial、勿 background、timeout 拉長）
$DC exec -T rust-api sh -c 'cd /app && find server/src cleanup-job/src -name "*.rs" -exec touch {} + && cargo build -p server -p cleanup-job'
# time 仍只走 simple_asn1 路徑（obs 未引 time edge）
$DC exec -T rust-api sh -c 'cd /app && cargo tree -i time'           # 期望：僅 jsonwebtoken→simple_asn1 path
# 敏感 transitive 解析版本對齊 1.86-known-good
$DC exec -T rust-api sh -c 'cd /app && cargo tree -i portable-atomic && cargo tree -i quanta && cargo tree -i zerofrom'
```
**期望**：build 綠；`cargo tree -i time` **不**出現 quanta/metrics 路徑；任一 transitive 報 `requires rustc 1.8x` → pin 至 rev2 known-good（portable-atomic=1.13.1／quanta=0.12.6／metrics-util=0.17.0／zerofrom=0.1.8／icu_normalizer=2.2.0）重 build 至綠。

## C-V-0（SC-001、opt-in 隔離）
```bash
$DC up -d --wait                                  # 一般啟動、不帶 obs/metrics profile
$DC ps --services | grep -E 'loki|alloy|grafana|prometheus|exporter|pushgateway' && echo "FAIL: obs 容器啟動了" || echo "PASS: 0 obs 容器"
docker volume ls | grep -E 'rev3-admin_(loki|grafana|alloy|prometheus)_data' && echo "FAIL: obs 卷建了" || echo "PASS: 0 obs 卷"
```
**期望**：obs service／卷皆未建（FR-001）。

## C-V-1（SC-002、log 軌）
> ★ rust-api dev 容器【無 curl/wget】、alloy 容器【無 wget】——凡內網 HTTP 查詢一律走【prometheus 容器的 wget】（rev3_net 內可達 rust-api:31081／loki:3100／grafana:3000）。
```bash
$DC --profile obs up -d --wait                    # 起 loki+alloy+grafana
$DC exec -T prometheus sh -c 'wget -qO- http://rust-api:31081/health'   # 產生容器 log（prometheus 有 wget）
# LogQL（prometheus 容器 wget 查 loki，繞 host port-forward；★ 勿用 alloy／rust-api 容器=無 wget/curl）
$DC exec -T prometheus sh -c 'wget -qO- "http://loki:3100/loki/api/v1/query_range?query=%7Bcompose_project%3D%22rev3-admin%22%7D&limit=5"' | grep -q '"values"' && echo "PASS: log 採到"
```
**期望**：loki/alloy/grafana healthy；LogQL `{compose_project="rev3-admin"}` 回容器 log（涵蓋多 service）。

## C-V-2（SC-003、log↔audit 關聯）★ 本刀核心
```bash
# 打一個已認證請求（curl 取 token→帶 Authorization 打 audit 讀端點），記其 trace_id
# 1) loki 查該請求 log 行的 fields_trace_id
# 2) psql 查 sys_access_log 最新列 trace_id
$DC exec -T postgres psql -U soybean -d soybean_admin_rust -tAc \
  "select trace_id from sys_access_log order by created_at desc limit 1;"
# LogQL 以該 trace_id drill：{compose_project="rev3-admin"} | json | fields_trace_id="<上面那個>"
```
**期望**：log 行的 `fields_trace_id` == `sys_access_log.trace_id`（同請求關聯成功；subscriber .json() 後每行合法 JSON 含 trace_id）。

## C-V-3（SC-004、metrics 軌）
```bash
$DC --profile metrics up -d --wait                # 起 prometheus+2 exporter+pushgateway(+grafana)
$DC exec -T prometheus sh -c 'wget -qO- http://rust-api:31081/metrics' | grep -E '^(axum_http_requests_total|casbin_enforce_total)' && echo "PASS: app metric"  # ★ rust-api 容器無 curl/wget、走 prometheus wget
# ★ prometheus 4 target 全 up==1（漏 networks:[rev3_net] 或 redis REDIS_ADDR 會靜默 down、容器卻起得來）
$DC exec -T prometheus sh -c 'wget -qO- "http://localhost:9090/api/v1/query?query=up"' | grep -oE '"job":"(rust-api|postgres|redis|pushgateway)"[^}]*"1"'   # 4 job 皆 1（含 up{job="redis"}==1 驗 REDIS_ADDR）
# 觸發一次 enforce allow + deny 後再抓 casbin_enforce_total{decision="allow"|"deny"}
# ★ cleanup-job 是 profiles:[prod]（非 metrics）→ 不會隨 --profile metrics 起，須手動觸發一次
$DC run --rm cleanup-job >/dev/null 2>&1 || true
$DC exec -T prometheus sh -c 'wget -qO- http://pushgateway:9091/metrics' | grep -q cleanup_job_last_success_timestamp && echo "PASS: cleanup gauge"
```
**期望**：`/metrics` 含 axum_http_*／casbin_enforce_total{decision}；**prometheus 4 target（rust-api/postgres/redis/pushgateway）皆 up==1**；pushgateway 含 cleanup_job_*（手動觸發 cleanup-job 後、dry-run 也推）。

## C-V-4（SC-005、alert）
> ★ 告警為【grafana-managed unified alerting】（T019、datasourceUid prometheus）、**不在** prometheus rules API（`prometheus :9090/api/v1/rules` 查 grafana-managed rule 必空＝假失敗）——須查【grafana alerting API】（host curl :33000、admin basic auth；127.0.0.1 IPv4 慢用長 --max-time）。
```bash
GPW=$(cat deploy/secrets/grafana_admin_password.txt)
# 3 baseline rule provisioned（provisioning API、provenance=file）：
curl -s --max-time 20 -u "admin:$GPW" http://127.0.0.1:33000/api/v1/provisioning/alert-rules \
  | grep -oE 'obsfull-(rustapi-down|infra-exporter-down|rustapi-high-5xx)' | sort -u | wc -l   # =3
# 規則即時狀態（inactive/pending/firing）：
curl -s --max-time 20 -u "admin:$GPW" http://127.0.0.1:33000/api/prometheus/grafana/api/v1/rules \
  | grep -oE '"name":"obsfull-[a-z0-9-]+"[^}]*"state":"[a-z]+"'
# 模擬：停 postgres_exporter → up{job="postgres"}=0 → infra-exporter-down 經 group interval+for 進 pending→firing
$DC stop postgres_exporter   # 驗畢 $DC start postgres_exporter 還原
```
**期望**：3 baseline rule provisioned（provenance=file）；模擬 down 經 `for` 門檻轉 pending/firing（v1 不投遞、僅狀態可見）。★ 高-5xx rule noDataState=OK（idle 零 5xx 維持 inactive、非誤 firing）。

## C-V-5（SC-006、provisioning 冪等）
```bash
$DC --profile obs --profile metrics up -d --wait
$DC restart grafana && sleep 5 && $DC logs grafana --tail 50 | grep -iE 'crash|panic|datasource.*not found' && echo "FAIL" || echo "PASS: 無 crash-loop"
# 重拉 grafana_data 卷後 provisioning 仍冪等（loki uid + deleteDatasources guard）
```
**期望**：grafana 重建無 crash-loop、datasource/dashboard 冪等（loki 顯式 uid + deleteDatasources guard 生效）。

## C-V-6（SC-007、dashboard、CDP）★ curl≠UI
```bash
# CDP（9229）登入 grafana :33000（admin / deploy/secrets/grafana_admin_password.txt），逐一開 6 dashboard uid 確認載入＋datasource 接妥＋panel 有資料/正確空態
# 參考 tests/000 的 CDP scripts；★ 若 CDP 環境不就緒而 defer C-V-6 → 於 INTEGRATION-CHECKLIST Follow-up Backlog 顯式登一條補測（CLAUDE.md §3「CDP defer 須 backlog 登記」、curl≠UI），不只靠本註腳
```
**期望**：6 dashboard（obs-master-overview/rust-api/audit-log/cleanup-job/postgres/redis）皆載入、datasource 自動接、audit-log 顯本工作區 log（compose_project 對齊）。

## C-V-7（SC-008、/metrics 不對外）
```bash
$DC up -d --wait                                  # front-nginx 起
curl -s -o /dev/null -w '%{http_code}' http://localhost:31080/api/metrics   # 期望 404
$DC exec -T prometheus sh -c 'wget -qO- http://rust-api:31081/metrics | head -1'   # 內網 scrape 正常
```
**期望**：公網路徑 `/api/metrics`→404；內網 `rust-api:31081/metrics` 可 scrape。

## C-V-8（SC-009、零回歸）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint --test endpoint_coverage_lint'
# 既有 audit/auth/menu/role 端點 curl 回 200 信封不變；base-web 既有頁可載（CDP）
```
**期望**：既有 lint/端點/前端零回歸（enforce decision 邏輯未變、counter 僅 observe-only side-effect）。

## C-V-prod（prod target image build；§3 紀律保險）
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api   # 含 server+cleanup-job 埋点 + 新 dep
```
**期望**：prod multi-stage build 綠（雖無新 crate、惟 dep+埋点動 build、防 dev bind-mount 遮蓋）。
