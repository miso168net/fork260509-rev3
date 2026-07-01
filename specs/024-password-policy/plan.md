# Implementation Plan: 密碼複雜度政策（管理員可設定、系統驗證就緒）

**Branch**: `024-password-policy` | **Date**: 2026-07-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/024-password-policy/spec.md`

## Summary

複用 008 `system_settings` KV 表新增 **7 個密碼複雜度政策列**（`m009` seed-only migration）＋handler `validate_value_type` 補 **`number` 型驗證分支**（正整數 `1..=1024`、違→既有 `biz.systemSettings.invalidValue`）＋新純模組 `auth/password_policy.rs`（`PasswordPolicy` ＋ `from_settings`〔吃**非-entity** 鍵值對〕＋ `validate_password_complexity`〔回**全部**違規〕＋ `PolicyViolation` enum）＋前端 `system-settings/index.vue` 加 `number` render 分支（`NInputNumber` ＋ `:update-value-on-input="false"`）。admin 即可設定政策、後端持有**已完整單元測試**的驗證原語；**實際 enforce（改密碼套政策）＝刀2 `025-user-center`**。**零新端點／零新 wire／零新 i18n key／零 schema／零新 workspace crate／零 casbin seed**。

## Technical Context

**Language/Version**: Rust 1.86（rust-api）+ TypeScript / Vue 3（base-web）

**Primary Dependencies**: axum + SeaORM（後端）；naive-ui `NInputNumber` + Vue 3（前端）

**Storage**: PostgreSQL（既有 `system_settings` 表、**不新增表/欄**；`m009` seed 7 KV 列）；無前端持久化

**Testing**: cargo test（rust、容器內 `docker exec`、live serial `--test-threads=1`）+ pnpm typecheck；acceptance＝curl + psql + CDP（`contracts/verification-commands.md`）

**Target Platform**: Linux 容器（docker compose dev/prod；migrate gate `migration up` 自動套 m009）

**Project Type**: web（base-web 前端 + rust-api 後端，worktree+submodule 傘狀 monorepo）

**Performance Goals**: 政策讀取罕見（僅刀2 改密碼時）→ **load-on-demand、不建 runtime store**（研究 R7 / brainstorm D2）；本刀**無 enforce 路徑**（原語 dormant）

**Constraints**: 零新端點／零新 wire／零新 i18n key／零 schema／**0 新 workspace crate**；`password_policy.rs` **零 `entity::`**（守 `entity_access_lint`、`from_settings` 吃非-entity 鍵值對，R5）

**Scale/Scope**: 7 政策 KV 列；後端＝1 migration + 1 純模組 + 1 handler 分支＋擴測；前端＝1 render 分支 + 1 handler

## Constitution Check

*GATE: Phase 0 前須評估、Phase 1 後複查。* 對照 constitution **v1.2.0** §IV 九問：

| # | 檢查 | 裁定 |
|---|---|---|
| 1 | §I.1 base-web 權威（rust-api 缺 endpoint？）| ✅ PASS — 零新端點；復用既有 super-only get/update system settings（008），前端 number 控件消費既有 `fetchUpdateSystemSetting` |
| 2 | §IV.2 動 base-web inline？MODAL-WIRING (a)~(f)？| ✅ **gate CLEARED（user 拍板 A、2026-07-01）** — 改 `system-settings/index.vue` 加 `number` render 分支＝**落既有 (e)**（008 建該頁之授權用途）。判定「(e) 涵蓋補完該頁 by-`value_type` render 控件」（單頁、純加、復用既有存檔 wrapper、不動共用元件、零新 key/component）。**constitution 不 bump**；DECISIONS §1 釐清列於収刀回填。實質不同於 023 跨 7 頁新排序能力〔(f) amendment〕 |
| 3 | §I.2 menu Casbin enforce？| ✅ N/A — 無 menu 顯示/enforce 改動 |
| 4 | §I.3 wire 對齊 typings？| ✅ PASS — 零新 wire；復用 `SystemSetting` 型（`settingValue` wire 恆 string、number 僅 render 時 `Number()`/送出 `String()`）；number 非法復用既有 `biz.systemSettings.invalidValue`→`2222`；13 碼矩陣不擴張 |
| 5 | §I.5 從 rev2 拷貝 code？| ✅ PASS — `m009`／`password_policy.rs`／number 分支皆全新寫、無拷貝、無帶回已推翻行為 |
| 6 | §II 拍板 #1~#13 抵觸？| ✅ PASS — 無反轉（#12 brainstorm 落 `docs/superpowers/024-password-policy.md`）|
| 7 | §III ★ 軌道？授權邊界內？| ✅ PASS — rust 全落 §III.1 RUSTAPI-SOURCE-ISOLATION 預設軌道；base-web number 分支＝MODAL-WIRING (e)（#2 CLEARED）；**零新 i18n key → BASE-WEB-I18N-WIRING 未觸發**；**零新 wrapper/typings → ADAPT/WRAPPER N/A** |
| 8 | §I.6 新建業務表含六審計欄？| ✅ N/A — `m009` 為 **seed-only**（INSERT 列進既有 archetype A `system_settings`、非新表非加欄）；seed 列 `created_by=null` ＝§I.6 明文授權（migration / system seed）|
| 9 | §I.7 行為島 invariants 保持？| ✅ PASS — 密碼政策非 3 行為島（token/policy/single-session）之一；R7/D2 不加 watcher、不建 AppState 快取；password key 的 `settings:invalidate` publish＝無訂閱者 no-op、`single_session_default` 零回歸 |

**Initial Gate 結論**：**9/9 通過**（#2 MODAL-WIRING gate 已 user 拍板 A「落既有 (e)、記釐清」CLEARED、constitution 不 bump）。可進 Phase 0/1。

**Post-Design 複查（Phase 1 後）**：設計未引入額外違反——`password_policy.rs` 純邏輯 `from_settings` 吃**非-entity** 鍵值對（避 `entity_access_lint` build-fail，R5）；新檔皆 additive（`m009`／`password_policy.rs`）；前端僅擴 `v-else-if number` render 分支、不動共用元件、零新 key。**Gate 9/9 不變、可進 `/speckit-tasks`。**

## Project Structure

### Documentation (this feature)

```text
specs/024-password-policy/
├── plan.md              # 本檔
├── research.md          # Phase 0：R1~R11 決策
├── data-model.md        # 7 KV 列 + PasswordPolicy + PolicyViolation + 驗證規則
├── quickstart.md        # 驗證流程
├── contracts/
│   ├── settings-policy-contract.md    # 7 KV 契約 + number value_type 驗證 + password_policy 純函式契約（零新 HTTP 端點）
│   └── verification-commands.md        # C-V：純測 + curl/psql + CDP + 三守恆
└── tasks.md             # /speckit-tasks 產（本步不產）
```

### Source Code（worktree）

```text
rust-api/                                        ← worktree（submodule pin）
├── server/src/
│   ├── auth/password_policy.rs                  # 新：PasswordPolicy + from_settings（吃非-entity KV 對）+ validate_password_complexity（回全部違規）+ PolicyViolation enum（純邏輯、零 entity::）+ #[cfg(test)] 純測
│   ├── auth/mod.rs                              # +`pub mod password_policy;`（字母序、password 後 session 前）
│   └── handler/system_settings.rs               # validate_value_type +`Some(("number", _))` 分支（正整數 1..=1024）+ 擴 mod value_type_tests
└── migration/src/
    ├── m009_seed_password_policy.rs             # 新：seed 7 密碼政策 KV（up INSERT ON CONFLICT DO NOTHING / down DELETE 7 keys、可逆）
    └── lib.rs                                   # +`mod m009_seed_password_policy;` + vec `Box::new(m009_seed_password_policy::Migration)`

base-web/                                        ← worktree（submodule pin）
└── src/views/manage/system-settings/index.vue  # +`v-else-if item.valueType==='number'` → NInputNumber（:min=1 :max=1024 :update-value-on-input=false）+ handleNumberUpdate（鏡像 handleToggle）  ★MODAL-WIRING (e)
```

**Structure Decision**：沿用既有 worktree+submodule 結構（CLAUDE.md §1）。後端集中：1 支 seed-only migration（m009）＋1 純模組（`password_policy.rs`，本刀 dormant、供刀2）＋handler 一個 match arm；前端單頁單分支。所有政策 KV 走既有 008 端點/wrapper/typings，零 wire 擴張。

## Complexity Tracking

> 無須 justified 的 Constitution 違反（gate 9/9 通過）。以下登備查：

| 項目 | 說明 |
|---|---|
| **MODAL-WIRING (e)（非 amendment）** | `system-settings/index.vue` 加 number 分支＝落既有 (e)（user 拍板 A、2026-07-01）；非 (f)/(g) 新用途、constitution 不 bump。決策痕跡在 Constitution Check #2；DECISIONS §1 釐清列於収刀回填 |
| **m009 seed-only migration（非違反）** | §I.6 審計欄 archetype 規則不適用（純資料 seed、非新表非加欄）；up→down→up 可逆 |
| **`entity_access_lint` 約束（設計已守）** | `password_policy.rs::from_settings` 吃非-entity 鍵值對（R5）；消費者從 `find_all()` Vec<Model> 讀欄位建對、不寫 `entity::` 字面 |
