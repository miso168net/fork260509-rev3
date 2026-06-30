# Research: 列表欄位排序（023-list-column-sort）

Phase 0 研究。解析 spec 與 brainstorm 的開放項，固化技術決策。所有 file:line 證據來自 brainstorm 階段 + plan 研究的 read-only 調查（rust-api `cb2767f`／base-web `aa2f57bc` worktree）。

---

## R1 — Wire 契約：單一 `sort` query 字串（inline、非 serde flatten）

- **Decision**：每個 list endpoint 的 query DTO **inline 加一欄** `sort: Option<String>`（camelCase rename）。wire 格式 `field:dir,field:dir`（逗號分隔、token `field:dir`、**順序＝優先序**）。例：`?sort=userName:asc,status:desc`。
- **Rationale**：(a) base-web axios `qs.stringify` 預設陣列序列化成 `sort[0]=..`（`packages/axios/src/options.ts:52-54`），單一字串乾淨、不觸陣列邏輯、順序天然保留；(b) 7 個端點各加一欄 trivial，避開 `#[serde(flatten)] SortQuery` 與 axum `Query` extractor 相容性未驗風險。
- **Alternatives rejected**：serde flatten 共用 struct（相容性未驗、收益僅省 7 行）；雙欄陣列 `sortBy[]`/`sortOrder[]`（qs 括號編碼、長度對齊脆弱）。
- 空字串守門：`None | Some("") | 全空白 → 無排序`（沿用 `normalize_str_filter` 範式 `system_manage.rs:472-474`）。

## R2 — 後端解析 + 白名單（防注入）

- **Decision**：
  - 共用 `parse_sort_spec(Option<String>) -> Result<Vec<(String, sea_orm::Order)>, AppError>`（放 `system_manage.rs` helper 區、鄰 `normalize_*`）：空→`vec![]`；切 token、解析 `field:dir`；方向只允 `asc`/`desc`（→`Order::Asc`/`Desc`）否則 `Biz`；**欄位重複**→`Biz`。
  - 每 entity 一個 `resolve_<entity>_sort(Vec<(String,Order)>) -> Result<Vec<(Column,Order)>, AppError>`：`match field { "userName" => Column::UserName, …, _ => Err(Biz) }`。**match 即白名單、擋注入**（無字串落進動態 SQL；repo 現無 `Column::from_str`、刻意維持）。
  - 錯誤碼＝**`2222`**（業務驗證、§I.3）；msg 用穩定 i18n key `biz.common.invalidSort`（沿用 `normalize_endpoint_method`→`biz.role.invalidEndpointMethod` 範式 `system_manage.rs` 測 `:3405-3417`）。
- **Rationale**：白名單 + 去重天然把排序深度卡在「該表可排欄位數」，無需數字 cap。防注入由 match 強制。
- **i18n 註（analyze F2 校正）**：rust 回 wire msg `biz.common.invalidSort`；前端攔截器 `translateBackendMsg`=`$t('backend.'+msg)`（`src/locales/index.ts:25`）→ 查 **`backend.biz.common.invalidSort`**（既有 biz 錯誤皆 `backend.biz.<domain>.<cond>`）。故前端在 `backend.biz` 下加 `common.invalidSort` 譯文 + Schema（**非** `backend.common.invalidSort`、少 `biz.` 層→raw key），循既授權 **BASE-WEB-I18N-WIRING ★** (ii/iii)。前端正常不觸發（只送白名單欄）→ 須 CDP 主動觸發驗 toast 非 raw key。

## R3 — 逐頁可排序欄白名單（權威清單）

「可排序欄＝對應單一 DB 純量欄 ∧ 前端列表實際顯示」。排除：selection/index/operate、join/computed 欄。**前端送的 key＝下表左欄（camelCase）；後端 resolver match 映到右欄 Column**。

| 頁 | 可排序欄（前端 key → DB 欄） |
|---|---|
| **user** | userName→user_name, userGender→user_gender, nickName→nick_name, userPhone→user_phone, userEmail→user_email, status→status |
| **role** | roleName→name, roleCode→code, roleDesc→role_desc, status→status |
| **ip-rule** | cidr→cidr, ruleType→rule_type, order→`order`(保留字、需 quote), description→description, createTime→created_at, updateTime→updated_at |
| **operation_log** | createTime→created_at, operation→operation, entityTable→entity_table, entityId→entity_id, operatorIpConfidence→operator_ip_confidence, operatorPeerIp→operator_peer_ip, operatorRealIp→operator_real_ip, operatorXForwardedFor→operator_x_forwarded_for |
| **access_log** | createTime→created_at, method→method, path→path, httpStatus→http_status, ipConfidence→ip_confidence, peerIp→peer_ip, realIp→real_ip, xForwardedFor→x_forwarded_for, region→region |
| **login_attempt** | createTime→created_at, attemptedUserName→attempted_user_name, success→success, ipConfidence→ip_confidence, peerIp→peer_ip, realIp→real_ip, xForwardedFor→x_forwarded_for, region→region |
| **casbin_policy_archive** | roleCode→v0, target→v1, archivedTime→archived_at, createdTime→created_at, archivedBy→archived_by, archiveReason→archive_reason（dimension/v2＝computed display、排除）|

明確排除：user 的 roles（join、且列表未顯示）；user/role 的 create/update time（列表未顯示）；ip-rule 的 deleted（computed）。⚠️ `ip-rule.order` 的 DB 欄名是 PG 保留字（entity `column_name="order"`、`sys_ip_rule.rs:14`）—— SeaORM `Column::Order` 會正確 quote。

## R4 — facade 套用排序（保留現況相容）

- **Decision**：每個 list facade `list*` 簽章多收 `sort: Vec<(Column, Order)>`：
  - `sort` 空 → **走原本寫死的預設排序那行**（byte-identical 現況）。
  - `sort` 非空 → `for (col,ord) in sort { q = q.order_by(col,ord); }` 後接 `Id` tie-breaker（方向＝該表既有 Id 預設向：user desc/role asc/logs desc/archive desc）。取代預設內容排序、保留穩定分頁。
  - ⚠️ **ip_rule 特例（analyze F4）**：`sys_ip_rule::list` 是回收桶（含已刪、領頭 `deleted_at IS NULL DESC` 把已刪沉底＋badge/restore）。sort 非空時**保留該領頭群組鍵**（已刪恆沉底）再接 user sort cols + Id，避免使用者排 cidr 時已刪列混入 active 列。其餘 6 facade 無此領頭群組、不受影響。
- 受影響 facade：`sys_user::list_active`(`sys_user.rs:156`)、`sys_role::list`(`sys_role.rs:99`)、`sys_operation_log::list`、`sys_access_log::list`、`sys_login_attempt::list`、`sys_casbin_policy_archive::list`、`sys_ip_rule::list`（7 支）。

## R5 — 前端：受控排序 + 自維護點擊序

- **Decision**：採**受控排序**（每可排序 column 綁 `sortOrder` 自 composable 狀態）。理由：多欄受控顯示已驗（`use-sorter.mjs:56-72`）；受控同時服務「持久化還原」（設狀態→欄位反映箭頭）與「一鍵清除」。
- **循環＝naive-ui 原生**（無→▼降→▲升→無、第一下反序）：直接讀 `@update:sorter` 給的 order、**不設 `customNextSortOrder`**（user 拍板用原生、最簡）。
- **優先序＝點擊順序**：composable **自維護有序清單**（每次事件 reconcile：改向/新欄 append 尾/取消移除），不依賴受控 payload 陣列序（受控下為 column 定義序）。
- 新增 `useTableSort` composable（單一職責、7 頁複用）：吐 sort 狀態、`@update:sorter` handler、column 排序 props helper（`sorter:{multiple:N}` + 受控 `sortOrder`）、`clearAll()`、localStorage 讀寫。`useNaivePaginatedTable`（`hooks/common/table.ts:76`）幾乎不動。
- `remote` 安全：表為 `remote`、naive-ui 不做 client 二次排（`use-table-data.mjs:193-198`）。

## R6 — 持久化（localStorage、per route.name）

- **Decision**：沿用 `localStg`（`src/utils/storage.ts:5`、auto-JSON、有 prefix）。新 key（`StorageType.Local` 註冊、`src/typings/storage.d.ts`）存 `Record<storageKey, sort字串>`，仿 tab store `cacheTabs`（`store/modules/tab/index.ts:349-352`）。**storageKey（analyze F3）**：單表頁＝`route.name`（elegant-router 唯一穩定）；**多表共用單一 route 的頁須加 per-table 辨識** —— `/manage/audit`＝1 route（`manage_audit`、`routes.ts:254`）含 operation/access/login 3 tab 表，各表 storageKey＝`` `${route.name}:${tab}` ``，否則 3 表共用 route.name 互相覆寫（`createTime` 三表都有→還原污染、last-writer-wins）。
- 還原：mount 讀回 → 解析有序 `{columnKey,order}` → 設受控 `sortOrder` + `searchParams.sort` → 首次 fetch 已排好。防禦性丟棄「已不存在/不在白名單」欄（FR-015）。
- 排序變更 reset 回第 1 頁（FR-006）。clear-all（`tableRef.clearSorter()` `DataTable.mjs:281` → `@update:sorter(null)`）清狀態 + 清該 route key + 重抓。

## R7 — Index-only migration `m008`（兌現 clarify Q1）

- **Decision**：新增 `migration/src/m008_<name>.rs` 建 `idx_login_attempt_created_at ON sys_login_attempt(created_at)`（非 unique、非 partial、單欄；對齊 operation/access 既有單欄 created_at 索引 `m005`）。在 `migration/src/lib.rs` 加 `mod m008_*;`（接 `:20`）+ vec push（接 `:35`）。
- **Rationale**：login_attempt 的預設排序欄 created_at 現只在複合索引第二欄、撐不住單獨 `ORDER BY created_at`（operation/access m005 有補、login_attempt 漏）。高基數、預設排序欄、最常排 → 唯一值得補。其餘可排序欄維持 best-effort（clarify Q1）。
- **migration 須含 up + down**（drop index）；C-V 跑 up→down→up（見 verification-commands）。

## R8 — 匯出反映排序（FR-016）

- **Decision**：匯出＝3 審計 log 頁（operation/access/login）list 端點上的 `export` 旗標（`parse_export` `system_manage.rs:647`），**與 list 共用同一個 `facade::<table>::list(...)` 呼叫**（只差 page=0/size=CSV_EXPORT_CAP `:628`）。R4 給 facade `list` 加 sort 參數後，handler 同一行呼叫（如 op-log `:2154`）同時供 list 與 export → **匯出自動反映排序、無需另開支**。
- 範圍：FR-016 只涉 operation/access/login（user/role/ip-rule/archive 無匯出 query 欄）。

## R9 — i18n：單一 `common.clearSort`（清除排序按鈕 label）

- **Decision**：新增 label key **`common.clearSort`**（共用元件 UI label 慣例命名空間＝`common.*`，對齊既有 add/refresh/batchDelete `table-header-operation.vue:55-73`）。三處同改（**先 Schema 後 locale**、repo 慣例 `app.d.ts:843`）：
  - `src/typings/app.d.ts` `App.I18n.Schema.common`（`:382-425`）加 `clearSort: string;`
  - `src/locales/langs/zh-cn.ts` common（`:9-52`）加 `clearSort: '清除排序'`
  - `src/locales/langs/en-us.ts` common（`:9-`）加 `clearSort: 'Clear sort'`
- naive-ui 排序箭頭為內建 icon、**無新文案**；本功能前端唯一新 label＝清除排序鈕。
- ⚠️ vite stale-locale：新 locale 鍵後 CDP 在地化驗收前須 `restart base-web`、斷言 toast/label 非 raw key。

## R10 — 測試策略（純函式 + acceptance）

- 純函式單元（rust）：`parse_sort_spec`（空/非法方向/重複欄→2222）+ 每個 `resolve_<entity>_sort`（白名單命中/拒絕）。可 in-crate `#[cfg(test)]`（無需 DB）。
- live smoke（容器內、`--ignored --test-threads=1`、帶 `DATABASE_URL`）：facade `list` 帶 sort 驗回傳順序。
- 前端單元：composable 點擊序維護（append/toggle/remove）、wire 字串生成、localStorage 往返。
- acceptance（curl + CDP + psql）：見 `contracts/verification-commands.md`。
- **無新 workspace crate**（只加模組/fn）→ 不強制 prod image build；但**有 migration** → C-V 必含 up→down→up。
