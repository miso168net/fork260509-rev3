---
description: "Task list for 017-audit-center-enhancement"
---

# Tasks: Audit Center Enhancement

**Input**: Design documents from `specs/017-audit-center-enhancement/`（[plan.md](plan.md) / [spec.md](spec.md) / [research.md](research.md) / [data-model.md](data-model.md) / [contracts/](contracts/)）

**Tests**: 含——純函式 test-first（CLAUDE.md §3 TDD）；wiring/形狀類由 C-V acceptance（curl/psql/CDP）覆蓋。

**Organization**: 依 spec User Stories（US1 P1 / US2 P2 / US3 P3）分相。

## Format: `[ID] [P?] [Story] Description（含 file path）`

- **[P]**: 可平行（不同檔、無相依）。**★ rust 全程 serial**（共用 target/crate）→ rust task 間【不】標 [P]；[P] 僅用於 base-web 跨檔或 base-web↔rust 之間。
- **[Story]**: US1/US2/US3。

## ★ 執行紀律（rev3、烤進每執行單元）

- 實作起手＝**`superpowers:executing-plans`**（**非** `/speckit-implement`）；編排用 **Workflow**（每執行單元一支：implementer→spec-compliance review→fix loop→code-quality review）。
- rust build/test 在 **rust-api 容器內** `docker exec`（force-touch 防 /mnt/d stale-mtime；live `--ignored --test-threads=1` 帶 `DATABASE_URL`）；base-web commit `--no-verify`、自驗 `pnpm typecheck`。
- **逐執行單元兩段式 commit**（worktree commit→outer bump pin、S9）；**★ 絕不 push/merge**（留 finishing-a-development-branch、需 user 同意）。
- **★ 相依**：US2 的 op-log export rolesBefore/After 欄（T010）抽自 US1（C-4）enrich 的 payload → **US1 先於 T010**（或 T010 容忍 payload 無 roles 顯空）。
- live op-log 斷言用**自身 trace_id + entity_table 雙欄守門**（共享 seed entity_id append-only、勿絕對列數）。

---

## Phase 1: Setup

- [ ] T001 確認在 `017-audit-center-enhancement` branch + dev stack healthy（`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`）——live/curl/CDP 驗收前置。無新專案 init（既有 codebase）。

---

## Phase 2: Foundational (Blocking Prerequisites)

**無 cross-story foundational blocker**——三子功能各自獨立（唯 US2 op-log roles 欄 soft-depends US1、見執行紀律）。直接進 User Stories。

---

## Phase 3: User Story 1 - 角色變更可事後追溯 (Priority: P1) 🎯 MVP

**Goal**: op-log payload 注入角色集 delta（create/update/soft_delete 三寫端），使「誰把 user 角色 A→B」可由單筆操作異動紀錄追溯。

**Independent Test**: 對 user 改/建/刪角色後，psql 查該 trace_id 的 sys_operation_log，payload_before/after 含正確 roles（見 quickstart US1 / C-V-3）。

### Tests (test-first)

- [ ] T002 [US1] `with_roles` 純函式單元測（插 "roles"、**排序**、空→`[]`、非 Object passthrough）in `rust-api/server/src/model/audit.rs`（`#[cfg(test)]`、先紅）

### Implementation

- [ ] T003 [US1] 實作 `pub fn with_roles(v: Value, roles: &[String]) -> Value`（roles 排序後入 Array、空→`[]`）in `rust-api/server/src/model/audit.rs`（綠 T002）
- [ ] T004 [US1] create facade：`payload_after = Some(with_roles(after.audit_json(), role_codes))`（before 維持 None）in `rust-api/server/src/model/facade/sys_user.rs:279-289`
- [ ] T005 [US1] update facade：replace_roles 之【前】`let roles_before = sys_user_role::roles_of_user(&txn, id).await?;`→`payload_before = Some(with_roles(before.audit_json(), &roles_before))`、`payload_after = Some(with_roles(after.audit_json(), role_codes))` in `rust-api/server/src/model/facade/sys_user.rs:300-337`
- [ ] T006 [US1] soft_delete facade（del+batch 共用）：刪前 `roles_of_user(&txn,id)`→`payload_before = Some(with_roles(before.audit_json(), &roles_before))`、`payload_after = Some(with_roles(after.audit_json(), &[]))` in `rust-api/server/src/model/facade/sys_user.rs:51-87`
- [ ] T007 [US1] live smoke：add/update/delete user 經真 server 帶自身 trace_id、psql 驗 op-log payload roles delta（4 scenario）in `rust-api/server/src/model/facade/sys_user.rs`（`#[ignore]`+`DATABASE_URL`+`--test-threads=1`、trace_id 隔離）— C-V-3

**Checkpoint**: US1 獨立可驗（op-log roles delta 可查）。

---

## Phase 4: User Story 2 - 審計紀錄可匯出離線分析/留存 (Priority: P2)

**Goal**: 三審計分頁各可匯出 CSV（既有讀端點 export query-param 變體、當前篩選、cap 1萬、UTF-8 BOM）；op-log CSV 含專屬 rolesBefore/After 欄。

**Independent Test**: 任一分頁套篩選→按匯出→下載 CSV＝當前篩選結果、中文不亂碼、op-log 含 rolesBefore/After（quickstart US2 / C-V-2/C-V-4）。

### Tests (test-first)

- [ ] T008 [US2] CSV helpers 純測：`csv_escape_field`（逗號/雙引號/換行）、`records_to_csv`（BOM+穩定英文表頭）、`parse_export`（"true"/"1"→true、其餘/空→false）in `rust-api/server/src/handler/system_manage.rs`（`#[cfg(test)]`、先紅）

### Implementation (rust)

- [ ] T009 [US2] 實作 CSV helpers + `const CSV_EXPORT_CAP: u64 = 10000` in `rust-api/server/src/handler/system_manage.rs`（綠 T008）
- [ ] T010 [US2] `get_operation_log`：Query 加 `export: Option<String>`；export 分支〔`facade::list(db,0,CSV_EXPORT_CAP,filter)`★繞過 normalize_size、組 *Item、**rolesBefore/After 自 payload["roles"] 抽（依 US1；payload None→空）**、payloadBefore/After JSON 字串入格、`Res::ok(csv)`〕in `rust-api/server/src/handler/system_manage.rs:242,1753`
- [ ] T011 [US2] `get_access_log`：Query 加 export + export 分支（同範式、無 roles 欄）in `rust-api/server/src/handler/system_manage.rs:262,1812`
- [ ] T012 [US2] `get_login_attempt`：Query 加 export + export 分支 in `rust-api/server/src/handler/system_manage.rs:282,1869`

### Implementation (base-web)

- [ ] T013 [P] [US2] `downloadCsv(csv, filename)` util（`new Blob([csv],{type:'text/csv;charset=utf-8'})`+a[download]、檔名 `<table>_<ts>.csv`）in `base-web/src/utils/download.ts`（新檔）
- [ ] T014 [US2] 3 export wrapper（`fetchExportOperationLog/AccessLog/LoginAttempt`、`request<string>`、`pruneNullParams({...params,export:'true'})`）in `base-web/src/service/api/rev3-system-manage.ts`
- [ ] T015 [US2] i18n Schema（**先**）：audit 區加匯出鈕/截斷 msg key in `base-web/src/typings/app.d.ts`（audit 區）
- [ ] T016 [US2] i18n locale（**後**、同 commit）：zh-cn/en-us audit 區加對應 in `base-web/src/locales/langs/zh-cn.ts` + `en-us.ts`
- [ ] T017 [P] [US2] operation-log-table.vue：匯出鈕 + onExport（呼 export wrapper→downloadCsv）+ 截斷 toast（`pagination.itemCount > CAP`）in `base-web/src/views/manage/audit/modules/operation-log-table.vue`
- [ ] T018 [US2] access-log-table.vue：匯出鈕 + onExport + 截斷 toast in `base-web/src/views/manage/audit/modules/access-log-table.vue`（★ 同檔 US3 T028、序列）
- [ ] T019 [P] [US2] login-attempt-table.vue：匯出鈕 + onExport + 截斷 toast in `base-web/src/views/manage/audit/modules/login-attempt-table.vue`

### Acceptance

- [ ] T020 [US2] curl：export Super 200 回 CSV／非 Super 403／三表（C-V-2）＋ CDP：三 tab 匯出下載（檔名+BOM+內容、截斷 toast）（C-V-4）

**Checkpoint**: US1+US2 各自獨立可驗。

---

## Phase 5: User Story 3 - HTTP 狀態類別快速篩 (Priority: P3)

**Goal**: access-log 加 2xx/4xx/5xx 類別 quick-filter（與既有單值精確並存＝AND）。

**Independent Test**: API 存取分頁選「4xx」→ 列表僅 400–499；清除還原（quickstart US3 / C-V-2/C-V-4）。

### Tests (test-first)

- [ ] T021 [US3] `parse_http_status_class` 純測（2xx→[200,300)/4xx/5xx 半開區間；空/None→None；**無法識別非空→None〔不 Err 2222〕**）in `rust-api/server/src/handler/system_manage.rs`（`#[cfg(test)]`、先紅）

### Implementation (rust)

- [ ] T022 [US3] 實作 `fn parse_http_status_class(Option<&str>)->Result<Option<(i32,i32)>,AppError>` in `rust-api/server/src/handler/system_manage.rs:475`（綠 T021）
- [ ] T023 [US3] AccessLogFilter 加 `http_status_class: Option<(i32,i32)>` + list 加範圍 `apply_if`（`HttpStatus.gte(lo).and(lt(hi))`、與既有 eq 並存 AND）in `rust-api/server/src/model/facade/sys_access_log.rs:84,102`
- [ ] T024 [US3] AccessLogQuery 加 `http_status_class: Option<String>`（wire `httpStatusClass`）+ get_access_log 組 filter（`parse_http_status_class(q.http_status_class.as_deref())?`）in `rust-api/server/src/handler/system_manage.rs:262,1825`

### Implementation (base-web)

- [ ] T025 [P] [US3] AccessLogSearchParams 加 `httpStatusClass: string`（'2xx'|'4xx'|'5xx'）in `base-web/src/typings/api/rev3-system-manage.d.ts:215`
- [ ] T026 [US3] i18n Schema（**先**）：audit 加 statusClass label/選項 key in `base-web/src/typings/app.d.ts:918`（★ 同檔 T015、序列）
- [ ] T027 [US3] i18n locale（**後**、同 commit）：zh-cn/en-us audit 加對應 in `base-web/src/locales/langs/zh-cn.ts` + `en-us.ts`（★ 同檔 T016、序列）
- [ ] T028 [US3] access-log-table.vue：class NSelect（全部/2xx/4xx/5xx、NSelect 已 import）+ searchParams `httpStatusClass:null` + reset 重置 in `base-web/src/views/manage/audit/modules/access-log-table.vue:31,134,173`（★ 同檔 T018、序列）

### Acceptance

- [ ] T029 [US3] curl：class 收窄／空 param 守門／無法識別略過（C-V-2）＋ CDP：UI 選類別收窄、清除還原（C-V-4）

**Checkpoint**: 三 US 全獨立可驗。

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T030 [P] lint：`endpoint_coverage_lint`（端點數**不變**＝零新端點佐證）+ `entity_access_lint`（rust-api 容器 `cargo test --test`）— C-V-0
- [ ] T031 build/typecheck：`cargo build -p server`（force-touch）+ base-web `pnpm typecheck` — C-V-0
- [ ] T032 regression：zero-migration（`git diff <base>..HEAD -- migration/` 空）+ prod target image build（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`）+ 既有 audit unit 測零回歸 — C-V-5
- [ ] T033 holistic review（fresh-agent 冷讀）：spec SC-001~008 覆蓋、Constitution 9/9（**item 2/7 複核**：audit 頁 rev3 自建 enhancement + page.manage UI i18n、非 frozen-upstream 違規）、跨子功能接縫、wire 3 端對齊無 type-lie

---

## Dependencies & Execution Order

### Phase
- Setup（P1）→ User Stories（P3-5、priority 序 US1→US2→US3）→ Polish（P6）。Phase 2 Foundational 空。
- **★ US1 先於 US2 T010**（op-log export roles 欄抽自 US1 enrich payload）；US2/US3 其餘互不相依。

### Within story
- 純函式 test-first（T002/T008/T021 先紅）→ impl 綠。
- rust：facade → handler；rust 全程 serial（無 [P]）。
- base-web：util/typing/wrapper → view；i18n **Schema 先 locale 後**（同 commit、base-web-i18n-schema gotcha）。

### 同檔序列（非 [P]）
- `access-log-table.vue`：T018（US2 匯出鈕）↔ T028（US3 class NSelect）——同檔、序列。
- `app.d.ts`：T015（US2 i18n）↔ T026（US3 i18n）；`zh-cn/en-us.ts`：T016 ↔ T027——同檔、序列（建議同一執行單元一次補齊兩 US 的 audit i18n）。

### Parallel opportunities（[P]）
- T013（downloadCsv util、新檔）／T025（typing 加欄）／T017、T019（不同 table 檔）／T030（lint）可與其它非同檔 task 平行；但 **rust 全程 serial**、base-web 同檔序列。

---

## Implementation Strategy

### MVP（US1 only）
Setup → US1（C-4 op-log roles delta）→ C-V-3 驗 → 即交付「角色變更可追溯」價值（資安問責盲點關閉）。

### Incremental
US1（MVP）→ US2（匯出）→ US3（class filter）→ Polish。每 US 獨立可測、不破前者。

### Workflow 編排建議（執行單元）
1. **EU1（US1 rust）**：T002-T007（with_roles + 三 facade + live smoke）→ 兩段式 commit + bump rust pin。
2. **EU2（US2 rust）**：T008-T012（CSV helpers + 三 handler export 分支）→ commit + bump pin。
3. **EU3（US2 base-web）**：T013-T020（util/wrapper/i18n/三表鈕 + acceptance）→ commit + bump base-web pin。
4. **EU4（US3 rust+base-web）**：T021-T029（class filter 三端 + acceptance；base-web 同檔 access-log-table.vue 與 EU3 T018 協調）→ commit + bump pins。
5. **EU5（Polish）**：T030-T033（lint/build/regression/holistic）。
（執行單元邊界＝可審 + 主線 git/test 自驗 + bump pin；rust serial。）

## Notes
- [P]＝不同檔無相依；rust 全程 serial。
- live op-log 斷言 trace_id 隔離（非絕對列數）。
- 收尾＝`superpowers:finishing-a-development-branch`→多段 commit→`merge --no-ff` 回 rev3-admin-root（push/merge 需 user 同意）。
