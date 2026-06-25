---
description: "Task list for 019-login-lockout"
---

# Tasks: 登入鎖定（login-lockout）

**Input**: Design documents from `/specs/019-login-lockout/`

**Prerequisites**: [plan.md](./plan.md)（必）, [spec.md](./spec.md)（US 來源）, [research.md](./research.md), [data-model.md](./data-model.md), [contracts/verification-commands.md](./contracts/verification-commands.md)

**Tests**: 本 feature **要 TDD**（CLAUDE.md §3 + spec §7）：純函式 `is_locked_out` test-first（red→green）；count/gate 之 wiring 由 in-crate `#[ignore]` live smoke ＋ C-V acceptance 覆蓋（無新純函式單元測）。

**Organization**: 依 user story 分相。**★ 本 gate 為 cohesive**：Foundational 交付可測 primitives（兩 count + `is_locked_out`）；US1 把 primitives wire 成 live gate（per-user 端到端＝MVP），同一 gate 的 `is_locked_out` 已 OR 兩維度 → **per-ip(US2)/恢復·fail-OPEN(US3) 行為隨 US1 gate 上線即生效**，US2/US3 phase 為**獨立驗證切片**（非新核心碼）。

## Format: `[ID] [P?] [Story] Description`
- **[P]**: 可平行（不同檔、無相依）。★ **rust 標 [P] 為邏輯性**——rust build/test 一律 **serial**（共用 target，CLAUDE.md §8.2）、不平行 cargo。
- **[Story]**: US1/US2/US3（對映 spec.md user story）。

## Path Conventions
web 結構（plan.md）：rust-api backend `rust-api/server/src/`、base-web frontend `base-web/src/`。

---

## Phase 1: Setup

**Purpose**: act-on-code 接地 + 環境基線。

- [ ] T001 [P] act-on-code 再接地：核對 login/login_inner/單一寫點 file:line 仍符 research.md（行號會漂），**★ 確認寫端 `IpAddr→IpNetwork` 轉換（D-04）並記下確切轉換**供 count 端鏡像 — `rust-api/server/src/handler/auth.rs` + `rust-api/server/src/model/facade/sys_login_attempt.rs`
- [ ] T002 [P] dev stack 基線綠：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`、rust-api `/health` 200、`cargo test -p server` 既有綠、base-web `pnpm typecheck` 綠 — 容器內 `docker exec`

---

## Phase 2: Foundational (Blocking — 可測 primitives)

**⚠️ CRITICAL**: 本 phase 完成前 US 不能開工。

- [ ] T003 Facade：append `count_failed_by_user_since(conn, user: &str, since)` ＋ `count_failed_by_ip_since(conn, real_ip: IpNetwork, since)`，各 `WHERE <key>=? AND success=false AND created_at>=?` `.count(conn)`；IpNetwork 用 T001 確認之同款轉換、走既有 `idx_login_attempt_{user,ip}_time` — `rust-api/server/src/model/facade/sys_login_attempt.rs`
- [ ] T004 Test-first（RED）：`is_locked_out` 單元測（per-user 邊界 4/5/6、per-ip 邊界 19/20/21、OR 語意〔任一達即鎖〕、both=0 未鎖）＋ 4 const（`PER_USER_THRESHOLD=5`/`PER_USER_WINDOW_SECS=900`/`PER_IP_THRESHOLD=20`/`PER_IP_WINDOW_SECS=900`）＋ stub `fn is_locked_out(ip_fails:i64,user_fails:i64)->bool{false}` — `rust-api/server/src/handler/auth.rs`（`#[cfg(test)]`）
- [ ] T005 Implement `is_locked_out` 本體 `ip_fails>=PER_IP_THRESHOLD || user_fails>=PER_USER_THRESHOLD` → T004 測 GREEN — `rust-api/server/src/handler/auth.rs`

**Checkpoint**: 兩 count + `is_locked_out` 可測就緒（純函式測綠）。

---

## Phase 3: User Story 1 - 帳號層暴力破解防護（per-user 鎖） (Priority: P1) 🎯 MVP

**Goal**: 對某帳號連續失敗達 5 → 後續登入擋下、回在地化「登入失敗次數過多，請稍後再試」。

**Independent Test**: 對拋棄式帳號 curl 5 次失敗 → 第 6 次（即使帶任意密碼）2222；browser 跳在地化 toast；換帳號同時不受影響。

### Implementation for User Story 1

- [ ] T006 [US1] Gate 插點：handler 在呼叫 `login_inner` **前** 算 `since=(Utc::now()-900s).into()`、`ip_fails/user_fails = count_*.unwrap_or(0)`〔fail-OPEN/D-07〕、`is_locked_out`→短路 `r=Err((None, AppError::Biz("auth.login.locked".into())))`（跳過 login_inner）、**匯流既有單一寫點(196-212)**、**login_inner 簽名/6 路徑不動** — `rust-api/server/src/handler/auth.rs`
- [ ] T007 [US1] In-crate `#[ignore]` live smoke（DB-gated、`--test-threads=1`、拋棄式帳號）：per-user 鎖 after 5 fails ＋ 隔離（換帳號不鎖）＋ gated 列寫入（success=false/operator=None/ctx 四欄照填、FR-008） — `rust-api/server/src/handler/auth.rs`（`#[cfg(test)]`）
- [ ] T008 [P] [US1] base-web i18n Schema：`App.I18n.Schema.backend.auth.login` 加 `locked: string`（★ **先 Schema**、`rev3-inline` 標記） — `base-web/src/typings/app.d.ts`
- [ ] T009 [US1] base-web locale：加 `backend.auth.login.locked`（zh-cn「登录失败次数过多，请稍后再试」/ en-us「Too many failed login attempts. Please try again later.」、`rev3-inline`） — `base-web/src/locales/langs/zh-cn.ts` + `base-web/src/locales/langs/en-us.ts`（依 T008、同 commit）
- [ ] T010 [US1] Acceptance C-V-3 + C-V-7：curl 5 fails→6th 2222 ＋ psql 驗 gated 列；CDP 驗鎖中在地化 toast（curl≠modal） — 依 `specs/019-login-lockout/contracts/verification-commands.md`

**Checkpoint**: US1 per-user 鎖 end-to-end 可獨立驗（MVP；此時 gate 已上線，per-ip/恢復/fail-OPEN 行為亦生效，待 US2/US3 驗證）。

---

## Phase 4: User Story 2 - 來源層暴力破解防護（per-ip 鎖） (Priority: P2)

**Goal**: 單來源跨多帳號失敗達 20 → 後續登入擋下（封換帳號規避 per-user 的橫掃）。

**Independent Test**: 同來源對 ≥20 個拋棄式帳號各 1 次失敗 → 第 21 次任一帳號 2222；換來源不受影響。

### Implementation for User Story 2

- [ ] T011 [US2] In-crate `#[ignore]` live smoke（**短窗 const override** 免鎖測試 IP 15 分、`--test-threads=1`）：per-ip 鎖 after 20 跨帳號 fails ＋ 來源隔離（另一 real_ip 不受影響） — `rust-api/server/src/handler/auth.rs`（`#[cfg(test)]`）
- [ ] T012 [US2] Acceptance C-V-4 + C-V-5：curl 短窗 per-ip 鎖；`EXPLAIN` 驗 count 走 `idx_login_attempt_ip_time` / `idx_login_attempt_user_time`（非 Seq Scan） — 依 `contracts/verification-commands.md`

**Checkpoint**: US1+US2 皆可獨立驗。

---

## Phase 5: User Story 3 - 合法使用者不受傷害（自動解鎖／非枚舉／不誤殺） (Priority: P3)

**Goal**: 滑動窗自動解鎖（免人工）、不存在帳號鎖法/訊息一致（防枚舉）、count 故障不擋合法登入（fail-OPEN）。

**Independent Test**: 失敗滑出 15 分窗→自動恢復；對不存在帳號連續失敗→一樣鎖/一樣 2222 訊息；count 不可用時合法登入照常。

### Implementation for User Story 3

- [ ] T013 [US3] In-crate `#[ignore]` live smoke（短窗、`--test-threads=1`）：滑動窗恢復（寫 `created_at` 窗外的舊失敗→count 不計→未鎖、不等 15 分）＋ sticky（gated 列計入→持續攻擊不解）＋ fail-OPEN（count 注入 DbErr→`unwrap_or(0)`→未鎖、不擋登入） — `rust-api/server/src/handler/auth.rs`（`#[cfg(test)]`）
- [ ] T014 [US3] Acceptance 防枚舉（FR-011/015）：以**拋棄式不存在帳號**連續失敗達門檻 → 一樣回 2222/一樣訊息、與真實帳號回應除存在性外無從區分；psql 驗不存在帳號亦寫 success=false 列且計入 — 依 `contracts/verification-commands.md`（C-V-3 路徑變體）

**Checkpoint**: 三 US 皆獨立功能/可驗。

---

## Phase 6: Polish & Cross-Cutting

- [ ] T015 [P] Lint C-V-2：`entity_access_lint`（count 走 facade、handler 零 path-root `entity::sys_login_attempt`）＋ `endpoint_coverage_lint`（無新 route、registered==as-built 不變） — 容器內 `cargo test -p server --test entity_access_lint --test endpoint_coverage_lint`
- [ ] T016 [P] Prod target image build C-V-8：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`（0 新 crate、§3 紀律保險防 dev bind-mount 遮蓋）
- [ ] T017 零回歸 C-V-9：`cargo test -p server -- --test-threads=1` 全綠（login 6 路徑/13 碼不破）＋ base-web `pnpm typecheck`（Schema 對齊）＋ `/health` 200 ＋ Super 正常 login → 0000（★ 別在 per-ip 測污染的 IP/窗上跑） — 容器內 + curl
- [ ] T018 Final holistic review（fresh-agent 冷讀 spec/plan/constitution、只讀）：3 US / 15 FR / 7 SC 全覆蓋、13 碼矩陣不變、Constitution 9/9、cross-unit 接縫一致 — 階段 2 收尾 gate（`finishing-a-development-branch` 前）

---

## Dependencies & Execution Order

### Phase Dependencies
- **Setup(P1)**：無相依、可即起。
- **Foundational(P2)**：依 Setup；**BLOCK 所有 US**（gate primitives）。
- **US(P3+)**：皆依 Foundational。**US1 的 gate 插點(T006) 一旦上線，US2/US3 的後端行為即生效**（同一 `is_locked_out` OR 兩維度、滑動窗/fail-OPEN 內生）→ US2/US3 為獨立**驗證**切片、無新核心碼。
- **Polish(P6)**：依所有 US 完成。

### User Story Dependencies
- **US1(P1)**：依 Foundational；MVP。含 gate wiring（T006）＝後續 US 行為的載體。
- **US2(P2)**：依 Foundational + T006 gate；驗證 per-ip 切片（+短窗 live、EXPLAIN）。
- **US3(P3)**：依 Foundational + T006 gate；驗證恢復/sticky/fail-OPEN/防枚舉切片。

### Within Each Story
- 純函式測（T004）FAIL 先於實作（T005）。
- Foundational primitives 先於 US1 gate wiring。
- gate wiring（T006）先於各 live smoke / acceptance。
- US1 i18n：★ Schema（T008）先於 locale（T009）、同 commit（否則 dict typecheck red）。

### Parallel Opportunities
- T001 ‖ T002（Setup）。
- T008（base-web Schema、U2）可與 rust 工作（T006/T007）平行（不同子系統）。
- T015 ‖ T016（lint ‖ prod build）。
- ★ 但 **rust build/test 一律 serial**（共用 target）；US 間「平行」僅指 base-web(U2) vs rust(U1) 跨子系統，rust 內部 task 仍序跑 cargo。

---

## Parallel Example: 跨執行單元（U1 rust ↔ U2 base-web）

```text
# US1 內，base-web i18n(U2) 與 rust gate(U1) 可平行推進：
Task T008: base-web Schema 加 backend.auth.login.locked（base-web/src/typings/app.d.ts）
Task T006/T007: rust gate 插點 + live smoke（rust-api/server/src/handler/auth.rs；rust 內部 serial）
```

---

## Implementation Strategy

### MVP First (US1)
1. Phase 1 Setup → 2. Phase 2 Foundational（CRITICAL）→ 3. Phase 3 US1 → 4. **STOP & VALIDATE**：per-user 鎖 end-to-end（C-V-3/C-V-7）→ MVP 可示範。

### Incremental Delivery
Setup+Foundational → US1（MVP：per-user 鎖+在地化）→ US2（驗 per-ip+索引）→ US3（驗恢復/防枚舉/fail-OPEN）→ Polish（lint/prod-build/零回歸/holistic review）。

### 階段 2 執行單元對映（CLAUDE.md §3 `executing-plans` 重組用）
本 tasks 之 rust 部（T003~T007,T011,T013,T014 + T001/T015~T017）≈ **U1 rust gate**；base-web 部（T008/T009）≈ **U2 base-web i18n**。實作者依實際相依/獨立可審邊界重編執行單元、每單元邊界 bump submodule pin。

---

## Notes
- [P]=不同檔/無相依；rust [P] 為邏輯性（cargo 仍 serial）。
- 每 task commit（base-web `--no-verify`；rust 容器內 build/test）；★ **絕不 push/merge until `finishing-a-development-branch`**（不排進本 tasks）。
- 測試隔離：per-user 用拋棄式帳號、per-ip 用短窗 override，**勿鎖 seed Super/Admin/User**（污染下游 live smoke）。
- gated 列、fail-OPEN、滑動窗皆無新狀態儲存（0 schema/migration）；防枚舉靠既有「查無帳號亦寫 1000 失敗列」+ count 含之。
