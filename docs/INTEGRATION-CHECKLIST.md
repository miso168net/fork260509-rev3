# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 0 地基 進行中（001+002 ✅ 已收刀 2026-06-13、餘 4 項〔audit ×2 計 5 刀〕）**（波 -1 as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-13 002-rev2-schema-baseline 全綠收刀＋merge＋push**:C-V-0~9 實機全綠（SC-001~008）、前代 35 支 squash 為 4 支基線（m001 schema 11 表／m002 seed 92 列 6 表／m003 FK／m004 demo 66）＋sea-orm-adapter 拷入、修 m002 兩層 seed drift（id 順序 bug＋normalize 第六規則 row-order 正規化〔user 拍板方案 A〕）、merge `9233ae0` 回 rev3-admin-root;三 ref 已 push（rev3-admin-root/002 保留分支/rev3-admin-rust-api）
- **2026-06-13 001-infra-deploy 全綠收刀＋merge＋push**:T001~T021、C-V-0~8 實機全綠（SC-001~007）、抓 redis --dir 持久化真 bug 並修、merge `c9ffad5` 回 rev3-admin-root;三 ref 已 push（rev3-admin-root〔含波 -1 累積〕/001-infra-deploy 保留分支/rev3-admin-rust-api）

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **波 0 第三刀 → envelope 刀**（`Res<T>{data,code,msg}`＋`BizCode` 13 碼矩陣＋`AppError`;rev2 008;⚠️e/⚠️f 拍板形;待 brainstorm→手動 `/speckit-specify`）

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
- [ ] **envelope 刀**（`Res<T>{data,code,msg}`＋`BizCode` 13 碼矩陣＋`AppError`;rev2 008;⚠️e/⚠️f 拍板形）
- [ ] **soft-delete 基建刀**（`SoftDeletable` trait＋facade 唯一管道＋`entity_access_lint`;rev2 009）
- [ ] **audit 刀 ×2**（op-log〔rev2 011:`sys_operation_log`＋`mutate_in_txn`〕/ access-log＋login-attempt＋xdb〔rev2 015:兩表＋request-context;`xdb` sub-crate 隨本刀拷入——⚠️v 拍板、注意 Dockerfile [[bench]] COPY 坑〕）
- [ ] **Auth 島最小段**（login＋getUserInfo＋`enforce_mw` 最小鏈;rev2 013 對應;§8.3 兩案共同前提）

**前置拍板（user 親決,4 項;結論全文見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）**: ✅ 全拍完（2026-06-13）
- [x] ①router 結構 ✅ flat-in-main 沿用（lint 三源一致直接沿用）
- [x] ④選擇性 FK ✅ 僅 join 表 `sys_user_role` 加 FK、其餘 11 表維持零（義務照 §3.3）
- [x] ⚠️d redis-stack image tag ✅ 建 stack 當下即 pin 數字版
- [x] ⚠️k migration 檔名 ✅ 短編號 `mNNN_<name>`

**出口條件（DESIGN §8.4,4 項全綠才換波）**:
- [x] dev stack `up --wait` 全 healthy ✅（001、C-V-2 實證 2026-06-13）
- [ ] 三守恆綠（entity_access_lint・endpoint_coverage_lint〔皆後刀〕・**migration up→down→up ✅ 002 C-V-5 達成 2026-06-13**）
- [ ] envelope 13 碼 contract 形狀測試綠（⚠️e 拍板形）
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
- [ ] graphify 圖譜更新（大改後 `graphify update`;最近一輪 2026-06-13、4176 nodes/567 communities——**早於 001 收刀**,rust-api scaffold＋compose/deploy 新碼未入圖,001 後待一輪 update）

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
- [ ] workspace Cargo.toml time pin 註解勘誤（**002 已實證 time=0 不入圖〔R3 最小 features 集〕**;但註解半過時未改〔U1 surgical 保留〕、下次動 Cargo.toml 順手勘誤）
- [ ] rust-api/.gitignore `debug`/`target` 未錨定 pattern（誤吞同名子目錄風險）
**拍板/上游**:
- [ ] JWT `_FILE` vs 直值 env 優先序（dev 兩者並存;Auth 刀消費時拍板）
- [ ] prod builder node:20.19 vs dev node:26 分歧（沿 rev2 驗證形;Dockerfile 補註記或 DECISIONS 開放項）
- [ ] cargo cache 卷遮蓋陳舊（dev image 升 toolchain 時需手動 `volume rm`;quickstart 註記）
- [ ] 兩段式 commit pin 時點紀律提案:worktree commit 落地的**當個 task** 即 bump outer pin（001 全延到 T021、中繼 15 個 outer commit 的 pin 過期、checkout 不可重現 tasks 勾選聲明）→ 提案補進 CLAUDE.md §4.1（user 核可後改）
- [ ] **rev2 repo 回灌通知**:redis-stack `--dir /data` 持久化 bug 為 rev2 同形潛伏（rev2 `docker-compose.yml` redis command 同款缺 `--dir`）——rev2 維護時修

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
