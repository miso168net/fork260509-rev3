# Implementation Plan: infra-deploy（rev3 部署地基）

**Branch**: `001-infra-deploy` | **Date**: 2026-06-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-infra-deploy/spec.md`＋brainstorm `docs/superpowers/001-infra-deploy.md`（五項拍板＋⚠️t）

## Summary

裁剪帶入 rev2 outer 部署層（master compose＋dev/prod override＋deploy/ 子集，token 改名 rev2→rev3、port 2X→3X、redis pin `7.4.0-v8`）＋從零重寫 rust-api 最小 scaffold（workspace：`server`〔axum `/health`〕＋`migration`〔空 migrator〕），實機達成 dev stack 5 service `up --wait` 全 healthy＋migrate gate 驗通＋prod baseline 起停 sanity。

## Technical Context

**Language/Version**: Rust 1.86（rust-toolchain.toml；rev2 as-built 鎖點＝rev3 起點，DESIGN §1.6）；Shell（compose/deploy scripts）

**Primary Dependencies**: axum 0.7、tokio 1、sea-orm-migration 1.1.20（含 time/home pin 對策，research R3）；Docker 29.x／Compose v5.x；nginx:1.31.0-alpine、postgres:17-alpine、redis-stack-server:7.4.0-v8（⚠️d）、node:26-alpine（base-web dev，沿 standalone 已驗證）

**Storage**: PostgreSQL 17（本刀僅 migrate 空跑建框架表；業務 schema＝002 刀 ⚠️t）；Redis Stack（本刀僅 healthcheck 連通）

**Testing**: 實機 acceptance（C-V：compose 狀態＋curl＋時序證據；contracts/verification-commands.md）。**無單元測試**——本刀純 wiring/infra、無可獨立測之純函式（`/health` 回常數屬 trivial）；依 CLAUDE.md §3 紀律於此明示，tasks.md 同步聲明。

**Target Platform**: Linux（WSL2 mirrored networking）＋Docker；prod 組態同套定義（演練級）

**Project Type**: infra/deployment（compose 編排＋最小 web-service scaffold）

**Performance Goals**: N/A（啟動完成以 `--wait` 信號定義；效能數字＝⚠️a 波 1 拍板）

**Constraints**: base 層禁 host ports／禁環境專屬掛載（rev2 R1）；base-web service 不放 image/build/command（rev2 H1）；healthcheck 容器內一律 `127.0.0.1`（alpine IPv6 坑）；port 3XXXX 段；卷靠 `name: rev3-admin` auto-prefix（§8.2.2）

**Scale/Scope**: 5 service＋migrate＋acme 殼；compose ×4＋deploy/ 約 18 檔（含 6 example＋README）＋scaffold 2 crate；單機 dev／演練 prod

## Constitution Check

*constitution-rev3 v1.0.0（2026-06-12 凍結）§IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 為權威？ | **PASS**——本刀無業務 endpoint；base-web 納入 master 沿 standalone 已驗證定義、零 inline 變動 |
| 2 | 動 base-web inline？ | **PASS（未觸）**——compose/deploy 全在 outer 層、scaffold 在 rust-api worktree；不涉 MODAL-WIRING |
| 3 | menu 顯示走 Casbin enforce？ | **N/A**——不涉 menu（⚠️p seed＝002 刀） |
| 4 | wire 對齊 §I.3 typings 權威序？ | **PASS**——唯一新 wire＝`GET /health`→plain text `ok`，為 §I.3「envelope universal 例外僅 2：`/health`/`/metrics`」明文允許形；無業務 wire |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——outer compose/deploy＝帶入改名（DESIGN 波 -1 既定策略，非 §I.5 標的——§I.5 管 rust-api source tree）；rust-api scaffold＝從零重寫、受控參照（讀 rev2 對照、重新打字）；本刀不消費 §I.5 拷貝例外（sea-orm-adapter/xdb＝後刀）；防回歸條款——scaffold 無業務行為、無可帶回的已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——#11 `/api/*` 前綴＝直接落實（nginx strip＋metrics 擋塊）；⚠️d/⚠️k 落值；無任何拍板需改變 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸）**——不動 `views/manage/**`；fork-delta 紀律（⚠️s）不適用（本刀無 base-web worktree 變動） |
| 8 | 新建業務表？ | **PASS（否）**——migration 空跑；`seaql_migrations` 為框架表（DESIGN 附錄 F #12 明列「不入 §8.8 drift 基線」）、非業務主表、不受 §I.6 約束 |
| 9 | 觸 §I.7 行為島？ | **N/A**——token rotation／policy governance／single-session 均不在本刀 |

**Gate 結論：9/9 PASS，無需 amendment、無 violation 待 justify。**

## Project Structure

### Documentation (this feature)

```text
specs/001-infra-deploy/
├── spec.md              # /speckit-specify ✅
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R11）
├── data-model.md        # Phase 1（本刀無資料模型之聲明）
├── quickstart.md        # Phase 1（從零驗證指南）
├── contracts/
│   ├── verification-commands.md   # C-V 驗收命令全集（含 prod image build 紀律）
│   └── health-endpoint.md         # /health＋dispatcher 契約
├── checklists/requirements.md     # 16/16 ✅
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
├── docker-compose.yml            # 新（裁剪帶入＋改名）：5 service＋migrate＋acme 殼＋6 secrets＋7 卷＋rev3_net
├── docker-compose.dev.yml        # 新（帶入裁剪）：loopback ports 31xxx、bind-mounts、dev certs、cargo-watch target
├── docker-compose.prod.yml       # 新（帶入裁剪）：80/443、prod.conf、certs 卷、runtime target、build args /api
├── docker-compose.rust-api.yml   # 新（帶入、debug 後備定位＋標註）
├── docker-compose.base-web.yml   # 既有不動（standalone、已驗證）
├── .dockerignore                 # 實作期授權補帶（T010 review I-1：rust-api build context=repo root、擋源倉/graphify/機密）
├── deploy/                       # 新目錄
│   ├── .dockerignore             # 實作期授權補帶（T010 review I-2：acme build context=deploy/、擋 secrets/dev-certs）
│   ├── Dockerfile.rust-api.txt   # 3-stage：builder（2 binary）/dev（cargo-watch --poll）/runtime（dispatcher＋HEALTHCHECK）
│   ├── Dockerfile.base-web.txt   # prod base-web multi-stage（prod.yml 引用）
│   ├── Dockerfile.acme.txt       # 4 行殼
│   ├── acme-entrypoint.sh        # 實作期授權補帶（T003：Dockerfile.acme COPY 依賴、R1 列舉遺漏）
│   ├── entrypoint.rust-api.sh    # 3-case dispatcher（原樣）
│   ├── nginx/{nginx.conf, conf.d/{_locations.inc,dev.conf,prod.conf}}   # port 31xxx
│   ├── generate-dev-cert.sh ＋ dev-certs/.gitkeep
│   ├── generate-secrets.sh       # 6 secrets 版
│   └── secrets/{*.txt.example ×6, README.md}
└── rust-api/                     # worktree（首批 code、兩段式 commit）
    ├── Cargo.toml                # workspace=["server","migration"]＋workspace.dependencies
    ├── Cargo.lock                # 自產＋home pin（R3；time 不在依賴圖、免 pin）
    ├── rust-toolchain.toml       # channel 1.86.0（實作期落值 patch 版，見 research R3）
    ├── server/{Cargo.toml, src/main.rs}        # axum /health → "ok"、bind 0.0.0.0:31081
    └── migration/{Cargo.toml, src/{main.rs,lib.rs}}  # 空 migrator＋mNNN_<name> 慣例注記
```

## Phase 0：研究結論

見 [research.md](research.md)——R1 裁剪邊界／R2 改名表／R3 版本鎖點＋time/home 坑／R4 scaffold 與 Dockerfile 裁剪／R5 health 契約／R6 migrate 空跑與 gate／R7 redis pin／R8 base-web dev 定義／R9 standalone 定位修正／R10 三 grep 紀律 N/A 聲明／R11 secrets 集合。NEEDS CLARIFICATION＝0。

## Phase 1：設計產物

- [data-model.md](data-model.md)：本刀無資料模型聲明（schema＝002 刀 ⚠️t；`seaql_migrations` 框架表說明）
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V 驗收全集——dev 硬出口（up --wait／健檢 6 點／proxy 2 點／gate 時序／config 雙組合／grep 歸零）＋prod baseline sanity＋**prod target image build**（CLAUDE.md §3 紀律：本刀新增 workspace crate ⇒ 必含，防 dev bind-mount 遮 Dockerfile COPY 缺口）
- [contracts/health-endpoint.md](contracts/health-endpoint.md)：`GET /health` 契約＋dispatcher 派發契約
- [quickstart.md](quickstart.md)：從零驗證指南（secrets→certs→up→驗收→prod 演練→down）

## 實作注意（移交 tasks）

1. **順序**：scaffold（worktree、可獨立 `cargo build` 驗）→ deploy/ 帶入改名 → compose 三件套 → standalone → 實機驗收（dev 硬出口 → prod sanity → prod image build）→ 兩段式 commit（rust-api 第一段→outer pin 第二段）
2. **裁剪殘留雙保險**：每檔帶入後 `grep -i rev2` 即驗；compose 完成後 `docker compose config` dev/prod 兩組合
3. **port 撞**：實機驗收前 `docker compose -f docker-compose.base-web.yml down`（standalone 與 master 的 base-web 同 port 31079）
4. **push/merge 全凍結（§I.4）**：實作期一律 commit only——rust-api worktree commit 不 push（SHA pin 指向本機 commit 合法）、outer feature branch 不 push 不 merge；全部 remote 同步由 `superpowers:finishing-a-development-branch` 階段一次補齊（屆時 push 仍依 §4.1 徵 user 同意）
