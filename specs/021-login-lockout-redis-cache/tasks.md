# Tasks: 登入鎖定快取層（021-login-lockout-redis-cache）

**Input**: Design docs from `specs/021-login-lockout-redis-cache/`（plan.md／spec.md／research.md／data-model.md／contracts/verification-commands.md／quickstart.md）
**Branch**: `021-login-lockout-redis-cache`
**Tests**: TDD requested（CLAUDE.md §3 + spec §7）→ 含測試任務（純函式 test-first；wiring/形狀類由 live 測 + C-V acceptance 覆蓋）。

## Format: `[ID] [P?] [Story] Description`
- **[P]**＝可平行（不同檔、無未完相依）。**rust 任務一律不標 [P]**：共用 cargo target、CLAUDE.md §3 全程 serial。本刀**全 rust、無 base-web** → **無 [P] 任務**。
- 路徑：rust-api worktree `rust-api/...`。

## Path Conventions（本刀）
- rust：`rust-api/server/src/handler/auth.rs`（login gate 分層）、`rust-api/server/src/redis.rs`（facade +incr/計數）。L2 既有 DB gate 與 `is_locked_out` 純函式、`model/facade/sys_login_attempt.rs` **不動**（真相層）。

## Execution notes（交 階段 2 superpowers:executing-plans + Workflow）
- rust build/test 在 rust-api 容器內 `docker exec`（host 無 cargo）；live `#[ignore]` 測帶 `DATABASE_URL=$(cat /run/secrets/database_url)` ＋ `REDIS_URL=$(cat /run/secrets/redis_url)` + `--test-threads=1`；改 `.rs` 後 force-touch 防 /mnt/d stale-mtime；rust 全程 serial。
- **★ 絕不 push/merge**（worktree commit 只 local，收尾才 finishing-a-development-branch）；執行單元邊界 bump submodule pin（§4.1）。
- 全程 fail-OPEN（沿 §I.7／019）；reuse 019 政策值（5/20/900）；**0 migration/crate/route/wire**；**有意識反轉 007 FR-004/SC-002 ＋ 019 FR-008**（鎖後不逐筆寫、收尾加 007/019 as-built 註記；★ 原誤標 019 FR-004、見 research D7）。

---

## Phase 1: Setup（前置）

- [ ] T001 確認 dev stack healthy（`docker compose -f docker-compose.yml -f docker-compose.dev.yml ps`、含 **redis-stack**）、Super 登入 0000；baseline：psql `SELECT count(*) FROM sys_login_attempt WHERE attempted_user_name LIKE 'zz021_%';`＝0、`redis-cli KEYS 'lockout:*'`＝空（C-V-0）

---

## Phase 2: Foundational（阻斷前置 — US1+US2 共用 infra：純函式決策 + redis facade）

- [ ] T002 [test-first] 純函式單元測 in `rust-api/server/src/handler/auth.rs`（`#[cfg(test)]`）：`lockout_keys(ip,name)`（組 `lockout:ip:{ip}`/`lockout:user:{name}`）／`tripped_keys(ip_fails,user_fails,ip,name)`（門檻 20/5、各維度 set 哪些 key、兩維皆觸發各 set）／`should_flush(flushed_exists)`（不存在才 true）；**★ key-string 一致性（G1）：斷言 `tripped_keys` 對同 `(ip,name)` 產生的 key 字串與 `lockout_keys` 完全相同（含 IPv6 渲染、防 L1-read≠L2-write 靜默失效）**；`is_locked_out` 不變（沿 019 既有測）（C-V-1）
- [ ] T003 實作純函式 `lockout_keys`/`tripped_keys`/`should_flush`（make T002 pass）in `rust-api/server/src/handler/auth.rs`：**★ `tripped_keys` 與 `lockout_keys` 的 key 字串必由共用 `ip_key(ip)`/`user_key(name)` helper 導出（保 L1-read==L2-write、G1、防 D-04-class 渲染分歧）**；**`tripped_keys` 門檻引用既有 `PER_IP_THRESHOLD(20)`/`PER_USER_THRESHOLD(5)` 常數、不硬編（G3、FR-010 政策值單一來源）**；不碰 IO；`is_locked_out`(:68) 不動
- [ ] T004 redis facade 加 `incr(key)`（INCR + 確保 TTL）/`take_suppressed(key)->i64`（GETDEL 讀+清、miss→0）+ lockout 語意薄包 `mark_locked(key,ttl)`/`is_locked(key)->bool`（薄封 set_ex/get）in `rust-api/server/src/redis.rs`；**全 fail-OPEN 鏡像既有範式**（:64-118、error 吞成降級值 + `tracing::warn!(key,error=%e,..)`）

---

## Phase 3: User Story 1 - 分散式攻擊下系統穩定（鎖後成本有界、0 DB 寫）（Priority: P1）🎯 MVP

**Goal**：login 起手加 L1 Redis 負快取；已鎖嘗試短路（拒 + ②b 不寫稽核 + 跳過 L2 DB），鎖後成本 O(1)；L2 達門檻時依觸發維度 set_ex（D2/D3 固定 TTL）。
**Independent Test**：5 fail→第6觸發鎖→後續 L1 短路；psql 該 user 行數不隨壓制成長（0 DB 寫）；per-user 鎖短路任意來源（`lockout:user` 存在、`lockout:ip` 不存）。

### Tests for User Story 1 ⚠️（live、in-crate `#[ignore]`+env-gate）
- [ ] T005 [US1] live 測 in `rust-api/server/src/handler/auth.rs`（`#[cfg(test)]#[ignore]`、需 `DATABASE_URL`+`REDIS_URL`）：對 throwaway `zz021_x` 5 fail→第6 L2 觸發鎖（set `lockout:user:zz021_x`、寫第6列）→ 後續 L1 短路（psql 行數**仍=6**＝0 DB 寫、②b/FR-004）+ **per-user 維度**短路（`lockout:user` 存在、`lockout:ip` 不存、FR-002；注入不同 `real_ip` 仍短路）＋**★ per-ip 維度變體（G1/FR-002）：同一 `real_ip` 跨多帳號（每帳號 <5）送 ≥20 fail → L2 set `lockout:ip:{ip}` → 同 IP 下一發任意帳號 L1 命中短路（行數不增）、證 per-ip 軌道亦接地且 L1-read key 命中 L2-write key**（C-V-2/3/8）

### Implementation for User Story 1（rust serial）
- [ ] T006 [US1] login gate **L1 短路** in `rust-api/server/src/handler/auth.rs`：`login`(:211) 起手、`since`(:226) 計算**之前** → **★ 落一行 greppable seam marker `// L0 trusted-ip bypass seam（FR-012、未實作、未來白名單插入點）` 於 gate 最頂端（G2/FR-012）** → `if let Some(h)=state.redis.as_ref().as_ref()`（fail-open：None 跳過退 L2）內查 `get(lockout:ip:{ip})`/`get(lockout:user:{name})`（key 字串用 T003 共用 helper）命中任一 → `return Err((None, AppError::Biz("auth.login.locked".into())))`（**②b：早 return、不到寫點 :256**）；miss → 續 L2（既有 :226-256 完全不動）
- [ ] T007 [US1] L2 **觸發 set_ex** in `rust-api/server/src/handler/auth.rs`：既有 `is_locked_out`(:245) 為 true 時，依 `tripped_keys`（`ip_fails>=20`→`lockout:ip:{ip}`／`user_fails>=5`→`lockout:user:{name}`）`set_ex(key,"1",900)`（**D2/D3 固定 TTL、不 refresh**）；L2 其餘（count/login_inner/write）不動
- [ ] T008 [US1] acceptance（curl/psql/redis-cli）：C-V-2（鎖後短路、行數不隨壓制成長）+ C-V-3（per-user 短路任意來源、`lockout:ip` 未設）+ **C-V-3b per-ip 軌道（G1）：跨帳號同 IP 達 20 → `RCLI EXISTS lockout:ip:<ip>`=1 → 同 IP 下發 L1 短路、行數不增** + C-V-8（鎖後 0 DB query 量測 / 行數不變 proxy）

**Checkpoint US1**：鎖後 O(1) 短路 + 0 DB 寫（MVP 達成、封住放大）；主線 bump rust-api submodule pin。

---

## Phase 4: User Story 2 - 鎖中稽核負擔有界、攻擊訊號保留（②c 節流麵包屑）（Priority: P2）

**Goal**：鎖中不灌稽核表（②b 已達），但保留「遭攻擊量級」鑑識訊號＝節流 ≤1/60s/key 的結構化 log（`suppressed=N`）→ loki。
**Independent Test**：鎖中持續壓制 → security.lockout log 出現、含 suppressed 計數、同窗多次只出 1 筆（節流）。

### Tests for User Story 2 ⚠️（live）
- [ ] T009 [US2] live 測 in `rust-api/server/src/handler/auth.rs`（`#[ignore]`）：鎖中多次壓制 → `incr(lockout:suppressed:{key})` 累計、`should_flush`（`flushed` key gate 60s）→ flush 出 `target=security.lockout` log 含 `suppressed=N`、**節流 ≤1/60s/key**（C-V-6）

### Implementation for User Story 2
- [ ] T010 [US2] L1 命中時 **②c 麵包屑** in `rust-api/server/src/handler/auth.rs`（T006 短路路徑內、return 前）：`incr(lockout:suppressed:{locked_key})` → `should_flush(get(lockout:flushed:{locked_key}).is_none())` 為真則 `take_suppressed` + `tracing::warn!(target:"security.lockout", locked_key, dimension, suppressed=n, "login lockout suppressing attempts")` + `set_ex(lockout:flushed:{locked_key},"1",60)`（**distinct-source HLL 可選、不做 v1**；clarify Q1）
- [ ] T011 [US2] acceptance：C-V-6（節流麵包屑 ≤1/60s/key、`suppressed` 計數、loki/grafana 可查；具體 alert rule 配置遞延 ops、不在本刀驗收、clarify Q2）

**Checkpoint US2**：鑑識訊號保留 + 稽核表不被灌；主線 bump rust-api pin（或併 US1/US3 一次）。

---

## Phase 5: User Story 3 - 自動恢復、韌性降級、零回歸（Priority: P3）

**Goal**：固定 TTL 自癒（攻擊停 ≤900s 自動解鎖）、Redis-down 退 L2 DB gate（fail-open）、未鎖路徑與 019 完全一致（零回歸）。
**Independent Test**：(a) TTL≈900 命中不 refresh；(b) stop redis-stack → 鎖仍由 DB gate 執行；(c) 未鎖 0000/1000、稽核照寫、toast `auth.login.locked` 不變。

### Tests for User Story 3 ⚠️（live）
- [ ] T012 [US3] live 測 in `rust-api/server/src/handler/auth.rs`（`#[ignore]`）：**fail-open**（`state.redis=None`／Redis-down → L1 跳過、鎖由 L2 DB gate 正確執行、達門檻仍 2222）+ **TTL 不 refresh**（鎖後命中 N 次、`TTL lockout:user` 持續下降不回彈 900）（C-V-4/5）

### Implementation / Validation for User Story 3
- [ ] T013 [US3] 確認 **fail-open guard + 固定 TTL**（多為碼面/設計驗證、性質源自 T006/T007）in `rust-api/server/src/handler/auth.rs`：L1 整段在 `if let Some(h)=...` 內（None 直走 L2）；`set_ex lockout:*` 僅 L2 觸發時一次、L1 命中**不**再 set lockout:ip/user（只 incr suppressed）→ 確保不 refresh；grep 確認無命中即 refresh 的殘留
- [ ] T014 [US3] acceptance：C-V-4（TTL≈900 自癒、不 refresh；完整 900s 實時 defer、以 TTL+不refresh+②b不寫覆蓋）+ C-V-5（stop redis-stack → 鎖仍執行、Super 0000 不破；restart）+ C-V-7（零回歸：未鎖 0000/1000、稽核照寫、toast 不變、login_inner 6 路徑不動）

---

## Phase 6: Polish & Cross-Cutting

- [ ] T015 lint + prod gate（rust 容器 + docker）：`cargo test -p server --test entity_access_lint` 綠 / `--test endpoint_coverage_lint` 綠（無新 route）/ `docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（無新 crate、驗 multi-stage 無破口）（C-V-9）
- [x] T016 **007 FR-004/SC-002 ＋ 019 FR-008 as-built 勘誤**（收尾刀時）：於 `specs/007-audit-overlay/spec.md` FR-004（exactly-one per terminal result）/SC-002 與 `specs/019-login-lockout/spec.md` FR-008（gated 列 sticky 審計痕跡）加 **forward-pointing as-built 註記**（保留原文、指 021 鎖後改 ②c 節流摘要）；權威更正登 DECISIONS §1（比照 020 對 011 data-model 的處理）。**★ 歸屬勘誤**：原誤標「019 FR-004」、實則 019 FR-004＝真實 IP 防偽（021 未碰）、exactly-one 之擁有者為 007 FR-004（3 獨立 reviewer grep 實證、見 research D7）
- [ ] T017 清理 throwaway：psql `DELETE FROM sys_login_attempt WHERE attempted_user_name LIKE 'zz021_%';` + redis `DEL lockout:*`（zz021 相關）→ 回 baseline（無殘留列/key）
- [ ] T018 final holistic review：spec FR-001~012 / SC-001~007 逐項對照 + Constitution 9/9 複核 + 全 rust 測 run（零回歸）+ §I.7 §4.3 非權威快取/fail-OPEN 一致性確認
- [ ] T019 收尾準備（交 finishing-a-development-branch）：擬多段式 commit + 進度回填清單（MILESTONES append、CHECKLIST 收尾、DECISIONS §1 登拍板〔本刀 + 007 FR-004/SC-002＋019 FR-008 反轉（★ 原誤標 019 FR-004）〕、§6 marker、019 §4.2「per-IP 白名單」緊接 future 提醒）—— **push/merge 需 user 同意**

---

## Dependencies & Story Completion Order

- **Setup（T001）** → **Foundational（T002-T004）** → **US1（T005-T008）** → **US2（T009-T011）** → **US3（T012-T014）** → **Polish（T015-T019）**。
- Foundational 純函式（T003）+ redis facade（T004）阻斷 US1（gate）與 US2（②c）。
- US1 的 L1 短路（T006）為 US2 ②c（T010、寫在 L1 短路路徑內）的前提；US1 的 L2 set_ex（T007）為 US3 TTL/自癒（T012-T014）的前提。
- rust 全程 serial（T002-T015 共用 cargo target）。

## Parallel opportunities
- **無**（全 rust、共用 target、§3 serial；無 base-web）。

## Implementation Strategy（MVP first）
- **MVP＝US1（Phase 1-3）**：login gate L1 短路 + ②b 不寫 + L2 set_ex —— 獨立可交付、封住 DB 讀取/寫入放大核心。
- 增量：US2（②c 鑑識麵包屑）→ US3（自癒/fail-open/零回歸驗證）。
- 每 phase checkpoint：主線復核 + load-bearing 自驗（容器 cargo build/全 live 測 + acceptance）+ bump submodule pin（§4.1）。

## 執行單元對映（交 階段 2 Workflow 驅動）
- **U1 rust**＝T002-T007, T009-T010, T012-T013, T015（Foundational + US1-impl + US2-impl + US3-impl/驗 + gate）serial 一支（T008/T011/T014 acceptance＝主線、不在單元）。
- acceptance（T008/T011/T014）+ Polish（T016-T019）＝主線邊界 checkpoint。
- **無 base-web 單元**（本刀全 rust）。
