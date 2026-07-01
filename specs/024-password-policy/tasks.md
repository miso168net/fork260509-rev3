---
description: "Task list for 024-password-policy"
---

# Tasks: 密碼複雜度政策（管理員可設定、系統驗證就緒）

**Input**: Design documents from `specs/024-password-policy/`（plan.md / spec.md / research.md / data-model.md / contracts/）

**Tests**: rev3 採 **TDD**（CLAUDE.md §3）——純函式 test-first（red→green）；data/wiring 類無新純函式測試者由 acceptance（migration 驗 + curl/psql + CDP）覆蓋，並於該 story 明示「無單元測試及理由」。

**Organization**: 按 user story 分階段、各自可獨立實作/驗收。

## Format: `[ID] [P?] [Story] Description`

- **[P]**：可平行（不同檔/工具鏈、無未完成相依）。**★ rust 全程 serial**（共用 `target`、即使標 [P] 也不平行 cargo；CLAUDE.md §3）——本刀 [P] 僅出現在 base-web 任務（與 rust 不同工具鏈、可真平行）。
- **[Story]**：US1/US2/US3；Setup/Polish 無 story 標籤。
- 路徑相對 worktree：`rust-api/…`、`base-web/…`。

## 執行紀律（烤進每個實作單元、CLAUDE.md §3）

- **rust**：build/test 一律**容器內** `docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`；改 `.rs` 後 force-touch（`find server/src -name '*.rs' -exec touch {} +`）避 stale-mtime 假綠；**全程 serial**。
- **兩段式 commit**：worktree commit（rust-api：正常 conventional；base-web：`--no-verify`〔dev alpine pre-commit 必失敗、非偷懶〕）→ 外層 bump submodule pin（**逐單元同步、不延末刀**，CLAUDE.md §4.1）。
- **★ 絕不 `git push` / `git merge`**（留待 `superpowers:finishing-a-development-branch`、需 user 同意）。

---

## Phase 1: Setup

**Purpose**: 前置確認（本刀無專案初始化）

- [ ] T001 確認在 `024-password-policy` 分支、dev stack `up -d --wait` 就緒；本刀**無新 workspace crate/依賴**（`rust-api/Cargo.toml` members 6 個不變、base-web 無新 npm 依賴）。

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 跨 story 阻塞前置

- **無**。三 story 彼此獨立：m009 seed 隨 US1、`validate_value_type` number 分支隨 US2、`password_policy.rs` 純模組隨 US3。無單一任務阻塞全部 story。

**Checkpoint**: 可直接進 US1（無前置 gate）。

---

## Phase 3: User Story 1 - 管理員設定密碼複雜度政策 (Priority: P1) 🎯 MVP

**Goal**: admin 在 `/manage/system-settings` 看到並可調整 7 政策項（2 數字長度 + 5 開關），值持久保存。

**Independent Test**: migration up 後 `system_settings` 有 7 個 `password_*` 列；CDP super 登入見 5 個 NSwitch + 2 個 NInputNumber，改值/切換後重載仍為新值。

> **無單元測試（理由）**：本 story ＝資料 seed（m009）+ 前端 render wiring，無新純函式 → 由 acceptance（migration 列數驗 + CDP 持久驗、C-V-5/C-V-6）覆蓋（CLAUDE.md §3）。

### Implementation for User Story 1

- [ ] T002 [US1] 建 `rust-api/migration/src/m009_seed_password_policy.rs`（仿 `m008` 骨架 + `m002` seed 片段）：`#[derive(DeriveMigrationName)] pub struct Migration`；**up** ＝ 7 政策 KV `INSERT INTO system_settings (setting_key, setting_value, value_type, description) VALUES (...) ON CONFLICT (setting_key) DO NOTHING`（7 列鍵/值/型/說明見 data-model §1）；**down** ＝ `DELETE FROM system_settings WHERE setting_key IN ('password_min_length','password_max_length','password_require_uppercase','password_require_lowercase','password_require_digit','password_require_special','password_forbid_username')`。
- [ ] T003 [US1] 註冊 m009 於 `rust-api/migration/src/lib.rs`：mod 區末（m008 後）加 `mod m009_seed_password_policy;`＋`migrations()` vec 末加 `Box::new(m009_seed_password_policy::Migration)`。（依賴 T002）
- [ ] T004 [US1] 套用並驗（容器內）：`migration up` → psql `SELECT setting_key,setting_value,value_type FROM system_settings WHERE setting_key LIKE 'password_%'` 得 **7 列**；`migration down` → `migration up` 驗可逆。（依賴 T003）
- [ ] T005 [P] [US1] base-web `base-web/src/views/manage/system-settings/index.vue`：template 於 enum `<template v-if>` 後、`<span v-else>` 前插 `<template v-else-if="item.valueType === 'number'"> <NInputNumber :value="Number(item.settingValue)" :min="1" :max="1024" :step="1" :update-value-on-input="false" @update:value="(v: number | null) => handleNumberUpdate(item, v)" class="w-160px" /> </template>`；script 加 `handleNumberUpdate(item, value)`（鏡像 `handleToggle`：`value===null` 忽略 → `fetchUpdateSystemSetting(item.settingKey, String(value))` → 成功 `window.$message?.success($t('common.updateSuccess'))` → `await getSettings()`）。**★MODAL-WIRING (e)**（user 拍板 A）。
- [ ] T006 [US1] 驗 US1（CDP、restart base-web 後）：super → `/manage/system-settings` 斷言 `NInputNumber` 數 == 2、NSwitch ≥ 5；改 `password_min_length`（blur 提交）+ 切一 `password_require_*` 開關 → 重新 dump 驗值持久（C-V-5）。（依賴 T004、T005）

**Checkpoint**: US1 完整可獨立驗收 —— admin 能設定全部 7 政策項（MVP）。

---

## Phase 4: User Story 2 - 系統拒絕不合法的政策數值 (Priority: P2)

**Goal**: number 型政策值（min/max 長度）非法（非正整數/超界）時，後端以業務錯誤 `2222` 拒絕、不寫入。

**Independent Test**: 純測 `validate_value_type` number 分支綠；curl POST 非法 number → `2222 biz.systemSettings.invalidValue`、psql 值不變。

### Tests for User Story 2 (TDD — 先寫、預期紅) ⚠️

- [ ] T007 [US2] **test-first**：`rust-api/server/src/handler/system_settings.rs` 的 `#[cfg(test)] mod value_type_tests` 內加 number case（沿既有 `.expect_err` + `err.code()`/`err.key()` 風格）：`validate_value_type("number","12"/"1"/"1024")` → `is_ok()`；`"abc"/"0"/"-1"/"9999"/""` → `err.code()=="2222"` 且 `err.key()=="biz.systemSettings.invalidValue"`。**先寫、預期紅**（number 目前 passthrough、非法值誤 pass）。

### Implementation for User Story 2

- [ ] T008 [US2] 實作 `validate_value_type` `number` 分支於 `rust-api/server/src/handler/system_settings.rs`：於 enum arm 後、`_ => Ok(())` fallback 前加 `Some(("number", _)) => { match value.parse::<u32>() { Ok(n) if (1..=1024).contains(&n) => Ok(()), _ => Err(AppError::Biz(Cow::Borrowed("biz.systemSettings.invalidValue"))) } }`。→ T007 轉綠。（依賴 T007）
- [ ] T009 [US2] 驗 US2（容器內 + live）：`cargo test -p server --lib value_type_tests`（含 number）綠（C-V-3）；curl POST update `password_min_length` 值 `abc/-1/0/9999` → `2222`、psql 值不變；合法 `12` → 持久（C-V-4c）。（依賴 T008、T004）

**Checkpoint**: US1 + US2 皆可獨立運作 —— 政策可設且非法數值被守門。

---

## Phase 5: User Story 3 - 系統能判定密碼是否符合政策（供後續改密碼套用） (Priority: P3)

**Goal**: 純函式 `validate_password_complexity` 能就「一組政策 + 候選密碼」判定符合性、回**全部**未滿足條件（本刀 dormant、供刀2 025-user-center 接線）。

**Independent Test**: `cargo test -p server --lib password_policy` 全綠（逐 knob）；與 US1/US2 無耦合（純模組、synthetic 資料測）。

### Tests for User Story 3 (TDD — 先寫、預期紅) ⚠️

- [ ] T010 [US3] **test-first**：建 `rust-api/server/src/auth/password_policy.rs`（`PasswordPolicy` struct + `PolicyViolation` enum〔7 變體〕 + `from_settings(items: &[(&str, &str)]) -> PasswordPolicy` 與 `validate_password_complexity(&PasswordPolicy, plain: &str, user_name: &str) -> Result<(), Vec<PolicyViolation>>` 簽名、body `unimplemented!()`，**全檔零 `entity::`**）＋註冊 `rust-api/server/src/auth/mod.rs` 於 `pub mod password;` 後加 `pub mod password_policy;`（字母序）＋同檔 `#[cfg(test)] mod password_policy_tests`（`from_settings`：on/off/number parse + 缺鍵→預設 8/64；`validate_password_complexity`：長度上下界含邊界、四字元類各缺、禁同帳號 case-insensitive、全通過 Ok、**回全部違規非短路**、min>max reject-all）。**tests 須編譯通過但紅**。

### Implementation for User Story 3

- [ ] T011 [US3] 實作 `rust-api/server/src/auth/password_policy.rs`：`from_settings`（`value=="on"`→true / 其餘含缺鍵→false；`parse::<usize>().unwrap_or(<預設>)`；**零 DB、零 `entity::`**、吃 `&[(&str,&str)]`）＋`validate_password_complexity`（長度用 `plain.chars().count()` 含邊界 `>=min && <=max`；特殊符號 `c.is_ascii_graphic() && !c.is_ascii_alphanumeric()`〔R1〕；禁同帳號 `plain.eq_ignore_ascii_case(user_name)`；逐條收集 `Vec<PolicyViolation>`、空則 `Ok(())`）。→ T010 測轉綠。（依賴 T010）
- [ ] T012 [US3] 驗 US3（容器內、force-touch）：`cargo test -p server --lib password_policy` 全綠（C-V-1/C-V-2）。（依賴 T011）

**Checkpoint**: 三 story 皆可獨立驗收；驗證原語就緒待刀2 接線。

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T013 三守恆（容器內、rust serial）：`cargo test -p server --test entity_access_lint`（`password_policy.rs` 零 `entity::`）＋`cargo test -p server --test endpoint_coverage_lint`（零新 route、registry 不變）＋`migration down`→`up`（up→down→up 可逆）——全綠（C-V-6 rust 部分）。
- [ ] T014 [P] base-web `pnpm typecheck` 綠（容器內 `exec -T base-web sh -c 'cd /app && pnpm typecheck'`）（C-V-6 前端部分）。
- [ ] T015 零回歸驗（C-V-7）：`single_session_default` 開關仍運作、`/auth/login`·`/auth/getUserInfo`·enforce 不變、既有 enum 開關列不破。
- [ ] T016 prod image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`，確認 `m009_seed_password_policy.rs` + `password_policy.rs` 編入 prod target、migration binary 含 m009（C-V-8）。
- [ ] T017 跑 `specs/024-password-policy/quickstart.md` 全流程收尾驗證。

---

## Dependencies & Execution Order

### Phase 相依

- **Setup（T001）**：無相依。
- **Foundational（Phase 2）**：無任務。
- **User Stories（Phase 3-5）**：US1 / US2 / US3 邏輯獨立可分別實作/驗收；US2 之 live 驗（T009）需 US1 的 m009 列（T004）；US3 完全獨立。**★ 因 rust 共用 target 全程 serial，實務上 rust story 順序執行（US1 rust → US2 → US3），base-web（T005/T014）可與 rust 平行。**
- **Polish（Phase 6）**：所有 story 完成後。

### User Story 相依

- **US1 (P1)**：T002→T003→T004（rust seed 鏈）；T005（base-web、[P]）；T006 需 T004+T005。
- **US2 (P2)**：T007→T008（同檔、test-first）；T009 需 T008 + T004（rows）。
- **US3 (P3)**：T010→T011→T012（同檔、test-first）；**與 US1/US2 無耦合**。

### Within Story（TDD）

- test-first（US2 T007 / US3 T010）**須先紅** → 再實作轉綠。
- data/wiring（US1）無純函式測 → acceptance 覆蓋（已於 US1 明示理由）。

### Parallel Opportunities

- **T005（base-web number 分支）** 可與 US1/US2 的 rust 任務平行（不同工具鏈）。
- **T014（pnpm typecheck）** 可與 rust polish 任務平行。
- rust 任務之間**不平行**（serial、共用 target）——US3 純模組雖邏輯獨立，仍與 US1/US2 rust 序列共用 target。

---

## Parallel Example

```bash
# base-web 前端分支（T005）可與後端 rust seed（T002-T004）同時進行：
Task: "base-web system-settings/index.vue 加 number render 分支 + handleNumberUpdate（T005）"
Task: "rust-api m009 seed migration + 註冊 + 驗（T002-T004、rust serial 內部序列）"
```

---

## Implementation Strategy

### MVP First（US1）

1. Phase 1 Setup（T001）。
2. Phase 3 US1（T002-T006）：m009 seed + 前端 number 控件 → **STOP & VALIDATE**（admin 能設定 7 政策項、CDP 持久）。
3. 此即 MVP —— admin 可設定密碼政策（雖 enforce 待刀2）。

### Incremental Delivery

1. US1 → admin 可設定政策（MVP）。
2. US2 → 非法數值守門（資料完整性）。
3. US3 → 驗證原語就緒（供刀2 改密碼）。
4. Polish（三守恆/typecheck/回歸/prod build/quickstart）。

---

## Notes

- [P] = 不同檔/工具鏈、無相依；**rust 全程 serial**（即使 [P]）。
- 每個 story 可獨立完成/驗收；test-first 者須先見紅。
- **逐單元** worktree commit → 外層 bump submodule pin（不延末刀，CLAUDE.md §4.1/§8）。
- base-web commit 用 `--no-verify`；自驗改跑 `pnpm typecheck`。
- **絕不 push/merge**（收尾 `superpowers:finishing-a-development-branch`、需 user 同意）。
- 特殊符號集、number 範圍 `1..=1024`、min>max 處理 已於 research.md R1/R2/R3 定案。
