# REVIEW 報告 — 018-observability（波 4）

> Claude workflow 驅動 TDD（階段 2）的 review 彙整。日期 2026-06-25。
> 來源：4 支 Workflow（U1/U2/U3 各 implementer→spec-review∥quality-review→fix loop ＋ 整體 holistic review 3 lens＋綜合）＋ 主線逐單元邊界自驗。
> feature 範圍/設計見 [spec.md](../specs/018-observability/spec.md)／[plan.md](../specs/018-observability/plan.md)；as-built 帳見 [INTEGRATION-DECISIONS §2](INTEGRATION-DECISIONS.md)。

## 1. 執行單元與 commit

| 單元 | 內容 | rust pin | outer commit |
|---|---|---|---|
| U0 Setup | obs dep（axum-prometheus 0.7.0／metrics 0.23／metrics-exporter-prometheus 0.15／ureq 2）＋★MSRV 1.86 gate＋grafana secret＋compose 宣告 | `8f84d3c` | `44ec2b46` |
| U1 obs-min | rust json subscriber＋per-request trace_id span/event；loki 3.7.2／alloy v1.16.1／grafana 13.0.2＋loki datasource | `56f8d01` | `5c403adf`＋`ef2ebaba`(grafana fix)＋`ad1687e9`(pin) |
| U2 obs-full | rust `/metrics`(axum-prometheus)＋`casbin_enforce_total{decision}`＋cleanup pushgateway；prometheus v3.12.0／2 exporter／pushgateway＋3 grafana alert | `6871907` | `0887d1fa`＋`fdca7bf2`(5xx fix)＋`0b39aec3`(pin) |
| U3 dashboard | provider＋6 dashboard（4 greenfield＋postgres 9628/redis 763 community pin） | （無 rust） | `638051f5` |
| Polish | prod obs internal-only override；holistic LOW 校正 | （無 rust） | `74e8d41f`＋`ed6beb3a` |

## 2. Review 裁定

- **U1/U2/U3 per-unit**：spec-compliance＋code-quality 皆收斂至 APPROVE（U1 fix 1 HIGH：grafana 密碼 `__FILE` 後綴無效→改 `$__file{}` provider；U2 0 must-fix；U3 0 must-fix）。
- **整體 holistic（3 lens）**：completeness CONCERNS／integration PASS／discipline PASS → **綜合 CONCERNS、無 BLOCK**。reviewer 獨立 live-verify FR-001~022／SC-001~009 全數功能滿足。

## 3. as-built 偏離（經驗判定、皆正當）

1. **FR-006 explicit completion event**（U1）：`.instrument(span)` 單獨對「無 in-span event 的請求」（如 /health）不輸出 log 行（實證 loki 0 行）、且 span 欄位落 JSON `span`/`spans` 非 `fields`。補 `tracing::info!(trace_id=…, http_status=…, "request completed")` event → trace_id 落 event `fields` → loki `| json` 攤平為 **`fields_trace_id`**（對齊 data-model §1.2）。**join key 經驗確證 ＝ `fields_trace_id`**。
2. **grafana 密碼 `$__file{}` provider**（U1）：Grafana 無 `GF_*__FILE` 後綴慣例；改 `GF_SECURITY_ADMIN_PASSWORD=$__file{/run/secrets/...}`。實測 file-password 登入 200、admin/admin 401（檔密碼確實生效）。
3. **5xx alert noDataState=OK**（U2）：data-model §1.3／tasks T019 對 3 rule 一律 `noDataState=Alerting`，但 5xx ratio query 在 idle/零 5xx 時回空向量→誤升 Firing（false positive、違 FR-015/016 意圖）。修：5xx rule `noDataState=OK`＋expr 兩端 `or vector(0)`（ratio 在 healthy 恆為 0）；down 類 rule 維持 `noDataState=Alerting`（語意正確）。實證 idle 3 rule 全 inactive。
4. **endpoint_coverage_lint AS_BUILT +`/metrics`**（U2、43→44）：新 public route 觸發既有 lint Assertion B；`/metrics` 無 policy（似 /health）、Assertion A 不需 seed。mandated 維護、非 scope creep。
5. **postgres community 板 ＝ grafana 9628 rev8**（U3）：tasks 允「postgres_mixin 或 grafana.com 相容板」；9628 對 postgres_exporter v0.19.1 emit 之 metric 相容、CDP 實渲染真資料。

## 4. holistic LOW 校正（已修、commit `ed6beb3a`）

- **C1** verification-commands.md：C-V-1/C-V-3 凡「經 rust-api/alloy 容器發 curl/wget」改走【prometheus 容器 wget】（rust-api dev 無 curl/wget、alloy 無 wget→字面重跑假失敗）；C-V-4 改【grafana alerting API】（grafana-managed 告警不在 prometheus rules API）。
- **I1** preflight-secrets.sh：REQUIRED 加 grafana_admin_password（6→7、免舊 secret 集靜默空密碼）。
- **D2** prometheus datasource：補 `deleteDatasources` guard（對齊 loki、FR-019 冪等一致性）。

## 5. 遞延 backlog（非 blocker、spec 容許/正確設計）

- **postgres.json docker 空態**：9628 的 `release`/`instance` template var 依賴 k8s label（kubernetes_namespace/release），docker 下 postgres_exporter v0.19.1 不 emit→該類 filter 面板空態（核心 pg_up/連線/DB stats 仍出圖）。spec 容許空態（C-V-6「panel 有資料/正確空態」）。如日後欲消空面板：改 docker 友善板（如 grafana 12485）或重寫變數 query。
- **/health request-completion log 噪音**：FR-006「每請求一行」設計使 /health 探針亦每次輸出一行 INFO log（loki 72h retention + opt-in 已界範圍）。如噪音過大可選在 subscriber 加 path 過濾（會權衡 join 完整性）。
- **C-V contract 全面對齊**：本次只校正會【假失敗】的命令；data-model §1.3 noDataState/expr 與 tasks T019 的 as-built 偏離（本報告 §3.3 已記）留 `/speckit-analyze` 批次校正。

## 6. 驗收實證（主線獨立）

C-V-0 隔離（無 profile 0 obs service）／C-V-1 log 採集（loki 收 8 service）／**C-V-2 log↔audit trace_id 關聯**（psql sys_access_log.trace_id == loki fields_trace_id、多 marker 重現）／C-V-3 metrics（4 prometheus target up==1〔含 redis REDIS_ADDR=redis-stack〕＋casbin_enforce_total{allow}＋cleanup pushgateway gauge）／C-V-4 3 grafana alert（idle inactive）／C-V-5 重啟×2 冪等／**C-V-6 6 dashboard CDP UI 實渲染**（截圖實證）／C-V-7 `/api/metrics`→404＋內網 scrape／C-V-8 零回歸（lint 2+2、既有端點 200 code=0000、base-web HTML）／**C-V-prod release multi-stage build green**。

**最終裁定：PASS、可 merge 回 rev3-admin-root。**
