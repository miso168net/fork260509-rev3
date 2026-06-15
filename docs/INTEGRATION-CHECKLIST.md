# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 0 地基 ✅ 全完成（001-007）→ 波 1 第一刀＝User 直刀 ✅ 全綠收刀＋merge（008-user-management、`b8de602`、2026-06-15、= 波 1 完成）→ 波 2 data islands 待開**（as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-15 008-user-management 全綠收刀＋merge（波 1 第一刀＝User 直刀③=A、波 1 完成）**:6 端點＋7 facade＋wire DTO＋composite role-delta 審計（複用 005 `mutate_in_txn`）＋6 route `enforce_mw` gated＋**`endpoint_coverage_lint` stand-up（⚠️x 移交、SC-009、controller sanity-bitten 真咬）**；零 migration／零新 crate；前端 `rev3-system-manage.ts` wrapper×4＋MODAL-WIRING(a)(c)（`system-manage.ts`/`auth.ts`/`route.ts` 零改）；41 task subagent-driven TDD＋兩段式 review（spec→quality）；109 純測＋9 lint＋22 entity_lint＋5 live smoke＋curl/psql＋**CDP modal smoke（C-V-6 clean pass）**＋p95 12/14.6ms 全綠；10 SC／Constitution PASS；**CDP smoke 抓到並修空字串 filter bug**（`0de38d6`、FR-002 空欄略過、curl 乾淨 query 掩蓋＝curl≠modal 印證、見 [[empty-string-query-params-mask-by-curl]]）；Q3 dup→**2222 非 5000**／種子保護（單+批 all-or-nothing、FR-016 可編輯）；worktree rust `0de38d6`/base-web `00911793`、merge `b8de602`
- **2026-06-15 波 1 前維護批**:① 波 1 前清債〔node26／nginx 1.31.1〔CVE-2026-42945〕／postgres healthcheck／openssl pin／secret 文件〕② 揮發行號 ref 全清（→穩定 §章節錨、見 [[brainstorm-doc-decision-table-not-warn-codes]]）③ graphify 003-007 同步進圖;拆 5 commit（worktree `01e1263`／outer `9fd7005` 等）

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **波 1 第一刀（User 直刀）已收＝波 1 完成 → 波 2 data islands**（Role 刀／Menu 刀／system_settings 刀；素材 DESIGN §8.2；⚠️b 審計查詢讀端＋UI 待拍〔波 2 排程前〕）。波 1 wave-collapse 已歸檔（本檔 §2 波1 收縮＋[DECISIONS §2](INTEGRATION-DECISIONS.md) as-built）。008 follow-up 見本檔 §3.11（均不阻塞）。

---

## 2. Roadmap & Phase 狀態

對齊 CLAUDE.md §3 SDD-TDD 工作流 + [DESIGN §8.4 交付波次](INTEGRATION-DESIGN.md)（波次定義/出口條件在彼）。本節為動態 status 追蹤;完成波 as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);完成波摘要累積數波後批次搬 [MILESTONES §2](INTEGRATION-MILESTONES.md)、本節永遠聚焦當前波。

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> 機械建構＋constitution 重鑄兩段全交（pre-spec-kit、全落 default branch、無 feature branch）:outer repo＋worktree/submodule 註冊 `2ec9cda`（⚠️j/⚠️q）/ 設計書入檔＋拍板回填＋歸位改名 `7fd1ac6`→`4aa7c89` / C 方案文件體系 DECISIONS+CHECKLIST+MILESTONES `4724549`・`4300b54` / graphify 首建 `8f66fe0` / 000 base-web bootstrap＋13 端點對映 `46591c4`~`e898421` / SessionStart hook 原樣承接 `ed2a789` / **constitution-rev3 v1.0.0 凍結 `167db96`**（13 項拍板融入）。出口四項全綠（session 健檢/獨立 commit/grep rev2 歸零/speckit 可用）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基 ✅ 全完成+已歸檔 (2026-06-15)

> 七刀全收（001 infra-deploy `c9ffad5`／002 schema-baseline `9233ae0`／003 envelope `7960a73`／004 soft-delete `e8334d7`／005 audit-op-log `65f4bbe`／006 auth-island `2c5a2a1`／007 audit-overlay `9046b63`）；rev2 001-012+015 對應跨切地基。**前置拍板 4 項全拍完（2026-06-13：①flat-in-main／④僅 join 表 FK／⚠️d redis pin 數字版／⚠️k 短編號 migration）**。**出口四項全綠**：dev stack `up --wait` healthy（001）／三守恆〔entity_access_lint ✅〔004〕・migration up→down→up ✅〔002〕・endpoint_coverage_lint **波 0 換波豁免**〔⚠️x user 親決 2026-06-14、移交波 1 第一刀〕〕／envelope 13 碼 contract 綠（003）／login→getUserInfo→enforce 鏈 curl 通（006）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)、per-刀 commit 見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 1 — 第一刀＝User 直刀 ✅ 全完成+已歸檔 (2026-06-15)

> 008-user-management（③=A User 直刀）全鏈一刀逼出 migration→facade→handler→enforce→wire→frontend：6 端點＋7 facade fn＋wire DTO（i16↔string／2^53 guard）＋composite role-delta 審計（複用 005 `mutate_in_txn`）＋6 route `enforce_mw` gated（首批 gated 業務端點）＋`endpoint_coverage_lint` stand-up（⚠️x 移交、SC-009 硬 gate、sanity-bitten）；**零 migration／零新 crate**（schema/seed/policy 全在波 0、m002 6 端點已 seed）；前端 `rev3-system-manage.ts` wrapper×4＋MODAL-WIRING(a)(c)（system-manage.ts/auth.ts/route.ts 零改、`rev3-inline` 標記）。前置拍板 ③A／⚠️a／⚠️o 全拍。出口三項全綠：§8.1 工序全過／CDP 經 front-nginx 真 `/api` modal smoke clean pass／entity §5.0 各面勾消。109 純測＋9 lint＋22 entity_lint＋5 live smoke＋curl/psql＋CDP＋p95 12/14.6ms 全綠；10 SC／Constitution PASS；CDP 抓修空字串 filter bug（`0de38d6`、FR-002）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)、per-task commit 見 worktree git／merge `b8de602` 回 rev3-admin-root、feature branch 保留。

### 波 2 — data islands（未開始）

其餘業務 entity 各一刀（rev2 016 一 feature 兩 entity → rev3 拆兩刀紀律）。

**刀/feature 清單**（素材=DESIGN §8.2 data island 縱切;波 1 拍 ③ 後本清單定稿）:
- [x] ~~**User 刀**~~ → **③=A、已移波 1 交付**（User 直刀＝波 1 第一刀、本列消解）
- [ ] **Role 刀**（rev2 013*/016*/018;schema 起點在 rev2 013〔sys_role+sys_user_role+policy seed〕）
- [ ] **Menu 刀**（rev2 014〔runtime 讀〕/019/020/021/025;DB-driven＋CRUD＋MenuAuth＋回收桶 restore/re-parent）
- [ ] **`system_settings` 刀**（§5.6 熱 KV/pub-sub＋settings_watcher;rev2 029 對應;若③=A 掛此波）
- [ ] **（⚠️b 核可後）審計查詢讀端＋UI 刀**（三 log 讀端＋R_SUPER policy seed＋manage 新頁〔MODAL-WIRING use (e)〕;DESIGN §8.2 待拍板刀位）

**前置拍板（user 親決,1 項）**:
- [ ] ⚠️b 審計查詢讀端＋UI 補做（預設=補、Super-only;波 2 排程前）

**出口條件（DESIGN §8.4）**:
- [ ] 各刀工序全過
- [ ] §7.1 對應 endpoint 兩端俱在、contract test 綠

### 波 3 — 行為島＋policy（未開始）

行為島 2 刀＋policy 縱切。de-risk:治理島形狀應於波 1-2 期間先 spike（可拋棄、不算交付;DESIGN §8.5）。

**刀/feature 清單**（素材=DESIGN §8.2 行為島/policy 縱切、§4 三台狀態機）:
- [ ] **Auth/Token/Session 合刀**（§4.1+§4.3 兩台機器:rotation chain＋reuse 偵測＋single-session pointer＋policy 三態;rev2 013*/026/027/028/029/030;cleanup-job=本刀 L8 binary）
- [ ] **Policy-governance 刀**（§4.2:治理欄 adapter-invisible＋archive 表＋protected＋restore＋`PolicyMutated` gate;rev2 034/035）
- [ ] **Button/Endpoint policy 縱切**（runtime 三維授權編輯＋rollout;rev2 022/023/024;純 policy、無新 entity、非行為島）
- [ ] **（⚠️m 拍板後）alt-login stub 刀**（§1.2 尾巴 4 流程 stub;captcha 2 端點已隨 ⚠️c 定案;DESIGN §8.2 待拍板刀位）

**前置拍板（user 親決,1 項）**:
- [ ] ⚠️m alt-login 4 流程 stub 入波排程（預設=入波;本項殘餘僅 alt-login;波 3 排程前）

**出口條件（DESIGN §8.4）**:
- [ ] §4 三台機器 invariants 逐條有自動化驗證（單測或 C-V contract）
- [ ] 7777/8888 兩通道 CDP 實證
- [ ] protected 拒撤 live 驗證

### 波 4 — observability（未開始）

包覆全體之刀（profiles opt-in、一般 `up` 不啟）。無前置拍板（⑥a-d 為「入波排程時」、不阻塞本波）。

**刀/feature 清單**（素材=DESIGN §8.2 包覆全體）:
- [ ] **obs-min 刀**（loki＋alloy＋grafana 純 log 三件套、72h retention;rev2 031）
- [ ] **obs-full 刀**（prometheus＋2 exporter＋pushgateway＋baseline alert＋rust-api `/metrics` in-process 埋點;rev2 032）
- [ ] **dashboard provisioning 刀**（grafana 面板 provisioning;rev2 033）

**出口條件（DESIGN §8.4）**:
- [ ] obs/metrics profile 起停乾淨（一般 `up` 不啟）
- [ ] provisioning 重建無 crash-loop
- [ ] rust-api log/metrics 兩軌可查

---

## 3. Follow-up Backlog

### 3.1 000-base-web-docker-bootstrap follow-up

- [x] ✅（2026-06-13）`getUserList` CDP 瀏覽器流量補抓 → `tests/000-.../getuserlist-cdp-capture.json`（mock 版;rust-api 版由接線 feature CDP smoke 覆蓋）
- [ ] dynamic route mode 切換後重抓 `/route/*` 真實瀏覽器流量（對象屆時為 rust-api,詳 000 文件 §7）
- [x] ✅（2026-06-13）`cdp-nav/login/clear-and-relogin.mjs` 三支重測全通過（000 文件 §3.2,含 mock 限流 gotcha）
- [x] ✅（2026-06-13）standalone compose 與整套 stack 的整合/退場——001 落地:base-web 段以 standalone 已驗定義納入 master dev.yml（R8）、standalone 檔保留並存;rust-api standalone 以 DEPRECATED debug 後備帶入（R9）

### 3.2 graphify follow-up

- [x] ✅（2026-06-13）`graphify update` — code 層 rebuild 完成（4176 nodes/4421 edges/567 communities）;**「docs 同步」前提不成立而關閉**:`.graphifyignore` 刻意排除 `docs/`（圖譜定位=code 圖,CLAUDE.md §8.3）,docs 從未入圖、無舊檔名殘留;`graphify-out/memory/` 的舊名屬歷史 Q&A 存檔不需改。docs 要不要入圖=另案（若要,先拔 `.graphifyignore` 的 `docs/` 行再 update;統計細節該記入 GRAPHIFY-NOTES ⏳）

### 3.3 fork-delta 工具 follow-up（⚠️s 衍生）

- [ ] `inline_coverage_lint` 候選:`grep -c rev3-inline` 對 spec 紀錄數,rebase 後驗足跡不丟失（rev2 endpoint_coverage_lint 同款思路;等 ⚠️q 移植 feature 一併評）
- [x] ✅（2026-06-13）git 配套設定:`merge.conflictStyle=zdiff3`＋`rerere.enabled=true` 已設於 base-web/docs 兩源倉（worktree 繼承已驗）

### 3.4 001-infra-deploy follow-up（收刀 review 鏈＋final review 落檔 2026-06-13;均不阻塞、修時機見各條）

**部署層加固**:
- [x] ✅（2026-06-15、波 1 前清債）nginx 自答 `/health` 雙 Content-Type——`_locations.inc` `add_header Content-Type`→`default_type text/plain`
- [ ] nginx prod 硬化:`server_tokens off`＋HSTS/X-Frame-Options/X-Content-Type-Options（公網前必做）
- [ ] XFF append 可偽造→`set_real_ip_from` 信任邊界（公網前評估）
- [x] ✅（2026-06-15、波 1 前清債）image pin 一致性：**已 pin** `alpine/openssl:latest`→`3.5.4`（兩腳本）／base-web runtime `nginx:alpine`→`1.31.1-alpine`（含 **CVE-2026-42945**）／front-nginx `nginx:1.31.0`→`1.31.1`（CVE）;**刻意保留 major-alpine**（自動收安全 patch）：`postgres:17-alpine`／`node:26-alpine`——pin 紀律＝消除 `:latest`/裸 tag、OS image 走 auto-patch（exact-pin 會丟安全更新、與 CVE 防護相悖）。**node 已定**（user 2026-06-15：統一 `node:26-alpine` major〔builder+dev〕、prod build 驗綠、非 exact-pin）;**postgres 已定**（user 2026-06-15：保留 `postgres:17-alpine` major、auto 收安全 patch、非 exact-pin——DB 釘死反丟安全更新、與 CVE 防護相悖）。**pin 紀律確立**：消除 :latest/裸 tag、OS image 留 major-alpine 走 auto-patch、reproducibility 由 Cargo.lock/`--locked` 在 build 層保證
- [x] ✅（2026-06-15、波 1 前清債）prod migrate 無意義 HEALTHCHECK——`docker-compose.prod.yml` migrate 補 `healthcheck: disable: true`（runtime image 帶 curl /health、對一次性 migration 無意義＋防 --wait 假陰性）
- [x] ✅（2026-06-15、007 S2）builder `cargo build` 補 `--locked`——007 S2 已在 `deploy/Dockerfile.rust-api.txt` builder 加 `cargo build --release --bins --locked`（守 lock pin、防 manifest／ipnetwork 漂移靜默 re-resolve）。原 005 Unit A 實證背景：**005 Unit A 實證**：Cargo.lock 曾遺漏 sea-orm optional-dep package stanza（`bigdecimal` 等、003/004 遺留），加 `with-json` 首次非 `--offline` build 觸 re-resolve、把 `time` 拉到 0.3.47〔off 文件 pin〕；`--locked` 會 fail-loud 擋下此類靜默 re-resolve（配套見 §3.8 MSRV 條）
- [x] ✅（2026-06-15、波 1 前清債）`docker-compose.base-web.yml` 檔頭補並行撞點警示（同 project `rev3-admin`/卷、勿與 master 同起、用前 down master）
- [x] ✅（2026-06-15、波 1 前清債）compose secrets 預檢——`deploy/secrets/README.md` 補「up 前必先生成、缺檔會 bind 成空目錄、錯誤不指向缺檔」註記（文件版）
- [ ] `front_nginx_certs` 要不要 `external: true`（消 compose warning vs 硬前置;拍板項）
- [x] ✅（2026-06-15、波 1 前清債）migrate redis depends_on 措辭——`docker-compose.yml` migrate 補註解「僅閘 postgres、不需 redis；spec FR-002/C-V-2 措辭待勘誤」（impl 正確、註明）
- [x] ✅（2026-06-15、波 1 前清債）postgres healthcheck 補 `-d soybean_admin_rust`——`docker-compose.yml:101` `pg_isready -U soybean`→`pg_isready -U soybean -d soybean_admin_rust`（原缺 -d、dbname 預設=username `soybean`→每 10s 一條 `FATAL: database "soybean" does not exist`，實證後修）。⚠️ 跑著的容器需 recreate 才生效;rev2 同形、回灌時修
- [ ] dev watcher 工具評估:cargo-watch 上游已 archived＋`cargo install` 無版本 pin＋無 cache mount（dev image build 慢）→ 後刀換 bacon/watchexec 屬顯式決策（rev2 形 carry）
- [x] ✅（2026-06-15、波 1 前清債）冷卷首啟 flap → CLAUDE.md §8.2.1 補註記（exit≠0 先 ps 區分仍在編譯、待穩重跑）
- [ ] C-V-2 gate 斷言①複驗方法注記:重複 `up` 會讓 migrate one-shot 重跑、刷新 inspect 時戳（假陰性）;複驗用 `docker logs --timestamps` 首輪——波 0 出口複驗時適用
- [ ] dispatcher `server)` 分支不 shift 不傳 `"$@"`（與 migration/cleanup-job 不對稱;多餘參數靜默丟棄;blob-identical 凍結下傾向 won't-fix、僅記錄）
**腳本**:
- [x] ✅（2026-06-15、波 1 前清債）generate-secrets 刪 leaf 重跑 drift——`deploy/secrets/README.md` 補「刪 leaf 重生但跳過既有 URL→drift」警語（README 版）
- [x] ✅（2026-06-15、波 1 前清債）generate-dev-cert.sh——私鑰 `chmod 600`（ca.key/privkey.pem）＋ TRUST 訊息註明「自簽 `--force` 一併重生 CA、需重 trust」
- [x] ✅（2026-06-15、波 1 前清債）generate-* 兩腳本 `docker pull` → `docker image inspect || docker pull` fallback（離線/已 cache 可跑）
- [x] ✅（2026-06-15、波 1 前清債）outer `.gitignore` 註解前代編號 `003-tls-dev-cert`→`001-infra-deploy`（dev cert 屬 001、rev3 的 003 是 envelope）
**rust-api**:
- [x] ✅（2026-06-13、002/U2）migration main.rs secret 讀檔失敗靜默 fallback→補 eprintln 警示（`inspect_err`、行為不變）
- [ ] `set_var` 於 runtime 啟動後（edition 2024 升級時根治）
- [x] ✅（2026-06-14、005 Unit A）workspace Cargo.toml time pin 註解勘誤——005 加 with-json 首次非 --offline build 補齊 lock 時 time 解析為 0.3.47（feature-gated 未編譯、user 拍板接受）、順手把「pin time=0.3.37」改為「home=0.5.9 pin；time 不入 compile graph、版本對 1.86 build 無影響、不變式＝不啟用拉 time 的 feature」
- [x] ✅（2026-06-15、波 1 前清債）rust-api/.gitignore `debug`/`target` 錨定為 `/debug`/`/target`（防誤吞同名子目錄）
**拍板/上游**:
- [x] ✅（2026-06-14、006）JWT `_FILE` vs 直值 env 優先序——006 `state::file_or_env(file_var,direct_var)`：`_FILE`（讀檔 trim）優先、直接 env fallback、皆缺→boot panic（fail-loud）;同形共用於 jwt secret（access/refresh）＋db url（main 重用）
- [x] ✅（2026-06-15、波 1 前清債）prod builder node:20.19 vs dev node:26 分歧——**統一 node:26-alpine**（user 決定 2026-06-15；builder 20.19→26、corepack 既被 npm-pnpm 跳過故 node 版本無關；**prod base-web build 實機驗綠**〔vite build successful、image Built〕）
- [x] ✅（2026-06-15、波 1 前清債）cargo cache 卷遮蓋——CLAUDE.md §8.2.1 補註記（升 toolchain 需手動 `volume rm rev3-admin_rust_api_cargo_cache`）
- [ ] 兩段式 commit pin 時點紀律提案:worktree commit 落地的**當個 task** 即 bump outer pin（001 全延到 T021、中繼 15 個 outer commit 的 pin 過期、checkout 不可重現 tasks 勾選聲明）→ 提案補進 CLAUDE.md §4.1（user 核可後改）;**003 已實踐 per-unit pin bump（每 Unit review 過即 bump、pin 全程==worktree HEAD）、實證可行**
- [ ] **rev2 repo 回灌通知**:redis-stack `--dir /data` 持久化 bug 為 rev2 同形潛伏（rev2 `docker-compose.yml` redis command 同款缺 `--dir`）——rev2 維護時修

### 3.5 002-rev2-schema-baseline follow-up（收刀移交 2026-06-13;均不阻塞、消費刀觸發時處理）

**Menu 刀消費（research.md R4 D2~D4 移交）**:
- [ ] `RouteMeta` 擴充:localIcon/multiTab/href 序列化＋`menu_node_to_route` 讀 `icon_type`（rev2 wire 不序列化這些欄、屬接線議題;**影響面 href 落值實為 ×10**〔原生 2＋D2 href 化 8〕、勿按原生 ×2 低估）
- [ ] iframe props 內嵌復原評估（D2:document 8 頁 props.url 現 href 化外開;iframe 內嵌需 props 欄位/wire 擴充）
- [ ] `filter_routes` 遞迴化評估（D3 配套:現 demo policy 全覆蓋 66 列為前向相容、filter 只查兩層;遞迴化後可收斂為嚴格最小集）
**rust-api 順手（002 引入後重驗）**:
- [x] ✅（2026-06-14、005 Unit A）workspace Cargo.toml time pin 註解勘誤（見 §3.4 同條、005 收口時一併處理）
**sea-orm-adapter vendored 已知瑕疵（byte-identical 拷貝保留、§I.5;重鑄/測試啟用時處理、U1+U2 review 發現）**:
- [ ] adapter `Cargo.toml` 內 `async-trait`/`tokio` 的 `default-features = false` 對 workspace 繼承條目 redundant → 每次 build 兩條 cargo warning（拷貝紀律刻意保留;日後拍板允許動 vendored manifest 時一併清）
- [ ] adapter `examples/`（rbac_*.conf/csv）為 `#[cfg(test)]` fixture:prod `--bins` build 免 COPY（已驗正確、Dockerfile 有註解），但若日後在 builder/容器內跑 `cargo test` 會缺 fixture（屆時 COPY examples 或 adapter 測試改 env-gate round-trip smoke）
**constitution（待 user 親決）**:
- [ ] ⚠️u constitution §IV 增第 10 題（normalize/驗證流程契約修訂的 amendment 提案;PATCH 級;002 normalize 第六規則為先例——執行期發現假紅源、user 拍板補規則、契約留痕）

### 3.6 003-envelope follow-up（收刀移交 2026-06-13;均不阻塞、消費刀觸發時處理）

**envelope 消費（research.md「移交 tasks 期紀律」＋data-model §7 排除聲明明文移交）**:
- [ ] 各碼實際發出點（`Res::err`/`AppError` 8 建構子的真實呼叫;含 router `.fallback()`→`not_found()`）＋每 route contract coverage gate（＝§2 出口條件已列後刀的 `endpoint_coverage_lint`）——本刀零非測試呼叫;散在 auth/system_manage/enforce/data-island/behavior-island 消費刀逐步接上＋逐 route 補測
- [x] ✅（2026-06-14、006）`AppError` 的 `From<…>` 轉換 impl——006 加 `From<DbErr>`/`From<casbin::Error>`→`internal`（5000、泛型 fallback 供 handler `?` 傳播；login/getUserInfo DB 系統錯誤經此映 5000；enforce role-lookup **刻意不走 From**、顯式 fail-closed 5003）
- [x] ✅（2026-06-14、006）⚠️r id 序列化 2^53 fail-loud——006 getUserInfo `user_id_to_wire(i64)->Result<String,AppError>`（>2^53-1 → `internal` 不靜默截斷、純測釘死 SC-004；userId wire 為 string）。lie ledger 未另立（單點守衛足、後續 DTO 刀沿用同形）
- [x] ✅（2026-06-14、006）**CDP browser smoke 補測**——006＝首個發出 envelope 的 handler 刀、已含 CDP smoke：base-web（`.env.test.local` 指真 rust-api、BASE-WEB-ADAPT L1、gitignored 暫時 override）pwd-login 超级管理员→`POST /auth/login` envelope `code:"0000"` 攔截器判 success→存 `SOY_token`/`SOY_refreshToken`（真 JWT iss=rev3-admin/user_id=1/R_SUPER）→`GET /auth/getUserInfo` 解析→`/login`→`/home`（static 模式止）;證 curl 直送 ≠ base-web 判讀對齊
**dead_code（infra ahead of consumers、實作期觀察）**:
- [ ] envelope/error 公開 API（`Res`/`PageRes`/4 建構子・`BizCode`・`AppError` 8 建構子）目前全 dead_code（非測試零消費、`cargo build` 數條 warning、**無 `-D warnings` gate 故不阻塞 prod build**）;消費刀 wiring 後漸清（Res/AppError→Auth/data island、7777/8888/3333→behavior island 波3）;**wiring 後仍殘留 dead_code 的建構子＝無真實消費者、回頭檢視是否 over-built**

### 3.7 004-soft-delete-infra follow-up（收刀移交 2026-06-14;均不阻塞、消費刀觸發時處理）

**dead_code（infra ahead of consumers、實作期觀察）**:
- [x] ✅（2026-06-14、006 Auth wiring）facade 讀 fn 全消費、dead_code 清、**非 over-built**：`find_active_by_name`←login(`handler/auth.rs`)／`find_active_by_id`←getUserInfo／`find_role_ids_by_user_id`+`find_active_by_ids`←新 `roles_for_user`(`facade/sys_user_role.rs`)／`roles_for_user`←enforce_mw+login+getUserInfo（`find_active`/`SoftDeletable` trait/impl 經 find_active_by_* 串到消費）。entity crate `Model` 為 lib API、本不受此 warning
**rust-api 未來 entity 刀**:
- [ ] sea-orm date-time backend:entity crate sea-orm 加 `with-chrono`（workspace `default-features=false` 無 backend、time 不入圖、chrono 已在 lock 無新下載）;feature unification 使 workspace 共用 sea-orm build 全得 `DateTimeWithTimeZone`——**未來帶 timestamptz 欄 entity 沿用 entity crate 即可**;新增獨立 crate 直接用 sea-orm（resolver=2、不經 entity 圖）才須自加。見 `entity/Cargo.toml` 註＋memory [[sea-orm-entity-datetime-feature-gate]]
**未來 live-smoke 刀注意**:
- [ ] (a) live test 須放 `src/` 內 `#[cfg(test)] mod`（server bin-only 無 lib target、`tests/` integration 拿不到 facade API）;(b) compose network 內跑時網路名 = **`rev3-admin_rev3_net`**（`specs/004-.../contracts/verification-commands.md` C-V-4 的 `rev3-admin_default` 為 stale placeholder、實際自訂網路 `rev3_net`＋project prefix）

### 3.8 005-audit-op-log follow-up（收刀移交 2026-06-14;均不阻塞、消費刀觸發時處理）

**dead_code（infra ahead of consumers、實作期觀察）**:
- [ ] audit 機制全鏈（`mutate_in_txn`／`AuditEvent`／`AuditOperation` 的 Insert/Update/Restore 三變體／`AuditSerialize` trait／`write_in_txn`／`audit_active_model`）＋`sys_user::soft_delete`／`soft_delete_query` 目前全 dead_code（server bin crate、無真實消費者、`cargo build` 數條 warning、無 `-D warnings` 不阻塞）;第二 audit 刀（接機制）＋User/管理刀（接 soft_delete 刪除端）＋其餘寫路徑（Insert/Update/Restore 用 SoftDelete 以外操作別）wiring 後漸清;**wiring 後仍殘留＝無真實消費者、回頭檢視 over-built**（同 §3.6/§3.7 紀律）
**redact 紀律傳播（Unit C code review 觀察）**:
- [ ] `AuditSerialize` 的 redact 僅靠各 entity facade 手寫 impl＋各自 redact 純測 guard、**不會自動傳播**;未來其他 entity 加 `impl AuditSerialize` 時須逐 entity 確保敏感欄 redact＋補對應 redact 測;若多 entity 陸續加入、評估以巨集／lint 統一 redact 紀律（避免新 entity 漏遮蔽敏感欄）
**operator_ip 真實 INET 寫入（defer 第二 audit 刀）**:
- [x] ✅（2026-06-15、007 U4a 解 42804）`audit_active_model` 的 `operator_ip` 真 INET 寫入已啟用：entity `operator_ip` String→`Option<IpNetwork>`、`AuditOperator.ip` String→`IpAddr`、facade `Some(ip)`→`Set(Some(IpNetwork::from(ip)))`（`ipnetwork` custom type、非 Expr cast）、C-V-7 live 驗 operator_ip 真 INET 非空。原 defer 背景（005）：`operator_ip` None→NotSet（005 operator.ip 恆 None）;`Some(ip)=>Set(Some(ip))` 分支為前向形狀、**若被觸發會 PG 42804（text→INET 隱式轉型失敗）**——真實 INET 寫入留第二 audit 刀（`audit_ctx` 中介層帶 operator_ip 時）、需 `Expr` cast 或 `ipnetwork` custom type 才可寫實值;**第二 audit 刀無法迴避此問題**——其 `sys_access_log.client_ip` 為 INET NOT NULL（不能套 005 的 `NotSet` 略過）、是真實 INET 寫入的 forcing function（§2 第二 audit 刀已標）
**payload_after 形狀（消費刀填）**:
- [ ] soft_delete 的 `payload_after` 恆 `None`（軟刪只 before 快照）;Insert/Update 操作別的消費刀（User/Role/Menu 等寫端）填 after 快照時、各自 facade 在 `mutate_in_txn` 閉包內構造
**实机 smoke 隔離（Unit D code review 觀察、未來 live-smoke 刀沿用）**:
- [ ] `live_smoke.rs` 的 3 audit 場景用拋棄式 user（9xxxxx）＋`hard_clean`（前後）隔離、**非 panic-safe**（assert 中途 panic 會留 DB 殘留、靠下次 run 的防禦性 pre-clean 自癒、永不污染 m002 seed——與 004 read-cluster smoke 的 bracketed-restore〔因觸 seed〕策略不同、各自合理）;commit/no-op 兩場景共用 id 900001、依賴 contract §4 強制的 `--test-threads=1`（序列跑）
**Cargo.lock 完整性＋未來 sea-orm feature 的 MSRV 地雷（Unit A 發現）**:
- [ ] 005 補齊 003/004 遺留的 16 筆 sea-orm optional-dep lock stanza（`bigdecimal`／`time` 0.3.47／`rust_decimal`／`uuid`／`pgvector`／`mac_address` 等、**全 feature-gated 未編譯**、user 拍板接受、time=0.3.47＝resolver 取最新）;⚠️ 這些 crate **以「最新版」躺在 lock、從未在 1.86 編譯過**——**未來任何刀啟用會拉它們的 sea-orm feature（`with-uuid`／`with-rust_decimal`／`with-bigdecimal`／`with-time` 等）、或為第二 audit 刀真實 INET 寫入加 `ipnetwork` 時，務必先驗該鎖定版 MSRV ≤ 1.86**（workspace 註解原憂「time/home 新 patch 需 1.88」、time 0.3.47 恐即是）;超標就 `cargo update -p <crate> --precise <1.86-safe 版>` 釘回。配套見 §3.4 `--locked` 條＋memory [[sea-orm-entity-datetime-feature-gate]]／[[inert-drift-accept-and-correct-doc]]。⚠️ **time 例外（006 起本條對 time 的「未編譯」描述已 stale）**：006 經 `jsonwebtoken→simple_asn1` 把 **time 拉進真 compile graph（會編譯）**、已 repin `time=0.3.37`/`simple_asn1=0.6.3` 配 1.86（詳 §3.9 末條 errata＋memory [[jsonwebtoken9-msrv-time-real-graph]]）；本條餘 15 筆（bigdecimal/uuid/rust_decimal/pgvector/mac_address 等）仍 feature-gated 未編譯、MSRV-先驗紀律對它們不變（尤 007 加 `ipnetwork`、**已執行**）。**✅ ipnetwork MSRV（007、2026-06-15）**：`ipnetwork 0.20.0`／`once_cell 1.21.4`／`uuid 1.23.3` 於 1.86 編譯綠**無需 --precise pin**、`cargo tree -i ipnetwork` 單一版本（詳 §3.10 deps MSRV 條）；餘 bigdecimal/rust_decimal/pgvector/mac_address 仍 feature-gated、未來啟用刀沿用本紀律。

### 3.9 006-auth-island-min follow-up（收刀移交 2026-06-14;均不阻塞、消費刀觸發時處理）

**dead_code（infra ahead of consumers、實作期觀察）**:
- [ ] `enforce_mw` 目前 dead_code（006 無受 enforce_mw gate 的業務端點、僅 enforce-proof #[ignore] 整合測消費;server bin crate、`cargo build` 一條 warning、無 `-D warnings` 不阻塞）;**波 1 第一刀**（首個受保護業務端點）wiring 後即清——屆時 `endpoint_coverage_lint`（§2 出口列）一併立、enforce_mw route_layer 首次真掛載;**wiring 後仍殘留＝over-built**（同 §3.6/3.7/3.8 紀律）
**live #[ignore] 測 parallel-safety（驗證收尾發現）**:
- [x] ✅ 根治（2026-06-15、波 1 前清債：005 no-op part(b) throwaway id 900001→900004、各測 id 互不撞〔commit=900001/no-op-a=900002/rollback=900003/no-op-b=900004/C-V-7=900007〕、5 live smoke 重跑全綠;`--test-threads=1` 仍為安全預設——enforce-proof 等其他 #[ignore] 未逐一 audit parallel-safety）006 新增 `auth::enforce::tests::enforce_proof_*`（#[ignore]、live DB、in-process oneshot）入 #[ignore] 集;與 005 audit live_smoke 併行跑時 **005 的 `live_smoke_audit_commit_atomic`/`live_smoke_audit_no_op` 偽失敗**（共用 `sys_operation_log` 非 parallel-safe、§3.8 已記）——`cargo test -- --ignored --test-threads=1` 序列跑全綠;**根治＝005 兩 audit 測各自隔離 fixture**（同 §3.8 觀察）、非 006 引入;enforce_proof 本身 parallel-safe（remove-before-add＋末端 cleanup、非 bracketed 但 down -v 自癒）。見 memory [[live-ignore-tests-need-serial]]
**buttons 實況（research R3.3 假設推翻、驗證收尾發現）**:
- [ ] research R3.3／spec/contract/plan「buttons 現空（m004 未 seed v2='button'）」**假設錯**——`casbin_rule` 實有 16 筆 v2='button'（R_SUPER 12：B_CODE1/2/3＋menu/role/user:*）;`buttons_for_roles` 正確只回 v2='button'（Unit 3 純測釘死、不誤抓 menu/method）、getUserInfo live 回真按鈕清單;**code 正確**、006 已校正 enforce.rs/handler 的「現空」stale 註解;波 2 Menu 刀的 getUserRoutes 也有料（v2='menu' 83 筆已 seed）。見 memory [[casbin-seed-has-button-policies]]
**CDP repoint 形（未來信封消費刀沿用）**:
- [ ] base-web 指真 rust-api 做 CDP smoke 的 repoint＝`base-web/.env.test.local`（gitignored、`*.local` 最高優先；dev=`vite --mode test` 故用 `.env.test.local` 非 `.env.local`）設 `VITE_SERVICE_BASE_URL=http://rust-api:31081`（rev3_net 內網名、proxy=Y 經 vite dev proxy）;CDP＝WSL Edge :9229〔origin 127.0.0.1≠localhost 各自 storage、token 在 `SOY_` 前綴鍵〕;smoke 後刪 override。下個信封刀沿用此形
**workspace Cargo.toml time/home 註解被 006 推翻（Unit 1 引入、⚠️ 建議即時 errata 校正）**:
- [x] ✅（2026-06-14 errata 即修、worktree `af7290b`）`rust-api/Cargo.toml` `[workspace.dependencies]` time/home 註解——005 收口寫的「time 為 sea-orm optional dep、**time 不入 compile graph、不編譯**、lock 版本無影響、不變式＝『不鎖 time』」**被 006 推翻**：006 `jsonwebtoken 9`→`simple_asn1`→`time` 把 time 拉進**真 compile graph**（會編譯）、time 0.3.47 需 rustc 1.88、已 pin `simple_asn1 0.6.3`/`time 0.3.37` 配 1.86。**已即時校正**（比照 [[inert-drift-accept-and-correct-doc]]：補兩來源說明＋simple_asn1/time pin＋--locked 配套、註明非 inert 為 MSRV 硬需求）;line 19 sea-orm「time 不入圖」括註同步補「006 jsonwebtoken 會拉入」。配套 §3.4 `--locked`。見 memory [[jsonwebtoken9-msrv-time-real-graph]]
**data-model 與實作 error-mapping 分歧（Unit 7 deliberate、honesty 留痕）**:
- [ ] `specs/006-auth-island-min/data-model.md §7` 寫 getUserInfo「`find_active_by_id`→None/**Err**→token_expired」;**實作對 `Err`（DB 系統錯誤）改回 `internal`（5000）**、僅 `Ok(None)`（查無/軟刪）→token_expired（3333）——controller 決定：DB 系統錯誤與 login/enforce 一致（→internal）、避免 base-web refresh churn;contract `auth-contract.md §5` 只釘「查無→3333」、未釘 DB-error 故 internal 合規。**deliberate divergence、code 正確且自註**（`handler/auth.rs` getUserInfo 註）;data-model 為已 commit spec-kit 史料、依 §7.2 不回頭重寫、此處留痕備查（無 action、純記錄）

### 3.10 007-audit-overlay follow-up（收刀移交 2026-06-15;均不阻塞、消費刀觸發時處理）

**op-log 回填 HTTP 路徑（infra ahead of consumer）**:
- [x] ✅（2026-06-15、008 消費）007 把 op-log operator/trace/operator_ip 回填能力經 facade 接好;**008 `add_user`/`update_user`/`delete_user`/`batch_delete_user` handler 經 `audit_operator(&ctx)` 把 operator_id+client_ip＋`ctx.trace_id` 餵進 `create`/`update`/`soft_delete` facade mutation**，curl+live smoke+CDP 驗 op-log operator_id/trace_id 非空 → 007 audit infra **確認有真實 gated mutation 消費者、非 over-built**。（operator_ip 值：dev 無 `TRUSTED_PROXY_CIDRS` 時 fail-safe 為 peer/nginx IP、真實 client IP 待本節下方 TRUSTED_PROXY 部署設定）

**偽造防護 e2e 測 defer（C-V-1 純測已覆蓋）**:
- [ ] `resolve_client_ip` 偽造防護（untrusted peer→忽略 XFF）僅 F3 純測 `resolve_client_ip_forgery_protection_peer_untrusted` 覆蓋;docker dev 所有 peer 為 trusted bridge、**無法乾淨呈現 untrusted 直連 peer**，U3b live 只證「經 trusted 代理解析真實 IP」半邊（注入 8.8.8.8→跳代理解出、region `美国|Level3`）。真實部署拓撲或能呈現 untrusted peer 的 harness 出現時補 e2e forgery live test

**audit 寫入延遲/留存/告警（cross-ref ⚠️a/⚠️n）**:
- [ ] access-log 寫入在 `audit_mw` after-phase **同步 await**（best-effort 但仍 await）→ 每已認證請求加一次 DB INSERT 延遲;三 log 表 007 起**實際寫入**、access-log 每請求一列成長最快。效能（同步寫、評估 fire-and-forget/批次，⚠️a 驗收一併）＋retention（⚠️n、波 4 obs）落地前留意容量
- [ ] audit 寫入失敗目前僅 `tracing::warn`（best-effort、靜默丟棄）;security/compliance 角度靜默審計遺失是風險——波 4 obs 應對 audit-write-failure warn 設告警

**xdb crate（vendored §I.5、未來 region 工作沿用）**:
- [ ] `xdb` 的 `searcher_init`/`get_full_cache` 對缺檔是 `.expect()` **panic**（非 best-effort）;007 boot 已 guard（`XDB_FILEPATH` 存在才 init、`AppState.xdb_ready` flag、middleware 才查 region）。未來動 region 沿用此 guard、勿不檢查 xdb_ready 直呼 `search_by_ip`。見 memory [[xdb-searcher-panics-on-missing-file]]
- [ ] xdb **IPv4-only**（ToUIntIP u32-based）:IPv6 client→region None（best-effort）;若需 IPv6 region 須擴 vendored xdb（評估）。xdb `[[bench]]`（criterion）從不 build（`--bins`/`--locked` 跳、Dockerfile 僅 COPY benches/ 供 manifest 驗）

**deps MSRV（✅ 結 §3.8 末條 ipnetwork 預警）**:
- [x] ✅（2026-06-15、007）§3.8 末條「007 加 `ipnetwork` 務必先驗 MSRV ≤1.86」已執行:`ipnetwork 0.20.0`／`once_cell 1.21.4`／`uuid 1.23.3` 於 1.86 編譯綠**無需 --precise pin**、`cargo tree -i ipnetwork` 單一版本（with-ipnetwork 未拉新 feature-gated crate 入真圖）;Dockerfile builder `--locked`（§3.4 條、S2 落地）守 prod 防 cargo update 靜默 un-pin;dev cargo update 仍守紀律（同 time/simple_asn1 pin）

**TRUSTED_PROXY 部署設定（cross-ref §3.4 nginx 硬化）**:
- [ ] prod 部署須填 `TRUSTED_PROXY_CIDRS`（內網段＋CDN/CF 段、見 `deploy/TRUSTED-PROXY.md`）否則 fail-safe 採直連 peer（=nginx IP、真實 IP 解析失效）。007 app-side `resolve_client_ip` 與 §3.4 nginx-level `set_real_ip_from`（公網前評估）為互補兩層、後者仍開放

**login-attempt 含系統錯誤終端（⚠️w lockout 消費者注意）**:
- [ ] login inner/outer 單一記錄點記**每條**終端路徑、含 DB/系統錯誤（5000）終止（FR-004 的 superset）;⚠️w login lockout 消費 fail 列時若需區分「憑證失敗 vs 系統錯誤」須加 filter（007 未分欄、`success=false` 涵蓋兩者）

### 3.11 008-user-management follow-up（收刀移交 2026-06-15;均不阻塞、消費刀觸發時處理）

**wire 顯示語意（非 type-lie、UX）**:
- [ ] `createBy`/`updateBy` 回 operator-**id 字串**（非人名）;entity `created_by`/`updated_by`＝`Option<i64>`、base-web typings＝`string`（type 對齊無 lie），但 UI 顯示數字 id。需人名則加 **batched** operator-id→name 解析（單一額外 query over distinct ids、勿 per-row N+1）
- [ ] base-web typings `nickName`/`userPhone`/`userEmail`＝**non-nullable** `string`，但 server 忠實發 `null`（DB 欄 nullable）;較安全方向（不靜默 coerce ""）、type 不 lie 但前端型偏窄。MODAL-WIRING/wrapper 層調和或前端 typings 放寬時處理

**CDP cutover 工件**:
- [ ] `base-web/.env.test.local`（`VITE_SERVICE_BASE_URL=http://rust-api:31081`、gitignored）留存自 C-V-6 cutover;**在則 normal dev base-web 打真 rust-api 而非 apifox mock**。要回 mock：刪此檔＋重啟 base-web 容器（整合驗收用真後端更貼近目標態、可留）

**base-web 工具鏈（★ 跨 feature、影響所有 base-web commit）**:
- [ ] base-web `simple-git-hooks` pre-commit（`pnpm typecheck && pnpm lint && pnpm fmt && git diff --exit-code`）在 dev 容器（`node:26-alpine`=musl）內**必失敗**：`pnpm lint` 的 oxlint 缺 musl native binding（`@oxlint/binding-linux-x64-musl`）＋另有 ≥1 pre-existing eslint error（upstream 324 檔）。**008 所有 base-web commit 用 `git commit --no-verify`、改自驗 `pnpm typecheck`**（hook 鏈中 typecheck 先過、可信）。**波 2+ 每個碰 base-web 的刀都會踩**——修向：補 oxlint musl binding＋修 upstream eslint error，或調 hook（base-web 環境/工具鏈、非業務碼）。見 memory [[base-web-precommit-hook-broken-in-alpine]]

**code 維護（minor）**:
- [ ] `add_user`／`update_user` handler 的值域＋role 解析 application-RI ~6 行重複（刻意不抽共用 helper、避免重動已 review 的 `add_user`）;若 FR-010/FR-011 改動須同步兩處。後續若 upsert RI 再擴張、考慮抽 `resolve_upsert_ri` 共用 helper

**已修（CDP 發現、留痕）**:
- [x] ✅（2026-06-15、`0de38d6`）空字串 filter bug：前端未設 filter→空字串 query→`Some("")`→2222／`user_phone=''` 排除 NULL→空列;修＝空字串視為未設（FR-002 空欄略過）＋CDP 重跑驗證;curl 乾淨 query 掩蓋＝curl≠modal 印證、見 [[empty-string-query-params-mask-by-curl]]

---

## 4. 跨 feature 待驗證項

**跨 feature 驗證（常駐）**:
- [ ] **dead_code over-built 回頭檢視**:infra-ahead-of-consumer 的 public API／fn（envelope/error §3.6・soft-delete facade §3.7・audit 機制 §3.8・enforce_mw §3.9・audit_ctx/op-log 回填 §3.10）——各消費刀 wiring 後**回頭檢視**：仍殘留 dead_code＝無真實消費者＝over-built，回收或補消費。具體 fn 清單在各 §3.N。**008 消費結果（2026-06-15、首個 gated 業務刀）**：已消費 envelope/error（Res/AppError/PageRes）・soft_delete facade・audit（mutate_in_txn/AuditEvent/audit_json）・enforce_mw・audit_ctx/op-log 回填 → **此五類確認非 over-built**（真 handler 消費＋curl/live/CDP 驗）;殘 dead_code（`ok_msg`／`modal_logout`／`not_found`／`AuditOperation::Restore`／`write_in_txn`）為未來 feature 保留 API（logout 流程／回收桶 restore／審計讀端）、非 008 範圍
- [x] ✅（2026-06-15、008 立、⚠️x 移交履行）**endpoint_coverage_lint**:`server/tests/endpoint_coverage_lint.rs` build-failing 靜態掃描，每 enforce-gated route 有 ≥1 m002 casbin policy（gated⊆policies、容忍 seeded-but-unimplemented）;**`EXPECTED_ROUTE_COUNT=6`＝008 實際 gated 數**（非 DESIGN §7.1 target 35；**後刀每加 gated route 須同步 +casbin policy +EXPECTED**，lint 會 build-fail 強制之）;controller sanity-bitten 真咬。立後為跨 feature route-coverage 守恆（每 gated route 有 policy）

**長期維護（自 §2 Roadmap 移入、非波狀態）**:
- [ ] upstream rebase（定期 `git rebase upstream/example`〔base-web〕＋docs 源倉 `upstream/main`;CLAUDE.md §4.6;⚠️s fork-delta 紀律＋zdiff3/rerere 已配套）
- [ ] graphify 圖譜更新——**2026-06-13 增量：002 Rust 碼（migration ×4＋sea-orm-adapter crate）＋docker-compose.yml 外科式併入（4274 nodes/581 communities、base-web/docs 零損失）**；⚠️ 標準 `graphify update`（build_merge）的全域 fuzzy-label dedup 會誤併 distinct 節點（本輪實測損 143 個 base-web/docs 真節點）、故改外科式增量；deploy/（compose override/nginx/Dockerfile）＋tests `.sh`/`.sql` 非 graphify 可索引型別、未入圖；**003 envelope.rs/error.rs＋004（entity crate 4 檔／server model：soft_delete＋facade ×4＋live_smoke／tests entity_access_lint.rs）＋005（entity `sys_operation_log.rs`／server `model/audit.rs`＋`facade/sys_operation_log.rs`＋`facade/sys_user.rs` 寫側＋`facade/live_smoke.rs` audit 場景）＋**006（server `auth/{jwt,bearer,password,enforce}.rs`＋`handler/{auth,mod}.rs`＋`state.rs`＋`error.rs` From impls＋`main.rs` boot 重寫＋`facade/sys_user_role.rs` roles_for_user）＋007（rust-api `xdb` crate 全套／server `audit_ctx.rs`〔RequestContext+audit_mw+trace_id+best_effort_audit〕／`state.rs` resolve_client_ip+parse_trusted_cidrs／2 entity `sys_{access_log,login_attempt}.rs`／2 facade `sys_{access_log,login_attempt}.rs`／`sys_operation_log` 型遷移＋`audit.rs`＋`handler/auth.rs` login split＋`facade/live_smoke.rs` C-V-7／`main.rs` 接線；deploy Dockerfile+compose override）**✅ 全套已同步（2026-06-15、dedup-safe）**——33 rust 檔 AST→**4274→4532 nodes／581→615 communities／37 命名社群／0 LLM token**（audit_ctx/auth/enforce/jwt/bearer/envelope/error/state/xdb/各 facade/各 entity 進圖）；法＝`build_merge(dedup=False)`＋**不傳 prune_sources**（prune_sources 只給 deleted 檔、誤用會剔掉新節點；安全閘驗 node 數成長）。docs/specs/deploy/CLAUDE/compose-override 全在 `.graphifyignore` 外不入圖。**008 碼（`handler/system_manage.rs`＋facade 增補〔sys_user search_active/create/update・sys_role all_active/find_active_by_codes・sys_user_role roles_for_users/replace_roles_in_txn〕＋`tests/endpoint_coverage_lint.rs`＋base-web `rev3-system-manage.ts`/index.vue/drawer）待下次增量同步**（dedup-safe 法、見 [[graphify-update-fuzzy-dedup]]）

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 23**:①flat-in-main 沿用｜② C+ typings-as-oracle｜④僅 join 表加 FK｜⑤凍結邊界=archetype+行為島+碼表入憲｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️d redis tag 建時 pin 數字版｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️g 受控參照 rev2 source｜⚠️i MODAL-WIRING 五用途全授+BUILD-CONFIG 不收錄｜⚠️j rust-api 沿倉換分支｜⚠️k migration 短編號 mNNN_<name>｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings｜⚠️s fork-delta 雙模式(原行註解保留+rev3-inline 標記)｜⚠️t schema 波 0 一次全建(rev2 終態 squash 基線+delta 顯式分離;seed 口徑 92 列/6 表勘誤 2026-06-13)｜⚠️v casbin_rule 委派式建表+adapter 併入 002(sub-crate 刀消解)｜⚠️x endpoint_coverage_lint 波 0 換波豁免(結構上需 gated 端點才能立、移交波 1 第一刀)｜③第一刀＝A User 直刀(sys_user 根 entity 最早凍結、波0 已驗管線故 B 排練價值縮水)｜⚠️a 效能批准保守預設(p95 300/500ms/1s・99.5%/月)｜⚠️o RI 維持 handler 層驗(不下沉 facade)｜⚠️u 不採納 §IV Q10(維持 9 題、不再議)

**開放 10**(依最晚決策點分組):
- 波 2~3:⚠️b 審計讀端(波2排程前)｜⚠️m alt-login 入波(波3排程前)
- 不阻塞/觸發時:⑥a-d 新能力包｜⚠️h 排程重議｜⚠️l settings 多 key｜⚠️n log retention｜⚠️w login lockout 刀位/設計(消費 007 sys_login_attempt、per-ip 因 007 真實 IP 現可行、排程時定)

---

## 6. 軌道授權快查(SOP 注入用)

> 完整定義與 ★ 軌道 spec 義務（file:line＋upstream 衝突評估）見 DESIGN §9.4。

| 軌道 | 等級 | 範圍一句話 |
|---|---|---|
| BASE-WEB-ADAPT | L1+L2 預設可動 | `.env*`＋typings 新檔（新增為主、禁刪既有 type/field） |
| BASE-WEB-WRAPPER | L3 預設可動 | `service/api/rev3-*.ts` 一律新檔;不改既有 auth/route/system-manage.ts |
| BASE-WEB-BUILD-CONFIG ★ | L4 已授、未動用 | `build/plugins/router.ts` pageExcludePatterns、嚴格限隱藏 demo menu（⚠️p 拍板後議題消解） |
| MODAL-WIRING ★ | L4 五用途 (a)~(e) | `views/manage/**` inline:接線/hasAuth gating/新權限 modal/復原控制/新管理頁;**絕不擴張到其他 inline** |
| RUSTAPI-SOURCE-ISOLATION | rust-api 整棵樹 | 全新寫;設計繼承、code 不拷貝;research 不准 grep rev1 source |

---

## 7. 已完成里程碑

完整 commit 里程碑歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)(append-only、不在 SOP 注入,避免本檔膨脹)。

§1「最新進展」滾動最近 2 條;歷史在 MILESTONES.md 永久保留。歸檔流程見 [CLAUDE.md §7.5](../CLAUDE.md)。
