# Tasks: Auth/Token/Session 合刀

**Branch**: `014-auth-token-session` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

**Input**: spec.md（5 User Stories）/ plan.md（7 實作單元 D1–D7）/ data-model.md / contracts/verification-commands.md（C-V-0~10）/ research.md（§D 接地+決策）

## Format: `[ID] [P?] [Story] Description with file path`
- **[P]**：不同檔、無未完成相依、可平行（**但 rust 一律 serial 跑 cargo、共用 target**）。
- **[Story]**：US1~US5（Setup/Foundational/Polish 無 Story label）。
- 測試紀律：**純函式 test-first（TDD red→green）**＝`decide_rotation`/`resolve_policy`；wiring/形狀對映由 acceptance（C-V live/CDP/curl/psql/redis-cli/2-instance）覆蓋（constitution §I.4 / §8.8 DoD：§I.7 §4.1+§4.3 每 invariant 須有自動化驗證）。
- 紀律：rust 容器內 `docker exec` build/test、live `--test-threads=1`；base-web commit `--no-verify`；base-web 改循 §III `rev3-inline` fork-delta；Redis/DB 抖動全 **fail-OPEN**；★ 絕不 push/merge until finishing。

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 新增 async Redis crate（`rust-api/Cargo.toml` `[workspace.dependencies]` 加 `redis`〔或 `deadpool-redis`〕+ `server/Cargo.toml` `redis={workspace=true}` + `Cargo.lock` 釘版），容器內驗 1.86 編得過（C-V-0；★ 沿 toml/time MSRV 教訓、首選驗 build 綠者）
- [ ] T002 [P] 建 cleanup-job 新 workspace crate 骨架（`rust-api/cleanup-job/Cargo.toml` + `src/main.rs` stub + `rust-api/Cargo.toml` `members` 加 `"cleanup-job"`）+ **prod Dockerfile COPY**（`deploy/Dockerfile.rust-api.txt` Manifest 段 `cleanup-job/Cargo.toml` + Source 段 `cleanup-job/src` + builder `--bins`）（D5；C-V-9 紀律）
- [ ] T003 [P] compose 第二 rust-api（`docker-compose.dev.yml` 加 `rust-api-2` service、host `:31082`、`profiles:[multi]`、共享同 DB+Redis、繼承 dev rust-api 定義）（D7；dev 預設不啟）

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ Redis 基建改 AppState 形狀（所有 handler 用之）；US2 熱載／US3 denylist／US4 全依本階段**

- [ ] T004 Redis client facade（`rust-api/server/src/redis.rs`：多工連線 ops〔`GET`/`SET .. EX`/`PUBLISH`〕+ 專用 subscriber 連線；全 fail-OPEN helper〔不可達回 Ok/None 不 panic〕）（D1；依 T001）
- [ ] T005 `AppState` +`redis:Arc<...>` +`single_session_default:Arc<AtomicBool>` in `rust-api/server/src/state.rs` + `main.rs` 構造（D1；依 T004）
- [ ] T006 main.rs boot：連 Redis（**best-effort 降級不 panic**、沿 007 xdb 哲學）+ 載 `single_session_default` 初值入快取 + spawn watcher task（`SUBSCRIBE settings:invalidate` → 重載快取；斷線重訂閱）in `rust-api/server/src/main.rs`（D1；依 T005）
- [ ] T007 008 `update_setting` handler commit 後 `PUBLISH settings:invalidate` in `rust-api/server/src/handler/system_settings.rs`（D1；依 T004；跨 feature 一行小改、不破 008）

## Phase 3: User Story 1 — token 輪替鏈與盜用偵測 (P1) 🎯 MVP

**Goal**：refresh 每次使用輪替、reuse 重放→撤整鏈→8888、雙擊容忍。**Independent Test**：refresh 換新對／舊重放→撤鏈+8888。**（Redis 無關、可作平行 MVP）**

- [ ] T008 [US1] 純測 `decide_rotation` 四分支（active→Rotate／used&(now−used_at)<GRACE(30s)→Benign／used≥grace·revoked·used_at=NULL→Reuse〔fail-closed〕／notfound、grace 邊界）in `rust-api/server/src/auth/session.rs`（#[cfg(test)]、test-first 先紅）（C-V-1）
- [ ] T009 [US1] `decide_rotation` 純函式 + `enum RotationDecision` in `rust-api/server/src/auth/session.rs`（令 T008 綠）（D3；§I.7 §4.1 decision seam 純函式）
- [ ] T010 [US1] `sys_token` facade：`find_by_hash` / `mark_used`〔UPDATE status='used',used_at WHERE id AND status='active' 冪等〕/ `revoke_chain`〔UPDATE status='revoked' WHERE rotation_chain〕in `rust-api/server/src/model/facade/sys_token.rs`（D3）
- [ ] T011 [US1] `/auth/refreshToken` handler：verify refresh JWT〔失敗→8888〕→ pointer-first `is_current`〔失敗→7777〕→ sha256→`find_by_hash`→`decide_rotation`→Rotate〔FOR UPDATE `mark_used`+insert 新 active 同 chain〕/Benign〔insert 新、不撤〕/Reuse〔`revoke_chain`+warn→8888〕→ 簽新 pair〔新 jti〕in `rust-api/server/src/handler/auth.rs`（D3；依 T009,T010；§I.7：絕不回 3333/9999/9998）
- [ ] T012 [US1] main.rs `/auth/refreshToken` route（public、非 enforce_mw 後）in `rust-api/server/src/main.rs`（依 T011）
- [ ] T013 [US1] live（容器內、`--test-threads=1`、curl+psql）：rotate→新對／benign 雙擊→不撤／reuse→8888+psql 證 `rotation_chain` 整鏈 `status='revoked'`／驗章失敗→8888（C-V-3）

**Checkpoint**：US1＝refresh 輪替+盜用偵測，獨立可驗（MVP 可交付）。

## Phase 4: User Story 2 — 單一登入（全域＋逐使用者）+ 設定 UI (P1)

**Goal**：`resolve_policy` 讓 `single_session_default`×`session_policy` 生效、effective on 踢(7777)/off 並存、per-user 覆寫、熱載。**Independent Test**：B 登入踢 A(on)／並存(off)／009 改 session_policy 生效。

- [ ] T014 [US2] 純測 `resolve_policy` 三態 × 全域 on/off in `rust-api/server/src/auth/session.rs`（test-first）（C-V-1）
- [ ] T015 [US2] `resolve_policy` 純函式 + `enum EffectivePolicy` in `rust-api/server/src/auth/session.rs`（令 T014 綠）（D2）
- [ ] T016 [US2] `is_current` 補讀 `resolve_policy`〔讀 AppState `single_session_default` + user `session_policy`；effective off→放行不踢；維持 fail-OPEN〕+ `sess:{uid}` pointer 快取〔persist-then-cache：set_pointer 先 DB 後 Redis、is_current 讀 Redis→miss 回 DB lazy rehydrate〕in `rust-api/server/src/auth/enforce.rs` + `model/facade/sys_user.rs`（D2；依 T015,T006）
- [ ] T017 [US2] login `revoke_other_chains`〔effective on 時撤該 user 其他 active rotation_chain〕+ `set_pointer` 永遠執行 in `rust-api/server/src/handler/auth.rs` + `model/facade/sys_token.rs`（D2；依 T015；§I.7：set_pointer 永遠、即使 off）
- [ ] T018 [US2] rust session_policy wire：`getUserList` item +`sessionPolicy`〔honest literal `'inherit'|'on'|'off'`〕+ `updateUser` 收+寫〔`UserWrite` +`session_policy:Option<String>`、`build_update_active_model` +`Set(session_policy)` None→不改〕in `rust-api/server/src/handler/system_manage.rs` + `model/facade/sys_user.rs`（D6）
- [ ] T019 [P] [US2] base-web typing：`rev3-system-manage.d.ts` UserUpsertModel +`sessionPolicy?` + rev3 list-item 型帶 `sessionPolicy`（**不動 frozen `system-manage.d.ts` 的 User**）in `base-web/src/typings/api/rev3-system-manage.d.ts`（D6；honest wire；依 T018）
- [ ] T020 [US2] base-web 009 編輯 drawer +`session_policy` NSelect（inherit/on/off）〔MODAL-WIRING ★ (a)、`rev3-inline` 紀律〕+ app.d.ts Schema 先擴 + 雙 locale `page.manage.user.sessionPolicy.*` 同 commit in `base-web/src/views/manage/user/modules/user-operate-drawer.vue` + `typings/app.d.ts` + `locales/langs/{zh-cn,en-us}.ts`（D6；依 T019）
- [ ] T021 [US2] live + CDP：effective on→B 登入踢 A(7777)/off→並存/per-user override 蓋全域 + 008 切 `single_session_default` 熱載生效 + CDP 009 改 session_policy psql 證（C-V-4 / C-V-8 per-user 部分）

## Phase 5: User Story 3 — 停用/刪除使用者即時失效（denylist）(P2)

**Goal**：停用/刪 user→access token 立即 8888、不分 policy、不等過期。**Independent Test**：停用持 token 的 user→下個請求即拒。

- [ ] T022 [US3] denylist ops：`set_revoked(uid)`〔`SET revoked:user:{uid}=now EX access_ttl`〕/ `revoked_at_of(uid)`〔`GET`、回 Option<i64>〕in `rust-api/server/src/redis.rs`（或 `model/facade/sys_session_denylist.rs`）（D4；依 T004）
- [ ] T023 [US3] `enforce_mw` 查 denylist〔bearer→is_current 後、uid 在名單且 `claims.iat<revoked_at`→reject 8888、**fail-OPEN**〕in `rust-api/server/src/auth/enforce.rs`（D4；依 T022）
- [ ] T024 [US3] `revoke_user_sessions(uid)`：撤該 user 全部 active rotation chain(DB) + 清 pointer〔DB `current_session_id=NULL` + Redis `sess:{uid}`〕+ `set_revoked`(Redis) in `rust-api/server/src/model/facade/sys_user.rs`（D4；依 T010,T022）
- [ ] T025 [US3] 接 009：`deleteUser` + `updateUser(status=2 停用)` handler 呼 `revoke_user_sessions` in `rust-api/server/src/handler/system_manage.rs`（D4；依 T024；跨 feature、不破 009 既有 CRUD）
- [ ] T026 [US3] live：停用/刪 user→access token 立即 8888（不分 policy）+ `redis-cli GET revoked:user:{uid}` + re-enable 新 login 正常〔iat>revoked_at〕+ 停 Redis→denylist fail-OPEN（C-V-5）

## Phase 6: User Story 4 — 多副本跨實例正確 (P2)

**Goal**：2 instance 共享 DB+Redis → 策略/pointer/denylist 跨副本一致 + watcher 韌性。**Independent Test**：A 切設定→B 收斂；A 登入→B 踢。

- [ ] T027 [US4] watcher 重訂閱韌性確認/加固（`SUBSCRIBE settings:invalidate` 斷線→重連重訂閱迴圈）in `rust-api/server/src/redis.rs` / `main.rs`（依 T006；若 T006 已含則確認補測）
- [ ] T028 [US4] live 2-instance（`$DC --profile multi up -d rust-api-2 --wait`、:31082）：A 切 `single_session_default`→B 收斂(watcher)／A 登入→B 讀 shared pointer 踢／denylist 跨副本一致／`redis-cli CLIENT KILL TYPE pubsub`→watcher 重訂閱後仍收斂；收尾 `--profile multi down`（C-V-6）

## Phase 7: User Story 5 — 過期 token 清理 (P3)

**Goal**：cleanup-job dry-run/--execute/冪等。**Independent Test**：dry-run 只 count／--execute 刪過期／再跑冪等。

- [ ] T029 [US5] `cleanup-job/src/main.rs`：連 DB(`DATABASE_URL`) + 查/刪 `sys_token` `expires_at<now()-SKEW_MARGIN(60s)`〔與 status 無關〕+ **dry-run 預設只 count + `--execute` 物理刪 + 冪等 + 單旗標**（§I.7 §4.1；D5；依 T002）
- [ ] T030 [US5] live：dry-run 只 count 不刪／`--execute` 刪過期／立即再跑冪等（刪 0）／未過期原封（C-V-7）

## Final Phase: Polish & Cross-Cutting

- [ ] T031 lint 綠：`entity_access_lint`（sys_token/sys_user 寫走 facade、零 path-root entity::）+ `endpoint_coverage_lint`（`/auth/refreshToken` public 納入分類、`[&str;N]` bump、registered==as-built）（C-V-2）
- [ ] T032 ★ prod target image build：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`（新 cleanup-job crate Manifest+Source COPY 無缺口、Redis crate `--locked` 編入、multi-stage）（C-V-9）
- [ ] T033 零回歸：006 login/getUserInfo/enforce、009 CRUD、008 設定、013 audit、`/health` + migration up→down→up〔**無新 migration**〕+ base-web `pnpm typecheck`（C-V-10）
- [ ] T034 final holistic review（fresh-agent 冷讀）：5 US / 14 FR / 10 SC 全覆蓋 + **§I.7 §4.1+§4.3 invariants 逐條有自動化驗證**（§8.8 DoD）+ 7777/8888 兩通道 CDP + cross-unit 接縫一致

---

## Dependencies（User Story 完成順序）

```
Setup(T001-T003) → Foundational(T004-T007) → US1(T008-T013, MVP)
                                                 ├→ US2(T014-T021)   依 resolve_policy + Redis 熱載
                                                 ├→ US3(T022-T026)   依 Redis denylist + revoke
                                                 ├→ US4(T027-T028)   依 US2 watcher + US3 denylist + shared pointer
                                                 └→ US5(T029-T030)   獨立（cleanup-job crate）
                                              → Polish(T031-T034)
```
- **Foundational（Redis 基建）阻塞 US2/US3/US4**（改 AppState 形狀、熱載/denylist 靠它）；**US1（rotation）Redis 無關、可平行 MVP**（僅依 AppState 形狀定稿 T005）。
- US4 依 US2(watcher)+US3(denylist)。US5 獨立。
- base-web（T019/T020）依 rust wire（T018）。

## Parallel execution（受 rust-serial 限制、僅標可平行檔）
- T002（cleanup-job 骨架）/T003（compose）可與 T001（Redis dep）平行（不同檔）。
- T019（base-web typing）與 rust 任務不同 repo 可錯開（但依 T018 wire）。
- **rust cargo build/test 一律 serial**（共用 target）；base-web 任務與 rust 錯開。

## Implementation Strategy（MVP first）
1. **MVP = Setup + Foundational + US1**（T001–T013）：refresh 輪替+盜用偵測，可獨立 demo/驗收。**US1 Redis 無關**：T005 AppState 形狀定稿後即可與 Foundational Redis（T004/T006/T007）平行推進。
2. 增量交付 US2（單一登入+UI）→ US3（即時撤銷）→ US4（多副本驗證）→ US5（清理）。
3. Polish 收尾（lint/prod build〔新 crate COPY〕/零回歸/holistic〔§I.7 invariants 逐條驗〕）。
4. 階段 2 由 `superpowers:executing-plans` 依**實際相依**把 tasks 重組執行單元（Workflow 驅動）、不綁定本檔編號。**★ 每執行單元一支 Workflow（implementer→spec review→fix→quality review→fix）**；主線單元邊界自驗+逐單元 bump pin。
