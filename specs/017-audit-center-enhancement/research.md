# Phase 0 Research: 017-audit-center-enhancement

**Date**: 2026-06-23 | **Method**: 3 唯讀研究 agent 對照實碼 grep（C-1/C-3/C-4 三鏈）。所有 file:line 為實證 ground-truth。

> CLAUDE.md §3 research 紀律：facade 真實返回型 grep／wire 3 端對齊／每 file:line 引用 grep 真實命名／list filter 空字串守門。本檔固化之，並解決 brainstorm 遺留問題。

---

## D0. 跨鏈關鍵實證（影響整刀）

- **casbin matcher 完全比對、無 super 繞過**：`m = g(r.sub,p.sub) && r.obj==p.obj && r.act==p.act`（`enforce.rs:48`）。`require_policy` 綁 (path,method)，三 audit 讀端點 R_SUPER policy 由 m005 seed（`main.rs:497/506/515`）。→ **C-3 export 走既有端點 query flag、不改 path/method → 零新 policy seed、零 migration、`endpoint_coverage_lint` 數不變**。
- **零 migration / 零新 crate / 零新端點** 三鏈皆成立。

---

## D1. C-1 — http_status 類別 quick-filter（僅 access-log）

**Decision**：access-log 加 `http_status_class`（"2xx"/"4xx"/"5xx"）；handler 純函式 `parse_http_status_class` → `Option<(i32,i32)>` 半開區間；facade 新 `apply_if` 範圍 filter，與既有單值 `eq` 並存（AND）。

**Rationale**：三端已對齊、entity `http_status: i32`（`entity/src/sys_access_log.rs:15`）；既有 `parse_http_status`（`system_manage.rs:466-475`）為空字串守門範本可仿；NSelect 已 import（`access-log-table.vue:3`）→ 不觸發 components.d.ts 重生。

**Alternatives**：取代既有單值精確 filter（否決——spec FR-011 要並存）。

**Ground-truth**：
| 項 | file:line | 實況 |
|---|---|---|
| AccessLogFilter 11 欄、http_status eq | `sys_access_log.rs:71-84` / `:102` | `http_status:Option<i32>` → `Col::HttpStatus.eq(s)`；多 apply_if = AND |
| entity HttpStatus 型 | `entity/src/sys_access_log.rs:15` | `i32`（非 Option）→ 範圍用 `gte(lo).and(lt(hi))` |
| AccessLogQuery（camelCase） | `system_manage.rs:262-276` | 全 Option；`http_status:Option<String>`；加 `http_status_class:Option<String>` → wire key 自動 `httpStatusClass` |
| handler 組 filter | `system_manage.rs:1821-1833` | `http_status: parse_http_status(...)?`；新增 `http_status_class: parse_http_status_class(...)?` |
| parse_http_status 範本 | `system_manage.rs:466-475` | None/Some("")→Ok(None)；非數→Err(Biz) |
| base-web searchParams / NSelect | `access-log-table.vue:25-39` / `:173-179` / `:3` | 加 `httpStatusClass:null` + reset；NSelect 已 import |
| typing AccessLogSearchParams | `rev3-system-manage.d.ts:215-229` | 加 `httpStatusClass: string`（值域 '2xx'\|'4xx'\|'5xx'；RecordNullable 自動 nullable） |
| pruneNullParams | `rev3-system-manage.ts:280-293` | 剔除 null/空字串 → class 未設時 wire 缺席（handler 收 None） |
| i18n Schema / locale | `app.d.ts:905-928` / `zh-cn.ts:683,702` `en-us.ts:687,706` | 先 Schema 後 locale（base-web-i18n-schema gotcha） |

**★ 風險/紀律**：
- `parse_http_status_class` 對**無法識別值回 `Ok(None)` 略過**（spec FR-012），**異於** `parse_http_status` 對畸形回 `Err(2222)`——dropdown 來源受限、不回 2222。**勿照抄 Err 分支**。
- 半開區間：2xx=[200,300)、4xx=[400,500)、5xx=[500,600)（避免 lte 邊界含 600）。
- class typing 用 `string`（勿沿 `httpStatus:number` 的 number↔string 隱轉）。
- 空字串守門仍須具備（curl 可帶空 param；modal 軌走缺席路徑）。

---

## D2. C-3 — CSV 匯出（approach B：既有 3 讀端點加 export query flag、CSV-in-envelope、cap 10000）

**Decision**：三讀 handler（getOperationLog/getAccessLog/getLoginAttempt）Query DTO 加 `export: Option<String>`；export 時 facade `list(db, page=0, size=CSV_EXPORT_CAP=10000, filter)`（**繞過 normalize_size**）→ 序列化已組好的 `*Item` 成 CSV 字串（UTF-8 BOM、手寫 escaper、穩定英文表頭）→ `Res::ok(csv_string)`（envelope data 為 String）。base-web 新 export wrapper 回 `string` + 新 `downloadCsv` util（Blob+a[download]）；截斷 toast 依 `pagination.itemCount(=total) > CAP`。

**Rationale**：`Res::ok<T:Serialize>`（`envelope.rs:30-41`）對 String 序列化合法；export flag 不改 (path,method) → 既有 R_SUPER policy 覆蓋（零 migration）；flatRequest transform 回 `response.data.data`（`request/index.ts:27`）→ `request<string>` 直拿 CSV；復用 request 層 auth/envelope/錯誤 i18n。

**Alternatives**：(A) 3 個新 export 端點 → 需 R_SUPER policy seed＝migration + lint churn（否決）。raw text/csv 下載 → 需 auth-fetch helper（token 在 localStorage 非 cookie、browser nav 無 auth）且破 envelope transform（否決）。

**Ground-truth**：
| 項 | file:line | 實況 |
|---|---|---|
| 三讀 handler 返回型 | `system_manage.rs:1753/1812/1869` | 皆回 `Res<serde_json::Value>`；body：構 Filter → `facade::list(db,current-1,size,filter)` → enrich → `*Item` → PageRes → `Res::ok` |
| Query DTO | `system_manage.rs:242-294` | 三 Query（Default+camelCase）；加 `export` 欄不破 serde |
| Res::ok（data 為 String 可行） | `envelope.rs:30-41` | `to_value(String)`→JSON string；data→code→msg、code string、HTTP 200 |
| facade list（可 size=10000/page=0） | `sys_access_log.rs:88-122`（op/login 同形） | `list(conn,page:u64,size:u64,f)`；facade 無 size clamp |
| ★ normalize_size clamp | `system_manage.rs:434-436` | `clamp(1,100)`——**export 不可經此**、直傳 CAP |
| require_policy 綁路由 | `main.rs:497-520` | 三 audit GET R_SUPER；export query 不改路由 → policy 覆蓋 |
| request transform | `request/index.ts:14,26-28` | `transform → response.data.data`；`request<string>` 拿 CSV |
| 既有 rev3 wrapper | `rev3-system-manage.ts:300/313/326` | 加 3 export wrapper（回 `request<string>`、沿 pruneNullParams） |
| 無 Blob/download helper | base-web src grep | 全無；新寫 `downloadCsv`（excel demo 用 xlsx、不同路徑） |
| total 供截斷 | `hooks/common/table.ts:129` | `pagination.itemCount=data.total`；component 讀之判 >CAP |
| 三表 CSV 欄（*Item） | `system_manage.rs:302-357` | OperationLogItem/AccessLogItem/LoginAttemptItem 欄清單（已 enrich operatorName、IP to_string、payload Value） |
| 無 CSV escaper | `system_manage.rs:393-395`（僅 escape_like） | 新寫純函式（quote、`"`→`""`、逗號/換行安全、BOM） |

**★ 風險/紀律**：
- **export 絕不走 normalize_size**（否則 cap 被砍成 100）→ 直傳 `CSV_EXPORT_CAP=10000`、page=0。
- FR-008 中文不亂碼 → CSV 前綴 UTF-8 BOM（`\u{FEFF}`）；escaper 處理欄內逗號/雙引號/換行（op-log payload JSON 含這些）。
- **C-3 op-log 的 roles_before/after 專屬欄（FR-005a）依賴 C-4 先 enrich payload**→ tasks 排序 C-4 先於 C-3 op-log roles 欄；或 C-3 容忍 payload 無 roles key（顯空）。
- FR-009：export 復用 GET R_SUPER policy；C-V-2 仍須 curl 顯式驗「非 Super export 403」。
- CDP 須實測下載（檔名+內容+BOM）；curl 只驗 envelope body（curl≠modal）。
- export flag `Option<String>`+`parse_export`（"true"/"1"→true、其餘/空→false 略過、不 2222）；沿 audit handler Option<String>+parse 慣例。

---

## D3. C-4 — op-log 角色集 delta（全生命週期）

**★ brainstorm 遺留問題解答**：sys_user 只有**三**個寫端 facade build AuditEvent：`create`(Insert)/`update`(Update)/`soft_delete`(SoftDelete)。**無 `sys_user::batch_soft_delete`**——`deleteUser` 與 `batchDeleteUser` 共用 `soft_delete`（handler `batch_delete_user` loop 逐 id 呼，`system_manage.rs:945-972`）。改 `soft_delete` 一處即覆蓋兩條刪除路徑。三端 payload 現**皆無 roles**。

**Decision**：新增純函式 `with_roles(Value, &[String]) -> Value`（放 `audit.rs`、插 "roles" key、**排序 roles 後**入 `Value::Array`、空→`[]`）；三寫端 merge：
| facade | roles_before | roles_after |
|---|---|---|
| create（`sys_user.rs:279-289`） | （payload_before 維持 `None`、INSERT 語意） | `with_roles(after.audit_json(), role_codes)` |
| update（`sys_user.rs:300-337`、replace 前讀） | `with_roles(before.audit_json(), &roles_before)`〔`roles_of_user(&txn,id)` 改前讀〕 | `with_roles(after.audit_json(), role_codes)` |
| soft_delete（`sys_user.rs:51-87`、刪前讀） | `with_roles(before.audit_json(), &roles_before)` | `with_roles(after.audit_json(), &[])` |

**Rationale**：三端皆已 build AuditEvent + 寫 op-log（`audit.rs:84-97` `mutate_in_txn` → `sys_operation_log::write_in_txn`，唯一 sink、同 txn 原子）；`audit_json()` 回 `Value::Object`（可 insert）；`roles_of_user`（`sys_user_role.rs:29`）泛型接受 `&txn`（同 txn 一致快照）。create before 維持 None＝不污染 INSERT 語意（spec scenario 2「前快照角色為空」由 None 表達；CSV 端 None→[] 顯示）。with_roles 排序＝集合語意，spec scenario 4「未動角色不誤報」成立。

**Alternatives**：把 create before 改成 `Some({roles:[]})`（否決——污染 INSERT before=None 語意；改由 CSV/讀端 None→[] 處理）。roles 不排序（否決——roles_of_user 無 order_by、desired 順序任意、陣列序比對會偽報變更）。

**Ground-truth**：
| 項 | file:line | 實況 |
|---|---|---|
| create AuditEvent | `sys_user.rs:279-289` | Insert；before:None/after:audit_json；role_codes 第3參（初始角色、handler `:852` 傳 `&req.user_roles`） |
| update AuditEvent | `sys_user.rs:300-337` | Update；replace_roles `:320`；before/after:audit_json |
| soft_delete AuditEvent（del/batch 共用） | `sys_user.rs:51-87` | SoftDelete；**不**呼 replace_roles（角色關聯保留）；before/after:audit_json |
| ★ 無 batch_soft_delete user | `system_manage.rs:945-972` | batch_delete_user loop 逐 id 呼 soft_delete；batch_soft_delete 只在 sys_role/sys_menu |
| audit_json 欄（key 校正） | `sys_user.rs:22-43` | 16 欄 `json!({...})`→Object；**key 是 `current_session_id`**（非 brainstorm 寫的 "session"）；含 session_policy |
| roles_of_user | `sys_user_role.rs:29-53` | `<C:ConnectionTrait>(conn,uid)->Vec<String>`（接受 &txn）；**無 order_by** |
| replace_roles_in_txn | `sys_user_role.rs:117-154` | `(txn,uid,role_codes)`；呼於 create:278/update:320 |
| AuditEvent struct | `audit.rs:59-69` | payload_before/after `Option<serde_json::Value>`；AuditOperation: Insert/Update/SoftDelete/Restore |
| op-log sink | `audit.rs:84-97` + `sys_operation_log.rs:17-34` | mutate_in_txn → write_in_txn（payload_* 直 Set、同 txn）；唯一 sink |

**★ 風險/紀律**：
- **三端皆無 roles**（不只 update）；C-4 改三 facade。
- **create before 維持 None**；CSV 端（C-3）對 None→roles_before 顯空（data-model 明示、避免兩端各做一半）。
- `roles_of_user` 須在 mutate_in_txn 閉包內用 **`&txn`**（非 `&state.db`、避 race）。
- `with_roles` **排序 roles**（集合語意；scenario 4 不誤報）。
- **live op-log 斷言用自身 trace_id + entity_table 雙欄守門**（共享 seed entity_id 1/2/3 append-only、別 feature 累積；**絕不**對 entity_id 絕對列數斷言；沿 `sys_user.rs:864-872` 既有 pattern）。
- C-4 不新增 wire endpoint/不改 handler 返回型（內部 op-log payload enrich）。
