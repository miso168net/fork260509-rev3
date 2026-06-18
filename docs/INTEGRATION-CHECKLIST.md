# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 2 data islands 進行中（009 User 首刀 merge `07b67d2`／010 Menu 第二刀 merge `3810103`〔2026-06-19〕完成;尚餘 Role 刀／⚠️b 審計讀端刀）**（as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-19 010-menu-management 全綠收刀（波 2 第二刀＝Menu;波 2 進行中）**（merge `3810103`）:動態角色選單（getUserRoutes Casbin v2='menu' 過濾、§I.2 首兌現、前端零過濾、tree 祖先包含〔dir 不在 visible 但子可見仍納入〕）＋選單 CRUD（reparent 3+1 guard ReparentError）＋統一回收桶（已刪除欄、restore 孤兒→頂層、AuditOperation::Restore 首 consumer）＋越權（8 端點 require_policy R_SUPER、Admin/User→5003）＋D1（選單可見性＋前端 hasAuth gating menu+retroactive user 兌現）＋.env static→dynamic（#7）。11 端點、3 全專案首立（menu_routes_for_roles／reparent facade slim enum／flat→tree 序列化）、DeleteError 批次整批拒 no-partial、getAllPages 裸 page 名修。4 單元 Workflow 驅動（U1 `1369ca1`→U2 `00436d1`→U3 `c377444`／U4 base-web `a59c2738`）;C-V-0~12 全綠（88 bin＋5 live `--test-threads=1`／lint `[&str;22]`／C-V-8 policy-gate／CDP 三角色側欄差異+CRUD 真發+restore+hasAuth gating〔R_ADMIN user:edit-only nuance〕+2222 在地化+login dynamic 可達+fail-fallback 導回登入／C-V-11 零回歸／C-V-12 prod build）、holistic READY-TO-FINISH（11/11 SC、零 blocking、wire 三端對齊無型謊）。**零 migration/entity/schema、無新 crate**;rust-api `8ccea9d`→`c377444`、base-web `c1806680`→`a59c2738`。2 clarify 拍板（批次刪父子整批拒＋retroactive gating 含 user/settings）。★ route store 1 處授權 rev3-inline 例外（dynamic 保留前端 builtin 常數路由 login/403/404/500、修 FR-002／R-cr 預示缺口、user 拍板）;D1（008+009 §3.10）已兌現;010 follow-up 見 §3.13
- **2026-06-18 009-user-management 全綠收刀（波 2 資料島首刀＝User;波 2 進行中）**（merge `07b67d2`）:使用者管理頁 mock→真後端 6 端點 CRUD（getUserList/getAllRoles/addUser/updateUser/deleteUser/batchDeleteUser）＋角色 M:N（`replace_roles_in_txn` 與 user 寫同 `mutate_in_txn`）＋同交易審計（INSERT/UPDATE/SOFT_DELETE op-log、operator_ip 真 INET）＋越權（6 端點 require_policy DB-fresh、read R_SUPER+R_ADMIN〔getAllRoles +R_USER_COMMON〕/write R_SUPER）＋停用登入 gate（status==2→1000 防枚舉）。多個全專案首次:§5.8 分頁/filter 首 exercise（空字串守門＋模糊 ILIKE userName/nickName/userEmail）／`PageRes` 首消費者／M:N join 寫／prod argon2 hash_password／23505→2222 `sql_err()` 寫端 map 首落（⚠️o、blanket From 不改）／INSERT op-log 首 consumer。2 clarify 拍板:self-lock 防自鎖對稱守門（→2222 整筆拒）＋批次刪缺漏 idempotent skip。★ as-built 偏離:research-R6 `PgExpr::ilike().escape()` 編譯過但 runtime 失效（sea-query 0.32.7 escape hack 不含 pg ILIKE→非法 SQL→5000）、改 `LOWER(col) LIKE ESCAPE`、校正 4 處文件（含 contract §3.2 跨 feature 權威）。4 單元 Workflow 驅動（U1 `7daa622`→U2 `79f4983`→U3 `977203f`/U4 base-web `c1806680`＋polish `8ccea9d`＋doc `5c0e3f7`）;C-V 全綠（62 bin＋7 live `--test-threads=1`／endpoint_coverage_lint `[&str;11]` 6 端點全治理＋entity_access_lint／C-V-9~11 CDP 真發 request／C-V-13 零回歸／C-V-14 prod build）、holistic PASS（12 FR+11 SC 全 covered、無 overbuild）;**零 migration/entity/schema、無新 crate**;rust-api `3874182`→`8ccea9d`、base-web `223bc83e`→`c1806680`;D1 follow-up（hasAuth gating＋getUserRoutes＋選單可見性）延波2 Menu 刀（§3.10）
- **2026-06-18 008-system-settings 全綠收刀（波 1 第一刀＝system_settings KV 打樋;波 1 全完成）**（merge `b52dafe`）:3 全專案首次——首個 policy-governed 端點（`require_policy` DB-fresh per-route layer、enforce_mw 不動、5003→403 live 首証）／首個 007 op-log threading live consumer（`to_audit_operator`→operator_ip 真 INET round-trip）／立 `endpoint_coverage_lint`（⚠️x:registered==as-built＋policy-governed⊆m002 seed＋self-test）。2 端點 GET/POST＋super-only＋value_type 2222＋同 txn 審計原子＋net-new base-web static 頁/rev3-* wrapper 首檔/i18n;零 migration/entity/schema（m005 MOOT）、無新 crate;4 單元 Workflow 驅動（U1 `8e5a024`→U2 `4f4952d`→U3 `3874182`/U4 `5fdd6f0`＋§2 trim `223bc83e`）;C-V-0~11 全綠（live policy-gate 5003／op-log INET／CDP toast off↔on／prod build／零回歸 perf 讀5.8改7.9ms）、holistic 雙 lens ready-to-merge 0 blocking;enforce_mw/base-web 既有檔未動、SC-006/007 零回歸;rust-api `fc4b50e`→`3874182`、base-web `c2ad92f`→`223bc83e`

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **波 2 Role 刀**（rev2 013*/016*/018;schema 起點 rev2 013〔sys_role+sys_user_role+policy seed〕;解鎖 Role×Menu 授權〔getRoleMenu/updateRoleMenu/getRoleHome/updateRoleHome+menu-auth-modal、消費 010 getMenuTree/getAllPages〕;DESIGN §8.2）;或 **⚠️b 審計讀端刀**（殿後）。**待階段 0 `superpowers:brainstorming` 起手**（產出 `docs/superpowers/<NNN>-role-*.md`）

---

## 2. Roadmap & Phase 狀態

對齊 CLAUDE.md §3 SDD-TDD 工作流 + [DESIGN §8.4 交付波次](INTEGRATION-DESIGN.md)（波次定義/出口條件在彼）。本節為動態 status 追蹤;完成波 as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);完成波摘要累積數波後批次搬 [MILESTONES §2](INTEGRATION-MILESTONES.md)、本節永遠聚焦當前波。

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基 ✅ 全完成+已歸檔 (2026-06-18)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 1 — 第一刀＝`system_settings` 打樋 ✅ 全完成+已歸檔 (2026-06-18)

> as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md);D1 波2 選單可見性 follow-up 見 §3.10。

### 波 2 — data islands（進行中;第一刀＝User 009 ✅／第二刀＝Menu 010 ✅;③=B → User 留本波、`system_settings` 已移波1）

其餘業務 entity 各一刀（rev2 016 一 feature 兩 entity → rev3 拆兩刀紀律）。建議序 User→Menu→Role（sys_menu 表＋10 baseline＋66 demo＋policy 已 002 baseline 備妥、**010 Menu 零 migration**;Menu 完成解鎖 Role×Menu 授權）。

**刀/feature 清單**（素材=DESIGN §8.2 data island 縱切）:
- [x] **User 刀** ✅（009-user-management、merge `07b67d2`、2026-06-18;讀 3 端＋CRUD＋join `sys_user_role`、§5 全套+M:N join+MODAL-WIRING (a)+§5.8 分頁/filter 首 exercise+PageRes+23505→2222+INSERT op-log+停用登入 gate;as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）
- [ ] **Role 刀**（rev2 013*/016*/018;schema 起點在 rev2 013〔sys_role+sys_user_role+policy seed〕;**消費 010 getMenuTree/getAllPages**〔menu-auth-modal 角色×選單授權〕＋getRoleHome/updateRoleHome）
- [x] **Menu 刀** ✅（010-menu-management、merge `3810103`、2026-06-19;動態角色選單 getUserRoutes〔Casbin v2='menu' 過濾、§I.2 首兌現、前端零過濾、tree 祖先包含〕＋選單 CRUD〔reparent 3+1 guard ⚠️o facade slim `ReparentError`、handler 映 2222〕＋統一回收桶〔已刪除欄、restore 孤兒→頂層、`AuditOperation::Restore` 首 consumer、批次整批拒 no-partial〕＋越權〔8 端點 require_policy R_SUPER〕＋D1〔選單可見性＋hasAuth gating menu+user〕＋.env dynamic〔#7〕;11 端點、零 migration、無新 crate;**Role×Menu 授權〔menu-auth-modal〕留 Role 刀**;as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）
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
- [ ] graphify 圖譜更新（大改後 `graphify update`;最近一輪 2026-06-13、4176 nodes/567 communities——**早於 001 收刀**,**波 0 全收（001-007 七刀）＋波 1（008 system_settings）＋波 2（009 user-management＋010 menu-management）新碼均未入圖**〔001 scaffold/compose/deploy・002 migration×4/sea-orm-adapter・003 envelope/i18n・004 entity crate/soft-delete lint・005 audit・006 auth runtime・007 xdb crate/audit_ctx・008 system_settings facade/handler/require_policy/endpoint_coverage_lint＋base-web 新頁/wrapper/i18n・009 user CRUD facade/handler＋base-web user 接線・010 menu facade/handler/enforce〔menu_routes_for_roles〕/flat→tree 序列化/route.rs＋base-web menu 接線/.env dynamic/route store 例外〕,待一輪 update;docs 同期大改〔INTEGRATION-* 四檔／008 specs〕亦未入圖、惟 `.graphifyignore` 排除 docs/、見 §3.2）

---

## 3. Follow-up Backlog

### 3.1 000-base-web-docker-bootstrap follow-up

- [x] ✅（2026-06-13）`getUserList` CDP 瀏覽器流量補抓 → `tests/000-.../getuserlist-cdp-capture.json`（mock 版;rust-api 版由接線 feature CDP smoke 覆蓋）
- [ ] dynamic route mode 切換後重抓 `/route/*` 真實瀏覽器流量（對象屆時為 rust-api,詳 000 文件 §7）**〔trigger 條件 010 已達：`.env` dynamic 已啟、/route/* 已實作;低優先 archival、要做時 CDP 抓 getUserRoutes/getConstantRoutes 真流量〕**
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
- [x] ✅（已 007 T019、commit `e255545`）builder `cargo build --locked`（Dockerfile.rust-api.txt:58）＋dev `cargo install --locked`（:74）兩 stage 皆帶、無遺漏
- [x] ✅（已存在）`docker-compose.base-web.yml`:27-30 檔頭已有並行撞點警示（同 project name rev3-admin／共用 base_web_node_modules·pnpm_store 卷、勿與 master 同起;與 rust-api standalone `7e3fed6` 對稱）
- [ ] compose secrets 預檢（bind 缺檔自動建空目錄→錯誤不指向缺檔;up 前 wrapper 或文件註記）
- [ ] `front_nginx_certs` 要不要 `external: true`（消 compose warning vs 硬前置;拍板項）
- [ ] migrate 的 redis depends_on 與 FR-002/C-V-2 措辭對齊（實作只閘 postgres;補 depends 或修 spec 措辭;rev2 同形）
- [ ] postgres healthcheck `pg_isready -U soybean` 缺 `-d soybean_admin_rust`（dbname 預設=username→每 10s 一條 FATAL log;波 4 obs 落地前修、一 token;rev2 同形）
- [ ] dev watcher 工具評估:cargo-watch 上游已 archived＋`cargo install` 無版本 pin＋無 cache mount（dev image build 慢）→ 後刀換 bacon/watchexec 屬顯式決策（rev2 形 carry）
- [ ] 冷卷首啟 `up --wait` 自癒型 flap（base-web 容忍 ≈140s/rust-api ≈240s;`down -v` 後或新機器會撞）→ quickstart 補「exit≠0 先 ps 區分仍在編譯、等穩重跑即過」一句
- [x] ✅（moot、波 0 已收 2026-06-18）C-V-2 gate 斷言①複驗方法注記——「波 0 出口複驗」觸發窗口已過;手法（`docker logs --timestamps` 驗 one-shot migrate 首輪）若跨波有用可摘進 quickstart C-V-2 段、否則純歸檔
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

**Menu 刀消費（research.md R4 D2~D4 移交;Menu 刀＝010 已收）**:
- [x] ✅（2026-06-19、010）`RouteMeta` 擴充——`build_user_route_tree` meta 序列化 icon/localIcon〔icon_type==2→localIcon〕/multiTab/href/activeMenu/keepAlive/constant/order/hideInMenu/i18nKey＋讀 `icon_type`;getUserRoutes 三角色 live＋CDP 側欄實證（href 落值由 entity 原樣序列化）
- [ ] iframe props 內嵌復原評估（D2）— **010 explicit OUT（沿 href 外開、plan §11）**、re-defer 未來 iframe feature（props 欄位/wire 擴充）
- [ ] `filter_routes` 遞迴化評估（D3）— **010 explicit OUT（登 backlog、plan §11;010 改以 build_tree 祖先包含解選單樹過濾、casbin policy filter 未遞迴化）**、re-defer optimization 刀（現 demo policy 全覆蓋 66 列前向相容、非急）
**rust-api 順手（002 引入後重驗）**:
- [x] ✅（2026-06-17、004/U1）workspace Cargo.toml time pin 註解勘誤（見 §3.4 同條;commit `3f87a25`）
**sea-orm-adapter vendored 已知瑕疵（byte-identical 拷貝保留、§I.5;重鑄/測試啟用時處理、U1+U2 review 發現）**:
- [ ] adapter `Cargo.toml` 內 `async-trait`/`tokio` 的 `default-features = false` 對 workspace 繼承條目 redundant → 每次 build 兩條 cargo warning（拷貝紀律刻意保留;日後拍板允許動 vendored manifest 時一併清）
- [ ] adapter `examples/`（rbac_*.conf/csv）為 `#[cfg(test)]` fixture:prod `--bins` build 免 COPY（已驗正確、Dockerfile 有註解），但若日後在 builder/容器內跑 `cargo test` 會缺 fixture（屆時 COPY examples 或 adapter 測試改 env-gate round-trip smoke）
**constitution（待 user 親決）**:
- [x] ✅（已決 不採納、2026-06-16、DECISIONS §1 ⚠️u）constitution §IV 增第 10 題提案——user 拍板【不採納】;CHECKLIST §5 拍板索引已列「已決 27」含 ⚠️u、此 [ ] 為 stale 殘留、關閉對齊

### 3.6 003-envelope follow-up（收刀移交 2026-06-16;均不阻塞、消費刀觸發時處理）

**i18n 顯示端到端階梯（FR-012；機制本刀已以型別/單元/component 測覆蓋、端到端待真端點）**:
- [x] ✅（2026-06-17、006）波 0 Auth/login 刀：login 失敗發 `1000`=`auth.login.failed`→toast 經 `$t` 在地化——006 C-V-3 CDP 實機證 toast 顯「用户名或密码错误」（非 raw key）＝i18n 顯示路徑首個端到端檢核點達成（fallback 已由 003 tsx 單元覆蓋;**踩點**：首跑 vite 服 stale locale 模組顯 raw key、`restart base-web` 後綠、CLAUDE.md §8.2.1）
- [x] ✅（008 per-entity 2222／009 list 端點補齊）波 1 system_settings＝首個真 biz endpoint 發 per-entity `2222` key（C-V-6/7）;`PageRes` runtime 形＋空字串 filter 守門由 **009 getUserList** 補齊（首個 list 端點、CDP 帶空 param 回全部非 0 列＝curl≠modal 實證、C-V-9/C-V-11）
**顯示限制（R3、本刀不修）**:
- [ ] `4040`/`5003`（HTTP 404/403）走 axios native error、`error.code≠BACKEND_ERROR` 致 envelope msg 今日不顯示（DESIGN §7.3 既認限制）；拓寬 `onError` extraction（**009 未做、再延**:009 守 contract §6.3【不改 request 攔截器】、只 MODAL-WIRING (a)＋2222 biz toast 在地化〔addUser dup 等〕;403/404 native msg 在地化需動 `service/request` interceptor → 改 target 為需碰 interceptor 的刀〔**010 Menu 刀亦未做（守 frozen request interceptor、§III 軌道未授改 request）、再延專門 interceptor 刀**〕）。**（R3 CDP 已驗 2026-06-18:Admin→403 前端實顯原生「Request failed with status code 403」、**未在地化**〔backend `system.forbidden`/5003 未被抽譯;根因 packages/axios HTTP non-2xx 走原生 reject→`error.code=ERR_BAD_REQUEST≠BACKEND_ERROR_CODE`→`request/index.ts:116` 判 false→`message=error.message`〕、頁面正常 render NEmpty 不崩。code 改動〔403/404 也抽 `error.response.data.msg` 經 translateBackendMsg〕排波2 User、與其 403 場景一起改〔base-web §III 軌道〕）**
**rust 範圍延後（R7）**:
- [x] ✅（2026-06-18、009）`From<DbErr> for AppError`→`Internal`/5000（006 帶入）＋`DbErr::sql_err()`→`SqlErr::UniqueConstraintViolation`（pg 23505）→`2222`（009 addUser/updateUser 寫端 `.map_err(map_write_err)` 帶入、⚠️o blanket From 不改、C-V-6 live dup→2222 實證;§3.8 末條同源）
**rust 信封消費（首個業務刀觸發、review 衍生、非阻塞）**:
- [x] ✅（2026-06-18、009/PageRes 實評:double-ser 成本可忽略·序列化失敗 fallback 不現實·維持現狀）`Res::ok` 採 `Res<serde_json::Value>`（`to_value` 中轉、003 時 `#[allow(dead_code)]` 無消費者）→ 首個消費業務刀重估兩點：(a) 序列化失敗 fallback `data:null` 仍掛 `code:"0000"`＝成功碼掩蓋錯誤 → 視需要導向 `AppError::Internal(5000)`；(b) 熱路徑大 payload 的 double-serialization（to_value→Json）→ 可改保留泛型 `Res<T>` 直接 Json、省中轉。**（008 觸發：波1 system_settings＝首個 `Res::ok` 業務消費者〔get flat 小陣列／update `Value::Null`〕；payload 極小 →(a) 序列化失敗不現實、(b) double-ser 成本可忽略，兩點皆不觸 → 留首個【重 payload】消費者〔波2 User `PageRes` 大列表〕實評）**
**測試守護 fidelity（review 衍生、非阻塞）**:
- [ ] base-web i18n 單元測 `src/locales/__tests__/translate-backend-msg.spec.ts` 以既有 `tsx` **重建** `translateBackendMsg` 公式（非 import 真匯出——`@/locales` 載入鏈耦合 `import.meta.env`/`localStorage`、純 node 不可解）→ 引入真測試環境（vitest+jsdom 或 vite-node＋shim）時改 import 實際 export 閉合 fidelity gap；`pnpm test` 現＝單一 i18n 腳本、屆時併入正式 suite

### 3.7 004-soft-delete-infra follow-up（收刀移交 2026-06-17;均不阻塞、消費刀觸發時處理）

**ipnetwork／time-lock（U1 實作期發現）**:
- [x] ✅（2026-06-17）with-ipnetwork 1.86 build 早驗綠（ipnetwork 0.20.0 入 compile graph、無退 String+cast）;inert time 0.3.47 入 lock 但 feature-gated 不編譯（註解已勘誤、見 §3.4／§3.5）
- [x] ✅（2026-06-17、006 Unit 1）**Auth/Token time-pin landmine 已排**:006 加 jsonwebtoken 9 經 `simple_asn1` 把 time 拉進真 compile graph（`cargo tree -i time` 實證 time←simple_asn1←jsonwebtoken←server）→ pin `simple_asn1 0.6.3`（其 time req 放寬回 ^0.3）再 `time 0.3.37`，1.86 dev build＋prod `--locked` 皆綠（commit `04fc6f8`）。**順序硬約束**：simple_asn1 須先降、否則 `cargo update -p time --precise 0.3.37` 失敗（0.6.4 floor `time^0.3.47`）
**INET log entity 消費（audit 刀觸發）**:
- [ ] 3 INET 欄 `IpNetwork` serde round-trip:**write-binding 無 42804 ✅**（3 欄、007+008 已證）;**`sys_operation_log.operator_ip` decode round-trip ✅**（008 C-V-5 經 entity Model find+IpNetwork assert）;**惟 `sys_access_log.client_ip`／`sys_login_attempt.client_ip` 仍僅 write-binding 證**——兩 sink facade 在 server/src 零 find/all 讀路徑、Model decode round-trip 待 **⚠️b 審計讀端刀**（波2 殿後）首次以 entity Model 讀回該兩表
**casbin_rule 治理欄消費（policy 刀觸發）**:
- [ ] `casbin_rule` entity 自定 11 欄（8 adapter 基底＋protected/created_at/created_by 治理 3）——policy 刀 cross-check:adapter 自身 8 欄 Model 對治理欄隱形（§I.6 D），確認 governance 讀寫經 entity crate Model 非 adapter Model
**soft-delete 活體覆蓋邊界（Role/Menu 刀觸發）**:
- [x] ✅（2026-06-19、010）`sys_menu` 的 `find_active` 活體驗證——010 menu_recycle live test 證 `list_active`（find_active）排除 soft-deleted、getMenuList/v2（list_all）含已刪;三 SoftDeletable facade（sys_user 004／sys_role 009／sys_menu 010）皆活體覆蓋

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
- [x] ✅（2026-06-18、009）首個把 `soft_delete` 接進 handler＝009 deleteUser/batchDeleteUser（`DbErr→AppError`→Internal 映射實際觸發）;`sql_err()` 23505→`2222` 補齊＝addUser/updateUser 寫端 `.map_err(map_write_err)`（⚠️o、blanket `From<DbErr>` 不改、禁裸 `?`）、C-V-6 live dup user_name→2222 非 5000 實證

### 3.9 006-auth-island-min follow-up（收刀移交 2026-06-17;均不阻塞、消費刀觸發時處理）

**`enforce_mw` policy-step 上線＋5003 live（✅ 波1 008 兌現，非波2）**:
- [x] ✅（2026-06-18、008）波 1 第一刀 system_settings＝**首個 policy-governed 端點**：新增 `require_policy(path,method)` per-route layer（**不改 enforce_mw 本體**、守契約 §3.4;DB-fresh `roles_of_user` 不信 claims.roles→`enforce_role_path_method`→`PermissionDenied`）、兩端點各掛 route_layer＋外層 enforce_mw;**首證 5003→HTTP403 live**（C-V-6 Admin/User GET/POST→403 code 5003 不洩值＋CDP）;`endpoint_coverage_lint`（⚠️x）立、分類 public（/health、/auth/login）/auth-only（/auth/getUserInfo）/policy-governed（system_settings×2）三類＋斷言 registered==as-built＋policy-governed⊆m002 seed。空字串 filter 守門＝§5.8、system_settings flat 無 filter→留波2 User
**token 不隨 user 停用/軟刪即時失效（波2 User CRUD／波3 session revocation 觸發）**:
- [ ] getUserInfo `find_by_id` 不濾 `deleted_at IS NULL`、`enforce_mw` 不查 user active → 已軟刪/停用 user 持既發 access token 仍可通關至過期（≤access_ttl ~1h）;login 端 `find_by_user_name` 已濾軟刪（無法新登入）。即時撤銷（user disable/delete 即踢）屬 §I.7 完整 session 機器=波3（rotation/reuse/revocation）;波2 User CRUD 若需即時失效須提前接 revocation hook
**JWT 參數硬編（波3 refresh/session 或 settings 觸發）**:
- [ ] JwtConfig 的 `access_ttl`(3600s)/`refresh_ttl`(7d)/`iss`(`rev3-admin`)/`aud`(`rev3-admin-web`) 為 main.rs boot 常數;波3 refresh/session policy 或 settings 若需可設定化（per-role TTL／runtime 調）再外移、本刀硬編足夠

### 3.10 008-system-settings follow-up（收刀移交 2026-06-18;均不阻塞、消費刀觸發時處理）

**D1 — 選單可見性＋前端 hasAuth gating ✅ 已兌現（010-menu-management、merge `3810103`、2026-06-19;008＋009 同家族共此項）**:
- [x] ✅ 010 Menu 刀兌現：getUserRoutes（Casbin v2='menu' 過濾、§I.2 首兌現、前端零過濾）收選單可見性（非 super 不見 manage_menu/manage_role/manage_system-settings）＋前端 hasAuth button gating（menu:* 於 menu 頁＋retroactive user:* 於 user 頁;system-settings skip＝無 button code＋super-only 選單已隱 moot）＋`.env` `VITE_AUTH_ROUTE_MODE` static→dynamic（#7 兌現）。★ route store 1 處授權 rev3-inline 例外（dynamic 分支合併前端 builtin 常數路由 login/403/404/500、修 FR-002／R-cr 預示缺口、user 拍板 option 1）。CDP 三角色側欄差異實證。詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)
**value_type 驗型擴充（新值型 seed 觸發）**:
- [ ] `validate_value_type` 現僅 enum 分支、非 enum 型（number/string/json）保守放行（spec.md Assumption／data-model §6「型擴充隨需要」背書、目前僅 `enum:on,off` 單鍵 seeded 無缺口）→ 後續若 seed 引入新值型 key 而未補對應驗證分支會「髒值靜默寫入」;補分支時併補純測（或在守恆檢查加「每 seeded value_type 前綴必有對應驗證分支」斷言）
**endpoint_coverage_lint 抽取器邊界（非字面 route 參數觸發）**:
- [ ] `first_string_after` 抽取假設 route/policy 參數為**字面字串**（非 const）、區塊註解 route 抽取無 self-test（現況 dormant:main.rs 全字面、零區塊註解）→ 後續刀若引入 `.route(CONST,...)`/`require_policy(ROUTE_CONST,...)` 須加守門（夾 ident 字元→panic 提示更新 lint）或補區塊註解 self-test

### 3.11 007-audit-overlay follow-up（XFF 解析完整化）

**rust-api XFF 真實 client IP 解析尚不完整（未來 feature;user 拍板 2026-06-18、#3 衍生）**:
- [ ] 拓樸分工已定（user 拍）:**nginx 維持忠實 append**（`proxy_add_x_forwarded_for` 把自己 IP 串進 XFF、不設 `set_real_ip_from`）、**真實 client IP 解析全由 rust-api `resolve_client_ip`（007 audit_ctx）負責**。惟現行 `resolve_client_ip`（rightmost-untrusted＋`TRUSTED_PROXY_CIDRS` gate）**尚不完整** → 後續開 feature 完整化（多跳 proxy 鏈精確處理／trusted-proxy CIDR 設定／fail-safe 邊界）;**公網部署前須收齊**（與 #2 nginx 硬化／#3 同部署窗口評估）

### 3.12 009-user-management follow-up（收刀移交 2026-06-18;均不阻塞、消費刀觸發時處理）

**User wire type-lie（typings 收斂刀觸發;⚠️r 契約漂移、user 對 type-lie 敏感）**:
- [ ] `getUserList` 的 `nickName`/`userPhone`/`userEmail` 當 DB NULL 時序列化為 `null`（rust `Option<String>`），但 base-web `Api.SystemManage.User` 宣告 non-null `string`＝wire↔typings type-lie（runtime 前端容忍 null、typecheck 不抓〔只驗前端碼非 rust 輸出〕）。009 守 contract §6.3【不改既有 system-manage.d.ts】未消解 → typings 收斂時（Menu 刀／專門）把該 3 欄改 `string | null` 對齊 rust（同 ⚠️r 精神）
**審計 payload 未含角色集 delta（⚠️b 審計讀端刀觸發）**:
- [ ] addUser/updateUser 的 op-log `payload_before`/`payload_after` 僅快照 `sys_user` Model（`audit_json`、password 已 redact）、**未含 `sys_user_role` 角色集 before/after**;原子性（user+roles+op-log 同 txn）已足、spec FR-006 未要求逐項列角色 → ⚠️b 審計讀端刀若要呈現「誰把 user 角色由 A 改 B」現查不到、屆時評估 payload 併入 role code 集 delta（holistic nit、非缺陷）
**getAllRoles/replace_roles「啟用角色」語意（Role 刀 confirm）**:
- [ ] getAllRoles 與 replace_roles 用 `sys_role::find_active`（僅濾 `deleted_at`、**不濾 `status`**）＝「啟用」解作未軟刪（SoftDeletable 語意、data-model §3／contract §6.1 背書）;FR-008「目前啟用角色」若 Role 刀日後要排除 status=停用角色不可指派、再於 find_active 後加 status 守門（本刀 by-design、非缺口）

### 3.13 010-menu-management follow-up（收刀移交 2026-06-19;均不阻塞、消費刀觸發時處理）

**login fallback 路徑 transient「No match for login」（upstream soybean、cosmetic）**:
- [ ] `.env` dynamic 後，未認證/getUserRoutes 失敗 fallback 路徑 `auth.resetStore`→`toLogin`（by route-name）在 routeStore 重註冊 constant routes **之前**呼叫→vue-router 拋一次 uncaught「No match for {name:login}」（upstream soybean `auth/index.ts` 排序、010 未動該檔）。**user-facing 正確**（最終導到 /login、token 清空、不白屏、CDP 實證）、僅 console transient 例外可恢復 → 若要 fallback 100% 例外-free，須調 resetStore/toLogin 排序（動 frozen `auth/index.ts`、另開 feature 評估）
**`manage_policy-archive` 前端 view 缺（波3 future feature seed gap、dynamic 暴露）**:
- [ ] `manage_policy-archive`（m002 baseline seed、R_SUPER menu policy）無對應前端 view／i18n（policy-archive＝波3 casbin_rule 治理功能、尚未建前端）→ `.env` dynamic 後 Super getUserRoutes 含此路由、`transform.ts` 報 `View component "manage_policy-archive" not found` console error（非致命、已 dropped from sidebar、Super 其餘頁正常）→ 波3 policy-archive 刀建前端 view 時自然消解;本刀忠實載入 seed、不為此加過濾/migration
**R_ADMIN `user:edit` button vs super-only endpoint seed 不對齊（沿 009、忠實 seed）**:
- [ ] m002 R_ADMIN 有 `user:edit` button code，但 user-write 端點（updateUser 等）R_SUPER-only → R_ADMIN 於 user 頁見「編輯」鈕但動作 403（button code 與 endpoint policy 不對齊）;010 hasAuth gating 忠實 seed、不在資料島刀修;policy 校正刀評估對齊（補 R_ADMIN updateUser policy 或收 user:edit button seed）。（★ 校正：R_ADMIN **無** `manage_role` menu policy〔ground-truth psql：R_ADMIN v2='menu'＝home/manage_user/manage_user-detail/function/function_toggle-auth〕、亦無 `role:*` button——先前「manage_role menu」為筆誤、已更正）
**MenuList wire type-lie（typings 收斂刀觸發;⚠️r、沿 §3.12 User 同款）**:
- [ ] 既有 `service/api/system-manage.ts` `fetchGetMenuList` 宣告回 `MenuList=PaginatingQueryRecord<Menu>`（分頁包），但後端 getMenuList/v2 回**裸陣列樹**＝wire↔typings type-lie;010 守 frozen 既有檔【不改 system-manage.ts/.d.ts】、改以 rev3 `fetchGetMenuListV2`（honest 裸陣列型）＋menu/index.vue custom transform 繞過 → 舊 `fetchGetMenuList` 成 latent type-lie/dead（現無消費者）→ typings 收斂刀（同 §3.12）reconcile：棄用舊 fn 或把 `MenuList` 改裸陣列型對齊;順帶檢視 `Menu`/`MenuRoute` nullable 欄（component/routePath 等 Option<String>→null vs typing non-null）是否同 §3.12 type-lie
**home_of_roles 多角色 tie-break（Role 刀 home 維護 confirm）**:
- [ ] getUserRoutes 的 `home`＝`home_of_roles`〔取啟用角色 by id ASC 首個非空 `sys_role.home`〕;現三角色皆 'home' 無歧義，未來 Role 刀讓不同角色有不同 home 時，多角色 user 的 home 解析（現 min-id 角色 home）語意須於 Role 刀 getRoleHome/updateRoleHome 確認/收斂（本刀 by-design、非缺口）
**batch_soft_delete sentinel DbErr 攜出（robustness、未來 refactor 候選）**:
- [ ] `batch_soft_delete` 因 `mutate_in_txn` 閉包簽名固定回 `DbErr`、以 sentinel `DbErr::Custom("BATCH_DELETE_PROTECTED"/"…HAS_ACTIVE_CHILDREN")` 攜出 `DeleteError` 分類、外層 `map_err` 還原;理論上 DB 若真回同字面 Custom 會誤判、但 sea-orm 不產此類字面＝實務零風險（U3 quality review 過）→ 若未來覺脆，改 batch 不走 mutate_in_txn、自行 begin/commit txn 直接攜 `DeleteError`（非急、現法全綠且隔離乾淨）

---

## 4. 跨 feature 待驗證項

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 27**:①flat-in-main 沿用｜② C+ typings-as-oracle｜④僅 join 表加 FK｜⑤凍結邊界=archetype+行為島+碼表入憲｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️d redis tag 建時 pin 數字版｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️g 受控參照 rev2 source｜⚠️i MODAL-WIRING 五用途全授+BUILD-CONFIG 不收錄｜⚠️j rust-api 沿倉換分支｜⚠️k migration 短編號 mNNN_<name>｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings｜⚠️s fork-delta 雙模式(原行註解保留+rev3-inline 標記)｜⚠️t schema 波 0 一次全建(rev2 終態 squash 基線+delta 顯式分離;seed 口徑 92 列/6 表勘誤 2026-06-13)｜⚠️v casbin_rule 委派式建表+adapter 併入 002(sub-crate 刀消解)｜③ B=`system_settings` 第一刀(2026-06-16)｜⚠️a perf 保守預設(p95 300/500/1s・99.5%)｜⚠️b 審計讀端 做+波2 殿後｜⚠️o application-RI hybrid(intra 下沉 facade/跨 facade·restore 留 handler)｜⚠️u §IV 第10題 不採納｜⚠️x endpoint_lint 波0 豁免移波1｜⚠️y biz-msg i18n A(前端譯·msg=key;規約於 003-envelope 落定〔4 根+文法+13 碼 key+兩端接線+locale 外包 backend.〕·刀1+ 僅套用)｜⚠️aa BASE-WEB-I18N-WIRING ★ 軌道(constitution §III amend v1.1.0;授權 i18n inline 接線：service/request 攔截器/locales backend 命名空間/app.d.ts Schema)｜⚠️ab constitution §I.3 措辭 PATCH(釐清 msg 載 i18n key 對齊 ⚠️y、v1.1.1)

**009-user clarify／as-built（spec.md ## Clarifications／contract §3.2;非 ⚠️ 碼級）**:self-lock 防自鎖對稱守門(禁超管自我移除超管角色/自我停用→2222 整筆拒)｜批次刪缺漏 idempotent skip(已不存在/已刪 id 靜默略過、cannot-delete-self 仍獨立整批拒)｜ILIKE 處方校正(`PgExpr::ilike().escape()` runtime 失效〔sea-query 0.32.7 escape hack 不含 pg ILIKE〕→改 `LOWER(col) LIKE ESCAPE`、權威見 user-management-contract §3.2 供 Role/Menu 刀繼承)

**010-menu clarify／as-built（spec.md ## Clarifications／menu-management-contract;非 ⚠️ 碼級）**:批次刪父子整批拒(逐項獨立驗證、批內任一 protected/有 active 子〔即使子同批被選〕即整批拒、no-partial、不做批內 cascade/排序)｜retroactive hasAuth gating 含 user/settings(user 頁 user:* gate〔code 已 seed〕、system-settings skip〔無 code+super-only moot〕)｜route store rev3-inline 例外(dynamic 分支合併前端 builtin 常數路由 login/403/404/500、修 FR-002／R-cr 預示缺口、user 拍板 option 1;C-V-11 零回歸註記為授權例外)

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
