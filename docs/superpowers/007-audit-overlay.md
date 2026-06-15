# 007-audit-overlay — Phase 0 Brainstorm（spec-design・v2 重做）

> 波 0 **最後一刀**（第二 audit 刀）。005 op-log → 007 access-log + login-attempt，audit 軌**三 sink 收齊**；合刀拆 006→007 序列之尾（006 已收 `2c5a2a1`）。
> **本檔為 v2 重做**（v1 `1bb1a96` 已 hard-rollback 退掉），修正兩處設計缺陷：① access-log scope 改 **conform 凍結 DESIGN**（v1 的「全部+sentinel」與 §3.3/§10.4 衝突）；② 真實 client IP — rev3 在 front-nginx（其前可能再有 Cloudflare／其它 proxy）反代後方，直連 peer = nginx IP，故改 **app-side 從 XFF 解析真實 client IP**。
> 本檔交手動 `/speckit-specify` 形式化（**非 writing-plans**；CLAUDE.md §3）。
> **凍結權威**：DESIGN §5.2（audit 三 sink、縱切兩刀）／§5.9（region 由 client_ip 解；本刀**推進** client_ip 來源、見 §4）／§1.5（xdb L3 → audit_ctx L7 跨層邊）／§3.1（審計 append-only 不可竄改）／§3.3·§10.4（access-log 已認證才記、單一 operator gate、無 path 排除清單）／§8.2（007 刀定義）。⚠️v（xdb vendored 併本刀）／⚠️g（rust-api 全新寫、rev2 受控參照讀允許拷貝禁止）／⚠️w（login lockout 為下游消費者，本刀只備資料）。本檔不得與之衝突（衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔）。

---

## 0. 刀界決策前情

- ⚠️v 拍板：`xdb` 併入**首個消費的 audit 刀** = 007（access-log/login-attempt 兩表帶 `region`、由 xdb 解）。
- **無 migration**：`sys_access_log` / `sys_login_attempt` 兩表已在 m001（002 baseline、⚠️t schema 波 0 一次全建）。本刀純 entity/facade/middleware/sub-crate＋一處 deploy（nginx 轉發 XFF）。**真實 IP 修法不動 m001**（只改 `client_ip` 欄裝什麼值、lockout 用哪個既有索引）。
- 007 = audit 軌第 2/3 sink + audit_ctx 中介層 + xdb sub-crate，並**回填 005 op-log 恆 None 的 operator/trace** + **解掉 005 defer 的真實 INET 寫入**（§3.8 forcing function）。

## 1. 目標一句話

把 audit 軌補滿：HTTP **access-log** + **login-attempt** 兩 append-only sink + 全域 **`audit_ctx`** 中介層（`RequestContext` 自動帶 operator/trace/client_ip/xff/region）+ **`xdb`**（ip→region）+ **app-side 真實 client IP 解析**（從 XFF、trusted-proxy 模型）；真實 INET 寫入（`with-ipnetwork`、無 42804）一併解 005 op-log 的 operator_ip。

## 2. Context（探索蒐集）

### 2.1 rev2 015 參考形（⚠️g 受控參照重寫、非照拷）

- `audit_ctx.rs`：middleware **無條件**對每請求建 `RequestContext` 塞 request extensions（**handler 前**）；`operator_id` 走獨立 bearer 抽取、成功 `Some(user_id)`／失敗 `None`、**永不 reject**（與 enforce_mw 嚴格驗證語意不同）。access-log 寫入 gate = `operator_id.is_some()`（rev2 實測即此、**非** v1 的「全部+sentinel」）。
- login handler 讀 `Extension(ctx)` 取 `ctx.client_ip` 寫 login-attempt；成功+失敗各 exactly-one 列（inner/outer split）。
- **INET**：sea-orm `with-ipnetwork` feature + `ipnetwork = "0.20"`；entity `client_ip: ipnetwork::IpNetwork`；facade 收 `IpAddr` → `IpNetwork::from(ip)`（V4→/32、V6→/128 原生 impl）→ sea-orm 原生 inet binding、**無 PG 42804**。codebase 首個寫真值 INET 的路徑。
- facade `sys_access_log.rs` / `sys_login_attempt.rs`：append-only write，`*_active_model` 純映射 seam（可純測）。
- `xdb`：ip2region binding（`searcher`），`.xdb` 二進位資料檔；rev2 為 file-based 載入（本刀改 **embed**、見 §4）。

### 2.2 凍結權威 + 本刀關係

- **§3.3 / §10.4（access-log 已認證才記、未認證刻意不落列、單一 operator gate、無 path 排除清單）**：本刀 **conform**。`sys_access_log.operator_id NOT NULL` 是這條 gate 的結構落地。
- **§5.9（region 由直連 client_ip、非 XFF；nginx 信任邊界＝§3.4 follow-up）**：本刀**推進** — 把 §3.4 的信任邊界 follow-up 提前做，`client_ip` 改為「從 XFF 經 trusted-proxy 解析的真實 client IP」、region 隨之由真實 IP 解。**屬偏離凍結 DESIGN §5.9，待 `/speckit-plan` Constitution Check 對齊**（spec.md 明載；下次 DESIGN 重鑄摺合）。

### 2.3 rust-api 現況（006 後）

- m001 已建 `sys_access_log`（10 欄：`operator_id BIGINT **NOT NULL**`／method／path／http_status／`client_ip **INET NOT NULL**`／x_forwarded_for TEXT NULL／region TEXT NULL／trace_id TEXT NULL／created_at）＋ `sys_login_attempt`（9 欄：attempted_user_name／success BOOL／`operator_id BIGINT **NULL**`／`client_ip **INET NOT NULL**`／x_forwarded_for TEXT NULL／region TEXT NULL／trace_id TEXT NULL／created_at ＋ 2 index〔`idx_login_attempt_ip_time`=(client_ip,created_at)、`idx_login_attempt_user_time`=(attempted_user_name,created_at)〕）。**兩表無 FK**。
- 005 `mutate_in_txn`／`AuditEvent`（`operator:Option<AuditOperator>`、`trace_id:Option<String>` **恆 None**）＋ `AuditOperator{ id:i64, ip:Option<String> }`（ip 恆 None、§3.8 defer 真 INET）。
- 006 `verify_bearer→Claims.user_id`（operator_id 源）＋ `enforce_mw`（嚴格驗證、壞 bearer 擋）；`login` handler（成功 `user.id`／三憑證失敗一致 1000）。**本刀不動 enforce_mw**。
- `main.rs`：`axum::serve(listener, app)` plain（**無 connect_info、無全域 middleware**）→ 007 改 `into_make_service_with_connect_info::<SocketAddr>()` + `audit_ctx` layer。
- nginx（001 front-nginx conf）：需**確保轉發 `X-Forwarded-For`**（標準 `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`、多半已有、驗一下）。

### 2.4 消費者（決定本刀面）

- 005 op-log：007 `audit_ctx` 顯式餵 operator/trace（對齊 005 SC-004「顯式 param、非隱式 context」）。
- 006 bearer/login：operator_id 源 ＋ login-attempt 寫點。
- 波 1+ gated endpoints：access-log 真實流量來源（本刀建機制、用 getUserInfo 認證請求即可實測；波 1 起有量）。
- **⚠️w login lockout（未來、波 3 候選）**：消費 `sys_login_attempt` 的 `(client_ip,created_at)`/`(attempted_user_name,created_at)` 索引。**本刀備齊真實 client IP 後、per-ip lockout 現可行**；per-ip／per-user／both 政策為 ⚠️w 未來定。

## 3. Scope

- **IN**：`xdb` sub-crate（vendored ⚠️v、embed）／`audit_ctx` 中介層 + `RequestContext`／`resolve_client_ip` 手刻純函式（XFF trusted-proxy 解析）／access-log 寫（conform：`operator_id.is_some()` 才寫、無 sentinel／無 skip-set）／login-attempt 寫（login handler inner/outer、成功/失敗各一列）／op-log operator/trace **回填**／真實 INET（`with-ipnetwork`、含 op-log operator_ip）／`main.rs` connect_info + audit_ctx layer／nginx 轉發 XFF（deploy）／`TRUSTED_PROXY_CIDRS` config。
- **無 migration、無新業務端點**。
- **OUT**：審計查詢讀端 + UI（⚠️b、波 2）／login lockout 本體（⚠️w、本刀只備資料）／access-log retention 清理（波 4 obs／⚠️n）／`CF-Connecting-IP` 特判（本刀 CF 走 trusted CIDR config 即夠）／全流量（含未認證）日誌（→ observability 波 4 obs/tracing→loki、非審計表）。

## 4. brainstorm 拍板（user 親決 2026-06-14 ~ 06-15）

| # | 決策 | options | 結論 |
|---|---|---|---|
| access-log 範圍 | 已認證才記／全部+匿名 sentinel | conform DESIGN（user 選） | **conform §3.3/§10.4：`operator_id.is_some()`（已認證）才寫一列、未認證刻意不落列、無 sentinel／無 /health skip-set**（單一 operator gate 天然排除未認證/health）。否決 v1「全部+sentinel(0)+skip-set」（與 §3.3/§10.4 衝突、sentinel=0 繞過 `operator_id NOT NULL` 意圖、偏離 rev2 015 實際）。「全流量日誌」歸 observability（波 4 obs），非審計表 |
| client_ip 來源 | 直連 peer／app-side XFF 解析(α)／nginx edge 解析(β) | app-side 解析（A/α、user 選） | **app-side 從 XFF 經 trusted-proxy 模型解析真實 client IP**；`x_forwarded_for TEXT` 存原始 XFF 鏈備查（user 明示）。**推進 DESIGN §5.9（直連→XFF 解析）、待 /speckit-plan Constitution Check 對齊**。否決 v1 直連 peer（nginx 後方→peer=nginx IP→audit IP 軌與 per-ip lockout 皆廢、client_ip 名實不符）。β（nginx edge）被否：app 端測不到、綁 nginx config 正確性 |
| 解析實作 | 手刻純函式／crate(axum-client-ip) | 手刻（user 選） | **手刻 `resolve_client_ip`**（rightmost-untrusted＋peer-gate＋fail-safe、見 §5.3）：重用 ipnetwork〔INET 欄本就入圖〕**零新 dep**、純測（合 ⚠️g TDD）；CF 走 trusted CIDR config（CF 段入 `TRUSTED_PROXY_CIDRS`）零 vendor code。crate 的 edge-case 戰功對「我們控 nginx 轉乾淨 XFF」溢出 |
| audit_ctx 結構 | — | P1–P4 + 獨立 bearer | **outermost(P3)＋無條件建 ctx(P1)＋`into_make_service_with_connect_info`(P2)＋best-effort 寫(P4)＋獨立寬鬆 bearer 取 operator(成功 Some/失敗 None、永不 reject)；006 enforce_mw 不動**（兩者各自獨立驗、雙驗 HS256 成本可忽略） |
| xdb 打包 | file-based(rev2)／embed | embed（user 選） | **embed `include_bytes!`**（vendored crate 加 buffer-load API、ip2region full-memory）：無 runtime 檔依賴、無缺檔 boot panic、順帶閃 runtime COPY/[[bench]] 坑。代價 binary +11MB、`.xdb` 進 repo、換 region 重編（少更新、可接受） |
| login-attempt 寫法 | — | inner/outer split | **`login_inner` 回 Result、outer 對每終端路徑 exactly-one 寫一列**（成功 `Some(user.id)`／失敗 `None`、皆 best-effort、讀 ctx.client_ip） |
| INET / threading | — | with-ipnetwork／Extension | **sea-orm `with-ipnetwork`＋`ipnetwork 0.20`**（啟 feature 把 ipnetwork 拉進真 compile graph、§3.8 → MSRV ≤1.86 驗＋釘版`--locked`）；RequestContext threading＝axum `Extension`（handler 取）＋顯式 param 進 facade/`mutate_in_txn`（對齊 005 SC-004「顯式非隱式」、非 task_local） |

## 5. Design

### 5.1 架構洞察（守 DESIGN §1.5 分層）

`xdb`(L3 platform) → `audit_ctx`(L7 middleware) → facade(L6 append-only sink) → entity(L4)。三 sink 共用 `RequestContext`（audit_ctx 一次解析 client_ip／region、三 sink 共用同一結果）：access-log＝全域 middleware（before 建 ctx／after 取 http_status、**operator 在才寫**）、login-attempt＝login handler 內（inner/outer）、op-log 回填＝handler 把 ctx 餵 005 `mutate_in_txn`。

### 5.2 audit_ctx 中介層（P1–P4）

- **P1**：middleware **無條件**對每請求建 `RequestContext` 塞 extensions。**不可**做「驗證成功才建 ctx」的防衛 — 否則未認證 /login 讀 `Extension(ctx)` 會 panic、login-attempt 寫不成。
- **P2**：`main.rs` 改 `into_make_service_with_connect_info::<SocketAddr>()`（現為 plain serve、缺此則 `ConnectInfo` extraction 失敗、拿不到 peer）。
- **P3**：`audit_ctx` 為 **outermost** layer（包住 /login、在 handler 前跑）。
- **P4**：`client_ip INET NOT NULL` 無 fallback；login-attempt/access-log 寫採 **best-effort**（寫失敗吞掉、絕不擋業務請求）。
- **獨立寬鬆 bearer 抽取**：audit_ctx 自行驗 bearer 取 operator_id（成功 Some／任何失敗 None、永不 reject）；與 006 `enforce_mw` 的**嚴格**驗證語意不同 → **兩者各自獨立驗、006 enforce_mw 一行不動**。
- access-log 寫入：`operator_id.is_some()` 才產生 `AccessLogEntry` 並 write（best-effort）。

### 5.3 真實 client IP 解析（`resolve_client_ip` 手刻純函式）

```rust
// trusted: TRUSTED_PROXY_CIDRS env 注入（內網段 + CF 的 IP 段 + 其它前置 proxy）
fn resolve_client_ip(peer: IpAddr, xff: Option<&str>, trusted: &[IpNetwork]) -> IpAddr {
    // ① 直連 peer 不在可信集合 → 不信任何 forwarded header（擋 bypass-nginx 直連偽造、dev 場景）
    if !is_trusted(peer, trusted) { return peer; }
    // ② XFF 由右往左走，跳過 trusted 內的 hop，第一個不可信的 = 真實 client
    if let Some(xff) = xff {
        for tok in xff.split(',').rev() {
            if let Ok(ip) = tok.trim().parse::<IpAddr>() {
                if !is_trusted(ip, trusted) { return ip; }
            }
        }
    }
    peer // 全是可信 hop／無 XFF → 退回 peer（fail-safe）
}
```

- `is_trusted` 用 `ipnetwork::contains`（ipnetwork 本就因 INET 欄入圖、零新 dep）；std `IpAddr::from_str` 解析每段。
- **欄位分工**：`client_ip INET` = 解析後真實 client IP；`x_forwarded_for TEXT` = 原始 XFF 鏈字串備查。兩表（access-log／login-attempt）皆如此。
- **config**：`TRUSTED_PROXY_CIDRS`（逗號分隔 CIDR）；**fail-safe 預設**＝未設→空集合→peer 不可信→用 peer（dev 正好）。
- **CF 支援 = CF IP 段放進 `trusted`**（config）→ 演算法自動跳過 cf_edge、落在真實 client。零 CF-specific code。
- **安全鐵律**：絕不盲信 forwarded header；trusted 集合必須顯式設定、預設 fail-safe。否則攻擊者偽造 XFF 規避 lockout／嫁禍 IP／污染審計。
- region：私有/內網 IP（解析結果落私網段）→ xdb 回 `"内网IP"` 非 NULL（DESIGN §5.9）；trace_id：honor `X-Request-Id`／無則 mint。

### 5.4 結構與檔案（全新寫 ⚠️g）

| 檔 | 動 | 職責 |
|---|---|---|
| `rust-api/xdb/`（新 crate） | vendored ⚠️v | ip2region binding（searcher＋`include_bytes!` 的 `.xdb`＋buffer-load API；benches 可留但不入 prod bin） |
| `entity/src/sys_access_log.rs`＋`sys_login_attempt.rs` | 新 | Model（`client_ip: IpNetwork`、10/9 欄鏡像 m001、`with-ipnetwork`） |
| `server/src/audit_ctx.rs` | 新 | `RequestContext`＋全域 middleware（無條件 P1／ConnectInfo peer P2／`resolve_client_ip`／xdb region／獨立寬鬆 bearer operator／trace honor-mint）；access-log operator-gate 寫 best-effort |
| `server/src/audit_ctx.rs`（或 `client_ip.rs`） | 新 | `resolve_client_ip` 純函式（rightmost-untrusted＋peer-gate＋fail-safe、純測） |
| `server/src/model/facade/sys_access_log.rs`＋`sys_login_attempt.rs` | 新 | append-only `write`＋`*_active_model`（IpAddr→IpNetwork seam、純測） |
| `server/src/model/audit.rs` | 改（005） | `AuditOperator.ip` 真 INET 化（`Option<String>`→`Option<IpAddr>`）、op-log active_model 同法寫真值（解 §3.8 42804 defer） |
| `server/src/handler/auth.rs` | 改（006） | `login` inner/outer split＋login-attempt 寫（成功/失敗 exactly-one、讀 ctx.client_ip） |
| `server/src/main.rs` | 改 | `into_make_service_with_connect_info::<SocketAddr>()`＋`audit_ctx` layer 包 router（outermost P3） |
| `server/src/state.rs`（或 config） | 改 | `TRUSTED_PROXY_CIDRS` env 解析為 `Vec<IpNetwork>`（fail-safe 空集合） |
| `rust-api/Cargo.toml`＋`server/Cargo.toml`＋`entity/Cargo.toml` | 改 | sea-orm `with-ipnetwork`、`ipnetwork 0.20`、`xdb` path dep |
| `deploy/Dockerfile.rust-api.txt` | 改 | xdb COPY（manifest＋src＋`.xdb`）、`--bin server` 跳 [[bench]] |
| `deploy/<front-nginx conf>` | 驗/改 | 確保轉發 `X-Forwarded-For` |

### 5.5 簽名（形狀草案、actual 形交 plan 期 grep 校 §8 三 grep）

- `audit_ctx::audit_mw(State, ConnectInfo<SocketAddr>, Request, Next) -> Response`（無條件建 ctx→塞 extensions→`next.run`→取 status→`operator_id.is_some()` 才寫 access-log best-effort）。
- `resolve_client_ip(peer: IpAddr, xff: Option<&str>, trusted: &[IpNetwork]) -> IpAddr`（純函式、§5.3）。
- `RequestContext{ client_ip:IpAddr, x_forwarded_for:Option<String>, region:Option<String>, trace_id:String, operator_id:Option<i64> }`。
- facade `sys_access_log::write(db, &AccessLogEntry) -> Result<(),DbErr>`＋`access_log_active_model(&AccessLogEntry)->ActiveModel`（純 seam）；login_attempt 對稱。
- `xdb::search(ip:IpAddr) -> Option<String>`（region；私有 IP→「内网IP」）。

### 5.6 INET / 42804 解法（codebase 首個真 INET）

entity `client_ip: ipnetwork::IpNetwork`；facade active_model：`IpNetwork::from(ip:IpAddr)`（host /32·/128）→ sea-orm `with-ipnetwork` 原生 binding。**連帶 005**：`AuditOperator.ip` 改帶 `IpAddr`、op-log `audit_active_model` 的 operator_ip 同法寫真值 → 解 §3.8 defer（005 的 `Some(ip)=>42804` 前向分支至此可寫實）。

### 5.7 資料流

```
請求 → [audit_ctx middleware (outermost P3)]
        ├─ ConnectInfo peer + headers
        ├─ resolve_client_ip(peer, XFF, TRUSTED_PROXY_CIDRS) → client_ip（真實）
        ├─ raw XFF 字串 → ctx.x_forwarded_for（備查）
        ├─ xdb.search(client_ip) → region（私有→内网IP）
        ├─ 獨立寬鬆 bearer → operator_id: Option（永不 reject）
        ├─ trace_id: X-Request-Id honor / mint
        └─ insert RequestContext 進 extensions（無條件 P1）
     → handler（login 讀 ctx 寫 login-attempt inner/outer；其餘 handler 把 ctx 餵 005 mutate_in_txn 回填 op-log operator/trace）
     → [audit_ctx after] 取 http_status；operator_id.is_some() 才寫 access-log（best-effort P4）
```

## 6. 驗證（純測 + live + **mandatory prod build**；交 /speckit-specify 形式化）

- **純測**（test-first、零 DB）：
  - `resolve_client_ip`：rightmost-untrusted 命中／多 hop 跳 trusted（含 CF 段命中）／IPv4·IPv6／畸形 XFF token 略過／**直連 peer 不可信→回 peer 不信 header（防偽造）**／全 trusted→fail-safe peer／空 XFF。
  - `*_active_model`：`IpAddr→IpNetwork`（/32·/128、V4/V6）。
  - `trace_id` honor-vs-mint。
- **live smoke**（#[ignore]、真 PG、`--test-threads=1` §3.8〔見 memory `live-ignore-tests-need-serial`〕）：真 INET 寫入無 42804／私有 IP region=「内网IP」非 NULL／op-log operator/trace 回填（含 operator_ip 真值）／login-attempt 成功+失敗各一列〔失敗列亦帶 client_ip〕／access-log **operator-gate**（已認證請求寫一列、未認證請求不產生列）。
- **prod image build（mandatory — xdb 為新 crate、CLAUDE.md §3）**：xdb COPY（含 `.xdb`）無缺、`--bin server` 跳 [[bench]]、embed binary 自足。
- **無 CDP**：純後端 audit、無信封/前端消費面（異於 006）。

### SC 候選

access-log operator-gate（已認證寫、未認證不寫）／login-attempt 成功+失敗各一列／真實 client IP 解析正確（trusted-proxy、防偽造）／raw XFF 入庫備查／真 INET 無 42804／region 私有→内网IP 非 NULL／op-log operator/trace+operator_ip 回填／prod build xdb embed 綠／純測 resolver·active_model·trace_id。

## 7. Out of scope / Deferred / Backlog

- 審計查詢讀端 + UI（⚠️b、波 2）。
- **login lockout 本體（⚠️w）**：本刀備真實 client IP 後 per-ip lockout 現可行；per-ip／per-user（兩索引都備）／both＝⚠️w 未來定。
- `CF-Connecting-IP` 特判（本刀 CF 走 trusted CIDR 即夠）。
- access-log retention/清理（波 4 obs／⚠️n log retention）。
- 全流量（含未認證）日誌 → observability（波 4 obs／tracing→loki），非 `sys_access_log`。

## 8. Phase 0 research 待辦（交 /speckit-plan research.md；CLAUDE.md §3 三 grep ＋ §3.8 MSRV）

- **R1** rev2 015 actual 簽名逐項 grep（`audit_ctx` 無條件建 ctx／operator-gate／login inner-outer／兩 facade／`xdb::search`/active_model 真實形；⚠️g 讀允許拷貝禁止）。
- **R2** m001 兩表欄序/型逐欄對齊（entity Model 鏡像 dump 欄序；client_ip INET、operator_id NOT NULL vs NULL、x_forwarded_for TEXT）。
- **R3 ⚠️ ipnetwork 0.20 MSRV ≤1.86 驗**（啟 `with-ipnetwork` 把 ipnetwork 拉進 graph＝§3.8 地雷；`cargo update -p ipnetwork --precise <0.20.x>` + `cargo build --locked`；超標即釘回）。連帶驗 sea-orm `with-ipnetwork` 啟用後是否再拉其他 feature-gated crate 入圖。
- **R4** xdb embed 形（vendored crate 的 buffer-load API、`include_bytes!` 路徑、prod Dockerfile COPY `.xdb` + `--bin server` 跳 [[bench]]；§3.4 builder `--locked`；mandatory prod build）。
- **R5** connect_info + `audit_ctx` layer 與 enforce_mw（波1）的 middleware stack ordering（audit_ctx 全域**最外** P3、enforce_mw per-route 內；兩者**獨立驗 bearer**、不共享 Claims；access-log operator-gate ≠ enforce_mw 嚴格驗證、互不衝突）。
- **R6** 005 `AuditOperator.ip` `Option<String>`→`Option<IpAddr>` 改動面（op-log active_model 真 INET、不破 005 既有純測/live smoke）。
- **R7** front-nginx conf 是否已轉發 `X-Forwarded-For`（`$proxy_add_x_forwarded_for`）；`TRUSTED_PROXY_CIDRS` env 注入點（dev/prod compose）與 fail-safe 預設；§5.9 推進的 Constitution Check 對齊。

---

**brainstorm 定稿 2026-06-15（v2 重做）；拍板見 §4（access-log conform §3.3/§10.4／client_ip app-side XFF 解析〔推進 §5.9〕／手刻 resolver／audit_ctx P1–P4／xdb embed／login-attempt inner-outer／with-ipnetwork）＋既有權威 DESIGN §5.2·§5.9·§1.5·§3.1·§3.3·§10.4·§8.2 ＋⚠️v xdb vendored ＋⚠️g 全新寫 ＋⚠️w lockout 下游。下一步：手動 `/speckit-specify`（input＝本檔；`before_specify` pre-hook 建 `007-audit-overlay` feature branch；CLAUDE.md §3 — 不排進 brainstorm 流程觸發）。**
