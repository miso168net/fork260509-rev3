# Tasks: soft-delete 基建（SoftDeletable＋facade 唯一管道＋entity_access_lint）

**Input**: Design documents from `/specs/004-soft-delete-infra/`

**Prerequisites**: plan.md ✅、spec.md ✅（US1~US3、16/16 checklist、NEEDS CLARIFICATION=0）、research.md（R1~R8）✅、data-model.md（11 entity 反射 m001＋型對映＋SoftDeletable＋facade＋lint）✅、contracts/（verification-commands＋soft-delete-lint-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS）

**Tests**: 本 feature **有契約/守恆/活體測**（spec FR-006/007＋C-V）。`entity_access_lint`＝rust `server/tests/`（build-failing、讀檔不 `use server::`、含 scan fn 自測）；`find_active` live＝in-crate `#[cfg(test)] #[ignore]`＋DATABASE_URL＋`--test-threads=1`；entity 編譯＝C-V-0。

**Organization**: 依 user story 分 phase；**US1＝MVP**。**rust 全程 serial**（共用 target、即使 [P] 不平行 cargo）、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime 假綠）；**兩段式 commit**（rust-api worktree→outer pin、不延後、001 教訓）；**deploy/Dockerfile 為 outer 檔→單段 commit**（非兩段式）；**§I.4：全程不 push 不 merge**（tasks 不得排 push/merge）。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup（rust-api worktree、blocking 全 US）

**Purpose**: 新 workspace crate `entity` 就位、server 取得 sea-orm＋entity dep、建置綠。⚠️ 動 rust-api worktree——兩段式 commit。

- [ ] T001 `rust-api/entity/Cargo.toml`（新建：edition 2021、`sea-orm` features `["macros","with-chrono","with-json","with-ipnetwork"]`）＋`rust-api/entity/src/lib.rs`（初始空、待各 entity `pub mod`）；`rust-api/Cargo.toml` `[workspace]` members 加 `"entity"`；容器內 `cargo build -p entity` 綠（空 crate）。**⚠️ with-ipnetwork build 早驗**：此步即拉 ipnetwork crate 編譯——若撞 1.86 MSRV／lock churn，退 INET→`String`+facade `::text` cast、改 entity Cargo.toml 去 with-ipnetwork、回報主線＋登 §3.X（research R2 contingency）
- [ ] T002 `rust-api/server/Cargo.toml` `[dependencies]` 加 `sea-orm = { workspace = true }`＋`entity = { path = "../entity" }`；容器內 `cargo build -p server` 綠（deps resolve、無新碼）

**Checkpoint**: entity crate 就位、server dep 解析綠、workspace members 含 entity（`cargo metadata` 核）

## Phase 2: Foundational

**無獨立 foundational 項**——entity crate scaffold（Setup）即共享前置；US1（soft-delete 機制）/US2（lint 守恆）/US3（其餘 entity）各自獨立可測。

## Phase 3: US1 — 統一 soft-delete 讀取機制（P1）🎯 MVP

**Goal**: 3 個真 soft-delete entity＋`SoftDeletable` trait＋`find_active`；被標記刪除列自 active 查詢排除、未過濾查詢仍含。
**Independent Test**: C-V-2 `find_active` live（txn 內刪 sys_user 一列 → `find_active()` 排除／`find()` 含）；不依賴 US2/US3。

- [ ] T003 [US1] `rust-api/entity/src/sys_user.rs`（新建）：sys_user entity（16 欄、欄權威＝m001:206；`DeriveEntityModel`；`id` i64 PK auto_increment；tstz→`DateTimeWithTimeZone`〔deleted_at/created_at/updated_at〕；smallint→i16〔user_gender/status〕；`session_policy` String〔default 'inherit'〕）＋`lib.rs` 加 `pub mod sys_user;`（依 T001）
- [ ] T004 [P] [US1] `rust-api/entity/src/sys_role.rs`（新建）：sys_role（12 欄、m001:261；同型對映慣例）＋`lib.rs`（與 T005 不同檔、可 [P]；rust 不平行 cargo）
- [ ] T005 [P] [US1] `rust-api/entity/src/sys_menu.rs`（新建）：sys_menu（28 欄、m001:303；**jsonb query/buttons→`Json`**；**`order`→`#[sea_orm(column_name = "order")]`**〔PG 保留字〕；`protected` bool default false）＋`lib.rs`
- [ ] T006 [US1] `rust-api/server/src/model/soft_delete.rs`（新建）：`SoftDeletable: EntityTrait` trait（`deleted_at_column() -> Self::Column`＋`find_active() -> Select<Self>` default＝`find().filter(deleted_at IS NULL)`；**純 sea_orm 泛型、無 `entity::`、lint-clean**）＋`server/src/model/mod.rs`（`pub mod soft_delete; pub mod facade;`）＋`server/src/main.rs` 加 `mod model;`（router/handler 不變、無新 endpoint）（依 T002）
- [ ] T007 [US1] `rust-api/server/src/model/facade/`（新建 dir）：`SoftDeletable` impl ×3（sys_user/sys_role/sys_menu、各 `fn deleted_at_column() -> Self::Column { <entity>::Column::DeletedAt }`；**含 `entity::` 路徑、置 facade/ 走 lint 豁免**）＋`facade/mod.rs`；容器內 force-touch → `cargo build -p server` 綠（依 T003~T006）
- [ ] T008 [US1] in-crate `#[cfg(test)] #[ignore]` `find_active` live smoke（C-V-2、置 `soft_delete.rs` 或 `facade/` 內）：開 txn → sys_user id=1 `UPDATE deleted_at=now()` → 斷言 `SysUser::find_active()` **不含** id=1、`SysUser::find()` **含** id=1 → **rollback**（不動 002 seed）；容器內 force-touch → `cargo test -p server -- --ignored --test-threads=1 soft_delete`（DATABASE_URL 帶；警覺「0 passed/N filtered」假綠）（依 T007）

**Checkpoint**: US1 全綠＝MVP（SC-001/002；soft-delete 讀取機制成立）→ **雙段 commit**（rust-api worktree→outer pin）

## Phase 4: US2 — facade 唯一管道守恆（P2）

**Goal**: `entity_access_lint` build-failing 守恆建立、且可證有效（綠＋抓得住違規＋不誤殺）。
**Independent Test**: C-V-1 lint 通過＋scan fn 自測；需 entity crate＋facade/ 存在（US1 後）、不依賴 US3。

- [ ] T009 [US2] `rust-api/server/tests/entity_access_lint.rs`（新建——現無 `server/tests/`）：build-failing `#[test]` 掃 `server/src/**/*.rs`——兩階段〔(1) 抹白註解 `//`、`/* */`＋字串字面 (2) 抓 token-boundary path-root `entity::`、前界非 ident〕；`server/src/model/facade/` 路徑豁免；命中非豁免 → panic 列違規處。**scan fn 自測** `#[test]`（免動樹）：`entity::Foo`→flagged／`sea_orm::entity::Bar`→not／`// entity::X`、`"entity::Y"`→not／facade/ 路徑→exempt（FR-006 雙證、防 vacuous）。`server` bin-only→只讀檔、不 `use server::`。容器內 force-touch → `cargo test -p server --test entity_access_lint` 綠（依 T007）

**Checkpoint**: US2 全綠（SC-003；facade 唯一管道守恆 enforced）→ **雙段 commit**（或併 US1 段）

## Phase 5: US3 — 完整 L2 資料層（P3）

**Goal**: 其餘 8 entity 建齊、11 entity 反射 schema 編譯綠（後續業務刀只加 facade）。
**Independent Test**: C-V-0 `cargo build -p entity`（全 11 模組）綠；依 entity crate（Setup）、各自不同檔。

- [ ] T010 [P] [US3] `rust-api/entity/src/{system_settings,sys_user_role,sys_token}.rs`（新建）：system_settings（10 欄、m001:366；PK `setting_key` String(64)；**不** impl SoftDeletable——例外）＋sys_user_role（2 欄、複合 PK `(user_id,role_id)`、m001:414、零審計）＋sys_token（9 欄、m001:433；tstz ×4；`token_hash` unique）＋`lib.rs` 補 3 `pub mod`（依 T001）
- [ ] T011 [P] [US3] `rust-api/entity/src/{sys_operation_log,sys_access_log,sys_login_attempt}.rs`（新建）：3 append-only log（m001:485/549/593）；**jsonb payload_before/after→`Json`**（operation_log）；**INET operator_ip/client_ip→`IpNetwork`**（三表、with-ipnetwork；若 T001 退 String 則此處同步 String+`::text` 慣例註記）＋`lib.rs` 補 3 `pub mod`（依 T001）
- [ ] T012 [P] [US3] `rust-api/entity/src/{casbin_rule,sys_casbin_policy_archive}.rs`（新建）：casbin_rule（11 欄＝8 adapter-base〔id/ptype/v0..v5、型 **cross-check `sea-orm-adapter` DDL**〕＋3 治理 ALTER protected/created_at/created_by、m001:643）＋sys_casbin_policy_archive（13 欄、m001:667；v0..v5 String(125)）＋`lib.rs` 補 2 `pub mod`；容器內 force-touch → `cargo build -p entity`（全 11）綠（依 T001）

**Checkpoint**: US3 全綠（SC-004；L2 entity 層完成 11 模組）→ **雙段 commit**

## Phase 6: Polish & Cross-Cutting

- [ ] T013 `deploy/Dockerfile.rust-api.txt`（**outer 檔、非 rust-api worktree → outer 單段 commit**）：Manifest 段加 `COPY rust-api/entity/Cargo.toml ./entity/`、Source 段加 `COPY rust-api/entity/src ./entity/src`；runtime 段不變（entity 是 lib、編進 server binary）
- [ ] T014 C-V-3 prod target image build sanity：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 成功（新 workspace crate＋全 11 entity 打包、防 prod COPY 缺口；SC-006）（依 T013＋US3）
- [ ] T015 follow-up backlog 登記（`docs/INTEGRATION-CHECKLIST.md` §3.X、outer 單段 commit）：① with-ipnetwork 1.86 MSRV／lock churn 風險（T001 若退 String+cast 則記實況、否則記「已驗綠」）② INET log entity 讀寫 facade＋decode 正確性 → audit 刀（首個 log 消費者）③ casbin_rule 8 欄 adapter-base 型 → policy 刀消費時 cross-check 複核 ④（順手、§7.5）拔 MILESTONES §1 row＋CHECKLIST 最新進展 兩處 stale「未 push」
- [ ] T016 收口驗證（**commit only——push/merge 凍結至 finishing、§I.4**）：rust-api worktree 全 task commit 齊＋outer pin == worktree HEAD（pin 隨 task bump 紀律回顧）＋deploy/Dockerfile outer commit＋specs/004 外層檔收；`git submodule status` rust-api 行首空格；quickstart 4 步逐步對照綠

## Dependencies

```
Phase 1 Setup (T001→T002) ──┬─→ US1 (T003,{T004∥T005}→T006→T007→T008)  [rust-api worktree、serial]
                            ├─→ US2 (T009；需 entity crate＋facade/〔US1 後〕)
                            └─→ US3 ({T010∥T011∥T012}；需 entity crate〔Setup 後〕、各不同檔)
US1+US2+US3 ──→ Polish (T013→T014；T015；T016)
內部：T002 依 T001；T003~T005 依 T001；T006 依 T002（trait 純泛型、不需 entity）；T007 依 T003~T006；T008 依 T007；T009 依 T007；T010~T012 依 T001；T014 依 T013＋T010~T012（全 entity）；T016 殿後
US1 ∥ US2 ∥ US3（概念上不同檔可並行；單實作者則序：US1 MVP 先 → US2 → US3）
```

## Parallel Execution Examples

- **Phase 3**：T004（sys_role）∥ T005（sys_menu）——不同檔、同依賴 T001。
- **Phase 5**：T010 ∥ T011 ∥ T012——三組 entity 不同檔、同依賴 T001。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔、邏輯可並行」。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T008）＝Setup＋US1 soft-delete 讀取機制即最小價值（find_active 成立）。US2 lint 守恆（T009）＋US3 完整 L2（T010~T012）緊接；Polish 收全刀（prod build／follow-up／收口）。每 phase checkpoint 過了才前進；任一 C-V fail＝修復重跑、不帶病前進。**rust serial、容器內 build/test、改 .rs 先 force-touch；with-ipnetwork build 早驗（T001）；兩段式 commit（worktree→outer pin）、deploy/Dockerfile 為 outer 單段；全程不 push/merge**。
