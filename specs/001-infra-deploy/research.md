# Research: 001-infra-deploy（Phase 0）

**Date**: 2026-06-13 ｜ **Input**: spec.md＋docs/superpowers/001-infra-deploy.md＋rev2 outer as-built 精讀

## R1 · 素材策略與裁剪邊界

- **Decision**: 裁剪帶入（brainstorm 拍板 A）。自 rev2 outer repo 帶入 `docker-compose.yml`/`dev.yml`/`prod.yml`＋`deploy/` 子集，裁掉波 0 範圍外內容。
- **裁剪清單（master compose）**：裁 8 service——`cleanup-job`（波 3）、`loki`/`alloy`/`grafana`（obs，波 4）、`prometheus`/`postgres_exporter`/`redis_exporter`/`pushgateway`（metrics，波 4）；裁 4 卷（`loki_data`/`grafana_data`/`alloy_data`/`prometheus_data`）；裁 2 secrets（`cleanup_database_url`/`grafana_admin_password`）。**保留** `acme`（profiles:[prod] 殼＋`Dockerfile.acme.txt` 4 行）。dev.yml/prod.yml 同步裁對應段（loki/alloy/grafana/prometheus/pushgateway/cleanup-job override）。
- **deploy/ 帶入子集**：`Dockerfile.rust-api.txt`（COPY 段裁剪見 R4）、`Dockerfile.acme.txt`、`entrypoint.rust-api.sh`、`nginx/`（4 檔）、`generate-dev-cert.sh`＋`dev-certs/`（`.gitkeep`；cert 本機生成）、`generate-secrets.sh`（裁至 6 secrets，見 R11）＋`secrets/*.example`×6＋README。**不帶**：`alloy-config.alloy`/`loki-config.yml`/`prometheus/`/`grafana-provisioning/`（波 4）、`Dockerfile.base-web.txt`（prod base-web build 需要！——**帶**，prod.yml 引用它；修正：帶入）。
- **Rationale**: 保留 rev2 35 features 踩坑調出的細節（healthcheck timing/127.0.0.1/gate 結構）；`grep rev2` 歸零可堵裁剪殘留。
- **Alternatives considered**: 從零重寫（丟細節、重踩機率高）；全量帶入＋profile 閘（帶而未驗死配置）——均於 brainstorm 否決。

## R2 · token 改名表（帶入時逐項套用）

| rev2 | rev3 |
|---|---|
| `name: rev2-admin`／image・container 前綴 `rev2-admin-*` | `rev3-admin`／`rev3-admin-*` |
| `rev2_net` | `rev3_net` |
| port `21079`/`21080`/`21081`/`21443` | `31079`/`31080`/`31081`/`31443` |
| port `25432`/`26379` | `35432`/`36379` |
| `redis/redis-stack-server:latest` | **`redis/redis-stack-server:7.4.0-v8`**（⚠️d；2026-06-13 查 Docker Hub 當下 stable） |
| 註解內 rev2 字樣 | rev3（或刪）；完成後 `grep -ri rev2` 歸零（豁免：`.dockerignore` 內 `fork260509-rev2-anew-rust-api` 為 GitHub repo 永久名、必要引用——T010 實作期發現並回填；C-V-5 grep 範圍〔docker-compose*.yml deploy/〕不含 .dockerignore，驗收不受影響。其餘 outer 檔無倉名引用） |

nginx conf 內 upstream port（`base-web:21079`→`:31079`、`rust-api:21081`→`:31081`）與 listen（`21080`/`21443`→`31080`/`31443`）、Dockerfile `EXPOSE`/HEALTHCHECK port 同步。

## R3 · rust-api 版本鎖點與 time/home 坑

- **Decision**: 沿 rev2 as-built 鎖點（DESIGN §1.6「版本＝rev2 as-built 鎖點、rev3 起點」）：toolchain **rust 1.86**（`rust-toolchain.toml` channel "1.86"）、`axum 0.7`、`tokio 1`、`sea-orm-migration 1.1.20`（migration crate）、edition 2021。基底映像 `rust:1.86-slim-bookworm`／`debian:bookworm-slim`。
- **已知坑（rev2 Cargo.toml 注記）**: sea-orm 1.1.20 過渡依賴的 `time`/`home` 新 patch 需 Rust 1.88——**新生成的 Cargo.lock 會踩**。對策：scaffold 自產 lock 後執行 `cargo update -p time --precise 0.3.37 -p home --precise 0.5.9` 並 commit lock（鎖定 1.86 可編譯集）。
- **Cargo.lock**: 自產並 commit（不拷 rev2 lock——rev2 lock 含 35-feature 全依賴、scaffold 僅小集合）。
- **Alternatives**: 升 rust 1.88+（脫離 rev2 鎖點、引入新變數）——否；版本升級屬日後顯式 bump。

## R4 · scaffold 形狀與 Dockerfile 裁剪

- **Decision**: workspace members＝`["server", "migration"]`（rev2 的 6 member 裁至 2；`cleanup-job`/`entity`/`sea-orm-adapter`/`xdb` 屬後刀）。
- **Dockerfile 對應裁剪**：COPY 段只留 server/migration 的 Cargo.toml＋src；裁 `application.yaml`（本刀 server 無 config 消費）、`xdb` benches/資料檔、cleanup-job/entity/adapter 行；builder `cp` 只出 2 binary（server/migration）。**⚠️ 後刀新增 workspace crate 時必須補 COPY 行——此即 CLAUDE.md §3「新增 crate ⇒ acceptance 必含 prod image build」紀律的看點**。
- **dispatcher（entrypoint.rust-api.sh）**: 保留 3-case 原樣（`cleanup-job` case 留殼——僅被呼叫時才失敗、無害、減後刀 diff）。
- **dev target**: `cargo watch --poll -x "run --bin server"`（WSL2 9P inotify 不可靠——rev2 T025 實測教訓 carry）。
- **HEALTHCHECK**: runtime stage `curl -fsS http://127.0.0.1:31081/health`（timing 沿 rev2：10s/3s/5s/3）。

## R5 · /health 端點契約

- **Decision**: `GET /health` → HTTP 200、`text/plain`、body `ok`。axum 0.7、bind `0.0.0.0:31081`。**不走 envelope**——constitution §I.3 明文 universal 例外（`/health` plain text）。詳 contracts/health-endpoint.md。

## R6 · migrate 空跑與 gate

- **Decision**: migration crate 實作 `MigratorTrait::migrations() → vec![]`；`migration up` 連 DB（`APP_DATABASE_URL_FILE`→sea-orm 慣例讀取）、建框架表 `seaql_migrations` 後成功退出。dev override：`entrypoint: ["cargo","run","--bin","migration"]`＋`command: ["up"]`（dev image ENTRYPOINT 是 cargo-watch、必須整段換——rev2 注記 carry）；prod：runtime image＋`command: ["migration","up"]` 經 dispatcher 派發。gate：`depends_on: migrate: condition: service_completed_successfully`（rust-api）。
- **`mNNN_<name>` 慣例（⚠️k）**: migration crate `src/` 留 README 注記＋`lib.rs` 注釋示例（`m001_rev2_schema` 為 002 刀首個實例）。
- **DB URL secret**: `database_url.txt`＝`postgres://soybean:<pw>@postgres:5432/soybean_admin_rust`（generate-secrets.sh 組合、同 rev2）。

## R7 · redis-stack 版本（⚠️d 落值）

- **Decision**: `redis/redis-stack-server:7.4.0-v8`（2026-06-13 Docker Hub 數字版最新 stable；7.2 系列為舊 line）。升版走顯式 bump commit。

## R8 · base-web master dev 定義

- **Decision**: master `dev.yml` 的 base-web 段採 **rev3 standalone 已驗證內容**（`node:26-alpine`、port 31079、`npm_config_store_dir=/pnpm-store`、`CI=true`、pnpm@10），**非** rev2 的 `node:20.19-alpine`——rev3 standalone 自 2026-06-12 起實機驗證 16h+。healthcheck 沿 rev2 master 形（wget grep doctype、start_period 90s）。
- standalone `docker-compose.base-web.yml` 保留並存（同 R9 定位）。

## R9 · standalone rust-api compose 定位

- **發現修正**: rev2 的 `docker-compose.rust-api.yml` 標 **DEPRECATED**（master 落地後退場、留作 single-service debug 後備、不保證同步）。rev3 帶入採同樣定位與標註——非「一等公民並存」。
- spec FR-010 的「standalone 並存」語意＝debug 後備殼，據此實作。

## R10 · CLAUDE.md §3 Phase 0 三 grep 紀律適用性聲明

| 紀律 | 本刀適用性 |
|---|---|
| ① facade 真實返回型 grep | **N/A**——本刀無 facade／無業務 endpoint（scaffold 僅 `/health`） |
| ② wire 鏈 3 端對齊 grep | **N/A**——唯一新 wire＝`/health`（非業務 wire、無 typings 對應端）；形狀＝plain text `ok`，對齊 constitution §I.3 envelope universal 例外明文 |
| ③ data-model file:line 命名對照 | **N/A**——本刀無 data-model（見 data-model.md 聲明；業務 schema＝002 刀 ⚠️t） |

## R11 · secrets 集合

- **Decision**: 6 secrets（`postgres_password`/`redis_password`/`jwt_secret`/`refresh_token_secret`/`database_url`/`redis_url`）；`generate-secrets.sh` 自 rev2 的 8 個裁至 6（裁 `cleanup_database_url`〔波 3〕/`grafana_admin_password`〔波 4〕，屆時加回）。jwt 兩支「接而不讀」（compose 接線就位、消費＝Auth 刀）。dev 的 rust-api JWT 用 env fallback（rev2 dev.yml 同款）；真值走 secrets（prod／migrate database_url）。
- `.txt` gitignored、`.example`＋README git-tracked（rev2 慣例 carry；rev3 `.gitignore` 既有 `deploy/secrets` 規則隨帶入確認）。
