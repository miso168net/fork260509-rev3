# Phase 0 Research: 009-user-management

> 接地源＝當前 lineage（rust-api worktree `028289a`／base-web `223bc83e`）親 grep＋4 平行 grounding dimension（R-A rust 資料層／R-B error·lint·login·main／R-C SeaORM ILIKE 構式／R-D base-web wire+MODAL-WIRING）＋主線親驗。**NEEDS CLARIFICATION = 0**（brainstorm＋specify＋clarify 已拍；plan-phase 親驗校正 3 處、見 R1/R2/R3）。
> 本刀借 rev2 016/017 設計、code 全新寫（§I.5／⚠️g）。grounding 抓到 brainstorm 抽象命名與實況偏差 1 處（R2 sys_role 欄名）＋spec 與實況偏差 1 處（R3 hasAuth）——act-on-code 校正、見下。

## R1 — 零 migration：表＋6 端點 policy 皆 m001/m002/m003 已 seed（親 grep 校正）
**Decision**：本刀**無 migration**——`sys_user`/`sys_role`/`sys_user_role` 表＋partial-unique＋6 端點 casbin p-policy 皆既存。
**Rationale（親 grep）**：`sys_user`(16 欄)/`sys_role`(12 欄)/`sys_user_role`(2 欄複合 PK) 表＋`sys_user_user_name_active_uniq WHERE deleted_at IS NULL`（m001）＋FK（m003）＋p-policy（m002:97-98 getUserList GET[R_SUPER,R_ADMIN]／:110-112 getAllRoles GET[R_SUPER,R_ADMIN,R_USER_COMMON]／:113-114 addUser·updateUser POST[R_SUPER]／:115-116 deleteUser·batchDeleteUser DELETE[R_SUPER]）皆 seed（R-B Q5 親驗）。`require_policy` 直接對既存 policy 強制；`endpoint_coverage_lint` Assertion A（policy-governed⊆seeded）自動過。`Migrator::up delta == 0`。
**Alternatives**：加 filter btree/pg_trgm GIN index（否決——小 admin 表 seq-scan 足、leading-wildcard ILIKE 吃不到 btree、且多一條 migration＋還原性負擔；pg_trgm＝未來選項、登 backlog、clarify Q3/spec D3）。

## R2 — ★ sys_role 欄名＝`code`/`name`/`role_desc`＋`home`（非 role_code/role_name；親驗校正）
**Decision**：getAllRoles DTO 映 **`sys_role.code → roleCode`**、**`sys_role.name → roleName`**；facade 用 `Column::Code`/`Column::Name`。
**Rationale（R-A 親驗 entity/src/sys_role.rs:9-21）**：Model 欄＝`id:i64`／`code:String`（role code 如 R_SUPER）／`name:String`／`deleted_at`／`role_desc:Option<String>`／`status:Option<i16>`／6 審計欄／`home:Option<String>`（route home）。**非** brainstorm 抽象假設的 `role_code`/`role_name`。`roles_of_user` 已讀 `Column::Code`（sys_user_role.rs:29 親驗）。typings `AllRole{id:number, roleName, roleCode}`（R-D）＝wire 形；rust 序列化邊界做 `code→roleCode`/`name→roleName` 映射。
**Alternatives**：信 brainstorm `role_code`/`role_name`（否決——E0412/E0609 at impl；act-on-code 第一）。

## R3 — ★ 前端 hasAuth button gating 延波2 Menu 刀（spec FR-011 校正、user 拍 2026-06-18）
**Decision**：本刀 MODAL-WIRING **只做 (a) 接線**（drawer handleSubmit＋index.vue delete/batchDelete 接真 fn）；**不做 (b) hasAuth button gating**——授權靠後端 `require_policy` 403、前端按鈕可見性統一延波2 Menu 刀（getUserRoutes）。spec FR-011 已校正去 hasAuth 句。
**Rationale（R-D 親驗）**：`grep hasAuth base-web/src/views/manage/` ＝**0 命中**——整個 manage/（user/role/menu）現零 hasAuth；008 亦同（授權全靠後端 403、前端可見性延波2＝CHECKLIST §3.10 D1 follow-up）。本刀加 hasAuth＝新建 button-code 機制（codebase 無此 pattern）＋與既定 backend-403 pattern 不一致＋波2 Menu 刀會再動一次（throwaway）。**同 008 D1**：R_ADMIN 可讀 list 故見寫入鈕、點了得 403（後端擋）＝非破口。
**Alternatives**：本刀加 hasAuth（否決——user 拍延波2、避 throwaway＋對齊既定 pattern）。

## R4 — facade GAPS 與簽名（act-on-code、零臆測）
**Decision／親驗（R-A file:line）**：
- `facade/sys_user.rs` 既有：`soft_delete`(L47、mutate_in_txn、entity_id Some(id)、成對 deleted_at/by)／`find_by_user_name`(L82、active+含 password、login 用)／`find_by_id`(L95、**含 soft-deleted**+含 password、getUserInfo 用)／`set_pointer`(L104)／`current_session_id_of`(L120)。`impl SoftDeletable`(L10-14)＋`impl AuditSerialize for Model`(L18-39、**已 redact password→"<redacted>"**、其餘 15 欄 rfc3339)。**缺：`list_active`(分頁+filter)／`create`(insert)／`update`(by id)／`find_active_by_id`**。
- `facade/sys_user_role.rs` 既有：`roles_of_user(uid)→Vec<String>`(L11、回 **code**、兩步、**無 sys_role.deleted_at 濾**)。**缺：`role_ids_of_user(Vec<i64>)／replace_roles_in_txn／roles_for_users(&[i64]→HashMap 批次)**。
- `facade/sys_role.rs`：**零 query fn**（僅 `impl SoftDeletable` L6-10）。**缺：`find_active` list**。
- `auth/password.rs`：僅 `verify()`；`hash()`＝`#[cfg(test)]` 測試專用（固定 salt）。**缺：prod `hash_password`**（`Argon2::default()`+`SaltString::generate(&mut OsRng)`、對齊 m002 seed 配方＋既有 verify）。
**Rationale**：facade-only（§I.6）、entity:: 僅 facade 合法（entity_access_lint）。AuditSerialize 既存且 redact password→op-log payload 直接復用。
**Alternatives**：在 handler 直存 entity::（否決——違 facade-only/lint）。

## R5 — 23505→2222 落點＝寫端 `sql_err()` map（⚠️o；不動 blanket From<DbErr>）
**Decision**：addUser/updateUser 寫端 `.map_err(|e| match e.sql_err() { Some(SqlErr::UniqueConstraintViolation(_)) => AppError::Biz("biz.user.duplicateUserName".into()), _ => AppError::Internal })`；**blanket `From<DbErr> for AppError`（→Internal/5000）不改**。
**Rationale（R-B 親驗）**：error.rs:110-116 `From<DbErr>` 丟棄 err 一律 Internal；error.rs:111 註解明示「23505→2222 留波2 CRUD」＝本刀兌現。⚠️o：「DB 能擋者（unique）續走 DbErr→handler sql_err() 映碼」→ 靠 partial-unique 約束 catch、**不做 app pre-check**（避 TOCTOU）。`DbErr::sql_err()→Some(SqlErr::UniqueConstraintViolation(_))` 在 sea-orm 1.1.20+`sqlx-postgres` active（R-B 親驗 container source error.rs:166/178）。**陷阱**：若寫端用裸 `?` 走 blanket From→23505 靜默變 5000（type-lie）；必顯式 `.map_err` at insert/update call site。
**Alternatives**：改 blanket From 收 sql_err（否決——影響全域 DbErr 語意、違 ⚠️o「handler 映碼」）／app pre-check find_active_by_name（否決——TOCTOU、⚠️o 棄）。

## R6 — ILIKE 模糊 filter 構式＋wildcard escape＋conditional（sea-orm 1.1.20 親驗 vendored）
**Decision**：`use sea_orm::sea_query::extension::postgres::PgExpr;`（★ 必須 in scope、**非** sea_orm top-level re-export）＋`Expr::col(Column::UserName).ilike(LikeExpr::new(format!("%{}%", escape_like(t))).escape('\\'))`；`escape_like(raw)=raw.replace('\\',"\\\\").replace('%',"\\%").replace('_',"\\_")`（backslash 先）。conditional 用 `QueryTrait::apply_if(Option, |q,v|...)`（`use sea_orm::QueryTrait;`、`apply_if(None,..)`＝no-op skip）鏈於 `SoftDeletable::find_active()`(回 `Select<Self>`)。
**Rationale（R-C 親驗 vendored sea-orm-1.1.20/sea-query-0.32.7）**：`ColumnTrait::contains` 是**大小寫敏感** `LIKE` ＋ `format!` 無 escape（column.rs:237）→棄。`PgExpr::ilike`（postgres/expr.rs:136、`PgExpr:ExprTrait` blanket impl）→ pg `ILIKE`。`LikeExpr{pattern,escape:Option<char>}`（types.rs:347）`.escape(c)` 出 `ESCAPE` clause。`apply_if`（query/traits.rs:46）confirmed。009＝全 rust-api 首個 ilike/apply_if/Condition 用者（grep 零既有）。
**★ 空字串守門（§5.8 首 exercise、curl≠modal）**：base-web axios 把未設 filter 序列化成 `?userName=&status=`→serde `Some("")`；filter normalize **`Some("")→None`**（字串 `.filter(|v|!v.is_empty())`；status/gender `Some("")→Ok(None)` 再 parse i16）**後**才 `apply_if`，否則 `ILIKE '%%'` 全中／enum 空字串致整頁 0 列（rev2 2222 regression）。**curl 乾淨 query 掩蓋、必 CDP 帶空 param**。
**Alternatives**：`ColumnTrait::contains`（否決——case-sensitive+無 escape）／`Condition::all().add_option`（可行但較不 ergonomic、apply_if 優先）。

## R7 — 分頁（PaginatorTrait、0-based fetch_page、num_items；PageRes 首消費者）
**Decision**：`Entity::find_active().apply_if(...).order_by_desc(Column::Id).paginate(&db, size)` → `total = .num_items().await?`、`records = .fetch_page(current-1).await?`（**0-based**）；normalize current 默 1、size 默 10 clamp[1,100]；超範圍頁→空 records＋真 total。`PageRes<T>{current,size,total,records}`(envelope.rs:52-63、camelCase、無 pages/success)。
**Rationale（R-A 親驗 vendored paginator.rs）**：`paginate(db,size)→Paginator`／`fetch_page(page)`（page 0-based、doc）／`num_items()→COUNT`(strip limit/offset/order)＝真 total。Paginator 無 ORDER BY 會 warn→`order_by_desc(Id)`（穩定序+靜音）。009＝首個 paginate 消費者（grep 零）。
**Alternatives**：手寫 limit/offset+count（否決——PaginatorTrait 內建）。

## R8 — op-log INSERT threading（首個 Insert constructor）＋審計欄
**Decision**：create 於 `mutate_in_txn` 內 `let after = am.insert(&txn).await?;` → `AuditEvent{ operation: Insert, entity_table:"sys_user", entity_id: Some(after.id), payload_before: None, payload_after: Some(after.audit_json()), operator, trace_id }`。update/delete `entity_id: Some(id)`、update payload_before=改前 Model.audit_json()。handler 經 `let (operator, trace) = ctx.to_audit_operator(claims.uid);` 餵 facade。
**Rationale（R-A 親驗 audit.rs）**：`AuditOperation{Insert,Update,SoftDelete,Restore}` 皆在（L16-21）；Insert/Update 008 前無 constructor、008 用 Update、**009 首個 Insert**。`mutate_in_txn`(L65-78) 閉包回 `(txn,R,Option<AuditEvent>)`。真 `operator_ip` INET（007/008 live、**不抄 rev2 ip:None**）。`now`＝`sea_orm::sqlx::types::chrono::Utc::now().into()`（server 無 chrono；business 表 created_at/updated_at 顯式 set、非 NotSet）。
**Alternatives**：`am.save()`（否決——只 insert() 回填 DB-gen id 供 after.id/audit_json）。

## R9 — wire 3 端對齊＋type-lie 消解（§I.3、R-D 親驗 typings）
**Decision／親驗**：`User=CommonRecord<{userName,userGender:'1'|'2'|null,nickName,userPhone,userEmail,userRoles:string[]}>`；`CommonRecord{id:number, createBy:string, createTime:string, updateBy:string, updateTime:string, status:'1'|'2'|null}`。rust DTO 序列化邊界消 lie：
- **id → number**（`CommonRecord.id:number`、⚠️r；**非** auth `userId` 的 to_string）。
- **createBy/updateBy → String**（`created_by/updated_by:Option<i64>` → `.map(|v|v.to_string()).unwrap_or_default()`、NULL→`""`；typings 宣告 non-null string＝雙重 lie：i64 vs string + nullable vs non-null）。
- **createTime → `created_at.to_rfc3339()`**（non-null）；**updateTime → `updated_at.map(to_rfc3339).unwrap_or_default()`**（NULL→`""`）。
- **userGender/status → Option<String>**（`Option<i16>.map(|n|n.to_string())`→`'1'|'2'|null`）。
- **userRoles → Vec<String>** role code（list 批次 `roles_for_users`、避 N+1）。
- **讀端零 password**（DTO 不含；entity Model 含但不投影/不選）。
- `AllRole{id:number, roleName(=name), roleCode(=code)}`；`UserUpsertReq`＝7 欄 Pick（無 id/password；update id 在 body、parse String→i64 fail→2222）。
**Rationale**：base-web typings＝wire 唯一權威（§I.3）；mock `AllRole.id` string＝缺陷不對齊。drawer `Model`＝`Pick<User,...>`＝component state 天然對齊 typings；lie 全在 rust↔wire 邊界、rust 出 typings 宣告型即 3 端齊。precedents：camelCase DTO（system_settings.rs:21）／to_rfc3339（sys_user.rs:30）／i64→string（auth.rs:217）。
**Alternatives**：mock 為 oracle（否決——§I.3 typings 優先）。

## R10 — 停用登入 gate（reuse LoginFailed 1000、防枚舉）
**Decision**：`handler/auth.rs` `login_inner` 密碼 `password::verify` 通過後（auth.rs:76 後、`let uid=model.id`(:79) 前）：`if model.status == Some(2) { return Err((Some(model.id), AppError::LoginFailed)); }`。
**Rationale（R-B 親驗）**：`find_by_user_name` 回的 Model 已含 `status:Option<i16>`（無需新 facade fn）；`AppError::LoginFailed`＝code **1000**、key `auth.login.failed`（error.rs:38/61/76）＝**統一登入失敗**（與帳號/密碼錯同訊息）＝spec FR-009「不洩停用狀態防枚舉」正解、**零新 i18n/變體**。置 verify 後（識別後）→ 回 `Some(model.id)` 對齊 auth.rs「識別前 None/識別後 Some(uid)」operator 歸屬 doctrine（login_attempt 審計）。status==Some(2)＝停用（typings EnableStatus '1'=啟用/'2'=停用、R-D）。
**Alternatives**：新 Biz("auth.user.disabled") 2222（否決——破 9 碼凍結語意+需新 i18n+洩停用狀態違防枚舉）／置 verify 前（否決——須回 None 否則洩帳號存在）。

## R11 — endpoint_coverage_lint bump 形（registered==as-built＋policy⊆seeded）
**Decision**：`AS_BUILT_ROUTES: [&str; 5]` → `[&str; 11]`，加 6 distinct path（`/systemManage/getUserList`／`getAllRoles`／`addUser`／`updateUser`／`deleteUser`／`batchDeleteUser`）。scan/assertion 邏輯不動。
**Rationale（R-B 親驗 endpoint_coverage_lint.rs:44-50,143-221）**：`extract_routes` 抓 `.route("<path>"` 首字面、BTreeSet **dedup by PATH**（同 path 多 method 算 1）；Assertion B `registered==expected`（main.rs route 集 == AS_BUILT_ROUTES）；Assertion A 每 `require_policy(path,method)` 須 m002 有 `'<path>','<method>'` seed（policy⊆seeded、非反向）。6 端點 distinct path → `+6`＝`[&str;11]`；**陣列長度型註記須手動 bump**（易漏）；**與路由註冊同 commit**（S9）。6 policy 已 m002 seed→Assertion A 自動過。
**Alternatives**：照搬 §7.1 @35（否決——day-1 紅、m002 預 seed 未註冊路由）。
