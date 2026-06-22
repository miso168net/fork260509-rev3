# Implementation Plan: Button-Endpoint 授權治理（三維 RBAC runtime 編輯）

**Branch**: `016-button-endpoint-policy` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/016-button-endpoint-policy/spec.md`

## Summary

把 011 鋪的選單授權寫側（`set_role_dimension` DB-first）＋015 補完的授權治理島（archive/restore/protected-reject/PolicyMutated gate/跨副本 watcher）**延伸到 button 與 endpoint 兩個授權維度**：

- **button 維度**＝撿現成：`updateRoleButton` 直接呼 `set_role_dimension(role,"button",desired_codes)`（v2='button' 固定、完美套用），011 寫側＋015 治理島**全免費繼承**；`getRoleButton`/`getAllButtons` 讀端（後者自 `sys_menu.buttons` JSON 萃取 registry）。
- **endpoint 維度**＝新 `set_role_endpoints`：endpoint policy 是 **(v0=role, v1=path, v2=HTTP method) 雙鍵集**（require_policy enforce 用的真實列），v2 會變、**套不上 `set_role_dimension`（v2 固定）** → 新 facade 做 (path,method) 雙鍵 diff，但 **archive-move／protected-reject／同 txn 審計／`reload_and_publish` gate helper 全復用 015**；`getRoleEndpoints`/`getAllEndpoints`（後者自 prod const registry）讀端。
- **鎖出安全**：既有 15 protected endpoint seed 涵蓋恢復路徑（自編輯/治理端點）→ `set_role_endpoints` 接 protected-reject → 撤 protected→整批 Rejected → **無硬鎖出、零 migration**。
- **回收桶三維統一**：archive 表維度無關、button/endpoint revoke 自動進回收桶；回收桶 `dimension` 由 v2 推導（'menu'/'button' 原值、HTTP method→'endpoint'）、不改 `archive_reason`。
- **base-web**：button-auth-modal un-mock＋新 endpoint-auth-modal（MODAL-WIRING (c)、嚴格鏡像 menu-auth-modal）＋role-operate-drawer 第三鈕＋6 service wrapper/型＋i18n。

**★ 接地確認零 migration**：6 編輯端點 policy（`m002:148-153`、全 protected R_SUPER）＋button policy（16）＋endpoint policy（39、含 15 protected）＋button JSON（`sys_menu.buttons`、`m002:209-240`）**全波0 m002 已備**。本刀只【註冊 6 route＋實作 handler＋新 `set_role_endpoints` facade＋bump `AS_BUILT_ROUTES` 37→43＋base-web】、**無新 migration、無新 crate**。決策/接地詳見 [research.md](./research.md)。

## Technical Context

**Language/Version**: Rust（rust-api、workspace MSRV 1.86）＋ TypeScript/Vue 3（base-web）

**Primary Dependencies**: axum / sea-orm / casbin / `redis`（**全既有**）；base-web naive-ui（既有）—— **無新 crate / 無新 dep**

**Storage**: PostgreSQL（`casbin_rule` 三維 ⇄ `sys_casbin_policy_archive` 狀態機 / `sys_operation_log` 審計——**全既有、零 migration**）＋ Redis（既有 pub-sub channel `casbin:policy:invalidate`、復用 015）

**Testing**: `cargo test`（in-crate `#[ignore]` live、容器內、`--test-threads=1`）/ `entity_access_lint` + `endpoint_coverage_lint`（`AS_BUILT_ROUTES` 37→43、+2 lint assertion〔registry 防漂移〕）/ CDP（:31080、role drawer 三 modal）/ curl / psql / **2-instance（rust-api-2 :31082）button/endpoint 跨副本收斂**

**Target Platform**: Linux 容器（docker compose dev/prod；dev 第二 instance `profiles:[multi]` opt-in）

**Performance Goals**: reload = 全量 `load_policy()`（§4.2 ⑤）；PolicyMutated gate 避免無謂 reload/廣播；受全域 ⚠️a perf 預算；無本刀特定延遲目標

**Constraints**：容器內 build/test（host 無 toolchain）；rust 全程 serial；base-web `--no-verify`；★ **i18n 改動後 restart base-web 才能 CDP 驗**（vite locale cache、016 memory）；Redis/DB 抖動 fail-OPEN；★ 絕不 push/merge until finishing

**Scale/Scope**：button 寫端（reuse set_role_dimension）＋新 `set_role_endpoints` facade＋6 handler＋6 route＋registry（button JSON / endpoint const）＋回收桶維度推導＋base-web（button un-mock＋endpoint modal＋6 wrapper＋i18n）＋typings 收斂 fold-in；**零 migration、零新 crate**；**6 實作單元**（research §D、Project Structure）

## Constitution Check

*GATE：Phase 0 前必過、Phase 1 後 re-check。* 對照 constitution **v1.1.2 §IV 9 項**：

| # | 檢查項 | 判定 | 說明 |
|---|---|---|---|
| 1 | §I.1 base-web 為權威（rust 補 endpoint） | ✅ PASS | 補 6 端點（getAll/getRole/updateRole × Button/Endpoints；base-web role drawer 三維編輯需；m002 seed 已備、endpoint 未註冊/實作）；按鈕可見性走 §I.2（buttons_for_roles enforce） |
| 2 | 動 base-web inline？屬 MODAL-WIRING ★ 哪用途 (a)~(e)？ | ✅ PASS | **(c) 同模式新權限 modal＋trigger**（`role-operate-drawer.vue` isEdit 區、嚴格鏡像 menu/button-auth-modal、「角色×某權限維度 runtime 編輯介面」）——endpoint-auth-modal 新建＋button-auth-modal un-mock＋第三鈕＋`page.manage.role.endpointAuth` i18n。另：rev3-WRAPPER（`rev3-system-manage.ts` 6 fn）＋rev3-ADAPT typing（`rev3-system-manage.d.ts` Button/Endpoint 型）＋BASE-WEB-I18N-WIRING（endpoint protected biz key）。循 §III fork-delta `rev3-inline` |
| 3 | menu 顯示走 Casbin enforce？ | ✅ PASS（N/A-extend） | 本刀非 menu 維度；button 可見性走 `hasAuth`←`buttons_for_roles`(v2='button' enforce 讀)、§I.2 同源；endpoint 走 require_policy enforce。不新增 menu |
| 4 | wire 對齊 §I.3 typings 權威序與不變式？ | ✅ PASS | honest typing：getRoleButton 回 `string[]`(button code)／getAllButtons 回 `Button[]{code,label}`／getRole/getAllEndpoints 回 `Endpoint[]{path,method,...}`／update* 回 `null`／Rejected→`2222`（**凍結 13 碼、無新碼**）；id ⚠️r 域；rev3-owned typing |
| 5 | 從 rev2 拷貝 code？防回歸？ | ✅ PASS | rust in-tree（`set_role_endpoints` 新寫、設計繼承 rev2 022/023 但 code 不拷）；復用 011 `set_role_dimension`（button）＋015 archive/gate/watcher（in-tree、§I.5）；不帶回已推翻行為（rev2-034 MgmtApi 明確不用） |
| 6 | 抵觸 §II 拍板 #1~#13？ | ✅ PASS | 不觸 13 凍結拍板；**un-protect 不做**（延續 015 A）保 §4.2 ② protected-reject 不被繞 |
| 7 | 觸及 §III ★ 軌道？授權內？ | ✅ PASS | **MODAL-WIRING (c)**（角色×權限維度編輯介面、明文授權）＋**BASE-WEB-I18N-WIRING (i)~(iii)**（endpoint protected biz key、`backend.biz.*`）皆授權邊界內；每處記 file:line＋upstream 衝突風險（research §D5） |
| 8 | 新建業務表（migration）？§I.6 六欄？ | ✅ PASS（**核心**） | **零新表、零 migration**——button policy/endpoint policy/6 編輯端點 policy/button JSON（`sys_menu.buttons`）/15 protected 標記**全波0 m002 已備**；本刀只註冊 route＋實作＋bump `AS_BUILT_ROUTES` 37→43（測試常數、**非 migration**）。`ALL_ENDPOINT_POLICIES` registry const＝prod 程式常數（非 schema） |
| 9 | 觸及 §I.7 行為島？invariants 保持？state-machine 鏡頭？ | ✅ PASS（**核心**） | 延伸 §4.2 policy governance 至 button/endpoint 維度；**5 invariants 維度無關、逐條沿用不改**〔① DB-first（不碰 MgmtApi）／② protected-reject（endpoint 15 protected=鎖出守門；button 0 protected moot）／③ PolicyMutated gate（updateRoleButton/Endpoints Applied〔含空-diff〕→reload+publish；Rejected→skip）／④ revoke/restore＋審計同 txn 原子／⑤ reload=全量 load_policy＋PUBLISH casbin:policy:invalidate〕；用 §4.2 state-machine 鏡頭（live⇄archived）；**延伸維度＝invariant-faithful、非 amendment**（invariant 文字本就 `casbin_rule/archive` 維度無關） |

**Gate 結論：通過 9/9**（零違反；**零 migration、零新 crate、無 Complexity 違反需登記**——同 015 scope-class）。

> **唯一非違反、供 user 知情的設計點**（非 §II/§I.7 凍結面之動）：endpoint 維度需新 `set_role_endpoints` facade（因 endpoint 的 (path,method) 雙鍵不套 `set_role_dimension` 的固定-v2 模型）；治理 helper 全復用 015、屬實作結構、非 invariant 變動。詳 Complexity Tracking。

## Project Structure

### Documentation (this feature)
```text
specs/016-button-endpoint-policy/
├── plan.md / research.md / data-model.md / quickstart.md
├── contracts/verification-commands.md   # C-V-0~8
├── checklists/requirements.md（specify 產）
└── tasks.md（/speckit-tasks 產）
```

### Source Code — 6 實作單元（research §D）
```text
rust-api/
├── server/src/model/facade/sys_casbin_rule.rs                 # D2 新 set_role_endpoints((path,method) 雙鍵 diff+archive+protected-reject+audit)；新 SetEndpointsError/Outcome
├── server/src/model/facade/sys_menu.rs（或 sys_casbin_rule）   # D1 all_buttons() 自 sys_menu.buttons JSON 萃取 {code,label}
├── server/src/auth/enforce.rs                                 # D1/D2 button_codes_for_role / endpoint_pairs_for_role（鏡像 buttons_for_roles）；ALL_ENDPOINT_POLICIES const（registry）
├── server/src/handler/system_manage.rs                        # D1 getAllButtons/getRoleButton/updateRoleButton（reuse set_role_dimension("button")+reload_and_publish）；D3 getAllEndpoints/getRoleEndpoints/updateRoleEndpoints（set_role_endpoints+gate）；回收桶 dimension v2-推導 display/filter
├── server/src/model/facade/sys_casbin_policy_archive.rs       # D3 list dimension filter endpoint 特例（v2∈HTTP methods）
├── server/src/main.rs                                         # D3 6 route 註冊（require_policy、m002 seed）
└── server/tests/endpoint_coverage_lint.rs                     # D3 AS_BUILT_ROUTES 37→43 + registry 防漂移 assertion
base-web/src/
├── typings/api/rev3-system-manage.d.ts                        # D4 Button/Endpoint 型 + role 關聯（rev3-owned、不動 frozen）；D5 RoleListItemRev3/UserListItemRev3 honest null（typings 收斂）
├── service/api/rev3-system-manage.ts                          # D4 6 wrapper（fetchGetAllButtons/getRoleButton/updateRoleButton/getAllEndpoints/getRoleEndpoints/updateRoleEndpoints）
├── views/manage/role/modules/button-auth-modal.vue           # D4 un-mock（鏡像 menu-auth-modal）
├── views/manage/role/modules/endpoint-auth-modal.vue（新）     # D4 新建（MODAL-WIRING (c)、樹狀 (path,method)、hard-replace）
├── views/manage/role/modules/role-operate-drawer.vue         # D4 第三鈕 endpointAuth + EndpointAuthModal 掛載
├── typings/app.d.ts + locales/langs/{zh-cn,en-us}.ts         # D4 page.manage.role.endpointAuth + endpoint modal 標籤 i18n（先 Schema 後 locale）；backend.biz.* endpoint protected key
```

**Structure Decision**：既有 web 結構、**零新 crate**。本刀＝對 011/015 治理島的維度延伸（button reuse／endpoint 新寫側）＋base-web role drawer 三維編輯（MODAL-WIRING (c)）。單元相依見 research §D，由 /speckit-tasks → 階段 2 `executing-plans` 編執行單元。

## Complexity Tracking

> **9/9 PASS 無 Constitution 違反**；本刀**無新增複雜度需登記**（零 migration、零新 crate、零新 dep）。下表登記**唯一結構性新增**供 user 知情（非違反、非 invariant 變動）：

| 項 | 為何需要 | 為何不採更簡單替代 |
|---|---|---|
| **新 `set_role_endpoints` facade（非復用 `set_role_dimension`）** | endpoint policy＝(v0=role, v1=path, v2=HTTP method) 雙鍵集（require_policy enforce 真實列）；`set_role_dimension` 模型＝「v2 固定 dimension＋diff v1 集」、套不上雙鍵（v2 會變） | 用 v2='endpoint'/v1='path:method' 單鍵編碼＝建出【不驅動 enforce】的平行列（require_policy 查的是 v1=path/v2=method）→ 功能假性、棄。新 facade 仍**復用 015 全部治理 helper**（insert_archived/mutate_in_txn/protected-reject/reload_and_publish），僅 diff 邏輯改雙鍵 |
| **typings 收斂 fold-in（rev3-owned read 型）** | §3.14 roleDesc／§3.12 User nick/phone/email 為 wire↔frozen typing type-lie | declaration-merge 是加法、不能覆寫既有欄型 → 須 `Omit<Role,'roleDesc'>&{roleDesc:string\|null}` rev3-owned 讀型＋service 回型改用；**最低優先、可拆為獨立 typings-收斂刀**（讀端型謊、runtime 已容忍） |
