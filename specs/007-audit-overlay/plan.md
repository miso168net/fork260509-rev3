# Implementation Plan: 007-audit-overlay（audit overlay＝access-log＋login-attempt＋真實 client IP＋region）

**Branch**: `007-audit-overlay` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/007-audit-overlay.md`（借前代 v2 設計、對齊當前 `b9de316` lineage；4 refinement＋§5.9 推進已拍定）

## Summary

波 0 第七刀（末）＝audit 軌第二刀（op-log 為第一刀＝005）。立起全域 `audit_ctx` 中介層（每請求建 `RequestContext`：operator/真實 client_ip/raw XFF/region/trace_id）＋兩 append-only sink（`sys_access_log` 已認證請求／`sys_login_attempt` 每登入終端結果）＋`xdb` sub-crate（client_ip→region、§I.5 拷貝例外）＋`resolve_client_ip` 手刻純函式（XFF trusted-proxy、**推進凍結 DESIGN §5.9**：直連→forwarded 解析）＋既有 `mutate_in_txn` 的 operator/trace/operator_ip threading seam。**當前 lineage 已落地 INET 地基（004/005）→ 本刀零 migration／零 entity／零型遷移**；新增 1 workspace crate（xdb）⇒ acceptance 必含 prod image build。完整 lockout＝波3、audit 讀端/UI＝波2、retention＝波4。對應前代 015。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-toolchain.toml` 嚴格 pin）

**Primary Dependencies**: server **新增**＝`xdb = { path = "../xdb" }`（vendored 拷貝、§I.5/⚠️v）；workspace 暴露 `once_cell`（xdb 依賴）。`ipnetwork` **走 `sea_orm::entity::prelude::IpNetwork` re-export**（transitive 0.20.0 已在 lock、零新顯式 dep；R1 refinement）；`uuid`（trace_id fallback）＋`tracing`／`tracing-subscriber`（xdb log）皆已在圖。**無 chrono 直接 dep**。

**Storage**: PostgreSQL（既有 dev stack、m001 schema）。**本刀無 migration、無建表、無 schema 變更**——`sys_access_log`(10)／`sys_login_attempt`(9、含 2 複合索引)／`sys_operation_log.operator_ip`(已 `Option<IpNetwork>`) 皆 002/004 建齊。

**Testing**: rust in-crate `#[cfg(test)]` 純函式測（`resolve_client_ip` trusted-proxy／facade `*_active_model` 的 `IpAddr→IpNetwork`／`extract_trace_id`）＋live `#[ignore]` smoke（INET no-42804＋region／login-attempt 成敗各列／access-log operator-gate／op-log threading）＋既有 `entity_access_lint`。**live 一律 `--test-threads=1` serial**（共用 audit 表、非 parallel-safe）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。**含 prod target image build**（新 crate、§3 紀律）。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內）。

**Project Type**: backend（rust-api workspace）——L3 `xdb` 拷貝 crate＋L7 `audit_ctx` 全域中介層＋L4 facade（2 sink write）＋L1 boot（state/config/main 接線）；跨 §1.5 多層。

**Performance Goals**: audit 寫**盡力而為**（best-effort、寫失敗不擋業務、FR-012）；不設新 p95（沿 ⚠️a 保守預設）。access-log 寫於回應後（同步、吞錯）；sync vs spawn 取最小（同步吞錯）、必要時後刀優化。

**Constraints**: RUSTAPI-SOURCE-ISOLATION（audit_ctx/facade/resolver 全新寫、§I.5；唯 `xdb` 拷貝例外〔⚠️v、整檔零改〕）；append-only 審計（§I.6 B、facade 只 write）；fail-safe IP 解析（FR-007）；**無 migration**（schema 凍）；**無新 wire/業務端點、零 base-web**（§I.1 未觸）；MSRV 1.86（已 pin、`--locked`）；§5.9 推進（DESIGN 細節、見 Constitution Check Q6）；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: 1 新 crate（xdb）＋`audit_ctx.rs`＋`resolve_client_ip`/`extract_trace_id` 純函式＋2 facade（access-log/login-attempt）＋login inner/outer split＋main(connect_info＋outermost layer＋xdb boot-guard)/state/config 接線＋Dockerfile xdb COPY＋compose env。**零 migration/entity/型遷移/base-web/i18n**。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威？rust-api 缺對應 endpoint？ | **PASS**——007 無新 wire/業務端點、base-web 零改；audit 為透明中介層＋內部表，base-web 無 audit 讀端（讀端＝波2 ⚠️b） |
| 2 | 動 base-web inline？ | **PASS（未觸）**——零 base-web 改動 |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（未觸）**——無 menu/route 端點 |
| 4 | wire 對齊 §I.3 typings？ | **PASS（N/A）**——無新 wire DTO；envelope/碼不變（audit 不改回應） |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——`xdb` 整檔拷貝為 **§I.5 明列例外**（constitution §I.5「`sea-orm-adapter`／`xdb` 自 rev2 整檔拷貝」、⚠️v）；`audit_ctx`/facade/`resolve_client_ip` 全新寫（受控參照、不拷貝）；防回歸：不帶回前代被推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——無拍板需改。**§5.9 推進說明**：client_ip 由「直連」推進為「XFF trusted-proxy 解析」，§5.9 屬 **DESIGN 細節**（grep 確認**不在** constitution §II 13 拍板、亦非 DECISIONS §1 項）→ 權威鏈 constitution＞DECISIONS＞DESIGN，本推進不動前兩者 → **無需 Amendment**；留痕於 spec Assumptions／research R8、下次 DESIGN 重鑄摺合 §5.9 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸 ★）**——rust-api 走 RUSTAPI-SOURCE-ISOLATION（§III.1 預設可動）；無 base-web inline（未觸 MODAL-WIRING/I18N ★） |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——零 migration、不建表；三 audit 表 m001 已建（append-only join-less、§I.6 archetype B；FR-014/SC-009） |
| 9 | 觸 §I.7 行為島（token rotation／policy／single-session）？ | **PASS（未觸）**——007 為 audit overlay、不動 token/session/policy invariant；§I.6 審計 archetype B（append-only、facade 唯一管道）全守 |

**Gate 結論：9/9 PASS；§5.9 推進＝DESIGN-detail 對齊（非 violation、非 Amendment）；Complexity Tracking 不適用。**

> **新 workspace crate ⇒ prod build 紀律**：007 加 `xdb`（新 workspace member）→ acceptance **必含 prod target image build**（C-V-8、CLAUDE.md §3）——dev bind-mount 會遮 prod multi-stage 的 xdb COPY（Manifest＋Source＋`benches`＋`resources/*.xdb`）＋`[[bench]]` 缺口；不得只靠 dev build。

## Project Structure

### Documentation (this feature)

```text
specs/007-audit-overlay/
├── spec.md              # /speckit-specify ✅（5 US／16 FR／9 SC／16-16 checklist）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R9 grep ground-truth；xdb API/panic・login 終端路徑・INET already・trusted-proxy・§5.9 推進）
├── data-model.md        # Phase 1 ✅（RequestContext／resolve_client_ip 契約／2 facade event／login inner-outer／op-log threading／xdb boot）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md   # C-V-0~9（build／3 純測／4 live／prod build／零回歸）
│   └── audit-overlay-contract.md  # 跨 feature 不變式
└── checklists/requirements.md     # 16/16 ✅
```

### Source Code (repository root)

```text
rust-api/
├── xdb/                                  # ★ 新 crate（§I.5 ⚠️v 整檔拷貝自 fork260509-rev2-anew-rust-api@rev2-admin-rust-api-rebase260531:xdb/）
│   ├── Cargo.toml                        #   [[bench]] name=search harness=false；deps once_cell/tracing/tracing-subscriber(ws)
│   ├── src/{lib,searcher,ip_value}.rs    #   search_by_ip<ToUIntIP>／searcher_init(Option<String>)／XDB_FILEPATH
│   ├── benches/search.rs
│   └── resources/{ip2region.xdb(~10.5MB git-tracked), ip.test.txt}
├── Cargo.toml                            # 改：workspace members +"xdb"；once_cell 升 workspace dep
└── server/
    ├── Cargo.toml                        # 改：+ xdb = { path = "../xdb" }（ipnetwork 走 sea-orm re-export、不顯式加）
    └── src/
        ├── audit_ctx.rs                  # ★ 新（L7 全域）：RequestContext＋audit_mw＋resolve_client_ip＋extract_trace_id＋best_effort_audit
        ├── main.rs                       # 改：into_make_service_with_connect_info::<SocketAddr>()＋audit_mw 最外層＋xdb boot-guard（mod audit_ctx; mod xdb dep）
        ├── state.rs                      # 改：AppState + trusted_proxy_cidrs:Vec<IpNetwork> + xdb_ready:bool
        ├── config.rs                     # 改：載 TRUSTED_PROXY_CIDRS（fail-safe 空）＋ XDB_FILEPATH
        ├── handler/auth.rs               # 改：login inner/outer split（login_inner→Result、outer 記 exactly-one）
        └── model/facade/
            ├── mod.rs                    # 改：+ pub mod sys_access_log; pub mod sys_login_attempt;
            ├── sys_access_log.rs         # ★ 新：AccessLogEvent＋access_log_active_model（IpAddr→IpNetwork seam）＋write
            └── sys_login_attempt.rs      # ★ 新：LoginAttemptEvent＋login_attempt_active_model＋write
deploy/Dockerfile.rust-api.txt           # 改：xdb COPY（Manifest+Source+benches+resources）、--bins 跳 [[bench]]、--locked
docker-compose.{dev,prod}.yml            # 改：rust-api env + TRUSTED_PROXY_CIDRS + XDB_FILEPATH
# ALREADY（不動）：entity/src/{sys_access_log,sys_login_attempt}.rs・sys_operation_log.rs(已 INET)・model/audit.rs(AuditOperator.ip 已 Option<IpNetwork>)・facade/sys_operation_log.rs(已無條件寫 operator_ip)・deploy/nginx(已轉發 XFF/X-Real-IP/X-Request-Id、僅驗)・enforce_mw(一行不動)
```

**Structure Decision**：backend（rust-api workspace）。L3 `xdb`（拷貝 crate）＋L7 `audit_ctx`（全域中介層）＋L4 `model/facade/{sys_access_log,sys_login_attempt}`（2 sink write、entity:: 合法）＋L5 `handler/auth.rs`（login split）＋L1 `main.rs`/`state.rs`/`config.rs`（boot 接線）。**無 entity/migration/base-web/i18n 改動**（地基 002/004/005 已 provisioned）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS、§5.9 推進為 DESIGN-detail 對齊非 violation）→ 不適用。

## 實作注意（移交 tasks）

1. **順序**：xdb crate 拷入（workspace member＋once_cell ws）→ `resolve_client_ip`/`extract_trace_id` 純函式（test-first）→ 2 facade（`*_active_model` 純測＋write）→ `audit_ctx`（RequestContext＋audit_mw）→ state/config（trusted_proxy_cidrs＋xdb_ready＋XDB_FILEPATH）→ main（connect_info＋outermost layer＋xdb boot-guard）→ handler login inner/outer split → op-log threading seam → 純測 → live smoke → Dockerfile/compose → prod build → 兩段式 commit（worktree→pin）。
2. **★ xdb PANIC gotcha（R1）**：`searcher_init`/`get_full_cache` 對缺檔 `.unwrap()`/`.expect()` panic（searcher.rs:127/135/137/144）。boot **必先 `Path::exists` 守門**再 `searcher_init`；存 `AppState.xdb_ready`；`search_by_ip` **僅在 xdb_ready 時呼叫**（否則 region=None 降級、FR-009）。
3. **login inner/outer（R2 refinement）**：current login 有多個 `?` 終端點（find_by_user_name DbErr／not-found／password-wrong／roles DbErr／2 sign／timestamp／begin/set_pointer/insert_token/commit）。**不**逐點散記；改 `login_inner(...) -> Result<Success, (Option<i64> operator, AppError)>`、outer **記 exactly-one**（Ok→success+Some(uid)／Err→fail+operator〔pre-identity None：not-found/lookup-DbErr/password-wrong；post-identity Some(uid)：roles/sign/timestamp/txn〕）再回 AppError。由建構保證 FR-004 exactly-one。
4. **INET 寫入（R3）**：`IpNetwork::from(IpAddr)`（V4→/32 V6→/128）在 facade `*_active_model` seam（純測）；sea-orm native inet binding、無 PG 42804。當前 lineage `with-ipnetwork` 已開、operator_ip 已 `Option<IpNetwork>`——**零型遷移**。
5. **resolve_client_ip（R4）**：`(peer, xff, trusted:&[IpNetwork])->IpAddr`：①peer ∉ trusted→peer（防偽造）②XFF 右→左跳 trusted、第一個不可信＝client ③fail-safe peer。`TRUSTED_PROXY_CIDRS` 解析 `Vec<IpNetwork>`（fail-safe 空）；CF 段入 trusted、零 CF code。ipnetwork 走 sea-orm re-export。
6. **audit_mw（R5）**：`(State, ConnectInfo<SocketAddr>, Request, Next)->Response`（無 Result）；前段無條件建 ctx 塞 extensions（否則 /login 讀 Extension panic）；後段取 http_status、**gate=operator_id.is_some()** 才寫 access_log（best-effort 吞 DbErr）；獨立寬鬆 bearer（`enforce::bearer(...).ok().map(|c|c.uid)`、永不 reject）；**enforce_mw 一行不動**。
7. **op-log threading（R7、誠實範圍）**：唯一 `mutate_in_txn` consumer `soft_delete` 為 test-only（無 live mutating handler）→ 本刀 = seam ready＋test-only live smoke 證 operator/operator_ip/trace 由恆 None→真值；production handler threading 留波1+。
8. **nginx（R6）**：`deploy/nginx/conf.d/_locations.inc` 已轉發 XFF/X-Real-IP/X-Request-Id（`/api/`→rust-api）→ **零改、僅驗**。
9. **§5.9 推進（R8）**：spec Assumptions＋research R8 已留痕；Constitution Check Q6 對齊（DESIGN-detail、非 Amendment）。
10. **lint 守恆**：`audit_ctx`/`handler`/`config`/`state` 零 path-root `entity::`；entity 存取全在 facade（`entity_access_lint` 續綠）。casbin/ipnetwork/xdb 型非 entity::。
11. **prod build／push 凍結**：新 crate → 必跑 prod image build（C-V-8、Dockerfile xdb COPY＋`--bins` 跳 `[[bench]]`）；實作期 commit only、tasks.md 不得出現 push/merge（§I.4）。
12. **rust serial／容器內 build/test／改 .rs 先 force-touch／live `--test-threads=1`／兩段式 commit（worktree→pin）**。
