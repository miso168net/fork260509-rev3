# Implementation Plan: Auth/Token/Session 合刀

**Branch**: `014-auth-token-session` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/014-auth-token-session/spec.md`

## Summary

把 006 鋪的「Auth 島最小段」（login + `enforce_mw` + pointer + `is_current` stub）補成**完整行為島**（DESIGN §4.4「2+1 合刀」之合刀）：§4.1 **token rotation chain**（`/auth/refreshToken` + `decide_rotation` 純函式 + reuse 偵測→撤整鏈→8888）＋§4.3 **single-session lifecycle**（`resolve_policy` 讓全域 `single_session_default` × per-user `session_policy` 生效、`is_current` 補讀 policy、7777）＋**硬即時撤銷**（Redis denylist、停用/刪 user→access token 立即失效）＋**cleanup-job binary**（新 workspace crate），並以 **2-instance 多副本驗證**證跨進程收斂與 watcher 韌性。**★ 接地揭露 rust-api 完全沒有 Redis client → 本刀含建 Redis 基建**（denylist/pub-sub watcher/pointer 快取的設計前提、§I.7「Redis 僅快取」假設它存在）。**零 migration**（schema 全在 m001/m002）。決策/接地詳見 [research.md](./research.md)。

## Technical Context

**Language/Version**: Rust（rust-api、workspace MSRV 1.86）＋ TypeScript/Vue 3（base-web）

**Primary Dependencies**: axum / sea-orm / casbin / jsonwebtoken / argon2（既有）＋ **async Redis client（新、`redis` 或 `deadpool-redis`、pin 版驗 1.86、§I.5 非 rev2 拷貝）**；base-web naive-ui（既有、refresh 攔截器 starter 既有）

**Storage**: PostgreSQL（`sys_token` 狀態機 / `sys_user.session_policy`+`current_session_id` / `system_settings.single_session_default`——**全既有、零 migration**）＋ **Redis（新：denylist `revoked:user:{uid}` / pointer 快取 `sess:{uid}` / pub-sub `settings:invalidate`、無表）**

**Testing**: `cargo test`（純函式 decide_rotation/resolve_policy + in-crate `#[ignore]` live、容器內、`--test-threads=1`）/ CDP（9229、7777/8888 兩通道）/ curl / psql / redis-cli / **2-instance 多副本 acceptance**

**Target Platform**: Linux 容器（docker compose dev/prod；dev 第二 instance `profiles:[multi]` opt-in）

**Project Type**: web（rust-api backend + base-web frontend + 新 cleanup-job binary crate）

**Performance Goals**: enforce 熱路徑 +1 Redis GET（denylist）+ pointer 讀（Redis 快取→DB fallback）；受全域 ⚠️a perf 預算（p95 300/500/1s、99.5%）；無本刀特定延遲目標

**Constraints**：容器內 build/test（host 無 toolchain）；rust 全程 serial；base-web `--no-verify`；Redis/DB 抖動全 **fail-OPEN**（§I.7）；★ **絕不 push/merge until finishing**

**Scale/Scope**：per-request enforce 中介層 + 行為島 2 機器 + Redis 基建 + cleanup-job crate + 動 009（per-user UI）+ 動 008（publish 一行）；**7 實作單元**（research §D、Project Structure）

## Constitution Check

*GATE：Phase 0 前必過、Phase 1 後 re-check。* 對照 constitution **v1.1.2 §IV 9 項**：

| # | 檢查項 | 判定 | 說明 |
|---|---|---|---|
| 1 | §I.1 base-web 為權威（rust 補 endpoint） | ✅ PASS | 提供 `/auth/refreshToken`（base-web `fetchRefreshToken` 既有呼叫、波0/006 未補）+ updateUser 收 session_policy；base-web 用到的皆對齊 |
| 2 | 動 base-web inline？屬哪 ★ 軌道？ | ✅ PASS | 動 base-web=(a) 009 編輯 drawer `session_policy` NSelect〔**MODAL-WIRING ★ (a)**〕(b) rev3-owned typing〔`rev3-system-manage.d.ts` UserUpsertModel+list-item 加 sessionPolicy、**ADAPT**、不動 frozen `system-manage.d.ts`〕(c) page i18n〔`page.manage.user.sessionPolicy.*`、先 Schema 後 locale〕。**7777/8888/3333 登出碼已配在 `.env`〔ADAPT〕→ 攔截器零改**。循 §III fork-delta `rev3-inline` 紀律 |
| 3 | menu 顯示走 Casbin enforce？ | ✅ PASS（N/A） | 不新增/動 menu；session_policy 在 user 編輯頁、非 menu |
| 4 | wire 對齊 §I.3 typings 權威序與不變式？ | ✅ PASS | refresh 回 LoginToken〔既有形〕；getUserList/updateUser 加 `sessionPolicy` literal〔honest〕；**7777/8888 在凍結 13 碼矩陣**、無新碼；id 型不變 |
| 5 | 從 rev2 拷貝 code？防回歸？ | ✅ PASS | rust in-tree 重寫（rotation/session/denylist/cleanup 設計繼承 rev2 026-030、code 不拷）；Redis crate＝外部 crate 非 rev2 拷貝；不帶回已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | ✅ PASS | 不觸 13 凍結拍板；#13 alt-login **排除本刀**（⚠️m 獨立尾巴刀、一致） |
| 7 | 觸及 §III ★ 軌道？授權內？ | ✅ PASS | MODAL-WIRING ★ (a)〔009 drawer session_policy〕在授權邊界內；每處記 file:line + upstream 風險（見 research §D6） |
| 8 | 新建業務表？含 §I.6 六審計欄？例外？ | ✅ PASS | **零新表、零 migration**（`sys_token`＝archetype C 既有狀態機；denylist/快取/pub-sub＝Redis 無表）；schema 全在 m001/m002 |
| 9 | 觸及 §I.7 行為島？invariants 保持？state-machine 鏡頭？ | ✅ PASS（**核心**） | 實作 §4.1（token rotation）+ §4.3（single-session）；逐 invariant 對齊〔token_hash UNIQUE/jti/rotation_chain 整鏈/reuse 撤整鏈/decide_rotation 純函式/used_at NULL fail-closed/cleanup dry-run·--execute·冪等·單旗標/refresh 絕不回 3333·9999·9998/is_current fail-OPEN/set_pointer 永遠/session_mode runtime store/7777·8888 分離〕、用 DESIGN §4.1/§4.3 state-machine 鏡頭；**每 invariant 須有自動化驗證**（§8.8 DoD、C-V-1~6） |

**Gate 結論：通過 9/9**（無違反；Complexity Tracking 登記 Redis 基建 + cleanup-job 新 crate 之 scope 實況）。

## Project Structure

### Documentation (this feature)
```text
specs/014-auth-token-session/
├── plan.md / research.md / data-model.md / quickstart.md
├── contracts/verification-commands.md   # C-V-0~10
└── tasks.md（/speckit-tasks 產）
```

### Source Code — 7 實作單元（research §D）
```text
rust-api/
├── Cargo.toml                              # 加 redis crate workspace dep；members 加 "cleanup-job"
├── server/
│   ├── Cargo.toml                          # 加 redis={workspace=true}
│   ├── src/redis.rs（新）                   # D1 Redis client facade（多工連線 + 專用 subscriber）
│   ├── src/state.rs / main.rs              # D1 AppState +redis +single_session_default 快取；boot 連 Redis(降級)+watcher spawn
│   ├── src/auth/enforce.rs                 # D2 is_current 補 resolve_policy；D4 enforce_mw 查 denylist
│   ├── src/auth/session.rs（新）            # D2 resolve_policy 純函式；D3 decide_rotation 純函式
│   ├── src/handler/auth.rs                 # D3 /auth/refreshToken 端點；login revoke_other_chains
│   ├── src/handler/system_manage.rs        # D6 getUserList+sessionPolicy / updateUser 收 session_policy；deleteUser 接 revoke
│   ├── src/handler/system_settings.rs      # 收掉 open：update 後 PUBLISH settings:invalidate
│   ├── src/model/facade/sys_token.rs       # D3 find_by_hash / mark_used / revoke_chain
│   ├── src/model/facade/sys_user.rs        # D6 UserWrite+session_policy / build_update_active_model；D4 revoke_user_sessions(清 pointer)
│   └── src/main.rs                         # /auth/refreshToken route
├── cleanup-job/（新 crate）                 # D5 dry-run/--execute/冪等/單旗標
│   ├── Cargo.toml / src/main.rs
base-web/src/
├── typings/api/rev3-system-manage.d.ts     # D6 UserUpsertModel+sessionPolicy + rev3 list-item 型（不動 frozen system-manage.d.ts）
├── views/manage/user/modules/user-operate-drawer.vue  # D6 session_policy NSelect〔MODAL-WIRING (a)〕
├── typings/app.d.ts + locales/langs/{zh-cn,en-us}.ts  # D6 page.manage.user.sessionPolicy.* i18n
deploy/Dockerfile.rust-api.txt              # D5 prod 補 cleanup-job Manifest+Source COPY + --bins
docker-compose.dev.yml                      # D7 rust-api-2 service（:31082、profiles:[multi]）
```

**Structure Decision**：既有 web 結構 + **新 cleanup-job binary crate**（D5）+ **新 Redis 基建**（D1、server/src/redis.rs + AppState）。本刀＝對 006 Auth 島的行為島補完（§4.1+§4.3）+ Redis 首消費者基建；單元相依見 research §D、由 /speckit-tasks → 階段 2 `executing-plans` 編執行單元。

## Complexity Tracking

> 9/9 PASS 無 Constitution 違反；登記本刀**規模實況**（接地揭露、非 spec 隱含）供 user 知情。

| 項 | 為何需要 | 為何不採更簡單替代 |
|---|---|---|
| **新建 Redis client 基建**（rust-api 原零 Redis） | 憲法 §I.7 §4.3 已凍「pointer 真相 DB、Redis 僅快取」+ 硬即時 denylist 需跨副本共享 store + 熱載需 pub-sub——Redis 是設計既定前提、本刀為首消費者 | DB denylist 表＝違零 migration（item 8）；DB 輪詢 settings＝§I.7 隱含 pub-sub；全 DB 無 Redis＝pointer 快取失/多副本熱載無門。**Redis 不可避**；建於首消費者（本刀）非 infra-ahead |
| **新 workspace crate `cleanup-job`** | §I.7 §4.1 明文「on-demand cleanup-job binary」 | server 內 background task＝與 on-demand binary 設計不符；server `[[bin]]`＝不獨立。**新 crate ⇒ prod build COPY 紀律**（C-V-9） |
| **動 009 + 008（跨 feature）** | per-user session_policy override（FR-006/009）需動 009 user 寫端+UI；settings 熱載需 008 update 後 publish 一行 | 不動則 per-user 覆寫無門、熱載無觸發。授權軌道內（MODAL-WIRING (a)）、不破既有行為 |

> 若 user 認為「建 Redis 基建」規模過大宜拆獨立前置刀（而非併本刀），可在 /speckit-tasks 前提出；工程上傾向建於首消費者（本刀）。
