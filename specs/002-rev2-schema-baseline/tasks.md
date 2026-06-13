# Tasks: rev2-schema-baseline（rev2 終態基線＋rev3 delta）

**Input**: Design documents from `/specs/002-rev2-schema-baseline/`

**Prerequisites**: plan.md ✅、spec.md ✅、research.md（R1~R10＋D1~D4）✅、data-model.md ✅、contracts/（verification-commands＋migration-chain＋demo-menu-enumeration）✅、quickstart.md ✅

**Tests**: 本 feature **無新增單元測試**（plan.md Technical Context 明示＋理由：migration／seed／驗證 scripts、無可獨立測純函式；adapter 自帶測試隨拷入但不納驗收——需 DB fixture、行為由零漂移 diff 實證覆蓋）；驗收＝C-V-0~9 實機（contracts/verification-commands.md），acceptance 任務為必做。

**Organization**: 依 user story 分 phase；US1＝MVP。**兩段式 commit 紀律（001 教訓）**：worktree task 完成即 worktree commit＋outer pin 隨同 bump（不延後收口；CHECKLIST §3.4 提案形）。**§I.4／⚠️u：全程不 push 不 merge**。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（adapter 拷入＋依賴——blocking 全部 US）

**Purpose**: vendored crate 與 workspace 依賴就位、建置綠（⚠️v 拍板＋research R2/R3/R9）。⚠️ 動 rust-api worktree——兩段式 commit

- [ ] T001 整檔拷貝 `rust-api/sea-orm-adapter/`（自 `fork260509-rev2/rust-api/sea-orm-adapter/`：Cargo.toml＋src/{lib,adapter,entity,action,migration}.rs＋examples/×4——§I.5 例外；**拷貝形拍板（analyze M1）**：src/＋examples/ byte-identical、**唯 Cargo.toml 檔頭 provenance 注記更新**為「拷貝自 fork260509-rev2 rust-api/sea-orm-adapter @ <短SHA>（§I.5 例外／拍板#6；原鏈 rev1@0b64a57）」——C-V-9 byte-diff 把關預期唯此 1 行差）；`rust-api/Cargo.toml` members 加 `"sea-orm-adapter"`
- [ ] T002 workspace deps 增量（`rust-api/Cargo.toml`）：`casbin = { version = "2.20", default-features = false }`＋`sea-orm = { version = "1.1.20", default-features = false, features = ["macros", "sqlx-postgres", "runtime-tokio-rustls"] }`（**R3 宣告形——刻意偏離前代 defaults-on、time 不入圖；注記寫進檔、措辭用「前代」不用 rev2 字樣**〔C-V-9 grep 紀律〕）＋`argon2 = "0.5.3"`；`rust-api/migration/Cargo.toml` 加 `argon2.workspace = true`＋`sea-orm-adapter = { path = "../sea-orm-adapter" }`
- [ ] T003 `cd rust-api && cargo build --bins`（host 無 cargo 以 rust:1.86 容器等效、001 形）＋lock 複驗（`grep -c 'name = "time"'`＝0、casbin≥1）＝C-V-1；commit lock＋pin bump
- [ ] T004 [P] `deploy/Dockerfile.rust-api.txt` Manifest／Source 段補 sea-orm-adapter COPY ×2 行（照檔內教訓註解格式；**adapter examples/ 為 .conf/.csv 資料檔、非 cargo [[example]] target、免 COPY**——勿被檔內 [[bench]]/[[example]] 警語誤導；outer 單段 commit）
- [ ] T005 [P] 順手項：`rust-api/migration/src/main.rs` secret 讀檔失敗補 eprintln 警示（CHECKLIST §3.4 既登、rev2 同形缺陷）

**Checkpoint**: workspace 3 member 建置綠、time 不在圖、Dockerfile COPY 就位

## Phase 2: Foundational

**無獨立 foundational 項**——migration 鏈本身即 user story 主體、Setup 已涵蓋全部前置。

## Phase 3: US1 — 基線零漂移（P1）🎯 MVP

**Goal**: m001＋m002 達 rev2 終態、pristine 雙 diff 零差異
**Independent Test**: C-V-2／C-V-3 全綠（檢查點雙零差異＋計數不變式＋argon2 VERIFY-OK）

- [ ] T006 [US1] `rust-api/migration/src/m001_rev2_schema.rs`：10 表手寫終態 DDL（**dump 欄序忠實、data-model.md 座標逐表對照**；INET custom(Alias)；NOT NULL 特例 access_log.operator_id／token.user_id；partial uniq ×3＋token_hash uniq＋一般 index 7；sys_user 直接 BIGSERIAL）＋casbin 委派 `sea_orm_adapter::up()`＋同檔 ALTER 3 治理欄＋對稱 down（DROP 10 表＋adapter::down）；`lib.rs` 掛載
- [ ] T007 [US1] `rust-api/migration/src/m002_rev2_seeds.rs`：92 列／6 表淨效果（sequence-driven 不寫死 id；user_role 雙向 subquery；casbin 72 列免 subquery；argon2id 單一 hash；`ON CONFLICT DO NOTHING`；UPDATE 淨值直接入 INSERT——nick_name=User01／status=1／home='home'／buttons／protected；值來源座標＝data-model.md §3＋R5 拆解）＋down 限定刪除；`lib.rs` 掛載
- [ ] T008 [US1] `tests/002-rev2-schema-baseline/scripts/`：四支 script 照 **verification-commands.md §0 I/O 契約**實作——`pristine-replay.sh`／`normalize.sh`（schema|data 雙模式、五規則凍結形）／`diff-baseline.sh`（含 `--reuse` 重跑語意＋pg 等待形＋計數不變式＋VERIFY 3/3）／`delta-assert.sh`（cv002|stack 雙模式）；**起手執行 C-V-0 前置檢查、fail 即停**（含 /tmp dump 重生）
- [ ] T009 [US1] C-V-2 實機：pristine 重放（seaql 35 applied 斷言）＋normalize 後**兩份基準檔** git-track→`tests/002-rev2-schema-baseline/{rev2-schema-baseline.sql, rev2-data-baseline.sql}`（schema＋6 表 data；audit 快照兼 C-V-5 重跑比對源）
- [ ] T010 [US1] C-V-3 實機：基線檢查點雙 diff **雙零差異**＋計數不變式全中（92 列／p=72 g=0／protected 19・8／id{1,2,3}／seq last_value=3／hash 單一＋VERIFY-OK）；fail＝先判假紅 vs 真 drift（migration-chain.md §3 判讀紀律）、真 drift 修 T006/T007 重跑

**Checkpoint**: US1 全綠＝MVP（SC-001/002/004 達成）

## Phase 4: US2 — rev3 delta 顯式可審（P2）

**Goal**: FK＋demo 選單以獨立步驟落地、delta 斷言全綠
**Independent Test**: C-V-4 對檢查點後資料庫獨立執行

- [ ] T011 [US2] [P] `rust-api/migration/src/m003_user_role_fk.rs`：FK ×2（→sys_user.id／sys_role.id、`ON DELETE RESTRICT`）＋down 卸 constraint（**lib.rs 掛載不在本 task**——T013 起頭單點收斂）
- [ ] T012 [US2] [P] `rust-api/migration/src/m004_demo_menu_seeds.rs`：demo 選單 66 列（**集合凍結權威＝contracts/demo-menu-enumeration.md、28 欄落值映射權威＝rev2 m018 INSERT 形＋enumeration 映射表；逐列回 route 源檔親驗 meta**；深度 4 段分批、parent_id subquery；document 8 頁 href 化〔R4-D2〕；plugin menu_name 中文）＋menu policy 66 列（`'p','R_SUPER',<route_name>,'menu','','',''`、全覆蓋〔R4-D3〕）＋**down 限定 demo 66 route_name 集**（不得波及基線——migration-chain.md 明文）（lib.rs 掛載不在本 task）
- [ ] T013 [US2] 起頭：`lib.rs` 掛載 m003→m004 兩行（單點收斂、避免 T011∥T012 同檔衝突）→ `scripts/delta-assert.sh`＋C-V-4 實機：FK=2（confdeltype='r'）／sys_menu 76／casbin 138（menu 維度 83）／**R_SUPER 直接斷言 66＋非 R_SUPER=0**（FR-006）／**基線全量不變**（靜態 4 表 dump diff＋menu/casbin 排除式 md5 對 C-V-3 留存值——M3 全量形）

**Checkpoint**: US2 全綠（SC-005）

## Phase 5: US3 — 回滾與冪等（P3）

**Goal**: 全鏈守恆＋重複執行安全
**Independent Test**: C-V-5／C-V-6 獨立執行

- [ ] T014 [US3] C-V-5 實機：`down -n 4` 全鏈回滾（僅剩 seaql_migrations 斷言）→ `up -n 2` 重建 → **C-V-3 雙 diff 重跑仍綠**（終態等價＝SC-003）→ 續 up → C-V-4 重斷言綠
- [ ] T015 [US3] C-V-6 實機：再次 `up` exit 0、無 pending、**列數全不變斷言集**＝sys_user 3／sys_role 3／sys_user_role 3／system_settings 1／sys_menu 76／casbin_rule 138（SC-008）

**Checkpoint**: US3 全綠（SC-003/008；波 0 出口「migration up→down→up」項達成）

## Phase 6: Polish & Cross-Cutting

- [ ] T016 C-V-7 實機：001 dev stack `up -d --wait`（migrate gate 自動套 4 支）→ rust-api healthy＋host psql 斷言 12 表＋92＋66 計數＋`/api/health` 不退化（SC-006）
- [ ] T017 C-V-8 prod target image build（**必含**——本刀新增 workspace crate，CLAUDE.md §3 紀律；SC-007）
- [ ] T018 C-V-9 殘留 grep（修訂規則：部署層零豁免不變；rust-api 側內容錨定豁免 `m00[0-9]_rev2_`＋migration README；**adapter 整目錄排除 grep、以 byte-diff 把關**——非 grep 豁免）＋quickstart.md 流程逐步對照零漂移＋拋棄式資源清理（cv002-* 容器/網/卷）
- [ ] T019 收口驗證（**commit only——push／merge 凍結至 finishing，§I.4／⚠️u**）：worktree 全 task commit 齊＋outer pin==worktree HEAD（隨 task bump 紀律執行情況回顧）＋tests/002＋deploy／specs 外層檔全收；`git submodule status` 行首空格

## Dependencies

```
Phase 1 (T001→T002→T003；T004/T005 [P]) ──→ US1 (T006→T007→T008→T009→T010)
                                            └→ US2 (T011∥T012 → T013；依賴 T010 過——delta 套在驗過的基線上)
                                                └→ US3 (T014→T015；依賴 T013)
                                                    └→ Polish (T016→T017→T018→T019)
內部：T006/T007 依賴 T003（adapter 編譯綠）；T009 依賴 T008；T012 依賴 contracts/demo-menu-enumeration.md（已凍結）
```

## Parallel Execution Examples

- Phase 1：T004∥T005（T003 後；不同檔、不同 repo 層）
- Phase 4：T011∥T012（不同 migration 檔本體；lib.rs 掛載**不在兩 task 內**、由 T013 起頭單點收斂、序固定 m003→m004）

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T010）＝US1 零漂移基線即最小價值；US2（T011~T013）緊接、US3（T014~T015）與 Polish 完成全刀。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進；diff 假紅判讀紀律（migration-chain.md §3）全程適用。
