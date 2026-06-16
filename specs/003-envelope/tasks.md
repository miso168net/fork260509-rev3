# Tasks: envelope（統一回應信封＋msg-i18n key 規約）

**Input**: Design documents from `/specs/003-envelope/`

**Prerequisites**: plan.md ✅、spec.md ✅（含 Clarifications）、research.md（R1~R8）✅、data-model.md ✅、contracts/（envelope-contract＋i18n-key-convention＋verification-commands）✅、quickstart.md ✅；constitution **v1.1.0**（⚠️aa `BASE-WEB-I18N-WIRING ★` 軌道）

**Tests**: 本 feature **有契約/元件測試**（spec FR-011＋C-V）。型別/序列化契約（`Res`/`PageRes`/`AppError`）＝rust **in-crate `#[cfg(test)]`**（非 classic 純函式 red-green、無 DB → 一般 `cargo test`、無 `#[ignore]`）；`translateBackendMsg`＝小純函式（base-web component/unit 可測）；4 翻譯點 wiring **無獨立單元測試**、由 component/acceptance 覆蓋（CLAUDE.md §3 紀律明示）。驗收＝C-V-0~3 實機（C-V-4 端到端為階梯、非本刀）。

**Organization**: 依 user story 分 phase；**US1＝MVP**。**雙 worktree 各兩段式 commit**（worktree commit→outer pin bump、不延後收口、001 教訓）；**rust 全程 serial**（共用 target、即使 [P] 不平行 cargo）、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime 假綠）；**base-web commit `--no-verify`**（dev 容器 pre-commit hook 必失敗）；**base-web 改走 ⚠️aa `BASE-WEB-I18N-WIRING ★` 軌道、fork-delta `rev3-inline`**（修改型保留原行註解＋token、新增型標記圈界）；**§I.4／⚠️u：全程不 push 不 merge**（tasks 不得排 push/merge）。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（rust-api worktree、blocking US1/US3）

**Purpose**: server crate 取得 serde 直接 dep、建置綠（research R6）。⚠️ 動 rust-api worktree——兩段式 commit

- [ ] T001 `rust-api/Cargo.toml` `[workspace.dependencies]` 加 `serde = { version = "1", features = ["derive"] }`＋`serde_json = "1"`（lock 已 pin `1.0.228`/`1.0.150`、無 churn）；`rust-api/server/Cargo.toml` `[dependencies]` 加 `serde = { workspace = true }`＋`serde_json = { workspace = true }`（**不加 sea-orm**——`From<DbErr>` 延後 R7）；容器內 `cargo build -p server` 綠

**Checkpoint**: server crate serde 就位、建置綠、workspace members 不變（無新 crate）

## Phase 2: Foundational

**無獨立 foundational 項**——US1 的 rust 信封/錯誤型即 US3 前置（規約載體）；US2（base-web）與 US1 各自獨立可測（不同 worktree）。Setup 已涵蓋 dep 前置。

## Phase 3: US1 — 統一信封＋凍結碼契約（rust-api、P1）🎯 MVP

**Goal**: 後端以統一信封＋凍結 13 碼矩陣交付；業務/內部錯誤走 HTTP 200、僅 `4040`→404/`5003`→403；reserved 4 碼永不發出。
**Independent Test**: C-V-0（in-crate 契約測全綠）＋C-V-1（curl `4040` wire 形）；不依賴 base-web。

- [ ] T002 [US1] `rust-api/server/src/envelope.rs`（新建）：`Res<T>{data,code,msg}`（`#[derive(Serialize)]`、欄序 data→code→msg、錯誤 `data:null` 不省略）＋`PageRes<T>{current,size,total,records}`（camelCase、無 pages/success、空頁 `records:[]`）＋`impl IntoResponse for Res<T>`（`StatusCode::OK`）＋`Res::ok(data)` helper（code `"0000"`/key `common.success`）；data-model.md §1 為型權威
- [ ] T003 [US1] `rust-api/server/src/error.rs`（新建）：`AppError` **僅 9 可發碼變體**（見 data-model.md §2／envelope-contract.md §2 表、各烤 `(code,key,http)`；`Biz(key: Cow<'static,str>)` 承載 per-entity key、未指定＝`biz.error`）＋`impl IntoResponse for AppError`（建 `Res{data:null,code,msg:key}`＋預設 200、match `NotFound`→404/`PermissionDenied`→403）；**reserved `7778`/`8889`/`9998`/`9999` 不設變體**＝型別層保證永不發出；**不**建 `From<DbErr>`（R7）（依賴 T002 的 `Res`）
- [ ] T004 [US1] `rust-api/server/src/main.rs`：加 `mod envelope; mod error;`＋router 接 `.fallback(handler_404)`（小 `async fn handler_404() -> AppError { AppError::NotFound }`——不能直接傳 enum variant、research R6）（依賴 T002/T003）
- [ ] T005 [US1] in-crate `#[cfg(test)] mod`（於 `envelope.rs`/`error.rs`）契約測＝C-V-0：① 每 `AppError` 變體→(code,key,http) 對齊 13 碼矩陣（9 可發）② `Res`/`PageRes` serde 形（欄序、`data:null` 不省略、`code` string、無 pages/success、空頁 `[]`）③ `IntoResponse` http（9 碼除 4040→404/5003→403 皆 200）④ msg 是 key（regex `^[a-z][a-zA-Z]*(\.[a-zA-Z]+)+$`、無 CJK）⑤ emitted ⊆ 9（reserved 無變體＝編譯期）；容器內 `cargo test -p server` 綠（先 force-touch；警覺「0 passed/N filtered」假綠）（依賴 T002~T004）
- [ ] T006 [US1] C-V-1 實機：dev stack `up -d --wait` 後 `curl -w '%{http_code}' http://127.0.0.1:31081/no-such-route` → HTTP 404＋`{"data":null,"code":"4040","msg":"system.notFound"}`（`jq -e` 斷言；新碼沒上先 force-touch＋`restart rust-api`）（依賴 T004）

**Checkpoint**: US1 全綠＝MVP（SC-001/002/003/004/008；後端信封契約成立、msg 載去前綴 key）→ **雙段 commit**（rust-api worktree→outer pin）

## Phase 4: US2 — 語言無關 key 前端在地化（base-web、P2）

**Goal**: 前端以 `$t` 將 wire `msg`（key）譯為當前語言顯示；未知 key graceful（顯原始 key 字串、Clarifications B）。
**Independent Test**: C-V-2（`pnpm typecheck` 過＋component：13 固定 key 命中譯文、未知 key 回原始字串）；component 不需後端。
**依賴**: 概念上承 US1 的 msg=key（wire），但本 story 自身 acceptance（component+typecheck）**獨立於 US1**；端到端需兩者（階梯、非本刀）。**全程 ⚠️aa 軌道、fork-delta `rev3-inline`、commit `--no-verify`**。

- [ ] T007 [US2] `base-web/src/typings/app.d.ts`：`App.I18n.Schema`（`:313-849` 內）加 `backend` 型（4 根 common/auth/biz/system＋13 固定碼 key 結構、見 data-model.md §3／i18n-key-convention.md §4）——使 `GetI18nKey` 納 `backend.*`；⚠️aa (iii)（新增型、檔頭/區塊 `rev3-inline` 標記）
- [ ] T008 [P] [US2] `base-web/src/locales/langs/zh-cn.ts`：加 `backend` 物件（zh-CN 譯文＝i18n-key-convention.md §3 表）；`: App.I18n.Schema` annotation 編譯強制補齊；⚠️aa (ii)（依賴 T007 Schema）
- [ ] T009 [P] [US2] `base-web/src/locales/langs/en-us.ts`：加 `backend` 物件（en-US 譯文＝§3 表）；同上強制；⚠️aa (ii)（依賴 T007；與 T008 不同檔、可 [P]）
- [ ] T010 [US2] `base-web/src/locales/index.ts`：匯出 `translateBackendMsg(msg: string): string`＝`$t(('backend.' + msg) as App.I18n.I18nKey)`（前端補 `backend.` 前綴、前綴歸屬 (c)）；⚠️aa (iii)（依賴 T007）
- [ ] T011 [US2] `base-web/src/service/request/index.ts`：4 翻譯點接 `translateBackendMsg`——`:71` modal `content`、`:109` `onError` 的 `message = translateBackendMsg(error.response?.data?.msg) ?? message`、`:64`/`:51` dedup push/filter 用翻譯後值（保 stack 鍵＝顯示文字）；**不**碰 `shared.ts:54 showErrorMsg`（R2）；⚠️aa (i)、每處保留原行註解＋`// [rev3-inline I18N(i)] 原行: ...`（依賴 T010）
- [ ] T012 [US2] C-V-2 實機：容器內 `pnpm typecheck` 過（Schema+雙 langs 齊）＋base-web component/unit——(a) **命中＝雙語各驗**（對齊 SC-005）：`translateBackendMsg('auth.login.failed')` 於 locale=zh-CN 回「用户名或密码错误」、en-US 回「Incorrect username or password」（13 固定 key 抽樣）；(b) **fallback**（SC-006）：`translateBackendMsg('biz.unknown.x')`→回 `backend.biz.unknown.x` 原始字串；vite 沒熱載新 export 時 `restart base-web`（依賴 T007~T011）

**Checkpoint**: US2 全綠（SC-005/006；前端 i18n 顯示機制成立）→ **雙段 commit**（base-web worktree `--no-verify`→outer pin；`git status` 確認無 `components.d.ts` 漏網——本刀不新增元件、預期無）

## Phase 5: US3 — 可擴充 key 規約 conformance guard（P3）

**Goal**: 規約（4 根＋文法 `<root>.<entity>.<condition>`）被定義並由自動檢查鎖定，後續切片一致擴充。
**Independent Test**: rust 文法-conformance 斷言綠（所有 `AppError` key 合文法＋4 根；13 seed key conform）。
**依賴**: US1（`error.rs` 的 key）。

- [ ] T013 [US3] 於 T005 的 in-crate 契約測**擴充**文法-conformance 斷言（`rust-api/server/src/error.rs` test）：所有 `AppError` 變體 key 符 `^(common|auth|biz|system)(\.[a-zA-Z]+)+$`（4 根 membership＋`<root>.<entity>.<condition>` 文法）；9 固定碼 key 逐一 conform；註記「後續切片 per-entity key 循此規約擴 Schema/langs」（i18n-key-convention.md §1/§4 權威）；容器內 `cargo test -p server` 綠（rust serial、接 US1 後）→ 隨 US1 段或獨立 commit

**Checkpoint**: US3 全綠（規約 enforced；FR-006 落地）

## Phase 6: Polish & Cross-Cutting

- [ ] T014 C-V-3 prod target image build sanity：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 成功（首批實質 server 碼＋serde 直接 dep、防 prod COPY/dep 缺口；SC-007）
- [ ] T015 fork-delta audit：`grep -rn 'rev3-inline' base-web/src/{typings/app.d.ts,locales,service/request}` 確認 ⚠️aa 三範圍每處改動皆帶 `rev3-inline` token、且**未逾三範圍**（無攔截器控制流/非 i18n inline 改動）；upstream 衝突風險逐處於 i18n-key-convention.md §6 已錄
- [ ] T016 follow-up backlog 登記（`docs/INTEGRATION-CHECKLIST.md` §3.X、outer 單段 commit）：① i18n 顯示端到端**階梯**（波 0 Auth/login `1000` toast 首檢；波 1 system_settings per-entity `2222`）② `4040`/`5003` 前端顯示限制（enforce 刀再議是否拓寬 `onError`）③ `From<DbErr>` 延後（首個產 `DbErr` 切片帶入＋加 sea-orm 到 server）
- [ ] T017 收口驗證（**commit only——push/merge 凍結至 finishing、§I.4／⚠️u**）：兩 worktree 全 task commit 齊＋outer pin == 各 worktree HEAD（pin 隨 task bump 紀律回顧）＋specs/003-envelope 外層檔收；`git submodule status` 兩列行首空格；quickstart.md 5 步逐步對照綠

## Dependencies

```
Phase 1 (T001) ──┬─→ US1 (T002→T003→T004→T005→T006)  [rust-api worktree、serial]
                 │       └─→ US3 (T013；接 T005 後、rust serial)
                 └─→ US2 (T007→{T008∥T009}→T010→T011→T012)  [base-web worktree、⚠️aa、--no-verify]
                                                              （US2 自身 acceptance 獨立於 US1）
US1 ∥ US2（不同 worktree、可並行；單實作者則序：US1 MVP 先）
US1+US2+US3 ──→ Polish (T014→T015→T016→T017)
內部：T003 依 T002；T004 依 T002/T003；T005 依 T002~T004；T006 依 T004；T008∥T009 依 T007；T010 依 T007；T011 依 T010；T012 依 T007~T011；T013 依 T005
```

## Parallel Execution Examples

- **Phase 4**：T008（zh-cn.ts）∥ T009（en-us.ts）——不同檔、同依賴 T007。
- **跨 story**：US1（rust-api worktree）∥ US2（base-web worktree）——不同 repo 層、無共享狀態（端到端才需兩者、屬階梯）。**rust 內部不 [P]**（共享 cargo target、serial）。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T006）＝US1 後端信封契約即最小價值（wire 成立、msg 載 key）。US2（T007~T012）前端 i18n 顯示、US3（T013）規約 guard 緊接；Polish 收全刀。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進。**雙 worktree 各兩段 commit、rust serial、base-web `--no-verify`、全程不 push/merge**。
