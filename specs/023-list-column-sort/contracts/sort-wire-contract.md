# Contract: 排序 wire 契約（023-list-column-sort）

對齊 constitution §I.3 wire 權威序與不變式。

## 請求（新增單一 query 參數）

7 個 list 端點各 inline 加 `sort: Option<String>`（camelCase rename `sort`）：

```
GET /systemManage/getUserList?current=1&size=10&userName=&sort=userName:asc,status:desc
```

- 格式：`field:dir` token 以 `,` 串接；**token 順序＝排序優先序**（首位主排序）。
- `dir` ∈ `asc` | `desc`。`field` ∈ 該端點白名單（data-model §3）。
- 未設 / 空字串 / 全空白 → 無排序（回該端點既有預設排序）。沿用空字串守門（`normalize_str_filter`）。

涉及端點：`getUserList` / `getRoleList` / `getOperationLogList` / `getAccessLogList` / `getLoginAttemptList` / `getArchivedPolicyList` / `getIpRuleList`（實際 route 名以 `main.rs` 註冊為準、plan 對齊）。

## 回應（不變）

- 成功：既有 `PageRes<T>` = `{current,size,total,records}`（envelope `{data,code:"0000",msg}`）。排序後 `records` 順序反映 `sort`、tie-break by id。
- 排序非法（未白名單欄 / 非 asc·desc 方向 / 重複欄）：**business error `2222`**（HTTP 200 信封、`msg` = 穩定 i18n key `biz.common.invalidSort`）。**絕不** 5000、絕不回錯排資料。

## 匯出（FR-016）

- operation/access/login 三審計頁：list 端點帶 `export=true` 時，匯出 CSV **反映同一 `sort`**（與 list 共用 facade 查詢、只差 page/size）。
- user/role/ip-rule/archive 無匯出、不涉。

## 不變式檢核（plan/實作對齊）

- envelope/code/PageRes 形不變；id 序列化不變（§I.3）。
- `sort` 為**新增** query 欄、不刪改既有 filter/分頁欄。
- 字串永不落進動態 SQL：`field` 經 per-entity `match` 映 `Column`（白名單）後才入 `order_by`。
- 未指定 `sort` 時各端點回傳**逐列等同**導入前（預設排序保留）。
