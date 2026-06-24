# Implementation Plan: Observability（波 4）

**Branch**: `018-observability` | **Date**: 2026-06-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/018-observability/spec.md`；brainstorm spec-design `docs/superpowers/018-observability.md`。

## Summary

波 4 observability ＝ DESIGN §8.2 包覆全體之刀：一個**完全 opt-in、預設不啟**的維運觀測層，三執行單元漸進（U1 obs-min log → U2 obs-full metrics → U3 dashboard）。技術途徑＝rev2 對等 ＋ hindsight 修正（rev2 031/032/033 已驗結構移植 rev3、12 踩坑一次烤進）。唯一 rust 碼動在 `server`/`cleanup-job`（RUSTAPI-SOURCE-ISOLATION 軌：log span + json subscriber／`/metrics` route + `casbin_enforce_total`／cleanup pushgateway push）；其餘為 compose service ＋ `deploy/` 配置 ＋ grafana provisioning。**零 base-web／零 migration／零新 workspace crate**。最高風險 MSRV 1.86 已 Phase 0 解（[research.md R1](research.md)：rev2 同 1.86 floor 已 ship 同版本、obs 鏈不拉 time、無需新 pin）。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-api/rust-toolchain.toml`、patch-pin 對齊 rust:1.86-slim-bookworm）；觀測棧為容器化現成元件。

**Primary Dependencies**:
- rust 新 dep（compat ceiling、R1）：`axum-prometheus 0.7.0`（axum-0.7 相容最後版、勿升 0.8）／`metrics 0.23`（須對齊 transitive 否則 recorder 不一致靜默消失）／`metrics-exporter-prometheus 0.15`(default-features=false)／`ureq 2`(default-features=false)；`tracing-subscriber` 開 `json` feature。
- 觀測棧 image pin（DESIGN §1.6）：loki 3.7.2／alloy v1.16.1／prometheus v3.12.0／grafana 13.0.2／postgres-exporter v0.19.1／redis_exporter v1.85.0-alpine／pushgateway v1.11.3。

**Storage**: 無 DB schema（零 migration）；obs 持久卷 `loki_data`/`grafana_data`/`alloy_data`/`prometheus_data`（profile-gated）。

**Testing**: cargo（容器內 `docker exec`、rust serial、live smoke `--test-threads=1`）＋ acceptance C-V（profile 起停／promql／LogQL／grafana provisioning／CDP UI）。rust 埋点屬 **wiring**、無純函式單元測（由 `/metrics` scrape ＋ LogQL 覆蓋；plan/tasks 明示理由）。

**Target Platform**: Linux container（WSL2 dev／prod compose）。

**Project Type**: web-service 之 ops/observability 包覆刀（內網維運、非 user-facing）。

**Performance Goals**: opt-in、一般 `up` 零開銷；alert 評估 1m interval；retention log 72h／metrics 15d。

**Constraints**: 零 base-web inline／零 migration／零新 workspace crate；**MSRV 1.86**（新 dep 須容器內 build 確證、obs 不得引入 time edge）；`/metrics` 不對外（nginx exact-match 擋、constitution envelope 例外）。

**Scale/Scope**: 內網單機觀測；多副本/水平擴展 v1 不做（Out-of-Scope）。

## Constitution Check

*GATE：Phase 0 前必過、Phase 1 後再核。對照 constitution §IV 九項：*

| # | 檢查 | 裁定 | 依據 |
|---|---|---|---|
| 1 | §I.1 base-web 權威／endpoint 缺口 | **PASS** | obs 為內網 ops、base-web 不消費；新增 `/metrics` 為 infra 端點、非 base-web wire。無 endpoint 缺口。 |
| 2 | 動 base-web inline？ | **PASS（不觸發）** | FR-004 base-web 零改 → 不觸 MODAL-WIRING/I18N-WIRING ★ 軌道。 |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（N/A）** | grafana 為內網工具、**不**進 `sys_menu`、無業務 menu。 |
| 4 | wire 對齊 §I.3 不變式？ | **PASS** | `/metrics` ＝ envelope universal 例外（§I.3 line 46、Prometheus exposition 不走信封）；無其他新 wire；log trace_id 為內部訊號非 wire 契約。 |
| 5 | 從 rev2 拷貝 code？ | **PASS** | rust 埋点全新打字（受控參照 §I.5、不拷貝）；`deploy/` 配置為外層 infra 檔（非 rust-api 源樹）、依 rev2-parity 改寫（relabel rev3-admin、port）；4 dashboard greenfield 重作、2 community pin（非 rev2）。無防回歸違規。 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS** | 正面落實 **#8 obs 漸進**（obs-min→obs-full）＋ **#11 `/api/metrics` 擋塊**；無抵觸。 |
| 7 | 觸及 ★ 軌道？ | **PASS** | 僅 **RUSTAPI-SOURCE-ISOLATION**（預設可動、非 ★）涵蓋 rust 埋点；不觸 MODAL-WIRING/I18N-WIRING/BUILD-CONFIG ★。 |
| 8 | 新建業務表（migration）？ | **PASS（不觸發）** | FR-004 零 migration → §I.6 審計欄/archetype 無涉。 |
| 9 | 觸及 §I.7 行為島？ | **PASS** | `casbin_enforce_total` counter 為 **observe-only side-effect**、**不改** enforce 判決邏輯（§4.2 DB-first/protected/PolicyMutated invariants 不變）；cleanup-job push 為 best-effort、**不新增 CLI flag**（§4.1「僅 `--execute` 一旗標」維持）、不改 dry-run/idempotent invariant；token rotation／single-session 未涉。 |

**結論：9/9 PASS、無 violation → 無 Complexity Tracking。**（Phase 1 設計後重核：rust 埋点插點與配置產物均不改上述裁定，維持 9/9。）

## Project Structure

### Documentation (this feature)
```text
specs/018-observability/
├── plan.md              # 本檔
├── research.md          # Phase 0：R1 MSRV ★／R2-R7 決策
├── data-model.md        # Phase 1：訊號實體＋配置產物＋rust 觸點(file:line)
├── quickstart.md        # Phase 1：起停驗證指南
├── contracts/
│   ├── observability-signals.md    # 穩定訊號介面（metric/log/alert/dashboard/scrape）
│   └── verification-commands.md    # C-V 驗收（SC-001~009＋MSRV＋prod build）
└── tasks.md             # Phase 2（/speckit-tasks 產、非本步）
```

### Source Code（觸及檔、act-on-code）
```text
rust-api/  (RUSTAPI-SOURCE-ISOLATION 軌)
├── server/
│   ├── Cargo.toml                  # +axum-prometheus 0.7.0 +metrics 0.23（U2）
│   └── src/
│       ├── main.rs                 # subscriber .json()(U1, L55-59) + PrometheusMetricLayer::pair/route/layer(U2, ~L555/556/574)
│       ├── audit_ctx.rs            # audit_mw 包 .instrument(span trace_id)(U1, L364)
│       └── auth/enforce.rs         # casbin_enforce_total counter(U2, L124 allow/L126 deny)
├── cleanup-job/
│   ├── Cargo.toml                  # +metrics 0.23 +metrics-exporter-prometheus 0.15(df=false) +ureq 2(df=false)(U2)
│   └── src/main.rs                 # push_metrics() best-effort pushgateway(U2, ~L63; std SystemTime 不引 chrono)
└── (workspace) Cargo.toml/Cargo.lock  # tracing-subscriber json feature; obs transitive seed rev2 known-good 版(R1)

deploy/  (外層 infra、自由可動)
├── generate-secrets.sh             # +grafana_admin_password leaf(U1, R6)
├── secrets/                        # +grafana_admin_password.txt(.example)
├── loki-config.yml                 # 新(U1, retention 72h)
├── alloy-config.alloy              # 新(U1, docker-SD, relabel keep rev3-admin)
├── prometheus/prometheus.yml       # 新(U2, 4 job, rust-api:31081, retention 15d)
└── grafana-provisioning/           # 新(U3): datasources{loki uid+deleteDatasources guard, prometheus} / alerting/rules.yml(3) / dashboards/{provider.yaml, json×6}

docker-compose.yml                  # +7 obs service(profiles obs/metrics) +4 卷 +grafana_admin_password secret
docker-compose.{dev,prod}.yml       # obs host port(dev 33000/33100/33090/39091) / prod internal-only override(評估)
```

**Structure Decision**: 沿用 rev3 既有 worktree+submodule（rust-api 埋点走 RUSTAPI-SOURCE-ISOLATION、兩段式 commit bump pin §4.1）；obs 配置/compose 為外層 `rev3-admin-root` 追蹤檔（單段 commit）。三執行單元 U1→U2→U3 為實作邊界（漸進序 #8）。

## Complexity Tracking
（無 Constitution violation → 不適用。）

## Phase 0 / Phase 1 產出

- **Phase 0**（[research.md](research.md)）：R1 MSRV ★ 已解（1.86 相容、無新 pin、殘餘 LOW=resolver drift）／R2 log span／R3 metrics 埋点（含 rev3 偏離：enforce helper 2-site、cleanup 不引 chrono）／R4-R7 切分/alert/secret/hindsight。**無遺留 NEEDS CLARIFICATION。**
- **Phase 1**（[data-model.md](data-model.md)／[contracts/](contracts/)／[quickstart.md](quickstart.md)）：6 metric＋log JSON 欄位＋3 alert＋6 dashboard 訊號契約；rust 觸點 file:line；C-V-MSRV/0~8/prod 驗收。
- **Agent context**：CLAUDE.md §6 marker 更新指向本 plan（見下步）。

> **下一步**：`/speckit-tasks` 產 dependency-ordered tasks.md（U1→U2→U3 執行單元）；再 `/speckit-analyze` 跨檔一致性；交棒 階段 2 `superpowers:executing-plans` + Workflow 驅動（**不** `/speckit-implement`）。
