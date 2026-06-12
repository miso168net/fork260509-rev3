# rev3 整合進度單一真相（INTEGRATION-CHECKLIST.md）

> 本檔由 `.claude/hook-git-submodule-SOP.sh` SessionStart hook 每次 session 開頭 cat 全檔注入,作為跨 session 的進度延續錨。
> **編輯紀律**:只更新狀態,不擴張內容;新發現的 follow-up 寫上去、處理完的勾掉(✅)或刪掉;不寫實作細節(留給 `specs/<NNN>-<feature-name>/`)。
> **處理完的去向**(四路分流,詳 [CLAUDE.md §7.5](../CLAUDE.md)):拍板→[DECISIONS §1](INTEGRATION-DECISIONS.md);波/Phase 完成→DECISIONS §2 + MILESTONES;feature/follow-up 完成→MILESTONES;DESIGN 勘誤→直接最小 patch DESIGN。**本檔永不膨脹、DESIGN 永不當狀態板。**
> **與 CLAUDE.md §6 分工**:當前 active feature 的 SPECKIT 快照在 CLAUDE.md §6 marker 區(spec-kit 將來自動同步用);本檔不重複那 4 行。

---

## 1. Current Focus

**階段**:**波 -1 — repo 建構（進行中）**（as-built 帳見 [DECISIONS §2](INTEGRATION-DECISIONS.md)）

**最新進展**(滾動最近 2 條;完整歷史見 [`docs/INTEGRATION-MILESTONES.md`](INTEGRATION-MILESTONES.md)):
- **2026-06-12 C 方案落地＋設計書歸位**:INTEGRATION-DESIGN.md 凍結藍圖＋INTEGRATION-DECISIONS.md 伴生活帳（附錄 G 27 條遷入）＋CLAUDE.md §7 紀律改版（`4724549`,已 push）
- **2026-06-12 000 base-web bootstrap 收口**:13 端點對映表＋CDP scripts＋mock raw 資料入 git（`46591c4`~`e898421`,已 push）

> 以下為預計`下一步` (不要合到`最新進展`)

**下一步**: **constitution-rev3 重鑄凍結 v1.0.0**（波 -1 最後一項;前置拍板:⑤凍結邊界／⚠️g 措辭／⚠️i L4 模式,見 §5 索引）

---

## 2. Roadmap & Phase 狀態

> 僅當前波快照;完成波收縮為一行指 [DECISIONS §2](INTEGRATION-DECISIONS.md)。波次定義與出口條件見 DESIGN §8.4。

- **波 -1 repo 建構（進行中）**:✅ worktree/submodule・設計書（歸位+C 方案）・graphify 建圖・000 bootstrap・CHECKLIST/MILESTONES 落地・SessionStart hook;⏳ constitution-rev3 重鑄 v1.0.0
- 波 0 地基 ～ 波 4 observability:未開始

---

## 3. Follow-up Backlog

### 3.1 000-base-web-docker-bootstrap follow-up

- [ ] `getUserList` 的 CDP 瀏覽器流量補抓（curl 直送 ≠ modal 對齊;等 dynamic 接線後 CDP smoke 一併,詳 000 文件 §7）
- [ ] dynamic route mode 切換後重抓 `/route/*` 真實瀏覽器流量（對象屆時為 rust-api,詳 000 文件 §7）
- [ ] `cdp-nav/login/clear-and-relogin.mjs` rev3 改 port 版未重測（下次用到先驗一輪）
- [ ] standalone compose 與 CLAUDE.md §8.2 整套 stack 的整合/退場（master compose 落地時 service 遷移）

### 3.2 graphify follow-up

- [ ] `graphify update`（INTEGRATION-DESIGN 改名＋docs 新四檔落地後,圖譜增量同步）

---

## 4. 跨 feature 待驗證項

---

## 5. 拍板項索引（常駐;結論全文與工程預設見 [DECISIONS §1](INTEGRATION-DECISIONS.md)）

**已決 8**:待決② C+ typings-as-oracle｜⚠️c /auth/error 翻案做＋demo 三頁完整包｜⚠️e 5000→HTTP 200 信封｜⚠️f 13 碼矩陣整組凍結｜⚠️j rust-api 沿倉換分支｜⚠️p demo 全進 sys_menu seed 僅勾 R_SUPER｜⚠️q clean-slate＋整批移植｜⚠️r id 逐欄位忠實 typings

**開放 19**(依最晚決策點分組):
- 波 -1 constitution 重鑄前:⑤凍結邊界｜⚠️g constitution 措辭｜⚠️i L4 授權模式
- 波 0 前:①router 結構｜④選擇性 FK｜⚠️d redis-stack tag｜⚠️k migration 檔名
- 波 1~3:③第一刀位｜⚠️a 效能數字｜⚠️o RI 下沉(波1)｜⚠️b 審計讀端(波2)｜⚠️m alt-login 入波(波3)
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
