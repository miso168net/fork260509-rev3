# Implementation Plan: Audit Center Enhancement

**Branch**: `017-audit-center-enhancement` | **Date**: 2026-06-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/017-audit-center-enhancement/spec.md`

## Summary

審計中心三增強（零 migration/crate/端點）：**C-1** access-log `http_status` 類別 quick-filter（2xx/4xx/5xx 範圍 filter、與既有單值並存）；**C-3** 三審計分頁 CSV 匯出（既有讀端點加 `export` query flag、CSV-in-envelope、當前篩選、cap 1 萬列、UTF-8 BOM）；**C-4** op-log payload 注入角色集 delta（create/update/soft_delete 三寫端 `roles_before`/`roles_after`、全生命週期、jsonb 零 migration）。技術途徑經 Phase 0 三鏈實碼驗證（[research.md](research.md)）：approach B 利用 casbin (path,method) policy 不變、export query flag 復用既有 R_SUPER policy。

## Technical Context

**Language/Version**: Rust 1.86（rust-api）＋ TypeScript / Vue 3（base-web）

**Primary Dependencies**: axum + sea-orm + casbin（rust，**無新 dep**——CSV 手寫 escaper）；naive-ui + vue（base-web，NSelect 已 import）

**Storage**: PostgreSQL（**無 schema 變更**——僅 query filter / jsonb payload 內欄 / 既有讀端點）

**Testing**: cargo test（純函式單元 + live `#[ignore]` `--test-threads=1`）＋ vue-tsc typecheck ＋ CDP browser smoke ＋ curl/psql（C-V-0~5、見 [contracts/verification-commands.md](contracts/verification-commands.md)）

**Target Platform**: Linux 容器（docker compose；base-web/rust-api worktree+submodule）

**Project Type**: web（rust-api 後端 + base-web 前端）

**Performance Goals**: admin 審計操作（無特定延遲目標）；CSV export cap 10000 列使 envelope payload 有界

**Constraints**: 零 migration / 零新 crate / 零新端點；wire 對齊 §I.3（envelope `{data,code,msg}`、code string、HTTP 200）；審計 R_SUPER-only

**Scale/Scope**: 既有 3 審計表（operation/access/login）；export 單次上限 1 萬列；3 子功能、~3 rust facade + 3 handler 分支 + base-web 3 表增強

## Constitution Check

*GATE: 對照 `.specify/memory/constitution.md` §IV 九項，Phase 0 前後各一次。*

| # | 檢查 | 結果 |
|---|---|---|
| 1 | §I.1 base-web 為權威；rust 提供對應 endpoint？ | **PASS**——本刀為 rust 補 base-web 審計頁所需（class filter/export 復用既有端點 + query 增量；C-4 純後端 op-log）。無 base-web 用到卻缺的 endpoint。 |
| 2 | 動 base-web inline？屬 MODAL-WIRING 哪用途？fork-delta 紀律？ | **PASS（註）**——觸及 `views/manage/audit/*`（class NSelect + 匯出鈕）。此頁為 **rev3 自建（012/013）、無 upstream counterpart**、零 rebase 風險→屬 rev3 authorship（延續 MODAL-WIRING (e) 既建頁之增強）；新增皆走 `rev3-inline` 標記紀律。**留 /speckit-analyze 複核**是否需嚴格 (f) Amendment（判定：rev3-owned 檔非 frozen-upstream inline、不需）。 |
| 3 | menu 顯示走 Casbin？demo menu 依 ⚠️p？ | **PASS（N/A）**——無新 menu；審計頁既有、已 Casbin-gated（R_SUPER）。 |
| 4 | wire 對齊 §I.3（envelope/id 型/13 碼/enum）？ | **PASS**——envelope 不變（export 為 `Res::ok(String)`、仍 `{data,code,msg}`）；無新 id 欄；無新 error code（class 無法識別→略過不發碼、export 旗標非碼）；3 端命名對齊無 type-lie（[wire-deltas.md](contracts/wire-deltas.md)）。 |
| 5 | 從 rev2 拷貝 code？防回歸？ | **PASS**——全新寫（RUSTAPI-SOURCE-ISOLATION）；CSV escaper/parse 純函式新寫、無拷貝。 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——無拍板需改。 |
| 7 | 觸及 ★ 軌道？授權邊界內？ | **PASS**——MODAL-WIRING（rev3 audit 頁增強、見 #2）；i18n 為 `page.manage.audit.*` UI key（非 backend.* 命名空間）→ **不涉 BASE-WEB-I18N-WIRING**（該軌道限 wire msg 翻譯）；WRAPPER（rev3-*.ts 新 export wrapper）+ ADAPT（typing 加欄）皆預設可動。 |
| 8 | 新建業務表（migration）？審計欄？ | **PASS**——**零 migration**（query/jsonb only）；不建表。 |
| 9 | 觸及 §I.7 行為島（token/policy/single-session）？invariants 保持？ | **PASS**——C-4 只 enrich op-log payload（審計），**不動 casbin_rule（policy governance §4.2 無涉）**、不動 token rotation/single-session；`current_session_id` 保留＝既有 audit_json 行為不變（§4.3 不涉）。 |

**Gate**：9/9 PASS（item 2/7 註記留 analyze 複核）。無違規→無 Complexity Tracking 條目。

## Project Structure

### Documentation (this feature)

```text
specs/017-audit-center-enhancement/
├── plan.md              # 本檔
├── research.md          # Phase 0：三鏈 grep ground-truth + decisions
├── data-model.md        # Phase 1：DTO/payload/filter 形狀（零 schema）
├── quickstart.md        # Phase 1：驗證 run 指南
├── contracts/
│   ├── verification-commands.md   # C-V-0~5 驗證契約
│   └── wire-deltas.md             # wire 契約增量
└── tasks.md             # Phase 2（/speckit-tasks 產、非本步）
```

### Source Code (repository root)

```text
rust-api/server/src/
├── model/facade/sys_access_log.rs        # C-1：AccessLogFilter +http_status_class、list +範圍 apply_if
├── model/facade/sys_user.rs              # C-4：create/update/soft_delete 三寫端 payload +roles
├── model/facade/sys_user_role.rs         # C-4：roles_of_user（既有、&txn 讀）
├── model/audit.rs                        # C-4：with_roles 純函式（新）
├── handler/system_manage.rs              # C-1 parse_http_status_class；C-3 三 handler export 分支 + CSV helper（CSV_EXPORT_CAP/csv_escape/records_to_csv/parse_export）
└── (main.rs/migration：不動)

base-web/src/
├── views/manage/audit/modules/
│   ├── access-log-table.vue              # C-1 class NSelect；C-3 匯出鈕
│   ├── operation-log-table.vue           # C-3 匯出鈕（roles 欄）
│   └── login-attempt-table.vue           # C-3 匯出鈕
├── service/api/rev3-system-manage.ts     # C-3：3 export wrapper（回 string）
├── utils/download.ts                     # C-3：downloadCsv（新）
├── typings/api/rev3-system-manage.d.ts   # C-1：AccessLogSearchParams +httpStatusClass
├── typings/app.d.ts                      # i18n Schema（先 Schema 後 locale）
└── locales/langs/{zh-cn,en-us}.ts        # audit UI label
```

**Structure Decision**: 沿 rev3 既有 facade-only（rust）+ rev3-wrapper（base-web）結構；無新目錄/crate。rust 改動集中 `sys_access_log.rs`/`sys_user.rs`/`audit.rs`/`system_manage.rs`；base-web 集中 `views/manage/audit/*` + 一 wrapper + 一 util + typings/locale。

## Complexity Tracking

> 無 Constitution 違規 → 本節空。
