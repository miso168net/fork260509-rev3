# 017-audit-center-enhancement — spec-design（Phase 0 brainstorm）

> CLAUDE.md §3 階段 0 產物。交棒 → 手動 `/speckit-specify`（input＝本檔）起 017 feature branch。
> 日期：2026-06-23。來源：[INTEGRATION-CHECKLIST §3.C](../INTEGRATION-CHECKLIST.md)（pre-波4 triage 後唯一 feature-grade 可做項）。

---

## 1. 背景與目標

審計中心（012 建、`/manage/audit` R_SUPER-only 三分頁）目前只能線上分頁瀏覽。本刀補三項 forensic/operational 可視性缺口（CHECKLIST §3.C 的三個 doable 子項，user 拍板組一刀）：

| 子 | 缺口 | 核心目標 |
|---|---|---|
| **C-1** | access-log `http_status` 只能單值精確篩 | 按 2xx/4xx/5xx 類別快速篩 |
| **C-3** | 全無匯出能力 | 把（當前篩選的）審計紀錄抓下來離線分析/留存 |
| **C-4** | op-log payload 無角色欄→「誰把 user 角色 A→B」查不到 | 角色授予變更可事後追溯 |

**整刀紀律**：零 migration、零新 crate、零新端點。Constitution 預期 9/9 PASS。

---

## 2. 拍板紀錄（user 親決 2026-06-23 brainstorm）

| # | 決策 | 結論 |
|---|---|---|
| D1 | CSV 匯出範圍 | **三表（operation/access/login）+ 跟當前篩選 + 上限 1 萬列** |
| D2 | C-4 角色 delta 覆蓋 | **updateUser + addUser + 停用/刪除 全生命週期** |
| D3 | current_session_id 遮蔽 | **保留（不遮蔽）**——可做 forensic session 關聯 |
| D4（工程拍） | C-1 filter UX | class 下拉與既有精確值輸入**並存**（非取代） |
| D5（工程拍） | C-3 機制 | **query-param 變體 + CSV-in-envelope**（approach B，見 §4.2） |

---

## 3. Phase 0 研究實證（grep ground-truth、act-on-code）

brainstorm 期間對照實碼確認（exact 行號於 `/speckit-plan` research.md 再固化）：

- **★ casbin matcher＝完全比對、無 super 繞過**：`m = g(r.sub,p.sub) && r.obj==p.obj && r.act==p.act`（`enforce.rs:48`）；`require_policy` DB-fresh roles 後 `enforce_role_path_method`（`enforce.rs`）。**R_SUPER 每端點需顯式 policy 列、無 wildcard**。→ 直接決定 C-3 不開新端點（新端點需 R_SUPER policy seed＝動 migration）。
- **3 audit 讀端點**：`get_operation_log`（handler `:1753`）/`get_access_log`（`:1812`）/`get_login_attempt`（`:1869`），各有 filter DTO + facade `list`（分頁）；main.rs audit group 掛 `require_policy` R_SUPER。
- **C-1**：`AccessLogFilter.http_status: Option<i32>` 單值 `eq`（`sys_access_log.rs:76` / `:102`）；前端 `access-log-table.vue:174` 單一 NInputNumber。**op-log/login 表無 status 欄**（C-1 僅 access-log）。
- **C-4**：`sys_user::update`（`sys_user.rs:300-337`）build `AuditEvent`，`payload_before/after = before/after.audit_json()`（**無 roles**）；`replace_roles_in_txn`（`:320`）同 txn 改角色但未進 payload；`sys_user_role::roles_of_user(conn,uid)`（`sys_user_role.rs:29`）可讀改前角色；`AuditEvent.payload_*: Option<serde_json::Value>`（`audit.rs:63-64`、jsonb）。`audit_json()` 含 `current_session_id`（"session" 欄）。
- 全 repo **無** export/csv/download 端點。

---

## 4. 各子功能設計

### 4.1 〔C-1〕http_status 類別 quick-filter（僅 access-log）

- **rust**：`AccessLogFilter` 加 `http_status_class: Option<String>`（"2xx"/"4xx"/"5xx"）。handler 純函式 `parse_http_status_class` → `(lo,hi)`〔200-299／400-499／500-599〕；空字串/未識別值 → `None` 略過（dropdown 來源已受限、同 list-filter 空字串守門紀律、不回 2222）；識別 2xx/4xx/5xx → 範圍。facade `apply_if` 範圍 filter（`HttpStatus.gte(lo) AND HttpStatus.lt(hi)`），與既有單值 `eq` **並存**（兩者皆設＝AND、罕見但合理）。
- **base-web**：`access-log-table.vue` searchParams 加 `httpStatusClass`；class NSelect（全部/2xx/4xx/5xx）置既有精確 NInputNumber 旁；rev3 typing 加欄；i18n（label）+ app.d.ts Schema（**先 Schema 後 locale**、base-web-i18n-schema gotcha）。
- 零 migration。

### 4.2 〔C-3〕CSV 匯出（query-param 變體、三表、當前篩選、cap 10k）

**approach B（採）**：3 讀端點 query DTO 加 `export: Option<bool>`。handler 分支：
- `export=true` → facade 撈當前篩選結果（page=1、size=`CSV_EXPORT_CAP=10000`）→ 後端序列化 CSV → 回 envelope `{code:"0000", data:"<csv 字串>", msg:""}`。
- 否則 → 正常分頁 JSON（既有行為零變）。

**同 path+method → 既有 R_SUPER policy 覆蓋 → 零 migration / 零新端點 / 零 ALL_ENDPOINT_POLICIES·endpoint_coverage_lint 變動。**

**approach A（否決、記錄理由）**：3 個新 export 端點 → 各需 R_SUPER policy seed＝**動 migration** + registry/lint churn。被 B 取代。

**CSV-in-envelope（非 raw text/csv、記錄理由）**：token 在 localStorage（非 cookie）→ browser nav 直下載無 auth；raw text/csv 需另寫 auth-fetch helper 且破 request 層 envelope transform。CSV-in-envelope 復用 request 層（auth/envelope/錯誤 i18n），cap 使 payload 有界。

- **CSV 序列化**：後端手寫最小 escaper（每欄 quote、`"`→`""`、含逗號/換行/quote 安全；**零新 dep**）。欄＝各表 wire DTO 欄；表頭用**穩定英文 field key**（分析友善、無 locale 歧義）；op-log `payload`（jsonb）以 JSON 字串入單格。前綴 **UTF-8 BOM**（`﻿`，Excel 中文相容）。
- **base-web**：每 tab 一「匯出」鈕 → rev3 export wrapper（帶當前 filter + export 旗標）→ `res.data`(csv) → `new Blob([data], {type:'text/csv;charset=utf-8'})` + `a[download]` 觸發（檔名 `<table>_<timestamp>.csv`）；i18n。
- **截斷信號**：前端已知當前分頁 total；若 `total > CAP` → 匯出後 toast「僅匯出前 1 萬列」（複用既有 total、無需後端再算）。
- 零 migration。

### 4.3 〔C-4〕op-log 角色集 delta（全生命週期）

對 user 寫端 enrich op-log payload 注入 `roles_before`/`roles_after`（merge 進 `audit_json()` 回的 `Value::Object`）：

| 寫端 | roles_before | roles_after |
|---|---|---|
| updateUser（含 status=2 停用） | `roles_of_user` 改前讀 | `role_codes` 參數（desired） |
| addUser | `[]` | 初始 `role_codes` |
| deleteUser / batchDelete | `roles_of_user` 刪前讀 | `[]`（已刪） |

- merge helper：`fn with_roles(v: Value, roles: &[String]) -> Value`（插 `"roles"` key、`Vec<String>→Value::Array`；roles 空＝`[]` 非 null）。
- `current_session_id` **保留**（不改 `audit_json`、D3）。
- 寫端覆蓋以「該 facade 是否 build op-log AuditEvent」為準（updateUser 確定；addUser/delete facade 於 plan research 確認 AuditEvent 建構點再 merge）。
- 零 migration（payload 既有 jsonb）。**live op-log 斷言用 trace_id/delta 隔離**（oplog-count 非冪等教訓）。

---

## 5. Acceptance（C-V contracts、plan 細化）

- **C-V-0**：build／兩 lint〔`endpoint_coverage_lint` 數**不變**＝零新端點佐證／`entity_access_lint`〕／typecheck。
- **C-V-1 純測**：`parse_http_status_class`（範圍/空/畸形）；CSV escaping（逗號/quote/換行/JSON cell/BOM）；`with_roles` payload 形。
- **C-V-2 curl**：access-log `?http_status_class=4xx` 收窄；export（Super 200 回 CSV body、非 Super 403）；三表 export 各驗。
- **C-V-3 psql**：updateUser/addUser/deleteUser 後 op-log `payload_before/after` 含 `roles_before/after`（trace_id 隔離自身寫）。
- **C-V-4 CDP**：class filter UI 收窄列；三 tab 匯出鈕下載 `.csv`（檔名+內容+BOM）；op-log payload 展開顯角色 delta。
- **C-V-5 回歸**：zero-migration（`git diff <base>..HEAD migration/` 空）+ prod target image build + 既有 audit 分頁/篩選行為零回歸。

---

## 6. 軌道 / Constitution

- **rust**：RUSTAPI-SOURCE-ISOLATION（新 facade 分支/handler export 分支/純函式；C-4 只動 op-log payload、**不涉 casbin policy 寫**）。
- **base-web**：audit 中心頁（`views/manage/audit/*`）為 012 rev3 自建（非 frozen）、可直接改；export wrapper 走 BASE-WEB-WRAPPER（`rev3-*.ts` 新 fn）；typing 加欄 BASE-WEB-ADAPT；i18n inline ⚠️aa BASE-WEB-I18N-WIRING。
- **Constitution**：零 migration/crate；無 retrofit（不動 archetype 審計欄）；§I.7 casbin 不涉。預期 **9/9 PASS**。

---

## 7. 風險 / edge

- CSV cap 10k 截斷 → 前端 toast 提示（依既有 total）。
- CSV 中文 Excel → UTF-8 BOM。
- op-log merge → `audit_json()` 須回 `Object`（已是）；roles 空用 `[]` 非 null。
- export envelope CSV 大 payload（10k×多欄）→ 可接受（admin 操作、有界）。
- C-4 寫端覆蓋以實際 AuditEvent 建構點為準（plan research 固化 addUser/delete facade 行號）。
- live op-log 斷言非冪等 → trace_id/delta 隔離。

---

## 8. Out of scope

- **C-2** 模糊 LIKE → `pg_trgm` GIN：scale-gated（需 CREATE EXTENSION + migration + 量大才值），defer。
- **C-5** archive 表 retention/purge：spec 明示不做、⚠️n log-retention 家族、obs 波/量大時統一處理，defer。

---

## 9. 交棒

手動 `/speckit-specify`（input＝本檔）起 `017-audit-center-enhancement` feature branch（CLAUDE.md §3 階段 1；`before_specify` pre-hook 建 branch）。**不 auto-chain、不用 superpowers:writing-plans**（CLAUDE.md §3 覆寫 skill 終態：SDD 鏈 specify→clarify→plan→tasks→analyze，再階段 2 `superpowers:executing-plans` + Workflow 驅動實作）。
