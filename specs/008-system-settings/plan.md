# Implementation Plan: 008-system-settings（system_settings KV 打樋＝波1 第一刀）

**Branch**: `008-system-settings` | **Date**: 2026-06-18 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/008-system-settings.md`（③=B 打樋；plan-phase 4 維 research 親驗校正 2 處：R1 m005 MOOT／R2 static Option A）

## Summary

波 1 第一刀（打樋）＝用最輕的 KV entity `system_settings` 便宜跑完 §8.1 縱切管線、達成三個「全專案首次」：**首個 policy-governed 端點**（新 `require_policy` per-route layer、DB-fresh roles、5003→403 live 首証、`enforce_mw` 本體不改守 §3.4）／**首個 007 op-log threading live consumer**（update→op-log operator_ip 真 INET）／**立 `endpoint_coverage_lint`**（⚠️x 波0 豁免項、三類 route 分類）。2 端點（讀全列／改單鍵）＋super-only＋value_type 驗（biz 2222）＋同 txn 審計（archetype A 異動原子）＋net-new base-web static 頁/wire/i18n。**plan-phase research 兩大校正**：①**m005 MOOT**——端點 policy×2＋menu policy＋sys_menu 列**已在 m002 baseline seed**（brainstorm 漏看 m002），本刀**零 migration**；②**前端 Option A**——base-web 現 `static` 模式＋getUserRoutes 後端未實作（dynamic-menu＝波2 Menu 刀），本刀加 static 頁、menu-Casbin-visibility 延波2。§5.6 watcher/session_mode consumption＝波3。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-api、`rust-toolchain.toml` pin）＋TypeScript/Vue 3（base-web、soybean-admin fork）

**Primary Dependencies**: server **無新增 dep／無新 crate**（既有 axum 0.7／sea-orm 1.1.20／casbin 2.20；`require_policy` 用既有 `axum::middleware::from_fn_with_state`、`enforce_role_path_method`/`roles_of_user`/`mutate_in_txn`/`to_audit_operator` seam 皆已在）。base-web 零新 npm dep。

**Storage**: PostgreSQL（既有 dev stack、m001 schema）。**本刀無 migration、無建表、無 schema 變更**——`system_settings`(10 欄 m001)＋端點 policy×2/menu policy/sys_menu 列（m002:162-165/251）皆已 seed（research R1）。

**Testing**: rust in-crate `#[cfg(test)]` 純測（facade `*_active_model`／`validate_value_type`）＋live `#[ignore]` smoke（update→op-log INET round-trip）＋新 `endpoint_coverage_lint`＋既有 `entity_access_lint`（守恆）。**live 一律 `--test-threads=1` serial**（共用 op-log 表）。base-web `pnpm typecheck`＋CDP 經 front-nginx。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。**無新 crate→prod build 輕**（C-V-10、確認新碼編入 prod target、非新 crate COPY 紀律）。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內）。

**Project Type**: web（rust-api backend＋base-web frontend）——L4 facade（read/update）＋L5 handler（2 端點）＋L4 `require_policy` layer＋L1 main 接線＋L8 endpoint_coverage_lint；base-web L3 wrapper（rev3-*）＋L1/L2 typings＋L4 view（MODAL-WIRING (e)）＋locale（I18N-WIRING）。

**Performance Goals**: 讀 p95<300ms／改（含同 txn 審計）p95<500ms（⚠️a 保守預設）；`require_policy` per-request `roles_of_user` join（getUserInfo 已同 join、proven-affordable）。

**Constraints**: `enforce_mw` 本體不改（§3.4）；授權 subject＝DB-fresh roles 非 claims.roles（§I.3 FR-008）；**零 migration/schema/entity 變更**（m005 MOOT）；無新 crate；base-web 既有檔不改（rev3-* wrapper/新 typings/新頁/locale 加 key、fork-delta rev3-inline 紀律）；static route 模式（dynamic＝波2）；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: KV 鍵極少（目前 1 seeded）；≤50 並發 admin（§1.3）；2 rust 端點＋1 base-web 頁。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威？rust-api 缺對應 endpoint？ | **PASS**——本刀同刀新增 rust-api（getSystemSettings/updateSystemSetting）＋對應 net-new base-web wire（rev3-* wrapper）；兩端俱在；m002 policy 已就位。base-web 為 net-new（無既有 system-settings wire 可不對齊） |
| 2 | 動 base-web inline？屬 MODAL-WIRING ★ 哪用途？依 fork-delta 紀律？ | **PASS**——MODAL-WIRING (e) 新管理頁＋BASE-WEB-I18N-WIRING (ii)(iii)（backend.biz.systemSettings.*＋Schema）＋WRAPPER（rev3-system-settings.ts 新檔）＋ADAPT（新 typings 檔）皆**既授**；不改既有 auth.ts/system-manage.ts/route.ts/system-manage.d.ts；Schema 改既有檔走 fork-delta 修改型（原行註解保留），locale/頁/wrapper 新增型走標記圈界、皆含 `rev3-inline` token |
| 3 | menu 顯示走 Casbin enforce？demo ⚠️p？ | **PASS（機制延波2）**——manage_system-settings menu policy 已 seed（m002:165、R_SUPER）；Casbin menu-visibility 經 getUserRoutes＝**波2 Menu 刀**（dynamic）；波1 static 頁可達、API 層 Casbin（require_policy）已強制 super-only。非 demo 頁、⚠️p N/A |
| 4 | wire 對齊 §I.3 typings 權威？ | **PASS**——envelope `Res{data,code,msg}`／business error 走 HTTP 200（5003→403 例外）／camelCase DTO／13 碼（2222 biz/5003 permission）；無 id-string 議題（setting_key=string PK、value=string、無 numeric id wire）；flat 回（system_settings 不套用 §5.8 PageRes、首 exercise＝波2 User） |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——設計借 rev2 029、code 全新寫（§I.5/⚠️g 受控參照、讀允許拷貝禁止）；不帶回已推翻行為 |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——無拍板需改。**#7 dynamic route mode**：本刀維持 static、dynamic 啟用＝波2 Menu 刀（getUserRoutes 落地時）；#7 為最終模式、啟用時點屬排程（roadmap 波2）→ 波1 static **非 #7 violation**（pre-migration、留痕 research R2） |
| 7 | 觸 §III ★ 軌道？授權邊界內？ | **PASS**——MODAL-WIRING (e) ★＋BASE-WEB-I18N-WIRING (ii)(iii) ★ 皆**本檔已授**、在邊界內；RUSTAPI-SOURCE-ISOLATION／WRAPPER／ADAPT（§III.1 預設可動） |
| 8 | 新建業務表（migration）？§I.6 六審計欄？ | **PASS（未觸）**——**零 migration**（m005 MOOT、research R1：端點 policy×2＋menu policy＋sys_menu 列已 m002 seed；system_settings 表 m001 已建、archetype A 全 6 審計欄已在）。無 retrofit |
| 9 | 觸 §I.7 行為島（token/policy/single-session）？ | **PASS（未觸）**——本刀持久化＋審計 `single_session_default` 值，但**不動** single-session/token/policy 三台狀態機（無 consumption、無 watcher、is_current〔006〕不變；`session_mode` 熱讀 consumption＝波3 §4.3）；§I.7 invariants 不受影響 |

**Gate 結論：9/9 PASS；無 Amendment；§II #7 dynamic 啟用延波2＝排程性〔非 violation〕；m005 MOOT；Complexity Tracking 不適用。**

> **無新 crate ⇒ prod build 輕**：008 不加 workspace crate（`require_policy`/`endpoint_coverage_lint` 皆 server 內模組/測）→ 無 §3「新 crate ⇒ Dockerfile COPY」紀律觸發；C-V-10 仍跑 prod target build 確認新碼編入（非新 crate COPY 驗）。

## Project Structure

### Documentation (this feature)
```text
specs/008-system-settings/
├── spec.md              # /speckit-specify ✅（4 US／11 FR／7 SC／16-16 checklist）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 m005 MOOT・R2 static Option A・R3-R9 grep ground-truth）
├── data-model.md        # Phase 1 ✅（facade/handler/require_policy/op-log threading/value_type/wire/i18n/lint）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md     # C-V-0~10（build／3 純測／lint×2／live op-log・policy-gate／CDP／typecheck／prod build／零回歸）
│   └── system-settings-contract.md  # 跨 feature 不變式（require_policy pattern／endpoint_coverage_lint／讀改/審計原子／wire-i18n 軌道）
└── checklists/requirements.md       # 16/16 ✅
```

### Source Code (repository root)
```text
rust-api/server/src/
├── model/facade/system_settings.rs    # ★ 新（archetype A）：find_all＋update_by_key〔mutate_in_txn 同 txn op-log〕＋AuditSerialize impl＋*_active_model 純測＋live smoke
├── model/facade/mod.rs                 # 改：+ pub mod system_settings;
├── handler/system_settings.rs          # ★ 新：get_system_settings（flat）＋update_setting（value_type 驗→2222、to_audit_operator 餵 mutate_in_txn）＋DTO
├── handler/mod.rs                      # 改：+ pub mod system_settings;
├── auth/enforce.rs                     # 改：+ require_policy（DB-fresh roles→casbin→5003、enforce_mw 不動）
└── main.rs                             # 改：註冊 2 路由＋enforce_mw→require_policy 兩層
rust-api/server/tests/endpoint_coverage_lint.rs  # ★ 新（⚠️x 波1 立）：route 三類分類＋policy-governed↔seed
base-web/src/
├── service/api/rev3-system-settings.ts            # ★ 新（WRAPPER ★III.1、首個 rev3-* 檔）
├── typings/api/rev3-system-settings.d.ts          # ★ 新（ADAPT ★III.1）：SystemSetting＋UpdateSystemSettingReq
├── views/manage/system-settings/index.vue         # ★ 新（MODAL-WIRING (e) ★III.2、static route manage_system-settings）
├── typings/app.d.ts                                # 改（I18N-WIRING (iii)）：App.I18n.Schema backend.biz.systemSettings 型
└── locales/langs/{zh-cn,en-us}.ts                  # 改（I18N-WIRING (ii)＋MODAL-WIRING(e)）：backend.biz.systemSettings.*＋route.manage_system-settings＋page.manage.systemSettings.*
# ALREADY（不動、research R1/R4）：migration（m005 MOOT、m002 已 seed policy/menu/sys_menu）・entity/system_settings.rs（004）・audit_ctx.rs+to_audit_operator（007）・enforce_mw+enforce_role_path_method+roles_of_user（006）・mutate_in_txn+write_in_txn（005）・error.rs 13 碼（003）・base-web auth.ts/system-manage.ts/route.ts/system-manage.d.ts
```

**Structure Decision**：web（rust-api backend＋base-web frontend）。rust-api：L4 facade（read/update）＋L5 handler（2 端點＋value_type 驗）＋L4 `require_policy`（§3.4 政策強制 pattern 之首）＋L1 main 接線＋L8 endpoint_coverage_lint。base-web：L3 wrapper（rev3-*）＋L1/L2 typings＋L4 view（static 頁）＋locale。**無 migration/entity/新 crate**（m005 MOOT、地基 001-007 已 provisioned）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks）

1. **★ 順序**：facade `system_settings`（find_all＋update_by_key、test-first active_model）→ `validate_value_type` 純函式（test-first）→ handler（2 端點、value_type 驗→2222、`ctx.to_audit_operator(claims.uid)` 餵 mutate_in_txn）→ `require_policy` layer（enforce.rs、DB-fresh）→ main 註冊 2 路由＋兩層 → `endpoint_coverage_lint`（新）→ 純測＋lint＋live smoke（op-log round-trip）→ live policy-gate（5003）→ base-web wrapper/typings/頁/i18n → CDP → prod build → **兩段式 commit（rust-api worktree→pin；base-web worktree→pin；outer specs/008）**。
2. **★ m005 MOOT（research R1）**：**不建 migration**。端點 policy×2（m002:162-163）＋menu policy（m002:165）＋sys_menu 列（m002:251）已 seed；`require_policy` 直接對既存 policy 強制；`endpoint_coverage_lint` 的 system-settings policy 已存。
3. **★ require_policy（research R3、§3.4）**：`enforce_mw` 一行不動；新 per-route layer 取 `State`+`Extension<Claims>`→ **DB-fresh** `roles_of_user(db, claims.uid)`（**不信 claims.roles**）→ `enforce_role_path_method`→ false→`PermissionDenied`(5003)。鏡像 main.rs:92-95 `from_fn_with_state` 寫法；2 端點 path/method 各自掛（與 lint registry 對齊）。
4. **op-log threading（research R9、007 seam 首 live consumer）**：update handler 經 `ctx.to_audit_operator(claims.uid)` 取 operator/IP/trace 餵 mutate_in_txn；op-log operator_ip 由恆 None→真 INET（達成 005/007 follow-up）。
5. **value_type 驗（research R5）**：handler 改前驗（`enum:on,off` 解析、不符→`Biz("biz.systemSettings.invalidValue")` 2222；查無 key→`Biz("biz.systemSettings.notFound")` 2222、no-op）。**不**落 DbErr 23505→2222（PK lookup 不觸、波2 CRUD、research R8）。
6. **endpoint_coverage_lint（research R6、⚠️x）**：鏡像 entity_access_lint 只讀掃描；斷言「registered policy-governed route 必有 m002 seed」＋「registered==as-built registry」、**非 §7.1 @35 字面**（m002 預 seed ~39 條未註冊路由 policy）；plan→impl 定確切斷言碼、避 fallback 4040 誤判。
7. **★ 前端 Option A（research R2、user 拍）**：base-web `static` 模式；加 `views/manage/system-settings/index.vue`（elegant-router 自動生 route `manage_system-settings`）＋rev3-* wrapper＋新 typings＋i18n；頁可達、API super-only 強制；**無前端 role-meta gating**（menu-Casbin-visibility＋`.env` dynamic 切換＝波2 Menu 刀）；`.vue`/wire/i18n 波2 沿用。
8. **i18n（research R7、兩軌道兩家族）**：`backend.biz.systemSettings.{invalidValue,notFound}`（zh-cn/en-us＋app.d.ts Schema、**先 Schema 後 locale**、I18N-WIRING (ii)(iii)、⚠️y canonical）＋`route.manage_system-settings`/`page.manage.systemSettings.*`（MODAL-WIRING (e)）；攔截器**無需改**（既有 translateBackendMsg `$t('backend.'+msg)`）。
9. **wire 3 端（research R7、§I.3）**：rust DTO camelCase ↔ ts `SystemSetting`（新 typings、不改既有 system-manage.d.ts）↔ component；rev3- wrapper（憲法 WRAPPER 紀律、首個 rev3-* 檔）。
10. **lint 守恆**：handler/`require_policy`/main 零 path-root `entity::`（entity 全在 facade）；`entity_access_lint` 續綠。
11. **base-web commit `--no-verify`**（§8.2.1 alpine oxlint musl）；rust serial／容器內 build·test／改 .rs 先 force-touch／live `--test-threads=1`；**兩段式 commit（worktree→pin、不延後）**；全程不 push/merge（§I.4）；CDP smoke 不 defer（有頁、modal toast）。
12. **零回歸（FR-009/SC-006）**：`enforce_mw`/`audit_mw`/`is_current`/login/getUserInfo/health 不變；零 migration/entity/schema；base-web 既有檔不改（diff 核）。
