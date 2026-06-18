# Tasks: 009-user-management（使用者 CRUD＋角色 M:N＝波2 資料島首刀）

**Input**: Design documents from `/specs/009-user-management/`

**Prerequisites**: plan.md ✅、spec.md ✅（6 US／12 FR／11 SC＋2 Clarifications）、research.md（R1 零 migration・R2 sys_role 欄名・R3 hasAuth 延波2・R4-R11 grep ground-truth）✅、data-model.md ✅、contracts/（verification-commands C-V-0~14＋user-management-contract）✅、quickstart.md ✅；constitution **v1.1.1**（9/9 PASS）。

**Tests**: 本 feature **有純函式測＋活體測＋lint**（constitution §I.4 TDD）。純測＝in-crate `#[cfg(test)]`（filter/page normalize／escape_like／wire mapper／facade `build_*_active_model`，**test-first red→green**）；活體＝live psql/curl（`#[ignore]` `--test-threads=1`：addUser INSERT op-log INET／23505 dup／updateUser self-lock／delete cannot-delete-self／policy-gate 5003／停用登入）；lint＝`endpoint_coverage_lint`（bump +6）＋既有 `entity_access_lint`。

**Organization**: 依 user story 分 phase。**★ 校正（research）**：零 migration（6 端點 policy＋表＋partial-unique 已 m001/m002/m003 seed）；**sys_role 欄＝`code`/`name`/`role_desc`+`home`**（非 role_code/role_name、R2）；**前端 hasAuth gating 延波2 Menu 刀**（R3、本刀只 MODAL-WIRING (a)）；23505 走寫端 `sql_err()` map（⚠️o、不動 blanket From）。**rust 全程 serial**、build/test **容器內** `docker compose … exec -T rust-api`（改 `.rs` 先 force-touch 防 stale-mtime；`--test <name>` 跑整支、防 bare-filter 假綠）；**live `#[ignore]` 一律 `--test-threads=1`＋`DATABASE_URL`**；base-web commit `--no-verify`；**逐單元兩段式 commit**（rust-api／base-web worktree→outer pin、S9 不延後）；**§I.4：全程不 push/merge**。**無新 crate／無新 dep**；**讀（getUserList/getAllRoles）用既有 `system-manage.ts` fn**（rust 補端點即生效），**只 4 寫端走新 `rev3-system-manage.ts`**（WRAPPER §III.1）。

## Format: `[ID] [P?] [Story?] Description`

## Phase 1: Setup

- [ ] T001 親驗前置（research R1）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait` 全 healthy；grep `rust-api/migration/src/m002_rev2_seeds.rs` 確認 6 端點 p-policy 已 seed（getUserList GET[R_SUPER,R_ADMIN]／getAllRoles GET[R_SUPER,R_ADMIN,R_USER_COMMON]／addUser·updateUser POST[R_SUPER]／deleteUser·batchDeleteUser DELETE[R_SUPER]）＋`sys_user_user_name_active_uniq` partial-unique（m001）＝本刀**零 migration、無新 crate/dep**

**Checkpoint**: 環境就緒、6 policy 已在（無 migration）

## Phase 2: Foundational（blocking US1~US4：共享 facade seam＋純函式）

- [ ] T002 [P] sys_user_role facade 3 fn 於 `rust-api/server/src/model/facade/sys_user_role.rs`（`roles_of_user` L11 不動）：`role_ids_of_user(conn,uid)->Vec<i64>`／`roles_for_users(conn,&[i64])->HashMap<i64,Vec<String>>`（批次、無 N+1、固定查詢、code）／`replace_roles_in_txn(txn,uid,&[code])`（delete-all+insert-all、code→role_id 經 sys_role find_active 解析、未知/已刪靜默丟）（data-model §2）
- [ ] T003 [P] sys_role facade `find_active(conn)->Vec<Model>` 於 `rust-api/server/src/model/facade/sys_role.rs`（現零 query fn；getAllRoles＋replace_roles 解析用；R2 欄 `code`/`name`）（data-model §3）
- [ ] T004 [P] 純函式 helper（**test-first red→green**）於 `rust-api/server/src/handler/system_manage.rs`（新檔；`handler/mod.rs` 加 `pub mod system_manage;`）：filter normalize（空字串→None：字串 `.filter(|v|!v.is_empty())`／gender·status `Some("")→Ok(None)` 再 parse i16）／`escape_like(raw)`（`\`→`\\`、`%`→`\%`、`_`→`\_`、backslash 先）／page normalize（current 默 1·max(1)／size 默 10·clamp[1,100]）／wire mapper（id 2^53 fail-loud／i16→`'1'/'2'`／`Option<i64>→string|""`）。純測：C-V-1/C-V-3（data-model §5、research R6）
- [ ] T005 [P] base-web wrapper skeleton（WRAPPER §III.1、首批 user rev3-* 檔）：`base-web/src/service/api/rev3-system-manage.ts`（`import {request} from '../request'`、view 直接路徑 import 非 barrel）`fetchAddUser`/`fetchUpdateUser`/`fetchDeleteUser`/`fetchBatchDeleteUser`（4 寫端）＋`base-web/src/typings/api/rev3-system-manage.d.ts`（ADAPT、declaration-merge `Api.SystemManage`）`UserUpsertModel`（write DTO、不改既有 system-manage.d.ts）（data-model §11、research R-D §6）

**Checkpoint**: 共享 facade seam＋純函式（純測綠）＋base-web wrapper 骨架就緒

## Phase 3: US1 — 管理員瀏覽與搜尋使用者 (P1) 🎯 MVP

**Goal**: 授權管理員分頁/搜尋 user list（模糊 userName/nickName/userEmail、精確 userPhone/enum、空字串跳過、超範圍頁空 records+真 total、零 password）。
**Independent Test**: C-V-9（curl 帶空 param 回全部非 0／模糊子字串／精確／超範圍頁／無 password）；不依賴寫。

- [ ] T006 [US1] sys_user facade `list_active(conn,page,size,UserFilter)->Result<(Vec<Model>,u64),DbErr>` 於 `rust-api/server/src/model/facade/sys_user.rs`（`SoftDeletable::find_active().apply_if(ilike/eq).order_by_desc(Column::Id).paginate(conn,size)`→`num_items()`+`fetch_page(page)`；`use sea_orm::sea_query::extension::postgres::PgExpr`；userName/nickName/userEmail `Expr::col(col).ilike(LikeExpr::new(format!("%{}%",escape_like(t))).escape('\\'))`、userPhone/gender/status `.eq`）（data-model §1、research R6/R7）
- [ ] T007 [US1] handler `get_user_list(State,Extension<Claims>,Query<UserSearchQuery>)->Res<PageRes<UserListItem>>`（filter/page normalize〔T004〕→`list_active`→`roles_for_users`〔T002〕組 `user_roles`→`UserListItem` camelCase **零 password**、id=number、gender/status→str、createBy/updateBy→str、createTime/updateTime→rfc3339）於 handler/system_manage.rs（data-model §5/§9）
- [ ] T008 [US1] `rust-api/server/src/main.rs` 加 `users` 子 router 註冊 `GET /systemManage/getUserList`（`route_layer(require_policy("/systemManage/getUserList","GET"))`＋外層 `enforce_mw`、`.merge(users)`；鏡像 008 main.rs:99-121）＋`endpoint_coverage_lint` `AS_BUILT_ROUTES [&str;5]→[&str;6]`（+getUserList、同 commit）（data-model §8/§12、research R11）
- [ ] T009 [US1] C-V-9 live：Super token→`getUserList` 帶**空 param**（records 非空+真 total）／模糊 `userName=us`（子字串）／精確 `userPhone`／超範圍 `current=999`（空 records+真 total）／回應**無 password**。對應 SC-001/SC-002

**Checkpoint**: US1 全綠＝MVP（既有 index.vue+fetchGetUserList 即顯真資料、無 base-web 改）→ **雙段 commit**（rust-api worktree→pin）

## Phase 4: US2 — 新增使用者並指派角色 (P2)

**Goal**: super addUser（預設密碼 argon2、指派角色、唯一 userName、INSERT op-log）；getAllRoles 下拉。
**Independent Test**: C-V-6（addUser→psql user+role+op-log INSERT 真 INET；dup userName→2222）。

- [ ] T010 [P] [US2] auth `hash_password(plain)->Result<String,_>`（`Argon2::default()`+`SaltString::generate(&mut OsRng)`、對齊 m002 seed+既有 verify）+純測 於 `rust-api/server/src/auth/password.rs`（既有 verify／`#[cfg(test)] hash` 不動）（data-model §4）
- [ ] T011 [US2] sys_user facade `create(conn,UserWrite,password_hash,operator,trace)->Model`（`mutate_in_txn`：ActiveModel set 基本欄+created_at/created_by+session_policy "inherit"→`am.insert(&txn)`→**INSERT op-log `entity_id:Some(after.id)`/before:None/after:audit_json**〔首個 Insert constructor〕）+`build_create_active_model` 純測 於 sys_user.rs（research R8、data-model §1）
- [ ] T012 [US2] handler `get_all_roles(State,Extension<Claims>)->Res<Vec<AllRoleItem>>`（sys_role `find_active`〔T003〕→map `code→roleCode`/`name→roleName`/id number）於 handler/system_manage.rs（R2、data-model §5）
- [ ] T013 [US2] handler `add_user(State,Extension<RequestContext>,Extension<Claims>,Json<UserUpsertReq>)->Res<()>`（`hash_password("123456")`〔T010〕→`ctx.to_audit_operator`→`create`+`replace_roles_in_txn` 同 txn；**寫端 `.map_err(sql_err→Some(UniqueConstraintViolation)→Biz("biz.user.duplicateUserName") else Internal)`**、禁裸 `?`）於 handler/system_manage.rs（research R5、data-model §5/§7）
- [ ] T014 [US2] `main.rs` 註冊 `POST /systemManage/addUser`＋`GET /systemManage/getAllRoles`（各 `route_layer(require_policy)`、入 `users` 子 router）＋`endpoint_coverage_lint` `[&str;6]→[&str;8]`（+addUser/getAllRoles、同 commit）
- [ ] T015 [P] [US2] base-web（MODAL-WIRING (a)）：`base-web/src/views/manage/user/modules/user-operate-drawer.vue` `handleSubmit`(:105) 於 `await validate()` 後分支 `props.operateType` add→`fetchAddUser`〔T005〕＋**移除 getRoleOptions mock workaround(:81-87)**→`roleOptions.value = options`（真 getAllRoles）；`rev3-inline MW(a)` 原行註解保留。i18n：`base-web/src/locales/langs/{zh-cn,en-us}.ts` 加 `backend.biz.user.duplicateUserName`（I18N-WIRING (ii)、⚠️y）
- [ ] T016 [US2] C-V-6 live（`#[ignore]` `--test-threads=1` `DATABASE_URL`）：addUser→psql `sys_user` 新列（argon2 `verify("123456")` 通過）+`sys_user_role`(roles)+`sys_operation_log` 末列 INSERT/entity_id/operator_ip 真 INET/trace；**重複 user_name→Biz 2222 非 5000**。對應 SC-003

**Checkpoint**: US2 全綠（新增+角色+審計+唯一）→ **雙段 commit**（rust-api／base-web worktree→pin）

## Phase 5: US3 — 修改使用者資料與角色 (P2)

**Goal**: super updateUser（userName/password 不動、角色整批替換、UPDATE op-log、self-lock 防護）。
**Independent Test**: C-V-7（update 不動帳密+roles 替換+op-log；self-demote/disable→2222）。

- [ ] T017 [US3] sys_user facade `update(conn,id,UserWrite,operator,trace)->Option<Model>`＋`find_active_by_id(conn,id)`（`mutate_in_txn`：find_active_by_id None→Ok(None)；命中→into_active_model set 基本欄+updated_at/updated_by 成對、**不 set user_name/password**→`am.update`→UPDATE op-log `entity_id:Some(id)`/before+after audit_json）+`build_update_active_model` 純測 於 sys_user.rs（data-model §1）
- [ ] T018 [US3] handler `update_user(...Json<UserUpsertReq>)->Res<()>`（id `String→i64` fail→`Biz("biz.user.notFound")`；**self-guard**：`id==claims.uid && (R_SUPER ∉ user_roles || status==Some("2"))`→`Biz("biz.user.selfLockForbidden")` 2222 整筆不執行；`update` None→`Biz("biz.user.notFound")`+`replace_roles_in_txn` 同 txn；寫端 sql_err map）於 handler/system_manage.rs（data-model §5、spec FR-004/clarify Q1）
- [ ] T019 [US3] `main.rs` 註冊 `POST /systemManage/updateUser`（route_layer require_policy、入 users）＋`endpoint_coverage_lint` `[&str;8]→[&str;9]`（同 commit）
- [ ] T020 [P] [US3] base-web（MODAL-WIRING (a)）：`user-operate-drawer.vue` `handleSubmit` edit 分支→`fetchUpdateUser({...model, id: props.rowData.id})`〔T005〕。i18n 加 `backend.biz.user.{notFound,selfLockForbidden}`
- [ ] T021 [US3] C-V-7 live：updateUser→`user_name`/`password` hash 不變（psql 比對）+`sys_user_role` 替換+op-log UPDATE；查無 id→notFound；**self 移除超管/設停用→selfLockForbidden 2222、DB 無變**。對應 SC-004

**Checkpoint**: US3 全綠（修改+self-guard）→ **雙段 commit**

## Phase 6: US4 — 刪除/批次刪除使用者 (P2)

**Goal**: super soft-delete 單/批；cannot-delete-self 整批拒；批次缺漏 idempotent 略過。
**Independent Test**: C-V-8（soft-delete；self→2222 整批拒；缺漏略過）。

- [ ] T022 [US4] handler `delete_user(...Json<IdReq>)`／`batch_delete_user(...Json<IdsReq>)->Res<()>`（id parse String→i64；**self in ids→`Biz("biz.user.cannotDeleteSelf")` 整批拒、無 partial**；複用既有 `facade::sys_user::soft_delete`〔L47〕loop、已不存在/已刪 id no-op 靜默略過）於 handler/system_manage.rs（data-model §5、spec FR-005/clarify Q2）
- [ ] T023 [US4] `main.rs` 註冊 `DELETE /systemManage/deleteUser`＋`DELETE /systemManage/batchDeleteUser`（route_layer require_policy、入 users）＋`endpoint_coverage_lint` `[&str;9]→[&str;11]`（+2、同 commit；6 user 路由全註冊完成）
- [ ] T024 [P] [US4] base-web（MODAL-WIRING (a)）：`base-web/src/views/manage/user/index.vue` `handleDelete`(:154)→`fetchDeleteUser(id)`／`handleBatchDelete`(:147)→`fetchBatchDeleteUser(checkedRowKeys)`〔T005〕（去 console.log stub、`rev3-inline MW(a)` 原行註解保留）。i18n 加 `backend.biz.user.cannotDeleteSelf`
- [ ] T025 [US4] C-V-8 live：delete/batch→`deleted_at`/`deleted_by` 成對、`find_active` 不再現、op-log SOFT_DELETE；**含 operator 自身（單/批）→2222 整批拒、DB 無變**；批次含已刪 id→略過、有效照刪。對應 SC-005

**Checkpoint**: US4 全綠（刪除+self-guard+idempotent）→ **雙段 commit**

## Phase 7: US5 — 依角色授權存取（越權防護） (P2)

**Goal**: 非授權（已認證）→403/5003 不洩；授權守恆。require_policy 復用 008、本 phase＝驗收+lint。
**Independent Test**: C-V-10（Admin 寫 403／User 讀 403）；C-V-4（endpoint_coverage_lint）。

- [ ] T026 [US5] C-V-4：`cargo test -p server --test endpoint_coverage_lint`（registered `[&str;11]`==as-built＋6 policy-governed route 皆對應 m002 p-policy seed、Assertion A/B 綠）＋`entity_access_lint` 守恆（handler/error/main 零 path-root `entity::`）。對應 FR-010/SC-009
- [ ] T027 [US5] C-V-10 live policy-gate（DB-fresh roles、不信 claims.roles）：Super 6 端點通過；**Admin 讀 getUserList 200／寫 addUser·deleteUser→403/5003**；**User 讀 getUserList→403/5003**；不洩使用者資料。對應 SC-006

**Checkpoint**: US5 全綠（5003 越權防護＋三守恆）→ **commit**

## Phase 8: US6 — 停用使用者無法登入 (P3)

**Goal**: 停用 user（status=2）無法重新登入、回統一失敗（防枚舉）；只擋新登入。
**Independent Test**: C-V-10（停用 user 登入→1000）。

- [ ] T028 [US6] `rust-api/server/src/handler/auth.rs` `login_inner` 密碼 `password::verify` 通過後（auth.rs:76 後、`let uid=model.id` 前）加 `if model.status == Some(2) { return Err((Some(model.id), AppError::LoginFailed)); }`（code 1000 統一失敗、復用既有碼/i18n、防枚舉；status 已在 find_by_user_name 回的 Model）（research R10、data-model §6）
- [ ] T029 [US6] C-V-10 live：Super 設某 user status=2（updateUser）→該 user `auth/login`→`code:"1000"`（與帳密錯同訊息、不洩停用）；啟用 user 登入正常。對應 SC-007

**Checkpoint**: US6 全綠（停用 gate）→ **雙段 commit**

## Phase 9: Polish & Cross-Cutting

- [ ] T030 [P] C-V-0 build `--locked`（容器內 force-touch、無新 dep）＋C-V-12 base-web `pnpm typecheck`（rev3-system-manage.ts+UserUpsertModel 對齊既有 User/UserSearchParams/AllRole、wire 3 端零型謊；`--no-verify` commit）
- [ ] T031 C-V-11 CDP 經 front-nginx 真 `/api` 全鏈：Super 登入→/manage/user 頁→搜尋（**刻意空 param 回全部+模糊 userName**）→新增（填表+角色 chip 真 code→**真發 addUser**→toast+列現新列）→編輯（改暱稱/角色→真發 updateUser）→刪除（NPopconfirm→真發 deleteUser→列消失）→批次刪→真發 batchDeleteUser；2222 toast 經 `$t` 在地化；非 super→403。對應 SC-008（★斷言真發 request、非 toast）
- [ ] T032 C-V-14 prod target image build（`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`、無新 crate→輕、確認新 facade/handler/login gate/error map/lint 編入）
- [ ] T033 C-V-13 零回歸收口：`/health` ok；`enforce_mw`/`require_policy`/`From<DbErr>`(blanket)/`audit_mw`/login 既有流程/getUserInfo/008 settings 不變；diff **零 migration/entity/schema**；base-web 既有 system-manage.ts/.d.ts/auth.ts/request 攔截器**不改**（只新增 rev3-* wrapper/typings/MODAL-WIRING (a) inline/locale 加 key、fork-delta rev3-inline）；quickstart 15 步逐步綠。對應 SC-010

## Dependencies

```
Setup (T001) ─→ Foundational (T002 sys_user_role／T003 sys_role find_active／T004 純函式 helper〔test-first〕／T005 base-web wrapper)  [rust serial、[P]=不同檔/worktree 可並行撰寫]
Foundational ──┬─→ US1 (T006 list_active→T007 handler→T008 main+lint→T009 live)   [MVP；base-web 讀無需改]
               ├─→ US2 (T010 hash_password〔P〕／T011 create→T012 getAllRoles→T013 add_user+23505→T014 main+lint／T015 base-web〔P〕→T016 live)
               ├─→ US3 (T017 update+find_active_by_id→T018 update_user+self-guard→T019 main+lint／T020 base-web〔P〕→T021 live)
               ├─→ US4 (T022 delete/batch handler→T023 main+lint／T024 base-web〔P〕→T025 live)   [複用既有 soft_delete]
               ├─→ US5 (T026 lint 守恆／T027 policy-gate live)        [require_policy=008 既有、本 phase 驗收]
               └─→ US6 (T028 login gate→T029 live)                    [auth.rs、獨立]
US1~US6 ──→ Polish (T030 build+typecheck／T031 CDP／T032 prod build／T033 零回歸)
```

## Parallel Execution Examples

- **Foundational 並行撰寫**：T002（sys_user_role）∥ T003（sys_role）∥ T004（handler 純函式、不同檔）∥ T005（base-web worktree）——皆 [P]、不同檔/worktree。
- **每 US 的 base-web [P]**：T015/T020/T024（base-web worktree）∥ 該 US rust task——base-web 與 rust-api 不同 worktree、可並行撰寫。
- **rust 內部不 [P]**（共享 cargo target、serial）；[P] 僅表「不同檔/worktree 可並行撰寫」、cargo build/test 一次一個。
- **US5 多為 acceptance/lint**（require_policy 機制 008 既有；6 路由的 route_layer 已在 US1~US4 各自 main task 掛）；可緊接驗、彈性併 commit。

## Implementation Strategy

**MVP first**：Phase 1→3（T001~T009）＝Setup＋Foundational（共享 facade seam＋純函式 test-first）＋US1（getUserList 全鏈：list_active→handler→main+lint→live；既有 index.vue 即顯真資料）＝最小價值（瀏覽/搜尋成立）。US2 新增（T010~T016）／US3 修改（T017~T021）／US4 刪除（T022~T025）緊接；US5 越權驗收+lint（T026~T027）／US6 停用 gate（T028~T029）；Polish 收口（build/typecheck/CDP/prod/零回歸）。每 phase checkpoint 過才前進；任一 C-V fail＝修復重跑、不帶病前進。**★ lint 逐路由 bump**（T008 [6]／T014 [8]／T019 [9]／T023 [11]）保每 checkpoint endpoint_coverage_lint 綠。**rust serial、容器內 build/test、改 .rs 先 force-touch、live `--test-threads=1`；逐單元兩段式 commit（worktree→pin、S9 不延後）；base-web `--no-verify`；全程不 push/merge（§I.4）。**

> **階段 2 交棒注記**（CLAUDE.md §3）：實作以 `superpowers:executing-plans` 起手、**Workflow 驅動**，依**實際相依/獨立可審邊界**重分執行單元（不綁本檔編號）——預期 **U1 reads**（Foundational T002-T004＋US1 getUserList＋US2 getAllRoles read 面）／**U2 create·update**（hash_password＋create/update facade＋add_user/update_user＋23505＋self-guard＋INSERT/UPDATE op-log）／**U3 delete·gate**（delete/batch＋cannot-delete-self＋US6 login gate）／**U4 base-web MODAL-WIRING (a)**（rev3-system-manage.ts wrapper＋drawer/index.vue 接線＋移除 mock＋i18n）為 4 load-bearing 單元；US5 越權 acceptance+lint 散入各 rust 單元邊界自驗。每單元邊界主線 `git show --stat HEAD` 復核＋容器內自驗＋bump submodule pin。
