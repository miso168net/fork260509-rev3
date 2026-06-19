# Phase 0 Research: 012-audit-log-query

> 接地源＝當前 lineage（rust-api `30de791`／base-web `caa1e4bc`、皆 011 收刀後）親 grep＋psql ground-truth＋2 平行 research agent（rust 讀路徑/enrich／migration·router·lint）＋主線親驗。**NEEDS CLARIFICATION = 0**（spec 零 marker；本階段解 brainstorm「plan 定」項）。
> 拍板：D1 單頁三分頁／D4 角色 delta 延後／D11 三欄 IP forensic 模型延後（讀現 schema）／D12 逐欄 fuzzy/exact／僅超管。

## R1 — 3 sink facade net-new 讀 fn（list、鏡像 sys_role::list；釘死簽名）
**Decision**：`sys_operation_log.rs`／`sys_access_log.rs`／`sys_login_attempt.rs` 各加（既有 write sink 不動）：
```rust
pub async fn list<C: ConnectionTrait>(conn: &C, page: u64, size: u64, f: XxxLogFilter)
    -> Result<(Vec<entity::sys_xxx::Model>, u64), DbErr>
```
鏡像 `sys_role::list`（096-118）之 apply_if/paginate **結構**〔注（F4）：sys_role::list 本身 `order_by_asc(id)`；本 list **改** order 為 `.order_by_desc(CreatedAt).order_by_desc(Id)`〔穩定、時序新到舊、對齊 FR-002〕〕：`.apply_if(f.field, |q,v| q.filter(...))` 逐欄、`.paginate(conn, size).fetch_page(page).num_items()` 取 `(rows, total)`。**page 0-based**（handler 傳 `current-1`、沿 009/011）。append-only 純 SELECT、無 mutate_in_txn、`entity::` 在 facade 層合法（entity_access_lint 豁免 `model/facade/`）。
**Rationale（親驗 sys_role.rs:96-118 list＋RoleFilter:77-82）**：3 sink facade 現 write-only（`write_in_txn`／`write`＋`AccessLogEvent`/`LoginAttemptEvent` pub struct＋pure seam）、零讀方法；list 鏡像 009 `sys_user::list_active`／011 `sys_role::list` 既證 pattern。
**Alternatives**：1 通用 list（否決 D2、3 schema 異質）。

## R2 — §5.8 read-filter reuse（normalize helper／PageRes／get_user_list 模板）
**Decision**：handler 沿 `get_user_list`（system_manage.rs:464-517）：`normalize_current`(228-230、default 1 floor 1)／`normalize_size`(233-235、default 10 clamp[1,100])／`normalize_str_filter`(213-215、`Some("")→None` 空字串守門)／`normalize_enum_filter`(219-225、`Some("")→Ok(None)`、numeric→i16)；`escape_like`(205-209) 供 fuzzy。回 `PageRes<T>{current〔1-based 原值〕,size,total,records}`（envelope.rs:52-63 camelCase）包進 `Res<serde_json::Value>`、handler 簽名 `Result<Json<Res<serde_json::Value>>, AppError>`、零 path-root `entity::`。
**Rationale**：009/011 已示範 normalize→facade list→map wire→PageRes 全鏈；本刀讀端直接復用。
**Alternatives**：無。

## R3 — fuzzy 文字 filter（`LOWER(col) LIKE ESCAPE`、非 PgExpr::ilike、沿 009 校正）
**Decision**：文字模糊欄（path/帳號/region/entity_table/trace、operatorName 解析用）走 `sys_user.rs:125-128` ilike seam：`Expr::expr(Func::lower(Expr::col(col))).like(LikeExpr::new(format!("%{}%", escape_like(raw)).to_lowercase()).escape('\\'))`。**絕不用 `PgExpr::ilike().escape()`**（sea-query 0.32.7 `drop_right_escape_hack` 只認 `BinOper::Like`、不含 pg `PgBinOper::ILike`→`ILIKE … ESCAPE` 非法 SQL→5000；009 ⚠️o 校正、跨 feature 權威 user-management-contract §3.2）。
**Rationale（親驗 sys_user.rs:117-128 註解＋ilike）**：009 踩過此雷、校正定案；本刀文字 fuzzy 沿用。
**Alternatives**：PgExpr::ilike（否決＝runtime 失效）。

## R4 — IP 模糊（INET→text cast、net-new expr、impl 須驗確切 sea-query 形）
**Decision**：IP 欄（`operator_ip`／`client_ip`＝`IpNetwork`/INET）模糊＝`host(col)::text LIKE '%q%'`（`host()` 去 /32·/128 mask、利部分比對）。codebase **無 `::text` cast 先例**＝net-new expr → 以 `Expr::cust_with_values("host(\"{col}\")::text LIKE $1", [pattern])`〔或 sea-query `Expr::col(col).cast_as(Alias::new("text")).like(...)`〕表達；**plan→impl 須在 rust-api 容器內驗確切 sea-query 渲染**（C-V-3 live 帶部分 IP 實證命中、curl≠modal）。`x_forwarded_for`＝`Option<String>`/TEXT → 直 `LOWER LIKE ESCAPE`（同 R3）。
**Rationale（親驗 3 entity IpNetwork 欄＋codebase 無 ::text grep）**：INET 不能直接 LIKE、須轉 text；`host()` 去 mask 最合「查含某 IP 片段」。
**Alternatives**：`col::text LIKE`（含 mask `/32`、片段比對較雜、次選）；存 text 副本欄（否決＝動 schema、D11 延後範圍）。
**★ 風險自覺**：此為本刀唯一「無 codebase 先例」之 SQL 形 → research.md 明示、impl 首要驗證點（U1 facade live smoke）。

## R5 — operator enrich（net-new `sys_user::names_for_ids` unfiltered；operatorName 篩亦復用）
**Decision**：新增 `sys_user::names_for_ids<C>(conn, ids: &[i64]) -> Result<HashMap<i64,String>, DbErr>`——`sys_user::Entity::find().filter(Id.is_in(ids)).all` → map `id→user_name`、**不濾 `deleted_at`**（含已刪、審計保留歷史操作者名、沿 006 find_by_id 不濾）。handler enrich：收 records 的 `operator_id` 集（去 None/去重）→ `names_for_ids` → 填 `operatorName`（null=operator_id NULL）。**operatorName 模糊篩**：handler 先 `sys_user` user_name LIKE（R3 ilike、unfiltered）→ `operator_ids: Vec<i64>` → facade filter `operator_id IN`；名無匹配→空 ids→空頁。
**Rationale（親驗 sys_user_role::roles_for_users:61-108 批次精神＋sys_user facade 無 names_for_ids）**：roles_for_users 示範批次免 N+1；user_id→name 無既有 fn＝net-new。find_by_id（097-102）不濾 deleted_at＝enrich unfiltered 之依據。
**Alternatives**：逐筆 find_by_id（否決＝N+1）；前端解析（否決＝前端 dumb 原則＋需 getAllUsers）。

## R6 — m005 delta migration（Migrator reg／up·down execute_unprepared／seed·index 鏡像 m002/m001）
**Decision**：新 `migration/src/m005_audit_log_query.rs`、`lib.rs` 加 `mod m005_audit_log_query;`＋`Box::new(m005_audit_log_query::Migration)`（m004 後）。`up`（raw SQL via `manager.get_connection().execute_unprepared`、沿 m002 seed 風）：① INSERT sys_menu `manage_audit`〔parent_id 子查詢 `(SELECT id FROM sys_menu WHERE route_name='manage' AND deleted_at IS NULL)`、menu_type=2、menu_name/route_name='manage_audit'、route_path='/manage/audit'、component='view.manage_audit'、icon_type=1、i18n_key='route.manage_audit'、"order"、status=1、protected=false〕；② INSERT casbin_rule 4 列〔8-col `(ptype,v0,v1,v2,v3,v4,v5,protected)`：`('p','R_SUPER','/systemManage/getOperationLog','GET','','','',false)` ×3〔getOperationLog/getAccessLog/getLoginAttempt〕＋`('p','R_SUPER','manage_audit','menu','','','',false)`〕；③ CREATE INDEX ×4〔sys_operation_log(created_at)／(operator_id,created_at)、sys_access_log(created_at)／(operator_id,created_at)、命名 `idx_<table>_<cols>`、沿 m001 idx_login_attempt_*〕。`down` 對稱（DELETE casbin by (v0,v1,v2) tuple＋DELETE sys_menu by route_name＋DROP INDEX IF EXISTS ×4）。**up→down→up 可逆**（波 0 出口紀律、C-V-5）。
**Rationale（親驗 lib.rs:1-31 Migrator＋m002 seed＋m001:799-819 index）**：m005 純 delta（seed 列+索引、**無新業務表、無 ALTER**）；不動 frozen m002（rev2 終態 baseline、⚠️t）。idempotent（F3 定）：sys_menu seed **`ON CONFLICT (route_name) WHERE deleted_at IS NULL DO NOTHING`**（route_name unique 為 **partial**〔`WHERE deleted_at IS NULL`〕、bare conflict-target 會 runtime error、鏡像 m002 形）；casbin `ON CONFLICT (ptype,v0,v1,v2,v3,v4,v5) DO NOTHING`（7-tuple unique `unique_key_sea_orm_adapter` 存在、非 partial）。
**Alternatives**：編 m002（否決＝動 frozen baseline）；sea-orm SchemaManager index API（可選、本刀 raw SQL 與 seed 一致）。

## R7 — main router＋lint（audit Router group／AS_BUILT [31→34]／entity_access）
**Decision／親驗（main.rs roles group:284-374＋endpoint_coverage_lint.rs:41-88＋entity_access_lint.rs:28-30）**：main.rs 加 `let audit = Router::new().route("/systemManage/getOperationLog", get(handler::system_manage::get_operation_log).route_layer(from_fn_with_state(state.clone(), require_policy("/systemManage/getOperationLog","GET"))))...×3 .layer(from_fn_with_state(state.clone(), enforce_mw));`＋`.merge(audit)`。`endpoint_coverage_lint` `AS_BUILT_ROUTES [&str;31]→[&str;34]`（+getOperationLog/getAccessLog/getLoginAttempt、與註冊同 commit；3 policy m005 seed→Assertion A 過、B registered==as-built）。`entity_access_lint`：handler/main 零 path-root entity::（資料經 facade）；3 sink facade list 用 entity:: 走 `model/facade/` 豁免。
**Alternatives**：無。

## R8 — wire 3 端 honest（3 log Model→wire item；nullable→`｜null`；無 type-lie）
**Decision／親驗（3 entity Model＋PageRes＋§I.3 ⚠️r）**：3 wire item 型從零 honest（base-web 100% 淨新、無既有型可守）：
- `OperationLogItem`：id:number／operation:`'INSERT'|'UPDATE'|'SOFT_DELETE'|'RESTORE'`／entityTable:string／entityId:`number｜null`／operatorId:`number｜null`／operatorName:`string｜null`〔enrich〕／operatorIp:`string｜null`〔host 去 mask〕／traceId:`string｜null`／createTime:string／payloadBefore·payloadAfter:`Record<string,unknown>｜null`〔jsonb〕。
- `AccessLogItem`：id／operatorId:number〔NOT NULL〕／operatorName:`string｜null`／method／path／httpStatus:number／clientIp:string／xForwardedFor:`string｜null`／region:`string｜null`／traceId:`string｜null`／createTime。
- `LoginAttemptItem`：id／attemptedUserName:string／success:boolean／operatorId:`number｜null`／operatorName:`string｜null`／clientIp:string／xForwardedFor:`string｜null`／region:`string｜null`／createTime。
id 域 number（⚠️r）；IpNetwork→字串（§3.4 首次 decode round-trip 讀回 access/login client_ip）；nullable→`｜null` 立 honest 先例（避 §3.12/§3.13 type-lie）。
**Alternatives**：沿用既有分頁包型（否決＝無既有型、淨新）。

## 解的 brainstorm「plan 定」項對照
| brainstorm 待定 | research 結論 |
|---|---|
| facade list 簽名 | R1（鏡像 sys_role::list、page 0-based） |
| §5.8 helper 簽名/PageRes | R2（確切簽名/行號） |
| fuzzy 形 | R3（LOWER LIKE ESCAPE、非 ilike） |
| IP fuzzy 確切 expr | R4（host()::text LIKE、net-new、impl 驗） |
| operator 解析 fn | R5（net-new names_for_ids unfiltered） |
| m005 seed/index/Migrator 形 | R6（execute_unprepared、鏡像 m002/m001） |
| main router/lint | R7（audit group、[31→34]） |
| wire 3 端 | R8（3 honest item 型） |
