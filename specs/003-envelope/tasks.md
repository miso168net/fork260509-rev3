# Tasks: envelope（統一回應信封＋13 碼矩陣＋集中錯誤映射）

**Input**: Design documents from `/specs/003-envelope/`

**Prerequisites**: plan.md ✅、spec.md ✅、research.md（R1~R6）✅、data-model.md ✅、contracts/（envelope-wire-contract＋verification-commands）✅、quickstart.md ✅

**Tests**: 本 feature **test-first TDD**（plan.md Testing 明示——envelope 全是可獨立測純函式／序列化：序列化 golden＋13 碼 table-driven＋AppError 映射＋⚠️e/⚠️f 結構斷言；inline `#[cfg(test)]` 於 envelope.rs／error.rs，rev2 同形）。**與 002「無純函式測試、靠實機」相反**——每 story 先寫測（red）再實作（green）。

**Organization**: 依 user story 分 phase。**build 依賴序＝US2→US1→US3**（BizCode〔US2〕是 Res::err〔US1〕與 AppError〔US3〕的型別前置；雖 US1 envelope 形狀為 P1/MVP 用戶價值，其 build 前置是 US2 的 BizCode）。**兩段式 commit 紀律（001/002 教訓）**：worktree task 完成即 worktree commit＋outer pin 隨同 bump（不延後收口）。**§I.4／⚠️u：全程不 push 不 merge**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（依賴＋scaffold——blocking 全部 US）

- [ ] T001 [P] 依賴增量：`rust-api/Cargo.toml` workspace deps 加 `serde = { version = "1", features = ["derive"] }`＋`serde_json = "1"`＋`thiserror = "2"`；`rust-api/server/Cargo.toml` 加這三個（`serde.workspace=true` 等）＋axum 改 `features = ["json"]`（0.7 `Json` 需 json feature、現宣告無 features）
- [ ] T002 容器 `cd rust-api && cargo build --bins`（host 無 cargo、rust:1.86 容器、001/002 形）＋lock 複驗（`grep -c 'name = "serde"'`／`serde_json`／`thiserror` 各 ≥1）＝C-V-1；commit lock＋pin bump
- [ ] T003 建 `rust-api/server/src/envelope.rs`＋`rust-api/server/src/error.rs`（空 module 起手）＋`rust-api/server/src/main.rs` 加 `mod envelope;`＋`mod error;`（首次 `mod` 引入、純加法；`/health` handler 不動）；容器編譯綠

**Checkpoint**: deps 入鎖、axum json feature 啟、2 空 module 掛載、`/health` 不動

## Phase 2: Foundational

**無獨立 foundational 項**——BizCode（US2 主體）即型別骨幹、由 Phase 3（US2）首建；Setup 已涵蓋全部前置。

## Phase 3: US2 — 13 碼矩陣型別化單一真相（P2；型別前置、US1/US3 依賴）

**Goal**: `BizCode` 13 碼＋3 方法成單一真相，contract test 鎖死凍結矩陣
**Independent Test**: 13 碼 table-driven 對齊矩陣＋`Internal.http_status()==200`＋全 enum 無 500（⚠️e）

- [ ] T004 [US2] test-first：`rust-api/server/src/envelope.rs` `#[cfg(test)]` 寫 BizCode 13 碼 table-driven 矩陣測（red；對 contracts/envelope-wire-contract.md §2——`[(variant, code(), default_msg(), http_status())]` 13 列逐項＋`BizCode::Internal.http_status()==200`＋`count(http_status==500)==0`〔⚠️e〕）
- [ ] T005 [US2] `rust-api/server/src/envelope.rs` 實作 `BizCode`（13 變體、命名沿 rev2 ⚠️k）＋`code()`／`default_msg()`／`http_status()`（green T004；**code/msg 字串逐字對 research R1 grep 座標 envelope.rs:110-144**；`http_status()` 表：Internal/餘→200、NotFound→404、PermissionDenied→403）；容器編譯＋`cargo test` 綠；worktree commit＋pin bump

**Checkpoint**: US2 全綠＝BizCode 單一真相鎖定（SC-002/003 達成）

## Phase 4: US1 — 統一回應信封形狀對齊前端（P1）🎯 MVP（依賴 US2 BizCode）

**Goal**: `Res<T>`／`PageRes<T>` 序列化逐欄對齊 base-web wire 期望
**Independent Test**: 序列化 golden 逐 byte（成功/錯誤/分頁/null/空[]/無 success）

- [ ] T006 [US1] test-first：`rust-api/server/src/envelope.rs` `#[cfg(test)]` 寫序列化 golden 測（red；對 contracts/envelope-wire-contract.md §1——`Res::ok(42)`→`{"data":42,"code":"0000","msg":"请求成功"}`／ok_msg／err／err_msg／泛型T err／`PageRes` camelCase／分頁承載／`data:null`／空 `records:[]`／斷言序列化字串不含 `"success"`）
- [ ] T007 [US1] `rust-api/server/src/envelope.rs` 實作 `Res<T>`（`{data:Option<T>, code:String, msg:String}`、`#[derive(Serialize)]`、欄序 data→code→msg、code 字串、`data:None`→null 不 `skip_serializing_if`、4 建構子 ok/ok_msg/err/err_msg〔err/err_msg `impl<T>` 泛型化〕、`IntoResponse` 強制 200）＋`PageRes<T>`（`{current,size,total,records}`、`rename_all="camelCase"`、u64、無 pages/success、空頁 []）（green T006；對 R1 envelope.rs:19-88）；容器 `cargo test` 綠；worktree commit＋pin bump

**Checkpoint**: US1 全綠＝信封形狀對齊前端（SC-001/005 達成）

## Phase 5: US3 — 集中錯誤映射人體學（P3；依賴 US2 BizCode＋US1 Res::err）

**Goal**: `AppError` 集中映射成信封＋正確 HTTP status；⚠️f 型別系統結構保證
**Independent Test**: 8 建構子 → (status, body) 對矩陣；保留碼無建構子；internal 不洩漏

- [ ] T008 [US3] test-first：`rust-api/server/src/error.rs` `#[cfg(test)]` 寫 AppError 映射＋⚠️f 結構測（red；對 contracts/envelope-wire-contract.md §3/§4——8 建構子 `into_response()` 的 `(status, body)` 對矩陣／`internal("boom")` body msg＝「服务器内部错误」不含 "boom"〔不洩漏〕／可發出碼集合==8、皆≠保留碼〔⚠️f〕）
- [ ] T009 [US3] `rust-api/server/src/error.rs` 實作 `AppError { code: BizCode, msg: Option<String> }`（`code` 私有、`#[derive(thiserror::Error)]` Display 供 log）＋**8 公開建構子**（login_failed/biz/token_expired/modal_logout/logout/not_found/permission_denied/internal——**4 保留碼無建構子**）＋集中 `IntoResponse`＝`(code.http_status(), Json(Res::err 形 body))`（internal detail 僅進 Display 不入 body）（green T008；對 R4／rev2 error.rs:15-34 改良形）；容器 `cargo test` 綠；worktree commit＋pin bump

**Checkpoint**: US3 全綠（SC-004 達成、⚠️f 結構保證）

## Phase 6: Polish & Cross-Cutting

- [ ] T010 C-V-3 prod target image build（**非新 crate、但驗 server crate multi-stage 不退化**）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`——serde/json feature 加入後 release build 綠（SC-006；Dockerfile 不需改、無新 COPY 行）
- [ ] T011 C-V-4 `/health` 不退化（`grep 'async fn health|"ok"' main.rs` 確認 health plain text 未被信封化、SC-007）＋C-V-5 殘留 grep（部署層零 rev2 不變；`grep -rinE "rev2" rust-api/server/src/envelope.rs error.rs` 零命中——內容註解用「前代」描述）＋quickstart.md 流程逐步對照＋拋棄式卷清理（cv003-cargo/target）
- [ ] T012 收口驗證（**commit only——push／merge 凍結至 finishing，§I.4／⚠️u**）：worktree 全 task commit 齊＋outer pin==worktree HEAD（隨 task bump 紀律回顧）＋specs/003 外層檔全收；`git submodule status` 行首空格

## Dependencies

```
Phase 1 (T001→T002→T003) ──→ US2 (T004→T005) ──→ US1 (T006→T007) ──→ US3 (T008→T009) ──→ Polish (T010→T011→T012)
build 依賴：BizCode〔US2〕← Res::err〔US1〕← AppError〔US3〕；故 build 序 US2→US1→US3（≠ spec 價值優先序 US1>US2>US3）
test-first：每 story T<even>（測 red）→ T<odd>（實作 green）
```

## Parallel Execution Examples

- Phase 1：T001 可獨立（deps 編輯）；T002/T003 序列（build 後掛 module）
- story 內 test→impl 嚴格序列（red→green）；story 間因型別依賴序列（US2→US1→US3）、**無跨 story 並行**

## Implementation Strategy

**MVP first**：Phase 1→3→4（Setup＋US2 BizCode＋US1 envelope）＝信封形狀對齊前端的最小可用價值（US1 P1 用戶價值＋其 US2 BizCode 型別前置）；US3（AppError 集中映射）緊接、Polish 完成全刀。每 phase checkpoint 過了才前進；test-first 嚴格 red→green；任一 `cargo test` fail＝對 wire-contract/research R1 grep 座標校形、不調測試遷就實作。
