# Implementation Plan: XFF → real_ip 鑑識

**Branch**: `013-xff-real-ip-forensics` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/013-xff-real-ip-forensics/spec.md`

## Summary

把 rust-api 現況「單值 XFF 解析」（`server/src/audit_ctx.rs::resolve_client_ip`）重寫為**兩層信任模型**（peer-gate / CDN 位置錨〔不硬 gate〕 / my-public+binding 走訪）＋ **IIS 正規化** ＋ **CF-Connecting-IP 交叉驗證 overlay** ＋ **Cloudflare Tunnel 支援**，回傳 `(real_ip, Confidence)`；把四欄鑑識（`peer_ip` / `real_ip` / `x_forwarded_for` / `ip_confidence`）存入三張既有審計表（`m006` 可逆 delta migration），並在 012 審計中心**全顯示**（順序 `ip_confidence → peer_ip → real_ip → x_forwarded_for`）＋ **全可篩**（三模糊 `real_ip`/`peer_ip`/`x_forwarded_for` + 一下拉 `ip_confidence`）。演算法、12 解析案例、逐層接地改動詳見 [research.md](./research.md)（ground 自 `docs/superpowers/000-rust-api-xff-real-ip-research.md`）。

## Technical Context

**Language/Version**: Rust（rust-api、workspace MSRV 1.86）＋ TypeScript / Vue 3（base-web）

**Primary Dependencies**: axum / sea-orm（feature `with-ipnetwork`）/ casbin / `xdb`（既有）＋ **`toml`（新 workspace dep、parse-only、§I.5 非 rev2 拷貝）**；base-web naive-ui（既有）

**Storage**: PostgreSQL — `sys_access_log` / `sys_login_attempt` / `sys_operation_log`（既有 append-only 審計日誌表；`m006` ALTER 加欄 + 改名）

**Testing**: `cargo test`（純函式 + in-crate `#[ignore]` live、**容器內** `docker exec`、`--test-threads=1`）/ CDP browser smoke（9229）/ curl / psql

**Target Platform**: Linux 容器（docker compose dev/prod）

**Project Type**: web（rust-api backend + base-web frontend + deploy/nginx）

**Performance Goals**: 解析為**輕量 per-request 中介層**（字串切分 + CIDR 比對；現況已 per-request 執行、無顯著額外開銷）；無特定延遲目標（非高頻熱路徑瓶頸）

**Constraints**: 容器內 build/test（host 無 rust toolchain）；**rust 全程 serial**（共用 target、即使標 [P] 也不平行 cargo）；base-web commit `--no-verify`；★ **絕不 `push`/`merge` until `finishing-a-development-branch`**

**Scale/Scope**: per-request 審計中介層；3 審計表 ALTER；**10 實作單元**（research §8.2 / 本檔 Project Structure）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* 對照 constitution v1.1.1 §IV 9 項：

| # | 檢查項 | 判定 | 說明 |
|---|---|---|---|
| 1 | §I.1 base-web 為權威（rust-api 補齊 endpoint） | ✅ PASS | 不新增 endpoint；擴充 012 既有三查詢端（`getOperationLog`/`getAccessLog`/`getLoginAttempt`）回傳鑑識欄，base-web 全消費 |
| 2 | 動 base-web inline？屬哪個 ★ 軌道？ | ✅ PASS | 改 base-web = (a) `rev3-system-manage.d.ts`〔rev3-owned typings/api、ADAPT〕 (b) `views/manage/audit/**`〔MODAL-WIRING ★ (e)：擴充 012 建的 rev3 管理頁，含 `page.manage.audit.*` i18n〕；須循 §III fork-delta `rev3-inline` 紀律 |
| 3 | menu 顯示走 Casbin enforce？ | ✅ PASS（N/A） | 不新增 menu；審計頁可見性沿 012 m005 menu policy（R_SUPER）；不動 menu 政策 |
| 4 | wire 對齊 §I.3 typings 權威序與不變式？ | ✅ PASS | honest wire：新欄 `string\|null`〔IP 去 mask 字串〕、`ip_confidence` literal union〔對齊 rust serde 7 字串〕、nullable 顯 null 不 skip；envelope/PageRes/13 碼矩陣不動；無 id 型問題 |
| 5 | 從 rev2 source 拷貝 code？防回歸？ | ✅ PASS | rust-api in-tree 重寫；`xdb` 既有（§I.5 例外、不動）；`toml`＝外部 crate 非 rev2 拷貝；不帶回任何已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | ✅ PASS | 不觸 13 凍結拍板；本案＝DECISIONS §2 遞延 D11，非 §II 項 |
| 7 | 觸及 §III ★ 軌道？授權邊界內？ | ✅ PASS | MODAL-WIRING ★ (e)〔擴充 audit 管理頁〕在授權邊界內；每改一處 plan/spec 記 file:line + upstream 衝突風險（見 research §逐層改動） |
| 8 | 新建業務表？含 §I.6 六審計欄？append-only 例外？ | ✅ PASS（**附破例說明**） | **不新建業務表**；ALTER 既有 append-only 日誌表（archetype B）：加 **domain 鑑識欄** `peer_ip`/`ip_confidence` + 改名 `client_ip→real_ip`，**未加** `updated_*`/`deleted_*`（archetype B 欄規則維持）。**「schema 一次定稿/無 retrofit」理想之刻意偏離 → 見 Complexity Tracking** |
| 9 | 觸及 §I.7 行為島？invariants 保持？ | ✅ PASS（N/A） | 不觸 token rotation／policy governance／single-session；解析在 audit overlay（007）、無 policy 寫、無 enforcer 動 |

**Gate 結論：通過**（9/9，item 8 附 Complexity Tracking 破例說明）。

## Project Structure

### Documentation (this feature)

```text
specs/013-xff-real-ip-forensics/
├── plan.md              # 本檔
├── research.md          # Phase 0：演算法/決策/逐層接地改動（ground 自 000-research）
├── data-model.md        # Phase 1：四欄 schema/entity/m006 DDL/TrustModel/Confidence
├── quickstart.md        # Phase 1：端到端驗證指南
├── contracts/
│   └── verification-commands.md   # Phase 1：C-V 驗收契約（純測/live/migration/CDP/curl/psql/prod-build）
└── tasks.md             # Phase 2（/speckit-tasks 產，非本步）
```

### Source Code (repository root) — 10 實作單元

```text
rust-api/                                    # backend（worktree+submodule）
├── server/src/
│   ├── audit_ctx.rs                         # L1 解析核心：normalize_xff_tokens / resolve→(IpAddr,Confidence) / Confidence enum / apply_cf_overlay；L6 RequestContext+IpForensics
│   ├── config.rs                            # L2 TrustModel TOML 載入（+toml dep）+ env fallback
│   ├── state.rs / main.rs                   # L3 AppState.trust_model:Arc<TrustModel>；ConnectInfo 不動
│   ├── model/audit.rs                       # L6 AuditOperator（維持 Copy）/ AuditEvent 帶 xff·confidence
│   ├── model/facade/sys_{access_log,login_attempt,operation_log}.rs  # L6 寫端映 4 欄；L7 list+ip_host_like 改名/加欄
│   ├── handler/system_manage.rs             # L7 三查詢端 wire DTO 改名+加欄；handler/auth.rs login sink
│   └── handler/...                          # L6 to_audit_operator 16 呼叫點（seam 吸收、零改）
├── entity/src/sys_{access_log,login_attempt,operation_log}.rs   # L4 entity Model 與 m006 同步
├── migration/src/m006_audit_ip_forensics.rs + lib.rs            # L5 m006 delta（rename+add、可逆）
base-web/src/                                # frontend
├── typings/api/rev3-system-manage.d.ts      # L8 3 Item+SearchParams 改名+加欄（honest wire）
├── views/manage/audit/{index.vue,modules/*} # L8 四欄顯示（欄序）+ 三模糊+一下拉 filter + confidence NTag
├── typings/app.d.ts + locales/langs/{zh-cn,en-us}.ts   # L8 Schema(先擴)+雙 locale（page.manage.audit.*）
deploy/nginx/{nginx.conf,conf.d/_locations.inc}          # L9 geo 閘 X-CF-Verified + 轉發 CF-Connecting-IP
docker-compose.{dev,prod}.yml                            # L10 TRUST_MODEL_FILE env + bind-mount
```

**Structure Decision**: 既有 web 結構（rust-api backend / base-web frontend / deploy）；本案為**對既有 007 audit overlay + 012 審計中心的縱切擴充**，無新專案/新目錄層；10 實作單元相依見 research §8、由 /speckit-tasks → 階段 2 `executing-plans` 編執行單元。

## Complexity Tracking

> 唯一需登記的破例：item 8 對既有審計日誌表的 ALTER vs「schema 一次定稿／無 retrofit」理想。

| 偏離 | 為何需要 | 為何不採更簡單替代 |
|---|---|---|
| 對既有 append-only 審計日誌表（`m001` 建）於 `m006` ALTER（加 `peer_ip`/`ip_confidence` domain 欄 + 改名 `client_ip→real_ip`），非「同刀或緊鄰兩刀 schema 一次定稿」 | 此為 **DECISIONS §2 的 D11 刻意排程**：012（讀端、讀現有 schema）先行交付波 2，鑑識欄寫端＋擷取基建（含 Cloudflare）刻意排為後續刀（013）——是**有意設計的 forensic 演進**，非 rev2 式意外 retrofit 債 | 替代「012 當刀就同步加四欄寫端」會把波 2 殿後刀（012）範圍灌大、且當時 XFF→real_ip 解析設計尚未定（需本案的兩層+CF+Tunnel 研究）；替代「建表 m001 即帶四欄」需 m001 時就有完整 forensic 設計（不存在）。**§I.6 archetype B 欄規則仍守**（未加 `updated_*`/`deleted_*`、日誌仍 append-only 不可竄改）；`m006` 嚴格可逆。**判定：constitution gate 不硬性禁止 ALTER 既有 log 表加 domain 欄（§I.6「無 retrofit」針對審計 archetype 欄，本案未 retrofit archetype 欄）；「schema 一次定稿」為設計理想、此處以 D11 排程拍板刻意換取，登記於此。** |

> 若 user 認為此破例需走 §V.2 Amendment（而非 Complexity Tracking 登記），可在進 /speckit-tasks 前提出。
