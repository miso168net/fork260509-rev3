# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 1 ✅ 全完成（008 system_settings 打樋、2026-06-18;波 0 七刀＋波 1 一刀全收）;波 2 data islands 待起跑**（as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-18 008-system-settings 全綠收刀（波 1 第一刀＝system_settings KV 打樋;波 1 全完成）**（merge `b52dafe`）:3 全專案首次——首個 policy-governed 端點（`require_policy` DB-fresh per-route layer、enforce_mw 不動、5003→403 live 首証）／首個 007 op-log threading live consumer（`to_audit_operator`→operator_ip 真 INET round-trip）／立 `endpoint_coverage_lint`（⚠️x:registered==as-built＋policy-governed⊆m002 seed＋self-test）。2 端點 GET/POST＋super-only＋value_type 2222＋同 txn 審計原子＋net-new base-web static 頁/rev3-* wrapper 首檔/i18n;零 migration/entity/schema（m005 MOOT）、無新 crate;4 單元 Workflow 驅動（U1 `8e5a024`→U2 `4f4952d`→U3 `3874182`/U4 `5fdd6f0`＋§2 trim `223bc83e`）;C-V-0~11 全綠（live policy-gate 5003／op-log INET／CDP toast off↔on／prod build／零回歸 perf 讀5.8改7.9ms）、holistic 雙 lens ready-to-merge 0 blocking;enforce_mw/base-web 既有檔未動、SC-006/007 零回歸;rust-api `fc4b50e`→`3874182`、base-web `c2ad92f`→`223bc83e`
- **2026-06-18 007-audit-overlay 全綠收刀（波 0 第七刀〔末〕＝audit overlay;本刀收齊波 0）**（merge `96280d8`）:L3 `xdb` crate 整檔零改拷入（§I.5⚠️v）＋L7 `audit_ctx` 全域中介層（`RequestContext` 每請求建塞 extensions／`resolve_client_ip` XFF trusted-proxy〔peer-gate→rightmost-untrusted→fail-safe、anti-spoof〕／`extract_trace_id`／`audit_mw` 全域最外層 operator-gate 寫 access-log best-effort／`to_audit_operator` op-log threading seam）＋2 append-only facade sink（`sys_access_log`/`sys_login_attempt`、`IpAddr→IpNetwork::from`）＋login inner/outer split exactly-one（not-found/wrong-pwd 同 1000、operator pre/post-identity）＋op-log threading live smoke（T018）;boot `Path::exists` 守門→`searcher_init`（缺檔降級不 panic、R1）＋`connect_info`;T009 compose env＋T019 Dockerfile xdb COPY（Manifest＋Source〔benches〕＋runtime .xdb＋builder `--locked`）。C-V-0~9 全綠（build／3 純測 8+5+4／lint 2／live login-attempt 成敗各列・access-gate・真 INET 無 42804・region 内网・behind-proxy 真 client・op-log INET round-trip／prod image 含 .xdb 11070083B）、holistic PASS（16 FR+9 SC 全 MET）、推進 DESIGN §5.9（直連→XFF trusted-proxy、非 Amendment）、零 migration/entity/型遷移/base-web/i18n/nginx、enforce_mw 未動、SC-007 零回歸;rust-api `b9de316`→`fc4b50e`（worktree `2fc0696`/`15e6491`/`fc4b50e`）

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **波 2 data islands 首刀 → User**（讀 3 端＋CRUD＋join `sys_user_role`、§5 全套＋M:N join＋★MODAL-WIRING 重刀;§5.8 分頁/filter/空字串守門首 exercise〔curl≠modal 經典案例、CLAUDE.md §3〕;DbErr 23505→2222 首落〔波2 CRUD unique 約束〕;DESIGN §8.2）；**待階段 0 `superpowers:brainstorming` 起手**（產出 `docs/superpowers/<NNN>-user-*.md`）

---

## 2. Roadmap & Phase 狀態

對齊 CLAUDE.md §3 SDD-TDD 工作流 + [DESIGN §8.4 交付波次](INTEGRATION-DESIGN.md)（波次定義/出口條件在彼）。本節為動態 status 追蹤;完成波 as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);完成波摘要累積數波後批次搬 [MILESTONES §2](INTEGRATION-MILESTONES.md)、本節永遠聚焦當前波。

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> 機械建構＋constitution 重鑄兩段全交（pre-spec-kit、全落 default branch、無 feature branch）:outer repo＋worktree/submodule 註冊 `2ec9cda`（⚠️j/⚠️q）/ 設計書入檔＋拍板回填＋歸位改名 `7fd1ac6`→`4aa7c89` / C 方案文件體系 DECISIONS+CHECKLIST+MILESTONES `4724549`・`4300b54` / graphify 首建 `8f66fe0` / 000 base-web bootstrap＋13 端點對映 `46591c4`~`e898421` / SessionStart hook 原樣承接 `ed2a789` / **constitution-rev3 v1.0.0 凍結 `167db96`**（13 項拍板融入）。出口四項全綠（session 健檢/獨立 commit/grep rev2 歸零/speckit 可用）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基 ✅ 全完成+已歸檔 (2026-06-18)

> 七刀全收（001 infra-deploy `c9ffad5`／002 schema-baseline `9233ae0`／003 envelope `13a01b1`／004 soft-delete-infra `a1105f0`／005 audit-op-log `98f1f7e`／006 auth-island-min `e279f23`／007 audit-overlay `96280d8`;sub-crate 刀 ⚠️v 消解併入 002/007）。前置拍板 4 項（①flat-in-main／④僅 join FK／⚠️d redis pin／⚠️k mNNN）全拍（2026-06-13）。出口四項達標：dev stack healthy✅・三守恆〔entity_access_lint✅ 004・migration up→down→up✅ 002・endpoint_coverage_lint ⚠️x 豁免移波1〕・envelope 13 碼✅ 003・login→getUserInfo→enforce✅ 006 → 換波 1。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 1 — 第一刀＝`system_settings` 打樋 ✅ 全完成+已歸檔 (2026-06-18)

> 1 刀打樋（merge `b52dafe`）＝最輕 KV entity 跑完 §8.1 全管線、達 3 全專案首次（首個 policy-governed 端點＋require_policy 5003 live／首個 op-log threading live consumer INET round-trip／立 endpoint_coverage_lint ⚠️x）;零 migration、無新 crate;C-V-0~11 全綠、holistic ready-to-merge 0 blocking。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md);D1 波2 選單可見性 follow-up 見 §3.10。

### 波 2 — data islands（未開始;③=B → User 留本波、`system_settings` 已移波1）

其餘業務 entity 各一刀（rev2 016 一 feature 兩 entity → rev3 拆兩刀紀律）。建議序 User→Menu→Role（Menu net-new `sys_menu`＋migration、Menu 完成解鎖 Role×Menu 授權）。

**刀/feature 清單**（素材=DESIGN §8.2 data island 縱切）:
- [ ] **User 刀**（③=B → User 留本波;讀 3 端＋CRUD＋join `sys_user_role`;rev2 016*+017;§5 全套+M:N join+★MODAL-WIRING 重刀）
- [ ] **Role 刀**（rev2 013*/016*/018;schema 起點在 rev2 013〔sys_role+sys_user_role+policy seed〕）
- [ ] **Menu 刀**（rev2 014〔runtime 讀〕/019/020/021/025;DB-driven＋CRUD＋MenuAuth＋回收桶 restore/re-parent;**＋⚠️o hybrid〔已決〕：reparent 3+1 guard 下沉 facade 自驗〔slim error enum、handler 映 2222〕**）
- [x] ~~**`system_settings` 刀**~~ **已移波 1 第一刀（③=B、2026-06-16）**
- [ ] **審計查詢讀端＋UI 刀（⚠️b ✅ 已決：做、波2 殿後刀）**（三 log 讀端＋R_SUPER policy seed＋manage 新頁〔MODAL-WIRING (e)〕;排 Menu→Role 之後;DESIGN §8.2）

**前置拍板 ✅ 已拍（2026-06-16）**:
- [x] ⚠️b 審計查詢讀端＋UI ✅ 做、排波2 殿後刀（Super-only、MODAL-WIRING (e)）

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

### 持續性維護

- [ ] upstream rebase（定期 `git rebase upstream/example`〔base-web〕＋docs 源倉 `upstream/main`;CLAUDE.md §4.6;⚠️s fork-delta 紀律＋zdiff3/rerere 已配套）
- [ ] graphify 圖譜更新（大改後 `graphify update`;最近一輪 2026-06-13、4176 nodes/567 communities——**早於 001 收刀**,**波 0 全收（001-007 七刀）＋波 1（008 system_settings）新碼均未入圖**〔001 scaffold/compose/deploy・002 migration×4/sea-orm-adapter・003 envelope/i18n・004 entity crate/soft-delete lint・005 audit・006 auth runtime・007 xdb crate/audit_ctx・008 system_settings facade/handler/require_policy/endpoint_coverage_lint＋base-web 新頁/wrapper/i18n〕,待一輪 update;docs 同期大改〔INTEGRATION-* 四檔／008 specs〕亦未入圖、惟 `.graphifyignore` 排除 docs/、見 §3.2）

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
- [ ] nginx 自答 `/health` 雙 Content-Type（`add_header`→改 `default_type`;rev2 同形）
- [ ] nginx prod 硬化:`server_tokens off`＋HSTS/X-Frame-Options/X-Content-Type-Options（公網前必做）
- [ ] XFF append 可偽造→`set_real_ip_from` 信任邊界（公網前評估）
- [ ] image pin 一致性:alpine/openssl:latest（兩生成腳本）、base-web runtime nginx:alpine、base-web dev node:26-alpine（26.x 滑動）、postgres:17-alpine/debian patch 浮動 → 統一 pin 紀律一次處理
- [ ] prod migrate 繼承 runtime image 無意義 HEALTHCHECK（migration 不開 port;>35s migration＋未來 `--wait` 假陰性伏筆→prod.yml 補 `healthcheck: disable`）
- [ ] builder `cargo build` 補 `--locked`（守 lock pin 防線、防 manifest 漂移靜默 re-resolve）
- [ ] `docker-compose.base-web.yml` 檔頭補與 master 並行撞點警示（同 project name/卷;與 rust-api standalone `7e3fed6` 對稱）
- [ ] compose secrets 預檢（bind 缺檔自動建空目錄→錯誤不指向缺檔;up 前 wrapper 或文件註記）
- [ ] `front_nginx_certs` 要不要 `external: true`（消 compose warning vs 硬前置;拍板項）
- [ ] migrate 的 redis depends_on 與 FR-002/C-V-2 措辭對齊（實作只閘 postgres;補 depends 或修 spec 措辭;rev2 同形）
- [ ] postgres healthcheck `pg_isready -U soybean` 缺 `-d soybean_admin_rust`（dbname 預設=username→每 10s 一條 FATAL log;波 4 obs 落地前修、一 token;rev2 同形）
- [ ] dev watcher 工具評估:cargo-watch 上游已 archived＋`cargo install` 無版本 pin＋無 cache mount（dev image build 慢）→ 後刀換 bacon/watchexec 屬顯式決策（rev2 形 carry）
- [ ] 冷卷首啟 `up --wait` 自癒型 flap（base-web 容忍 ≈140s/rust-api ≈240s;`down -v` 後或新機器會撞）→ quickstart 補「exit≠0 先 ps 區分仍在編譯、等穩重跑即過」一句
- [ ] C-V-2 gate 斷言①複驗方法注記:重複 `up` 會讓 migrate one-shot 重跑、刷新 inspect 時戳（假陰性）;複驗用 `docker logs --timestamps` 首輪——波 0 出口複驗時適用
- [ ] dispatcher `server)` 分支不 shift 不傳 `"$@"`（與 migration/cleanup-job 不對稱;多餘參數靜默丟棄;blob-identical 凍結下傾向 won't-fix、僅記錄）
**腳本**:
- [ ] generate-secrets.sh 刪 leaf 重跑 dual-write drift 邊角（GENERATED 視同 force 或 README 警語）
- [ ] generate-dev-cert.sh 自簽 renew 必重生 CA 與教學矛盾＋私鑰 chmod 600（native Linux 644 風險）
- [ ] generate-* 兩腳本 `docker pull -q` 離線即 abort（image 已 cache 也炸）→ `docker image inspect || docker pull` fallback
- [ ] outer `.gitignore:133` 註解殘留前代 feature 編號（順手修）
**rust-api**:
- [x] ✅（2026-06-13、002/U2）migration main.rs secret 讀檔失敗靜默 fallback→補 eprintln 警示（`inspect_err`、行為不變）
- [ ] `set_var` 於 runtime 啟動後（edition 2024 升級時根治）
- [x] ✅（2026-06-17、004/U1）workspace Cargo.toml time pin 註解勘誤——004 引入 with-chrono 後 time 0.3.47 入 lock 但 feature-gated 不入 compile graph（inert、`cargo tree -i time`＝nothing to print）、註解已校正為實況＋保留「未來 time 進真 graph〔如 jwt9 經 simple_asn1〕須 pin≤0.3.37」前瞻（commit `3f87a25`）
- [ ] rust-api/.gitignore `debug`/`target` 未錨定 pattern（誤吞同名子目錄風險）
**拍板/上游**:
- [x] ✅（2026-06-17、006）JWT `_FILE` vs 直值 env 優先序——`config.rs` 採 `_FILE` 優先、env fallback（FR-014）＋長度≥32＋拒 `change-me*` boot panic;Auth 刀（006）消費時即定案
- [ ] prod builder node:20.19 vs dev node:26 分歧（沿 rev2 驗證形;Dockerfile 補註記或 DECISIONS 開放項）
- [ ] cargo cache 卷遮蓋陳舊（dev image 升 toolchain 時需手動 `volume rm`;quickstart 註記）
- [ ] 兩段式 commit pin 時點紀律提案:worktree commit 落地的**當個 task** 即 bump outer pin（001 全延到 T021、中繼 15 個 outer commit 的 pin 過期、checkout 不可重現 tasks 勾選聲明）→ 提案補進 CLAUDE.md §4.1（user 核可後改）
- [ ] **rev2 repo 回灌通知**:redis-stack `--dir /data` 持久化 bug 為 rev2 同形潛伏（rev2 `docker-compose.yml` redis command 同款缺 `--dir`）——rev2 維護時修

### 3.5 002-rev2-schema-baseline follow-up（收刀移交 2026-06-13;均不阻塞、消費刀觸發時處理）

**Menu 刀消費（research.md R4 D2~D4 移交）**:
- [ ] `RouteMeta` 擴充:localIcon/multiTab/href 序列化＋`menu_node_to_route` 讀 `icon_type`（rev2 wire 不序列化這些欄、屬接線議題;**影響面 href 落值實為 ×10**〔原生 2＋D2 href 化 8〕、勿按原生 ×2 低估）
- [ ] iframe props 內嵌復原評估（D2:document 8 頁 props.url 現 href 化外開;iframe 內嵌需 props 欄位/wire 擴充）
- [ ] `filter_routes` 遞迴化評估（D3 配套:現 demo policy 全覆蓋 66 列為前向相容、filter 只查兩層;遞迴化後可收斂為嚴格最小集）
**rust-api 順手（002 引入後重驗）**:
- [x] ✅（2026-06-17、004/U1）workspace Cargo.toml time pin 註解勘誤（見 §3.4 同條;commit `3f87a25`）
**sea-orm-adapter vendored 已知瑕疵（byte-identical 拷貝保留、§I.5;重鑄/測試啟用時處理、U1+U2 review 發現）**:
- [ ] adapter `Cargo.toml` 內 `async-trait`/`tokio` 的 `default-features = false` 對 workspace 繼承條目 redundant → 每次 build 兩條 cargo warning（拷貝紀律刻意保留;日後拍板允許動 vendored manifest 時一併清）
- [ ] adapter `examples/`（rbac_*.conf/csv）為 `#[cfg(test)]` fixture:prod `--bins` build 免 COPY（已驗正確、Dockerfile 有註解），但若日後在 builder/容器內跑 `cargo test` 會缺 fixture（屆時 COPY examples 或 adapter 測試改 env-gate round-trip smoke）
**constitution（待 user 親決）**:
- [ ] ⚠️u constitution §IV 增第 10 題（normalize/驗證流程契約修訂的 amendment 提案;PATCH 級;002 normalize 第六規則為先例——執行期發現假紅源、user 拍板補規則、契約留痕）

### 3.6 003-envelope follow-up（收刀移交 2026-06-16;均不阻塞、消費刀觸發時處理）

**i18n 顯示端到端階梯（FR-012；機制本刀已以型別/單元/component 測覆蓋、端到端待真端點）**:
- [x] ✅（2026-06-17、006）波 0 Auth/login 刀：login 失敗發 `1000`=`auth.login.failed`→toast 經 `$t` 在地化——006 C-V-3 CDP 實機證 toast 顯「用户名或密码错误」（非 raw key）＝i18n 顯示路徑首個端到端檢核點達成（fallback 已由 003 tsx 單元覆蓋;**踩點**：首跑 vite 服 stale locale 模組顯 raw key、`restart base-web` 後綠、CLAUDE.md §8.2.1）
- [x] ✅ 半（2026-06-18、008）波 1 system_settings 刀：首個真 biz endpoint 發 per-entity `2222` key（`biz.systemSettings.{invalidValue,notFound}`）→per-entity 端到端達成（C-V-6 maybe→2222 invalidValue／查無 key→2222 notFound、C-V-7 CDP 在地化 toast「設定值不符」類）;**惟** `PageRes` runtime 形＋空字串 filter 守門 system_settings flat 不觸→留**波2 User**首個 list 端點（curl≠modal 經典案例、CLAUDE.md §3）
**顯示限制（R3、本刀不修）**:
- [ ] `4040`/`5003`（HTTP 404/403）走 axios native error、`error.code≠BACKEND_ERROR` 致 envelope msg 今日不顯示（DESIGN §7.3 既認限制）；enforce 刀再議是否拓寬 `onError` extraction。**（008 觸發：波1 system_settings＝首個發 `5003`/403 的端點〔C-V-6 Admin/User curl 實證 403 code 5003〕；惟 base-web 前端 403 顯示路徑〔是否在地化顯 `system.forbidden`〕CDP 收口時 deferred、未瀏覽器驗 → 本決策現已 actionable，波2 User/Menu 刀順帶決定 `onError` 是否抽 403/404 envelope msg＋瀏覽器實證）**
**rust 範圍延後（R7）**:
- [x] ✅ 半（2026-06-17、006）`From<DbErr> for AppError`→`Internal`/5000 已由 006 帶入（sea-orm 早於 004 入 server）;**惟 `DbErr::sql_err()`→`SqlErr::UniqueConstraintViolation`（pg 23505）→`2222` 映射仍待**——login/getUserInfo 不撞 unique violation，留首個 CRUD 寫端刀（波2 User/Role）帶入（§3.8 末條同源）
**rust 信封消費（首個業務刀觸發、review 衍生、非阻塞）**:
- [ ] `Res::ok` 採 `Res<serde_json::Value>`（`to_value` 中轉、003 時 `#[allow(dead_code)]` 無消費者）→ 首個消費業務刀重估兩點：(a) 序列化失敗 fallback `data:null` 仍掛 `code:"0000"`＝成功碼掩蓋錯誤 → 視需要導向 `AppError::Internal(5000)`；(b) 熱路徑大 payload 的 double-serialization（to_value→Json）→ 可改保留泛型 `Res<T>` 直接 Json、省中轉。**（008 觸發：波1 system_settings＝首個 `Res::ok` 業務消費者〔get flat 小陣列／update `Value::Null`〕；payload 極小 →(a) 序列化失敗不現實、(b) double-ser 成本可忽略，兩點皆不觸 → 留首個【重 payload】消費者〔波2 User `PageRes` 大列表〕實評）**
**測試守護 fidelity（review 衍生、非阻塞）**:
- [ ] base-web i18n 單元測 `src/locales/__tests__/translate-backend-msg.spec.ts` 以既有 `tsx` **重建** `translateBackendMsg` 公式（非 import 真匯出——`@/locales` 載入鏈耦合 `import.meta.env`/`localStorage`、純 node 不可解）→ 引入真測試環境（vitest+jsdom 或 vite-node＋shim）時改 import 實際 export 閉合 fidelity gap；`pnpm test` 現＝單一 i18n 腳本、屆時併入正式 suite

### 3.7 004-soft-delete-infra follow-up（收刀移交 2026-06-17;均不阻塞、消費刀觸發時處理）

**ipnetwork／time-lock（U1 實作期發現）**:
- [x] ✅（2026-06-17）with-ipnetwork 1.86 build 早驗綠（ipnetwork 0.20.0 入 compile graph、無退 String+cast）;inert time 0.3.47 入 lock 但 feature-gated 不編譯（註解已勘誤、見 §3.4／§3.5）
- [x] ✅（2026-06-17、006 Unit 1）**Auth/Token time-pin landmine 已排**:006 加 jsonwebtoken 9 經 `simple_asn1` 把 time 拉進真 compile graph（`cargo tree -i time` 實證 time←simple_asn1←jsonwebtoken←server）→ pin `simple_asn1 0.6.3`（其 time req 放寬回 ^0.3）再 `time 0.3.37`，1.86 dev build＋prod `--locked` 皆綠（commit `04fc6f8`）。**順序硬約束**：simple_asn1 須先降、否則 `cargo update -p time --precise 0.3.37` 失敗（0.6.4 floor `time^0.3.47`）
**INET log entity 消費（audit 刀觸發）**:
- [ ] 3 INET 欄（`sys_operation_log.operator_ip`／`sys_access_log.client_ip`／`sys_login_attempt.client_ip`）`IpNetwork` 讀寫 facade＋decode 正確性——audit 刀為首個 log 消費者，須對真實資料驗 `IpNetwork` serde round-trip（本刀 entity 僅編譯綠、未跑時資料 decode）
**casbin_rule 治理欄消費（policy 刀觸發）**:
- [ ] `casbin_rule` entity 自定 11 欄（8 adapter 基底＋protected/created_at/created_by 治理 3）——policy 刀 cross-check:adapter 自身 8 欄 Model 對治理欄隱形（§I.6 D），確認 governance 讀寫經 entity crate Model 非 adapter Model
**soft-delete 活體覆蓋邊界（Role/Menu 刀觸發）**:
- [ ] `sys_role`／`sys_menu` 的 `find_active` 活體驗證待各自業務刀 list 端點順帶覆蓋（本刀僅 `sys_user` 活體證〔C-V-2〕、其餘 2 由共用 trait＋compile 繼承、spec SC-001 接受此驗證級別）

### 3.8 005-audit-op-log follow-up（收刀移交 2026-06-17;均不阻塞、消費刀觸發時處理）

**operator_ip INET 真實資料 round-trip（007 機制／✅ 008 首個業務消費者兌現）**:
- [x] ✅（2026-06-18、008）波 1 system_settings update＝**首個 007 op-log threading live consumer**：update handler 經 `ctx.to_audit_operator(claims.uid)` 取真 operator/IP/trace 餵 `mutate_in_txn`→`write_in_txn`，op-log `operator_ip` 由恆 None→**真 INET round-trip 活證**（C-V-5 顯式 IpNetwork 203.0.113.7 by-trace 查證 serde 正確＋savepoint rollback、C-V-6 live 真 to_audit_operator）;007 T018 已先驗 threading 機制、008 為首個真業務寫端
**redact 遮蔽清單擴充（user/session 寫端消費刀觸發）**:
- [ ] `sys_user::audit_json` 現僅遮蔽 `password`（spec 明定本刀範圍、spec-compliant）;`current_session_id` 以原值序列化進審計快照——後續 user/session 寫端刀 impl/擴充 `AuditSerialize` 時評估 `current_session_id` 是否一併遮蔽/截斷（holistic review Lens 2 nit、非缺陷）
**soft_delete 中途失敗審計同步（消費刀觸發）**:
- [ ] 本刀 rollback 證明經「裸 `mutate_in_txn`＋raw SQL write-then-Err」演練（FR-010 單一 proof 範圍、contract C-V-2 明示設計、非 vacuous）;`soft_delete` 自身中途失敗（DB 約束衝突等）的審計同步回滾由 `mutate_in_txn` 機制保證、可留消費刀以注入約束衝突收緊覆蓋
**op-log `operation` 字串契約對齊（op-log 讀端＝波2 ⚠️b 觸發）**:
- [ ] `AuditOperation::as_str()` 定 `operation` 欄封閉詞彙＝`INSERT`/`UPDATE`/`SOFT_DELETE`/`RESTORE`（005 `SOFT_DELETE`＋**008 `UPDATE`** 經 live smoke 實證〔008 C-V-5 op-log `operation='UPDATE'`〕、`INSERT`/`RESTORE` 隨各寫端刀漸用）;op-log 讀端（rust 查詢 filter／base-web UI by-operation dropdown）字串須對齊此契約——rust 端 ref `AuditOperation` enum、base-web 端硬編字串須一致（勿造 `DELETE` 之類不符值致 filter 失準）
**DbErr→AppError 映射（首個消費 soft_delete 的 handler 刀觸發）**:
- [ ] 本刀 `soft_delete`/`mutate_in_txn`/`write_in_txn` 為首批【產 `DbErr` 的 facade 方法】（004 的 `find_active` 僅回 `Select`、未執行）;`From<DbErr> for AppError`→Internal/5000 **已由 006 帶入**（見 §3.6 同條）、惟本刀 facade 仍無 handler 消費。首個把 `soft_delete` 接進 handler 的刀須驗該映射實際觸發＋補 `sql_err()` 23505→`2222`（波2 CRUD）

### 3.9 006-auth-island-min follow-up（收刀移交 2026-06-17;均不阻塞、消費刀觸發時處理）

**`enforce_mw` policy-step 上線＋5003 live（✅ 波1 008 兌現，非波2）**:
- [x] ✅（2026-06-18、008）波 1 第一刀 system_settings＝**首個 policy-governed 端點**：新增 `require_policy(path,method)` per-route layer（**不改 enforce_mw 本體**、守契約 §3.4;DB-fresh `roles_of_user` 不信 claims.roles→`enforce_role_path_method`→`PermissionDenied`）、兩端點各掛 route_layer＋外層 enforce_mw;**首證 5003→HTTP403 live**（C-V-6 Admin/User GET/POST→403 code 5003 不洩值＋CDP）;`endpoint_coverage_lint`（⚠️x）立、分類 public（/health、/auth/login）/auth-only（/auth/getUserInfo）/policy-governed（system_settings×2）三類＋斷言 registered==as-built＋policy-governed⊆m002 seed。空字串 filter 守門＝§5.8、system_settings flat 無 filter→留波2 User
**token 不隨 user 停用/軟刪即時失效（波2 User CRUD／波3 session revocation 觸發）**:
- [ ] getUserInfo `find_by_id` 不濾 `deleted_at IS NULL`、`enforce_mw` 不查 user active → 已軟刪/停用 user 持既發 access token 仍可通關至過期（≤access_ttl ~1h）;login 端 `find_by_user_name` 已濾軟刪（無法新登入）。即時撤銷（user disable/delete 即踢）屬 §I.7 完整 session 機器=波3（rotation/reuse/revocation）;波2 User CRUD 若需即時失效須提前接 revocation hook
**JWT 參數硬編（波3 refresh/session 或 settings 觸發）**:
- [ ] JwtConfig 的 `access_ttl`(3600s)/`refresh_ttl`(7d)/`iss`(`rev3-admin`)/`aud`(`rev3-admin-web`) 為 main.rs boot 常數;波3 refresh/session policy 或 settings 若需可設定化（per-role TTL／runtime 調）再外移、本刀硬編足夠

### 3.10 008-system-settings follow-up（收刀移交 2026-06-18;均不阻塞、消費刀觸發時處理）

**D1 — 選單可見性（波2 Menu 刀觸發;analyze D1／plan §7／contract §6）**:
- [ ] 波1 static 模式下 system-settings 選單對非 super 亦可見（前端 menu 非 Casbin 過濾、惟 API `require_policy` 擋 403、**非授權破口**）→ **波2 Menu 刀**以 getUserRoutes＋m002:165 menu policy（R_SUPER）收選單可見性（非 super 不顯）、收 §I.2 menu-Casbin-enforce 機制延後;同時 `.env` `VITE_AUTH_ROUTE_MODE` static→dynamic（拍板#7、getUserRoutes 落地時）、移除波1 static route 註冊（小 throwaway）
**value_type 驗型擴充（新值型 seed 觸發）**:
- [ ] `validate_value_type` 現僅 enum 分支、非 enum 型（number/string/json）保守放行（spec.md Assumption／data-model §6「型擴充隨需要」背書、目前僅 `enum:on,off` 單鍵 seeded 無缺口）→ 後續若 seed 引入新值型 key 而未補對應驗證分支會「髒值靜默寫入」;補分支時併補純測（或在守恆檢查加「每 seeded value_type 前綴必有對應驗證分支」斷言）
**endpoint_coverage_lint 抽取器邊界（非字面 route 參數觸發）**:
- [ ] `first_string_after` 抽取假設 route/policy 參數為**字面字串**（非 const）、區塊註解 route 抽取無 self-test（現況 dormant:main.rs 全字面、零區塊註解）→ 後續刀若引入 `.route(CONST,...)`/`require_policy(ROUTE_CONST,...)` 須加守門（夾 ident 字元→panic 提示更新 lint）或補區塊註解 self-test

---

## 4. 跨 feature 待驗證項

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 27**:①flat-in-main 沿用｜② C+ typings-as-oracle｜④僅 join 表加 FK｜⑤凍結邊界=archetype+行為島+碼表入憲｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️d redis tag 建時 pin 數字版｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️g 受控參照 rev2 source｜⚠️i MODAL-WIRING 五用途全授+BUILD-CONFIG 不收錄｜⚠️j rust-api 沿倉換分支｜⚠️k migration 短編號 mNNN_<name>｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings｜⚠️s fork-delta 雙模式(原行註解保留+rev3-inline 標記)｜⚠️t schema 波 0 一次全建(rev2 終態 squash 基線+delta 顯式分離;seed 口徑 92 列/6 表勘誤 2026-06-13)｜⚠️v casbin_rule 委派式建表+adapter 併入 002(sub-crate 刀消解)｜③ B=`system_settings` 第一刀(2026-06-16)｜⚠️a perf 保守預設(p95 300/500/1s・99.5%)｜⚠️b 審計讀端 做+波2 殿後｜⚠️o application-RI hybrid(intra 下沉 facade/跨 facade·restore 留 handler)｜⚠️u §IV 第10題 不採納｜⚠️x endpoint_lint 波0 豁免移波1｜⚠️y biz-msg i18n A(前端譯·msg=key;規約於 003-envelope 落定〔4 根+文法+13 碼 key+兩端接線+locale 外包 backend.〕·刀1+ 僅套用)｜⚠️aa BASE-WEB-I18N-WIRING ★ 軌道(constitution §III amend v1.1.0;授權 i18n inline 接線：service/request 攔截器/locales backend 命名空間/app.d.ts Schema)｜⚠️ab constitution §I.3 措辭 PATCH(釐清 msg 載 i18n key 對齊 ⚠️y、v1.1.1)

**開放 9**(依最晚決策點分組):
- 波 1~3:⚠️m alt-login 入波(波3排程前)｜⚠️w login lockout(做、刀位/設計待排程;消費 audit-overlay 的 sys_login_attempt 索引)
- 不阻塞/觸發時:⑥a-d 新能力包｜⚠️h 排程重議｜⚠️l settings 多 key｜⚠️n log retention

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
