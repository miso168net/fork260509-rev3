# Data Model: 007-audit-overlay（Phase 1）

**Date**: 2026-06-15 | **Branch**: `007-audit-overlay` | 來源：[research.md](research.md)（R2/R6）+ m001 actual

> **無 migration**：三 log 表已在 m001（波 0 一次全建 ⚠️t、archetype B append-only §I.6）。本刀新增 = 2 個 entity Model（鏡像既有表）+ 1 個既有 Model 的型遷移（`sys_operation_log.operator_ip`）+ in-memory event/context 結構。下列型以 sea-orm `with-ipnetwork` 為前提。

---

## 1. DB 實體（entity crate，逐欄鏡像 m001）

### 1.1 `sys_access_log`（新 Model；archetype B append-only）

| 欄 | 型（DB） | Rust（entity Model） | 約束 |
|---|---|---|---|
| `id` | BIGINT PK auto | `i64` | PK |
| `operator_id` | BIGINT **NOT NULL** | `i64` | 必填——「已認證才寫」結構落地（FR-001/002） |
| `method` | TEXT NN | `String` | |
| `path` | TEXT NN | `String` | |
| `http_status` | INTEGER NN | `i32` | |
| `client_ip` | INET NN | `ipnetwork::IpNetwork` | 解析後真實 client IP（FR-006） |
| `x_forwarded_for` | TEXT NULL | `Option<String>` | 原始 XFF 鏈備查（FR-008） |
| `region` | TEXT NULL | `Option<String>` | xdb 解、best-effort（FR-009） |
| `trace_id` | TEXT NULL | `Option<String>` | 追蹤 id（FR-010） |
| `created_at` | TIMESTAMPTZ NN default now | `DateTimeWithTimeZone` | |

- **無更新/刪除路徑**（append-only §I.6 B；FR-014）；facade 只暴露 `write`。
- **無額外 index**（R2）。

### 1.2 `sys_login_attempt`（新 Model；archetype B append-only）

| 欄 | 型（DB） | Rust（entity Model） | 約束 |
|---|---|---|---|
| `id` | BIGINT PK auto | `i64` | PK |
| `attempted_user_name` | TEXT NN | `String` | 嘗試帳號（成敗皆記） |
| `success` | BOOLEAN NN | `bool` | |
| `operator_id` | BIGINT **NULL** | `Option<i64>` | 成功 Some(user.id)／失敗 None（FR-005） |
| `client_ip` | INET NN | `ipnetwork::IpNetwork` | 真實 client IP（含未認證 /login、FR-011） |
| `x_forwarded_for` | TEXT NULL | `Option<String>` | 原始 XFF 備查 |
| `region` | TEXT NULL | `Option<String>` | |
| `trace_id` | TEXT NULL | `Option<String>` | |
| `created_at` | TIMESTAMPTZ NN default now | `DateTimeWithTimeZone` | |

- **2 index（既有 m001）**：`idx_login_attempt_ip_time (client_ip, created_at)`、`idx_login_attempt_user_time (attempted_user_name, created_at)` —— 為未來 lockout（⚠️w）的 per-ip / per-user 查詢服務（**本刀只備資料、不查**）。

### 1.3 `sys_operation_log`（既有 Model 型遷移；R6／FR-013／§3.8）

| 欄 | 變更 | 說明 |
|---|---|---|
| `operator_ip` | `Option<String>` → **`Option<ipnetwork::IpNetwork>`** | 解 005 defer 的 42804；facade 啟用現 defer 的 `Some(ip)` 分支寫真 INET |
| `operator_id` / `trace_id` | 無型變、由 None→真值 | 由 audit_ctx 餵 RequestContext（005 機制本就有欄、恆 None） |

- 其餘 10 欄不動（005 已建）。**005 既有 None-path 純測/live smoke 不破**（R6）；新增 Some(ip)-path 測。

---

## 2. In-memory 結構（server crate，非 DB）

### 2.1 `RequestContext`（每請求一份、跨三 sink 共用；audit_ctx 建、塞 extensions）

```
RequestContext {
  operator_id:      Option<i64>,     // 寬鬆 bearer 抽取：成功 Some / 任何失敗 None（永不 reject）
  client_ip:        IpAddr,          // resolve_client_ip 解析後真實 IP（注意：IpAddr，非 IpNetwork）
  x_forwarded_for:  Option<String>,  // 原始 XFF 鏈字串
  region:           Option<String>,  // xdb best-effort
  trace_id:         String,          // honor x-request-id（≤64 char）/ uuid v4
}
```

- **無條件**對每請求建立（含未認證、P1）；`Extension(ctx)` 供 handler 讀。
- **型 seam**：context 持 `IpAddr`；`IpAddr→IpNetwork` 轉換**只在 facade 層**（R1 risk、§2.14 分離關注）。

### 2.2 `AccessLogEvent` / `LoginAttemptEvent`（facade 入參 → ActiveModel）

```
AccessLogEvent { operator_id: i64, method: String, path: String, http_status: i32,
                 client_ip: IpAddr, x_forwarded_for: Option<String>, region: Option<String>, trace_id: String }
LoginAttemptEvent { attempted_user_name: String, success: bool, operator_id: Option<i64>,
                    client_ip: IpAddr, x_forwarded_for: Option<String>, region: Option<String>, trace_id: String }
```

- facade `*_active_model(Event) -> ActiveModel`〔純映射 seam、可純測；`IpNetwork::from(client_ip)`〕＋`write(&db, &Event) -> Result<(), DbErr>`〔單 INSERT〕。

### 2.3 `resolve_client_ip`（純函式、安全敏感、test-first）

```
resolve_client_ip(peer: IpAddr, xff: Option<&str>, trusted: &[IpNetwork]) -> IpAddr
  ① peer ∉ trusted            → return peer（不信任何 forwarded、擋偽造／dev）
  ② XFF 由右往左、跳 trusted   → 第一個 ∉ trusted = 真實 client
  ③ 全 trusted / 無 XFF        → return peer（fail-safe）
```

- `is_trusted` = `ipnetwork::contains`；`IpAddr::from_str` 解析每 token（畸形略過）。
- 配置：`TRUSTED_PROXY_CIDRS` env → `Vec<IpNetwork>`，未設/parse 失敗→空（fail-safe）。

---

## 3. 驗證規則 / 不變式（從 FR 導出）

- access-log：`operator_id.is_some()` 才產生 AccessLogEvent（FR-001/002）；`operator_id` 非空（NOT NULL 結構保證）。
- login-attempt：每登入終端路徑 exactly-one（6 呼叫點、FR-004）；失敗 operator_id=None。
- 所有審計 write **best-effort**（FR-012）：`best_effort_audit` 吞 DbErr、不阻請求。
- 三表 append-only（FR-014）：facade 不暴露 update/delete。
- client_ip：解析後真實 IP（FR-006）；不可信來源 forwarded 不採信（SC-003）；fail-safe peer（FR-007）。
- 原始 XFF 原文保存（FR-008、鑑識）。
- region 私有→非空「內網」類（FR-009）；best-effort、IPv6/查無→None（與 §I.6 不衝突：region 為 nullable domain 欄）。

## 4. 關係 / 狀態

- 三 log 表**無 FK、無狀態機**（archetype B append-only）；彼此獨立。
- RequestContext → 三 sink 單向餵（access-log in middleware／login-attempt in handler／op-log 回填 via `mutate_in_txn`）。
- 無生命週期轉換（append-only、不可竄改）。
