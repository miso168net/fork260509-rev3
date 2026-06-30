# Data Model: 列表欄位排序（023-list-column-sort）

本功能**不新增資料表、不新增資料欄**；資料層改動僅一支 index-only migration（R7）。下列「實體」多為傳輸/狀態概念物件（非 DB table），加上權威的「欄位名→Column」映射。

---

## 1. 概念實體

### SortSpec（排序規格）— 傳輸/狀態物件，非 DB

使用者對某列表的當前排序意圖。

| 欄位 | 型別 | 說明 |
|---|---|---|
| entries | `[(field, direction)]` 有序 | 有序清單；**順序＝優先序**（首位為主排序）|
| field | string（camelCase） | 前端 column key；後端 resolver 映 `Column`（見 §3 白名單）|
| direction | `asc` \| `desc` | 升/降 |

- **wire 表示**：單一字串 `field:dir,field:dir`（R1）。例 `userName:asc,status:desc`。
- **不變式**：field 必在該表白名單（否則 2222）；direction ∈ {asc,desc}（否則 2222）；field 不重複（否則 2222）；空字串/未設 → 空 SortSpec（回預設排序）。
- **深度上限**：天然＝該表可排序欄數（白名單 + 去重）；無額外數字 cap。

### PersistedSortState（已保留排序狀態）— localStorage，非 DB

| 欄位 | 型別 | 說明 |
|---|---|---|
| (key) | routeName | elegant-router route.name、per 列表頁唯一 |
| (value) | sort 字串 | 同 wire 格式 `field:dir,...` |

- 容器：單一 localStorage key（`StorageType.Local` 註冊）存 `Record<routeName, string>`（仿 tab store `cacheTabs`）。
- 生命週期：sort 變更時寫；mount 時讀回還原；clear-all 時刪該 route key。還原時防禦性丟棄非白名單/不存在欄（FR-015）。登出不清（無害 UI 偏好、clarify Outstanding）。

### SortableColumn（可排序欄）— 設定，非 DB

每列表「被允許排序的欄」＝該表白名單成員（§3）。前端 column 加 `sorter:{multiple:N}` + 受控 `sortOrder` 啟用。

---

## 2. Index migration（m008，唯一資料層改動）

| 項目 | 值 |
|---|---|
| 檔 | `rust-api/migration/src/m008_<name>.rs`（接 m007 後；`lib.rs:20`/`:35` 註冊）|
| 動作 | `CREATE INDEX idx_login_attempt_created_at ON sys_login_attempt (created_at)` |
| 性質 | 非 unique、非 partial、單欄；對齊 operation/access 既有 `m005` 單欄 created_at 索引 |
| up | 建索引 |
| down | drop 索引（`DROP INDEX idx_login_attempt_created_at`）|
| 理由 | login_attempt 預設排序欄 created_at 現無專屬索引（只在複合索引第二欄）；補唯一真缺口（clarify Q1）|

- **不觸 §I.6**：非新表、非加業務欄、僅加索引 → 審計欄 archetype 規則不適用。
- **不改 entity**：索引純 DB 層、SeaORM entity Model 不變（entity 不宣告索引）。

## 3. 欄位名 → Column 權威映射（per entity resolver 白名單）

每個 `resolve_<entity>_sort` 的 match arm。**這是防注入白名單的單一真相**。

| entity | 前端 key → `Column` 變體 |
|---|---|
| sys_user | userName→UserName, userGender→UserGender, nickName→NickName, userPhone→UserPhone, userEmail→UserEmail, status→Status |
| sys_role | roleName→Name, roleCode→Code, roleDesc→RoleDesc, status→Status |
| sys_ip_rule | cidr→Cidr, ruleType→RuleType, order→Order, description→Description, createTime→CreatedAt, updateTime→UpdatedAt |
| sys_operation_log | createTime→CreatedAt, operation→Operation, entityTable→EntityTable, entityId→EntityId, operatorIpConfidence→OperatorIpConfidence, operatorPeerIp→OperatorPeerIp, operatorRealIp→OperatorRealIp, operatorXForwardedFor→OperatorXForwardedFor |
| sys_access_log | createTime→CreatedAt, method→Method, path→Path, httpStatus→HttpStatus, ipConfidence→IpConfidence, peerIp→PeerIp, realIp→RealIp, xForwardedFor→XForwardedFor, region→Region |
| sys_login_attempt | createTime→CreatedAt, attemptedUserName→AttemptedUserName, success→Success, ipConfidence→IpConfidence, peerIp→PeerIp, realIp→RealIp, xForwardedFor→XForwardedFor, region→Region |
| sys_casbin_policy_archive | roleCode→V0, target→V1, archivedTime→ArchivedAt, createdTime→CreatedAt, archivedBy→ArchivedBy, archiveReason→ArchiveReason |

> ⚠️ plan 階段不信此映射、實作時 `grep` entity `Column` 真實變體名對齊（DeriveEntityModel 由 Model 欄位 PascalCase 生成）。`sys_ip_rule.Column::Order` 對應 DB 保留字欄 `order`（SeaORM 自動 quote）。

## 4. 預設排序（未指定 sort 時，不變）

| 表 | 現預設（sort 空時保留）| tie-breaker（sort 非空時）|
|---|---|---|
| sys_user | `order_by_desc(Id)` | Id desc |
| sys_role | `order_by_asc(Id)` | Id asc |
| sys_operation_log / access_log / login_attempt | `order_by_desc(CreatedAt, Id)` | Id desc |
| sys_casbin_policy_archive | `order_by_desc(ArchivedAt, Id)` | Id desc |
| sys_ip_rule | 多鍵（deleted/Order/Id）| Id（保留現邏輯）|
