# Implementation Plan: envelope（統一回應信封＋msg-i18n key 規約）

**Branch**: `003-envelope` | **Date**: 2026-06-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-envelope/spec.md`＋brainstorm `docs/superpowers/003-envelope.md`（named aspect「error envelope ＋ msg-i18n key 規約」一體設計、scope A；4 sub-拍板＋⚠️e/⚠️f/⚠️y；Clarifications 2026-06-16＝fallback 顯示原始 key）

## Summary

兩端一刀 ship 統一回應信封契約＋msg-i18n key 規約（scope A 完整縱切）：

- **rust-api（greenfield、純加既有 `server` crate 模組）**：`envelope.rs`（`Res<T>`＋`PageRes<T>`＋`IntoResponse`，預設 HTTP 200／`4040`→404／`5003`→403）＋`error.rs`（`AppError` 僅 9 可發碼變體、各烤 `(code,key,http)`、reserved 4 碼型別層不存在；`AppError::Biz(key)` 承載 per-entity key）＋`main.rs` 接 `.fallback`（小 `handler_404`）。msg **只產去前綴語意 key**（⚠️y、語言無關）。`From<DbErr>` **延後**（R7、無 caller、不加 sea-orm）。
- **base-web（⚠️aa `BASE-WEB-I18N-WIRING ★` 軌道、fork-delta `rev3-inline`）**：`app.d.ts` `Schema` 加 `backend` 型＋`translateBackendMsg` helper（自 `@/locales`）＋`locales/langs/{zh-cn,en-us}.ts` 加 `backend` 命名空間（13 固定碼 seed key 雙語）＋`service/request/index.ts` 兩翻譯點（`:71` modal、`:109` onError extraction）＋dedup companions（`:64`/`:51`）。
- **驗收**：rust in-crate `#[cfg(test)]` 契約測（碼/key/http 對齊矩陣、msg 是 key 非人話、emitted ⊆ 9）＋curl `4040` wire＋base-web component（helper 命中+fallback）＋prod target build sanity。端到端 i18n 顯示分階梯（波 0 Auth login `1000`／波 1 system_settings per-entity `2222`）。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-toolchain pin、001 落值）＋ TypeScript（base-web：Vue 3 SFC、vue-i18n 11.4.2）

**Primary Dependencies**: rust-api `server` crate **新增直接 dep**：`serde`（derive feature）＋`serde_json`（`Cargo.lock` 已 pin `1.0.228`/`1.0.150`、無版本 churn；先入 `[workspace.dependencies]` 再 `{ workspace = true }`，對齊既有慣例）；既有 `axum 0.7.9`（`Json` 免 feature flag）＋`tokio`＋`tracing`。**不加 sea-orm**（`From<DbErr>` 延後、R7）。base-web：既有 `vue-i18n 11.4.2`＋`@sa/axios`（createFlatRequest）——**零新 npm dep**。

**Storage**: N/A（序列化/錯誤層、無持久化、無 DB 觸及）

**Testing**: rust **in-crate `#[cfg(test)] mod`**（`server` bin-only、無 lib.rs、`server/tests/` 無法 `use server::`；純型別/serde shape、無 DB → 一般 `cargo test`、**無 `#[ignore]`**）＋base-web 單元/component（`translateBackendMsg` 命中+fallback）＋curl `4040` wire＋prod target image build sanity。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。

**Target Platform**: 001 交付 dev stack（rust-api dev 容器 `cargo watch`、base-web vite；活體驗證在容器內）

**Project Type**: web（rust-api backend ＋ base-web frontend）——envelope/error 序列化層＋i18n 接線基建

**Performance Goals**: N/A（序列化層；msg-key 多一次 `$t` 查表；⚠️a perf SLA 屬 endpoint-level、非本層）

**Constraints**: 凍結 wire 契約忠實實作不重決（§I.3／DESIGN §7.3）；msg=去前綴語意 key（⚠️y）；**本刀無 biz endpoint**（`server` 僅 `main.rs`/health＋`.fallback`→`4040`）；base-web inline 嚴限 ⚠️aa `BASE-WEB-I18N-WIRING ★` 三範圍、走 fork-delta `rev3-inline`；`4040`/`5003` msg 今日不顯示＝既認限制、本刀不修（R3）；push/merge 凍結至 finishing（§I.4／⚠️u、tasks 不得排 push）

**Scale/Scope**: rust＝`envelope.rs`＋`error.rs`＋`main.rs` 接線＋in-crate tests；base-web＝`app.d.ts` Schema `backend`＋`translateBackendMsg`＋`langs/{zh-cn,en-us}.ts` `backend` 命名空間（13 固定 key×2 語）＋`service/request/index.ts` 2 翻譯點+2 dedup companion；deps＝`server` +serde/serde_json

## Constitution Check

*constitution-rev3 **v1.1.0**（含本刀觸發的 ⚠️aa `BASE-WEB-I18N-WIRING ★` amendment）§IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 為權威？ | **PASS**——本刀無新 endpoint，但實作 base-web wire 所依賴的**信封地基**（envelope/13 碼/PageRes）＋對齊其 i18n 權威（§I.1：base-web 為 wire+i18n 權威）；不縮減設計範圍 |
| 2 | 動 base-web inline？ | **YES→PASS**——i18n 接線改 `service/request/{index,shared}.ts`＋`locales/langs/*`＋`app.d.ts` Schema；屬**新授權 ⚠️aa `BASE-WEB-I18N-WIRING ★` 軌道**三範圍 (i)/(ii)/(iii) 之內（constitution §III.2、v1.1.0）；走 fork-delta `rev3-inline`（修改型保留原行註解＋token、新增型標記圈界）。逐處 file:line 紀錄見 [contracts/i18n-key-convention.md](contracts/i18n-key-convention.md) |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（未觸）**——本刀無 menu、無 route |
| 4 | wire 對齊 §I.3 typings 權威序？ | **PASS（正面落地）**——忠實實作凍結信封/13 碼/PageRes；`msg`=穩定 key（⚠️y）；mock 僅補充 fixture、不當 shape oracle；wire 3 端對齊（rust `Res`/`AppError` ↔ `app.d.ts:901-908`＋`backend` Schema ↔ `service/request` 消費點） |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——rust-api 全新寫（RUSTAPI-SOURCE-ISOLATION）；rev2 008＝受控參照重寫非照拷；防回歸查核：msg=key（非人話）、無 `Internal→HTTP 500`（⚠️e）、無 id-string lie（⚠️r）——已推翻行為皆未帶回 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——受 ⚠️e/⚠️f/⚠️y 治理、無拍板需改；⚠️aa amendment 為**新增** ★ 軌道（§V.3 MINOR）、未動 #1~#13 |
| 7 | 觸 §III ★ 軌道？ | **YES→PASS**——base-web 側觸新授權 BASE-WEB-I18N-WIRING ★（邊界內、見 Q2）；rust-api 側走 RUSTAPI-SOURCE-ISOLATION |
| 8 | 新建業務表？ | **PASS（未觸）**——本刀無 migration、無建表 |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸）**——序列化/錯誤層；token rotation／policy governance／single-session 狀態機未動 |

**Gate 結論：9/9 PASS（Q2/Q7 由 ⚠️aa v1.1.0 amendment 授權滿足）；無 violation 待 justify、Complexity Tracking 不適用。**

## Project Structure

### Documentation (this feature)

```text
specs/003-envelope/
├── spec.md              # /speckit-specify ✅（含 Clarifications 2026-06-16）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R8＋三-grep 紀律；NEEDS CLARIFICATION=0）
├── data-model.md        # Phase 1 ✅（envelope/error 型模型＋base-web Schema delta＋無持久實體聲明）
├── quickstart.md        # Phase 1（從零驗證指南）
├── contracts/
│   ├── verification-commands.md   # C-V 全集（in-crate cargo test／curl 4040／base-web component／prod build／CDP 階梯）
│   ├── envelope-contract.md       # 凍結信封＋13 碼矩陣 (code,變體,key,http,顯示路徑)＋reserved guard
│   └── i18n-key-convention.md     # 規約（4 根+文法）＋13 固定碼 seed key 雙語＋wire 去前綴/前端 backend. 前綴＋翻譯點 file:line＋fork-delta 紀錄
├── checklists/requirements.md     # 16/16 ✅
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
├── rust-api/                          # worktree（兩段式 commit）
│   ├── Cargo.toml                     # [workspace.dependencies] +serde(derive)/+serde_json（lock 已 pin、無 churn）
│   └── server/
│       ├── Cargo.toml                 # +serde/+serde_json（{workspace=true}）；不加 sea-orm（R7）
│       └── src/
│           ├── main.rs                # +mod envelope; +mod error;＋.fallback(handler_404)（小 fn 回 AppError::NotFound）
│           ├── envelope.rs            # Res<T>/PageRes<T>＋IntoResponse（200 預設、4040→404/5003→403）；in-crate #[cfg(test)]
│           └── error.rs               # AppError（9 可發碼變體+(code,key,http)）＋IntoResponse；in-crate #[cfg(test)]
└── base-web/                          # worktree（⚠️aa BASE-WEB-I18N-WIRING ★、fork-delta rev3-inline）
    └── src/
        ├── typings/app.d.ts           # (iii) Schema 加 backend 型（GetI18nKey 納 backend.*）
        ├── locales/
        │   ├── index.ts               # (iii) 匯出 translateBackendMsg helper
        │   └── langs/{zh-cn,en-us}.ts # (ii) 加 backend 命名空間（13 固定 key 雙語）
        └── service/request/
            ├── index.ts               # (i) :71 modal content 翻譯／:109 onError extraction 翻譯／:64,:51 dedup companion
            └── shared.ts              # (i) showErrorMsg 不改（翻譯在邊界、非此）
```

**Structure Decision**：web（backend＋frontend）。rust-api＝純加 `server` crate 模組（無新 workspace crate）；base-web＝⚠️aa 軌道三範圍 inline 接線。tests：rust in-crate `#[cfg(test)]`（bin-only 約束）＋base-web component。

## Phase 0：研究結論

見 [research.md](research.md)——R1 凍結契約／R2 請求層翻譯插入點（file:line）／**R3 傳輸錯誤 4040/5003 不顯示限制（修正 FR-008）**／R4 i18n Schema 手寫→三處編輯＋cast／R5 fallback=原生 raw key（驗證 Clarifications B）／R6 scaffold greenfield+serde 須加／**R7 From<DbErr> 延後**／R8 key 規約。三-grep 紀律：facade grep N/A、wire 3 端對齊已驗、CDP 階梯。**NEEDS CLARIFICATION=0**。

## Phase 1：設計產物

- [data-model.md](data-model.md)：`Res<T>`/`PageRes<T>`/`AppError` 型模型＋base-web `backend` Schema delta（三處編輯）＋helper 簽名＋**無持久實體聲明**（序列化層）
- [contracts/envelope-contract.md](contracts/envelope-contract.md)：凍結信封形＋13 碼矩陣 (code,變體,wire key,http,顯示路徑)＋reserved 4 碼型別層 guard＋HTTP 例外二
- [contracts/i18n-key-convention.md](contracts/i18n-key-convention.md)：規約（4 根 common/auth/biz/system＋文法）＋13 固定碼 seed key 雙語表＋wire 去前綴/前端 `backend.` 前綴 (c)＋翻譯點 file:line＋⚠️aa 軌道 fork-delta 紀錄＋typed-key cast
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V——in-crate `cargo test`（碼/key/http 對齊、msg-是-key、emitted⊆9）／curl `4040` wire／base-web component（helper 命中+fallback）／**prod target build sanity**（首批實質 server 碼）／i18n 顯示端到端**階梯**（波 0 Auth login `1000`／波 1 per-entity `2222`、登 follow-up）
- [quickstart.md](quickstart.md)：從零驗證指南

## 實作注意（移交 tasks）

1. **順序**：rust-api 先（`Cargo.toml` +serde/serde_json → `envelope.rs` → `error.rs` → `main.rs` mod+fallback → in-crate 契約測 `cargo build/test` 容器內綠）→ base-web（`app.d.ts` Schema backend → `langs/{zh-cn,en-us}` backend 命名空間 → `translateBackendMsg` helper → `index.ts` 2 翻譯點+2 dedup companion）→ C-V（cargo test／curl 4040／base-web component／prod build）→ 兩段式 commit（worktree 逐單元、outer pin 隨同 bump——001 教訓：pin 不延後）
2. **rust 細節**：`AppError` 僅 9 變體（reserved 4 碼**無變體**＝型別層保證）；`Res<T>` serde 欄序 data→code→msg、`data:null` 不省略；`IntoResponse` 預設 200、match 出 `4040`→404/`5003`→403；`.fallback` 需 `async fn handler_404()->AppError`（不能傳 enum variant）；**不**建 `From<DbErr>`、**不**加 sea-orm（R7）
3. **base-web 細節（⚠️aa 軌道、fork-delta `rev3-inline`）**：Schema 加 `backend` 後兩 langs **必須**補齊（`: App.I18n.Schema` annotation 編譯強制）；helper `translateBackendMsg(msg)`＝`$t(('backend.'+msg) as App.I18n.I18nKey)`、自 `@/locales` 匯出；翻譯點 `index.ts:71`（modal content）/`:109`（onError extraction）/`:64`,`:51`（dedup companion 保 stack 鍵=翻譯後文字）；**不**碰 `showErrorMsg`（R2）；每處補原行註解+`rev3-inline` token
4. **4040/5003 限制（R3、不修）**：今日 axios native error 路徑不讀 envelope msg——本刀接線不拓寬 `onError` gate；contracts 明示、follow-up 登（enforce 刀再議）
5. **push/merge 全凍結（§I.4／⚠️u）**：實作期 commit only；tasks.md 不得出現 push／merge 步驟
6. **測試紀律**：rust 容器內 `docker compose … exec rust-api cargo test`（host 無 toolchain；改 `.rs` 先 force-touch 防 stale-mtime 假綠、見 CLAUDE.md §8.2.1）；base-web commit `--no-verify`；i18n 顯示端到端 CDP 不在本刀（無 biz endpoint）、列階梯+follow-up
