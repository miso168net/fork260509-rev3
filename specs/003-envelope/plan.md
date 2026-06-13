# Implementation Plan: envelope（統一回應信封＋13 碼矩陣＋集中錯誤映射）

**Branch**: `003-envelope` | **Date**: 2026-06-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-envelope/spec.md`＋brainstorm `docs/superpowers/003-envelope.md`（四項拍板＋⚠️e/⚠️f 凍結承接）

## Summary

把後端統一回應信封一次建成型別骨架：`Res<T>{data,code,msg}`（序列化逐欄對齊 base-web `Service.Response<T>`）＋`PageRes<T>` 分頁殼＋`BizCode` 13 碼矩陣（碼值／預設訊息／HTTP status 三方法、單一真相）＋`AppError` 集中錯誤映射（rev3 改良——`BizCode::http_status()` 解 ⚠️e 逆紋、`Internal→200` 無 500、handler 用 `Result<Res<T>,AppError>`＋`?`）。⚠️f 由「`AppError` 對 8 可發出碼有建構子、4 保留碼無建構子」型別系統結構保證。落點＝server crate 內 `envelope.rs`＋`error.rs`（非新 crate）；test-first TDD（序列化 golden＋13 碼 table-driven＋結構斷言）。各碼發出點與 ⚠️r id 守衛 defer 後續刀。

## Technical Context

**Language/Version**: Rust 1.86.0（`rust-toolchain.toml` channel、001 落值）

**Primary Dependencies**: axum 0.7（既有；本刀啟用 `features=["json"]`——`Json` 回應需此 feature）＋**workspace 新增** `serde`(derive)＋`serde_json`＋`thiserror`（`AppError` Display 供 log）；既有 tokio／tracing 不動。

**Storage**: N/A（純型別／序列化、無 DB／redis）

**Testing**: `cargo test`——**test-first TDD**（envelope 全是可獨立測純函式／序列化：序列化 golden 逐 byte＋13 碼 table-driven 矩陣＋⚠️e/⚠️f 結構斷言；inline `#[cfg(test)]` 於 envelope.rs／error.rs，rev2 同形）。**與 002「無純函式測試、靠實機」相反**——envelope 是純函式刀、單元測試為主驗收。

**Target Platform**: 001 交付 server crate（dev/prod stack）；本刀為 server 內模組、不改 stack 拓撲

**Project Type**: backend infra 模組（server crate 內 module、**非新 workspace crate**）

**Performance Goals**: N/A（純序列化；⚠️a 效能數字屬波 1）

**Constraints**: wire 序列化形凍結（欄序 data→code→msg／code 字串／無 success／data:null 不 skip／PageRes camelCase u64 無 pages）不可改；⚠️e（5000→200）／⚠️f（13 碼整組＋4 保留碼不發）／constitution §I.3 不可違反；非新 crate（FR-011）；各碼發出點＋⚠️r id 2^53 守衛 deferred

**Scale/Scope**: `envelope.rs`＋`error.rs` 2 新檔＋`main.rs` 加 `mod` ×2；型別 `Res<T>`／`PageRes<T>`／`BizCode`(13 變體×3 方法)／`AppError`(struct＋8 建構子＋集中 IntoResponse)；deps ×3（serde/serde_json/thiserror）＋axum json feature；contract test suite（golden＋matrix＋結構斷言）

## Constitution Check

*constitution-rev3 v1.0.0 §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威／缺 endpoint？ | **PASS（未觸）**——無業務 endpoint；envelope 是所有未來 endpoint 的回應地基；base-web `Service.Response<T>`（app.d.ts:901-907）為對齊目標（FR-003、R2 grep 驗證） |
| 2 | 動 base-web inline？ | **PASS（未觸）**——全在 rust-api server crate；base-web 唯讀 grep（typings 驗證） |
| 3 | menu 走 Casbin enforce？ | **PASS（N/A）**——envelope 無 menu |
| 4 | wire 對齊 §I.3 不變式？ | **PASS（正面命中）**——envelope{data,code,msg} 無 success／code 字串「0000」not number／business 200／13 碼整組凍結／4 保留碼不發＝FR-001~007 直接實作 §I.3 鎖定不變式；⚠️r 逐欄位 id 型 defer（data:T generic、本刀無具體 DTO 可守、不違反）；mock 僅補充 fixture（B1 以 mock 驗證非 oracle） |
| 5 | 拷 rev2 source？ | **PASS（全新寫合規）**——envelope **不在 §I.5 拷貝例外清單**（唯 sea-orm-adapter/xdb）、屬受控參照重寫（讀允許拷貝禁止）；防回歸條款查核：AppError 採 rev3 改良集中映射（rev2 瘦身取向未照拷）✓、⚠️e `5000→200`（rev2 test-only 500 未帶回）✓ |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——⚠️e（5000→HTTP 200）＋⚠️f（13 碼整組凍結含 4 保留碼）直接承接（FR-005/007）；⚠️k 命名沿用；無拍板需改變 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸）**——不動 `views/manage/**`、無 inline、無 MODAL-WIRING |
| 8 | 新建業務表（migration）？ | **PASS（未觸）**——純型別、無 migration、無 DB 表 |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸）**——envelope 是回應外殼；碼（3333/7777/8888）定義在矩陣、其**發出狀態機**（token rotation／policy governance／single-session）屬波 3 行為島刀 |

**Gate 結論：9/9 PASS，無需 amendment、無 violation 待 justify。**

## Project Structure

### Documentation (this feature)

```text
specs/003-envelope/
├── spec.md              # /speckit-specify ✅
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R6＋3-grep 紀律）
├── data-model.md        # Phase 1 ✅（型別形狀＋13 碼矩陣＋rev2/base-web 座標）
├── quickstart.md        # Phase 1（驗證指南）
├── contracts/
│   ├── envelope-wire-contract.md    # 凍結 wire 形（序列化 golden 期望＋13 碼權威表＋AppError 映射）
│   └── verification-commands.md     # C-V 驗收（cargo build/test＋prod build sanity＋grep 紀律）
├── checklists/requirements.md       # 16/16 ✅
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
└── rust-api/                          # worktree（兩段式 commit）
    ├── Cargo.toml                     # workspace deps ＋ serde/serde_json/thiserror
    └── server/
        ├── Cargo.toml                 # ＋serde/serde_json/thiserror；axum 改 features=["json"]
        └── src/
            ├── main.rs                # ＋mod envelope; mod error;（首次 mod 引入）；/health 不動
            ├── envelope.rs            # Res<T>＋PageRes<T>＋BizCode(13×3 方法)＋inline #[cfg(test)]
            └── error.rs               # AppError(struct＋8 建構子)＋集中 IntoResponse＋inline #[cfg(test)]
```

**Structure Decision**: envelope 落 server crate 內 2 模組（`envelope.rs`／`error.rs`），DESIGN §1.5 L1 側軌＋§7.3 as-built 錨明定；非新 crate（⚠️v sub-crate 消解精神），故 CLAUDE.md §3「新 workspace crate ⇒ acceptance 必含 prod build」紀律**不觸發**——但 verification-commands 仍含 prod build sanity（serde/json feature 加入不破壞 server crate multi-stage）。`main.rs` flat-in-main 沿用（待決① 沿用）、首次引入 `mod`。

## Phase 0：研究結論

見 [research.md](research.md)——R1 rev2 參考形實 grep（Res/BizCode 13 碼/AppError 逐字鎖、envelope.rs:93-142／error.rs:15-34）／R2 base-web wire 對齊 grep（Service.Response app.d.ts:901-907＋成功碼 .env:32）／R3 依賴增量（serde/serde_json/thiserror＋axum json feature；無 time 顧慮）／R4 AppError 集中映射設計（http_status() 解 ⚠️e、struct+8 建構子結構保證 ⚠️f）／R5 CLAUDE.md §3 三 grep 紀律適用性／R6 contract test 策略（test-first）。NEEDS CLARIFICATION＝0。

## Phase 1：設計產物

- [data-model.md](data-model.md)：`Res<T>`／`PageRes<T>`／`BizCode`（13 變體×3 方法）／`AppError`（struct＋8 建構子）型別形狀＋13 碼矩陣權威表＋rev2/base-web file:line 座標＋序列化契約＋排除聲明
- [contracts/envelope-wire-contract.md](contracts/envelope-wire-contract.md)：凍結 wire 形（序列化 golden 逐 byte 期望＋13 碼 table-driven 權威＋AppError→(status,信封) 映射）
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V 驗收——cargo build（deps/feature 後綠）／cargo test（golden＋matrix＋結構斷言全綠）／prod build sanity（server crate multi-stage 不退化）／C-V grep（部署層零 rev2／rust-api 內容錨定豁免）／/health 不退化
- [quickstart.md](quickstart.md)：從零驗證指南

## 實作注意（移交 tasks）

1. **順序**：依賴增量（serde/serde_json/thiserror＋axum json feature、cargo build 綠）→ test-first（先寫序列化 golden＋13 碼 matrix＋結構斷言＝red）→ envelope.rs（Res/PageRes/BizCode、green）→ error.rs（AppError 集中映射、green）→ main.rs 掛 mod → contract/prod 驗收 → 兩段式 commit（worktree 逐 task、outer pin 隨同 task bump——001 教訓）
2. **wire 凍結紀律**：序列化形（欄序／code 字串／無 success／data:null 不 skip／PageRes camelCase）不可改；13 碼 code/msg 字串逐字對齊 rev2（R1 grep 鎖）＋凍結矩陣
3. **⚠️e/⚠️f 結構落地**：`BizCode::http_status()` 表 Internal→200 無 500；`AppError` 8 建構子（無保留碼建構子）；contract test 斷言之
4. **push/merge 全凍結（§I.4/⚠️u）**：實作期 commit only；tasks.md 不得出現 push／merge 步驟
5. **失敗處置**：序列化 golden 紅＝對 rev2 grep/base-web typings 校形（不調 golden 遷就實作）；矩陣紅＝對凍結表校碼值/msg/status
