# rev3-admin (fork260509-rev3) Constitution

> 整合 rev3 設計凍結權威。內容自 [`docs/INTEGRATION-DESIGN.md`](../../docs/INTEGRATION-DESIGN.md) §9 凍結基盤（rev2 constitution v1.6.0 承接快照）重鑄，融入 [`docs/INTEGRATION-DECISIONS.md`](../../docs/INTEGRATION-DECISIONS.md) §1 已決拍板（待決②⑤／⚠️c/⚠️e/⚠️f/⚠️g/⚠️i/⚠️j/⚠️p/⚠️q/⚠️r），2026-06-12 凍結 v1.0.0。
> **本檔為凍結權威**：與 DESIGN／DECISIONS／CHECKLIST 衝突時以本檔為準；改動需經 Amendment 流程（見 §V Governance）。
> spec-kit `/speckit-plan` 步必須對照本檔做 Constitution Check（見 §IV）。

---

## I. Core Principles

### I.1 base-web 為權威（NON-NEGOTIABLE）

**規則**：base-web（**現行 `rev3-admin-base-web` 分支實碼**，含 ⚠️q 整批移植後的接線成果）有的功能、rust-api 都要提供對應 endpoint。設計範圍嚴格、不縮減。

**含義**：
- base-web 的 wire / type / endpoint / route shape，rust-api 必須對齊
- 「v1 從簡」只能是交付排程（DESIGN §8.4 波次）、不能簡化設計範圍
- 不動 base-web inline（例外見 §III 軌道授權；授權後的變動執行紀律——**原行註解保留／標記圈界**——見 §III fork-delta 紀律）
- upstream rebase 友善 — 不留 upstream 衝突風險高的改動；fork 差異全程 `rev3-inline` 標記可定位

**例外與升級路徑**：見 §III 軌道授權邊界（MODAL-WIRING ★）

### I.2 menu 權限 Casbin enforce（rev2 核心突破、rev3 沿用）

**規則**：menu 由 Casbin RBAC enforce、有權才顯示。

**含義**：
- 業務 menu 走 `/route/getUserRoutes` → 後端 Casbin enforce 過濾 → 前端顯示（機制本體 DESIGN §5.3、治理行為 §4.2）
- **demo menu 處理（⚠️p 拍板、推翻 rev2 隱藏取向）**：demo view **全部進 `sys_menu` seed、初始僅勾給 `R_SUPER`** — 全集完整、可見性由 ROLE 勾選層（menu-auth-modal → casbin menu 維度）治理下放；`hideInMenu`／`pageExcludePatterns` 隱藏機制**皆不啟用**（議題消解）
- constantRoutes（login / 404 / 403）前端寫死、與 menu 無關 → 不動

### I.3 wire 契約權威序與不變式（NON-NEGOTIABLE）

**權威序**（對賬裁決，取代 rev2「mock 為權威」）：
1. **base-web 實碼**（現行 `rev3-admin-base-web` 分支：`typings/api/*.d.ts`＋`service/api/*.ts`＋`.env`＋`views/**`）＝ wire **唯一權威**
2. 官方 docs 站 ＝ 解釋性文件，僅「紀律性約束」引為規範（如 refreshToken 不回 expiredTokenCodes、history mode 須 SPA fallback）
3. mock 實測 ＝ 補充回歸 fixture（驗 runtime 行為如 User→User01 alias），**不當 shape oracle**

**鎖定不變式**：
- envelope `{data, code, msg}`（無 `success` bool）；`code` = string `"0000"` not number；business error 走 **HTTP 200** 信封
- **id 序列化＝逐欄位忠實 typings（⚠️r 拍板、推翻 rev2「id 全字串」凍結）**：`Common.CommonRecord.id`／`Menu.parentId`／`MenuTree.id`/`pId`／`Role.id` 與 write payload `ids` → JSON **number**；`MenuRoute.id`／`UserInfo.userId` → **string**（typings 本就如此宣告）。DB 一律 i64 自增；轉換只發生在 rust-api **序列化邊界**；serializer 加 2^53 fail-loud 守衛；**lie ledger（顯式偏離宣告帳本，每筆偏離＝拍板、登 [DECISIONS §1](../../docs/INTEGRATION-DECISIONS.md)）初始為空**；rev2 的消費端 `Number()` 正規化補丁移植時應還原刪除
- **13 碼矩陣整組凍結（⚠️f）**：`0000`/`1000`/`2222`/`3333`/`7777`/`7778`/`8888`/`8889`/`9998`/`9999`/`4040`/`5003`/`5000`（碼為 wire 凍結事實；`msg` 自 ⚠️y 起載穩定 i18n key〔非人話字串、後端語言無關、前端 `$t` 譯〕；完整矩陣與 key 規約見 DESIGN §7.3）；HTTP status 例外僅 `4040`→404、`5003`→403，**`5000` 一律 HTTP 200 信封（⚠️e）**；4 保留碼（7778/8889/9998/9999）**後端從不發出**、僅前端 `.env` 分組認得
- 業務驗證 error code = **`2222`**（`BizError`）；**`5xxx` 段為授權/基建、非業務**；refresh 類 critical code（`9999`/`9998`/`3333`）絕不用在業務驗證
- `MenuType` enum：1 = directory / 2 = menu；`Status` nullable：`CommonRecord.status: EnableStatus | null` rust-api 須支援
- 分頁形 `PageRes<T>` = `{current, size, total, records}`（camelCase、**無 `pages`/`success`**、空頁 `records:[]`）↔ `Common.PaginatingQueryRecord<T>`
- envelope universal 例外僅 2：`/health`（plain text）與 `/metrics`（Prometheus exposition）不走 envelope
- 預設帳號：`Super / Admin / User`（login req）＋ User → User01 alias（getUserInfo response）
- **契約機器化（待決② C+ 拍板）**：typings 抽 JSON Schema 當 contract test 裁判（唯讀、不動官方檔）＋ coverage gate（router 每條 route 必有 contract case、缺＝CI 紅）＋ 碼表 table-driven case

### I.4 SDD + TDD 混合工作流（NON-NEGOTIABLE）

**規則**：每個 feature 走 CLAUDE.md §3 的 SDD + TDD 混合工作流。

**鎖定**：
- **階段 0 brainstorm**：`docs/superpowers/<NNN>-<feature-name>.md`（由 `superpowers:brainstorming` 產出 spec-design）
- **階段 1 SDD 設計鏈**：`/speckit-specify` → `/speckit-clarify` → `/speckit-plan`（對照本 constitution！）→ `/speckit-tasks` → `/speckit-analyze`
- **階段 2 TDD 實作**：**`superpowers:executing-plans`**（**不是 `/speckit-implement`**）
- **收尾**：`superpowers:finishing-a-development-branch` → 多段式 commit → `git merge --no-ff` 回 `rev3-admin-root`（保留 feature branch 供 audit）
- `git push` / `git merge` 不得出現於 `finishing-a-development-branch` 之前
- 拍板登 DECISIONS §1、波次 as-built 登 DECISIONS §2、commit 流水登 MILESTONES（C 方案四路分流，CLAUDE.md §7.5；**DESIGN 為凍結藍圖、不回填**）

**詳細操作**：CLAUDE.md §3 / §4 / §7（本檔不重複）

### I.5 rust-api 全新寫，對 rev2 source 受控參照（RUSTAPI-SOURCE-ISOLATION）

**規則**：rev3 rust-api 整棵樹從零重寫（⚠️q 拍板）；設計繼承 rev2（結論已內化於 DESIGN），**code 不拷貝**。

**rev2 source 立場（⚠️g 拍板＝受控參照，異於 rev2 對 rev1 的嚴格隔離）**：
- **讀允許**：可 grep／閱讀 rev2 rust-api source 對照驗證（DESIGN 本就 ground 自 rev2 as-built、附錄 D 允許回查）
- **拷貝禁止**：實作必須重新打字消化、不可整段複製
- **防回歸條款**：參照 rev2 code 時，凡 rev3 拍板已推翻的行為（如 ⚠️r 廢除的 id string 序列化、`Number()` 正規化補丁、⚠️e 廢除的 Internal→HTTP 500 mapping）**不得帶回**

**例外**（拍板 #6）：
- `sea-orm-adapter`／`xdb`：自 rev2 整檔拷貝（工具性 crate、rev2 期 35 features 已驗證）
- enforce 層：**全新寫（in-tree，無獨立 `axum-casbin` crate）**——as-built 措辭校正：落地為 `server/src/auth/enforce.rs` 同款 in-tree 實作，非獨立 crate

### I.6 業務表審計欄標準（SCHEMA-AUDIT-COLUMNS）

**規則**：業務主表建表（create migration）時 MUST 含 6 審計欄 —
`created_at` / `created_by` / `updated_at` / `updated_by` / `deleted_at` / `deleted_by`。

**型與約束**：
- `*_at`：`timestamptz`。`created_at` NOT NULL default `now()`；`updated_at` / `deleted_at` nullable。
- `*_by`：operator 的 `user_id`（`bigint` nullable / `Option<i64>`，**非 `user_name` 字串**）；
  system seed / migration 建立 / 未認證情境無 operator → `null`。
- **成對**：`deleted_at`（何時刪）必與 `deleted_by`（誰刪）同寫；`updated_at`＋`updated_by` 同理，不可只寫其一。

**archetype 四變體（待決⑤ 拍板：§3.2 archetype 整組入凍結；各表歸屬見 DESIGN 附錄 F）**：
- **A 業務全 6 審計欄**（`sys_user`/`sys_role`/`sys_menu`/`system_settings`）：如上；soft-delete 表配 partial-uniq `WHERE deleted_at IS NULL`（**三表**；**`system_settings` 例外**——PK=`setting_key` 本身總體唯一、無 partial-uniq）
- **B append-only 日誌**（三 log 表）：只 `created_at` NN（＋`operator_id` 當 domain 欄）；**無 soft-delete、無 update、不可竄改**；MUST NOT 加 `updated_*`/`deleted_*`
- **C join／狀態機**：`sys_user_role`＝零審計（硬刪）；`sys_token`＝僅 `created_at`＋`status` 狀態機（生命週期 §I.7）
- **D 治理變體**：`casbin_rule`＝`protected`/`created_at`/`created_by` **對 stock adapter 隱形**（adapter 的 insert_many/load_policy 不碰這 3 欄）；archive＝原 grant `created_at/by`＋`archived_at/by`＋`archive_reason`（**無 update/delete 欄**、restore＝硬刪移回）

**rev3 加嚴**：本標準自第一條 migration 即生效（DESIGN §3.4 schema 演進紀律：建表即帶 archetype 全欄；§8.6：同 entity 讀／寫同刀**或緊鄰兩刀**、schema 一次定稿）——**無 retrofit 條款**（rev2 的 retrofit 債模式不允許重演）。 **〔v1.1.2 釐清・⚠️ac〕「無 retrofit」之標的＝archetype 審計欄**（即「建表漏帶審計欄、事後補」的 rev2 債形態）；**既有表加 domain 業務／forensic 欄的【刻意、規劃、可逆】演進【不在此限】**——例 D11（審計 log 表加 IP forensic 欄、寫端依設計排為後續刀〔`m006`、可逆〕）為**合規演進**，前提：archetype 欄規則不變（archetype B 不加 `updated_*`/`deleted_*`、不可竄改性維持）、且非「忘帶事後補」的意外債。

### I.7 行為島 invariants（待決⑤ 拍板新增）

**規則**：DESIGN §4 的 3 台狀態機（token rotation／policy governance／single-session）之 invariants 為凍結不變式；動任一條走 Amendment。常數值（如 grace 秒數）與欄級細節留 DESIGN（非凍結面）。

**§4.1 token rotation chain**：
- `token_hash` UNIQUE；同秒輪替靠 per-token `jti` 不撞鍵
- `rotation_chain` = 每次 login 一個 uuid、整鏈共用；reuse 偵測 → 撤整條鏈
- decision seam（`decide_rotation`）為純函式可測；`used_at NULL` → Reuse（fail-closed）
- 過期實體清理 = on-demand `cleanup-job` binary：**預設 dry-run 只 count、`--execute` 才物理刪、冪等、僅此一旗標**（不開其他 CLI flag）
- refresh handler **絕不回 `3333`/`9999`/`9998`**（防前端自動 refresh 迴圈）；Reuse/NotFound → `8888`

**§4.2 policy governance**：
- **DB-first**：寫側只動 DB（`casbin_rule`/archive）、不碰 in-memory enforcer
- `protected` 列拒撤 → 整批 `Rejected`、零變更
- **`PolicyMutated` gate**：commit 後只有結構性真變更才 `reload_and_publish`（Rejected／restore NoOp／NotFound → 跳）；惟**空-diff Applied 與 menu-found-但-無-policy 仍 reload（刻意、不優化）**
- revoke/restore 與審計同 txn 原子；reload = 全量 `load_policy()` + `PUBLISH casbin:policy:invalidate`

**§4.3 single-session lifecycle**：
- pointer 真相在 DB（`sys_user.current_session_id`）、Redis 僅快取（persist-then-cache、可失憶 lazy rehydrate）
- `is_current` **fail-OPEN**（backing-store 抖動不誤踢）；`set_pointer` 永遠執行（即使 policy off）
- policy 三態 `session_policy`∈{inherit, on, off} × runtime `session_mode`；**`session_mode` 讀 runtime store（settings 熱切換）、非靜態 config**
- 兩條踢人通道分離：`7777` = pointer 比對失敗（4 access gate + refresh 第 5 掛點）；`8888` = refresh 鏈被撤/驗章失敗

---

## II. 設計拍板凍結

13 項拍板摘要（rev2 §11.1~§11.13 重編為 **#1~#13** 無撞號形；rev2 期 2026-05-27 親決＋rev3 重鑄調整 2026-06-12；拍板現況唯一清單＝[DECISIONS §1](../../docs/INTEGRATION-DECISIONS.md)）：

| # | 主題 | 拍板凍結 |
|---|---|---|
| #1 | 預設帳號命名 | `Super/Admin/User` 對齊 mock ＋ 模仿 User → User01 alias |
| #2 | alova 端點 | **⚠️c 定案**：`/auth/error`（echo）＋`sendCaptcha`/`verifyCaptcha`（stub 雙模）＋`/mock/getLastTime`（回 `{time}`）；alova demo 三頁（`alova/request`・`alova/scenes`・`function/request`）進 sys_menu seed |
| #3 ★ | modal CRUD 衝突 | 升 L4 改 modal placeholder（MODAL-WIRING 啟用，見 §III.2） |
| #4 | apifoxToken | rust-api 忽略 unknown header（base-web 不動） |
| #5 | demo menu 處理 | **⚠️p 定案（推翻 rev2 (b'-narrow) 隱藏取向）**：demo 全進 `sys_menu` seed、初始僅勾 `R_SUPER`、可見性交 ROLE 勾選層（§I.2）；隱藏機制不啟用、**本拍板不再涉 ★ 軌道** |
| #6 | sub-crate | enforce 層全新寫（in-tree、無獨立 axum-casbin crate）；`sea-orm-adapter`/`xdb` 自 rev2 拷貝（§I.5 例外） |
| #7 | auth route mode | dynamic（後端控 menu；`.env` `VITE_AUTH_ROUTE_MODE=dynamic`、BASE-WEB-ADAPT 軌道） |
| #8 | obs stack | 漸進 — obs-min(log) → obs-full(metrics)（rev3 = 波 4 包覆刀，DESIGN §8.4） |
| #9 | 軌道清單 | **5 軌道（2 ★）**：ADAPT／WRAPPER／MODAL-WIRING ★／RUSTAPI-SOURCE-ISOLATION／BASE-WEB-I18N-WIRING ★〔⚠️aa、v1.1.0 amend〕（⚠️i-2：BUILD-CONFIG 不收錄，見 §III 注） |
| #10 | wire id 細節 | **⚠️r 定案（推翻 rev2 string 拍板）**：逐欄位忠實 typings（詳 §I.3）；User alias 模仿；business error `2222` |
| #11 | prod 路徑前綴 | `/api/*` 主流（front-nginx strip 轉發、`/api/metrics` 擋塊，DESIGN §7.4） |
| #12 | brainstorm 位置 | `docs/superpowers/<NNN>-<feature-name>.md` |
| #13 | login 替代入口 | 全實作雙模 ＋ v1 啟 stub mode（captcha 2 端點已隨 #2 定案；殘餘 alt-login 4 流程 stub 入波排程＝DECISIONS §1 ⚠️m） |

★ = 違反「不動 inline」直覺紀律的拍板項，影響 §III 對應 ★ 軌道。
**排程性拍板註記**：#2/#8/#13 屬排程性（rev3 重排交付序時可重議）——重議仍走 §V.2 Amendment、不默改。

---

## III. 軌道授權邊界

4 軌道完整定義見 [DESIGN §9.4](../../docs/INTEGRATION-DESIGN.md)；第 5 軌道 BASE-WEB-I18N-WIRING ★（⚠️aa、v1.1.0 amend）定義見下方 §III.2（DESIGN §9.4 次回重鑄補入）。本節**只列授權邊界與紀律**。

> **rev2 差異注**：rev2 曾授第 5 軌道 BASE-WEB-BUILD-CONFIG ★（`pageExcludePatterns` 隱藏 demo menu），as-built 從未動用；⚠️p 拍板後隱藏議題消解，**rev3 v1.0.0 不收錄此軌道**（⚠️i-2）——日後若真需 build 配置改動，走 §V.2 Amendment 新授。

**跨軌道 fork-delta 執行紀律（⚠️s 拍板）**——upstream（soybeanjs example）常態更新，本紀律使 fork 差異在 rebase 時可快速定位：
- **修改型**（既有行語意被改變：MODAL-WIRING (a)(b)、ADAPT `.env` 改值等）：**原行註解保留**、緊鄰新行之上，含標記：`// [rev3-inline MW(a)] 原行: ...`／`<!-- [rev3-inline MW(b)] 原行: ... -->`／`# [rev3-inline ADAPT] 原行: VITE_AUTH_ROUTE_MODE=static`——upstream rebase 衝突時，衝突塊自含三方（註解原行＝對照基準），合併解一眼可得
- **新增型**（純插入新行／區塊／檔，無原行可註解）：插入區塊以 `[rev3-inline MW(x)+]` 標記圈界；新檔（(e) 整頁、`modules/*` 新元件、wrapper／typings 新檔）僅檔頭一行標記、不逐行
- **標記統一含 `rev3-inline` token**：全 repo grep 即得完整 fork patch set 清單（upstream 大重構時＝重套 delta 的災難重建索引）
- **rebase 同步紀律**：upstream rebase 解衝突時，註解內「原行」**同步更新為 upstream 現行版**（防對照基準過時、註解漂移成誤導源）
- **⚠️q 整批移植**：rev2 inline 成果移植時，修改型逐處補 example 原行註解（原行自 example diff 取得）

### III.1 預設可動軌道（無需額外授權）

| 軌道 | 範圍 | 紀律 |
|---|---|---|
| **BASE-WEB-ADAPT**（L1+L2） | `.env*` ＋ `src/typings/api/` 新檔（如 `rev3-extra.d.ts`） | 新增為主、不改 inline；禁止刪除既有 type / field |
| **BASE-WEB-WRAPPER**（L3） | `src/service/api/rev3-*.ts` 新檔 | 一律新檔（`rev3-` 前綴）；不改既有 `auth.ts` / `system-manage.ts` / `route.ts` |
| **RUSTAPI-SOURCE-ISOLATION** | rust-api 整棵樹 | 全新寫；設計繼承 rev2、code 受控參照不拷貝（§I.5） |

### III.2 ★ 需 constitution 顯式授權軌道（本檔已授權）

#### MODAL-WIRING ★ — **本檔授權七用途 (a)~(g)**（⚠️i-1：(a)~(e) rev2 經 v1.0→v1.6 五次擴邊驗證過的邊界、rev3 一次全授；**(f)＝⚠️af、v1.2.0 amend（列表排序掛載）**；**(g)＝⚠️ah、v1.3.0 amend（非-manage user-center 自助頁）**；**新用途 (h) 起仍走 Amendment**）

**邊界**：`base-web/src/views/manage/**` 內的——
- **(a)** `// request` placeholder 接線：`modules/*-operate-{modal,drawer}.vue`（create/update）與 `index.vue` 的 delete/batchDelete handler
- **(b)** 業務頁操作按鈕 `hasAuth(<button_code>)` 可見性 gating：`index.vue` 操作鈕 `v-if` 與共用元件 `table-header-operation.vue` 的附加顯隱 prop
- **(c)** 同模式新權限 modal＋trigger：`role-operate-drawer.vue` 的 `v-if="isEdit"` 授權編輯區新增 `*-auth-modal.vue`（鏡像 menu/button-auth-modal）＋觸發 NButton＋對應 i18n key——嚴格限「角色 × 某權限維度」runtime 編輯介面
- **(d)** 選單復原／re-parent 維運控制：`menu-operate-modal.vue` edit 模式 parentId selector（種子父固定、僅自訂可搬）＋`index.vue`「顯示已刪除」toggle＋restore 鈕（孤兒父已刪擋下）＋對應 i18n key——嚴格限「選單樹復原／父層級調整」
- **(e)** 同 manage 範式新管理頁：`views/manage/<page>/index.vue`＋可選 `modules/*`（嚴格鏡像既有 user/role/menu 結構）、消費 rust-api 端點、含 `route.manage_<page>`＋`page.manage.<page>.*` i18n key——不擴張到任意新 UI／非 manage 頁／自訂佈局；route 由 elegant-router 自動生成、可見性走 §I.2
- **(f)** 列表欄位排序掛載（⚠️af、023-list-column-sort）：column 定義加 naive-ui `sorter` props（`sorter:{multiple:N}`＋受控 `sortOrder`）＋`<NDataTable>` 綁 `@update:sorter`＋補 `useRoute()`／`searchParams.sort`；**於列表 view 工具列掛「清除排序」控制**（有 `TableHeaderOperation` 的頁〔user/role/ip-rule〕用其既有 `#suffix` slot；審計/封存等自有 `NSpace` 工具列的頁則於該既有工具列 inline）＋ UI label key `common.clearSort`（locale＋`App.I18n.Schema` 同步）——嚴格限「列表排序」用途、不擴張其他 inline；**不改 `table-header-operation.vue` 元件本體**。配套新檔（`useTableSort`／`SortClearButton`／`rev3-extra` typings）循 ADAPT/WRAPPER；非法排序 `2222`〔wire msg `biz.common.invalidSort`〕的 `backend.biz.common.invalidSort` 譯文循 BASE-WEB-I18N-WIRING ★
- **(g)** 非-manage 頂層自助頁（⚠️ah、025-user-center）：授權於 `base-web/src/views/manage/**` **之外**新增登入者自助頁 `views/user-center/index.vue`＋可選 `modules/*`——profile 自助檢視/編輯（帳號/角色唯讀、性別/昵稱/手機/郵箱可改）＋改密碼（消費密碼政策 024）＋手機/郵箱驗證 UI 佔位，消費 rust-api 自助端點（auth-only、operator=登入者本人），含 `route.user-center`＋`page.userCenter.*` i18n key；route 由 elegant-router 自動生成、可見性走 §I.2——**嚴格限「登入者本人自助（profile／改密碼／手機郵箱驗證佔位）」用途、不擴張到管理他人資料／任意新 UI／自訂佈局**。配套新檔（wrapper／typings）循 ADAPT/WRAPPER；後端 biz 訊息譯文循 BASE-WEB-I18N-WIRING ★

**紀律**：
- **嚴格限七用途，絕不擴張到其他 inline 邏輯**；第 (h) 種用途 → §V.2 Amendment
- 每改一處在 spec 內紀錄（file:line ＋ 改動內容 ＋ upstream 衝突風險評估）
- 共用元件改動 MUST 用附加 prop ＋ 安全預設（不變既有呼叫端行為）

#### BASE-WEB-I18N-WIRING ★ — **本檔授權三範圍 (i)~(iii)**（⚠️aa 拍板 2026-06-16、v1.1.0 amendment；⚠️y biz-msg i18n〔前端譯·msg=key〕的接線載體）

**背景**：⚠️y（[DECISIONS §1](../../docs/INTEGRATION-DECISIONS.md)）定 wire `msg` 載穩定 i18n key、base-web 以 `$t(msg)` 翻譯（後端語言無關）。其接線**必然改 base-web inline**（攔截器顯示點＋核心 typings＋locale 字典），非既有 ADAPT（`.env`/`typings/api/` 新檔）/WRAPPER（`service/api/rev3-*` 新檔）/MODAL-WIRING（`views/manage/**`）所能涵蓋 → 本軌道補齊 §I.1「不動 inline、例外見 §III」的授權鏈。

**邊界**（base-web，嚴格限以下三範圍）：
- **(i)** 請求攔截器 msg 翻譯接線：`src/service/request/index.ts`（modal `content:` 顯示點、`onError` 的 backend-msg extraction、及其 dedup-stack companion 行）＋`src/service/request/shared.ts`（`showErrorMsg` 相關）——**僅**為「將 wire `msg`（key）經 `$t` 譯為在地化文字再顯示」之最小接線；**不改**攔截器的碼分組/logout/refresh/retry 等控制流語意
- **(ii)** locale 字典 backend 命名空間：`src/locales/langs/{zh-cn,en-us}.ts` 新增 top-level `backend` 命名空間（key 形＝`backend.<root>.<entity>.<condition>`、root∈{common,auth,biz,system}）＋對應譯文——純新增、不改既有命名空間
- **(iii)** i18n typed-key Schema：`src/typings/app.d.ts` 的 `App.I18n.Schema` 新增 `backend` 型別（使 `GetI18nKey` 納入 `backend.*` typed key）＋視需要一支 `translateBackendMsg` helper（自 `@/locales` 匯出）——純新增型/匯出、不改既有 Schema 成員

**紀律**：
- **嚴格限三範圍**，絕不擴張到攔截器其他控制流或非 i18n 的 inline 邏輯；第四種範圍 → §V.2 Amendment
- 每改一處在 spec／plan 內紀錄（file:line ＋ 改動內容 ＋ upstream 衝突風險評估）
- 走 fork-delta `rev3-inline` 紀律（§III 跨軌道紀律：修改型保留原行註解、新增型標記圈界、含 `rev3-inline` token）
- 後續切片新增其 per-entity biz key（locale ＋ Schema 擴充）依本軌道、循 ⚠️y key 規約（規約於 003-envelope 落定）

---

## IV. Compliance Check（spec-kit `/speckit-plan` 用）

`/speckit-plan` 步必須對照本 constitution 跑 Constitution Check，逐項 yes/no：

1. **此 plan 是否違反 §I.1 base-web 為權威紀律？** rust-api 是否未提供 base-web 用到的對應 endpoint？
2. **此 plan 是否動到 base-web inline？** 若是、屬 MODAL-WIRING ★ 哪個用途 (a)~(e)？授權邊界內？是否依 §III fork-delta 紀律（修改型原行註解保留／新增型標記圈界、`rev3-inline` token）？
3. **此 plan 涉及 menu 顯示是否走 Casbin enforce？**（§I.2；demo menu 是否依 ⚠️p 進 seed 而非隱藏？）
4. **此 plan 的 wire 設計是否對齊 §I.3 typings 權威序與不變式？**（envelope／逐欄位 id 型／13 碼矩陣／enum；mock 僅作補充 fixture）
5. **此 plan 是否從 rev2 source 拷貝 code？** 若是、屬 §I.5 例外清單嗎？參照處是否觸發防回歸條款（帶回已推翻行為）？
6. **此 plan 是否抵觸 §II 拍板 #1~#13？** 任一拍板需改變、必先走 Amendment 流程
7. **此 plan 是否觸及 §III ★ 軌道？** 若是、在授權邊界內？
8. **此 plan 是否新建業務表（create migration）？** 若是，是否含 §I.6 六審計欄（建表即帶、無 retrofit）？append-only / join 表是否依例外處理？
9. **此 plan 是否觸及 §I.7 行為島（token rotation／policy governance／single-session）？** 若是、各 invariants 是否保持？是否用 state-machine 鏡頭設計（非 CRUD 格子）？

任一檢查不通過 → plan 須回 brainstorm 或申請 Amendment（§V.2）。

---

## V. Governance

### V.1 凍結權威性

本 constitution 為 rev3 整合的**凍結權威**；與其他文件衝突時**以本檔為準**。文件權威鏈（C 方案，CLAUDE.md §7）：

> constitution（凍結權威）＞ [DECISIONS §1](../../docs/INTEGRATION-DECISIONS.md)（拍板現況；優先於 DESIGN 本文）＞ [DESIGN](../../docs/INTEGRATION-DESIGN.md)（凍結藍圖、只被引用）＞ CHECKLIST（當前狀態）

DESIGN 仍為「核心事實」（設計契約＋詳細軌道定義＋行為島全文），但設計**結論**以本檔 §II 為凍結值；本檔與 DECISIONS §1 不一致＝amendment 未同步的程序錯誤，以本檔為準並立即補同步。

### V.2 Amendment 流程

任何改動本檔內容需走以下流程：

1. **提案**：在 [`docs/INTEGRATION-DECISIONS.md`](../../docs/INTEGRATION-DECISIONS.md) **§1 決策紀錄表**新增一列，註明改哪一節／為何改／改後影響
2. **討論**：user 親決（本檔內容皆為 user 拍板項，Claude 不主動 amend）
3. **凍結**：更新本檔對應段、bump version（規則見 §V.3）、DECISIONS §1 該列改「✅ 已決＋結論全文」（DESIGN 本文不動、重鑄時摺合）
4. **commit**：獨立 commit `docs(constitution): amend <條目>...`＋CHECKLIST 拍板索引行＋MILESTONES §1 一行

### V.3 Version 規則

- **MAJOR**（2.0.0）：鐵紀律（§I.1~I.6 原則）改變、§I.7 **方向性不變式反轉**（fail-OPEN/fail-closed 方向、DB-first、7777/8888 雙通道分離）、§II 拍板項撤回、★ 軌道授權撤銷
- **MINOR**（1.1.0）：新拍板項固化（§II 加項）、軌道授權邊界擴展（含 MODAL-WIRING 新用途 (f)）、新增 ★ 軌道、§I.7 其餘 invariant 細項調整（如 cleanup CLI 旗標政策、gate 跳過清單）
- **PATCH**（1.0.1）：文字校正、釐清、reference 更新、Compliance Check 增補

---

**Version**: 1.3.0 | **Ratified**: 2026-06-12 | **Last Amended**: 2026-07-02（v1.1.0：§III 新增 BASE-WEB-I18N-WIRING ★ 軌道〔⚠️aa、MINOR〕；v1.1.1：§I.3 釐清 `msg` 載 i18n key 對齊 ⚠️y〔⚠️ab、PATCH＝釐清〕；v1.1.2：§I.6 釐清「無 retrofit」標的＝archetype 審計欄、既有表 domain forensic 之刻意可逆演進不在此限〔⚠️ac、PATCH＝釐清〕；v1.2.0：§III.2 MODAL-WIRING ★ 新增用途 (f) 列表排序掛載〔⚠️af、MINOR；清除鈕掛點＝列表 view 工具列〔有 TableHeaderOperation 的頁用 #suffix、其餘用頁面既有工具列〕、analyze F1 校正機制描述〕；v1.3.0：§III.2 MODAL-WIRING ★ 新增用途 (g) 非-manage user-center 自助頁〔⚠️ah、MINOR〕）
