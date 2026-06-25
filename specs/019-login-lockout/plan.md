# Implementation Plan: 登入鎖定（login-lockout）

**Branch**: `019-login-lockout` | **Date**: 2026-06-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/019-login-lockout/spec.md`

## Summary

在 `/auth/login` handler 前置一道**失敗次數節流 gate**：對既有 `sys_login_attempt`（007/m001 建、archetype B append-only）**唯讀消費**，在滑動 15 分鐘窗內 count per-ip（`real_ip`）與 per-user（`attempted_user_name`）的 `success=false` 數，任一達門檻（per-user 5／per-ip 20）即短路、不進 `login_inner`、回既有 `Biz`→2222 + i18n key `auth.login.locked`。gate 結果匯流進**既有單一寫點**（gated 列 success=false／operator=None／ctx 四欄鑑識照填＝sticky+審計完整）。**0 schema／0 migration／0 新 crate／0 新 route**；base-web 只加 1 個 i18n key（locale + Schema）。fail-OPEN（count DbErr→放行）。設計接地、決策與 8 項待固化詳 [research.md](./research.md)；read-path/決策邏輯詳 [data-model.md](./data-model.md)。

## Technical Context

**Language/Version**: Rust（rust-api、workspace MSRV 1.86）＋ TypeScript / Vue 3（base-web）

**Primary Dependencies**: axum / sea-orm（既有 feature `with-chrono`/`with-ipnetwork`，**無新 dep**）/ casbin（既有）；base-web naive-ui + i18n（既有）

**Storage**: PostgreSQL — `sys_login_attempt`（既有 append-only 審計表，**唯讀消費**；不 ALTER、不加欄、不 migration）；兩既有複合索引 `idx_login_attempt_{ip_time,user_time}`（007 為 ⚠️w lockout 備）

**Testing**: `cargo test`（純函式 `is_locked_out` test-first + in-crate `#[ignore]` live、**容器內** `docker exec`、`--test-threads=1`）/ CDP browser smoke（9229、鎖中 toast 在地化）/ curl / psql / EXPLAIN

**Target Platform**: Linux 容器（docker compose dev/prod）

**Project Type**: web（rust-api backend + base-web frontend）

**Performance Goals**: gate＝per-login 兩個 indexed COUNT（走 `idx_login_attempt_*`）；非高頻熱路徑（僅 login）、無顯著額外開銷

**Constraints**: 容器內 build/test（host 無 rust toolchain）；**rust 全程 serial**（共用 target）；live smoke `--test-threads=1`（共用 `sys_login_attempt` 非 parallel-safe）；base-web commit `--no-verify`；**測試隔離**＝拋棄式帳號/短窗 override（防鎖 seed 帳號 15 分污染下游、見 contracts §測試隔離）；★ **絕不 `push`/`merge` until `finishing-a-development-branch`**

**Scale/Scope**: per-login gate；**2 執行單元**（U1 rust gate／U2 base-web i18n）；3 rust 動點（facade ×2 count + handler gate + 純函式）＋ 1 base-web i18n key

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* 對照 constitution **v1.1.2** §IV 9 項：

| # | 檢查項 | 判定 | 說明 |
|---|---|---|---|
| 1 | §I.1 base-web 為權威（rust-api 補齊 endpoint） | ✅ PASS | **不新增 endpoint**；gate 在既有 `/auth/login` 內部。base-web login form 既有錯誤路徑（攔截器 `onError`→toast）即消費 2222+msg、無需 rust 補新端點 |
| 2 | 動 base-web inline？屬哪個 ★ 軌道？ | ✅ PASS | 改 base-web ＝ **BASE-WEB-I18N-WIRING ★ (ii)+(iii)**：`locales/langs/{zh-cn,en-us}.ts` 加 `backend.auth.login.locked`（純 additive）+ `typings/app.d.ts` Schema 加 `login.locked`。**login form / 攔截器控制流零改**（R3 實證）。循 §III fork-delta `rev3-inline` 紀律 |
| 3 | menu 顯示走 Casbin enforce？ | ✅ PASS（N/A） | 不涉 menu（login 為 public route、constantRoutes、§I.2 不適用） |
| 4 | wire 對齊 §I.3 typings 權威序與不變式？ | ✅ PASS | 鎖中走既有 **2222** `Biz`（HTTP 200 envelope）、msg=穩定 i18n key（⚠️y/⚠️aa）；**13 碼矩陣不變、2222 既有非新碼**；無 id 型/PageRes/enum 問題 |
| 5 | 從 rev2 source 拷貝 code？防回歸？ | ✅ PASS | rust-api in-tree 新寫（facade count + gate）；無 rev2 拷貝；不帶回任何已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | ✅ PASS | 不觸 13 凍結拍板；2222 reuse 不破 ⚠️f（#10/§I.3）；本案＝DECISIONS §1 ⚠️w 落地、非 §II 項 |
| 7 | 觸及 §III ★ 軌道？授權邊界內？ | ✅ PASS | **BASE-WEB-I18N-WIRING ★ (ii)(iii)** 在授權邊界內（純加 backend.* key + Schema、不改攔截器控制流）；每改一處 plan/spec 記 file:line（見 data-model §5）+ upstream 衝突風險（純 additive、低） |
| 8 | 新建業務表？含 §I.6 六審計欄？append-only 例外？ | ✅ PASS（N/A） | **0 新表、0 migration、0 ALTER**；對既有 archetype B `sys_login_attempt` **唯讀消費**（read-path facade count）；無 schema 演進、不觸 §I.6 retrofit 議題 |
| 9 | 觸及 §I.7 行為島？invariants 保持？ | ✅ PASS | **不觸** token rotation／policy governance／single-session 三狀態機；gate＝**新增 fail-OPEN blocking gate**（鏡像 `is_current`/`denylist_gate` fail-OPEN 範式、**不反轉**任何 §I.7 方向性不變式）。§V.2「gate 跳過清單」條款指 skip-list 改動、與「新增 blocking gate」無關 → **不需 Amendment**（brainstorm §8 #7 預答） |

**Gate 結論：通過（9/9，無破例、無 Complexity Tracking）**。較 013（item 8 schema-ALTER 破例）更乾淨——本刀純讀消費既有資料。

## Project Structure

### Documentation (this feature)

```text
specs/019-login-lockout/
├── plan.md              # 本檔
├── research.md          # Phase 0：3-agent act-on-code 接地 + 8 決策 + §8 待固化回答
├── data-model.md        # Phase 1：唯讀 entity + 2 count read-path + 純函式 gate + i18n key
├── quickstart.md        # Phase 1：端到端驗證導引
├── contracts/
│   └── verification-commands.md   # Phase 1：C-V-0~9 驗收契約（純函式/lint/live/EXPLAIN/CDP/prod-build/零回歸）
└── tasks.md             # Phase 2（/speckit-tasks 產，非本步）
```

### Source Code (repository root) — 2 執行單元

```text
rust-api/                                         # backend（worktree+submodule）— U1
└── server/src/
    ├── model/facade/sys_login_attempt.rs         # U1：append count_failed_by_ip_since / count_failed_by_user_since（走兩既有索引；唯讀）
    └── handler/auth.rs                            # U1：is_locked_out 純函式 + 4 const + login_inner 前 gate 插點（匯流既有單一寫點 196-212、不改 login_inner 簽名）
                                                   #     + in-crate #[cfg(test)] #[ignore] live smoke（count/gate/滑動窗/轉換一致）
base-web/src/                                      # frontend — U2（BASE-WEB-I18N-WIRING ★ (ii)(iii)）
├── typings/app.d.ts                              # U2：App.I18n.Schema.backend.auth.login 加 locked（★ 先 Schema）
└── locales/langs/{zh-cn,en-us}.ts                # U2：backend.auth.login.locked 雙語（後 locale、同 commit）
```

**Structure Decision**: 既有 web 結構（rust-api backend / base-web frontend）；本案為**對既有 007 audit overlay 的下游唯讀消費**（同表兩獨立讀者：012 審計顯示分頁 vs 本刀即時 count gate、0 寫競爭/0 schema 衝突）。無新專案/目錄/crate/migration。2 執行單元相依：U1（rust，自足可獨立驗）→ U2（base-web i18n，依 U1 的 msg key 對齊但可平行寫、CDP 在地化驗需兩者）。由 /speckit-tasks → 階段 2 `executing-plans` 編執行單元。

## Complexity Tracking

> **無破例需登記**。0 新表/migration（不觸 §I.6 retrofit）、0 新 crate（不觸「新 crate⇒四處 COPY」）、2222 reuse（不破 ⚠️f）、fail-OPEN 鏡像既有範式（不反轉 §I.7、不需 Amendment）。Constitution Check 9/9 乾淨通過、本表留空。
