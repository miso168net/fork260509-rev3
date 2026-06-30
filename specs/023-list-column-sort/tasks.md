---
description: "Task list — 列表欄位排序（023-list-column-sort）"
---

# Tasks: 列表欄位排序（多欄、伺服端、可保留）

**Input**: `specs/023-list-column-sort/`（plan.md / spec.md / research.md / data-model.md / contracts/）

**Tests**: 含測試任務 —— 專案 §3 TDD 紀律：純函式 test-first（red→green）；wiring 由 contracts/ 的 C-V acceptance（curl+CDP+psql）覆蓋。

**Organization**: 依 user story 分相。**注意**：executing-plans 階段不綁本檔編號，依【實際相依/獨立可審邊界】重組執行單元（CLAUDE.md §3）。

## 紀律（烤進每個執行單元、不可違反）

- **rust 全程 serial**（共用 target，即使標 [P] 也不平行 cargo）；build/test 在 rust-api **容器內** `docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`；改 `.rs` 後 **force-touch**（`find server/src migration/src -name '*.rs' -exec touch {} +`）；live smoke `--include-ignored --test-threads=1` 帶 `DATABASE_URL`。
- **base-web** commit `--no-verify`（alpine pre-commit hook 壞）；自驗跑 `pnpm typecheck`；加 i18n 鍵後 CDP 前 **`restart base-web`**（vite stale-locale）。
- **★ 絕不 `git push`／`git merge`** 於 `finishing-a-development-branch` 之前；worktree commit 只 local。
- **兩段式 commit**（§4.1）：worktree commit → 回外層 bump submodule pin（**逐執行單元邊界即做、不延末刀**、S9）。
- **[P]** = 不同檔/不同 worktree、無相依；rust 任務即使 [P] 仍 serial 跑。

---

## Phase 1: Setup

- [ ] T001 [P] 建 index migration `rust-api/migration/src/m008_login_attempt_created_at_index.rs`（up：`CREATE INDEX idx_login_attempt_created_at ON sys_login_attempt(created_at)`；down：`DROP INDEX idx_login_attempt_created_at`），並在 `rust-api/migration/src/lib.rs` 加 `mod m008_login_attempt_created_at_index;`（接 m007 後）+ `migrations()` vec push `Box::new(m008_login_attempt_created_at_index::Migration)`（兌現 clarify Q1、data-model §2）

---

## Phase 2: Foundational（排序引擎 — 阻擋所有 user story）

**⚠️ CRITICAL**：本相完成前任何 user story 不可開工。

### 後端引擎（rust，serial）

- [ ] T002 寫 `parse_sort_spec` 純函式單元測試（red）於 `rust-api/server/src/handler/system_manage.rs` `#[cfg(test)]`：空/全空白→`Ok(vec![])`、非法方向→`Err`、重複欄→`Err`、`"a:asc,b:desc"`→有序 `[(a,Asc),(b,Desc)]`
- [ ] T003 實作 `parse_sort_spec(Option<String>) -> Result<Vec<(String, sea_orm::Order)>, AppError>`（green）於 `system_manage.rs`（鄰 `normalize_*`；空字串守門；方向白名單 asc/desc；去重；違規→`AppError::Biz("biz.common.invalidSort")`）
- [ ] T004 寫 7 個 `resolve_<entity>_sort` 白名單測試（red）於 `system_manage.rs`：每 entity 白名單欄命中→正確 `Column`、未白名單欄→`Err`（對照 data-model §3）
- [ ] T005 實作 7 個 `resolve_<entity>_sort(Vec<(String,Order)>) -> Result<Vec<(Column,Order)>, AppError>`（green）於 `system_manage.rs`：`match` 白名單映 Column（user/role/ip_rule/operation_log/access_log/login_attempt/casbin_policy_archive；**grep entity `Column` 真實變體名對齊**，⚠️ `sys_ip_rule.Column::Order` 對應保留字欄）
- [ ] T006 7 個 list query DTO inline 加 `sort: Option<String>`（camelCase）於 `system_manage.rs`：`UserSearchQuery`/`RoleSearchQuery`/`OperationLogQuery`/`AccessLogQuery`/`LoginAttemptQuery`/`ArchivedPolicySearchQuery`/`IpRuleSearchQuery`
- [ ] T007 7 個 facade `list*` 簽章加 `sort: Vec<(Column, Order)>` 並 apply（`sort` 空→走原預設那行 byte-identical；非空→`for (c,o) in sort { q=q.order_by(c,o) }` + Id tie-break、方向依各表既有 Id 預設）於 `rust-api/server/src/model/facade/sys_{user,role,ip_rule,operation_log,access_log,login_attempt,casbin_policy_archive}.rs`（data-model §4）。⚠️ **ip_rule 特例（analyze F4）**：sort 非空時仍**保留領頭 `deleted_at IS NULL DESC` 群組鍵**（回收桶語意、已刪恆沉底）再接 user sort cols + Id，避免已刪列混入
- [ ] T008 7 handler 接線（`parse_sort_spec` → `resolve_<entity>_sort` → 傳入 facade `list`；3 審計頁 export 分支共用同一呼叫→自動反映排序 FR-016）於 `system_manage.rs`；非法 sort 由 `?` 冒泡成 `2222`
- [ ] T009 後端非法排序 i18n key（analyze F2）：rust 回 wire msg `biz.common.invalidSort`（T003）；攔截器 `translateBackendMsg`=`$t('backend.'+msg)`（`base-web/src/locales/index.ts:25`）→ 查 **`backend.biz.common.invalidSort`**。故 base-web 在 **`backend.biz` 下新增 `common.invalidSort`** 譯文（`src/locales/langs/{zh-cn,en-us}.ts` + `src/typings/app.d.ts` Schema，**先 Schema 後 locale**，循 BASE-WEB-I18N-WIRING ★ (ii)(iii)）—— **絕不**用 `backend.common.invalidSort`（少 `biz.` 層→raw key）。防禦性（前端正常不觸發、只送白名單欄；故須 CDP 主動觸發驗 toast 非 raw key、見 C-V-5）

### 前端引擎（base-web，可與 rust [P]）

- [ ] T010 [P] 新檔 `base-web/src/typings/api/rev3-extra.d.ts`：search params 擴 `sort?: string`（ADAPT 新檔、不改 frozen `system-manage.d.ts`）
- [ ] T011 新建 `useTableSort` composable `base-web/src/hooks/common/use-table-sort.ts`：受控排序狀態（自維護點擊序清單）+ `@update:sorter` handler（讀 naive-ui 原生 order、reconcile：改向/新欄 append/取消移除、**不覆寫循環**）+ column 排序 props helper（`sorter:{multiple:N}` + 受控 `sortOrder`）+ 導出 `sort` wire 字串（`field:dir,...`）+ 排序變更 reset 回第 1 頁。research §R5（clear/persist 留 US3/US4 additive）
- [ ] T012 [P] i18n `common.clearSort`：`src/typings/app.d.ts` `Schema.common` 加 `clearSort: string;`（先）+ `src/locales/langs/zh-cn.ts`（`清除排序`）/`en-us.ts`（`Clear sort`）common 區（research §R9；MODAL-WIRING (f) 範圍）
- [ ] T013 [P] 若 base-web 有單元測試 infra（vitest）：寫 composable 純邏輯測（點擊序 append/toggle/remove、wire 字串生成）；無則由 C-V CDP 覆蓋、在本檔註明「composable 無單元測試、acceptance 覆蓋」

**Checkpoint**：引擎就緒 —— 後端 7 端點可收 sort、composable 可掛任一頁。

---

## Phase 3: User Story 1 — 依單一欄位排序整個列表 (P1) 🎯 MVP

**Goal**：在 user 頁點欄頭即整資料集排序、3-state 循環（第一下反序）。

**Independent Test**：user 頁多頁資料點欄頭，第一列為全表極值（非僅當前頁）。

- [ ] T014 [US1] wire `base-web/src/views/manage/user/index.vue`：import `useTableSort`+`useRoute`、可排序欄（userName/userGender/nickName/userPhone/userEmail/status，data-model §3）spread 排序 props、`<NDataTable>` 綁 `@update:sorter`、`sort` 併進 `searchParams`
- [ ] T015 [US1] curl acceptance（C-V-2/4/5）：getUserList `?sort=userName:asc` 順序對整資料集（psql 比對）、空 sort→id desc 等同現況、`?sort=password:asc`（非白名單欄）/`?sort=userRoles:asc`（衍生欄、F8）/`:sideways`（非法方向）/重複欄→`code==2222`+wire msg `biz.common.invalidSort`
- [ ] T016 [US1] CDP acceptance（C-V-7.1-2、先 restart base-web）：user 欄頭點擊 3-state（▼降→▲升→取消）、list 重抓、第一列變；**在非第 1 頁時點欄頭 → pagination 跳回第 1 頁（FR-006/analyze F5）**

**Checkpoint**：單欄 server-side 排序在 user 頁可用（MVP）。

---

## Phase 4: User Story 2 — 多欄位排序 + 全頁套用 + 匯出 (P2)

**Goal**：點擊序＝優先序、7 頁全可排、審計匯出反映排序。

**Independent Test**：點欄 A 再 B → A 主 B 次；審計 `export=true&sort=...` CSV 列序依排序。

- [ ] T017 [P] [US2] wire `base-web/src/views/manage/role/index.vue` 可排序欄（roleName/roleCode/roleDesc/status）
- [ ] T018 [P] [US2] wire `base-web/src/views/manage/ip-rule/index.vue` 可排序欄（cidr/ruleType/order/description/createTime/updateTime）
- [ ] T019 [P] [US2] wire 3 審計表元件可排序欄（`views/manage/audit/modules/operation-log-table.vue`、`access-log-table.vue`、`login-attempt-table.vue`，data-model §3）
- [ ] T020 [P] [US2] wire `base-web/src/views/manage/policy-archive/modules/policy-archive-table.vue` 可排序欄（roleCode/target/archivedTime/createdTime/archivedBy/archiveReason；dimension 排除）
- [ ] T021 [US2] curl acceptance（C-V-3）：`?sort=status:asc,userName:desc` 主/次序正確；抽驗各頁端點 empty→預設等同現況（C-V-4 擴及 7 端點）
- [ ] T022 [US2] 匯出反映排序（C-V-6）：3 審計頁 `?export=true&sort=...` CSV 列序依排序（共用 facade、應自動；驗證）
- [ ] T023 [US2] CDP 多欄 acceptance（C-V-7.3）：user + 一審計頁實點多欄、驗 DOM 主/次列序；**順手斷言多欄 header 無優先序號碼 badge（FR-014、框架保證、analyze F9）**

**Checkpoint**：7 頁全可排、多欄點擊序、匯出反映。

---

## Phase 5: User Story 3 — 一鍵清除全部排序 (P3)

**Goal**：工具列一鍵清除、回預設序。

**Independent Test**：多欄排序後按「清除排序」→ 回預設、指示消失。

- [ ] T024 [US3] `useTableSort` 加 `clearAll()`（`tableRef.clearSorter()` → `@update:sorter(null)` → 清狀態+清儲存+重抓）於 `src/hooks/common/use-table-sort.ts`
- [ ] T025 [US3] 掛「清除排序」鈡（label `common.clearSort`、綁 `clearAll`；抽共用元件 `src/components/.../sort-clear-button.vue` 避重複）—— **逐頁掛點（analyze F1：僅 3 頁有 `TableHeaderOperation`）**：user/role/ip-rule 用 `TableHeaderOperation` 的 `#suffix` slot；**3 審計表（operation/access/login-attempt-table.vue）+ policy-archive-table.vue 用各自既有 `NSpace` 工具列 inline 加鈕**（無 `TableHeaderOperation`）。**不改 `table-header-operation.vue` 元件本體**；每改一處記 file:line + `rev3-inline` 標記（§III）
- [ ] T026 [US3] CDP acceptance（C-V-7.4，先 restart base-web）：清除鈕 label 非 raw key（`PAGE_HAS_RAWKEY:false`）、按下全清回預設

**Checkpoint**：一鍵清除可用。

---

## Phase 6: User Story 4 — 排序跨頁保留 (P3)

**Goal**：離開頁面再回來、排序還原。

**Independent Test**：排序 → 導航離開 → 返回 → 排序+箭頭還原。

- [ ] T027 [US4] `useTableSort` 加持久化於 `src/hooks/common/use-table-sort.ts`：composable 收一個 `storageKey: string`（caller 給）、`localStg` 存 `Record<storageKey, sort字串>`（`StorageType.Local` 註冊新 key 於 `src/typings/storage.d.ts`，仿 tab store `cacheTabs`）+ mount 還原（解析→受控 sortOrder + searchParams.sort）+ **防禦性丟棄非白名單/不存在欄（FR-015）**。⚠️ **storageKey 非僅 route.name（analyze F3）**：多表共用單一 route 的頁（`/manage/audit`＝1 route 3 tab 表）須加 per-table 辨識（見 T028）
- [ ] T028 [US4] 各表傳 `storageKey` 給 composable：單表頁（user/role/ip-rule/policy-archive）= `route.name`；**`/manage/audit` 的 3 表各傳 `` `${route.name}:${tab}` ``（tab∈operation/access/login）避免共用 route.name 互相覆寫（analyze F3）**（user 頁 T014 已引入 useRoute；其餘頁補）
- [ ] T029 [US4] CDP acceptance（C-V-7.5）：排序 → navigate 離開 → 返回 → 資料順序+箭頭還原；**(a) FR-015/analyze F6**：手動注入含失效（非白名單）欄的 persisted sort → 返回 → 驗其餘有效排序生效且**無 error**、失效欄被丟棄；**(b) analyze F3**：`/manage/audit` 排序某 tab → 切另一 tab → 切回 → 各 tab 排序**獨立保留**（不互相污染）

**Checkpoint**：持久化可用。

---

## Phase 7: Polish & Cross-Cutting

- [ ] T030 [P] migration up→down→up（C-V-8）：m008 可逆、`\di idx_login_attempt_created_at` 驗最終存在
- [ ] T031 全量驗證（C-V-0/9）：容器內 force-touch + `cargo build -p server -p migration` + `cargo test -p server`（serial）零回歸 + `pnpm typecheck` 綠 + entity/endpoint lint 零回歸
- [ ] T032 vite stale-locale guard：所有 CDP 在地化斷言前 `restart base-web`、斷言 `common.clearSort`/`backend.*` 非 raw key
- [ ] T033 final holistic review（fresh-agent 冷讀）：FR-001~016 / SC-001~007 全覆蓋、wire 契約對齊（envelope/PageRes/2222 不變式）、Constitution 9/9、未指定 sort 逐列等同現況
- [ ] T034 收尾（`finishing-a-development-branch` 後）：MILESTONES/CHECKLIST/§6 marker 回填、merge `--no-ff` 回 rev3-admin-root（push/merge 需 user 同意）

---

## Dependencies & Execution Order

### Phase 相依
- Setup(T001) 無相依、可即起（與引擎平行）。
- Foundational(T002-T013) 阻擋所有 US；**後端 T002→T003→T004→T005→T006→T007→T008 序列**（同檔+rust serial），T009/T010/T012/T013 可與後端 [P]，T011 composable 須先於所有 US wiring。
- US1(T014-16) 依 Foundational。US2/US3/US4 依 Foundational + composable；US3 改 composable(clearAll)、US4 改 composable(persist)，故 US3/US4 對 composable 為序列、但與各頁 wiring 獨立。
- Polish 依所有 US。

### Story 獨立性
- US1（user 頁單欄）獨立可測＝MVP。
- US2（全頁+多欄+匯出）依引擎、不依 US1 之外。
- US3（清除）、US4（持久化）各 additive 於 composable、獨立可測。

### Parallel 機會
- T017-T020（4 頁 wiring，不同檔）可 [P]。
- T010/T012（typings/i18n，不同檔）可 [P]，但 T009 與 T012 皆動 `app.d.ts`/locale → 不互 [P]、序列。
- 後端 rust 即使邏輯獨立仍 serial（共用 target）。

---

## Parallel Example: US2 全頁 wiring

```
# 4 頁 view wiring 同時（不同檔、composable 已就緒）：
T017 role/index.vue 排序欄
T018 ip-rule/index.vue 排序欄
T019 3 審計 table 元件排序欄
T020 policy-archive-table.vue 排序欄
```

---

## Implementation Strategy

### MVP（US1）
1. Setup(T001) + Foundational(T002-T013) — 引擎就緒
2. US1(T014-16) — user 頁單欄排序 + 驗收
3. **STOP & VALIDATE**：user 頁獨立可用

### 增量交付
US1（MVP）→ US2（全頁+多欄+匯出）→ US3（清除）→ US4（持久化），每步獨立加值不破前。

### 執行單元建議（executing-plans 自定、供參）
- **U1 後端引擎**：T002-T009（一支 rust 單元、serial、含 migration T001 可併或獨立）
- **U2 前端引擎+MVP**：T010-T016（composable+typings+i18n+user 頁+US1 驗收）
- **U3 全頁+多欄+匯出**：T017-T023（US2）
- **U4 清除+持久化**：T024-T029（US3+US4，composable additive）
- **U5 polish**：T030-T033 + 收尾 T034
> 每單元邊界主線獨立 ground-truth（`git show --stat`+容器內 build/test+C-V live）+ bump submodule pin。

---

## Notes
- [P]=不同檔無相依；rust 即使 [P] 仍 serial。
- 測試：純函式 test-first（T002/T004 red→green）；wiring 由 C-V acceptance 覆蓋。
- 每執行單元邊界主線復核 + bump pin；**push/merge 留收尾、需 user 同意**。
- 可排序欄白名單權威＝data-model §3；wire 契約＝contracts/sort-wire-contract.md；驗收＝contracts/verification-commands.md。
- **§III fork-delta（analyze F10）**：每處 base-web inline 改動（MODAL-WIRING (f) 範圍）記 file:line + 改動內容 + upstream 衝突風險 + `rev3-inline` 標記（修改型保留原行註解、新增型圈界）。
