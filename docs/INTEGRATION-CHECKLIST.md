# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 -1 ✅ 全完成（2026-06-12）→ 波 0 地基 待啟動**（as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-12 constitution-rev3 v1.0.0 凍結＋波 -1 收口**:13 項拍板融入（含 ⚠️s fork-delta 紀律）、出口四項全綠（`167db96`,未 push）
- **2026-06-12 波 -1 文件層全收齊＋hook 落地**:CHECKLIST/MILESTONES 落地＋外檔引用查驗＋§7.1 改定＋SessionStart hook 原樣承接（`4300b54`~`ed2a789`,未 push）

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **001-infra-deploy 刀 → user 手動 `/speckit-specify`**（input=docs/superpowers/001-infra-deploy.md;brainstorm ✅ 五項拍板＋⚠️t schema 交付模型;波 0 前置拍板 4 項已全決）

---

## 2. Roadmap & Phase 狀態

對齊 CLAUDE.md §3 SDD-TDD 工作流 + [DESIGN §8.4 交付波次](INTEGRATION-DESIGN.md)（波次定義/出口條件在彼）。本節為動態 status 追蹤;完成波 as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);完成波摘要累積數波後批次搬 [MILESTONES §2](INTEGRATION-MILESTONES.md)、本節永遠聚焦當前波。

### 波 -1 — repo 建構 ✅ 全完成+已歸檔 (2026-06-12)

> 機械建構＋constitution 重鑄兩段全交（pre-spec-kit、全落 default branch、無 feature branch）:outer repo＋worktree/submodule 註冊 `2ec9cda`（⚠️j/⚠️q）/ 設計書入檔＋拍板回填＋歸位改名 `7fd1ac6`→`4aa7c89` / C 方案文件體系 DECISIONS+CHECKLIST+MILESTONES `4724549`・`4300b54` / graphify 首建 `8f66fe0` / 000 base-web bootstrap＋13 端點對映 `46591c4`~`e898421` / SessionStart hook 原樣承接 `ed2a789` / **constitution-rev3 v1.0.0 凍結 `167db96`**（13 項拍板融入）。出口四項全綠（session 健檢/獨立 commit/grep rev2 歸零/speckit 可用）。as-built 詳帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md);commit 史見 [MILESTONES §1](INTEGRATION-MILESTONES.md)。

### 波 0 — 地基（待啟動・當前）

infra/deploy＋envelope＋soft-delete 基建＋audit 兩刀＋Auth 島最小段 —（rev2 001-012＋015）對應、首個 spec-kit feature 起跑點。

**刀/feature 清單**（素材=DESIGN §8.2 跨切地基;刀界由各刀 brainstorm/specify 時定稿）:
- [ ] **001-infra-deploy 刀**（master compose 5 service＋deploy/ 裁剪帶入＋rust-api 最小 scaffold〔/health＋空 migrator〕＋migrate gate;rev2 001-007/010 對應;**brainstorm ✅ 2026-06-13**〔docs/superpowers/001-infra-deploy.md、五項拍板＋⚠️t〕→ 待 user 手動 /speckit-specify）
- [ ] **002-rev2-schema-baseline 刀**（⚠️t 拍板產物:m001_rev2_schema＋m002_rev2_seeds〔rev2 12 表/17 seed 終態 squash〕＋rev3 delta m003+〔④FK・⚠️p/⚠️c seed〕＋pg_dump 雙庫 diff 驗證閉環;001 之後緊接;開放點=casbin_rule 建表方式〔委派 adapter vs 直接 CREATE〕牽動 sub-crate 刀時序）
- [ ] **sub-crate 刀**（`sea-orm-adapter`＋`xdb` 自 rev2 拷貝＋casbin pin;rev2 012;§I.5 唯二拷貝例外）
- [ ] **envelope 刀**（`Res<T>{data,code,msg}`＋`BizCode` 13 碼矩陣＋`AppError`;rev2 008;⚠️e/⚠️f 拍板形）
- [ ] **soft-delete 基建刀**（`SoftDeletable` trait＋facade 唯一管道＋`entity_access_lint`;rev2 009）
- [ ] **audit 刀 ×2**（op-log〔rev2 011:`sys_operation_log`＋`mutate_in_txn`〕/ access-log＋login-attempt＋xdb〔rev2 015:兩表＋request-context〕）
- [ ] **Auth 島最小段**（login＋getUserInfo＋`enforce_mw` 最小鏈;rev2 013 對應;§8.3 兩案共同前提）

**前置拍板（user 親決,4 項;結論全文見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）**: ✅ 全拍完（2026-06-13）
- [x] ①router 結構 ✅ flat-in-main 沿用（lint 三源一致直接沿用）
- [x] ④選擇性 FK ✅ 僅 join 表 `sys_user_role` 加 FK、其餘 11 表維持零（義務照 §3.3）
- [x] ⚠️d redis-stack image tag ✅ 建 stack 當下即 pin 數字版
- [x] ⚠️k migration 檔名 ✅ 短編號 `mNNN_<name>`

**出口條件（DESIGN §8.4,4 項全綠才換波）**:
- [ ] dev stack `up --wait` 全 healthy
- [ ] 三守恆綠（entity_access_lint・endpoint_coverage_lint・migration up→down→up）
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
- [ ] graphify 圖譜更新（大改後 `graphify update`;最近一輪 2026-06-13、4176 nodes/567 communities）

---

## 3. Follow-up Backlog

### 3.1 000-base-web-docker-bootstrap follow-up

- [x] ✅（2026-06-13）`getUserList` CDP 瀏覽器流量補抓 → `tests/000-.../getuserlist-cdp-capture.json`（mock 版;rust-api 版由接線 feature CDP smoke 覆蓋）
- [ ] dynamic route mode 切換後重抓 `/route/*` 真實瀏覽器流量（對象屆時為 rust-api,詳 000 文件 §7）
- [x] ✅（2026-06-13）`cdp-nav/login/clear-and-relogin.mjs` 三支重測全通過（000 文件 §3.2,含 mock 限流 gotcha）
- [ ] standalone compose 與 CLAUDE.md §8.2 整套 stack 的整合/退場（master compose 落地時 service 遷移）

### 3.2 graphify follow-up

- [x] ✅（2026-06-13）`graphify update` — code 層 rebuild 完成（4176 nodes/4421 edges/567 communities）;**「docs 同步」前提不成立而關閉**:`.graphifyignore` 刻意排除 `docs/`（圖譜定位=code 圖,CLAUDE.md §8.3）,docs 從未入圖、無舊檔名殘留;`graphify-out/memory/` 的舊名屬歷史 Q&A 存檔不需改。docs 要不要入圖=另案（若要,先拔 `.graphifyignore` 的 `docs/` 行再 update;統計細節該記入 GRAPHIFY-NOTES ⏳）

### 3.3 fork-delta 工具 follow-up（⚠️s 衍生）

- [ ] `inline_coverage_lint` 候選:`grep -c rev3-inline` 對 spec 紀錄數,rebase 後驗足跡不丟失（rev2 endpoint_coverage_lint 同款思路;等 ⚠️q 移植 feature 一併評）
- [x] ✅（2026-06-13）git 配套設定:`merge.conflictStyle=zdiff3`＋`rerere.enabled=true` 已設於 base-web/docs 兩源倉（worktree 繼承已驗）

---

## 4. 跨 feature 待驗證項

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 17**:①flat-in-main 沿用｜② C+ typings-as-oracle｜④僅 join 表加 FK｜⑤凍結邊界=archetype+行為島+碼表入憲｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️d redis tag 建時 pin 數字版｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️g 受控參照 rev2 source｜⚠️i MODAL-WIRING 五用途全授+BUILD-CONFIG 不收錄｜⚠️j rust-api 沿倉換分支｜⚠️k migration 短編號 mNNN_<name>｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings｜⚠️s fork-delta 雙模式(原行註解保留+rev3-inline 標記)｜⚠️t schema 波 0 一次全建(rev2 終態 squash 基線+delta 顯式分離)

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
