# Phase 0 Research: 007-audit-overlay

> 接地源＝當前 lineage（`b9de316`）親 grep（handler/auth.rs／entity／audit.rs／facade／deploy nginx）＋xdb 拷貝源親讀（`fork260509-rev2-anew-rust-api@rev2-admin-rust-api-rebase260531:xdb/`、§I.5 拷貝例外 ⚠️v）＋constitution v1.1.1 親 grep（§5.9 不在憲法、§I.5 列 xdb 例外）。**NEEDS CLARIFICATION = 0**（brainstorm＋specify 已全拍）。
> ★ 借前代 v2 設計、但對齊當前 lineage：v2 多項「工作」在 rev3 已 MOOT（見 R3）。

## R1 — xdb crate API ＋ PANIC gotcha（拷貝源親讀）

**Decision**：整檔拷入 `xdb` 為 workspace member（§I.5/⚠️v）；boot 以 **file-exists 守門 + `xdb_ready` flag** 包 `searcher_init`，`search_by_ip` 僅在 ready 時呼叫（否則 region=None 降級）。
**Rationale（親讀 `xdb/{Cargo.toml,src/lib.rs,src/searcher.rs}`）**：
- API：`pub fn search_by_ip<T: ToUIntIP>(ip)->Result<String,Box<dyn Error>>`（searcher.rs:62、回 `中国|0|福建省|福州市|电信` pipe）；`pub fn searcher_init(xdb_filepath: Option<String>)`（:143、prewarm `get_full_cache`）；`const XDB_FILEPATH_ENV="XDB_FILEPATH"`（:13）。`lib.rs` re-export `search_by_ip, searcher_init`。
- **★ PANIC**：`get_full_cache()` `.expect("file open error")`(:135)／`.expect("load file error")`(:137)、`default_detect_xdb_file().unwrap()`(:127,:144) → **缺檔即 panic、非 best-effort**；且 `search_by_ip` 內部呼 `get_full_cache`(:77) 亦會 panic。⇒ 必 boot 守門＋ready flag、ready 才 search。
- deps：`once_cell`/`tracing`/`tracing-subscriber`（皆 `{workspace=true}`；workspace 需暴露 `once_cell`）；dev-deps `criterion 0.5.1`+`rand 0.8`；`[[bench]] name=search harness=false`；`resources/{ip2region.xdb(~10.5MB), ip.test.txt}`。
**Alternatives**：embed（`include_bytes!`）——否決（改 vendored crate 違整檔拷貝紀律；rev2 xdb 僅 file-path API）。改 vendored panic 為 Result——否決（整檔零改紀律；以 boot 守門替代）。

## R2 — current login 終端路徑 ＋ inner/outer（親 grep `handler/auth.rs`）

**Decision**：login refactor 為 `login_inner(...) -> Result<Success, (Option<i64> operator, AppError)>`；outer `login(State, Extension<RequestContext>, Json<LoginReq>)` 對 inner 結果**記 exactly-one** login_attempt 再回 AppError——由建構保證 FR-004「每終端路徑恰一筆」。
**Rationale（親 grep login L49-124）**：實際終端 `?`/return 多於 brainstorm 的 7 點：`find_by_user_name.await?`(L58 DbErr)＋`.ok_or(LoginFailed)?`(L59)／`!verify→LoginFailed`(L63)／`roles_of_user.await?`(L67)／`sign(access).map_err(Internal)?`(L92)／`sign(refresh)?`(L94)／`from_timestamp.ok_or(Internal)?`(L104)／`begin.await?`(L106)／`set_pointer.await?`(L107)／`insert_token.await?`(L116)／`commit.await?`(L117)／success(L120)。逐點散記易違 exactly-one ⇒ 收斂為 inner→Result、outer 單一記點。
**operator_id 規則（R3 of brainstorm）**：pre-identity 失敗（L58 lookup-DbErr／L59 not-found／L63 password-wrong）→ `None`；post-identity 失敗（L67 起：roles／sign／timestamp／txn，user 已驗）→ `Some(uid)`；success → `Some(uid)`。
**Alternatives**：7 個散 `record_login_attempt` 呼點（v2 §4.5）——否決（exactly-one 靠紀律易漏；inner/outer 由型別保證）。

## R3 — ★ INET 地基已落地（當前 lineage、v2 多項 MOOT）（親 grep）

**Decision**：facade `*_active_model` 以 `IpNetwork::from(IpAddr)`（V4→/32 V6→/128）寫 INET、sea-orm native binding、無 PG 42804；**無型遷移、無 entity 改、無 migration**。
**Rationale（親 grep `entity/src/*`／`model/audit.rs`／`facade/sys_operation_log.rs`／`Cargo.lock`）**：
- `entity/src/sys_access_log.rs`（10 欄、`client_ip: IpNetwork`、`operator_id: i64` NN）＋`sys_login_attempt.rs`（9 欄、`operator_id: Option<i64>`、2 複合索引）**已存在**（004）。
- `sys_operation_log.operator_ip: Option<IpNetwork>`（已 INET）；`audit.rs` `AuditOperator{id:i64, ip:Option<IpNetwork>}`＋`use sea_orm::entity::prelude::IpNetwork`；`facade/sys_operation_log::write_in_txn` **已無條件** `operator_ip: Set(...o.ip)`——**無 42804 defer 分支待解**。
- `Cargo.lock` 已 `ipnetwork 0.20.0`＋`time 0.3.37`＋`jsonwebtoken 9.3.1`、1.86 build 綠（006 已解 time-pin）。
⇒ v2 research R3（ipnetwork MSRV 重驗）／R6（String→INET 遷移＋解 42804 defer）／entity Model 建立 **全 MOOT**。`ipnetwork` 走 `sea_orm::entity::prelude::IpNetwork` re-export（零新顯式 dep；`contains()`/`from()` 同型可用）。
**Alternatives**：顯式 `ipnetwork="0.20"` server dep（v2）——否決（re-export 已足、零新 dep、合 audit.rs 現況）。

## R4 — resolve_client_ip trusted-proxy（手刻純函式、安全敏感）

**Decision**：手刻 `resolve_client_ip(peer: IpAddr, xff: Option<&str>, trusted: &[IpNetwork]) -> IpAddr`：① `!is_trusted(peer)→return peer`（peer-gate 防偽造）② XFF `split(',').rev()`、跳 trusted、第一個不可信＝真 client（rightmost-untrusted；畸形 token `parse` 失敗略過）③ `return peer`（fail-safe）。`is_trusted` 用 `IpNetwork::contains`。`TRUSTED_PROXY_CIDRS` env（comma CIDR）→`Vec<IpNetwork>`、**fail-safe 預設空**（未設→peer 不可信→用 peer、dev 正確）。CF 段入 trusted、零 CF code。
**Rationale**：重用 ipnetwork（已在圖）＝零新 dep；純函式 test-first（合 ⚠️g TDD）；安全鐵則「絕不盲信 forwarded、trusted 須顯式配置、預設 fail-safe」防偽造規避 lockout/嫁禍/污染稽核。
**Alternatives**：crate `axum-client-ip`——否決（edge-case 戰功對「我們控 nginx 轉乾淨 XFF」溢出、+新 dep）。nginx-edge 解析（β）——否決（app 端測不到、綁 nginx 正確性）。直連 peer（v1）——否決（nginx 後方 peer=nginx IP、IP 軌與 lockout 皆廢）。

## R5 — audit_mw 全域中介層 ＋ RequestContext

**Decision**：`audit_mw(State<AppState>, ConnectInfo<SocketAddr>, Request, Next) -> Response`（無 Result、永不 reject）。前段**無條件**建 `RequestContext{ operator_id:Option<i64>, client_ip:IpAddr, x_forwarded_for:Option<String>, region:Option<String>, trace_id:String }` 塞 extensions（否則 /login 讀 Extension panic）；後段取 `response.status().as_u16()`、**gate=`operator_id.is_some()`** 才寫一列 access_log（best-effort、`tracing::warn` 吞 DbErr、不擋回應）。operator_id via 獨立寬鬆 bearer `enforce::bearer(headers,&state.jwt).ok().map(|c|c.uid)`（Some/None 永不 reject）。region via `xdb::search_by_ip` best-effort（xdb_ready=false/IPv6/parse-fail→None）。掛 main **最外層**；`into_make_service_with_connect_info::<SocketAddr>()` 取 peer。
**Rationale（親讀 `enforce.rs`/`main.rs`/`state.rs`）**：bearer 在 `auth/enforce.rs`、`bearer(&HeaderMap,&JwtConfig)->Result<Claims,AppError>`、Claims.uid；main 現為 plain `axum::serve`（需改 connect_info）；與 006 `enforce_mw`(strict、壞 token→3333) 各自獨立 verify、不共用 Claims、**enforce_mw 不動**（conform DESIGN §3.3/§10.4 operator-gate、無 path skip-set）。
**Alternatives**：逐 handler 自寫 audit——否決（重複、漏 global layer）；access-log 全流量＋sentinel(0)（v1）——否決（破 operator_id NN 意圖、衝突 §3.3/§10.4）。

## R6 — nginx XFF 轉發（親 grep、零改）

**Decision**：nginx **零改、僅驗**。
**Rationale（親 grep `deploy/nginx/conf.d/_locations.inc`）**：`/api/`→`rust-api:31081` 已 `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`＋`X-Real-IP`＋`X-Request-Id $request_id`。`TRUSTED_PROXY_CIDRS` 為 app-side config（compose env 注入）、prod 依拓樸填、dev 空。
**Alternatives**：nginx edge 解 real-IP——否決（綁 nginx config 正確性、app 測不到）。

## R7 — op-log operator/trace threading seam（誠實範圍）

**Decision**：建 threading helper（`RequestContext`→`AuditOperator{id, ip:Some(IpNetwork::from(ctx.client_ip))}`＋`trace_id:Some(ctx.trace_id)`）餵既有 `mutate_in_txn`；**本刀 = seam ready ＋ test-only live smoke** 證 op-log operator_id/operator_ip/trace_id 由恆 None→真值（INET round-trip、解 §3.7/§3.8）；**production handler threading 留波1+**。
**Rationale（親 grep）**：唯一 `mutate_in_txn` consumer `facade/sys_user::soft_delete(conn,id,operator:AuditOperator,trace_id)` 已收 operator+trace 參數、INET 已通，但 **test-only**（grep handler/ 零 caller、無 live mutating 端點）。
**Alternatives**：合成臨時 mutating 端點即時驗 live——否決（scope creep）；假裝 live 回填——否決（不誠實）。

## R8 — §5.9 推進 Constitution 對齊（親 grep 憲法）

**Decision**：client_ip 由「直連 client_ip」（DESIGN §5.9 凍結文字）推進為「forwarded 鏈 trusted-proxy 解析真實 IP」；**無需 Amendment**。
**Rationale（親 grep `constitution.md`）**：§5.9 **不在** constitution（grep `5\.9|audit|client_ip|xdb|XFF` 僅命中 §I.5 xdb 拷貝例外與 menu enforce、無 §5.9）；亦非 §II 13 拍板、非 DECISIONS §1 項。權威鏈（§V.1）constitution＞DECISIONS＞DESIGN，本推進屬 DESIGN 細節、不動前兩者 → Constitution Check Q6 PASS（非 violation）。留痕 spec Assumptions＋本檔；下次 DESIGN 重鑄摺合 §5.9。
**Alternatives**：走 Amendment——否決（§5.9 非憲法/決策層、Amendment 不適用）；保留直連 peer 守 §5.9 字面——否決（功能廢、見 R4）。

## R9 — prod build 紀律（新 workspace crate）

**Decision**：acceptance **必含 prod target image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、C-V-8）；Dockerfile 加 xdb COPY（Manifest `xdb/Cargo.toml`＋Source `xdb/src`＋`xdb/benches`＋`xdb/resources`）、`--bins` 跳 `[[bench]]` 編譯、`--locked`；驗 `.xdb` 在 image＋prod boot `xdb_ready=true`。
**Rationale（CLAUDE.md §3 紀律＋親讀 `deploy/Dockerfile.rust-api.txt`）**：新 workspace member 必經 prod multi-stage 逐 crate COPY；dev bind-mount 遮 prod COPY 缺口＋`[[bench]]` 坑（rev2 教訓）。
**Alternatives**：只靠 dev build——否決（§3 紀律明禁）。

## 三-grep 紀律落地
- **facade/entity 返回型**：sys_access_log/sys_login_attempt/sys_operation_log 欄＋AuditOperator 已親 grep（R3）；facade 回 `Result<(),DbErr>`。
- **wire 3-端**：**N/A**——007 無新 wire/業務端點、base-web 零改（§I.1 未觸）。
- **命名對照**：xdb API（R1）／login 終端點（R2）／IpNetwork re-export（R3）／bearer 簽名・Claims.uid（R5）皆親 grep actual code。
- **CDP smoke**：**N/A**——007 後端純寫端、無 modal；live psql 證 audit 列（C-V-4~7）。
- **list filter 空字串守門**：N/A——007 無 list 端點（讀端＝波2）。
