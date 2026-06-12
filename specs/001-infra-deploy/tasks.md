# Tasks: infra-deploy（rev3 部署地基）

**Input**: Design documents from `/specs/001-infra-deploy/`

**Prerequisites**: plan.md ✅、spec.md ✅、research.md（R1~R11）✅、contracts/ ✅、quickstart.md ✅、data-model.md（無資料模型聲明）✅

**Tests**: 本 feature **無單元測試**（plan.md Technical Context 明示＋理由：純 wiring/infra、無可獨立測純函式）；驗收＝C-V acceptance 實機執行（contracts/verification-commands.md，spec 拍板 B 實機），以下 acceptance 任務為必做、非 optional test。

**Organization**: 依 user story 分 phase；US1＝MVP。

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup（deploy/ 支援檔帶入）

**Purpose**: 機密／憑證／派發器等支援檔就位（全部自 rev2 裁剪帶入＋改名，research R1/R2/R11）

- [x] T001 帶入並裁剪 `deploy/generate-secrets.sh`（8→6 secrets：裁 cleanup_database_url/grafana_admin_password）＋`deploy/secrets/*.txt.example` ×6＋`deploy/secrets/README.md`；確認 `.gitignore` 蓋住 `deploy/secrets/*.txt`；本機執行生成 6 個 `.txt` 驗證
- [x] T002 [P] 帶入 `deploy/generate-dev-cert.sh`＋`deploy/dev-certs/.gitkeep`；本機執行生成自簽 cert 驗證（SAN localhost＋127.0.0.1）
- [x] T003 [P] 帶入 `deploy/entrypoint.rust-api.sh`（3-case dispatcher 原樣）＋`deploy/Dockerfile.acme.txt`（4 行殼）

**Checkpoint**: `deploy/` 骨架就位、secrets/cert 本機已生成

## Phase 2: Foundational（rust-api scaffold——blocking 全部 US）

**Purpose**: rust-api worktree 首批 code（從零重寫、受控參照；research R3/R4/R5/R6）。⚠️ 此 phase 動 worktree——commit 走兩段式（T021）

- [x] T004 建 `rust-api/Cargo.toml`（workspace members=["server","migration"]＋workspace.dependencies：axum 0.7／tokio 1〔macros,rt-multi-thread,signal〕／sea-orm-migration 1.1.20〔sqlx-postgres,runtime-tokio-rustls〕／tracing 組）＋`rust-api/rust-toolchain.toml`（channel "1.86"）
- [x] T005 [P] 建 `rust-api/server/Cargo.toml`＋`rust-api/server/src/main.rs`：axum `GET /health` → 200 text/plain `ok`、bind `0.0.0.0:31081`、tracing 最小初始化（契約：contracts/health-endpoint.md）
- [x] T006 [P] 建 `rust-api/migration/Cargo.toml`＋`rust-api/migration/src/{lib.rs,main.rs}`：空 migrator（`migrations() → vec![]`）＋`mNNN_<name>` 慣例注記（lib.rs 註釋＋`rust-api/migration/README.md`：⚠️k、002 刀 m001/m002 預告）
- [x] T007 `cd rust-api && cargo build --bins` 自產 `Cargo.lock`＋驗 sea-orm-migration 解析版本＝1.1.20（非則 `cargo update -p sea-orm-migration --precise 1.1.20` 拉回）＋執行 time/home pin（`cargo update -p time --precise 0.3.37 && cargo update -p home --precise 0.5.9`——拆兩次呼叫、`--precise` 限單一 package；若 home 不在依賴圖則註記免 pin；research R3 坑）＋重 build 驗證＝C-V-1（host 無 cargo 時以 rust:1.86-slim-bookworm 容器執行等效）；commit lock
- [x] T008 建 `deploy/Dockerfile.rust-api.txt`：3-stage 裁剪版（builder COPY 僅 server/migration＋cp 2 binary；dev stage `cargo watch --poll -x "run --bin server"`；runtime stage dispatcher＋HEALTHCHECK `curl 127.0.0.1:31081/health` 10s/3s/5s/3、非 root uid 10001、EXPOSE 31081）（research R4）

**Checkpoint**: `cargo build` 綠＝scaffold 獨立可驗；Dockerfile 就位

## Phase 3: US1 — 一鍵啟動 dev stack（P1）🎯 MVP

**Goal**: dev 組合 `up -d --wait` 5 service 全 healthy＋migrate gate 驗通
**Independent Test**: C-V-0/1/2/4/5（dev 部分）全綠

- [x] T009 [P] [US1] 帶入 `deploy/nginx/`（nginx.conf＋conf.d/{_locations.inc,dev.conf,prod.conf}）＋port 改名（base-web:21079→31079、rust-api:21081→31081、listen 21080/21443→31080/31443）（research R2）
- [x] T010 [US1] 建 `docker-compose.yml`（master base）：裁剪帶入＋改名——5 service＋migrate＋acme 殼；裁 8 service/4 卷/2 secrets（research R1）；redis pin `redis/redis-stack-server:7.4.0-v8`（⚠️d）；`name: rev3-admin`＋`rev3_net`＋7 卷＋6 secrets；base 層禁 host ports／base-web 不放 image-build-command（rev2 R1/H1 規則 carry）
- [x] T011 [US1] 建 `docker-compose.dev.yml`：裁剪帶入＋改名——loopback 31xxx 全組；base-web 段採 standalone 已驗定義（node:26-alpine＋pnpm@10＋store redirect＋CI=true，research R8）；rust-api dev target＋bind mount＋cargo_cache/target 卷＋JWT env fallback；migrate entrypoint override（`cargo run --bin migration`＋`command:["up"]`）；postgres 35432／redis 36379
- [x] T012 [US1] 組態驗證：`docker compose -f docker-compose.yml -f docker-compose.dev.yml config -q` 通過＋已交付各檔 `grep -i rev2` 歸零（C-V-5 dev 部分）
- [ ] T013 [US1] dev 實機驗收：C-V-0（standalone down＋secrets/cert 就緒）→ C-V-2 全套（`up -d --wait` exit 0／ps 5 healthy＋migrate exited(0)／gate 時序雙斷言／健檢 6 點含 Content-Type）→ C-V-8（缺 secrets fail-fast 負向＋重複 up 冪等；Edge case 2 豁免註記確認）
- [ ] T014 [US1] 持久化驗收 C-V-4（probe 表寫入→down→up→存活→清除）

**Checkpoint**: US1 全綠＝MVP 達成（SC-001/002/003/004）

## Phase 4: US2 — 統一入口路由（P2）

**Goal**: 入口路由行為正確（strip／擋塊／前端／自答）
**Independent Test**: C-V-3 對運行中 stack 獨立執行

- [ ] T015 [US2] proxy 鏈驗收 C-V-3：`/api/health`→`ok`（strip 證明）／`/api/metrics`→404（擋塊）／`/`→base-web HTML／`/health`→入口自答；任一 fail 修 `deploy/nginx/conf.d/_locations.inc` 後重驗（SC-007）

**Checkpoint**: US2 全綠（SC-007）

## Phase 5: US3 — prod baseline 起停演練（P3）

**Goal**: prod 組合起停 sanity＋prod image build 紀律
**Independent Test**: C-V-6/7 獨立執行

- [ ] T016 [US3] 建 `docker-compose.prod.yml`（裁剪帶入＋改名：0.0.0.0:80/443、prod.conf、front_nginx_certs 卷、rust-api runtime target :latest、migrate dispatcher `command:["migration","up"]`、base-web build args `VITE_SERVICE_BASE_URL=/api`、acme 卷）＋帶入 `deploy/Dockerfile.base-web.txt`（port 改名 21079→31079）（research R1/R2）
- [ ] T017 [US3] prod 組態驗（`config -q`）＋cert seed 進 `rev3-admin_front_nginx_certs` → C-V-6 起停 sanity（80 `/health` 例外 ok／`/` 301→https／down 乾淨）
- [ ] T018 [US3] prod target image build：C-V-7（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`——**CLAUDE.md §3 紀律：本刀新增 workspace crate 必含**，防 dev bind-mount 遮 COPY 缺口）

**Checkpoint**: US3 全綠（SC-005）

## Phase 6: Polish & Cross-Cutting

- [ ] T019 [P] 帶入 `docker-compose.rust-api.yml`（standalone debug 後備：DEPRECATED 同款定位標註＋改名 31081；research R9）＋`config -q` 驗
- [ ] T020 總驗：全交付物 `grep -ri rev2` 歸零（C-V-5 全量）＋quickstart.md 流程逐步對照（文件與實況零漂移）＋`docker compose config -q` dev/prod 雙組合終驗
- [ ] T021 兩段式 commit 收口（**commit only——任何 push／merge 凍結至 `superpowers:finishing-a-development-branch`，constitution §I.4**）：①`cd rust-api`──scaffold 首批 commit（conventional、中文；**不 push**——SHA pin 指向本機 commit 完全合法，remote 一致性由 finishing 階段一次補齊）②outer──`git add rust-api`（SHA pin）＋compose×4＋deploy/ 全交付物 commit（feature branch、**不 push 不 merge**）

## Dependencies

```
Phase 1 (T001-T003) ──→ Phase 2 (T004-T008) ──→ Phase 3/US1 (T009-T014) ──→ Phase 4/US2 (T015)
                                                                          └─→ Phase 5/US3 (T016-T018) ──→ Phase 6 (T020-T021)
T019 [P]：任何時點可做（獨立檔、不在主鏈上）
內部：T004 → T005∥T006 → T007 → T008；T009 可與 Phase 2 並行（不同樹）；T010 → T011 → T012 → T013 → T014
US2(T015) 依賴 US1 stack 運行中；US3(T016-018) 依賴 Phase 2 產物＋T010
```

## Parallel Execution Examples

- Phase 1：T002∥T003（T001 先行確認 .gitignore）
- Phase 2：T005∥T006（T004 完成後）；T009 [US1] 可與整個 Phase 2 並行
- Phase 6：T019 可提早並行

## Implementation Strategy

**MVP first**：Phase 1→2→3（T001-T014）＝US1 達成即可交付最小價值（dev stack 可用）；US2 驗收（T015）幾乎零成本緊接；US3（T016-018）與 Polish 完成全刀。每 phase checkpoint 過了才前進；任一 acceptance fail＝修復後重跑該 C-V、不帶病前進。
