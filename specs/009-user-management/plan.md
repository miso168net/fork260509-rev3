# Implementation Plan: 009-user-management（使用者 CRUD＋角色 M:N＝波2 資料島首刀）

**Branch**: `009-user-management` | **Date**: 2026-06-18 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/009-user-management.md`（波2 資料島首刀；plan-phase research 親驗校正見下）

## Summary

波 2 資料島首刀＝把 `/manage/user` 從 mock 切到真 rust-api：**6 端點 CRUD**（getUserList／getAllRoles／addUser／updateUser／deleteUser／batchDeleteUser）＋角色 M:N join，達成多個「全專案首次」：**§5.8 分頁/filter 首 exercise**（含空字串守門＋**模糊查詢**〔userName/nickName/userEmail ILIKE、userPhone/enum 精確〕、`PageRes` 首消費者）／**M:N join 寫**（`replace_roles_in_txn` 與 user 寫入同 txn）／**prod argon2 `hash_password`**／**23505→2222 首落地**（⚠️o：`sql_err()` 於寫端、不動 blanket `From<DbErr>`）／**首個 INSERT op-log consumer**（addUser、`entity_id=Some(after.id)`）／**停用登入 gate**（status==2→1000）。沿 008 已立的 `require_policy`/op-log threading/envelope/`endpoint_coverage_lint` 骨架。**零 migration／零 schema／零 entity 改／無新 crate**。

**plan-phase research 三大親驗校正**（act-on-code、見 [research.md](research.md)）：
1. **sys_role 欄名＝`code`/`name`/`role_desc`＋`home`**（**非** role_code/role_name；brainstorm 抽象命名與實況偏差）→ getAllRoles DTO 映 `code→roleCode`/`name→roleName`。
2. **23505→2222 落點＝寫端 `e.sql_err()` map**（⚠️o），**不改** blanket `From<DbErr>→Internal(5000)`（error.rs:111 deferral 註解兌現）。
3. **前端 hasAuth gating 延波2 Menu 刀**（base-web 整個 manage/ 現零 hasAuth、008 亦同；授權靠後端 403、前端可見性收於 Menu 刀＝D1 follow-up 家族）→ 本刀 MODAL-WIRING 只做 **(a) 接線**、不做 (b) gating；spec FR-011 已校正。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-api、`rust-toolchain.toml` pin）＋TypeScript/Vue 3（base-web、soybean-admin fork）

**Primary Dependencies**: server **無新增 dep／無新 crate**（既有 sea-orm 1.1.20〔`macros`+`sqlx-postgres`+`runtime-tokio-rustls`〕／axum 0.7／argon2／casbin）。`PgExpr::ilike`／`LikeExpr`／`apply_if`／`PaginatorTrait`／`SqlErr` 皆 sea-orm 1.1.20 內建（research R-C/R-A/R-B 親驗 vendored source）。base-web 零新 npm dep。

**Storage**: PostgreSQL（既有 dev stack、m001 schema）。**本刀無 migration、無建表、無 schema 變更**——`sys_user`(16 欄)/`sys_role`(12 欄)/`sys_user_role`(2 欄複合 PK) 表＋partial-unique `sys_user_user_name_active_uniq`＋6 端點 casbin p-policy 皆 m001/m002/m003 已 seed（research R1）。

**Testing**: rust in-crate `#[cfg(test)]` 純測（filter normalize／page normalize／enum i16↔string／id 2^53 guard／`build_*_active_model`）＋live `#[ignore]` smoke（addUser INSERT op-log INET round-trip／23505 dup／cannot-delete-self／空字串+模糊 filter）＋`endpoint_coverage_lint`(bump)＋既有 `entity_access_lint`（守恆）。**live 一律 `--test-threads=1` serial**（共用 op-log/seed、外層 txn rollback 隔離）。base-web `pnpm typecheck`＋CDP 經 front-nginx（**刻意帶空 param＋模糊關鍵字**）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。**無新 crate→prod build 輕**。

**Target Platform**: 001 dev/prod 容器堆疊（rust-api dev `cargo watch`；驗證容器內 `docker exec`）。

**Project Type**: web（rust-api backend＋base-web frontend）——rust：L4 facade（sys_user list/create/update/find_active_by_id＋sys_user_role role_ids/replace/batch＋sys_role find_active）＋L4 auth/password hash_password＋L5 handler（6 端點）＋L4 main 接線（復用 008 require_policy）＋login gate＋error.rs sql_err map＋L8 endpoint_coverage_lint bump；base-web L3 wrapper（rev3-system-manage.ts）＋L1/L2 typings（rev3-system-manage.d.ts）＋L4 view（MODAL-WIRING (a)）＋locale（I18N-WIRING (ii)）。

**Performance Goals**: list 讀 p95<300ms／寫（含同 txn 審計）p95<500ms（⚠️a 保守預設）；list roles 批次 `roles_for_users(&[i64])`（無 N+1、固定 3 query/頁）；`require_policy` per-request `roles_of_user` join（getUserInfo 已同 join、proven-affordable）。

**Constraints**: `enforce_mw`/`require_policy`/`From<DbErr>` 本體不改（§3.4／⚠️o）；授權 subject＝DB-fresh roles 非 claims.roles（§I.3 FR-008）；**零 migration/schema/entity 變更**；無新 crate；base-web 既有檔不改（rev3-* wrapper/新 typings/MODAL-WIRING (a) inline／locale 加 key、fork-delta rev3-inline 紀律）；前端 hasAuth gating＋dynamic menu＝波2（static 維持）；push/merge 凍結至 finishing（§I.4）。

**Scale/Scope**: admin 使用者表小（≤50 並發 admin、§1.3）；6 rust 端點＋既有 base-web 頁接線。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 權威？rust-api 缺對應 endpoint？ | **PASS**——base-web 有 user CRUD wire（`system-manage.d.ts` User/UserSearchParams/AllRole＋既有 view、CRUD 現 stub）；本刀 rust-api 補齊 6 對應 endpoint；m002 policy 已就位、兩端俱在 |
| 2 | 動 base-web inline？屬 MODAL-WIRING ★ 哪用途？依 fork-delta 紀律？ | **PASS**——MODAL-WIRING **(a)** 接線（drawer `handleSubmit` create/update＋`index.vue` `handleDelete`/`handleBatchDelete`，§III.2 既授 v1.0.0）＋BASE-WEB-I18N-WIRING **(ii)**（`backend.biz.user.*` locale）＋WRAPPER（`rev3-system-manage.ts` 新檔）＋ADAPT（`rev3-system-manage.d.ts` 新檔）皆**既授**；**MW (b) hasAuth gating 不做、延波2 Menu 刀**（research R3 校正）；不改既有 system-manage.ts/system-manage.d.ts/auth.ts；inline 處 `rev3-inline MW(a)` 修改型原行註解保留 |
| 3 | menu 顯示走 Casbin enforce？demo ⚠️p？ | **PASS（機制延波2）**——user 為**既有** manage 頁（非新頁、非 demo、⚠️p N/A）；選單可見性 Casbin（getUserRoutes）＝**波2 Menu 刀**（static 維持）；本刀 API 層 require_policy 已強制（R_ADMIN 可讀 list、寫限 R_SUPER）。**同 008 D1**：static 下非 super 仍見 user 選單、API 擋 403、非破口→波2 Menu 刀收 |
| 4 | wire 對齊 §I.3 typings 權威？ | **PASS**——envelope `Res{data,code,msg}`／`PageRes{current,size,total,records}`（camelCase、無 success/pages）；**`id`=number**（`CommonRecord.id`、⚠️r、非 auth `userId` 的 string）；business error 2222/HTTP200、5003→403；type-lie 於序列化邊界消解（createBy/updateBy `Option<i64>→string`、createTime/updateTime rfc3339、userGender/status i16→'1'/'2'、userRoles code[]）；2^53 fail-loud guard；mock 僅 fixture |
| 5 | 從 rev2 source 拷貝 code？ | **PASS**——借 rev2 016/017 設計、code 全新寫（§I.5／⚠️g 受控參照）；**不帶回**已推翻行為（rev2 017 op-log `ip:None`／id-string／`Number()` 補丁皆不帶） |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——#1 `Super/Admin/User`＋User→User01 alias（006 已建、本刀不動）；#10 wire id ⚠️r（id=number）；**#7 dynamic route mode**：本刀維持 static、dynamic＝波2 Menu 刀（getUserRoutes 落地時）＝排程性**非 violation**（同 008）。無拍板需改 |
| 7 | 觸 §III ★ 軌道？授權邊界內？ | **PASS**——MODAL-WIRING **(a)**＋BASE-WEB-I18N-WIRING **(ii)** 皆**本檔已授**、在邊界內；WRAPPER／ADAPT／RUSTAPI-SOURCE-ISOLATION（§III.1 預設可動）。MW (b) 不觸（延波2） |
| 8 | 新建業務表（migration）？§I.6 六審計欄？ | **PASS（未觸）**——**零 migration**；`sys_user`/`sys_role`（archetype A 全 6 審計欄、m001）＋`sys_user_role`（archetype C 零審計硬刪、m001）＋partial-unique＋6 端點 policy（m002）皆已建。寫端 create/update/delete 成對寫審計欄（`*_at`+`*_by`、§I.6）；**無 retrofit** |
| 9 | 觸 §I.7 行為島（token/policy/single-session）？ | **PASS（未觸/守）**——停用登入 gate **只擋新登入**（不動 token rotation／policy governance／single-session 三台狀態機）；deleteUser soft_delete 不碰 `current_session_id` pointer／`is_current`；即時 token 撤銷（停用即踢）＝**波3、不前拉**；§I.7 invariants 不受影響 |

**Gate 結論：9/9 PASS；無 Amendment；§II #7 dynamic 啟用延波2＝排程性〔非 violation〕；零 migration；無新 crate；Complexity Tracking 不適用。**

> **無新 crate ⇒ prod build 輕**：6 端點皆 server 內 facade/handler/模組（無 workspace crate 新增）→ 不觸 §3「新 crate ⇒ Dockerfile COPY」紀律；C-V 仍跑 prod target build 確認新碼編入。

## Project Structure

### Documentation (this feature)
```text
specs/009-user-management/
├── spec.md              # /speckit-specify ✅（6 US／12 FR／11 SC＋2 Clarifications；FR-011 plan 校正去 hasAuth）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 零 migration・R2 sys_role 欄名・R3 hasAuth 延波2・R4-R10 grep ground-truth）
├── data-model.md        # Phase 1 ✅（facade 6 fn＋handler 6 端點＋DTO/wire 3 端＋filter/分頁/23505/op-log/login gate/lint）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md     # C-V-0~13（build／純測／lint×2／live op-log·23505·self-guard·filter／policy-gate／CDP／typecheck／prod build／零回歸）
│   └── user-management-contract.md  # 跨 feature 不變式（CRUD+M:N 寫同 txn／23505 sql_err pattern／空字串+模糊 filter／分頁／停用 gate／wire 3 端）
└── checklists/requirements.md       # 16/16 ✅
```

### Source Code (repository root)
```text
rust-api/server/src/
├── model/facade/sys_user.rs        # 改：+ list_active(分頁+filter)／create／update／find_active_by_id／build_*_active_model 純測（SoftDeletable/AuditSerialize 既存、redact password 既存）
├── model/facade/sys_user_role.rs   # 改：+ role_ids_of_user(Vec<i64>)／replace_roles_in_txn(同 txn)／roles_for_users(&[i64]→HashMap 批次)（roles_of_user 既存不動）
├── model/facade/sys_role.rs        # 改：+ find_active list fn（getAllRoles 用；現零 query fn）
├── auth/password.rs                # 改：+ prod hash_password（Argon2::default()+SaltString::generate(OsRng)；既有 hash() #[cfg(test)] 不動）
├── handler/system_manage.rs        # ★ 新：6 handler（get_user_list/get_all_roles/add_user/update_user/delete_user/batch_delete_user）＋DTO（UserListItem/AllRoleItem/UserUpsertReq/IdReq/IdsReq）＋filter normalize＋escape_like
├── handler/mod.rs                  # 改：+ pub mod system_manage;
├── handler/auth.rs                 # 改：login_inner 密碼驗證後加 status==Some(2)→LoginFailed(1000) 停用 gate
├── error.rs                        # 改：addUser/updateUser 寫端 e.sql_err()→UniqueConstraintViolation→Biz(2222)（不動 blanket From<DbErr>）— 落點見 data-model §7
└── main.rs                         # 改：users 子 router（6 路由各 route_layer(require_policy)＋外層 enforce_mw）.merge(users)；+ mod
rust-api/server/tests/endpoint_coverage_lint.rs  # 改：AS_BUILT_ROUTES [&str;5]→[&str;11]（+6 distinct path）
base-web/src/
├── service/api/rev3-system-manage.ts        # ★ 新（WRAPPER §III.1）：fetchGetUserList／fetchGetAllRoles?／fetchAddUser／fetchUpdateUser／fetchDeleteUser／fetchBatchDeleteUser
├── typings/api/rev3-system-manage.d.ts      # ★ 新（ADAPT §III.1、declaration-merge）：UserUpsertModel（write DTO；不改既有 system-manage.d.ts）
├── views/manage/user/index.vue              # 改（MODAL-WIRING (a)）：handleDelete/handleBatchDelete 接真 fn（去 console.log stub）
├── views/manage/user/modules/user-operate-drawer.vue  # 改（MODAL-WIRING (a)）：handleSubmit 接 add/update（分支 operateType）＋移除 getRoleOptions mock workaround(:81-87)
└── locales/langs/{zh-cn,en-us}.ts           # 改（I18N-WIRING (ii)）：backend.biz.user.{duplicateUserName,notFound,cannotDeleteSelf,selfLockForbidden}
# ALREADY（不動）：entity/src/{sys_user,sys_role,sys_user_role}.rs／migration（m001/m002/m003 已 seed schema+policy+FK）／audit_ctx.rs+to_audit_operator（007）／enforce_mw+require_policy+roles_of_user（006/008）／mutate_in_txn+SoftDeletable+PageRes（004/005）／blanket From<DbErr>+envelope 13 碼（003/006）／base-web auth.ts/system-manage.ts/system-manage.d.ts/request 攔截器（既有）
```

**Structure Decision**：web（rust-api backend＋base-web frontend）。rust：facade-only（sys_user/sys_user_role/sys_role 補 fn）＋handler 6 端點＋login gate＋error sql_err map＋main 接線（復用 008 require_policy）＋lint bump。base-web：WRAPPER＋ADAPT 新檔＋MODAL-WIRING (a) inline＋locale。**無 migration/entity/新 crate**（地基 001-008 已 provisioned）。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks；~4 Workflow 單元 §12 brainstorm）

1. **★ 順序（rust serial、容器內、改 .rs 先 force-touch）**：
   - **U1 reads**：sys_user `list_active`（`find_active().apply_if(filter).order_by_desc(Id).paginate(size)`→`num_items()`+`fetch_page(current-1)`）＋`escape_like`＋filter normalize（純測 test-first）＋sys_user_role `roles_for_users(&[i64])`（批次 HashMap）＋sys_role `find_active`＋handler get_user_list/get_all_roles＋main 2 路由＋lint bump → 純測＋live filter（空字串/模糊）。
   - **U2 create/update**：sys_user `create`/`update`/`find_active_by_id`＋auth `hash_password`＋sys_user_role `replace_roles_in_txn`＋23505 sql_err map（error 落點）＋handler add_user/update_user（INSERT/UPDATE op-log 同 txn、self-demote/disable guard）＋main 2 路由＋lint bump → live addUser INET round-trip＋23505 dup＋self-guard。
   - **U3 delete + gate**：sys_user delete/batch（復用 soft_delete、cannot-delete-self batch-whole-reject）＋login gate（auth.rs status==2→1000）＋main 2 路由＋lint bump → live delete＋self-delete reject＋停用登入。
   - **U4 base-web MODAL-WIRING (a)**：rev3-system-manage.ts wrapper＋rev3-system-manage.d.ts＋drawer handleSubmit/index.vue delete 接線＋移除 getRoleOptions mock＋backend.biz.user.* i18n → typecheck＋CDP（帶空 param＋模糊）。
2. **★ 零 migration（research R1）**：6 端點 casbin p-policy 已 m002 seed（getUserList GET[SUPER,ADMIN]／getAllRoles GET[SUPER,ADMIN,USER_COMMON]／addUser·updateUser POST[SUPER]／deleteUser·batchDeleteUser DELETE[SUPER]）；表＋partial-unique m001/m003。`require_policy` 直接對既存 policy 強制。
3. **★ 23505→2222（research R5、⚠️o）**：**不改** blanket `From<DbErr>→Internal`；於 addUser/updateUser 寫端 `.map_err(|e| match e.sql_err() { Some(SqlErr::UniqueConstraintViolation(_)) => AppError::Biz("biz.user.duplicateUserName".into()), _ => AppError::Internal })`（落點 data-model §7）。updateUser userName immutable→理論不撞、仍保留 guard。
4. **★ ILIKE 模糊 filter（research R-C、§5.8 首 exercise）**：`use sea_orm::sea_query::extension::postgres::PgExpr;`＋`Expr::col(Column::UserName).ilike(LikeExpr::new(format!("%{}%", escape_like(t))).escape('\\'))`；`escape_like`＝`replace('\\',"\\\\").replace('%',"\\%").replace('_',"\\_")`（backslash 先）。userName/nickName/userEmail 模糊、userPhone/userGender/status `.eq`。**空字串守門**：filter normalize `Some("")→None`（`.filter(|v|!v.is_empty())`；status/gender `Some("")→Ok(None)` 再 parse i16）後才 `apply_if`。
5. **★ 分頁（research R-A）**：`order_by_desc(Column::Id)`（避 paginator no-order warn＋穩定序）→ `.paginate(&db, size)` → `total = num_items()`、`records = fetch_page(current-1)`（**0-based**）；normalize current 默 1、size 默 10 clamp[1,100]；超範圍頁→空 records＋真 total（PageRes）。
6. **★ INSERT op-log（research R-A、首個 Insert constructor）**：`mutate_in_txn` 內 `let after = am.insert(&txn).await?;` → `AuditEvent{ operation: Insert, entity_id: Some(after.id), payload_before: None, payload_after: Some(after.audit_json()), operator, trace_id }`。update/delete `entity_id: Some(id)`。`now` 用 `sea_orm::sqlx::types::chrono::Utc::now().into()`（server 無 chrono；created_at/updated_at 顯式 set）。
7. **★ replace_roles_in_txn（M:N 寫、與 user 寫同 txn）**：delete-all（`sys_user_role` by user_id）+insert-all（code→role_id 經 sys_role `find_active` 解析、**未知/已刪 code 靜默丟**）；**必在 create/update 的同一 `mutate_in_txn`**（否則 roles/op-log desync）。
8. **★ self-guard（spec FR-004 clarify Q1）**：update_user 若 `id == ctx.operator_id` 且（移除自身超管 code ∉ 新 userRoles ∥ status==Some(2)）→ `Biz("biz.user.selfLockForbidden")` 2222 整筆拒。delete/batch `id == operator_id`→`Biz("biz.user.cannotDeleteSelf")` 整批拒（無 partial）。batch 缺漏 id（已不存在/已刪）靜默略過（soft_delete no-op、clarify Q2）。
9. **★ 停用登入 gate（research R-B）**：`handler/auth.rs` `login_inner` 密碼 verify 後（auth.rs:76 後、`let uid` 前）：`if model.status == Some(2) { return Err((Some(model.id), AppError::LoginFailed)); }`（code 1000 統一失敗、防枚舉、零新 i18n；status 已在 find_by_user_name 回的 Model）。
10. **★ wire DTO（research R-D、§I.3 三端）**：`UserListItem`（camelCase serde）：`id:i64`(number)／`userName`／`userGender: Option<String>`(`user_gender.map(|n|n.to_string())`)／`nickName`／`userPhone`／`userEmail`／`status: Option<String>`／`userRoles: Vec<String>`(批次 roles_for_users)／`createBy: String`(`created_by.map(|v|v.to_string()).unwrap_or_default()`)／`createTime: String`(`created_at.to_rfc3339()`)／`updateBy: String`／`updateTime: String`(`updated_at.map(to_rfc3339).unwrap_or_default()`)。**讀端零 password**（不選 password 欄／DTO 不含）。`AllRoleItem{id:i64, roleName: name, roleCode: code}`。`UserUpsertReq`（7 欄+update 帶 id；無 password）。
11. **lint**：handler/error/main 零 path-root `entity::`（entity 全在 facade）；`entity_access_lint` 續綠；`endpoint_coverage_lint` AS_BUILT_ROUTES bump +6（distinct path）**與註冊同 commit**（dedup by path、`[&str;11]`）。
12. **base-web commit `--no-verify`**（§8.2.1 alpine oxlint musl）；rust serial／容器內 build·test／改 .rs 先 force-touch／live `--test-threads=1`＋DATABASE_URL；**逐單元兩段式 commit（worktree→pin、S9 不延末刀）**；全程不 push/merge（§I.4）；CDP 不 defer（有頁、modal toast、空字串陷阱必 browser 軌）。
13. **零回歸（FR-012/SC-010）**：`enforce_mw`/`require_policy`/`From<DbErr>`/`audit_mw`/login 既有流程/getUserInfo/health/008 settings 不變；零 migration/entity/schema；base-web 既有 system-manage.ts/.d.ts/auth.ts 不改（diff 核）。
