# rev3 整合決策與實施帳（INTEGRATION-DECISIONS）

> 本檔 = [`INTEGRATION-DESIGN.md`](INTEGRATION-DESIGN.md)（凍結藍圖）的**伴生活帳**：藍圖只被引用，所有「會動的」都記這裡。
> - **§1 決策紀錄表** — 全書待決／拍板唯一清單（原 DESIGN 附錄 G 整表遷入 @ 2026-06-12）
> - **§2 實施階段** — 波次執行 as-built 帳（計畫的設計在 DESIGN §8.4、執行的帳在此；rev2 DESIGN §10 的外移對應物）
>
> **優先序**：本檔 §1 > DESIGN 本文 — 衝突時以本檔為準；DESIGN 本文的「待決N／⚠️x」字樣以本檔現況為準。
> **分工**：CHECKLIST（hook 注入）持「當前波快照＋拍板項一行索引」；MILESTONES 收 commit 里程碑流水；完整職責分工見 CLAUDE.md §7。
> **本檔不被 hook 注入**——會長無妨（表格帳本性質，與 MILESTONES 同類）。

---

## §1 決策紀錄表（全書唯一清單；user 親決前不入凍結集）

> **編輯紀律**：新增 ⚠️／待決必登本表；拍板後該列改「✅ 已決（日期）＋結論全文」，**不回填 DESIGN 本文**（DESIGN 重鑄時批次摺合、版本 +0.1、該列補標「已併入 vX.Y」）；DESIGN 勘誤不經本表、直接最小 patch。「最晚決策點」= 再不決就 block 哪一步；「所在章」指 DESIGN 章節。文中「待決⑥」泛指 ⑥a~⑥d 四子項。

| # | 決策點 | 工程預設 ⚠️ | 所在章 | 最晚決策點 |
|---|---|---|---|---|
| 待決① | router 結構：維持 flat-in-main 還是重整 `router/` 樹 | 無強預設（as-built = flat + endpoint_coverage_lint 三源一致 @ 35，運作良好） | §1.5・§8.1 | 波 0 scaffold 前 |
| 待決② | wire contract 機器化（OpenAPI／contract test／維持 grep） | ✅ 已決(2026-06-12)：**C+ typings-as-oracle** — typings 抽 JSON Schema 當裁判（唯讀、不動官方檔）＋ coverage gate（router 每條 route 必有 contract case、缺＝CI 紅）＋ 碼表 table-driven（§7.3）＋ CDP capture 降為補充回歸 fixture ＋ lie ledger（顯式覆寫帳本、初始空）；B 案留「endpoint 增速再評」 | §7.2 | ✅ 已決 |
| 待決③ | 縱切第一刀：User 直刀 vs `system_settings` 打樣 | 傾向 A（User 直刀） | §8.3 | 波 1 開工前 |
| 待決④ | 選擇性 FK | join 表（`sys_user_role`）加 FK、其餘維持零 | §3.1 | 第一條 migration 前（波 0） |
| 待決⑤ | §3/§5 凍結邊界：哪些進 constitution、哪些留設計書 | archetype（§3.2）+ 行為島 invariants（§4）+ wire 碼表（§5.4/§7.3）入凍結；欄級字典與常數值留設計書 | §3・§9 章首注 | constitution-rev3 重鑄前（**波 -1**） |
| 待決⑥a | user-facing 儀表板 | rev3 v1 = 固定儀表板、0 新表（§2 表 #1） | §2 | 入波排程時（不 block 波 0-3） |
| 待決⑥b | 報表匯出 PDF/CSV | rev3 v1 = 同步匯出、0 新表（§2 表 #2） | §2 | 同 ⑥a |
| 待決⑥c | AES-256 靜態加密 | rev3 v1 = 磁碟/tablespace 層（§2 表 #3） | §2 | prod 部署定稿前（加密卷屬部署期決策） |
| 待決⑥d | 合規姿態升級 | 維持現姿態（§2 表 #4） | §2 | 對外／多租戶觸發時 |
| ⚠️a | 效能／可用性數字 | p95 300/500ms/1s；99.5%/月 | §1.3 | 波 1 驗收前 |
| ⚠️b | 審計查詢讀端 + UI 補做 | 補（Super-only；矩陣已預標 ⚠️） | §1.2・§5.0 | 波 2 排程前 |
| ⚠️c | `/auth/error` | ✅ 已決(2026-06-12)：**翻案 — 做**（echo 端點）。配套完整包：`alova/request`＋`alova/scenes`＋`function/request` 三 demo 頁進 sys_menu seed（初始僅勾 R_SUPER、下放交 ROLE 勾選層）；端點補 `/auth/error`＋`sendCaptcha`/`verifyCaptcha`（stub 雙模、⚠️m captcha 依賴就此解決）＋`/mock/getLastTime`（回 `{time}`）；§1.4 兩條「不做」同步翻案 | §1.4・§6.1 | ✅ 已決 |
| ⚠️d | redis-stack image tag | 建 stack 當下即 pin 數字版 | §1.6 | 波 0 compose 定稿前 |
| ⚠️e | `5000` 的 HTTP status 配對 | ✅ 已決(2026-06-12)：**一律 HTTP 200 信封**（對齊前端 msg 顯示通道僅 200 生效＋「business error 走 200」總則）；`AppError::Internal`→HTTP 500 mapping 標 test-only 或刪除；contract test 鎖 `5000`→200 | §5.4・§7.3 | ✅ 已決 |
| ⚠️f | 13 碼矩陣整組凍結（含 4 保留碼） | ✅ 已決(2026-06-12)：**整組凍結**（保留碼是前端 `.env` 分組實值、刪碼違 §I.1）；contract test 斷言「後端從不發出 7778/8889/9998/9999」 | §7.3 | ✅ 已決 |
| ⚠️g | constitution 重鑄措辭（§I.5 `axum-casbin`＋§9.6 Q5 rev1 指涉） | `axum-casbin` 重鑄為「enforce 層全新寫（in-tree）」；Q5 改寫為對 rev2 source 的隔離／參照立場（user 親決） | §9.2・§9.6 | constitution-rev3 重鑄時（波 -1） |
| ⚠️h | 排程性拍板重議（§9.3 表之拍板 §11.2/§11.8/§11.13） | 重議走 amendment、不默改 | §9.3 | 重議觸發時 |
| ⚠️i | L4 授權模式 | 沿用「窄邊界 + 逐次擴邊」 | §9.5 | constitution-rev3 重鑄時（波 -1） |
| ⚠️j | rust-api 源倉 | ✅ 已決(2026-06-12)：**沿用倉、換分支**——`fork260509-rev2-anew-rust-api` 倉名（含 rev2）為永久名保留、分支改 `rev3-admin-rust-api`（已落地） | 附錄 A | ✅ 已決 |
| ⚠️k | migration 檔名 | 改短編號（`mNNN_<name>`） | 附錄 C | 第一條 migration 前（波 0） |
| ⚠️l | settings 多 key 熱讀 | 需要時把單鍵 swap 推廣為 keyed map（設計變更、非預設） | §5.6 | 不阻塞（需要時） |
| ⚠️m | §1.2 尾巴（alt-login stub 4 + captcha 2）入波或重議 | 入波（§8.2 待拍板刀位）；重議則走 §9.5 amendment。**註(2026-06-12)**：captcha 2 端點已隨 ⚠️c 完整包拍定（stub 雙模、alova/scenes 需要）— 本項殘餘範圍縮為 alt-login 4 流程 stub 的入波排程 | §1.2・§8.2 | 波 3 排程前 |
| ⚠️n | 三 log 表 DB retention 政策 | rev3 v1 僅容量監控、retention defer | §1.3・§10.5 | 不阻塞（容量警示觸發時） |
| ⚠️o | application-RI 驗證下沉 facade 層 | 維持 rev2 handler 層驗；下沉屬設計變更須明示 | §3.3 | 波 1 facade 設計時 |
| ⚠️p | demo menu 隱藏機制 | ✅ 已決(2026-06-12)：**翻案 — 全部 demo 頁進 sys_menu seed、初始僅勾給 R_SUPER**；「隱藏機制」議題消解（hideInMenu／pageExcludePatterns 皆不啟用），可見性全交 ROLE 勾選層（casbin menu 維度）治理下放。推翻 rev2 §11.5 的隱藏取向（constitution-rev3 重鑄時同步改寫、⚠️g 同梱）。配套盤點 **✅ 完成（2026-06-12）**：API 依賴者共 4 頁＝⚠️c 完整包三頁＋`plugin/excel`（用既有官方端點 `getUserList`、零新端點）；其餘 demo 頁純前端；`demoRequest` 線路 vanilla 閒置。詳 §6.1 表 | §6.1 | ✅ 已決 |
| ⚠️q | worktree 內容起點（base-web／rust-api 帶不帶 rev2 程式碼） | ✅ 已決(2026-06-12)：base-web=**clean-slate 血緣**（自 `example` 衍生、已落地）＋**整批移植** `rev2-admin-base-web` 完成接線＋rev2→rev3 改名（附錄 A.2）；rust-api 依 §8 波次**從零重寫**（已落地、`main`@Initial commit） | §8.4 波 -1・附錄 A | ✅ 已決 |
| ⚠️r | id 序列化策略（rev2「id 全字串」凍結存廢） | ✅ 已決(2026-06-12)：**廢除字串凍結 — 逐欄位忠實 typings**。DB 一律 i64 自增（BIGSERIAL）；僅在 rust-api **序列化邊界**對 typings 宣告 string 的欄位轉換（`MenuRoute.id`・`userId`）；其餘（`CommonRecord.id`/`parentId`/`MenuTree.id/pId`/`Role.id`、write payload `ids`）回 JSON number；serializer 加 2^53 fail-loud 守衛。**推翻 rev2 constitution §I.3／§11.10 的 string 拍板**（刻意偏離、constitution-rev3 重鑄時與 ⚠️g 同梱處理）；rev2 025-I1 類 type-lie 自此根除、lie ledger 初始為空 | §7.2・§9.2・§9.3 | ✅ 已決 |

---

## §2 實施階段（rev3 波次 as-built 帳）

> 骨架衍生自 DESIGN §8.4 交付波次（波次定義／出口條件在彼、執行紀錄在此）。
> **回填紀律**：波／Phase 完成後，as-built（feature 清單＋merge SHA＋日期）回填本節對應波；CHECKLIST「Roadmap & Phase 狀態」該波收縮為一行指本節。本節**永久留此、DESIGN 重鑄不摺**（執行帳不屬於藍圖 — rev2 §10 的 65 次補丁教訓）。

### 波 -1 — repo 建構（進行中）

- ✅ outer repo＋worktree/submodule 註冊（`2ec9cda`；⚠️j／⚠️q 拍板已落地）
- ✅ CLAUDE.md-rev3／.gitignore 家族／.specify spec-kit 殼
- ✅ 設計書入 docs/（`7fd1ac6`）＋拍板回填（`88f9011`）＋歸位改名 INTEGRATION-DESIGN.md（`4aa7c89`）
- ✅ graphify 首次建圖（`8f66fe0`，2060 nodes/311 communities）
- ✅ base-web standalone 容器化＋mock wire ground truth 捕獲與對映（000：`46591c4`/`309099d`/`aea0e18`/`e898421`）
- ⏳ SessionStart hook（`.claude/settings.json`＋`hook-git-submodule-SOP.sh`）
- ⏳ constitution-rev3 重鑄凍結 v1.0.0
- 出口條件：DESIGN §8.4 波 -1 列

### 波 0 — 地基（未開始）

### 波 1 — 第一刀（未開始；刀位待決③）

### 波 2 — data islands（未開始）

### 波 3 — 行為島＋policy（未開始）

### 波 4 — observability（未開始）
