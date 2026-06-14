# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 0 地基 進行中（001+002+003+004+005 ✅ 已收刀、餘 第二 audit 刀＋Auth 島最小段＝計 2 刀）**（波 -1 as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-14 005-audit-op-log 全綠收刀＋merge（未 push、波 0 第五刀／audit 刀之首）**:`model/audit.rs`（`mutate_in_txn` 泛型 wrapper 業務寫＋審計寫同 txn 原子〔Some 寫+commit／None no-op／Err 回滾〕＋`AuditOperation` 全4／`AuditEvent`／`AuditSerialize` trait、零 entity:: 守 lint③）＋`facade/sys_operation_log.rs`（append-only sink、`audit_active_model` operator_ip None→NotSet 避 42804＋`write_in_txn`）＋`sys_user` `impl AuditSerialize`（redact password、15 欄排除 current_session_id）＋單一寫路徑 proof `soft_delete`（Ok(true)/Ok(false)）＋`soft_delete_query`;擴 entity crate（sys_operation_log Model 10 欄＋with-json、無 migration）＋Cargo.lock 補 16 筆 sea-orm optional-dep（feature-gated、time=0.3.47 user 拍板接受、清 time pin 註解 backlog）;test-first TDD（redact＋SQL-build 純測 red→green）＋3 場景实机 smoke（commit〔operator_id==1 SC-004〕/no-op/rollback、orchestrator 親驗綠）;4 unit subagent-driven（spec+quality 各過＋final READY TO MERGE）;7 SC／12 FR 全滿足;merge `65f4bbe` 回 rev3-admin-root、feature branch 保留;**未 push（待 user 同意）**
- **2026-06-14 004-soft-delete-infra 全綠收刀＋merge＋push**:test-first TDD、DB-free 20+1ignored+22／live --ignored 1／prod image build 全綠（orchestrator 親測）;新 `entity` crate（3 Model 逐欄鏡像 m001、with-chrono 僅 entity〔time 不入圖〕）＋`SoftDeletable` trait（active minimal 無寫側）＋facade 三閘（user/role soft-del＋`find_active_by_*`／user_role plain、不 re-export Entity、回 raw Model/DbErr）＋`entity_access_lint` build-failing（兩階段抹白掃描＋meta-test 22 test、⚠️g 全新寫）＋bounded 实机 smoke（#[ignore] 證 soft-delete 真生效）＋Dockerfile entity COPY（prod build mandatory、RED→GREEN）;triple-guard 就位、7 SC／11 FR 全綠（FR-010 零洩漏）;7 單元 subagent-driven＋final READY TO MERGE;merge `e8334d7` 回 rev3-admin-root、feature branch 保留、三 ref 已 push（rev3-admin-root/004 保留分支/rev3-admin-rust-api）

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **波 0 剩 2 刀（擇一起手）**——①第二 audit 刀〔rev2 015：`sys_access_log`＋`sys_login_attempt` entity/facade＋`audit_ctx` 全域中介層〔RequestContext 自動抽取 operator/trace〕＋`xdb` sub-crate〔client_ip→region、⚠️v 隨本刀拷入、注意 Dockerfile [[bench]] COPY 坑〕；接 005 `mutate_in_txn`/`AuditEvent` 機制〕／②Auth 島最小段〔rev2 013：login＋getUserInfo＋`enforce_mw` 最小鏈；§8.3 兩案共同前提、出口條件「login→getUserInfo→enforce curl 通」靠此達成〕。起手＝階段 0 brainstorm（`docs/superpowers/<NNN>-<name>.md`）→ 手動 `/speckit-specify`（§3）

---

## 2. Roadmap & Phase 狀態

對齊 CLAUDE.md §3 SDD-TDD 工作流 + [DESIGN §8.4 交付波次](INTEGRATION-DESIGN.md)（波次定義/出口條件在彼）。本節為動態 status 追蹤;完成波 as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);完成波摘要累積數波後批次搬 [MILESTONES §2](INTEGRATION-MILESTONES.md)、本節永遠聚焦當前波。

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> 機械建構＋constitution 重鑄兩段全交（pre-spec-kit、全落 default branch、無 feature branch）:outer repo＋worktree/submodule 註冊 `2ec9cda`（⚠️j/⚠️q）/ 設計書入檔＋拍板回填＋歸位改名 `7fd1ac6`→`4aa7c89` / C 方案文件體系 DECISIONS+CHECKLIST+MILESTONES `4724549`・`4300b54` / graphify 首建 `8f66fe0` / 000 base-web bootstrap＋13 端點對映 `46591c4`~`e898421` / SessionStart hook 原樣承接 `ed2a789` / **constitution-rev3 v1.0.0 凍結 `167db96`**（13 項拍板融入）。出口四項全綠（session 健檢/獨立 commit/grep rev2 歸零/speckit 可用）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基（進行中・當前）

infra/deploy＋envelope＋soft-delete 基建＋audit 兩刀＋Auth 島最小段 —（rev2 001-012＋015）對應、首個 spec-kit feature 起跑點。

**刀/feature 清單**（素材=DESIGN §8.2 跨切地基;刀界由各刀 brainstorm/specify 時定稿）:
- [x] **001-infra-deploy 刀 ✅ 收刀（2026-06-13、merge `c9ffad5`）**——master compose 5 service＋migrate gate＋acme 殼、dev/prod override、deploy/ 全套、rust-api scaffold（/health＋空 migrator＋lock pin）;C-V-0~8 實機全綠（SC-001~007）;follow-up 見 §3.4;spec 全帳在 `specs/001-infra-deploy/`
- [x] **002-rev2-schema-baseline 刀 ✅ 收刀（2026-06-13、merge `9233ae0`）**——前代 35 支 squash 為 4 支基線（m001 schema 11 表終態／m002 seed 92 列 6 表／m003 user_role FK ×2 RESTRICT／m004 demo 選單 66＋policy 全 R_SUPER）＋sea-orm-adapter 整檔拷入（⚠️v 委派式、§I.5）;C-V-0~9 實機全綠（SC-001~008）、normalize 六規則（row-order 假紅、user 拍板方案 A、契約留痕 migration-chain.md §3）;spec 全帳在 `specs/002-rev2-schema-baseline/`
- [x] ~~**sub-crate 刀**~~ **已消解（2026-06-13、⚠️v 拍板）**——`sea-orm-adapter` 併入 002（委派式建表的直接消費者）、`xdb` 併入 audit 刀（首個消費者）;§I.5 唯二拷貝例外不變、casbin 2.20 pin 隨 002
- [x] **003-envelope 刀 ✅ 收刀（2026-06-13、merge `7960a73`）**——`Res<T>{data,code,msg}`＋`PageRes<T>`＋`BizCode` 13 碼矩陣（code/msg 凍結⚠️f＋http_status() 單一真相）＋`AppError` struct＋8 建構子（4 保留碼無建構子⚠️f／Internal→200⚠️e／detail 不洩漏）;非新 crate（server 內 2 模組）;test-first TDD 18/18＋prod build＋C-V 1-5 全綠;spec 全帳在 `specs/003-envelope/`
- [x] **004-soft-delete-infra 刀 ✅ 收刀（2026-06-14、merge `e8334d7`）**——新 `entity` crate（3 Model 鏡像 m001）＋`SoftDeletable` trait（active 過濾 minimal）＋`model/facade/` 三 facade（user/role soft-del＋`find_active_by_*`／user_role plain、不 re-export Entity、回 raw Model）＋`entity_access_lint` build-failing 守恆（兩階段抹白掃描＋meta-test＋regression 22 test）＋bounded 实机 smoke（#[ignore]、m002 seed）;triple-guard 就位;test-first TDD、DB-free 20+1+22／live 1／prod image build 全綠;7 SC／11 FR 全滿足（FR-010 零洩漏）;spec 全帳在 `specs/004-soft-delete-infra/`
- [x] **005-audit-op-log 刀 ✅ 收刀（2026-06-14、merge `65f4bbe`）**——op-log 同 txn 原子審計：`model/audit.rs`（`mutate_in_txn` 泛型 wrapper＋`AuditOperation` 全4／`AuditEvent`／`AuditSerialize` trait、零 entity:: 守 lint③）＋`facade/sys_operation_log.rs`（append-only sink、`audit_active_model` operator_ip None→NotSet 避 42804＋`write_in_txn`）＋`sys_user` `impl AuditSerialize`（redact password 15 欄）＋單一寫路徑 proof `soft_delete`＋`soft_delete_query`;擴 entity crate（sys_operation_log Model+with-json、無 migration）;test-first TDD（redact＋SQL-build 純測）＋3 場景实机 smoke（commit/no-op/rollback 原子）;7 SC／12 FR 全滿足;spec 全帳在 `specs/005-audit-op-log/`
- [ ] **第二 audit 刀**（access-log＋login-attempt＋xdb〔rev2 015:`sys_access_log`＋`sys_login_attempt` 兩表＋`audit_ctx` request-context 中介層;`xdb` sub-crate 隨本刀拷入——⚠️v 拍板、注意 Dockerfile [[bench]] COPY 坑;接 005 `mutate_in_txn`/`AuditEvent` 機制〕）
- [ ] **Auth 島最小段**（login＋getUserInfo＋`enforce_mw` 最小鏈;rev2 013 對應;§8.3 兩案共同前提）

**前置拍板（user 親決,4 項;結論全文見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）**: ✅ 全拍完（2026-06-13）
- [x] ①router 結構 ✅ flat-in-main 沿用（lint 三源一致直接沿用）
- [x] ④選擇性 FK ✅ 僅 join 表 `sys_user_role` 加 FK、其餘 11 表維持零（義務照 §3.3）
- [x] ⚠️d redis-stack image tag ✅ 建 stack 當下即 pin 數字版
- [x] ⚠️k migration 檔名 ✅ 短編號 `mNNN_<name>`

**出口條件（DESIGN §8.4,4 項全綠才換波）**:
- [x] dev stack `up --wait` 全 healthy ✅（001、C-V-2 實證 2026-06-13）
- [ ] 三守恆綠（**entity_access_lint ✅ 004 達成 2026-06-14**〔build-failing＋meta-test 22 test〕・endpoint_coverage_lint〔後刀〕・**migration up→down→up ✅ 002 C-V-5 達成 2026-06-13**）
- [x] envelope 13 碼 contract 形狀測試綠 ✅（003、18/18 test-first 2026-06-13）
- [ ] login→getUserInfo→enforce 最小鏈 curl 通

### 波 1 — 第一刀（未開始）

User **或** `system_settings` 打樣（待決③）:migration→facade→handler→enforce→wire→frontend 全鏈＋§5 各面一次逼出。

**刀/feature 清單**:
- [ ] **第一刀**（待決③ 拍板後定:A=User 直刀〔rev2 016*+017 規模、§5 全套+M:N join+★MODAL-WIRING〕或 B=`system_settings` 打樣〔rev2 029 子集、§5.6 熱 KV 獨有〕;兩案比較見 DESIGN §8.3）

**前置拍板（user 親決,3 項;工程預設與結論全文見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）**:
- [ ] ③第一刀位（User 直刀 vs `system_settings` 打樣;預設=傾向 User 直刀;開工前）
- [ ] ⚠️a 效能/可用性數字（預設=p95 300/500ms/1s・99.5%/月;波 1 驗收前）
- [ ] ⚠️o application-RI 驗證層位（預設=維持 handler 層驗、下沉 facade 屬設計變更須明示;facade 設計時）

**出口條件（DESIGN §8.4）**:
- [ ] §8.1 工序 9 列全過
- [ ] CDP 經 front-nginx 真 `/api` 路徑驗收
- [ ] 該 entity 的 §5.0 列逐面勾消

### 波 2 — data islands（未開始）

其餘業務 entity 各一刀（rev2 016 一 feature 兩 entity → rev3 拆兩刀紀律）。

**刀/feature 清單**（素材=DESIGN §8.2 data island 縱切;波 1 拍 ③ 後本清單定稿）:
- [ ] **User 刀**（讀 3 端＋CRUD＋join `sys_user_role`;rev2 016*+017;若③=A 已於波 1 交付、本列改註）
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

### 持續性維護

- [ ] upstream rebase（定期 `git rebase upstream/example`〔base-web〕＋docs 源倉 `upstream/main`;CLAUDE.md §4.6;⚠️s fork-delta 紀律＋zdiff3/rerere 已配套）
- [ ] graphify 圖譜更新——**2026-06-13 增量：002 Rust 碼（migration ×4＋sea-orm-adapter crate）＋docker-compose.yml 外科式併入（4274 nodes/581 communities、base-web/docs 零損失）**；⚠️ 標準 `graphify update`（build_merge）的全域 fuzzy-label dedup 會誤併 distinct 節點（本輪實測損 143 個 base-web/docs 真節點）、故改外科式增量；deploy/（compose override/nginx/Dockerfile）＋tests `.sh`/`.sql` 非 graphify 可索引型別、未入圖；**003 envelope.rs/error.rs＋004（entity crate 4 檔／server model：soft_delete＋facade ×4＋live_smoke／tests entity_access_lint.rs）＋005（entity `sys_operation_log.rs`／server `model/audit.rs`＋`facade/sys_operation_log.rs`＋`facade/sys_user.rs` 寫側＋`facade/live_smoke.rs` audit 場景）待外科式併入**；大改後再 update（見 [[graphify-update-fuzzy-dedup]]）

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
- [ ] builder `cargo build` 補 `--locked`（守 lock pin 防線、防 manifest 漂移靜默 re-resolve）——**005 Unit A 實證**：Cargo.lock 曾遺漏 sea-orm optional-dep package stanza（`bigdecimal` 等、003/004 遺留），加 `with-json` 首次非 `--offline` build 觸 re-resolve、把 `time` 拉到 0.3.47〔off 文件 pin〕；`--locked` 會 fail-loud 擋下此類靜默 re-resolve（配套見 §3.8 MSRV 條）
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
- [x] ✅（2026-06-14、005 Unit A）workspace Cargo.toml time pin 註解勘誤——005 加 with-json 首次非 --offline build 補齊 lock 時 time 解析為 0.3.47（feature-gated 未編譯、user 拍板接受）、順手把「pin time=0.3.37」改為「home=0.5.9 pin；time 不入 compile graph、版本對 1.86 build 無影響、不變式＝不啟用拉 time 的 feature」
- [ ] rust-api/.gitignore `debug`/`target` 未錨定 pattern（誤吞同名子目錄風險）
**拍板/上游**:
- [ ] JWT `_FILE` vs 直值 env 優先序（dev 兩者並存;Auth 刀消費時拍板）
- [ ] prod builder node:20.19 vs dev node:26 分歧（沿 rev2 驗證形;Dockerfile 補註記或 DECISIONS 開放項）
- [ ] cargo cache 卷遮蓋陳舊（dev image 升 toolchain 時需手動 `volume rm`;quickstart 註記）
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
- [ ] `AppError` 的 `From<…>` 轉換 impl（供 handler `Result<Res<T>,AppError>` 用 `?` 傳播 DbErr/casbin 等 foreign error）——本刀無 error source、YAGNI 未加;首個需傳播外部錯誤的 handler 刀按需加
- [ ] ⚠️r id 序列化 2^53 fail-loud 守衛＋lie ledger → 首個 DTO 刀（本刀 `data:T` generic、無具體 DTO 可守）
- [ ] **CDP browser smoke 補測**（research R5 明文 directed）:首個發出 envelope 的 handler 刀必含 CDP 經 front-nginx 驗 base-web 攔截器真讀 `code`/`data`/`msg`——**curl 直送 ≠ base-web modal/success 判讀對齊**;本刀純型別、無 endpoint 可 smoke、整條 runtime 消費鏈未驗
**dead_code（infra ahead of consumers、實作期觀察）**:
- [ ] envelope/error 公開 API（`Res`/`PageRes`/4 建構子・`BizCode`・`AppError` 8 建構子）目前全 dead_code（非測試零消費、`cargo build` 數條 warning、**無 `-D warnings` gate 故不阻塞 prod build**）;消費刀 wiring 後漸清（Res/AppError→Auth/data island、7777/8888/3333→behavior island 波3）;**wiring 後仍殘留 dead_code 的建構子＝無真實消費者、回頭檢視是否 over-built**

### 3.7 004-soft-delete-infra follow-up（收刀移交 2026-06-14;均不阻塞、消費刀觸發時處理）

**dead_code（infra ahead of consumers、實作期觀察）**:
- [ ] facade 讀 fn（`find_active_by_name`/`find_active_by_id`/`find_active_by_ids`/`find_role_ids_by_user_id`）＋`find_active`＋`SoftDeletable` trait/impl 全 dead_code（server bin crate、無真實消費者、`cargo build` 數條 warning、無 `-D warnings` 不阻塞）;Auth 島 getUserInfo 讀 cluster 組裝消費後漸清;**wiring 後仍殘留＝無真實消費者、回頭檢視 over-built**（同 §3.6 紀律）。entity crate `Model` 為 lib API、不受此 warning
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
- [ ] `audit_active_model` 的 `operator_ip` 目前 None→NotSet（本刀 operator.ip 恆 None）;`Some(ip)=>Set(Some(ip))` 分支為前向形狀、**若被觸發會 PG 42804（text→INET 隱式轉型失敗）**——真實 INET 寫入留第二 audit 刀（`audit_ctx` 中介層帶 operator_ip 時）、需 `Expr` cast 或 `ipnetwork` custom type 才可寫實值
**payload_after 形狀（消費刀填）**:
- [ ] soft_delete 的 `payload_after` 恆 `None`（軟刪只 before 快照）;Insert/Update 操作別的消費刀（User/Role/Menu 等寫端）填 after 快照時、各自 facade 在 `mutate_in_txn` 閉包內構造
**实机 smoke 隔離（Unit D code review 觀察、未來 live-smoke 刀沿用）**:
- [ ] `live_smoke.rs` 的 3 audit 場景用拋棄式 user（9xxxxx）＋`hard_clean`（前後）隔離、**非 panic-safe**（assert 中途 panic 會留 DB 殘留、靠下次 run 的防禦性 pre-clean 自癒、永不污染 m002 seed——與 004 read-cluster smoke 的 bracketed-restore〔因觸 seed〕策略不同、各自合理）;commit/no-op 兩場景共用 id 900001、依賴 contract §4 強制的 `--test-threads=1`（序列跑）
**Cargo.lock 完整性＋未來 sea-orm feature 的 MSRV 地雷（Unit A 發現）**:
- [ ] 005 補齊 003/004 遺留的 16 筆 sea-orm optional-dep lock stanza（`bigdecimal`／`time` 0.3.47／`rust_decimal`／`uuid`／`pgvector`／`mac_address` 等、**全 feature-gated 未編譯**、user 拍板接受、time=0.3.47＝resolver 取最新）;⚠️ 這些 crate **以「最新版」躺在 lock、從未在 1.86 編譯過**——**未來任何刀啟用會拉它們的 sea-orm feature（`with-uuid`／`with-rust_decimal`／`with-bigdecimal`／`with-time` 等）、或為第二 audit 刀真實 INET 寫入加 `ipnetwork` 時，務必先驗該鎖定版 MSRV ≤ 1.86**（workspace 註解原憂「time/home 新 patch 需 1.88」、time 0.3.47 恐即是）;超標就 `cargo update -p <crate> --precise <1.86-safe 版>` 釘回。配套見 §3.4 `--locked` 條＋memory [[sea-orm-entity-datetime-feature-gate]]／[[inert-drift-accept-and-correct-doc]]

---

## 4. 跨 feature 待驗證項

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 18**:①flat-in-main 沿用｜② C+ typings-as-oracle｜④僅 join 表加 FK｜⑤凍結邊界=archetype+行為島+碼表入憲｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️d redis tag 建時 pin 數字版｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️g 受控參照 rev2 source｜⚠️i MODAL-WIRING 五用途全授+BUILD-CONFIG 不收錄｜⚠️j rust-api 沿倉換分支｜⚠️k migration 短編號 mNNN_<name>｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings｜⚠️s fork-delta 雙模式(原行註解保留+rev3-inline 標記)｜⚠️t schema 波 0 一次全建(rev2 終態 squash 基線+delta 顯式分離;seed 口徑 92 列/6 表勘誤 2026-06-13)｜⚠️v casbin_rule 委派式建表+adapter 併入 002(sub-crate 刀消解)

**開放 13**(依最晚決策點分組):
- 波 1~3:③第一刀位(波1開工前)｜⚠️a 效能數字(波1驗收前)｜⚠️o RI 下沉(波1 facade 設計時)｜⚠️b 審計讀端(波2排程前)｜⚠️m alt-login 入波(波3排程前)
- 不阻塞/觸發時:⑥a-d 新能力包｜⚠️h 排程重議｜⚠️l settings 多 key｜⚠️n log retention｜⚠️u §IV 增第 10 題(amendment 提案,PATCH)

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
