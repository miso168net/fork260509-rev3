# Research: 007-audit-overlay（Phase 0）

**Date**: 2026-06-15 | **Branch**: `007-audit-overlay` | **Spec**: [spec.md](spec.md)

> 來源：7 軌並行驗證實際 code（rev2 015 源〔branch `rev2-admin-rust-api-rebase260531`〕／m001／現 rust-api 006／Cargo／deploy/nginx）。⚠️g 受控參照（讀允許、拷貝禁止；以下記 shape 非可貼 code）。每項 Decision / Rationale / Alternatives。

---

## R1 — rev2 015 audit 真實簽名（重寫對照基準）

**Decision**：rev3 audit_ctx + 2 facade + login inner/outer 依以下 rev2 實證 shape **全新重寫**（⚠️g）；唯一新增 = `resolve_client_ip`（rev2 沒有）。

- `RequestContext { operator_id: Option<i64>, client_ip: IpAddr, x_forwarded_for: Option<String>, region: Option<String>, trace_id: String }` —— 中介層**無條件**塞 request extensions（handler 前）。
- `audit_mw(State<AppState>, ConnectInfo<SocketAddr>, Request, Next) -> Response`（無 Result）；`next.run()` 後取 `response.status().as_u16()`；**access-log 寫入 gate = `operator_id.is_some()`**。
- `AccessLogEvent { operator_id: i64, method, path, http_status: i32, client_ip: IpAddr, x_forwarded_for: Option<String>, region: Option<String>, trace_id: String }`。
- `LoginAttemptEvent { attempted_user_name: String, success: bool, operator_id: Option<i64>, client_ip: IpAddr, x_forwarded_for, region, trace_id }`。
- login **inner/outer split**：outer `(State, Extension<RequestContext>, Json<LoginReq>)`；`record_login_attempt` **6 個呼叫點**＝5 失敗〔user-not-found／password-wrong／role-lookup-error／access-token-sign-error／refresh-token-sign-error〕＋1 成功〔operator_id=Some(user.id)〕。
- facade：`*_active_model(Event)`〔facade 層才 `IpNetwork::from(IpAddr)` seam〕＋`write(&db, event) -> Result<(), DbErr>`〔單 INSERT、no-txn〕。
- `best_effort_audit(Result<(), DbErr>, &str) -> ()`〔`tracing::warn!` 吞 Err、不傳播〕。
- operator_id 抽取：`bearer_token(&headers)` → `jwt::verify(token, &state.jwt.jwt_secret, JWT_AUD).ok().map(|c| c.user_id)`——**獨立於 enforce_mw**。
- trace_id：honor `x-request-id`〔trim、`chars().take(64)` UTF-8 邊界安全〕／無則 uuid v4。
- region：`xdb::search_by_ip(client_ip.to_string())` best-effort、IPv6/parse 失敗→None。

**★ 關鍵差異（驅動 §5.9 推進）**：rev2 `extract_client_ip(peer) = peer.ip()`（**直連 peer**）、`extract_x_forwarded_for` 讀 raw header **不做 proxy-trust 解析**。007 **新增** `resolve_client_ip`（trusted-proxy rightmost-untrusted）取代「client_ip = 直連 peer」，raw XFF 仍原文存欄。

**Rationale**：rev2 015 為 ground truth；rev3 重寫保 shape 相容、僅在 client_ip 來源這點推進。
**Alternatives**：照搬 rev2 直連 peer（被否——nginx 後方廢值、§5.9 推進主旨）。
**Evidence**：`fork260509-rev2-anew-rust-api`@`rev2-admin-rust-api-rebase260531`：audit_ctx.rs:36-174、handler/auth.rs:28-161、facade/sys_{access_log,login_attempt}.rs、main.rs、auth/{bearer,jwt}.rs。

---

## R2 — m001 兩表逐欄（entity Model 鏡像基準）

**Decision**：entity `sys_access_log` / `sys_login_attempt` Model 逐欄鏡像 m001（型/null性/順序）；`client_ip` 用 `ipnetwork::IpNetwork`（`with-ipnetwork`）。**無 migration**（表已在 m001、波 0 一次全建 ⚠️t）。

- `sys_access_log`（10 欄）：`id BIGINT PK auto`、`operator_id BIGINT NOT NULL`、`method TEXT NN`、`path TEXT NN`、`http_status INTEGER NN`、`client_ip INET NN`、`x_forwarded_for TEXT NULL`、`region TEXT NULL`、`trace_id TEXT NULL`、`created_at TIMESTAMPTZ NN default CURRENT_TIMESTAMP`。**無額外 index**。
- `sys_login_attempt`（9 欄）：`id BIGINT PK auto`、`attempted_user_name TEXT NN`、`success BOOLEAN NN`、`operator_id BIGINT NULL`、`client_ip INET NN`、`x_forwarded_for TEXT NULL`、`region TEXT NULL`、`trace_id TEXT NULL`、`created_at TIMESTAMPTZ NN default CURRENT_TIMESTAMP`。**2 index**：`idx_login_attempt_ip_time (client_ip, created_at)`、`idx_login_attempt_user_time (attempted_user_name, created_at)`。
- operator_id 兩表差異：access-log **NOT NULL**（已認證才寫的結構落地）vs login-attempt **NULL**（失敗無 operator）。

**Rationale**：data-model �forced 對齊 actual schema、防 type-lie。
**Evidence**：`rust-api/migration/src/m001_rev2_schema.rs:547-588`（access-log）、`591-635`（login-attempt）、`799-819`（2 index）。

---

## R3 — ipnetwork 0.20 / `with-ipnetwork` MSRV（≤1.86）

**Decision**：加 `ipnetwork = "0.20"` + sea-orm feature `with-ipnetwork`；**Cargo.lock pin 至 1.86-safe 版本**、builder `cargo build --locked`。**確切 0.20.x MSRV 與 prod build-verify 屬 implementation acceptance**（read-only research 無法定論、列風險）。

- 現況：`rust-toolchain.toml` channel=1.86.0；Cargo.lock **無** ipnetwork、`with-ipnetwork` 未啟。
- 紀律（依 §3.8 + memory `jsonwebtoken9-msrv-time-real-graph` / `sea-orm-entity-datetime-feature-gate`）：啟新 feature 把 feature-gated crate 拉進**真 compile graph** → 必驗 MSRV、釘 lock、`--locked` 防靜默 re-resolve。
- 連帶驗：啟 `with-ipnetwork` 後 `cargo tree` 是否再拉其他 feature-gated crate 入圖。

**Rationale**：feature-gated 不入圖 ≠ 版本無影響（006 time 教訓）；先定策略、implementation 落地實測。
**Alternatives**：若 0.20.x 任一版超標 1.86 → 降 0.19.x（相容性查）或改 `Expr` cast 不用 ipnetwork custom type（fallback）。
**Risk（轉 implementation/acceptance）**：① 實測 `cargo update -p ipnetwork --precise <ver>` + `cargo build --locked` 找 lower bound；② **prod image build 綠為 acceptance**（C-V）；③ lock 補 ipnetwork 後對比前後依賴清單防意外新 crate。
**Evidence**：`rust-api/rust-toolchain.toml:4`、`rust-api/Cargo.toml:10-23`、CHECKLIST §3.8。

---

## R4 — xdb 打包：**file-path 載入（決策反轉 embed→file-path、user 拍 2026-06-15）**

**Decision**：xdb crate **自 rev2 整檔原樣拷貝、不改**（§I.5 例外 ⚠️v/#6）；**boot file-path 載入**（`searcher_init(Option<XDB_FILEPATH>)` + OnceCell in-memory cache）；region **best-effort**（缺檔/查不到→None、不 panic）。Dockerfile 補齊 xdb 全套 COPY。

> **反轉 brainstorm §4.4「embed include_bytes!」**。R4 把 rev2 xdb ground 在實際 code，brainstorm 的 embed 假設被推翻：

- rev2 xdb（`fork260509-rev2-anew-rust-api/xdb/`、兩 rev2 分支皆有）**只有 file-path 載入**（`searcher.rs` `File::open` + `read_to_end` → OnceCell cache）、**無 buffer-load/from-bytes/include_bytes! API**。embed 須**改 vendored crate 加 buffer API**（違整檔拷貝精神）。
- `.xdb` = **11,070,083 bytes（~10.5MB）**；rev2 file-path 本就全載入記憶體（in-memory search）→ **embed 與 file 兩案都 10.5MB 在記憶體**，embed 只多「runtime 無檔」這點好處、代價是 +10.5MB binary + 改 crate。
- Dockerfile COPY **閃不掉**：xdb 有 `[[bench]]` target（`benches/search.rs` criterion）→ 兩案 builder 都要 COPY `xdb/{Cargo.toml,src,benches,resources}`，否則 manifest parse 失敗。當前 `deploy/Dockerfile.rust-api.txt` 缺這些 COPY 行（兩案都要補）。
- API：`search_by_ip<T: ToUIntIP>(ip) -> Result<String, Box<dyn Error>>`（回管道分隔 region 如 `中国|0|福建省|福州市|电信`；ToUIntIP impl 於 u32/&str/Ipv4Addr）。

**Rationale**：file-path 守整檔拷貝（crate 不動）、binary 不肥、rev2 實證；best-effort 下「runtime 需檔」風險可控（缺檔→region None 非致命）。
**Alternatives**：embed（被否——須改拷貝 crate + 10.5MB binary、COPY 仍要、in-memory 兩案一樣）。
**Follow-up**：Dockerfile builder 補 `COPY rust-api/xdb/{Cargo.toml→./xdb/, src→./xdb/src, benches→./xdb/benches, resources→./xdb/resources}`；`XDB_FILEPATH` 容器設為實際路徑（或 default detect `resources/ip2region.xdb`）。
**Evidence**：`fork260509-rev2-anew-rust-api/xdb/{Cargo.toml,src/searcher.rs:142,resources/ip2region.xdb}`、`deploy/Dockerfile.rust-api.txt:30-41`。

---

## R5 — middleware ordering（audit_ctx outermost + 不動 006 enforce_mw）

**Decision**：`main.rs` 加 `into_make_service_with_connect_info::<SocketAddr>()`；Router `.layer(audit_ctx)` 為 **outermost**（包全部含 /health、/auth/login）；**006 enforce_mw 一行不動**。

- 現況：plain `axum::serve(listener, app)`、**無** connect_info、**無**全域 layer；enforce_mw per-route `route_layer`、獨立嚴格驗 bearer（壞→3333/5003）。
- stack：connect_info（最外）→ audit_ctx（寬鬆驗 bearer、寫 None 也續行）→ routes →（per-route）enforce_mw（嚴格）。
- audit_ctx 寬鬆驗 vs enforce_mw 嚴格驗 **語意不同、各自獨立**、Request 不被 audit_ctx 改 → 不衝突。

**Rationale**：outermost 確保未認證 /login 也有 ctx（P1）；獨立驗避免耦合、不擾動已收 006。
**Evidence**：`rust-api/server/src/main.rs:61-71`、`auth/enforce.rs:88-131`、`auth/bearer.rs:34-43`、`state.rs:104-112`。

---

## R6 — 005 `AuditOperator.ip` 真 INET 化（解 §3.8 42804 defer、驅動 FR-013）

**Decision**：把 op-log 的 operator_ip 從「恆 None defer」改為**寫真值**：`AuditOperator.ip: Option<String>` → `Option<IpAddr>`、entity `sys_operation_log.operator_ip` 型別遷移為 `ipnetwork::IpNetwork`（`with-ipnetwork`）、啟用 facade 現 defer 的 `Some(ip)` 分支（用 IpNetwork、解 42804）。

- 現況：`AuditOperator.ip: Option<String>`（audit.rs:37「INET 寫入 defer」）；`AuditEvent.operator/trace_id: Option`；facade `sys_operation_log.rs:26` `None→NotSet`（避 42804）、`Some(ip)→Set`（**defer、005 never-run**）；entity `operator_ip: Option<String>`（刻意 String≠INET）。
- 改動面：entity 型遷移 + facade `Some(ip)` 分支用 IpNetwork；audit_ctx 把 RequestContext 的 operator_id/trace_id/client_ip 餵進 005 `mutate_in_txn` 的 `AuditEvent`。
- **005 測試**：unit `audit_active_model...omits_operator_ip_when_no_operator`（sys_operation_log.rs:51-74，斷 `!sql.contains("operator_ip")`）—— None-path **不破**；3 live smoke（commit/no-op/rollback，皆 ip:None）—— **需 regression 驗、預期續綠**（None path 不變）；**新增** Some(ip)-path 純測 + live（真 INET 無 42804）。

**Rationale**：FR-013 要 op-log 帶真 operator/trace/ip；§3.8 42804 defer 至此解。
**Risk**：型遷移須顧 sea-orm type mapping；005 既有測 None-path 斷言保留、不誤動。
**Evidence**：`rust-api/server/src/model/audit.rs:34-50`、`facade/sys_operation_log.rs:26-74`、`entity/src/sys_operation_log.rs:17`、`m001:527-529`、`facade/live_smoke.rs:129-281`。

---

## R7 — nginx XFF 轉發 + `TRUSTED_PROXY_CIDRS` 注入

**Decision**：**nginx 不用改**（已轉發 XFF）；`TRUSTED_PROXY_CIDRS` env 注入 compose dev/prod 的 rust-api service、**fail-safe 預設空**（未設→空集合→peer 不可信→用 peer）。

- front-nginx **已轉發** `X-Forwarded-For`（`deploy/nginx/conf.d/_locations.inc:5` `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`）；`/api/`→rust-api proxy_pass（`:17-22`，strip `/api`、轉 Host/X-Real-IP/X-Forwarded-For/X-Forwarded-Proto/X-Request-Id）。
- 注入點：`docker-compose.dev.yml`（rust-api 已有 environment 段、加一行）／`docker-compose.prod.yml`（rust-api 無 environment 段、需新增）；格式逗號分隔 CIDR（內網 + 視部署加 CF 段）。
- `state.rs`（已有 `file_or_env`）007 加 `TRUSTED_PROXY_CIDRS` 解析為 `Vec<IpNetwork>`、parse 失敗/未設→空。

**Rationale**：nginx 既符標準轉發、零改；trust 集合為 app-side config、prod 依實際拓撲填（CF 段線上維護）。
**Evidence**：`deploy/nginx/conf.d/_locations.inc:5,17-22`、`docker-compose.{dev,prod}.yml`、`rust-api/server/src/state.rs:40-68`、`main.rs:71`。

---

## 彙整：對 plan 的淨輸入

- **無 migration、無新 wire/業務端點**；entity 2 新 Model + 1 既有（sys_operation_log）型遷移。
- **新 workspace crate `xdb`**（vendored file-path、§I.5 例外）→ acceptance **必含 prod image build**（CLAUDE.md §3）。
- deps：+`ipnetwork 0.20`、sea-orm `+with-ipnetwork`（MSRV 風險、lock pin、`--locked`）。
- deploy：Dockerfile 補 xdb COPY；compose 加 `TRUSTED_PROXY_CIDRS` env；nginx 零改。
- **DESIGN §5.9 推進**（client_ip 直連→XFF trusted-proxy 解析）：非 constitution/DECISIONS §1 項、屬 DESIGN 細節推進，記此 + brainstorm、下次 DESIGN 重鑄摺合。
- 無 NEEDS CLARIFICATION 殘留。
