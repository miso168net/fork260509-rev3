# 007-audit-overlay — Phase 0 Brainstorm（spec-design）

> 波 0 第七刀（末）（001 infra-deploy → 002 schema-baseline → 003 envelope → 004 soft-delete-infra → 005 audit-op-log → 006 auth-island-min → **007 audit-overlay**）。完成後波 0 出口四項全綠 → 換波 1（system_settings 打樣）。
> 對應前代 015「access-log＋login-attempt＋xdb」。**audit 三 sink 縱切兩刀**：op-log（005）＋ access-log/login-attempt（007）。本檔為 brainstorm 定稿的 spec-design，作 `/speckit-specify` 的 input。
> **本檔來歷**：以**前代 v2 設計**（outer 分支 `rebase260616-007-audit-overlay`、pin rust-api `d20bac3b`）為基礎**重做**、對齊**當前 lineage**（rust-api worktree `b9de316`）；只借 v2 設計、不沿用其 spec-kit 產物（user 拍板 2026-06-17）。
> **凍結權威**：DESIGN §5.2（audit 三 sink、縱切兩刀）＋§5.9（region 由 client_ip 解；**本刀推進 client_ip 來源＝XFF trusted-proxy 解析、見 §3 與 §7**）＋§3.1（審計 append-only 不可竄改、archetype B）＋§3.3／§10.4（access-log 已認證才記、單一 operator gate、無 path 排除清單）＋§1.5（xdb L3 → audit_ctx L7 跨層邊、audit_ctx.rs global layer）＋§I.5（rust 全新寫；唯二拷貝例外＝`sea-orm-adapter`＋**`xdb`**）＋§I.6（archetype B append-only、facade 唯一管道）＋§7.4（`/api` strip 前綴）。
> **相關 ⚠️ 拍板（DECISIONS §1）**：⚠️v（xdb vendored 併本刀）／⚠️g（rust-api 全新寫、前代受控參照讀允許拷貝禁止）／⚠️w（login lockout 為下游消費者，本刀只備資料＋索引）／⚠️b（審計讀端＝波2）／⚠️n（retention＝波4 obs）。
> **衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（引用一律用穩定 §錨、不用揮發行號；本檔不引用本機 memory）。

---

## 1. 目標一句話

把 audit 軌補滿最後一段：全域 **`audit_ctx`** 中介層（每請求建 `RequestContext`、帶 operator/trace/真實 client_ip/region）＋ **access-log**（已認證請求 exactly-one）＋ **login-attempt**（login 每終端路徑 exactly-one、成敗皆記）兩個 append-only sink ＋ **`xdb`** sub-crate（client_ip→region）＋ **app-side 真實 client IP 解析**（XFF trusted-proxy 模型），讓「誰/何時/從哪 IP/哪地區 登入或呼叫受保護資源」可稽核；並把既有 `mutate_in_txn` seam 的 operator/trace/operator_ip threading 立到位（供波1+ 首個 mutating 端點即時填）。完成波 0 出口最後一塊（audit 第二刀）。

## 2. Context（探索蒐集）

### 2.1 前代 v2 設計（借鑑基礎，§I.5／⚠️g 受控參照、不照拷）
- v2（`rebase260616-007-audit-overlay`）為 **v2 重做**（v1 `1bb1a96` 已 hard-rollback），修兩處：① access-log scope 改 conform 凍結 DESIGN（v1 的「全部＋sentinel(0)＋skip-set」與 §3.3/§10.4 衝突）；② 真實 client IP — rust-api 在 front-nginx（其前可能再有 Cloudflare／其它 proxy）反代後方，**直連 peer＝nginx IP**，故改 **app-side 從 XFF 解析真實 client IP**。
- 借 v2 的：`resolve_client_ip` 手刻純函式（trusted-proxy）／`audit_ctx`＋`RequestContext`／2 facade 形／login inner-outer split／op-log threading／xdb file-path 載入＋boot-guard／operator-gate access-log。
- **auth/audit 層全新寫**（§I.5 拷貝例外唯 `sea-orm-adapter`／`xdb`；audit_ctx/facade 不在內）→ v2 僅作設計參照（讀允許、拷貝禁止）。

### 2.2 ★ 當前 lineage 已落地（v2 規劃為「工作」、本刀「確認跳過」、不重排）
> v2 pin `d20bac3b` 與當前 `b9de316` 為**不同 lineage**；rev3 的 005-audit-op-log 與 004 已把 v2 當初要做的 INET 地基做掉：
- `sys_access_log`（10 欄、`client_ip: IpNetwork`）＋`sys_login_attempt`（9 欄、`operator_id: Option<i64>`）entity Model **已存在**（004 建）。
- entity crate **已開** sea-orm `with-ipnetwork`；`Cargo.lock` 已 `ipnetwork 0.20.0`＋`time 0.3.37`＋`simple_asn1 0.6.3`＋`jsonwebtoken 9.3.1`、**1.86 build 綠**（006 已解 time-pin）。
- `sys_operation_log.operator_ip` **已是** `Option<IpNetwork>`；`AuditOperator { id:i64, ip:Option<IpNetwork> }`（`audit.rs`）已是 INET 型；`facade/sys_operation_log::write_in_txn` **已無條件寫** `operator_ip`（無 42804 defer 分支）。
- ⇒ **本刀無 migration、無 entity 改、無 String→INET 型遷移、無 42804 defer 要解、無 MSRV 重驗、無 entity Model 建立**（皆 already-done；v2 research R3/R6＋entity 建立在當前 lineage MOOT）。

### 2.3 rust-api 現況（當前 lineage `b9de316`——親驗、seam 命名差異）
- `server/src/main.rs`：006 已接 `AppConfig`→`Database::connect`→`init_enforcer`→`AppState`、mount `/auth/login`(public)／`/auth/getUserInfo`(enforce_mw)／`/health`／fallback；**目前是 plain `axum::serve`**（無 `ConnectInfo`、無全域 layer）。
- `server/src/auth/enforce.rs`：`bearer(&HeaderMap, &JwtConfig) -> Result<Claims, AppError>`（**bearer 在 enforce.rs、非獨立 bearer.rs**）；`enforce_mw` strict（壞 token→3333）；Claims 欄為 **`uid`**（非 user_id）；`jwt::verify(token, secret, iss, aud)`（4 參）。
- `server/src/state.rs`：`AppState{ db, jwt:JwtConfig{access_secret,refresh_secret,...}, enforcer }`。
- `server/src/handler/auth.rs`：`login`（flat 單 fn、原子 txn set_pointer+insert_token）／`get_user_info`。
- `server/src/model/audit.rs`：`mutate_in_txn`（泛型 `C:TransactionTrait`）＋`AuditOperator{id,ip:Option<IpNetwork>}`＋`AuditEvent{...,operator:Option<AuditOperator>,trace_id:Option<String>}`；`use sea_orm::entity::prelude::IpNetwork`（**IpNetwork 走 sea-orm re-export、無 standalone `ipnetwork` dep 宣告**、transitive 0.20.0 已在 lock）。
- `model/facade/sys_user::soft_delete(conn, id, operator:AuditOperator, trace_id:Option<String>)`：**唯一 `mutate_in_txn` consumer，但 test-only**（grep handler/＝零 caller、無 live mutating 端點）。
- workspace members＝`server/migration/sea-orm-adapter/entity`（**無 `xdb`**、無 `cleanup-job`〔cleanup-job＝波3〕）。

### 2.4 base-web / nginx wire 現況（§I.1 權威／R7——親驗）
- **base-web 零改**：搜 `/audit`/`access_log`/`login_attempt`/`loginLog` 等 → **無**任何 audit 讀端/UI；audit 為純後端寫端，讀端＝波2（⚠️b）。
- **nginx 零改（R7 驗即可）**：`deploy/nginx/conf.d/_locations.inc` `/api/`→rust-api `:31081`，**已轉發** `X-Forwarded-For`（`$proxy_add_x_forwarded_for`）＋`X-Real-IP`＋`X-Request-Id`（`$request_id`）。

### 2.5 schema 現況（004/002 建齊、本刀不動；INET NN 欄是寫入重點）
- `sys_access_log`（10）：`id`／`operator_id BIGINT **NOT NULL**`／`method`／`path`／`http_status int`／`client_ip **INET NOT NULL**`／`x_forwarded_for TEXT NULL`／`region TEXT NULL`／`trace_id TEXT NULL`／`created_at`（DB default）。**無額外 index**。
- `sys_login_attempt`（9）：`id`／`attempted_user_name`／`success bool`／`operator_id BIGINT **NULL**`／`client_ip **INET NOT NULL**`／`x_forwarded_for`／`region`／`trace_id`／`created_at`。**2 index**（既有 m001、為 ⚠️w lockout 備）：`idx_login_attempt_ip_time (client_ip,created_at)`、`idx_login_attempt_user_time (attempted_user_name,created_at)`。
- `sys_operation_log.operator_ip Option<IpNetwork>`（已 INET、本刀只 threading）。**無 migration、無 schema 變動。**

### 2.6 消費者
- **直接**：稽核軌（誰登入/從哪 IP）＝後端寫端；波 0 出口 audit 第二刀達成。
- **下游**：⚠️w login lockout（波3、查 login_attempt 2 索引）／⚠️b 審計讀端+UI（波2）／波1+ 首個 mutating handler（即時填 op-log operator/trace/operator_ip）。

## 3. 設計決策表（借 v2＋當前 lineage 對齊＋本次 refinement；描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | xdb 進本刀 | **是、全做**（user 拍 2026-06-17） | 完整收波 0 audit 軌（§5.9）；region 是 access/login 稽核的點。代價（新 crate/panic-guard/prod COPY/prod-build）已知可控 |
| D2 | client_ip 來源 | **app-side XFF trusted-proxy 解析** | **推進 DESIGN §5.9（直連→XFF）**：nginx（+CF）後方、直連 peer＝nginx IP→IP 軌與 per-ip lockout 皆廢。§5.9 屬 DESIGN 細節（非 constitution §II／非 DECISIONS §1）→ 無 amendment、`/speckit-plan` Constitution Check 對齊、下次 DESIGN 重鑄摺合（見 §7）。否決直連 peer（名實不符）／nginx-edge 解析（app 端測不到、綁 nginx 正確性） |
| D3 | resolver 實作 | **手刻 `resolve_client_ip` 純函式**（非 crate） | 重用 ipnetwork（已在圖）＝零新 dep、純測（合 ⚠️g TDD）；CF 走 trusted CIDR config、零 CF code。crate（axum-client-ip）edge-case 戰功對「我們控 nginx 轉乾淨 XFF」溢出 |
| D4 | access-log scope | **`operator_id.is_some()` 單一 gate** | conform DESIGN §3.3/§10.4：已認證才記一列；未認證/health/login 自然不記（無 sentinel、無 path skip-set）。否決 v1「全部＋sentinel(0)」（破 operator_id NOT NULL 意圖）。全流量日誌＝波4 obs（tracing→loki）、非本表 |
| D5 | xdb 打包 | **file-path 載入**（非 embed） | 整檔拷貝紀律（embed `include_bytes!` 會改 vendored crate）；rev2 xdb 僅 file-path API；Dockerfile COPY 因 `[[bench]]` 不可免、embed 無益 |
| D6 | audit_ctx 結構 | **無條件建 ctx＋ConnectInfo＋最外層＋best-effort 寫＋獨立寬鬆 bearer** | P1 無條件建（否則 /login 讀 Extension panic）；P2 `into_make_service_with_connect_info`（取 peer）；P3 最外層 layer；P4 寫失敗吞（tracing::warn、不擋業務）；獨立寬鬆 bearer（Some/None 永不 reject）與 006 enforce_mw strict 分開、**enforce_mw 一行不動** |
| D7 | INET 寫入 | **IpAddr→`IpNetwork::from(ip)` 在 facade seam**（純測） | with-ipnetwork 已開、IpNetwork::from V4→/32 V6→/128 原生→ sea-orm native inet binding、無 PG 42804（42804＝String 綁 INET 型不符） |
| **R1** | **ipnetwork 取得**（refinement） | **用 `sea_orm::entity::prelude::IpNetwork` re-export**（非 v2 顯式 `ipnetwork="0.20"`） | 零新 dep、合 codebase 現況（audit.rs 已此法）；`contains()`/`from()` 同型可用。lock 已含 0.20.0 |
| **R2** | **login 終端路徑數**（refinement） | **7 點＝6 失敗＋1 成功**（user 拍） | v2 為 6 點（5 失敗＋1 成功），但 006 login 多了原子 txn（set_pointer/insert_token/commit 會錯）→ 補第 7 條 txn-error 路徑。見 §4.5 對映 |
| **R3** | **login_attempt operator_id 規則**（refinement、微調 v2） | **pre-identity 失敗（查無/壞密碼）＝None；post-identity 失敗（role-lookup/簽章/txn-error）＋成功＝Some(uid)** | post-password-verify 已確認 user → operator_id 帶 uid 對稽核更有用且一致；v2 把 5 失敗全設 None 是簡化；lockout 不查 operator_id（查 user_name/ip 索引）→ 無外洩疑慮（本表無讀端）。**spec review 可調** |
| **R4** | **op-log operator_ip 回填誠實範圍**（refinement、user 拍） | **seam ready＋test-only live smoke 證 INET round-trip；production handler threading 留波1+** | `mutate_in_txn`/`soft_delete` 已收 operator+trace 參數、INET 已通，但 soft_delete test-only、**無 live mutating handler** → 本刀不假裝 live 回填；FR-013/SC-006 由 test-only smoke 證 |
| **R5** | **`ip2region.xdb`（~10.5MB）git-tracked**（refinement、user 拍） | **是、納版控＋prod COPY** | 同 graphify-out 既有大二進位慣例；prod runtime 須有檔（否則 xdb_ready=false 降級） |

## 4. 元件設計（act-on-code、當前 lineage seam 名）

### 4.1 `xdb/` 新 crate（§I.5 ⚠️v 整檔拷貝）
- **來源**：`fork260509-rev2-anew-rust-api` @ 分支 `rev2-admin-rust-api-rebase260531`、path `xdb/`（git show 讀；整檔拷貝、零修改）。檔：`Cargo.toml`（`[[bench]] name=search harness=false`）／`src/{lib,searcher,ip_value}.rs`／`benches/search.rs`／`resources/{ip2region.xdb(~10.5MB), ip.test.txt}`。
- **deps**：`once_cell`／`tracing`／`tracing-subscriber`（皆 workspace；需把 `once_cell` 升為 workspace dep）；dev-deps `criterion 0.5.1`＋`rand 0.8`。
- **API**：`search_by_ip<T: ToUIntIP>(ip) -> Result<String, Box<dyn Error>>`（回 pipe 分隔 `中国|0|福建省|福州市|电信`；私有/內網→`内网IP` 類非 NULL）；`searcher_init(xdb_filepath: Option<String>)`（prewarm `get_full_cache()`+`get_vector_index_cache()`）；`XDB_FILEPATH` env；`default_detect_xdb_file()` 探 `resources/ip2region.xdb`。
- **★ PANIC gotcha**：`get_full_cache()` 對缺檔 `.expect("file open error")`／`searcher_init` `.unwrap()` → **缺檔即 panic、非 best-effort**。⇒ **boot 須先檔存在守門再 `searcher_init`**，存 `AppState.xdb_ready` flag，middleware 依此 region 降級 None（FR-009 best-effort），不 crash。
- workspace `Cargo.toml` members 加 `"xdb"`；server `Cargo.toml` 加 `xdb = { path = "../xdb" }`。

### 4.2 `server/src/audit_ctx.rs` 新（L7 全域中介層）
```text
RequestContext {
  operator_id: Option<i64>,        // 獨立寬鬆 bearer：Some 成功/None 任何失敗、永不 reject
  client_ip:   IpAddr,             // resolve_client_ip 解析後真實 IP（注意 IpAddr、非 IpNetwork）
  x_forwarded_for: Option<String>, // 原始 XFF 鏈字串（鑑識備查）
  region:      Option<String>,     // xdb best-effort（IPv6/parse-fail/xdb_ready=false → None）
  trace_id:    String,             // extract_trace_id
}
audit_mw(State<AppState>, ConnectInfo<SocketAddr>, Request, Next) -> Response  // 無 Result、永不 reject
```
- **前段**：對**每**請求無條件建 `RequestContext`（`client_ip` via §4.3 resolver〔peer＝ConnectInfo、xff＝header、trusted＝state.trusted_proxy_cidrs〕、raw xff 原文、`region` via `xdb::search_by_ip` best-effort、`trace_id` via §4.4、`operator_id` via **獨立寬鬆 bearer**〔`auth::enforce::bearer(headers, &state.jwt).ok().map(|c| c.uid)`＝Some/None 永不 reject〕）→ 塞 request extensions。
- **後段**：`next.run().await` 後取 `response.status().as_u16()` 為 `http_status`；**gate＝`operator_id.is_some()`** → 才建 `AccessLogEvent` + `best_effort_audit` 寫（吞 DbErr via tracing::warn、不擋回應）。未認證/health/login → operator None → 不寫列。
- 與 006 enforce_mw 各自獨立 verify HS256（成本可忽略）、不共用 Claims、enforce_mw 不動。
- **lint**：audit_ctx 不得 path-root `entity::`（走 facade）。

### 4.3 `resolve_client_ip` 純函式（test-first、安全敏感）
```text
resolve_client_ip(peer: IpAddr, xff: Option<&str>, trusted: &[IpNetwork]) -> IpAddr
  ① if !is_trusted(peer, trusted) { return peer }        // peer-gate：直連不可信→不信 header（防繞 nginx 偽造）
  ② if let Some(xff) { for tok in xff.split(',').rev() {  // rightmost-untrusted：右→左
        if let Ok(ip)=tok.trim().parse() { if !is_trusted(ip,trusted) { return ip } } } }  // 第一個不可信＝真 client；畸形 token 略過
  ③ return peer                                          // 全 trusted/空 XFF → fail-safe
```
- `is_trusted` 用 `IpNetwork::contains`；`TRUSTED_PROXY_CIDRS` env（comma CIDR）→ `Vec<IpNetwork>`、**fail-safe 預設空**（未設→空→peer 不可信→用 peer、dev 正確）。CF 段填進 trusted → 演算法自動跳、零 CF code。
- **安全鐵則**：絕不盲信 forwarded header；trusted 集合須顯式配置、預設 fail-safe（否則攻擊者偽造 XFF 規避 lockout／嫁禍 IP／污染稽核）。

### 4.4 `extract_trace_id(&HeaderMap) -> String`
- honor `x-request-id`（nginx 已設 `X-Request-Id $request_id`、trim、`chars().take(64)` UTF-8 邊界安全）否則 uuid v4。

### 4.5 `server/src/handler/auth.rs` — login inner/outer split（R2／R3）
- `login_inner(...) -> Result<...>`；outer `login(State, Extension<RequestContext>, Json<LoginReq>)` 讀 `ctx`，每終端路徑 exactly-one `record_login_attempt`（best-effort、client_ip 取 `ctx`）。**7 點對映當前 `handler/auth.rs` login**：
  1. user-not-found（`find_by_user_name`→None）→ success=false、operator_id=**None**（pre-identity）
  2. password-wrong（`verify`=false）→ success=false、operator_id=**None**（pre-identity）
  3. role-lookup-error（`roles_of_user?`）→ success=false、operator_id=**Some(uid)**（post-identity、R3）
  4. access-token-sign-error（`jwt::sign(access)?`）→ success=false、operator_id=**Some(uid)**
  5. refresh-token-sign-error（`jwt::sign(refresh)?`）→ success=false、operator_id=**Some(uid)**
  6. **txn-error（`begin`/`set_pointer`/`insert_token`/`commit`?，006 原子寫，R2 新增）**→ success=false、operator_id=**Some(uid)**（密碼已過）
  7. success（commit 後）→ success=true、operator_id=**Some(uid)**

### 4.6 2 facade 新（archetype B、只 expose write）
- `facade/sys_access_log.rs`：`AccessLogEvent{ operator_id:i64, method, path, http_status:i32, client_ip:IpAddr, x_forwarded_for, region, trace_id }`＋`access_log_active_model(&Event)->ActiveModel`（**IpAddr→`IpNetwork::from` seam、純測**）＋`write(&db,&Event)->Result<(),DbErr>`（單 INSERT、無 txn）。
- `facade/sys_login_attempt.rs`：對稱 `LoginAttemptEvent{ attempted_user_name, success:bool, operator_id:Option<i64>, client_ip:IpAddr, x_forwarded_for, region, trace_id }`＋`login_attempt_active_model`（`IpNetwork::from`＋operator_id Set(None)/Set(Some)）＋`write`。
- `facade/mod.rs` 註冊 2 新 facade。entity:: 在 facade 合法（lint 豁免）。

### 4.7 op-log operator/trace threading（R4、seam-ready）
- helper：mutating handler 必經 enforce_mw（已認證、operator_id 必 Some）→ `AuditOperator{ id: <authenticated uid>, ip: Some(IpNetwork::from(ctx.client_ip)) }`＋`trace_id: Some(ctx.trace_id)` → 餵既有 `mutate_in_txn` 的 `AuditEvent`（test-only smoke 以顯式 id/ip 構造）。
- **唯一 consumer `soft_delete` test-only** → 本刀 = seam ready ＋ test-only live smoke 證 op-log operator_id/operator_ip/trace_id 由恆 None→真值（INET round-trip）；production handler threading 留波1+ 首個 mutating 端點。

### 4.8 `main.rs` / `state.rs` / `config.rs` / Dockerfile / compose
- `main.rs`：plain serve → **`into_make_service_with_connect_info::<SocketAddr>()`**；audit_mw 掛**最外層**（全域）；boot `xdb::searcher_init`（**檔存在守門**→`xdb_ready`）；006 enforce_mw 不動。
- `state.rs`：`AppState` 加 `trusted_proxy_cidrs: Vec<IpNetwork>`＋`xdb_ready`（＋xdb searcher handle）。
- `config.rs`：載 `TRUSTED_PROXY_CIDRS`（fail-safe 空）＋`XDB_FILEPATH`（沿既有 `_FILE`/env 模式）。
- `deploy/Dockerfile.rust-api.txt`：加 xdb COPY（Manifest `xdb/Cargo.toml`＋Source `xdb/src`＋`xdb/benches`＋`xdb/resources`）；保 `--bins`（跳 `[[bench]]` 編譯）；`--locked`。
- `docker-compose.dev.yml`／`docker-compose.prod.yml`：rust-api env 加 `TRUSTED_PROXY_CIDRS`（dev 空＝peer／prod 內網+CF 段）＋`XDB_FILEPATH`。
- `deploy/nginx`：**零改、僅驗**（R7 已轉發 XFF/X-Real-IP/X-Request-Id）。

## 5. wire / 碼 / INET
- **無新 wire／業務端點**（base-web 零改）；audit 為透明中介層＋內部表。
- 碼：audit 寫失敗不發碼（best-effort 吞）；login 仍走 006 既有碼（0000/1000）；access-log 不改回應。
- **INET**：codebase 首個寫真值 INET 的路徑（access_log/login_attempt 的 client_ip＋op-log operator_ip）；`IpNetwork::from(IpAddr)` 原生 binding、無 42804。

## 6. 範圍邊界

**IN**：xdb crate（vendored）／audit_ctx＋RequestContext／resolve_client_ip＋extract_trace_id 純函式／2 facade（access-log/login-attempt）／login inner-outer split（7 點）／main connect_info＋audit_mw 最外層＋xdb boot-guard／state trusted_proxy_cidrs＋xdb_ready／config TRUSTED_PROXY_CIDRS＋XDB_FILEPATH／Dockerfile xdb COPY／compose env／op-log threading seam（+test-only smoke）。

**OUT（遞延）**：審計讀端+UI（波2 ⚠️b）／login lockout 本體（波3 ⚠️w、本刀只備真實 IP＋既有 2 索引）／CF 特例 code（走 trusted CIDR config）／retention/cleanup（波4 ⚠️n）／全流量（含未認證）日誌（波4 obs tracing→loki、非本表）／op-log operator_ip **live handler 回填**（波1+ 首個 mutating 端點）／cleanup-job crate（波3）。

**MOOT（當前 lineage already-done、不重排）**：String→INET 型遷移／42804 defer 分支解／ipnetwork 0.20 MSRV 重驗＋lock pin／access_log/login_attempt entity Model 建立。

## 7. DESIGN §5.9 推進留痕（`/speckit-plan` Constitution Check 對齊用）
- **推進**：client_ip 由「直連 client_ip（§5.9 凍結文字）」推進為「XFF trusted-proxy 解析真實 IP」。
- **權威鏈**（constitution §V.1：constitution ＞ DECISIONS ＞ DESIGN）：§5.9 屬 **DESIGN 細節**、**不在** constitution §II 13 拍板、**亦非** DECISIONS §1 項 → **無需 amendment**。
- **處置**：記於本檔 §3-D2 + 將於 `/speckit-specify`/`/speckit-plan` spec.md/research.md 明載；`/speckit-plan` Constitution Check 對齊（非 violation、屬 DESIGN-detail 推進）；**下次 DESIGN 重鑄摺合** §5.9。

## 8. Functional Requirements / Success Criteria（借 v2、當前 lineage 校）
- **FR-001** 每**已認證**請求寫 exactly-one access-log。**FR-002** 未認證（無/壞/過期 bearer，含 login/health/public）**MUST NOT** 寫 access-log。**FR-003** access-log 欄：operator/method/path/status/真實 client IP/原始 XFF/region/trace_id/time。
- **FR-004** login 每終端路徑（成功或任一失敗）寫 exactly-one login-attempt。**FR-005** login-attempt 欄：attempted_user_name/success/(規則見 R3)operator_id/真實 client IP/原始 XFF/region/trace_id/time。
- **FR-006** 自 forwarded 鏈解析真實 client IP、**只信顯式配置的 trusted-proxy**、絕不信不可信來源的 forwarded。**FR-007** fail-safe：trusted 未設／直連來源不可信 → 用直連 peer、不信 forwarded。**FR-008** 原始 forwarded 鏈逐字保存（與解析後 client_ip 分欄）。
- **FR-009** region 由解析後 client IP 解；私有/內網→非空 `内网`類；**xdb 不可用→region NULL（best-effort、不 crash）**。**FR-010** 每請求附 trace_id（honor 入站 request-id header 否則生成）。**FR-011** 未認證請求（含 login）亦擷取真實 client IP（使 login-attempt 帶 IP）。
- **FR-012** 所有 audit 寫 **best-effort**：寫失敗 MUST NOT 失敗/擋業務請求。**FR-013** op-log operator/trace/operator_ip threading seam ready（live 回填 by 波1+ mutating 端點）。**FR-014** 三 audit 表 append-only（facade 僅 write、無 update/delete、§I.6 B）。
- **SC**：SC-001 access-log operator-gate（認證 1 列/未認證 0 列）／SC-002 login-attempt 成敗各 exactly-one（失敗帶 IP）／SC-003 resolve_client_ip trusted-proxy 正確（rightmost-untrusted＋peer-gate＋fail-safe＋anti-spoof）／SC-004 IpAddr→IpNetwork /32·/128 對映／SC-005 trace_id 每請求附（honor x-request-id 否則生成）＋原始 XFF 鏈逐字保存／SC-006 op-log threading test-only smoke 證 INET round-trip／SC-007 真值 INET 無 42804＋私有 region 非 NULL／**SC-008 新 crate prod image build 綠（xdb COPY＋`[[bench]]`＋`.xdb` 在 image＋`xdb_ready`）**／SC-009 零回歸（/health、login/getUserInfo/enforce 不變、零 migration/entity/base-web）。

## 9. C-V 驗收（live 一律 `--test-threads=1` serial）
- **C-V-1** `resolve_client_ip` 純測（`cargo test -p server resolve_client_ip`）→ SC-003：rightmost-untrusted 命中／多 hop 跳 trusted（含 CF 段）／IPv4+IPv6／畸形 token 略過／直連 peer 不可信→回 peer（anti-spoof）／全 trusted/空 XFF fail-safe peer／TRUSTED_PROXY_CIDRS 未設→空→peer。
- **C-V-2** facade `*_active_model` 純測（`cargo test -p server active_model`）→ SC-004：IpAddr→IpNetwork /32·/128、欄映射、access/login 對稱。
- **C-V-3** `extract_trace_id` 純測（`cargo test -p server trace_id`）→ FR-010：x-request-id honored（trim≤64 UTF-8-safe）否則非空 uuid。
- **C-V-4** live INET 無 42804＋region 內網非 NULL（`--ignored --test-threads=1` + psql `client_ip,region`）→ SC-007。
- **C-V-5** live login-attempt 成+敗各一列（curl 壞密碼＋`Super/123456`、psql）→ SC-002：失敗 success=false/operator_id 依 R3/has_ip=true；成功 success=true/operator_id=Some。
- **C-V-6** live access-log operator-gate（login→token、getUserInfo 帶/不帶 bearer、/health、psql）→ SC-001：認證 getUserInfo 1 列 operator 非空；未認證 getUserInfo/health/login 0 列。
- **C-V-7** live op-log threading（test-only smoke、psql operator_id/operator_ip/trace_id）→ SC-006：末列由恆 None→真值。
- **C-V-8** **prod image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`）→ SC-008：xdb crate＋`.xdb` COPY＋`[[bench]]` 不撞、`--locked`、prod boot `xdb_ready=true`。
- **C-V-9** 零回歸（/health ok、login/getUserInfo/enforce 不變、diff 零 migration/entity/base-web）→ SC-009。

## 10. Files（當前 lineage、標 BUILD vs ALREADY）
**BUILD（新/改）**：`rust-api/xdb/`（新 crate）／`server/src/audit_ctx.rs`（新）／`server/src/model/facade/{sys_access_log,sys_login_attempt}.rs`（新）／`facade/mod.rs`（註冊）／`handler/auth.rs`（login split＋7 點）／`main.rs`（connect_info＋audit_mw 最外層＋xdb boot-guard）／`state.rs`（trusted_proxy_cidrs＋xdb_ready）／`config.rs`（TRUSTED_PROXY_CIDRS＋XDB_FILEPATH）／`server/Cargo.toml`（+xdb path）／workspace `Cargo.toml`（+xdb member、once_cell→workspace）／`deploy/Dockerfile.rust-api.txt`（xdb COPY）／`docker-compose.{dev,prod}.yml`（env）。
**ALREADY（當前 lineage、不動）**：`entity/src/{sys_access_log,sys_login_attempt}.rs`（已存在）／`entity/src/sys_operation_log.rs`（已 INET）／`model/audit.rs`（AuditOperator.ip 已 Option<IpNetwork>）／`facade/sys_operation_log.rs`（已無條件寫 operator_ip）／`deploy/nginx`（已轉發、僅驗）。

## 11. forward-compat / 下游
- ⚠️w lockout（波3）：本刀備真實 client IP＋既有 2 索引、per-ip/per-user 政策待 ⚠️w。
- ⚠️b 讀端+UI（波2）：三 log 讀端＋R_SUPER policy seed＋manage 新頁。
- op-log live 回填（波1+）：首個 mutating handler 把 RequestContext 餵 `mutate_in_txn`。
- cleanup-job（波3）／retention（波4 ⚠️n）／全流量 obs（波4）。
