# 023 · 列表欄位排序（rev3）

> Phase 0 brainstorm（spec-design）。需求：現有 `/manage/*` 等分頁列表頁無法依使用者當下想排的欄位排序。
> 目標：**server-side 排序**（rust-api 查 DB 時就 `ORDER BY`，非 base-web 單頁前端排）＋**多欄位排序**（各欄獨立 asc/desc、點擊順序＝優先序）＋**3-state 循環**（naive-ui 原生：第一下反序、第二下正序、第三下取消）＋**一鍵清除全部排序**＋**持久化**（換頁回來排序還在）。
> 範圍：7 個分頁列表（user / role / operation_log / access_log / login_attempt / casbin_policy_archive / ip_rule）；**menu 排除**（樹狀表、非分頁平表）。
> 交棒：本檔 → `/speckit-specify`（手動）→ plan → tasks → `superpowers:executing-plans`（Workflow 驅動）。

---

## 1. 需求與範圍

**問題**：列表頁（如 `/manage/user`、`/manage/role`）的欄位標頭不能點擊排序；後端排序是 facade 內寫死的 `order_by_*(Column::Id)`，前端完全無法指定。

**核心約束**：這些列表是**後端分頁**（每次只抓 `size` 筆）。所以排序**一定在後端做**才正確 —— 純前端排序只會重排「當前這頁可見的 N 筆」、不動整個資料集，對分頁表是語意陷阱。

**範圍（7 個分頁列表）**：

| 列表 | handler | facade | 現預設排序 |
|---|---|---|---|
| 使用者 | `get_user_list` (`system_manage.rs:1027`) | `sys_user::list_active` (`sys_user.rs:156`) | `order_by_desc(Id)` (`:181`) |
| 角色 | `get_role_list` (`:1245`) | `sys_role::list` (`sys_role.rs:99`) | `order_by_asc(Id)` (`:113`) |
| 操作日誌 | `OperationLogQuery` (`:246`) | `sys_operation_log` | `order_by_desc(CreatedAt, Id)` |
| 存取日誌 | `AccessLogQuery` (`:268`) | `sys_access_log` | `order_by_desc(CreatedAt, Id)` |
| 登入嘗試 | `LoginAttemptQuery` (`:293`) | `sys_login_attempt` | `order_by_desc(CreatedAt, Id)` |
| 政策封存 | `ArchivedPolicySearchQuery` (`:378`) | `sys_casbin_policy_archive` | `order_by_desc(ArchivedAt, Id)` |
| IP 規則 | `IpRuleSearchQuery` (`:430`) | `sys_ip_rule` | 多鍵（deleted/Order/Id） |

**menu 排除（已確認）**：選單管理走樹狀端點（`get_menu_tree` `:1789`、`get_menu_list_v2` `:1891` → `build_management_list_tree` parent_id 巢狀），**非分頁平表**，欄位排序語意不適用，維持現有 `order` 欄樹序。

## 2. 拍板決策

| # | 決策 | 理由 |
|---|---|---|
| D1 | **server-side 排序**（後端 `ORDER BY`） | 分頁表唯一正確解；純前端排只排當前頁 |
| D2 | **多欄位排序**，各欄獨立 asc/desc | user 需求 |
| D3 | **優先序＝點擊順序**（先點為主排序） | 最直覺；對齊「依當下想排的欄位排」 |
| D4 | **3-state 循環＝naive-ui 原生**（無→▼降→▲升→無、第一下反序） | 原生內建即此循環、直接用、**不覆寫**（user 拍板：原生有就用原生、最簡；見 §3.1、§6 E1） |
| D5 | **一鍵清除全部排序**按鈕 | user 需求 |
| D6 | **持久化＝localStorage**（per `route.name`），非 cookie | cookie 每請求帶去後端純浪費；後端從請求參數就拿到排序；localStorage 是 UI 偏好標準存法、專案已用 |
| D7 | **不顯示優先序號碼**（只顯箭頭） | user 選；naive-ui 預設亦不顯 |
| D8 | **單欄白名單防注入**：欄位名→`Column` 顯式 `match` | 絕不讓前端字串落進動態 SQL；沿用 `normalize_endpoint_method` 白名單→2222 範式 |
| D9 | **sort 狀態管理：傾向非受控**（用原生 + payload 點擊序）；多欄還原有疑慮則退受控 | D4 改用原生循環後不再需受控；非受控最簡（payload 陣列＝點擊序、無覆寫）；唯多欄持久化還原須 plan 驗（見 §3.4、§8） |

## 3. 互動設計（前端，主軸）

### 3.1 點擊與 3-state 循環（naive-ui 原生）

- **點擊位置**：table 欄位標頭（th）；naive-ui 在可排序欄顯示排序箭頭。
- **循環＝naive-ui 內建**：`無 → ▼降(反序) → ▲升(正序) → 無`（**第一下反序**）。直接用 naive-ui 預設 `getNextOrderOf`（`utils.mjs:98-101`），**不設 `customNextSortOrder`、不覆寫**（user 拍板：原生就有就用原生、最簡，省掉「修第一下」的整塊複雜度）。
- handler 只需「讀」naive-ui 給的 order（不改寫），轉成 wire + 持久化 + 重抓。

### 3.2 多欄＝點擊序優先

- 可排序 column 設 `sorter: { multiple: N }` 啟用多欄（`SorterMultiple`，`interface.d.ts:2865`）。`multiple` 值僅為「啟用多欄」開關，因走 `remote`、naive-ui 不做 client 排序，值不影響結果。
- **優先序＝點擊順序**。非受控模式下 `@update:sorter` 的 payload 陣列即點擊序（push-to-tail，`use-sorter.mjs:171-178`），可直接用；若退受控（§3.4 fallback）則 composable 自維護點擊序清單（受控 payload 順序為 column 定義序、非點擊序）。
- 走查（原生循環）：`/manage/user` 點「使用者名稱」▼降 → 點「建立時間」▼降（userName 主、createdAt 次）→ 再點「使用者名稱」▲升（userName 主升、createdAt 次降）→ 點「使用者名稱」第三下取消（userName 移出、createdAt 遞補成主）。

### 3.3 一鍵清除全部排序

- 工具列 `TableHeaderOperation` 的 `#suffix` slot 加「清除排序」鈕（**無侵入、不改元件**，slot 已存在 `table-header-operation.vue:76`）。
- 按下 → `tableRef.clearSorter()`（naive-ui expose，`DataTable.mjs:281`）→ 觸發 `@update:sorter(null)`（`use-sorter.mjs:168-170`、`doUpdateSorter` 會 call callback `:137-153`）→ 同一 handler 清空狀態 + 清該 URI 的 localStorage + 回預設序重抓。一處收斂。

### 3.4 持久化與還原（localStorage）

- **存**：沿用專案 `localStg`（`src/utils/storage.ts:5`；自動 JSON、有 prefix）。在 `StorageType.Local`（`src/typings/storage.d.ts`）註冊新 key，存 `Record<routeName, sort字串>`（單一 key 存集合，仿 tab store `cacheTabs` `store/modules/tab/index.ts:349-352`）。
- **key**：`route.name`（elegant-router 下唯一穩定；`fullPath` 含 query 不適合）。⚠️ 目標頁目前未 `import { useRoute }`，須補。
- **還原**：頁面 mount 讀回該 route 的 sort 字串 → 解析成有序 `{columnKey, order}` 清單 → 寫進 `searchParams.sort`（首次 fetch 就已排好）+ 還原欄位箭頭：**非受控**用各 column `defaultSortOrder`、**受控** fallback 用 `sortOrder`（多欄同時顯箭頭已驗證 `use-sorter.mjs:56-72`）。還原時對「已不存在 / 不在白名單」的欄做防禦性丟棄。多欄非受控還原（多個 `defaultSortOrder` 同時生效）須 plan 容器驗（見 §8）。
- **remote 安全**：表是 `remote`，naive-ui 顯示資料繞過 client 排序結果（`use-table-data.mjs:193-198`），純後端 `ORDER BY`、不被二次 client 排。

## 4. 後端設計（server-side ORDER BY）

### 4.1 Wire 契約

- 新增**單一** query 參數 `sort`，格式 `field:dir,field:dir`（逗號分隔、各 token `field:dir`、**順序＝優先序**）。例：`?sort=userName:asc,createdAt:desc`。
- **為何單一字串非陣列**：base-web axios `paramsSerializer = qs.stringify(params)` 無 options（`packages/axios/src/options.ts:52-54`），陣列走 qs 預設 `indices` → `sort[0]=..&sort[1]=..`（括號還被 encode）；單一字串乾淨、順序天然保留、不觸發 qs 陣列邏輯。
- 未設 / 空字串 → 各 endpoint 既有預設排序（沿用空字串守門，`normalize_str_filter` `system_manage.rs:472-474`）。

### 4.2 解析與白名單（防注入）

- **共用** `parse_sort_spec(Option<String>) -> Result<Vec<(String, sea_orm::Order)>, AppError>`：
  - `None` / 空 / 全空白 → `Ok(vec![])`。
  - 切 token、解析 `field:dir`；方向只允許 `asc`/`desc`（→ `Order::Asc`/`Desc`），否則 Biz 2222。
  - **欄位不可重複** → Biz 2222。
- **每 entity 一個** `resolve_*_sort(Vec<(String, Order)>) -> Result<Vec<(Column, Order)>, AppError>`：`match field { "userName" => Column::UserName, …, _ => Err(Biz 2222) }`。
  - **match 即白名單、擋注入**（無任何字串落進動態 SQL；repo 現無 `Column::from_str` 之類動態映射、刻意維持）。
  - 白名單 + 去重**天然把排序深度卡在「該表可排欄位數」**，不需另設數字 cap。

### 4.3 facade 套用（保留現況相容）

- facade `list*` 簽章多收 `Vec<(Column, Order)>`，**在現有 `.order_by_*` 之前**依序 apply，保留 `Id` tie-breaker（穩定分頁、免 paginator 無序 warning）。
- **未指定排序時 byte-identical 於現況**：`sort` 空 → 走原本預設排序那行；有指定 → 使用者欄位（依序）＋ `Id` 收尾，取代預設內容排序。
- 持久化是純前端，**後端 wire 完全不受影響**。

## 5. 前端落地單元

- 新增 `useTableSort` composable（單一職責、7 頁複用）：吃 route key + 可排序欄清單 + refetch 觸發；吐 sort 狀態、`@update:sorter` handler（讀 naive-ui order、組 wire、不覆寫循環）、column 排序 props helper（`sorter:{multiple}` + 還原用 `defaultSortOrder`/`sortOrder`）、`clearAll()`、localStorage 讀寫。
- `useNaivePaginatedTable`（`src/hooks/common/table.ts:76`）幾乎不動（surgical）；view 端：spread 排序 props 到可排序欄、綁 `@update:sorter`、`sort` 併進 `searchParams`、`#suffix` 放清除鈕、補 `useRoute()`。
- typings：共用 search params 加 `sort?: string`；`StorageType.Local` 註冊持久化 key。naive-ui 排序是內建 icon、**無新 i18n**。

## 6. 關鍵實證事實（file:line）

| # | 事實 | 證據 |
|---|---|---|
| E1 | naive-ui 原生循環＝無→descend→ascend→無（第一下 descend）；第一次點硬寫 `getNextOrderOf(false)`、`customNextSortOrder` 僅第二次起生效 → **D4 決定直接採原生、不覆寫** | `naive-ui/es/data-table/src/utils.mjs:98-118`（`getNextOrderOf` / `createNextSorter`） |
| E2 | `customNextSortOrder` 為合法 column prop | `interface.d.ts:2911` |
| E3 | `clearSorter()` / `sort()` 經 ref expose；`clearSorter` 觸發 `@update:sorter(null)` | `DataTable.mjs:277-290,407-420`；`use-sorter.mjs:154-170,137-153` |
| E4 | 多欄受控：設各 column `sortOrder` 即多欄同時顯箭頭；naive-ui 不顯優先序號碼 | `use-sorter.mjs:56-72`；`SortButton.mjs:23-67`（無 priority 渲染） |
| E5 | `@update:sorter` 多欄吐 `SortState[]`（單欄吐物件、清除吐 null）；array＝點擊序 | `interface.d.ts:3075-3082`；`use-sorter.mjs:118-132,171-178` |
| E6 | `remote` 顯示資料繞過 client 排序、後端排安全 | `use-table-data.mjs:193-198`；user/index.vue 已 `remote` |
| E7 | `localStg` auto-JSON + prefix；key 型別註冊在 `StorageType.Local` | `src/utils/storage.ts:5`；`packages/utils/src/storage.ts:16-50`；`src/typings/storage.d.ts` |
| E8 | per-route 持久化範式＝tab store `cacheTabs`（單 key 存集合）；`columnChecks` 無持久化前例 | `store/modules/tab/index.ts:63,349-352`；`packages/hooks/src/use-table.ts:76` |
| E9 | `TableHeaderOperation` 有 `#suffix` slot 可塞按鈕（無侵入） | `src/components/advanced/table-header-operation.vue:76` |
| E10 | axios qs 預設 `indices` 陣列序列化 → 改用單一 `sort` 字串 | `packages/axios/src/options.ts:52-54`（qs 6.15.1） |
| E11 | 後端排序全寫死 facade、無一從 request；無字串→Column 動態映射 | `sys_user.rs:181`、`sys_role.rs:113`；grep `Column::from_str` 零命中 |
| E12 | 白名單→2222 既有範式可沿用 | `normalize_endpoint_method` / `normalize_rejects_non_whitelisted`（`system_manage.rs` 測 `:3405-3417`） |

## 7. 測試 / 驗收策略

- **單元（rust）**：`parse_sort_spec`（空 / 非法方向 / 重複欄 → 2222）＋每個 `resolve_*_sort`（白名單命中 / 拒絕）。純函式、好測。
- **單元（前端）**：composable 的點擊序維護（append / toggle / remove）、第一下→ascend 修正、wire 字串生成、localStorage 讀寫往返。
- **acceptance（curl + CDP，curl≠modal 紀律）**：
  - curl：多欄 `?sort=userName:asc,status:desc` 驗回傳順序；空 param 驗回預設；非法欄位 / 方向驗 2222；curl 刻意帶空 param 模擬前端。
  - **CDP browser smoke**：實點多欄、驗 3-state 循環（**naive-ui 原生：第一下反序**）、清除鈕、**換頁回來還原**、箭頭狀態。
- **不新增 workspace crate**（只加模組 / fn）→ 不強制 prod image build；照常 dev 容器內 `cargo build`/`test`（rust serial、`docker exec`、live smoke 帶 `DATABASE_URL`+`--test-threads=1`）。

## 8. 開放項（交 `/speckit-plan`）

1. **每頁可排序欄位清單**：逐頁列舉（預設「真正的 DB 純量欄」可排；排除 join/computed 欄如 user 角色徽章、操作鈕欄、index 欄），spec-review 時給 user 確認。
2. `parse_sort_spec` 是否抽共用結構 `#[serde(flatten)] SortQuery` vs 每 endpoint inline `sort: Option<String>`：驗證 serde flatten + axum Query 抽取相容性（不相容則 inline）。
3. 持久化是否於 logout 清除：傾向不清（UI 偏好、無害），plan 定。
4. `useTableSort` 與 `useNaivePaginatedTable` 整合點：sort 變動 reset 回第 1 頁的觸發方式。
5. **sort 狀態管理＝非受控 vs 受控**：非受控最簡（payload＝點擊序、無覆寫），但多欄持久化還原（多個 `defaultSortOrder` 同時生效）未驗；plan 容器 CDP 驗非受控多欄還原，不可靠則退受控（`sortOrder` 多欄還原已驗 E4）。

## 9. 不做的事（YAGNI / 範圍邊界）

- ❌ 不做純前端 / 單頁排序（D1：分頁表語意錯）。
- ❌ 不把排序反映進瀏覽器網址列 / SPA 路由 query（持久化走 localStorage、不污染 URL；對齊現有 searchParams 不入 URL 的慣例）。
- ❌ 不顯示多欄優先序號碼（D7）。
- ❌ menu 不納入（樹狀）。
- ❌ 不覆寫 naive-ui 排序循環（D4：原生第一下反序即可、最簡、不寫 `customNextSortOrder` 或 handler 改寫）。
- ❌ 不做全站泛型 `SortQuery` resolver 框架（過度抽象；共用僅止於 `parse_sort_spec` + per-entity match）。
