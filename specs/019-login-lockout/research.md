# Phase 0 Research: 019-login-lockout

> act-on-code 接地（3 平行 Explore agent @ 2026-06-25），**不信 brainstorm 命名假設、以 as-built 為準**。以下 file:line 為實證凍結；行號會隨後續 commit 漂移，implementer 須 act-on-code 再核。
> 來源 brainstorm：`docs/superpowers/019-login-lockout.md`（§8 待固化 7 項於本檔逐一回答）。

## 1. rust 登入流程 as-built（gate 插點 + 寫點）

| 元件 | as-built | file:line |
|---|---|---|
| `login` handler | `pub async fn login(State, Extension(ctx): Extension<RequestContext>, Json(req): Json<LoginReq>) -> Result<Json<Res<Value>>, AppError>` | `server/src/handler/auth.rs:185-222` |
| `RequestContext` | 解析後真 IP 欄名＝**`client_ip: IpAddr`**（**非** `real_ip`）；另 `peer_ip: IpAddr`／`ip_confidence: Confidence`／`x_forwarded_for: Option<String>`／`region: Option<String>`／`trace_id: String` | `server/src/audit_ctx.rs:66-101` |
| `login_inner` | `async fn login_inner(state: &AppState, req: &LoginReq) -> Result<Success, (Option<i64>, AppError)>`；**不接 ctx** | `server/src/handler/auth.rs:59-177` |
| 6 終局路徑 | 查無帳號／密碼錯／停用＝統一 `AppError::LoginFailed`（**1000、防枚舉確認**，查無帳號 operator=None）；角色 DbErr／JWT 簽發／token DB 寫＝`AppError::Internal`（5000）；成功＝`Success`（0000） | `auth.rs:75-90,98-170` |
| 單一寫點 | handler 內 login_inner 後（行 196-212）一個 `facade::sys_login_attempt::write(&state.db, &LoginAttemptEvent{...})`、**best-effort**（`.map_err(\|e\| tracing::warn!(...))`、不改回應）；`success`/`operator_id` 由 `r` match 決定（`Ok→true,Some(uid)`／`Err((op,_))→false,*op`）；`real_ip: ctx.client_ip` | `auth.rs:196-212` |
| facade | `write(db,&e)->Result<(),DbErr>`(51-54)＋`list<C>(conn,page,size,f)->Result<(Vec<Model>,u64),DbErr>`(85-117)；**無 count-by-window**；時間 filter 範式 `Col::CreatedAt.gte(t)` | `server/src/model/facade/sys_login_attempt.rs` |
| `AppError::Biz` | `Biz(Cow<'static, str>)` → wire code **2222**、`msg`＝key 直通；既有 key 慣例 `<root>.<entity>.<condition>`、root∈{common,auth,biz,system}（如 `biz.systemSettings.locked`／`biz.audit.invalidDateRange`） | `server/src/error.rs:40-41,62,77` |
| 時鐘 | 全 codebase 用 `sea_orm::sqlx::types::chrono::Utc::now()`、**無 SQL `make_interval`**；窗 since 走 Rust 端 `(Utc::now()-Duration::seconds(N)).into()` 餵 `CreatedAt.gte` | `facade/sys_token.rs:76,337-340`；`auth.rs:107-109` |

## 2. sys_login_attempt entity / schema / 索引 + sea-orm count

| 項 | as-built | file:line |
|---|---|---|
| entity Model（11 欄） | `id:i64`／`attempted_user_name:String`／`success:bool`／`operator_id:Option<i64>`／**`real_ip:IpNetwork`**(`sea_orm::entity::prelude::IpNetwork`)／`peer_ip:Option<IpNetwork>`／`ip_confidence:Option<String>`／`x_forwarded_for:Option<String>`／`region:Option<String>`／`trace_id:Option<String>`／`created_at:DateTimeWithTimeZone` | `entity/src/sys_login_attempt.rs:1-27` |
| 建表 + 索引 | m001 建表(590-635)＋兩索引(799-819)：`idx_login_attempt_ip_time (real_ip, created_at)`／`idx_login_attempt_user_time (attempted_user_name, created_at)`——007 明文「為 ⚠️w lockout 備」 | `migration/src/m001_rev2_schema.rs:799-819` |
| 欄改名 | m006 `RENAME COLUMN client_ip→real_ip`＋ADD peer_ip/ip_confidence；**現用欄名＝`real_ip`**；索引名不變、PG 自動跟欄參照 | `migration/src/m006_audit_ip_forensics.rs:37-43` |
| count 範式 | `Entity::find().filter(...).count(conn).await?`（既有 `count_users_by_role_id`） | `facade/sys_user_role.rs:15-25` |
| `created_at` 來源 | DB-default `now()`（m001 建表；單一寫點不 set created_at）→ 寫端走 **DB 時鐘**、count `since` 走 **app 時鐘** | `m001`／`auth.rs:196-212` |
| 新 crate | **不需**；sea-orm 已含 `with-chrono`/`with-ipnetwork`；workspace members 不變（`server/migration/sea-orm-adapter/entity/xdb/cleanup-job`） | `rust-api/Cargo.toml` |

## 3. base-web 登入錯誤路徑 + i18n（wire 3 端對齊）

| 項 | as-built | file:line |
|---|---|---|
| 登入表單 | `pwd-login.vue:39` `authStore.login(...)`；**無 try/catch、無自訂 error 處理**、全委託全域攔截器 | `views/_builtin/login/modules/pwd-login.vue:39` |
| login wire | `fetchLogin` → `POST /auth/login` | `service/api/auth.ts:9-18` |
| 攔截器 | 2222（不在 LOGOUT/MODAL_LOGOUT/EXPIRED_TOKEN 碼清單）→ `onBackendFail` 回 null → `onError` 行 118 `translateBackendMsg(msg)` → `showErrorMsg` toast | `service/request/index.ts:40-139`；`shared.ts:44-64` |
| translateBackendMsg | `$t(('backend.'+msg))`——**前端自動補 `backend.` 前綴** | `locales/index.ts:25-27` |
| locale backend.auth | 既有 `login.failed`／`token.expired`／`session.{kicked,reLogin}`；新增 `login.locked` | `locales/langs/zh-cn.ts:823-869`／`en-us.ts:827-873` |
| Schema | `App.I18n.Schema.backend.auth` 巢狀宣告（行 324）；加 `locked: string` under `login` | `typings/app.d.ts:322-364` |

---

## 決策（Decision / Rationale / Alternatives）

### D-01 — count 方法形狀：兩個 typed facade fn
- **Decision**：facade 加 `count_failed_by_ip_since(conn, real_ip: IpNetwork, since: DateTimeWithTimeZone) -> Result<i64,DbErr>` 與 `count_failed_by_user_since(conn, user: &str, since) -> Result<i64,DbErr>`，各 `WHERE <key>=? AND success=false AND created_at>=?`、`.count(conn)`。
- **Rationale**：兩 fn 各自走對應索引（ip→`idx_login_attempt_ip_time`、user→`idx_login_attempt_user_time`）、命名自證、鏡像既有 `count_users_by_role_id` 範式。
- **Alternatives**：單一參數化 fn（dimension enum）——否決：兩索引/兩 key 型別不同，分開更清晰、零抽象成本。

### D-02 — gate 插點與寫點匯流（不改 login_inner 簽名、不重複寫）
- **Decision**：handler 在呼叫 `login_inner` 前算 gate；鎖中 → 把 `r` 設為 `Err((None, AppError::Biz("auth.login.locked".into())))` **短路**（跳過 login_inner）；未鎖 → `r = login_inner(...).await`。**既有單一寫點(196-212)不動位置**，照 match `r` 寫 attempt（gated 列＝success=false／operator=None／ctx 四欄鑑識照填）並 return。
- **Rationale**：brainstorm §4.1「gate 結果匯流進既有單一寫點」；login_inner 簽名/6 路徑零改、寫點零重複、gated 列與真失敗列同構（防枚舉一致＋審計完整＝FR-008）。
- **Alternatives**：login_inner 內做 gate——否決：login_inner 不接 ctx（無 client_ip）、且會把 gate 混進帳密驗證後（違 FR-009「鎖中跳過帳密驗證」＋失防 DoS 加分）。

### D-03 — 時窗 since 計算：Rust 端（app 時鐘）
- **Decision**：handler 算 `since = (Utc::now() - Duration::seconds(900)).into()`（per-user/per-ip 窗值同 900s），餵 count fn 的 `CreatedAt.gte(since)`。
- **Rationale**：**codebase 正典**——全 facade（sys_token/system_settings/casbin_archive）用 `sea_orm::sqlx::types::chrono::Utc::now().into()`、無一處 PG `now()-interval`；引入 `Expr::cust` raw SQL 反成孤例。
- **Alternatives**：PG 端 `created_at >= now() - make_interval(secs=>900)`（brainstorm §8 #1 原議、避 app/DB skew）——**否決**：(a) 需 `Expr::cust` raw SQL 新範式、(b) app↔DB 同 host（docker compose 共用 kernel 時鐘）skew <1s、對 900s 窗＜0.2% 邊界誤差、且 lockout 為 best-effort 縱深防禦（E6）非強一致 gate、(c) `created_at` DB-default、count since app-set 的 skew 影響可忽略。**clock-skew 風險已評估為非問題、登記於此**。

### D-04 — IpAddr→IpNetwork 轉換一致性（★ load-bearing correctness）
- **Decision**：per-ip count 的 `Col::RealIp.eq(x)` 之 `x: IpNetwork` **必須**用與寫端**完全相同**的 `IpAddr→IpNetwork` 轉換（host route：v4=/32、v6=/128）。implementer 須核對寫端（`LoginAttemptEvent.real_ip` 進 ActiveModel 的轉換）並在 count 端用同一 `From`/`.into()`。
- **Rationale**：若兩端轉換不一致（如一端 /32 一端 bare host），`.eq()` 永不中、per-ip 鎖**靜默失效**（feature 壞但純函式測仍綠）。
- **驗證**：C-V acceptance（curl 連續失敗→第 6 次鎖）會接住此 bug（轉換不符＝count 看不到列＝永不鎖）；EXPLAIN 驗走 ip 索引。

### D-05 — wire/i18n key：rust `auth.login.locked`、frontend `backend.auth.login.locked`
- **Decision**：rust 回 `AppError::Biz("auth.login.locked")`（root=auth、**無** `backend.` 前綴、對齊既有 `biz.*` key 樣式）。frontend `translateBackendMsg` 自動補 `backend.` → `$t("backend.auth.login.locked")`。locale 加巢狀 `backend.auth.login.locked`、Schema 加 `login.locked: string`。
- **Rationale**：act-on-code 校正——brainstorm §4.2 寫 flat `loginLocked` 是錯的；as-built 是巢狀 `login.locked`，且 rust key 不帶 `backend.` 前綴（前端補）。
- **Alternatives**：rust 直回 `backend.auth.login.locked`——否決：與既有 Biz key 樣式不符、會被前端再補成 `backend.backend....`。

### D-06 — 政策值 consts 位置：handler module 內 `const`
- **Decision**：`PER_USER_THRESHOLD: i64 = 5`／`PER_USER_WINDOW_SECS: i64 = 900`／`PER_IP_THRESHOLD: i64 = 20`／`PER_IP_WINDOW_SECS: i64 = 900` 置 `handler/auth.rs`（gate 邏輯所在）module 級 const。
- **Rationale**：最小 scope、runtime 可調（settings 島）為 defer（E4）；短窗 override 測試靠把純函式門檻/窗值參數化或 `#[cfg(test)]` const，不需獨立 config module。
- **Alternatives**：獨立 config module / settings 表——否決：v1 hardcode 拍板（E4），過早抽象。

### D-07 — count 出錯策略：fail-OPEN
- **Decision**：count query `DbErr` → 視為 0 失敗（`.unwrap_or(0)` ＋ `tracing::warn`）→ `is_locked_out` 判 false → 照常進 login_inner。
- **Rationale**：§I.7 fail-OPEN 範式（鏡像 `is_current`/denylist_gate）、⚠️w「best-effort 縱深防禦」；DB 抖動**不可鎖死全站登入入口**（FR-010/SC-006）。
- **Alternatives**：fail-closed（DbErr→擋）——否決：反轉 §I.7 方向性、需 Amendment、且把 DB 抖動放大成登入全斷。

### D-08 — wire code：復用既有 2222（不破 ⚠️f）
- **Decision**：鎖中走既有 `Biz`→2222（HTTP 200 envelope）、不新增碼。
- **Rationale**：⚠️f 13 碼整組凍結；2222 為「可擴充業務碼」（傳穩定 i18n key、⚠️y/⚠️aa）；不需新碼、不需 constitution Amendment。
- **Alternatives**：HTTP 429 Too Many Requests / 新碼——否決：破 13 碼凍結矩陣（§I.3）、需 Amendment、且前端攔截器已對 2222+msg 自動譯 toast（R3）。

---

## brainstorm §8 待固化逐項回答

1. **count SQL + 索引**：✅ D-01。per-ip `WHERE real_ip=? AND success=false AND created_at>=?`走 `idx_login_attempt_ip_time`；per-user 同形走 `idx_login_attempt_user_time`。`real_ip` 比較＝`IpNetwork.eq`（D-04 轉換一致）、`created_at` since＝`DateTimeWithTimeZone`（D-03 Rust 端）。EXPLAIN 驗於 C-V-5。
2. **gate 插點不破既有流程**：✅ D-02。handler login_inner 前插、匯流既有寫點、6 路徑/best-effort 寫不破；gated write 欄位（operator=None、success=false、ctx 四欄照填）。
3. **base-web 錯誤路徑對齊**：✅ R3/D-05。2222+msg(key) 走 `onError`/`translateBackendMsg`、**免改 login form**、1 locale key 足夠；CDP 驗鎖中 toast 在地化（curl≠modal、C-V-7）。
4. **gated write 的 sticky 語意**：✅ count 含 gated 列（D-02 寫點匯流）→ 持續攻擊不解鎖、停手滿窗才解（FR-008、C-V-3 驗）。
5. **政策值 const 命名/位置**：✅ D-06（handler module const）。
6. **無 MSRV/新 dep 風險**：✅ R2（0 新 crate、sea-orm 既有 feature 足夠、不觸「新 crate⇒四處 COPY」）。
7. **Constitution 預答 item 6/9**：✅ 見 plan.md Constitution Check（新 fail-OPEN gate、無 invariant 反轉、2222 reuse 不破 ⚠️f、不涉 §I.7 三狀態機）。

---

## /speckit-clarify Outstanding（已記、v1 defer、非阻擋）

- **per-ip IPv6 granularity**：v1 per-ip 以 exact `real_ip` 計數；IPv6 來源可輪替前綴（單主機常控 /64）規避 per-ip。**緩解**：per-user（P1）IP-independent、為主防線；admin panel 帳號數少、per-user 主導。**defer**：IPv6 前綴鍵（/64 group）留未來；此限制顯式登記於此供日後 security review。
- **account-lockout 自我 DoS**：per-user 鎖的內在後果——攻擊者知道某 username 即可故意失敗 5 次把該帳號鎖 ≤15 分。**緩解**：滑動窗自動解（≤15 分上限）、無永久鎖。為 user 拍板 D1/D2「per-user＋短窗」之已接受取捨（非缺陷）。
