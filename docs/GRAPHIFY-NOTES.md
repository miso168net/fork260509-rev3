# GRAPHIFY-NOTES — 圖譜現況統計 + 已知抽取限制

> **推論前必讀**（[CLAUDE.md](../CLAUDE.md) §8.3 點名）。用 `graphify query` / `explain` / `path` 推論前先讀本檔。
>
> **核心心法：「圖上沒有邊」≠「程式上沒有關係」。** graphify 以 AST（結構）＋ LLM subagent（語意）抽取、有明確盲點；把盲點當成「不存在」會推出錯誤結論。
>
> 本檔三實質區：**§1 當前統計**（每次 `graphify update` 後更新）／**§2 已知抽取限制**（盲點＋守則）／**§4 維護紀律**（外科式 `--update` 配方，從操作經驗提取進 repo、見 §7 紀律）。

---

## 1. 圖譜現況統計（2026-07-02、024/025 code 增量後）

| 指標 | 值 |
|---|---|
| 節點 | **3616** |
| 邊 | **4627** |
| 社群 | **520**（最大 99、中位數 4） |

**節點來源組成**：

| 來源 | 節點數 | 說明 |
|---|---|---|
| `base-web/` | 2502 | Vue 前端 worktree（AST + semantic subagent；**024/025：user-center 4 卡（含 password-card 誤傷補入 §2.9）/rev3-user-center wrapper·typings/system-settings 收尾/locales·app.d.ts 增量**、.vue 語意盲點限制見 §2.2） |
| `rust-api/` | 1091 | Rust 後端 worktree（**AST-only**、見 §2.3；018 obs／022 ipgate／023 sort 已入圖；**024/025：`password_policy` 模組（PasswordPolicy/PolicyViolation/from_settings/validate_*）＋m009＋`user_center` handler（get_profile/update_profile/change_password/get_password_policy/classify_operator）＋sys_user 2 窄寫 fn＋既有缺席補入 auth/password.rs·sys_token ×2（§2.9）**、`ip()`/`mutate_in_txn()` 為 god node） |
| `docker-compose.yml` | 23 | compose service 拓撲（018 obs 加 7 service＋4 卷＋1 secret，手刻入圖、profiles opt-in） |

> docs 源倉 `fork260509-soybean-admin-docs/`（~1856 noise 節點）已於 2026-06-24 prune 出圖並加入 `.graphifyignore`（見 §2.4）；圖現只含 base-web/rust-api worktree 真碼 + master compose。
> **2026-06-26 audit/019 code 增量**（外科式配方、見 §4）：14 個變更 code 檔重抽（8 rust audit/auth/enforce/facade + 6 base-web audit views/locales/app.d.ts），純 AST、**0 LLM token**；手動 prune 舊圖 14 變更檔 source 節點 → `dedup=False` 嫁接，3284→3311（+27）、成長閘 PASS；graph_diff 僅 37 new/10 removed（全真實 feature 符號）。★ **避開 fuzzy-dedup 陷阱**：照 skill 文件的 `build_merge(dedup=True)` 會把圖砍到 2610（誤刪 ~701 真節點、165 fuzzy）；外科式 `dedup=False` 才得正確 3311（見 §4）。community ID 重分群後置換、hand-label 以 membership-overlap 重對齊（非按 ID）。★ obsidian vault stale orphan note **已清**（2026-06-26：`find -name '*.md' -delete` + 重生 export → 3630 實檔、0 docs 孤兒；先前 ~3194 cruft 來自 2026-06-24 docs prune 未清、export 不刪舊檔）。
> **2026-06-29 020/021/022 code 增量**（外科式配方、見 §4）：39 個變更 code 檔重抽（rust auth/redis/ipgate/entity/facade/migration m007/handler/enforce + base-web ip-rule view·modules·service·typings·locales·app.d.ts·router），純 AST、**0 LLM token**；★ 再次踩到並避開 fuzzy-dedup 陷阱——skill 預設 `build_merge(dedup=True)` 砍到 **2782**（540 exact＋**171 fuzzy 誤併 distinct**），改 `dedup=False` 才得正確 **3499**（3311→+188：rust-api +138 ipgate/sys_ip_rule/m007/handler、base-web +50 ip-rule 管理頁）、成長閘 PASS。174「deleted」全＝docs 源倉舊 manifest 殘留〔圖內早無此節點、prune no-op〕、本輪 manifest 已校正消除。worktree rust-api `cb2767f`／base-web `aa2f57bc`；obsidian 重生 4001 note。
> **2026-07-01 023 code 增量**（外科式配方、見 §4）：28 個變更 code 檔重抽（10 rust：7 facade＋handler＋migration m008＋lib；18 base-web：composable/core/component/typings/locales/7 view），純 AST、**0 LLM token**；`dedup=False` 外科式併入、成長閘 PASS（3499→**3558**、**+59**：rust-api +42〔parse_sort_spec＋7×resolve_sort＋各純測＋m008〕、base-web +17〔useTableSort 純函式群＋SortClearButton＋WithSort＋types〕）；174「deleted」仍全＝docs 源倉舊 manifest 殘留〔圖內無節點、prune no-op、已知無害、再 save_manifest 仍顯示〕。worktree rust-api `2591efe`／base-web `78791b33`；obsidian 重生 4064 note。
> **2026-07-02 024/025 code 增量**（外科式配方、見 §4）：**23** 檔重抽＝17 變更（7 rust：user_center handler＋sys_user facade＋main/mod/system_settings/migration lib；10 base-web：user-center index+3 卡＋wrapper＋typings ×2＋locales ×2＋system-settings view）**＋6 個 sensitive 誤傷手動補入（★新盲點 §2.9：檔名含 password/token 被 detect 跳過**——password_policy.rs/m009/password-card.vue〔024/025 新檔〕＋auth/password.rs/sys_token ×2〔**建圖起即缺席**、本輪一併補入〕），純 AST、**0 LLM token**；先手動 prune 舊圖 23 檔 stale 節點（-132）→`dedup=False` 嫁接（+190）、成長閘 PASS（3558→**3616**、**+58**：rust-api +42〔password_policy 模組+m009+user_center handler+2 窄寫 fn+sys_token/password.rs 補入〕、base-web +16〔4 卡+wrapper+typings〕）；graph_diff 59 new/1 removed 全真實符號；174「deleted」仍＝docs 源倉殘留 no-op。worktree rust-api `ef1d21a`／base-web `f3ad8e23`；obsidian 重生 4136 note。

**file_type**：code 2854／document 693／concept 37／rationale 9／image 23（document 693＝base-web 內含 README/CHANGELOG/.github 等 `.md`、非 docs 源倉）
**edge confidence**：EXTRACTED 4560／INFERRED 67／AMBIGUOUS 0
**edge relation（top）**：contains 2899／calls 1000／imports 235／imports_from 195／references 122／method 77／re_exports 46／depends_on 23／conceptually_related_to 16／semantically_similar_to 7／implements 5／shares_data_with 1

> **★ 關鍵觀察**：98% 的邊是 EXTRACTED（AST 結構事實）、INFERRED 僅 2%、AMBIGUOUS 0。所以本圖的風險 **不是「畫錯邊」**（虛構關係極少）、**而是「漏畫邊」**（§2 盲點）。推論時主要防「圖沒抓到 ⇒ 誤判無關係」、而非防「圖亂連」。

---

## 2. 已知抽取限制（盲點）

### 2.1 ★ runtime 字串鍵耦合 — 圖完全看不到
pub/sub channel、redis key、event bus、動態 config key 這類**靠執行期字串配對**的耦合，**不產生任何邊**——它們不是 import 也不是 call，且字串字面值/`const` 不會成為節點（見 §2.5）。

**實證（2026-06-24）**：casbin 跨副本失效廣播 `reload_and_publish`（publisher）與 `spawn_policy_watcher`（subscriber）靠 redis channel `"casbin:policy:invalidate"` 耦合，但在圖上：

- 兩者**分屬不同社群**、**彼此零邊**（社群 ID 隨每次重分群變動、不列舉）；
- channel 常數 `CASBIN_INVALIDATE_CHANNEL` **根本不是節點**（`graphify explain` 回 "No node matching..."）。

→ 問「誰會因這個寫入被通知／重載」「事件 X 的訂閱者是誰」這類問題，**圖必漏**，直接 `grep` channel 字串兩端。同類受害：`settings:invalidate`、`revoked:user:{uid}` denylist key 等。

### 2.2 `.vue` SFC composition 盲點
`.vue` 不在 AST 抽取語言集，SFC 之間的 template↔import↔composable wiring AST 抓不全。週期性 semantic subagent pass（如 2026-06-24 對變更的 base-web 派 subagent）能補回**概念節點與部分 wire 邊**，但**非結構完備、亦非每次 update 都跑**（code-only 增量只走 AST、跳過 .vue 語意）。
→ 問 Vue SFC 之間 wiring（哪個 view 用哪個 component／composable）**直接讀 SFC**、別只信圖。

### 2.3 rust = AST-only：結構完整、概念邊稀疏
rust 後端走 AST（`calls`/`contains`/`imports` 完整），但**幾乎沒有 LLM semantic 概念邊**：實測 rust 涉入的 `semantically_similar_to`/`conceptually_related_to`/`shares_data_with` 概念邊僅 **1 條**（base-web 涉入 23 條；全圖 concept 邊共 24、2026-06-29）。
→ rust 的「結構」可信（誰呼叫誰、誰 import 誰），但「跨檔概念關聯／同類設計」圖上幾乎空白；要這類洞察須讀碼、或對 rust 另跑 semantic pass。

### 2.4 docs 源倉過度索引（噪音）— ✅ 已 prune（2026-06-24）
`fork260509-soybean-admin-docs/` 曾在 2026-06-12 原始建圖時被一併索引（1856 節點 ≈ 全圖 36%、多語 `nodejs.md`/`use-table.md`/`structure.md`/FAQ 各自成社群），與整合碼無關。**2026-06-24 已 prune 出圖**（外科式移除 1856 節點+牽連邊、5127→3271）並加入 `.graphifyignore`（永久不再索引）。
→ ⚠️ **校正**：god node `Changelog`（77 邊）/`更新日志`（24）**不是** docs 源倉、而是 **base-web 自己的 `CHANGELOG.md`**（worktree 真碼、prune 後仍居 god node 榜首）。它程式價值低但屬合法 worktree 內容、未 prune；若也想清，需另外針對 base-web `CHANGELOG.md` 處理。

### 2.5 `const`／字面值不成節點
AST 不把 `const`/字串字面值抽成節點（如 §2.1 的 `CASBIN_INVALIDATE_CHANNEL`）。靠常數耦合的關係因此**雙重隱形**（既無節點、又無邊）。

### 2.6 社群碎片化 + 標籤為 top-node 自動衍生
**506** 社群、中位數 **4** 節點、**207** 個 thin（<3）。標籤自 **2026-06-29 起全部由【該社群最高 degree 節點的 label】自動衍生**（top-node-derived，如 `system manage.rs`／`ipgate.rs`／`audit ctx.rs`；非手寫精準語意、**0** 個 `Community N` placeholder）。
→ 「社群」邊界**不等於**模組真實邊界；標籤僅供導覽（file-name-ish、非策展模組名）、別據以推論模組歸屬。

### 2.7 `calls` 邊 confidence 標記不一致（小坑）
同為 AST `calls` 邊，`explain` 有時標 `[EXTRACTED]` 有時 `[INFERRED]`（實測 `mutate_in_txn` 的 caller 多標 INFERRED、`reload_and_publish` 的 caller 標 EXTRACTED）。
→ 別據單一 `calls` 邊的 confidence 標記判斷其可靠度；邊存在即代表 AST 真的看到該呼叫。

### 2.8 ★ 跨模組 fully-qualified call 漏邊（facade caller 嚴重低估）
AST 解析得了 **unqualified call**（`use` import 後直呼 `f(...)`、`super::f(...)`、同模組）→ 成 `calls` 邊；但**寫成多段 qualified path 的跨模組呼叫**（`facade::sys_token::f(...)`、`crate::a::b::f(...)`）**常被丟邊**。rev3 handler 慣例正是用全路徑 `facade::sys_token::X(...)` 呼 facade（不逐一 import），所以 **facade fn 的 production caller 在圖上幾乎不存在**——in-degree 主要反映 in-crate `super::` 測試、而非真實呼叫者。

實證（2026-06-24，facade fn 的 call site vs 圖上 captured caller）：

| facade fn | production 呼叫寫法 | 圖上 captured caller |
|---|---|---|
| `find_by_hash_for_update` | `rotate_locked_or_revoke` 用 `facade::sys_token::…`（qualified） | 只有 toctou 測試（`super::`）、**缺 handler** |
| `mark_used` | `rotate_locked_or_revoke`（qualified） | **零 caller**（連測試都沒呼） |
| `revoke_chain` | `revoke_chain_and_logout`（qualified） | 只有 toctou 測試（`super::`）、**缺 handler** |
| `insert_token` | login + rotate ×2（皆 qualified） | 只有 toctou 測試（`super::`） |

對照：`mutate_in_txn` 被各 facade 以 **import 後 unqualified** 呼叫（`use crate::model::audit::mutate_in_txn`）→ **14** 條 caller 邊全抓到（`explain` degree 15＝14 `calls`＋1 `contains`；2026-06-29）。差別純在**呼叫寫法**（qualified vs unqualified）、不在關係真假。
→ 問「誰呼叫某 facade fn」「誰寫某 entity」「某 facade fn 的重要性（in-degree）」→ 圖會把你導向**測試**、漏掉 production handler；一律回 `grep` fn 名。此盲點與 §2.3（rust facade AST-only）疊加：facade 層 call graph 系統性偏向測試 caller。
→ **增量變體（2026-07-02 mutate_in_txn trace 實證）**：①**單檔增量抽取丟 cross-file 邊**——即使 unqualified＋有 `use` import（如 025 `update_own_profile` 呼 `mutate_in_txn`），callee 檔不在本輪抽取檔集時 import 對映斷鏈、邊被丟（實測 mutate_in_txn 圖上 14 caller vs grep 24 真 call site）；②**方法呼叫誤配同名 fn**——閉包內 `am.update(&txn)`（SeaORM ActiveModel method）被 AST 誤配成同檔 `update()` fn 的**假 calls 邊**。→ 被 prune 重抽的檔、其 fn 的 cross-file caller/callee 邊會靜默流失；橋節點（mutate_in_txn 等）的 in-degree 隨增量輪次**單調衰減**、必以 grep 為準。

### 2.9 ★ 檔名含 password/token 被 detect sensitive 過濾跳過（真碼誤傷）
graphify `detect`/`detect_incremental` 的 sensitive 過濾以**檔名 pattern** 判定、會把檔名含 `password`/`token` 的**真碼檔**當敏感檔跳過（與 `.env.*` 一同進 `skipped_sensitive`、不進 `new_files`）。實證（2026-07-02）：`auth/password_policy.rs`、`m009_seed_password_policy.rs`、`password-card.vue`（024/025 新檔）＋ `auth/password.rs`、`entity/sys_token.rs`、`facade/sys_token.rs`（**建圖起即缺席**、2026-07-02 已手動補入）。`extract()` 本身**不過濾**（直接餵 Path list 即可抽）。
→ **後果雙重**：①這些檔不在 manifest → 日後變更**永遠不會**自動出現在 `--update` 的 new_files；②不明就裡看圖會以為 password/token 相關碼不存在。**每次 `--update` 必查 `skipped_sensitive`、對其中真碼檔手動加進 extract 清單**（`.env.*` 等真敏感不補）；配方見 §4。

---

## 3. 推論安全守則（TL;DR）

1. **圖沒邊 ≠ 沒關係**：runtime 耦合（pub/sub、redis key、event）、`.vue` wiring、rust 概念關聯，圖會漏——這些一律回去 `grep`/讀碼。
2. **結構問題信圖、語意問題存疑**：「誰呼叫誰／誰 import 誰」（EXTRACTED）可信；「同類/相關/概念橋」在 rust 端幾乎空白。
3. **濾掉 docs 噪音**：god node / 社群分析自動排除 `fork260509-soybean-admin-docs/`。
4. **社群與標籤僅供導覽**：碎片化 + 標籤為 top-node 自動衍生（file-name-ish、非手寫語意），別當模組真相。
5. **想知道一個「橋節點」為何連兩群**：先看它是不是真 call-edge 橋（如 `mutate_in_txn`，圖有實邊、可信）；若兩端在圖上無邊卻你知道有關係（如 pub/sub），那是 §2.1 盲點、回去讀碼。
6. **facade 層 caller / in-degree 信不過**：rev3 用全路徑 `facade::X::fn(...)` 呼 facade、AST 漏邊 → facade fn 的 caller 在圖上多半只剩 `super::` 測試；問「誰呼叫／誰寫 entity／哪個 facade 重要」直接 grep fn 名（§2.8）。
7. **password/token 檔名檔曾系統性缺席**：2026-07-02 前圖上完全沒有 `auth/password.rs`/`sys_token` ×2（detect sensitive 誤傷、§2.9、已補入）；更早的分析結論若涉這些檔的「不存在／零 caller」判斷須重驗。

---

## 4. 維護紀律（外科式 `--update` 配方）

> 從操作經驗提取進 repo（CLAUDE.md §7「不引用本機 memory、重要者先提取進 repo 文件」）。圖只索引 `base-web`/`rust-api` worktree 整合碼；`docs/`、`specs/`、`deploy/`、`CLAUDE.md`、compose override 等在 `.graphifyignore` 外、不進圖。

- **增量分流**：code 變更走 AST（免 token、deterministic）；doc／`.vue` 語意變更才派 semantic subagent。
- **★ 必查 `skipped_sensitive`（§2.9）**：detect 以檔名 pattern 把 `password`/`token` 真碼檔當敏感跳過（不進 new_files、不進 manifest → 變更**永遠不會**自動偵測）；每輪 update 讀 `skipped_sensitive` 清單、真碼檔（`.rs`/`.vue`/`.ts`）手動 append 進 extract 檔案清單（`.env.*` 等真敏感不補）。現知常駐誤傷戶：`auth/password.rs`、`auth/password_policy.rs`、`m009_seed_password_policy.rs`、`password-card.vue`、`entity/sys_token.rs`、`facade/sys_token.rs`——**這些檔有變更時必手動補抽**。
- **⚠️ `build_merge` 預設 `dedup=True` 會跑全域 fuzzy-label dedup、誤併不同 ID 的 distinct 節點**（本 corpus 的 CHANGELOG 等大量同 label 結構化節點會誘發誤併、實證曾損真節點）。本 corpus **必用 `build_merge([new], graph_path=..., dedup=False, root=ROOT)` 外科式併入**（同 ID in-place 更新、不跨-label fuzzy 收合）。
- **`prune_sources` 只給 deleted 檔**：它在併入後對合併圖剔除該 source 的節點、把 changed 檔丟進去會連新節點一起殺。
- **成長安全閘**：merge 後比對節點數，**必須成長**；縮水＝疑 fuzzy/誤併損、停手不寫檔。
- **⚠️ graph.json 可能與 `manifest.json` 失同步**：2026-06-24 曾發現 rust 後端整批從 graph.json 消失（4176 節點裡 rust 僅 11、全來自 1 個 .md），manifest 卻仍宣稱已索引 44 個 rust 檔。**`--update` 前先驗 graph.json 實際覆蓋**（`grep` node `source_file` 頂層分佈）、別只信 manifest；發現某子樹整批缺席時，對該整棵子樹跑**全量** AST 補回（非只抽變更檔）。
