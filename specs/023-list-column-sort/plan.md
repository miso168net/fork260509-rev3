# Implementation Plan: 列表欄位排序（多欄、伺服端、可保留）

**Branch**: `023-list-column-sort` | **Date**: 2026-06-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/023-list-column-sort/spec.md`

## Summary

讓 7 個分頁列表頁（user/role + 5 個審計/日誌/治理頁，menu 排除）支援**使用者點欄頭做 server-side 多欄排序**（點擊序＝優先序、naive-ui 原生 3-state 循環）、**一鍵清除**、**localStorage per-route 持久化**。後端每個 list 端點新增單一 `sort` query 字串（`field:dir,...`）→ 共用 `parse_sort_spec` + per-entity `match` 白名單（防注入、非法→2222）→ facade `list` 依序 `order_by` + Id tie-breaker（未指定時逐列等同現況）。匯出（3 審計頁）因共用 facade 查詢自動反映排序（FR-016）。前端新增 `useTableSort` composable（受控排序 + 自維護點擊序 + 持久化）。資料層唯一改動＝1 支 index-only migration（`m008` 補 `idx_login_attempt_created_at`，clarify Q1）。

## Technical Context

**Language/Version**: Rust 1.86（rust-api）+ TypeScript / Vue 3（base-web）

**Primary Dependencies**: axum + SeaORM 1.1.20（後端）；naive-ui 2.44.1 + Vue 3 + qs 6.15.1（前端）

**Storage**: PostgreSQL（既有表、**不新增表/欄**；+1 index `m008`）；localStorage（前端排序持久化）

**Testing**: cargo test（rust、容器內 serial）+ pnpm typecheck；acceptance＝curl + CDP + psql（`contracts/verification-commands.md`）

**Target Platform**: Linux 容器（docker compose dev/prod）

**Project Type**: web（base-web 前端 + rust-api 後端，worktree+submodule 傘狀 monorepo）

**Performance Goals**: 排序 **best-effort**（clarify Q1）；唯補 `login_attempt.created_at` 索引（高基數/預設排序欄缺口）；其餘可排序欄不保證大表延遲

**Constraints**: server-side 排序（整資料集、非單頁）；**0 新 workspace crate**；**1 支 index-only migration**；動 base-web inline 需 MODAL-WIRING ★ (f) 授權（見下）

**Scale/Scope**: 7 列表頁、~50 可排序欄（白名單 data-model §3）；前端 1 composable + 各 view 接線；後端 1 helper + 7 resolver + 7 facade 簽章

## Constitution Check

*GATE: Phase 0 前須評估、Phase 1 後複查。* 對照 constitution v1.1.2 §IV 九問：

| # | 檢查 | 裁定 |
|---|---|---|
| 1 | §I.1 base-web 權威：rust-api 是否未提供 base-web 用到的 endpoint？ | ✅ PASS — sort 為前後端**同刀新增**；每個 base-web 排序的列表，rust-api 對應端點都加 `sort` 參數、無缺口 |
| 2 | §IV.2 動 base-web inline？屬 MODAL-WIRING (a)~(f)？ | ✅ **已授權（⚠️af）**：動 `views/manage/**` inline 掛排序＝(a)~(e) 未涵蓋 → **user 親決 MODAL-WIRING ★ (f) Amendment**（constitution v1.2.0、commit `ef070468`）。gate CLEARED |
| 3 | §I.2 menu Casbin enforce？ | ✅ PASS / N/A — menu 為樹狀、**排除**；無 menu 顯示/enforce 改動 |
| 4 | §I.3 wire 對齊 typings 權威序與不變式？ | ✅ PASS — `sort` 為**新增** query 欄；envelope/`PageRes`/id 序列化不變；非法排序→**`2222`**（業務碼、HTTP 200 信封）、msg＝i18n key `biz.common.invalidSort`；13 碼矩陣不擴張 |
| 5 | §I.5 從 rev2 拷貝 code？ | ✅ PASS — rust 全新寫（parse/resolver/facade 改），無拷貝、無帶回已推翻行為 |
| 6 | §II 拍板 #1~#13 抵觸？ | ✅ PASS — 無拍板反轉（#12 brainstorm 位置已循；#3 MODAL-WIRING 為**擴用途 (f)**、非撤回）|
| 7 | §III ★ 軌道？授權邊界內？ | ⚠️ 同 #2（MODAL-WIRING ★ 需 (f) Amendment）；另 backend msg key `backend.common.invalidSort` 譯文走**既授權** BASE-WEB-I18N-WIRING ★ (ii)(iii)；新檔（composable/wrapper/typings）落 ADAPT/WRAPPER |
| 8 | §I.6 新建業務表（migration）含六審計欄？ | ✅ PASS / N/A — `m008` 為 **index-only**（非新表、非加欄、僅加索引）→ 審計欄 archetype 規則不適用 |
| 9 | §I.7 行為島（token/policy/single-session）invariants 保持？ | ✅ PASS — `login_attempt` 加索引純讀路徑加速、**不改 lockout 行為**；archive/log 唯讀被排序；無 invariant 觸動 |

**Initial Gate 結論**：8/9 PASS；**第 1 項（#2/#7 MODAL-WIRING）原為 gate、已 user 親決 Amendment (f)**（⚠️af、constitution v1.1.2→**v1.2.0**、commit `ef070468`）→ **gate CLEARED**。**9/9 通過、可進 /speckit-tasks**。

**Post-Design 複查（Phase 1 後）**：設計未引入額外違反 —— 新檔（`useTableSort`/`rev3-extra` typings/可選 `SortClearButton`）皆 additive、落 ADAPT/WRAPPER；shared `table-header-operation.vue` **元件本體不改**（僅用既有 `#suffix` slot）；migration 維持 index-only。Gate 狀態不變（仍待 (f) 親決）。

## Project Structure

### Documentation (this feature)

```text
specs/023-list-column-sort/
├── plan.md              # 本檔
├── research.md          # Phase 0：R1~R10 決策
├── data-model.md        # 實體 + 逐頁白名單 + m008
├── quickstart.md        # 驗證流程
├── contracts/
│   ├── sort-wire-contract.md
│   └── verification-commands.md
└── tasks.md             # /speckit-tasks 產（本步不產）
```

### Source Code（worktree）

```text
rust-api/                                   ← worktree（submodule pin）
├── server/src/handler/system_manage.rs     # +parse_sort_spec、+7 resolve_<entity>_sort、+7 query DTO `sort` 欄、+7 handler 接線、export 帶 sort
├── server/src/model/facade/
│   ├── sys_user.rs / sys_role.rs / sys_ip_rule.rs
│   └── sys_operation_log.rs / sys_access_log.rs / sys_login_attempt.rs / sys_casbin_policy_archive.rs   # 各 list* 簽章 +sort、order_by 依參數
└── migration/src/
    ├── m008_<name>.rs                       # idx_login_attempt_created_at（up/down）
    └── lib.rs                               # 註冊 m008

base-web/                                    ← worktree（submodule pin）
├── src/hooks/…/use-table-sort.ts            # 新：useTableSort composable（受控排序+點擊序+持久化）
├── src/views/manage/{user,role,ip-rule,audit/*,policy-archive}/index.vue(+modules/*-table.vue)  # column sorter props、@update:sorter、#suffix 清除鈕、useRoute、searchParams.sort  ★MODAL-WIRING (f)
├── src/components/.../sort-clear-button.vue # 可選新：清除鈕（避 7 頁重複；shared table-header-operation.vue 不改）
├── src/service/api/rev3-system-manage.ts    # sort 參數透傳（多半免改、params 整包送）  ★WRAPPER
├── src/typings/api/rev3-*.d.ts              # search params +sort?: string  ★ADAPT（新檔、不改 frozen system-manage.d.ts）
├── src/typings/app.d.ts                     # Schema.common.clearSort  ★(f)/I18N
└── src/locales/langs/{zh-cn,en-us}.ts       # common.clearSort（+ backend.common.invalidSort）  ★I18N-WIRING
```

**Structure Decision**：沿用既有 worktree+submodule 結構（§1）。後端集中改 `system_manage.rs`（helper+resolver+DTO+接線）+ 7 facade + 1 migration；前端以 `useTableSort` 收斂排序邏輯、各 view 最小接線。逐頁可排序欄＝data-model §3 白名單。

## Complexity Tracking

> 唯一須 justified 的 Constitution 違反：

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| **動 base-web `views/manage/**` inline（MODAL-WIRING (a)~(e) 未涵蓋）→ 需 ★ (f) Amendment** | 「點欄頭排序」本質即在列表 view 的 column 定義掛 `sorter` + 綁 `@update:sorter` + 工具列加清除鈕 —— 無法不動 view inline 而存在；feature 已 user 核可 | (1) 純前端/CSS 排序＝分頁表語意錯（spec D1）；(2) 另建平行排序頁＝荒謬、違 §I.1 對齊；(3) 全放新檔不碰 view＝技術不可能（column 定義在 view inline）。故須授權，且以 (f) **嚴格限「列表排序掛載」**、不擴張其他 inline |

**index-only migration（m008）**：非違反（§I.6 不適用）；登此處備查 —— 推翻 brainstorm「0 migration」屬 clarify Q1 user 拍板的刻意取捨（補唯一索引缺口），可逆（up/down）。

---

> **★ gate 已解除**：MODAL-WIRING ★ (f) Amendment 已 user 親決（⚠️af、constitution v1.2.0、commit `ef070468`、MILESTONES `c1fb99f3`）。**Constitution Check 9/9 通過、可進 `/speckit-tasks`**。
