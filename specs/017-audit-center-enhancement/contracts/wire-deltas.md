# Wire Contract Deltas: 017-audit-center-enhancement

**Date**: 2026-06-23 | 零新端點；皆為既有 3 audit 讀端點的 query/response 增量 + op-log payload 內欄。envelope `{data,code,msg}` 不變、code string、HTTP 200（§I.3）。

---

## 既有端點（path/method 不變、R_SUPER policy 不變）

| 端點 | method | 既有 policy |
|---|---|---|
| `/systemManage/getOperationLog` | GET | R_SUPER（m005 seed） |
| `/systemManage/getAccessLog` | GET | R_SUPER（m005 seed） |
| `/systemManage/getLoginAttempt` | GET | R_SUPER（m005 seed） |
| `/systemManage/addUser` `/updateUser` `/deleteUser` `/batchDeleteUser` | POST | 既有（C-4 只動其 op-log payload、wire 返回不變） |

## C-1 query 增量（getAccessLog）

- 新 query param `httpStatusClass`（camelCase）：`"2xx"|"4xx"|"5xx"`，未設則缺席（pruneNullParams 剔除）。與既有 `httpStatus`（單值）並存（AND）。
- 無法識別/空 → 後端略過（不報錯、FR-012）。response shape 不變（PageRes<AccessLogItem>）。

## C-3 query + response 增量（三讀端點）

- 新 query param `export`（camelCase）：`"true"` 觸發匯出。
- **export=true 時 response 變體**：`{code:"0000", data:"<CSV 字串>", msg:...}`——`data` 為 CSV 文字（UTF-8 BOM 前綴）、**非** PageRes。未帶 export＝既有分頁 JSON（零變）。
- op-log（getOperationLog）export CSV 含專屬欄 `rolesBefore`/`rolesAfter`（自 payload 抽）+ 既有 `payloadBefore`/`payloadAfter`（JSON 字串入格）。
- cap：export 至多 10000 列；前端依 `total` 提示截斷（不在 wire）。
- **F6 已知契約形態**：export 使同一路由依 `query.export` 條件式回兩種 data shape（`PageRes<T>` / CSV `String`）；登記為已知形態，供日後 §I.3 契約 schema oracle（待決②）加 discriminator（依 `query.export` 分流 schema）、勿誤判 schema 漂移（rust 型均為 `Res<serde_json::Value>`、無編譯期 type-lie）。

## C-4 op-log payload 內欄增量（不改端點 wire 形）

- `sys_operation_log.payload_before`/`payload_after`（jsonb，既有）對 **sys_user 寫操作**（addUser/updateUser/deleteUser/batchDeleteUser）新增內欄 `roles`（排序後 string 陣列）：
  - addUser：`payload_after.roles` = 初始角色；`payload_before` = null（INSERT）。
  - updateUser：`payload_before.roles` = 改前；`payload_after.roles` = 改後。
  - delete/batchDelete：`payload_before.roles` = 刪前；`payload_after.roles` = `[]`。
- `current_session_id` 保留於 payload（不遮蔽、D3）。讀端 getOperationLog 的 `payloadBefore/After` 自然帶出 `roles`（讀端 DTO 不改）。

## 3 端對齊（無 type-lie）

- C-1：handler `AccessLogQuery.http_status_class:Option<String>` ↔ base-web `AccessLogSearchParams.httpStatusClass:string|null` ↔ component searchParams。wire key `httpStatusClass` 兩端一致。
- C-3：handler export 回 `Res<Value>`（data=String）↔ base-web export wrapper `request<string>`（transform 回 data.data）↔ component `downloadCsv(string)`。export wrapper 回 `string`（非 *List）。
