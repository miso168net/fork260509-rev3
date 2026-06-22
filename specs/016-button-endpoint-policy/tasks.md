# Tasks: Button-Endpoint 授權治理（三維 RBAC runtime 編輯）

**Feature Branch**: `016-button-endpoint-policy` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

> 接地 pin rust-api `2ad2029` / base-web `0adfd12d`。**零 migration、零新 crate**（6 編輯端點 policy `m002:148-153`＋button/endpoint policy＋button JSON 全波0已備）。
> 階段 2 由 `superpowers:executing-plans` + Workflow 依**實際相依/獨立可審邊界**重組執行單元（不綁本清單編號）。rust **全程 serial**（共用 crate）；容器內 build/test（`--test-threads=1` live）；base-web `--no-verify`；**★ i18n 改後 restart base-web 才能 CDP 驗**（vite locale cache）；★ 絕不 push/merge until finishing。
> **★★ 正確性鐵則**：endpoint 編輯動【真實 (v0=role, v1=path, v2=HTTP method) 列】（require_policy enforce 查的列）；**絕不**用 `v2='endpoint'`/`v1='path:method'` 平行編碼（會建出不驅動 enforce 的假列）。

## Format: `[ID] [P?] [Story] Description with file path`
- `[P]`＝可平行（不同檔、無未完相依）；rust 跨檔仍 serial（共用 crate）、`[P]` 主標 base-web↔rust 跨棧平行。
- `[US1/US2/US3]`＝對應 spec user story；Setup/Foundational/Polish 無 story label。
- 對外碼：updateRoleButton/Endpoints Applied（含空-diff）→`0000`；撤含 protected Rejected→`2222`；非 R_SUPER→`5003`。

---

## Phase 1: Setup

- [ ] T001 驗證前置（psql 經 postgres 容器）：6 編輯端點 policy（getAllButtons/getRoleButton/updateRoleButton/getAllEndpoints/getRoleEndpoints/updateRoleEndpoints、`m002:148-153`、protected=true R_SUPER）＋button policy（v2='button' 16 筆）＋endpoint policy（v2∈HTTP method 39 筆／15 protected）＋`sys_menu.buttons` JSON（`m002:209-240`）皆在 `casbin_rule`/`sys_menu`；dev stack `up --wait`；確認在 `016-button-endpoint-policy` branch。**無新 migration/crate**（C-V-0 前置）

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ 阻擋 endpoint（US2）與治理（US3）；button（US1）獨立、不依此。**

- [ ] T002 endpoint 維度共用基元：`const HTTP_METHODS:&[&str]=&["GET","POST","PUT","DELETE","PATCH"]` + endpoint-列辨識 helper（`v2 ∈ HTTP_METHODS`）in `rust-api/server/src/auth/enforce.rs`（或 `model/facade/sys_casbin_rule.rs`）——供 US2 `set_role_endpoints` read-current 與 US3 回收桶 dimension filter 共用（D2/D3；阻 US2/US3）

## Phase 3: User Story 1 — 角色操作按鈕權限編輯：可復原、即時生效 (P1) 🎯 MVP

**Goal**：超管編輯某角色 button 權限（grant/revoke）→ 撤的進回收桶可復原、getUserInfo buttons 即時反映。
**Independent Test**：撤一 button→psql casbin v2='button' 列無＋archive 有＋getUserInfo 不含；grant→含；restore→回現役。**（�撿現成、復用 011+015、不需 endpoint/多副本）**

- [ ] T003 [US1] `all_buttons(conn)` facade（讀全 active `sys_menu.buttons` JSON〔`{code,desc}`〕→ `Vec<Button{code,label:=desc}>` 字典序去重）in `rust-api/server/src/model/facade/sys_menu.rs`（entity:: 在 facade 合法）（D1）
- [ ] T004 [US1] `button_codes_for_role(enforcer, role_code)` helper（鏡像 `buttons_for_roles:132-146`、單角色 v2='button' v1 集）in `rust-api/server/src/auth/enforce.rs`（D1）
- [ ] T005 [US1] handler `getAllButtons`（GET、`Vec<Button>`）/`getRoleButton`（GET、`Vec<String>` codes）/`updateRoleButton`（POST `{roleId,buttonCodes}`→`set_role_dimension(&role.code,"button",&codes,..)`→Ok→`reload_and_publish`／Rejected→2222／Db→5000）+ Button DTO（camelCase honest）in `rust-api/server/src/handler/system_manage.rs`（D1；reuse set_role_dimension+015 archive 免費繼承；依 T003/T004）
- [ ] T006 [US1] main.rs 註冊 3 button route（require_policy R_SUPER、enforce_mw 兩層、m002 seed 已備）in `rust-api/server/src/main.rs` + **`AS_BUILT_ROUTES` 37→40** in `rust-api/server/tests/endpoint_coverage_lint.rs`（D1；依 T005）
- [ ] T007 [P] [US1] base-web typings：`Button{code:string,label:string}` + `RoleButtonUpdate{roleId:number,buttonCodes:string[]}`（rev3-inline、不動 frozen `system-manage.d.ts`）in `base-web/src/typings/api/rev3-system-manage.d.ts`（D4；honest）
- [ ] T008 [P] [US1] base-web service：`fetchGetAllButtons()→Button[]`/`fetchGetRoleButton(roleId)→string[]`/`fetchUpdateRoleButton(roleId,buttonCodes)→null`（request<T>、roleId 維 number ⚠️r）in `base-web/src/service/api/rev3-system-manage.ts`（D4；依 T007）
- [ ] T009 [US1] base-web `button-auth-modal.vue` **un-mock**（鏡像 `menu-auth-modal`：watch visible→init→`fetchGetAllButtons`+`fetchGetRoleButton`→NTree checkable〔key=code〕→handleSubmit `fetchUpdateRoleButton`→reload）in `base-web/src/views/manage/role/modules/button-auth-modal.vue`（D4；MODAL-WIRING (c)；依 T008）
- [ ] T010 [US1] live button（in-crate `#[ignore]`、容器內 `--test-threads=1`、`DATABASE_URL`、trace_id `"016-button-smoke"`、snapshot-restore guard 自清）in `sys_casbin_rule.rs`（或 archive test mod）：updateRoleButton 撤一非保護 code→psql casbin v2='button' 列無＋archive 有（archive_reason='role_dimension_revoke'）／grant→新列／restore→回＋archive 消費＋審計／`button_codes_for_role` 反映（C-V-2；依 T005）

**✅ Checkpoint US1**：MVP 可獨立交付驗（button 編輯/回收桶/UI）。

## Phase 4: User Story 2 — 角色 API 端點存取權限編輯：受保護核心防誤鎖、可復原 (P2)

**Goal**：超管編輯某角色 endpoint 權限（(path,method) grant/revoke）→ enforce 即時反映；撤含受保護核心→整批拒防鎖出；撤的可復原。
**Independent Test**：撤一非保護 (path,method)→psql 列無＋archive＋enforce 拒；撤含 protected→Rejected 零變更＋恢復路徑在；restore→回。**（依 T002）**

- [ ] T011 [US2] ★ 新 `set_role_endpoints<C:TransactionTrait>(conn, role_code, desired:&[(String,String)]/*（path,method）*/, meta, role_id) -> Result<SetEndpointsOutcome{changed}, SetEndpointsError{Db,Rejected(Vec<(String,String)>)}>` in `rust-api/server/src/model/facade/sys_casbin_rule.rs`：single `mutate_in_txn`——read-current（`v0=role ∧ v2∈HTTP_METHODS`）→ (path,method) 雙鍵 diff → **protected-reject**〔含 protected→Rejected 帶被擋 (path,method)、零變更、任何寫之前〕→ revoke（`insert_archived(reason="role_endpoint_revoke")`+DELETE 同 txn）→ grant（insert `v1=path,v2=method`）→ op-log。**★ 動真實 (role,path,method) 列、不用 v2='endpoint'**；治理 helper 全復用 015（D2；依 T002；§4.2 ①②④）
- [ ] T012 [US2] `ALL_ENDPOINT_POLICIES:&[(&str,&str)]` const（全部可授權 (path,method)、含本刀 6 個、registry 完整穩定）+ `endpoint_pairs_for_role(enforcer, role_code)` helper（讀該 role v2∈HTTP_METHODS 的 (v1,v2)）in `rust-api/server/src/auth/enforce.rs`（D3；依 T002）
- [ ] T013 [US2] handler `getAllEndpoints`（GET、自 const→`Vec<Endpoint{path,method,label?}>`）/`getRoleEndpoints`（GET、`Vec<Endpoint>`）/`updateRoleEndpoints`（POST `{roleId,endpoints}`→`set_role_endpoints`→Ok→`reload_and_publish`／Rejected→2222 `biz.role.endpointProtected`〔帶被擋〕／Db→5000）+ Endpoint DTO（camelCase honest）in `rust-api/server/src/handler/system_manage.rs`（D3；依 T011/T012）
- [ ] T014 [US2] main.rs 註冊 3 endpoint route（require_policy R_SUPER、m002 seed）in `rust-api/server/src/main.rs` + **`AS_BUILT_ROUTES` 40→43** + **registry 防漂移 assertion**（`ALL_ENDPOINT_POLICIES` ⊇ registered policy-governed endpoint）in `rust-api/server/tests/endpoint_coverage_lint.rs`（D3；依 T013/T012）
- [ ] T015 [P] [US2] base-web typings：`Endpoint{path:string,method:string,label?:string}` + `RoleEndpointsUpdate{roleId:number,endpoints:Endpoint[]}`（rev3-inline）in `base-web/src/typings/api/rev3-system-manage.d.ts`（D4；honest）
- [ ] T016 [P] [US2] base-web service：`fetchGetAllEndpoints()→Endpoint[]`/`fetchGetRoleEndpoints(roleId)→Endpoint[]`/`fetchUpdateRoleEndpoints(roleId,endpoints)→null` in `base-web/src/service/api/rev3-system-manage.ts`（D4；依 T015）
- [ ] T017 [US2] base-web **新** `endpoint-auth-modal.vue`〔**MODAL-WIRING (c)**、鏡像 button-auth、樹狀/列表顯 (path,method)〔可按 path 群組〕、hard-replace `fetchUpdateRoleEndpoints`〕+ `role-operate-drawer.vue` 第三 useBoolean+鈕 `$t('page.manage.role.endpointAuth')`+`<EndpointAuthModal>` 掛載 + **i18n 先 Schema 後 locale**（`app.d.ts` page.manage.role.endpointAuth〔+modal 標籤〕、zh-cn/en-us、`backend.biz.role.endpointProtected` BASE-WEB-I18N-WIRING）in `base-web/src/views/manage/role/modules/{endpoint-auth-modal.vue,role-operate-drawer.vue}` + `base-web/src/typings/app.d.ts` + `base-web/src/locales/langs/{zh-cn,en-us}.ts`（D4；依 T016；base-web-i18n-schema gotcha）
- [ ] T018 [US2] live endpoint（in-crate `#[ignore]`、`--test-threads=1`、trace_id `"016-endpoint-smoke"`、snapshot-restore）in `sys_casbin_rule.rs`：set_role_endpoints 撤一非保護 (path,method)→psql 該列無＋archive（reason='role_endpoint_revoke'）／grant→新列／**enforce 反映**（撤後該 role enforce 該 endpoint 被拒）／**★ 鎖出**：撤含 protected〔如 updateRoleEndpoints/getRoleMenu〕→Rejected〔帶被擋〕、現役與 archive 皆零變更、恢復路徑在／restore→回（C-V-3；依 T011）

**✅ Checkpoint US2**：endpoint 編輯/鎖出守門/回收桶/UI 可獨立驗。

## Phase 5: User Story 3 — 三維授權治理統一：回收桶涵蓋三維＋跨副本收斂 (P3)

**Goal**：回收桶統一三維（可依維度區分）＋button/endpoint 跨副本收斂。
**Independent Test**：撤 button/endpoint→回收桶列出、dimension 顯 button/endpoint、filter 命中；2 副本 A 改→B 收斂。
> archive/restore 已於 US1（button via set_role_dimension）/US2（endpoint via set_role_endpoints）自動進回收桶；本 phase = 三維【顯示/filter 統一】+【精準 gate 獨立驗】+【跨副本】。

- [ ] T019 [US3] 回收桶三維 v2-推導：`getArchivedPolicies` 回應 `dimension` 由 v2 推導（`match v2 {"menu"|"button"=>原值, _=>"endpoint"}`）+ list facade `?dimension=endpoint` filter→`v2 IN HTTP_METHODS`（特例）in `rust-api/server/src/handler/system_manage.rs` + `rust-api/server/src/model/facade/sys_casbin_policy_archive.rs`（D3；**不改 archive_reason**、依 T002；依 015 既有 list/restore）
- [ ] T020 [US3] live gate 精準（in-crate `#[ignore]`、`--test-threads=1`）：updateRoleButton/Endpoints Rejected→**不** `load_policy` **不** publish〔publish 計數=0〕／Applied（含**空-diff** 送相同集合）→**必** reload+publish（鏡像 015 gate 測法、復用 reload_and_publish）in `sys_casbin_rule.rs`（C-V-4；依 T005/T013）
- [ ] T021 [US3] live 2-instance（`$DC --profile multi up -d rust-api-2 --wait`、:31082、shared pg/redis）：副本 A updateRoleButton 撤某 button→psql 證→副本 B `getUserInfo` buttons 反映（watcher 收斂）／A updateRoleEndpoints 撤某 endpoint→B 對該 (role,path,method) enforce 被拒／A restore→B 恢復／`CLIENT KILL TYPE pubsub`→重訂閱仍收斂；id-snapshot op-log 清理＋`--profile multi down`（C-V-6；依 T011/T005/T021 watcher 復用 015）

**✅ Checkpoint US3**：三維治理統一＋跨副本＋gate 精準驗。

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T022 [P] typings 收斂 fold-in（**最低優先、可拆為獨立刀**）：`RoleListItemRev3=Omit<Role,'roleDesc'>&{roleDesc:string|null}`（honest）+ User nickName/userPhone/userEmail rev3-owned 讀型（擴 `UserListItemRev3` 或新型）+ service getRoleList/getUserList 回型改用 in `base-web/src/typings/api/rev3-system-manage.d.ts` + `base-web/src/service/api/rev3-system-manage.ts`（D5；§3.13 Menu.buttons no-op；declaration-merge Omit+intersection、不動 frozen）
- [ ] T023 [P] lints 綠：`entity_access_lint`（新 facade 在 model/facade/ 豁免、handler/main 零 path-root `entity::`）+ `endpoint_coverage_lint`（**AS_BUILT 43**、registered==as-built、Assertion A 6 端點已 seed、registry 防漂移 assertion）in 容器內（C-V-1；依 T006/T014）
- [ ] T024 live policy-gate + CDP 三維 UI：curl Super getAll{Buttons,Endpoints}→200／Admin→403/5003（C-V-5）；**★ 先 `restart base-web`**；CDP `:31080` Super→`/manage/role`→edit drawer **三鈕（選單/按鈕/端點授權）**→button/endpoint modal 真打讀寫+psql 證／撤 protected endpoint→前端 `biz.role.endpointProtected` 在地化／i18n `endpointAuth` resolve（非原始 key、016 memory）（C-V-7；依 T009/T017/T013）
- [ ] T025 零回歸 + prod build：`--ignored` 全套綠（menu 011/015 + button/endpoint 新測；archive_reason menu/button vs endpoint 並存、回收桶 v2-推導不破 012 audit_query 基線）／非-ignored 全套綠／`git diff migration/` 空＋up→down→up 綠／base-web `pnpm typecheck`／**prod target image build**（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`）（C-V-8；依全部）
- [ ] T026 final holistic review：§4.2 5 invariants ↔ C-V 對照齊（①DB-first→C-V-2/3／②protected-reject〔endpoint 鎖出〕→C-V-3／③gate→C-V-4／④原子+審計→C-V-2/3／⑤reload+publish 跨副本→C-V-6）；spec SC-001~008 全覆蓋；US1~US3 acceptance 全綠；**★ grep 確認 endpoint 寫端動真實 (v0,v1=path,v2=method) 列、無 v2='endpoint' 平行編碼**

---

## Dependencies & 執行順序

```
Setup(T001) → Foundational(T002 endpoint 共用基元；US1 不依)
  → US1〔T003 all_buttons, T004 button_codes_for_role, T005 handlers, T006 routes+AS_BUILT 40, T007∥T008 base-web, T009 button-auth un-mock, T010 live〕  ← MVP（撿現成、reuse 011+015）
  → US2〔T011 set_role_endpoints〔★雙鍵 diff、真實列〕, T012 registry const+helper, T013 handlers, T014 routes+AS_BUILT 43+registry assertion, T015∥T016 base-web, T017 endpoint-auth-modal+drawer+i18n, T018 live〔含鎖出〕〕  （依 T002）
  → US3〔T019 回收桶 v2-推導, T020 gate 精準, T021 2-instance〕  （依 US1+US2）
  → Polish〔T022 typings 收斂〔可拆〕, T023 lints, T024 curl+CDP, T025 零回歸+prod build, T026 holistic〕
```
- **rust 全程 serial**（T002-T006,T010-T014,T018-T021 共用 crate、即使不同檔不平行 cargo）。
- **跨棧平行**：base-web（T007/T008、T015/T016 `[P]`）可與 rust 平行；modal（T009/T017）依各自 service。
- **每 worktree commit 落地即 bump submodule pin**（§4.1 S9、逐單元邊界、不延末刀）。

## Parallel 機會
- US1 內：rust 串（T003→T004→T005→T006）∥ base-web 串（T007→T008→T009）；匯於 T010 live。
- US2 內：rust 串（T011→T012→T013→T014）∥ base-web 串（T015→T016→T017）；匯於 T018 live。
- T022 typings 收斂、T023 lints 可在 impl 後平行（base-web/只讀）。

## Implementation Strategy
- **MVP = US1**（button 撿現成、reuse 011 set_role_dimension + 015 治理島免費繼承）：可獨立交付驗。其後 US2（endpoint 新雙鍵 facade + 鎖出守門）、US3（治理統一 + 跨副本）為增量。
- 階段 2 `executing-plans`：每執行單元一支 Workflow（implementer TDD→spec-compliance review→fix↔loop→code-quality review），主線單元邊界 checkpoint（git show --stat 自核 + 容器內自驗 + bump pin）→ 啟下一支；全完成 final holistic → `finishing-a-development-branch`（push/merge 需 user 同意）。**★ i18n 改後 restart base-web 才 CDP 驗**。
- **無單元測試之單元**（wiring/形狀類：T005/T013 handler、T006/T014 route、T009/T017 base-web view）由 acceptance（C-V）覆蓋；純測者（set_role_endpoints 雙鍵 diff/鎖出邏輯）由 in-crate `#[ignore]` live 覆蓋（T010/T018/T020）。
- **D5 typings 收斂（T022）可拆**：若 016 scope 過大、可移獨立 typings-收斂刀（讀端型謊、runtime 已容忍）。
