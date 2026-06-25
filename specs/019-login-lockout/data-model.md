# Data Model: 019-login-lockout

> **0 schema 變更／0 migration／0 新 entity**。本刀對 `sys_login_attempt`（007/m001 建、m006 演進）**唯讀消費**。下列為新增的 read-path（facade count）＋ in-memory 決策邏輯，非資料模型異動。

## 1. 消費 entity（既有、唯讀、不動）

`entity::sys_login_attempt::Model`（`entity/src/sys_login_attempt.rs`、archetype B append-only）。lockout 只讀其中 4 欄：

| 欄 | 型 | lockout 用途 |
|---|---|---|
| `attempted_user_name` | `String` | per-user 計數 key |
| `real_ip` | `IpNetwork` | per-ip 計數 key |
| `success` | `bool` | 只計 `=false`（FR-005） |
| `created_at` | `DateTimeWithTimeZone`（DB-default `now()`） | 滑動窗 `>= since`（FR-006） |

**索引（既有、不動）**：
- `idx_login_attempt_ip_time (real_ip, created_at)` ← per-ip count
- `idx_login_attempt_user_time (attempted_user_name, created_at)` ← per-user count

## 2. 新增 facade read-path（`server/src/model/facade/sys_login_attempt.rs` append）

```rust
/// per-ip 時窗內失敗數（走 idx_login_attempt_ip_time）
pub async fn count_failed_by_ip_since<C: ConnectionTrait>(
    conn: &C, real_ip: IpNetwork, since: DateTimeWithTimeZone,
) -> Result<i64, DbErr>;
// WHERE real_ip = ? AND success = false AND created_at >= ?

/// per-user 時窗內失敗數（走 idx_login_attempt_user_time）
pub async fn count_failed_by_user_since<C: ConnectionTrait>(
    conn: &C, attempted_user_name: &str, since: DateTimeWithTimeZone,
) -> Result<i64, DbErr>;
// WHERE attempted_user_name = ? AND success = false AND created_at >= ?
```

**契約**：
- 回 `i64`（`.count(conn) as i64`）；DbErr 上拋（fail-OPEN 在 handler 端以 `.unwrap_or(0)` 收，D-07）。
- `real_ip` 之 `IpNetwork` **必須**與寫端同款 `IpAddr→IpNetwork` 轉換（host route /32·/128，D-04 ★ correctness）。
- entity 存取唯一管道＝facade（§I.5 RUSTAPI-SOURCE-ISOLATION；`entity_access_lint` 須維持綠）。

## 3. 決策邏輯（in-memory、純函式 + 常數）

```rust
// handler/auth.rs module const（D-06；runtime 可調為 defer/E4）
const PER_USER_THRESHOLD: i64 = 5;
const PER_USER_WINDOW_SECS: i64 = 900;   // 15 min
const PER_IP_THRESHOLD: i64 = 20;
const PER_IP_WINDOW_SECS: i64 = 900;     // 15 min

/// 純函式、test-first（red→green）；dimension-blind 回 bool（FR-012 不標哪軌觸發）
fn is_locked_out(ip_fails: i64, user_fails: i64) -> bool {
    ip_fails >= PER_IP_THRESHOLD || user_fails >= PER_USER_THRESHOLD   // OR 語意 = FR-003
}
```

**門檻語意**（FR-001/002、SC-001/002）：`>= N` 為「已有 N 次失敗 → 下一次擋」。即連續 5 次失敗（各正常回 1000）後，第 6 次起 `user_fails>=5` → 擋（2222）。

## 4. gate 狀態流（handler、無持久狀態）

```
POST /auth/login → handler 取 ctx（client_ip 走 013 真 IP 解析）
  since := (Utc::now() - 900s).into()
  ip_fails   := count_failed_by_ip_since(db, ctx.client_ip→IpNetwork, since).unwrap_or(0)   // fail-OPEN
  user_fails := count_failed_by_user_since(db, &req.user_name, since).unwrap_or(0)           // fail-OPEN
  r := if is_locked_out(ip_fails, user_fails) {
         Err((None, AppError::Biz("auth.login.locked")))      // 短路、跳過 login_inner（FR-009）
       } else {
         login_inner(state, &req).await                       // 既有 6 路徑不動
       }
  ── 既有單一寫點(196-212) ── write attempt(success=r.is_ok(), operator=r的op, ctx 四欄) best-effort
  return envelope(r)   // 鎖中=2222 / 既有=0000·1000·5000
```

**無新狀態儲存**（FR-006 滑動窗、E5）：lockout 不存任何 lock-state 欄/表；純對既有 attempt 列在窗內 count。gated 列亦寫入（success=false）→ count 含之 → sticky（FR-008）；舊失敗隨 `created_at` 滑出窗即自動解（FR-006）。

## 5. base-web i18n（新增 key、純 additive）

| 檔 | 變更（★ 先 Schema 後 locale、同 commit，否則 dict typecheck red） |
|---|---|
| `typings/app.d.ts:324` | `App.I18n.Schema.backend.auth.login` 加 `locked: string` |
| `locales/langs/zh-cn.ts` | `backend.auth.login.locked = '登录失败次数过多，请稍后再试'` |
| `locales/langs/en-us.ts` | `backend.auth.login.locked = 'Too many failed login attempts. Please try again later.'` |

rust 回 `msg="auth.login.locked"` → 前端 `translateBackendMsg` 補 `backend.` → `$t("backend.auth.login.locked")`（D-05）。**無 login form / 攔截器控制流改動**（R3）。

## 6. 不變式對映（spec FR → 實作點）

| FR | 落點 |
|---|---|
| FR-001/002 門檻 | consts + `is_locked_out` |
| FR-003 OR 語意 | `is_locked_out` `\|\|` |
| FR-004 真 IP | `ctx.client_ip`（013 解析、anti-XFF-spoof） |
| FR-005 只計失敗 | count `success=false` |
| FR-006 滑動窗自動解 | `created_at>=since`、0 狀態 |
| FR-007 成功不 reset | 純窗 count、無 reset-on-success 邏輯 |
| FR-008 sticky+審計留痕 | gated 列匯流既有寫點（success=false） |
| FR-009 鎖中跳帳密驗證 | gate 短路、不進 login_inner |
| FR-010 fail-OPEN | `.unwrap_or(0)` |
| FR-011/015 防枚舉 | 統一 1000 路徑(查無帳號亦寫失敗列)＋鎖中統一 2222 訊息、count 含不存在帳號 |
| FR-012/013 靜態在地化訊息 | `Biz("auth.login.locked")` + locale key |
| FR-014 零回歸 | 未達門檻 r=login_inner、6 路徑/13 碼不變 |
