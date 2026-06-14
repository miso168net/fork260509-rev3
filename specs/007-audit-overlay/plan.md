# Implementation Plan: 007-audit-overlay（存取審計 + 登入嘗試 + 真實 client IP）

**Branch**: `007-audit-overlay` | **Date**: 2026-06-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/007-audit-overlay/spec.md`

## Summary

補滿 audit 軌：HTTP **access-log**（已認證才記、operator-gate conform DESIGN §3.3/§10.4）+ **login-attempt**（每登入終端路徑 exactly-one）兩 append-only sink + 全域 **`audit_ctx`** 中介層（無條件建 `RequestContext`、outermost）+ **`xdb`**（ip→region、file-path 載入）+ **app-side 真實 client IP 解析**（`resolve_client_ip` trusted-proxy、推進 DESIGN §5.9）；真實 INET 寫入（sea-orm `with-ipnetwork` + `ipnetwork 0.20`）一併**回填 005 op-log** 恆 None 的 operator/trace/operator_ip（解 §3.8 42804 defer）。**無 migration、無新 wire/業務端點**。技術路線全 grounded 於 [research.md](research.md)（R1–R7 + xdb 決策反轉）。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-api/rust-toolchain.toml` pin）

**Primary Dependencies**: axum 0.7、sea-orm 1.1.20（**+`with-ipnetwork` feature**）、**`ipnetwork 0.20`（新增）**、`xdb`（vendored ip2region、§I.5 例外、file-path 載入）、jsonwebtoken 9、argon2 0.5.3、casbin 2.20、tokio、tracing、once_cell（xdb）

**Storage**: PostgreSQL —— `sys_access_log` / `sys_login_attempt`（既有 m001、archetype B append-only）+ `sys_operation_log`（既有、`operator_ip` 型遷移 String→INET）；`client_ip`/`operator_ip` 為 INET

**Testing**: `cargo test`（test-first 純測、零 DB）+ `#[ignore]` live smoke（真 PG、**`--test-threads=1`** serial）+ **prod image build**（xdb 新 crate 強制、§3.4）；無 CDP（純後端）

**Target Platform**: Linux server（Docker 容器、front-nginx 反代後方、其前可能 CDN）

**Project Type**: web-service backend（rust-api；monorepo 含 base-web 前端、但本刀**僅後端**、不動 base-web）

**Performance Goals**: audit 寫入 **best-effort、非阻斷**（寫失敗不擋業務請求）；具體效能數字 deferred（⚠️a、波 1 驗收前）

**Constraints**: MSRV ≤1.86（pin 紀律、`--locked`）；append-only 審計（無 update/delete、§I.6 B）；best-effort（FR-012）；fail-safe IP 解析（FR-007）；**無 migration**（表在 m001）；**無新 wire/業務端點**；client_ip 解析推進 DESIGN §5.9（DESIGN 細節、非 constitution/DECISIONS §1 項）

**Scale/Scope**: 新 `xdb` crate（vendored）+ `audit_ctx`/`resolve_client_ip` 模組 + 2 facade + 2 entity Model + `sys_operation_log` 型遷移 + 005 `AuditOperator.ip`/main.rs/state.rs/Dockerfile/compose 編修；retention deferred（⚠️n、波 4 obs）

## Constitution Check

*GATE：Phase 0 前過、Phase 1 後復查。對照 constitution v1.0.0 §IV 九題。*

| # | 檢查（§IV） | 結論 |
|---|---|---|
| 1 | §I.1 base-web 為權威：rust-api 缺 base-web 用到的端點？ | **PASS** —— 本刀**無新 wire/業務端點**（audit 為透明中介層 + 內部表）；base-web 端點 006 已備、不增不減 |
| 2 | 動 base-web inline？ | **PASS（N/A）** —— **零 base-web 改動** |
| 3 | menu 顯示走 Casbin enforce？demo menu 進 seed？ | **PASS（N/A）** —— 不涉 menu |
| 4 | wire 對齊 §I.3 typings 不變式？ | **PASS** —— audit 為內部表、**不入 wire response**；envelope/碼表/id 型不受影響 |
| 5 | 從 rev2 拷貝 code？屬 §I.5 例外？ | **PASS** —— audit_ctx/facade/resolver **全新寫**（受控參照 rev2 ⚠️g）；**`xdb` ＝ §I.5 明文例外**（整檔原樣拷貝、**不改**、file-path） |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS** —— 一致；#6（xdb 自 rev2 拷貝）正落實（file-path、不改 crate） |
| 7 | 觸及 §III ★ 軌道？ | **PASS** —— 無 base-web inline→無 MODAL-WIRING；RUSTAPI-SOURCE-ISOLATION 遵循（rust-api 全新寫） |
| 8 | 新建業務表（create migration）？六審計欄？ | **PASS** —— **無 migration**；三 log 表已在 m001、archetype **B append-only**（只 created_at + domain 欄、無 soft-delete/update、§I.6 B 例外正確） |
| 9 | 觸及 §I.7 行為島？ | **PASS（N/A）** —— 不涉 token rotation/policy governance/single-session |

**Gate：全 PASS、零違規** → 無 Complexity Tracking。

> **DESIGN §5.9 推進留痕**（非 constitution gate）：client_ip 由「直連 peer」推進為「XFF trusted-proxy 解析真實 IP」。§5.9 屬 DESIGN 細節、**不在 constitution §II 13 拍板、亦非 DECISIONS §1 項** → 無需 amendment；記於 research.md R1/R4 + brainstorm，**下次 DESIGN 重鑄摺合**（constitution V.1 權威鏈：constitution > DECISIONS > DESIGN；本推進不動前兩者）。
> **xdb 決策反轉留痕**：brainstorm §4.4「embed」→ plan「file-path」（R4 ground 實際 code、user 拍 2026-06-15）。

## Project Structure

### Documentation (this feature)

```text
specs/007-audit-overlay/
├── plan.md              # 本檔
├── research.md          # Phase 0（R1–R7 + xdb 反轉）
├── data-model.md        # Phase 1（entity Model + event/context + 型遷移）
├── quickstart.md        # Phase 1（驗證導引）
├── contracts/
│   └── verification-commands.md   # Phase 1（C-V-1~9、無 HTTP wire contract）
├── checklists/
│   └── requirements.md  # spec 品質 checklist（16/16）
└── tasks.md             # Phase 2（/speckit-tasks 產、本步不建）
```

### Source Code (repository root)

```text
rust-api/
├── xdb/                              # 新 crate（vendored ip2region、§I.5 例外、整檔原樣拷貝）
│   ├── Cargo.toml                    #   含 [[bench]] target
│   ├── src/{lib,searcher,ip_value}.rs#   file-path 載入 + OnceCell cache；search_by_ip(ip)->Result<String,_>
│   └── resources/ip2region.xdb       #   ~10.5MB 資料檔
├── entity/src/
│   ├── sys_access_log.rs             # 新 Model（10 欄鏡像 m001、client_ip: IpNetwork、with-ipnetwork）
│   ├── sys_login_attempt.rs          # 新 Model（9 欄）
│   └── sys_operation_log.rs          # 改：operator_ip String→IpNetwork（型遷移）
├── server/src/
│   ├── audit_ctx.rs                  # 新：RequestContext + audit_mw（outermost P3、無條件 P1、operator-gate、best_effort_audit）
│   │                                 #     + resolve_client_ip 純函式（或拆 client_ip.rs）
│   ├── model/facade/
│   │   ├── sys_access_log.rs         # 新：write + access_log_active_model（IpAddr→IpNetwork seam、純測）
│   │   ├── sys_login_attempt.rs      # 新：對稱
│   │   └── sys_operation_log.rs      # 改：啟用 Some(ip) 分支寫真 INET（解 42804）
│   ├── model/audit.rs                # 改（005）：AuditOperator.ip String→IpAddr
│   ├── handler/auth.rs               # 改（006）：login inner/outer split + 6 record_login_attempt 點
│   ├── state.rs                      # 改：+ TRUSTED_PROXY_CIDRS env→Vec<IpNetwork>（fail-safe 空）
│   └── main.rs                       # 改：into_make_service_with_connect_info::<SocketAddr>() + audit_ctx outermost layer + xdb::searcher_init
├── server/Cargo.toml + entity/Cargo.toml + Cargo.toml(workspace)
│                                     # 改：sea-orm +with-ipnetwork、+ipnetwork 0.20、+xdb path dep、workspace members +xdb
deploy/
├── Dockerfile.rust-api.txt           # 改：補 xdb 全套 COPY（Cargo.toml/src/benches/resources）；--locked
docker-compose.dev.yml + docker-compose.prod.yml
                                      # 改：rust-api service + TRUSTED_PROXY_CIDRS env（+ XDB_FILEPATH）
# nginx：零改（已轉發 X-Forwarded-For，R7）
```

**Structure Decision**：沿用 rust-api 既有分層（entity / server〔auth・handler・model/facade・middleware〕、§I.5 in-tree）。新增唯一 workspace crate ＝ `xdb`（vendored 例外）。audit 軌守 DESIGN §1.5 分層：`xdb`(L3) → `audit_ctx`(L7) → facade(L6) → entity(L4)。

## Phase 1 後 Constitution Check 復查

設計產物（data-model/contracts/quickstart）未引入任何 base-web 改動、新 wire、新業務表、行為島變動或 rev2 code 拷貝（xdb 例外照舊）。**九題仍全 PASS、零違規**。§5.9 推進與 xdb 反轉均已留痕、非 gate 失敗。
