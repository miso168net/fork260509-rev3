# Phase 0 Research: 018-observability

> `/speckit-plan` Phase 0 輸出。act-on-code（rev3 實碼 ＋ rev2 known-good 參照、不拷貝 §I.5），不信假設。
> 來源 brainstorm spec-design：[`docs/superpowers/018-observability.md`](../../docs/superpowers/018-observability.md)。

## R1 ★ MSRV — obs dep 在 rev3 Rust 1.86 相容性（最高風險、已解）

**Decision**: obs 依賴在 rev3 Rust **1.86 相容、無需新 MSRV-pin**。固定為相容上限（compat ceiling、非 MSRV 強制）：`axum-prometheus = 0.7.0`／`metrics = 0.23`／`metrics-exporter-prometheus = 0.15`（default-features=false）／`ureq = 2`（default-features=false）。

**Rationale（act-on-code 證據）**:
- rev3 toolchain ＝ `1.86.0`（`rust-api/rust-toolchain.toml`）；rev2 ＝ `1.86`（同 floor）。
- rev2 已成功 ship 這些**完全相同解析版本**（rev2 `Cargo.lock`：axum-prometheus 0.7.0／metrics 0.23.1／metrics-exporter-prometheus 0.15.3／ureq 2.12.1；032 已 merge、rev2 HEAD 035、obs 碼路徑〔`PrometheusMetricLayer::pair`／`metrics::counter!`／`PrometheusBuilder`〕實際編譯運行於 1.86）。
- obs 鏈引入的 MSRV 敏感 transitive：要嘛**已在 rev3 現行 `Cargo.lock` 同版本**（portable-atomic 1.13.1、url 2.5.8／idna 1.1.0／icu_normalizer 2.2.0／zerofrom 0.1.8）、要嘛**自含 1.86-clean**（quanta 0.12.6、metrics-util 0.17.0、raw-cpuid 11.6.0、sketches-ddsketch 0.2.2）。
- ★ **obs 鏈不拉 `time`**（quanta 用 crossbeam-utils／raw-cpuid、非 time）→ **不重新觸發**rev3 既有 time≥0.3.41-需-1.88 問題（rev3 已由 `time 0.3.37`／`simple_asn1 0.6.3` pin 處理）。obs 對 time-MSRV 暴露＝零。

**Alternatives considered**:
- 升 `axum-prometheus ≥0.8`：否決——需 axum 0.8 遷移（rev3 是 axum 0.7、root Cargo.toml 載重註解）。
- `metrics` 不對齊 0.23：否決——server/cleanup-job 與 axum-prometheus/exporter 的 0.23 transitive 不一致 → counter/gauge 寫到不同 global recorder、**靜默消失**（rev2 server/Cargo.toml 載重註解，移植時逐字帶入）。

**Residual risk（LOW）**: rev3 加 obs dep 時跑 fresh `cargo update`、可能把 obs transitive 解析得比 rev2 lock 高（rev2 lock ~16 天舊快照）→ 理論上某 floor 可能宣告 >1.86。**緩解**：以 rev2 known-good 版本 seed 初始 lock pin、再放寬。known-good floor（若需 pin）：portable-atomic=1.13.1／quanta=0.12.6／metrics-util=0.17.0／zerofrom=0.1.8／icu_normalizer=2.2.0／raw-cpuid=11.6.0。實作時確證命令見 [contracts/verification-commands.md](contracts/verification-commands.md) C-V-MSRV。

**新 crate？無**——metrics 加進**既有** server／cleanup-job crate，非新 workspace member → CLAUDE.md §3「新 crate ⇒ 四處 Dockerfile COPY ＋ prod image build acceptance」**不觸發**；惟 contracts 仍納一條 prod target build（防 dev bind-mount 遮 Cargo.toml/Cargo.lock 變動）。

## R2 log↔audit 關聯（U1）

**Decision**: rust-api `server` crate 加兩處小改：(1) `audit_ctx.rs` audit_mw 在 `next.run(req).await`（L364）外**包一個 async-aware tracing span**（`.instrument(info_span!("request", trace_id=%trace_id, …))`），trace_id 值已於 L348 `extract_trace_id` 算出；(2) `main.rs:55-59` subscriber 改 `fmt().json()` ＋ workspace `tracing-subscriber` 開 `json` feature。

**Rationale**: act-on-code 證 rev3 現況——trace_id 只進 DB 審計欄（`sys_access_log.trace_id`），**從不上 log 輸出**；subscriber 是純文字 `fmt()`（無 json feature）。loki/alloy 要結構化抽 trace_id 做 log↔audit join，須 JSON log ＋ span field。span 必 `.instrument()`（跨 `.await` 不脫離；sync `_enter` guard 會在 await 點丟失）。

**Alternatives**: 純文字 log ＋ LogQL regex 抽 trace_id（否決：脆、易漂；rev2-parity 採 JSON）。

## R3 metrics 埋点（U2、全 greenfield）

**Decision**: `server/main.rs` 建 `PrometheusMetricLayer::pair()` ＋ public `/metrics` route（無 JWT/enforce、似 /health）＋ `enforce.rs` `casbin_enforce_total{decision}` counter ＋ `cleanup-job` `push_metrics()` best-effort 推 pushgateway。act-on-code 插點見 [data-model.md](data-model.md) §6。

**Rationale**: DESIGN §8.6 包覆刀一次定、前面 entity 刀無 retrofit 債；rev3 現況 `/metrics`／axum-prometheus／cleanup pushgateway **全無**（greenfield）。

**rev3-specific 偏離（不照抄 rev2）**:
- (a) rev3 enforce 決策已因子化到純 helper `enforce_role_path_method`（enforce.rs L112-127），counter 插 **L124 allow / L126 deny** 2 site（≠ rev2 直接埋 `enforce_mw`）。rev3 fail-closed（roles DB error）走 `require_policy` 閉包 L352-353 `?` 早退、**未經 helper** → **U2 取捨**：只記 2 site（fail-closed DB-error 不計入 enforce decision、語意可接受），或改 L352 為 match 補 deny counter 對齊 rev2「fail-closed 也算 deny」。**plan 採前者**（最小改、語意清晰：counter 計「policy 判決」而非「DB 異常」）。
- (b) rev3 cleanup-job **刻意不引 chrono**（檔頭紀律：cutoff 走 Postgres-side `make_interval`、避 entity DateTime feature-gate）→ `push_metrics` 的 `now_epoch` 用 `std::time::SystemTime::now().duration_since(UNIX_EPOCH)` 取秒（**非** rev2 的 `chrono::Utc::now().timestamp()`）。

## R4 切分與漸進序（D1）

3 執行單元 **U1 obs-min(log) → U2 obs-full(metrics) → U3 dashboard**；漸進序由 constitution §II #8／§11.8 凍結（obs-min 先）。一刀 018（否決照搬 rev2 三 feature＝3× SDD ceremony；DESIGN §8.4 量級錨「obs 1 刀」）。

## R5 alert rules-only（D3）

provision 3 baseline rule、**不 provision** contact point/notification policy（送信 channel 延後；spec FR-017／Out-of-Scope）。

## R6 grafana_admin_password 新 secret（DESIGN:706 落差）

**Decision**: U1 須**新增** `grafana_admin_password` secret（`deploy/generate-secrets.sh` leaf ＋ compose top-level `secrets:` ＋ grafana `GF_SECURITY_ADMIN_PASSWORD__FILE`）。
**Rationale**: act-on-code 證 DESIGN:706 宣稱「5-leaf/8 檔含 grafana」與實檔不符——`generate-secrets.sh` 實 4-leaf/6 檔、grafana 是腳本(:15)＋README(:72) 明標「波 4 再加」deferred。以 as-built 為準（憲法 §V.1）。exporter 復用既有 postgres/redis secret、**零其他新 secret**。

## R7 hindsight 修正（rev2 踩坑、一次烤進）

redis_exporter 必 `-alpine` 變體（bare=FROM scratch 無 sh、sh-wrapper 會掛）＋ sh-wrapper 讀 secret；cleanup push 用 `ureq`（非 `reqwest::blocking`、tokio runtime 內 nested-runtime panic）；loki 一開始給顯式 `uid: loki` ＋ datasource `deleteDatasources` guard（免 grafana uid crash-loop）；alloy relabel keep `rev3-admin`、audit-log.json LogQL `compose_project="rev3-admin"`、trace_id 巢狀 `fields_trace_id`、rust-api panel `` |~ `^{` `` JSON guard；dashboard json staging ＋ atomic-mv（防半成品 provision orphan）。
