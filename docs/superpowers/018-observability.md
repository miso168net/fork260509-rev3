# 018-observability — spec-design（Phase 0 brainstorm）

> CLAUDE.md §3 階段 0 產物。交棒 → 手動 `/speckit-specify`（input＝本檔）起 018 feature branch。
> 日期：2026-06-24。來源：[INTEGRATION-CHECKLIST §2 波 4](../INTEGRATION-CHECKLIST.md)（波 3 收刀後唯一 roadmap 下一波）。
> 素材＝[DESIGN §8.2 包覆全體 Observability](../INTEGRATION-DESIGN.md)（rev2 031/032/033 對應物）、§8.4 波 4 出口條件、§8.6 包覆刀埋點義務、§11.2 三段式、§1.6 版本鎖。

---

## 1. 背景與目標

波 4 ＝ observability，DESIGN §8.2/§8.6 界定為**「包覆全體之刀」**（非 entity data island）：跨整個 stack 的 ops 觀測層，**全段 `profiles` opt-in、一般 `docker compose up` 不啟**。grafana 為 ops 內網用途、**非 §2 user-facing 業務 UI**（DESIGN §8.4 明示）。

**一刀 `018-observability`，內部 3 執行單元**（依 constitution §11.8 已拍板漸進序）：

| 單元 | profile | 核心目標 | rev2 對應 |
|---|---|---|---|
| **U1 obs-min（log）** | `obs` | 全容器 stdout → 集中 log 查詢，且 log 可關聯 DB 審計列 | rev2 031 |
| **U2 obs-full（metrics）** | `metrics` | rust-api/PG/redis/job 指標 scrape + baseline alert + in-process 埋點 | rev2 032 |
| **U3 dashboard** | `obs,metrics` | grafana provisioning as-code（datasource/alert/6 dashboard） | rev2 033 |

**整刀紀律**：base-web **零改**；唯一 rust 碼動在 **RUSTAPI-SOURCE-ISOLATION** 軌（U1 log span + U2 埋點）；**零 migration**；**零新 workspace crate**（dep 加既有 `server`/`cleanup-job` crate）。

---

## 2. 拍板紀錄（user 親決 2026-06-24 brainstorm）

| # | 決策 | 結論 |
|---|---|---|
| **D1** 切分 | 波 4 怎麼切成 spec-kit feature | **一刀 018-observability，內部三執行單元 obs-min→obs-full→dashboard**（否決照搬 rev2 三刀＝3× SDD ceremony；DESIGN §8.4 量級錨「obs 1 刀」；三段相依、協同設計避 rev2 033 retrofit） |
| **D2** v1 定位 | 企圖心 | **rev2 對等 + hindsight 修正**：採 rev2 證明過的全部結構，把 survey 抓到的 rev2 踩坑教訓一次烤進（applicable 者落 §4；其中 nginx 404／JSON quote 等 rev3 已具備、見 §3、本刀不重做）；defer 與 rev2 相同項 |

**defer（D2 衍生、與 rev2 相同）**：非-root alloy 硬化 ｜ alert notification 投遞 channel ｜ 3 DB log 表 retention/purge（⚠️n）｜ 模糊 LIKE→pg_trgm（§4.2）｜ prod internal-only 部署細節（§3.A prod 硬化）。

**工程拍板（我決、記錄；非 user 拍板級）**：

| # | 決策 | 結論 |
|---|---|---|
| D3 | alert 投遞 | **rules-only、不 provision contact point/notification policy**（承 D2 parity-defer、同 rev2 032） |
| D4 | U1 是否含 rust 單元 | **含**（grounding 證 rev3 無 log-side trace_id span、見 §3）——非純 config 單元 |
| D5 | 是否開新 crate | **不開**（axum-prometheus 加 `server`、pushgateway client 加 `cleanup-job`，皆既有 crate）→ §3「新 crate ⇒ 四處 Dockerfile COPY」**不觸發** |

---

## 3. Phase 0 研究實證（act-on-code grep、已核 @ 2026-06-24）

brainstorm 期間對 rev3 實碼核對（exact 行號於 `/speckit-plan` research.md 再固化）。**★ 不信 rev2 假設、不信 DESIGN 目標態、以 as-built 為準**：

**rust-api（worktree）**
- **axum 版本＝0.7**（`rust-api/Cargo.toml:6`、`server` inherit）→ **axum-prometheus 0.7.0（targets axum 0.7）直接相容、無 0.8 遷移**。
- **`/metrics` route + axum-prometheus dep ＝ 全無**（`main.rs:555-575` router 無 /metrics；兩 Cargo.toml 無 axum-prometheus/prometheus crate；僅 `envelope.rs:4` doc-comment 提及 /metrics 為未來 envelope 豁免）→ **U2 埋點全 greenfield**。
- **★ log-side trace_id span ＝ 不存在**：grep `info_span!`/`TraceLayer`/`tower_http::trace`/`.instrument()` over `server/src/` → **零命中**。trace_id 值在 `audit_ctx.rs:348`（extract_trace_id）算出、塞 request extensions、**只**進 DB 審計欄（`sys_access_log.trace_id` `audit_ctx.rs:381`／`sys_operation_log.trace_id` 經 AuditMeta `:95`），**從不上 tracing/log 輸出**。subscriber ＝純文字 `fmt()`（`main.rs:55-59`、tracing-subscriber **無 `json` feature**）→ 今日 log 行 ↔ DB 審計列**無共用關聯鍵**。
- 全域 per-request middleware ＝ `audit_ctx::audit_mw`（`main.rs:571-574` 最外層 layer；`audit_ctx.rs:308-390`；需 `into_make_service_with_connect_info` 提供 ConnectInfo）。
- enforce casbin 決策點 ＝ `enforce_role_path_method`（`enforce.rs:112-127`、async fn 回 bool、**2 個 return site**＝allow/deny）；消費於 `require_policy`（`:339-360`）。**無任何 metrics**。
- `cleanup-job`（014 已落地）：`cleanup-job/src/main.rs`、dep 僅 sea-orm+tokio、**無 pushgateway/prometheus 任何推送**→ U2 cleanup-job push 全 greenfield（加 pushgateway client 到既有 crate）。
- **★ MSRV ＝ Rust 1.86**（workspace `Cargo.toml:14-15` 註解、含 time/jsonwebtoken 約束）→ **新 dep（axum-prometheus／metrics／metrics-exporter-prometheus／pushgateway client）必須對 1.86 做 MSRV 檢**（這是 time/simple_asn1 同類坑、見 §8 首要 research）。

**deploy / compose**
- **nginx `/api/metrics` 404 ＝ 已是實際規則**（`deploy/nginx/conf.d/_locations.inc:12-14` `location = /api/metrics { return 404; }`、001 FR-003、DESIGN 一致）→ **U2 不需動 nginx**。
- **nginx JSON log + X-Request-Id ＝ 已落地**（`nginx.conf:16-31` `log_format json_combined` + stdout；`_locations.inc:22` `proxy_set_header X-Request-Id $request_id`、**僅 `/api/` 設、`/`〔base-web〕未設**）→ **U1 不需動 nginx**、log pipeline 基礎已備。
- **★ `grafana_admin_password` 落差**：DESIGN `INTEGRATION-DESIGN.md:706` 宣稱「已在 generate-secrets 5-leaf 集／總 8 檔」，**實檔 `deploy/generate-secrets.sh` 只 4 leaf（jwt_secret/refresh_token_secret/postgres_password/redis_password）+ 2 URL（database_url/redis_url）＝6 檔**；grafana 是腳本（`:15`）與 `deploy/secrets/README.md`（`:72`）都明文標的「波 4 再加」deferred 項 → **U1 須補**（generate-secrets leaf + compose 頂層 secrets + grafana `GF_SECURITY_ADMIN_PASSWORD__FILE`），不可假設已存在。詳 §9。
- **obs/metrics service/volume/profile ＝ 完全不存在**（三 compose 檔 grep 零命中）。現況：services `docker-compose.yml:17-176`（8 個）／volumes `:180-187`（7 個 always-on）／secrets `:189-201`（6 個）。插入點見 §4。
- **`deploy/grafana-provisioning/`（及 prometheus/loki/alloy config）＝ 不存在**、須新建（rev2 既有、rev3 未移植）。

---

## 4. 各執行單元設計

> 版本鎖：loki `3.7.2` / alloy `v1.16.1` / prometheus `v3.12.0` / grafana `13.0.2`（DESIGN §1.6）；postgres_exporter `v0.19.1` / redis_exporter `v1.85.0-alpine` / pushgateway `v1.11.3`（rev2 as-built）。
> rev3 dev host port：grafana `33000` / loki `33100` / prometheus `33090` / pushgateway `39091`（alloy/exporter 無 host port）。prod 全 internal-only。

### 4.1 U1 — obs-min（log）｜`profiles:[obs]`

**compose（新增 service）**：loki（filesystem TSDB v13、retention **72h**）← alloy（docker-SD `discovery.docker` 讀 docker.sock、取代 EOL promtail、user:root）→ grafana（Explore + loki datasource）。
- 卷：`loki_data`/`grafana_data`/`alloy_data`（皆 `profiles:[obs]`、一般 up 不建）。
- secret：**新增 `grafana_admin_password`**（generate-secrets leaf + compose secrets + `GF_SECURITY_ADMIN_PASSWORD__FILE`、見 §9）。
- depends_on：alloy→loki；grafana→loki `{condition:service_started, required:false}`（跨 obs+metrics、metrics-only 啟動時容 loki 缺席）。

**rust（D4、`server` crate、小而外科）**：
- `audit_ctx.rs` audit_mw 內把 `next.run` 包進 `info_span!("request", trace_id = %trace_id)`（trace_id 值已在 `:348` 算好、僅未 span-attach）。
- `main.rs:55-59` subscriber 改 `fmt().json()` + workspace `tracing-subscriber` 開 `json` feature → log 行帶機器可解析 trace_id，可 join `sys_access_log`/`sys_operation_log`。
- 無新 crate／schema／migration。**注意**：`.json()` 改變**全部** log 輸出形狀（dev console 變 JSON）——rev2 031 已接受此 tradeoff、parity 沿用。

**nginx**：不需動（JSON log + X-Request-Id 已落地、§3）。

**hindsight 烤進**：① alloy relabel keep `rev3-admin`（漏改＝採不到 log）② loki **一開始就給顯式 `uid: loki`** + datasource `deleteDatasources` guard（免 rev2 033 grafana uid crash-loop）。

### 4.2 U2 — obs-full（metrics）｜`profiles:[metrics]`

**compose（新增 service）**：prometheus（retention **15d**、static-scrape 4 target：rust-api:31081/metrics + postgres_exporter:9187 + redis_exporter:9121 + pushgateway:9091）+ postgres_exporter + redis_exporter + pushgateway；grafana profile 擴 `[obs,metrics]`。
- 卷：`prometheus_data`（`profiles:[metrics]`）。
- secret：**exporter reuse 既有 `postgres_password`（`DATA_SOURCE_PASS_FILE`）/ `redis_password`（sh-wrapper）、零新 secret**。

**rust 埋點（D5、本刀一次定、entity 刀無 retrofit 債、全 greenfield）**：
- `server/main.rs`：公開 `/metrics` route（無 JWT/enforce、似 /health）+ axum-prometheus `0.7.0` `PrometheusMetricLayer::pair()` layer（套 flat router、低基數 MatchedPath endpoint label）。自動 metric：`axum_http_requests_total{endpoint,status}` / `..._duration_seconds_bucket{le}` / `..._pending`。
- `auth/enforce.rs`：`casbin_enforce_total{decision}` counter（`metrics` crate）插 `enforce_role_path_method` 2 個 return site（allow/deny）。
- `cleanup-job/main.rs`：跑完 best-effort `push_metrics()` 推 `cleanup_job_last_success_timestamp`/`cleanup_job_rows_deleted` 兩 gauge 到 `pushgateway:9091`（★ 用 `ureq` default-features=false 非 `reqwest::blocking`〔tokio runtime 內 nested-runtime panic〕；`metrics-exporter-prometheus` default-features=false 砍 push-gateway/rustls/aws-lc-rs 重 transitive）。失敗只 warn、不改 cleanup 結果/exit code。

**alert（D3、rules-only）**：3 條 baseline rule（rust-api down `up{job=rust-api}<1`／exporter down／5xx率 >5%）；**不 provision notification channel**。

**nginx**：不需動（`/api/metrics` 404 已落地、§3）。

**hindsight 烤進**：redis_exporter 必用 `-alpine` 變體（bare = FROM scratch 無 sh、sh-wrapper 會掛）＋ sh-wrapper 從 secret 讀 `REDIS_PASSWORD` 再 exec。

### 4.3 U3 — dashboard provisioning（純 grafana config）

**`deploy/grafana-provisioning/`（新建）**：2 datasource（loki `uid:loki` + deleteDatasources guard／prometheus `uid:prometheus`）+ `provider.yaml`（disableDeletion/allowUiUpdates:false/updateIntervalSeconds:30）+ **6 dashboard json**：master-overview / rust-api / postgres / redis / audit-log / cleanup-job。
- greenfield 4：master-overview/rust-api/cleanup-job/audit-log；community pin 2：postgres（@exporter v0.19.1）/redis（grafana 763 rev6）。

**hindsight 烤進**：① audit-log.json LogQL `compose_project="rev3-admin"`（漏改＝該板全空）② trace_id 是**巢狀 `fields_trace_id`** 非 top-level（subscriber `.json()` 把 event 欄位巢狀 `fields` 下）③ 三 rust-api panel 補 `` |~ `^{` `` 行首 JSON guard（cleanup-job 純文字 stdout 被 alloy 標 service=rust-api、無 guard 的 `| json` 對純文字回 400）④ json 在 scanned 目錄外 staging + atomic-mv（防 provider 搶先 provision 半成品 orphan）。

---

## 5. v1 不做（defer、與 rev2 相同、D2）

| 項 | 何時做 |
|---|---|
| 非-root alloy 硬化（讀 docker.sock 現 user:root） | prod security pass（§3.A） |
| alert notification 投遞 channel（contact point/policy） | 後續 feature（送信需 channel creds） |
| 3 DB log 表（operation/access/login）retention/purge | ⚠️n、容量警示觸發時 |
| 模糊 LIKE→pg_trgm GIN | §4.2、規模增長（需 CREATE EXTENSION+migration） |
| prod internal-only 細節（obs host port 不對外） | §3.A prod 硬化、dev/prod override 評估 |

---

## 6. 出口條件（DESIGN §8.4）

- [ ] obs/metrics profile 起停乾淨（一般 `up` **不啟**任何 obs；`--profile obs`/`--profile metrics` 才起）
- [ ] provisioning 重建無 crash-loop（含 loki uid、grafana datasource、dashboard provider）
- [ ] rust-api log/metrics **兩軌可查**（LogQL 查得帶 trace_id 的 log 行可 join 審計列；promql 查得 axum/casbin/cleanup metric）

---

## 7. 測試 / 驗收策略

obs 以 compose/YAML/JSON config 為主、**低邏輯面** → 多數由 **acceptance 覆蓋**（C-V contract：`up --profile` 起停 + promql/LogQL query + grafana provisioning load + CDP grafana UI）。
- **純函式單元測**：U2 的 `parse`/低基數 label 邏輯若有純函式可 test-first；rust 埋點本體（counter increment、span attach）屬 **wiring**、由 `/metrics` scrape 見 counter + LogQL 見 trace_id 覆蓋 → **spec/plan 須明示「無單元測試及理由」**（per §3）。
- **prod image build 驗**：雖無新 crate（§3「新 crate ⇒ 四處 COPY」不觸發），但 U2 動 `server`+`cleanup-job` build + 引新 dep + **MSRV 風險** → contracts **仍納一條 prod target image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、§3 紀律保險）。
- **rust 全程 serial**（共用 target）；build/test 在 rust-api 容器內 `docker exec`；live smoke 帶 `DATABASE_URL`+`--test-threads=1`。

---

## 8. Phase 0 research 待固化（交 `/speckit-plan` research.md）

> §3 已核項標「✅ 已核」；以下為 plan 階段須**再固化/補查**者，**★ 首要＝MSRV**：

1. **★ MSRV 1.86 dep 檢（最高風險、load-bearing）**：`axum-prometheus 0.7.0` + transitive（`metrics 0.23`/`metrics-exporter-prometheus 0.15`）+ cleanup-job pushgateway client（`ureq`/`metrics-exporter-prometheus` default-features=false）**全部對 Rust 1.86 做 `cargo tree`/容器內 build 驗**、**不假設**。任一需 >1.86 ⇒ 降版或換 client（同 time/simple_asn1 處置）。
2. ✅ 已核：axum 0.7（axum-prometheus 相容）／/metrics greenfield／log-side trace_id span 不存在（U1 含 rust）／nginx 404+JSON 已落地（不動）／grafana_admin_password 落差（U1 須補）／cleanup-job 無 pushgateway（greenfield）。
3. wire 對齊：prometheus scrape target `rust-api:31081/metrics`（rev3 容器內 port）+ exporter `:9187`/`:9121` + pushgateway `:9091`；確認 rev3 service/network 名（`rev3_net`、容器內 port 不變）。
4. compose override：dev/prod（`docker-compose.dev.yml`/`prod.yml`）是否需 obs 特定覆寫（prod internal-only 不映 host port、dev 映 33000/33100/33090/39091）。
5. alloy/grafana LogQL 的 `compose_project` 值＝rev3 project name（`rev3-admin`、來自 compose top-level `name:`）——relabel keep regex 與 audit-log.json 兩處須一致對齊此值。

---

## 9. DESIGN 落差紀錄（act-on-code 接住、供勘誤評估）

**`grafana_admin_password` / `cleanup_database_url` secret 落差**：`INTEGRATION-DESIGN.md:706`（§10.3 secrets 段）宣稱 generate-secrets.sh 產「5 leaf + 3 URL ＝ 8 檔」（含 grafana_admin_password、cleanup_database_url），但 as-built `deploy/generate-secrets.sh` 僅「4 leaf + 2 URL ＝ 6 檔」：
- `grafana_admin_password`：腳本+README 明文「波 4 再加」→ **018 U1 實作待補項**（非缺陷、是 deferred 排程）。
- `cleanup_database_url`：DESIGN 稱「波 3 加」、實檔亦無——014 cleanup-job 實際**復用 `database_url`**（`APP_DATABASE_URL_FILE`、CHECKLIST §3.A）而非獨立 secret；DESIGN:706 與 014 as-built 選擇不同。

DESIGN:706 屬 hindsight-complete 目標態（§7.2 凍結藍圖、不當狀態板），落差**以 as-built 為準**。是否最小 patch DESIGN:706（標「grafana 波4 補／cleanup 復用 database_url」）留 user 決——本刀至少把「U1 補 grafana_admin_password」列為實作項即可、不阻塞。
