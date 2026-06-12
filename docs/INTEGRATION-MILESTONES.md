# rev3 commit 里程碑永久紀錄（INTEGRATION-MILESTONES）

> **append-only、不在 SOP hook 注入**（避免 CHECKLIST 膨脹）。兩區：
> 「§1 commit 里程碑表」收每筆 docs／feature commit 一行（表尾 append）；
> 「§2 ✅ 完成＋歸檔」收 CHECKLIST「Follow-up Backlog」批次搬來的已完成 follow-up 細節。
> 歸檔流程見 [CLAUDE.md §7.5](../CLAUDE.md)；波次 as-built 帳在 [DECISIONS §2](INTEGRATION-DECISIONS.md)（職責不同：彼為波次狀態、此為 commit 流水）。

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

## §2 ✅ 完成＋歸檔

（CHECKLIST「Follow-up Backlog」完成節累積數節後批次搬入；目前空。）
