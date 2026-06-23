# Phase 1 Data Model: 017-audit-center-enhancement

**Date**: 2026-06-23 | 來源：[research.md](research.md) ground-truth。**零 migration、零 schema 變更**——以下皆為 query DTO／in-memory filter／jsonb payload 形狀，無 DB 結構動。

---

## 1. C-1：http_status 類別 filter（僅 access-log）

### 1.1 `AccessLogFilter`（rust facade，`sys_access_log.rs`）
新增欄（既有 11 欄不動）：
```
pub http_status_class: Option<(i32, i32)>,   // parse 後的半開區間 [lo, hi)
```
- list fn 新 `apply_if`（緊鄰既有 http_status eq）：`Col::HttpStatus.gte(lo).and(Col::HttpStatus.lt(hi))`，與既有單值 eq 並存（AND）。

### 1.2 `AccessLogQuery`（rust handler，`system_manage.rs`）
新增欄（serde camelCase → wire `httpStatusClass`）：
```
pub http_status_class: Option<String>,   // "2xx" | "4xx" | "5xx"
```
- handler 組 filter 時：`http_status_class: parse_http_status_class(q.http_status_class.as_deref())?`

### 1.3 `parse_http_status_class`（rust 純函式，可測）
```
fn parse_http_status_class(v: Option<&str>) -> Result<Option<(i32,i32)>, AppError>
  None | Some("")            -> Ok(None)
  Some("2xx")                -> Ok(Some((200, 300)))
  Some("4xx")                -> Ok(Some((400, 500)))
  Some("5xx")                -> Ok(Some((500, 600)))
  Some(其他非空)              -> Ok(None)   // FR-012：無法識別→略過、★不回 2222（異於 parse_http_status）
```

### 1.4 `AccessLogSearchParams`（base-web typing，`rev3-system-manage.d.ts`）
```
httpStatusClass: string;   // 值域 '2xx'|'4xx'|'5xx'；RecordNullable 自動 nullable
```
- component searchParams 加 `httpStatusClass: null` + reset 重置；NSelect（已 import）綁定，選項 全部/2xx/4xx/5xx。

**驗證規則**：class 與既有 `httpStatus`（單值）並存＝AND（FR-011；同設 4xx+200 → 必空、合理）。

---

## 2. C-4：op-log payload 角色集（全生命週期、jsonb，零 migration）

### 2.1 `with_roles` helper（rust 純函式，`audit.rs`，可測）
```
pub fn with_roles(v: Value, roles: &[String]) -> Value
  // v.as_object_mut() 時 insert("roles", Value::Array(sorted(roles)))；空 roles -> []（非 null）
  // ★ roles 排序後入陣列（集合語意；scenario 4 未動角色不誤報）
```

### 2.2 op-log payload enrich（三寫端、`sys_user.rs`）
`payload_before`/`payload_after` 既為 `Option<serde_json::Value>`（jsonb）。各寫端注入 `roles`：
| facade | payload_before | payload_after |
|---|---|---|
| create（Insert） | `None`（維持 INSERT 語意；CSV/讀端對 None→roles 顯空） | `with_roles(after.audit_json(), role_codes)` |
| update（Update） | `with_roles(before.audit_json(), &roles_before)`〔`roles_of_user(&txn,id)` replace 前讀〕 | `with_roles(after.audit_json(), role_codes)` |
| soft_delete（SoftDelete、del+batch 共用） | `with_roles(before.audit_json(), &roles_before)`〔刪前讀〕 | `with_roles(after.audit_json(), &[])` |

- `roles_of_user` 須用 `&txn`（同 txn 一致快照）。
- `audit_json()` 既含 `current_session_id`（★ key 名為 `current_session_id`、非 "session"）——**保留不遮蔽**（拍板 D3）；`roles` 為新增 key、不撞名。
- **不**新增 wire endpoint、不改 handler 返回型（addUser/updateUser/deleteUser/batchDeleteUser 仍回 `Res::ok(null)`）。

**狀態轉移**（角色快照 by operation）：Insert→after 有 roles；Update→before/after 各快照；SoftDelete→before 有 roles、after 空。

---

## 3. C-3：CSV 匯出（query DTO + envelope data，零 migration）

### 3.1 export 旗標（三讀 Query DTO，`system_manage.rs`）
`OperationLogQuery`/`AccessLogQuery`/`LoginAttemptQuery` 各加：
```
pub export: Option<String>,   // export wrapper 送 "true"
```
- `parse_export(Option<&str>) -> bool`：`Some("true")|Some("1")` → true；其餘/空 → false（不 2222）。（F9：前端 wrapper 僅送 `"true"`；`"1"` 為 curl 便利的額外接受值、無前端消費端。）

### 3.2 export 分支（三 handler）
```
if parse_export(q.export.as_deref()) {
    let (rows, _total) = facade::Xxx::list(&db, 0, CSV_EXPORT_CAP, filter).await?;  // ★ page=0/size=CAP、繞過 normalize_size
    // 重用既有 enrich + 組 *Item 邏輯
    let csv = records_to_csv(headers, items);   // UTF-8 BOM + escaper
    return Ok(Json(Res::ok(csv)));              // envelope data = CSV String
}
// else 既有分頁路徑零變
```
- `const CSV_EXPORT_CAP: u64 = 10000;`

### 3.3 CSV 欄（穩定英文 field key、來源＝既有 `*Item` DTO）
| 表 | CSV 欄（依 *Item，`system_manage.rs:302-357`） |
|---|---|
| operation | id, operation, entityTable, entityId, operatorId, operatorName, operatorRealIp, operatorPeerIp, operatorXForwardedFor, operatorIpConfidence, traceId, createTime, **rolesBefore, rolesAfter**（FR-005a、自 payload 抽）, payloadBefore, payloadAfter（JSON 字串入格） |
| access | id, operatorId, operatorName, method, path, httpStatus, realIp, peerIp, ipConfidence, xForwardedFor, region, traceId, createTime |
| login | id, attemptedUserName, success, operatorId, operatorName, realIp, peerIp, ipConfidence, xForwardedFor, region, createTime |

- **op-log rolesBefore/rolesAfter**（FR-005a）：自 `payloadBefore["roles"]`/`payloadAfter["roles"]` 抽（C-4 enrich 後存在）。**F5 空值語意（延續 FR-004「空集合 vs 未記錄」可區分）**：payload 有 roles key 但空陣列 → 輸出 `[]`；payload 為 None 或無 roles key（非 user 寫操作／舊資料／INSERT before）→ 輸出空字串。payloadBefore/After 完整內容仍保留為獨立欄（JSON 字串、**F2 經 `csv_escape_field` 轉義**——含逗號/雙引號/換行不破欄位對齊）。
- CSV escaper：每欄 quote、`"`→`""`、含逗號/換行/quote 安全；整檔前綴 `\u{FEFF}` BOM。

### 3.4 CSV 序列化 helper（rust 純函式，可測）
```
fn csv_escape_field(&str) -> String          // quote + " 轉義
fn records_to_csv(headers: &[&str], rows: Vec<Vec<String>>) -> String   // BOM + 表頭 + 列
```

### 3.5 base-web export 端（`rev3-system-manage.ts` + 新 util）
- 3 export wrapper：`fetchExportOperationLog/AccessLog/LoginAttempt(params)` → `request<string>({url, method:'get', params: pruneNullParams({...params, export:'true'})})`（回 `string`、非 *List）。
- `downloadCsv(csv, filename)` util（`src/utils/`）：`new Blob([csv],{type:'text/csv;charset=utf-8'})` + `a[download]`；檔名 `<table>_<timestamp>.csv`。
- 截斷 toast：component 讀 `pagination.itemCount`（=最近一次**同篩選 list 查詢**的 total）；`> CSV_EXPORT_CAP` → `$message.warning(exportTruncated)`。**F4 信號可靠性**：須以匯出前同篩選 list 的 total 為準（匯出前確保該分頁已載入，否則 itemCount 可能 stale/為當前頁 size）；total（查詢當下）與實際匯出列數的併發微小落差為低風險（審計表 append-only、admin 低頻）、可接受；嚴格保證可由後端 export 帶截斷旗標（follow-up、非本刀）。

---

## 4. i18n（base-web，先 Schema 後 locale）

`App.I18n.Schema` audit 區（`app.d.ts:905-928`）+ `zh-cn.ts`/`en-us.ts` audit 區（同 commit）新增：
- C-1：`page.manage.audit.col.statusClass` / `filter.httpStatusClass` + class 下拉選項 label（全部/2xx/4xx/5xx）
- C-3：匯出鈕 label（`btn.export` 或 common.export 復用）/ `msg.exportTruncated`

（皆 page.manage.audit UI i18n，非 backend.* 命名空間；不涉 BASE-WEB-I18N-WIRING 軌道。）
