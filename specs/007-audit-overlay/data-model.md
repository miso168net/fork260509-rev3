# Data Model: 007-audit-overlay

> 本刀＝L3 xdb（拷貝）＋L7 audit_ctx＋L4 facade（2 sink write）＋L1 boot 接線。**無持久實體變更、無 migration**——`sys_access_log`/`sys_login_attempt`/`sys_operation_log` 皆 m001 凍結 schema（欄級權威＝entity Model，見 research R3）。本檔定義 **audit 機制層型與接線**；`IpNetwork` 一律走 `sea_orm::entity::prelude::IpNetwork` re-export（R3）。

## 1. RequestContext（`audit_ctx.rs`、每請求一次解析、塞 extensions）
```rust
#[derive(Clone)]
pub struct RequestContext {
    pub operator_id: Option<i64>,      // 寬鬆 bearer：Some(uid) 成功／None 任何失敗、永不 reject
    pub client_ip: std::net::IpAddr,   // resolve_client_ip 解析後真實 IP（IpAddr、非 IpNetwork）
    pub x_forwarded_for: Option<String>, // 原始 XFF 鏈字串（逐字、鑑識）
    pub region: Option<String>,        // xdb best-effort（xdb_ready=false／IPv6／parse-fail → None）
    pub trace_id: String,              // extract_trace_id
}
```

## 2. resolve_client_ip（`audit_ctx.rs`、純函式、test-first、R4）
```rust
pub fn resolve_client_ip(peer: IpAddr, xff: Option<&str>, trusted: &[IpNetwork]) -> IpAddr
//  ① if !is_trusted(peer, trusted) { return peer }              // peer-gate（防偽造）
//  ② if let Some(xff)=xff { for tok in xff.split(',').rev() {
//        if let Ok(ip)=tok.trim().parse::<IpAddr>() {
//           if !is_trusted(ip, trusted) { return ip } } } }      // rightmost-untrusted；畸形 token 略過
//  ③ peer                                                        // fail-safe（全 trusted／空 XFF）
// is_trusted(ip, trusted): trusted.iter().any(|n| n.contains(ip))   // IpNetwork::contains
```
- `TRUSTED_PROXY_CIDRS` env（comma CIDR）→ `Vec<IpNetwork>`（parse 於 config/state、**fail-safe 空**）。CF 段加入 trusted、零 CF code。
- **純測**（C-V-1）：rightmost-untrusted 命中／多 hop 跳 trusted〔含 CF 段〕／IPv4·IPv6／畸形 token 略過／**直連 peer 不可信→回 peer（anti-spoof）**／全 trusted・空 XFF→peer／trusted 空集→peer。

## 3. extract_trace_id（`audit_ctx.rs`、純函式、R5）
```rust
pub fn extract_trace_id(headers: &HeaderMap) -> String
// honor "x-request-id"（trim、chars().take(64) UTF-8 邊界安全、非空）否則 Uuid::new_v4().to_string()
```
- **純測**（C-V-3）：x-request-id honored（trim≤64）／缺→非空 uuid。

## 4. audit_mw（`audit_ctx.rs`、L7 全域、R5）
```text
audit_mw(State<AppState>, ConnectInfo<SocketAddr>, mut req: Request, next: Next) -> Response
 前段（建 ctx、無條件）：
   peer = connect_info.ip(); xff = headers.get("x-forwarded-for")→Option<String>
   client_ip = resolve_client_ip(peer, xff.as_deref(), &state.trusted_proxy_cidrs)
   region = if state.xdb_ready { xdb::search_by_ip(client_ip.to_string()).ok() } else { None }
   operator_id = enforce::bearer(headers, &state.jwt).ok().map(|c| c.uid)   // 寬鬆、永不 reject
   trace_id = extract_trace_id(headers)
   req.extensions_mut().insert(RequestContext{ operator_id, client_ip, x_forwarded_for: xff, region, trace_id })
 let resp = next.run(req).await;
 後段（gate）：
   if operator_id.is_some() {
     best_effort_audit(sys_access_log::write(&state.db, &AccessLogEvent{ operator_id: uid, method, path,
        http_status: resp.status().as_u16() as i32, client_ip, x_forwarded_for, region, trace_id }))
   }   // 未認證/health/login → operator None → 不寫列
 resp
// best_effort_audit(fut): fut.await.unwrap_or_else(|e| tracing::warn!(...));  // 吞 DbErr、不擋
```
- method/path 自 req 前段擷取（move 進閉包前複製）；**enforce_mw 不動**（各自獨立 verify）。

## 5. facade（`model/facade/`、entity:: 合法、archetype B append-only：只 expose write）

### 5.1 `sys_access_log.rs`（新）
```rust
pub struct AccessLogEvent { pub operator_id: i64, pub method: String, pub path: String,
    pub http_status: i32, pub client_ip: IpAddr, pub x_forwarded_for: Option<String>,
    pub region: Option<String>, pub trace_id: String }
fn access_log_active_model(e: &AccessLogEvent) -> entity::sys_access_log::ActiveModel  // 純測 seam：client_ip→IpNetwork::from
pub async fn write(db: &DatabaseConnection, e: &AccessLogEvent) -> Result<(), DbErr>   // 單 INSERT、id/created_at DB 生成
```
### 5.2 `sys_login_attempt.rs`（新）
```rust
pub struct LoginAttemptEvent { pub attempted_user_name: String, pub success: bool,
    pub operator_id: Option<i64>, pub client_ip: IpAddr, pub x_forwarded_for: Option<String>,
    pub region: Option<String>, pub trace_id: String }
fn login_attempt_active_model(e: &LoginAttemptEvent) -> entity::sys_login_attempt::ActiveModel  // IpNetwork::from＋operator_id Set(None)/Set(Some)
pub async fn write(db: &DatabaseConnection, e: &LoginAttemptEvent) -> Result<(), DbErr>
```
- **純測**（C-V-2）：`*_active_model` 的 `IpAddr→IpNetwork`（V4→/32、V6→/128）、欄映射、access/login 對稱。
- `facade/mod.rs` 加 `pub mod sys_access_log; pub mod sys_login_attempt;`。entity 欄＝research R3（access 10／login 9）。

## 6. login inner/outer（`handler/auth.rs`、R2）
```text
login_inner(State, &RequestContext, LoginReq) -> Result<Success{uid, tokens}, (Option<i64> operator, AppError)>
   // 沿用 006 既有流程；各 ? 終端映射到 Err((operator, app_err))：
   //   pre-identity（operator=None）：find_by_user_name DbErr／not-found(LoginFailed)／password-wrong(LoginFailed)
   //   post-identity（operator=Some(uid)）：roles DbErr／sign err／timestamp／begin/set_pointer/insert_token/commit（→Internal）
login(State, Extension<RequestContext>, Json<LoginReq>) -> Result<Json<Res>, AppError>
   let ctx = ext; let r = login_inner(...).await;
   match &r {
     Ok(s)            => best_effort: login_attempt::write(success=true,  operator=Some(s.uid), client_ip=ctx..),
     Err((op, _err))  => best_effort: login_attempt::write(success=false, operator=*op,         client_ip=ctx..),
   }   // exactly-one per 終端結果（FR-004 由建構保證）
   r.map(|s| Ok(Json(Res::ok(LoginToken{token, refreshToken })))).unwrap_or_else(|(_,e)| Err(e))
```
- `attempted_user_name`＝`req.user_name`（成敗皆有）；region/x_forwarded_for/trace_id 取 `ctx`。
- 行為不變式守：1000 collapse（not-found／password-wrong 同回 LoginFailed）、原子 txn、wire DTO 皆**不**動（006 既有）。

## 7. op-log operator/trace threading seam（R7、誠實範圍）
```rust
// helper（供波1+ mutating handler 用）：
AuditOperator{ id: ctx.operator_id.expect("mutating handler 必經 enforce_mw"), ip: Some(IpNetwork::from(ctx.client_ip)) }
trace_id: Some(ctx.trace_id)  →  mutate_in_txn 的 AuditEvent
```
- 本刀**無 live mutating handler**（唯一 consumer `soft_delete` test-only）→ FR-013/SC-006 由 **test-only live smoke** 證（顯式構造 AuditOperator{id,ip}＋trace 餵 soft_delete、psql 驗 op-log 末列 operator_id/operator_ip/trace_id 非空）。production threading 留波1+。

## 8. xdb boot（`main.rs`/`state.rs`、R1）
```text
boot：
  let xdb_path = config.xdb_filepath;  // XDB_FILEPATH（或 default resources/ip2region.xdb）
  let xdb_ready = std::path::Path::new(&xdb_path).exists();
  if xdb_ready { xdb::searcher_init(Some(xdb_path)); } else { tracing::warn!("xdb file missing → region degraded"); }
  // AppState{ ..., xdb_ready }
serve：axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>())  // 取 peer
```
- **★ 守門必在 searcher_init 之前**（searcher_init 缺檔 panic、R1）；`search_by_ip` 僅在 `xdb_ready` 時呼叫。

## 9. config / state 接線
- `state.rs`：`AppState` 加 `pub trusted_proxy_cidrs: Vec<IpNetwork>`＋`pub xdb_ready: bool`（derive Clone 保持）。
- `config.rs`：載 `TRUSTED_PROXY_CIDRS`（comma CIDR→`Vec<IpNetwork>`、parse 失敗/未設→空 fail-safe）＋`XDB_FILEPATH`（沿 `_FILE`/env 模式、default `resources/ip2region.xdb`）。
- `main.rs`：`mod audit_ctx;`＋xdb dep；audit_mw 掛**最外層**（全路由、operator-gate 自然排除 health/login/public）。

## 10. 排除聲明（OUT、各歸其刀）
- audit 讀端/查詢端點＋UI＝波2（⚠️b）；login lockout 本體＝波3（⚠️w、本刀只備真實 IP＋既有 2 索引）；retention/cleanup＝波4（⚠️n）；op-log operator_ip **live handler 回填**＝波1+ 首個 mutating 端點；全流量（含未認證）日誌＝波4 obs（tracing→loki、非本表）；CF 特例 code（走 trusted CIDR config）。
- **無 migration/entity/型遷移/base-web/i18n/nginx 變動**（地基 002/004/005 已 provisioned、nginx 已轉發）。
