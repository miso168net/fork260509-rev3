# rev3 commit 里程碑永久紀錄（INTEGRATION-MILESTONES）

> **append-only、不在 SOP hook 注入**（避免 CHECKLIST 膨脹）。三區、§2/§3 與 CHECKLIST 同號區鏡像對應：
> 「§1 commit 里程碑表」收每筆 docs／feature commit 一行（表尾 append）；
> 「§2」收 CHECKLIST §2 完成波的收縮節（✅ 標題＋blockquote 摘要;批次搬入後 CHECKLIST 永遠聚焦當前波）；
> 「§3」收 CHECKLIST §3 已完成 follow-up 節的細節（批次搬入）。
> 歸檔流程見 [CLAUDE.md §7.5](../CLAUDE.md)。**與 [DECISIONS §2](INTEGRATION-DECISIONS.md) 的分工**：波次 as-built **詳帳**在 DECISIONS §2（權威）；本檔 §2 只收 CHECKLIST 的一行式快照歸檔，查波次細節一律去 DECISIONS。

---

## §1 commit 里程碑表

| commit | 日期 | 主題 |
|---|---|---|
| `f8e0728` | 2026-06-11 | Spec-Kit presets / extensions / skills 落地 |
| `f6c4939` | 2026-06-11 | .gitignore 補強 — 排除 Claude 憑證與 fork 子專案 |
| `e006b7c` | 2026-06-11 | CLAUDE.md 從 rev2 改寫為 rev3（身分／⏳ 目標態／port 3XXXX） |
| `8ebce10` | 2026-06-11 | CLAUDE.md 微調 — pre-hook 檔名、§7 跨檔引用改語意錨 |
| `2ec9cda` | 2026-06-11 | 註冊 base-web/rust-api 為 submodule（worktree+submodule 雙重身分落地） |
| `0713db4` | 2026-06-12 | CLAUDE.md 拔除 worktree/submodule 已落地 ⏳ |
| `03a1b01` | 2026-06-12 | bump base-web 到 dd771540 — x_fork.branch-origin.md 分支來源紀錄 |
| `fb87a67` | 2026-06-12 | bump rust-api 到 f73ef10 — x_fork.branch-origin.md 分支來源紀錄 |
| `7fd1ac6` | 2026-06-12 | 設計權威 INTEGRATION-DESIGN-rev3.md 入 docs/ |
| `88f9011` | 2026-06-12 | DESIGN 拍板回填 — 官方權威序＋六項拍板＋對賬修補 |
| `8f66fe0` | 2026-06-12 | graphify rev3 首次建圖（2060 nodes／311 communities／83.7x） |
| `46591c4` | 2026-06-12 | 000：保存 base-web/apifox mock API 捕獲原始資料 |
| `309099d` | 2026-06-12 | base-web standalone dev compose |
| `aea0e18` | 2026-06-12 | 000：補抓 mock 缺口端點＋CDP scripts git-track |
| `e898421` | 2026-06-12 | 000：13 端點對映表＋設計書比對文件落地 |
| `4aa7c89` | 2026-06-12 | INTEGRATION-DESIGN-rev3.md 歸位改名 INTEGRATION-DESIGN.md |
| `4724549` | 2026-06-12 | C 方案落地 — DESIGN 凍結藍圖＋INTEGRATION-DECISIONS.md 伴生活帳 |
| `4300b54` | 2026-06-12 | CHECKLIST/MILESTONES 落地 — 注入活檔成形、波 -1 文件層收齊 |
| `9d8303f` | 2026-06-12 | 外檔引用全面查驗修正 — ⏳ 同步現實＋DESIGN amendment 動線勘誤 |
| `e8e1a99` | 2026-06-12 | §7.1 改定 — rev2 研究三檔不移植不重作 |
| `ed2a789` | 2026-06-12 | SessionStart hook 落地 — 自 rev2 原樣承接（零改動） |
| `71cdd61` | 2026-06-12 | §7.5 歸檔 — MILESTONES append＋CHECKLIST 進展滾動 |
| `4ec9cc6` | 2026-06-12 | MILESTONES 三區化收整 — user 鏡像設計補一致性 |
| `612ddcd` | 2026-06-12 | 波 -1 constitution 重鑄項加 §V.2 提案位置搬家註記 |
| `167db96` | 2026-06-12 | **constitution-rev3 v1.0.0 凍結** — 13 項拍板融入（含 ⚠️s fork-delta 紀律）；波 -1 出口四項全綠、**波 -1 全完成** |
| `c9ffad5` | 2026-06-13 | **001-infra-deploy 全綠收刀（波 0 第一刀）** — master compose 5 service＋migrate gate＋dev/prod override＋deploy/ 全套＋rust-api scaffold（worktree `5d69c06`）；C-V-0~8 實機全綠（SC-001~007）、捕獲 redis `--dir` 持久化真 bug 並修；merge --no-ff、feature branch 保留 |
| `9233ae0` | 2026-06-13 | **002-rev2-schema-baseline 全綠收刀（波 0 第二刀）** — 前代 35 支 migration squash 為 4 支基線（m001 schema 11 表終態〔10 手寫＋casbin 委派 vendored adapter＋ALTER 治理欄〕／m002 seed 92 列 6 表〔argon2id 單一 hash〕／m003 user_role FK ×2 RESTRICT／m004 demo 選單 66＋policy 全 R_SUPER）＋sea-orm-adapter 整檔拷入（§I.5、worktree `91cfc80`）；tests/002 四支驗證 scripts（normalize 六規則）＋2 基準檔；C-V-0~9 實機全綠（SC-001~008）、修 m002 兩層 seed drift（id 順序 bug＋normalize 第六規則 row-order 正規化〔user 拍板方案 A、契約留痕 migration-chain.md §3〕）；merge --no-ff、feature branch 保留 |
| `7269e67` | 2026-06-16 | **constitution v1.0.0→v1.1.0 amend**（⚠️aa、§V.3 MINOR） — §III 新增 `BASE-WEB-I18N-WIRING ★` 軌道；觸發＝003-envelope `/speckit-plan` Constitution Check Q2/Q7（base-web i18n 接線必改 inline：`service/request` 攔截器／`locales` backend 命名空間／`app.d.ts` Schema；⚠️y 已授權改動本身、但 §I.1 需 §III 軌道才合規）；授權三範圍 (i) 攔截器 msg 翻譯接線〔不改控制流〕(ii) locales backend 命名空間 (iii) app.d.ts Schema backend 型＋helper；走 fork-delta `rev3-inline`；user 親決 A |

---

## §2 Roadmap & Phase 狀態 — 完成＋歸檔

>（收 [CHECKLIST §2](INTEGRATION-CHECKLIST.md) 完成波的快照收縮行，累積數波後批次搬入；as-built 詳帳在 DECISIONS §2、此處只存一行式快照。目前空。）

---

## §3 Follow-up Backlog — 完成＋歸檔

>（收 [CHECKLIST §3](INTEGRATION-CHECKLIST.md) 已完成 `### 3.X` follow-up 節，累積數節後批次搬入、原處留收合指標。目前空。）

