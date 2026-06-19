# Data Model: 012-audit-log-query

> 本刀＝rust facade（3 sink facade 各加 `list` 讀 fn＋filter DTO）＋`sys_user::names_for_ids`（net-new enrich）＋handler（system_manage.rs +3 唯讀端點）＋main 3 路由＋**m005 delta migration**（menu/policy seed＋filter 索引）＋base-web 審計中心頁。**唯讀、零寫端、零既有日誌表結構變更**（D11 三欄 IP 模型延後）。型/簽名一律當前 lineage（rust-api `30de791`／base-web `caa1e4bc`）親 grep（research R1-R8）。

## 0. 命名對照
| 場景 | 形 | 例 |
|---|---|---|
| DB（entity 欄） | snake_case | `operation`／`entity_table`／`operator_id`／`operator_ip`／`client_ip`／`x_forwarded_for`／`http_status`／`attempted_user_name`／`created_at` |
| 端點 path | camelCase 尾 | `/systemManage/getOperationLog`／`getAccessLog`／`getLoginAttempt` |
| wire DTO/typings | camelCase | `operatorId`／`operatorName`／`entityTable`／`httpStatus`／`clientIp`／`xForwardedFor`／`attemptedUserName`／`createTime` |
| **id 域（⚠️r）** | number | 各 log `id`／`operatorId`／`entityId`（不轉 String、唯讀無 body id） |
| operation enum | 封閉詞彙 | `INSERT`／`UPDATE`／`SOFT_DELETE`／`RESTORE`（005 AuditOperation） |
| i18n（⚠️y） | `page.manage.audit.*` | tab/col/filter label（非 biz）；biz＝`backend.biz.audit.invalidDateRange`（畸形日期 2222、F2 定） |

## 1. facade `sys_operation_log.rs`（改：+list 讀 fn＋filter；append-only 純 SELECT、write sink 不動）
```rust
pub struct OperationLogFilter {
    pub entity_table: Option<String>,   // 模糊 LOWER LIKE
    pub operation: Option<String>,      // 精確 eq（enum 字串）
    pub operator_ids: Option<Vec<i64>>, // operator_id IN（handler 由 operatorName LIKE 解析）
    pub operator_ip: Option<String>,    // 模糊 host(col)::text LIKE（R4）
    pub entity_id: Option<i64>,         // 精確 eq
    pub trace_id: Option<String>,       // 模糊 LOWER LIKE
    pub created_from: Option<DateTimeWithTimeZone>, // gte
    pub created_to: Option<DateTimeWithTimeZone>,   // lte
}
pub async fn list<C: ConnectionTrait>(conn:&C, page:u64, size:u64, f:OperationLogFilter)
    -> Result<(Vec<entity::sys_operation_log::Model>, u64), DbErr>
// .apply_if 逐欄（R1）、.order_by_desc(CreatedAt).order_by_desc(Id)、.paginate(conn,size).fetch_page(page).num_items()
```

## 2. facade `sys_access_log.rs`（改：+list＋filter）
```rust
pub struct AccessLogFilter {
    pub operator_ids: Option<Vec<i64>>, // operator_id IN（by 名解析）
    pub method: Option<String>,         // 精確 eq（下拉）
    pub path: Option<String>,           // 模糊 LOWER LIKE
    pub http_status: Option<i32>,       // 精確 eq（2xx/4xx/5xx 類別 quick-filter＝UX follow-up）
    pub client_ip: Option<String>,      // 模糊 host(col)::text LIKE
    pub x_forwarded_for: Option<String>,// 模糊 LOWER LIKE（TEXT 欄）
    pub region: Option<String>,         // 模糊 LOWER LIKE
    pub created_from/created_to: Option<DateTimeWithTimeZone>,
}
pub async fn list<C>(conn,page,size,f:AccessLogFilter) -> Result<(Vec<Model>, u64), DbErr>
```

## 3. facade `sys_login_attempt.rs`（改：+list＋filter）
```rust
pub struct LoginAttemptFilter {
    pub attempted_user_name: Option<String>, // 模糊 LOWER LIKE
    pub success: Option<bool>,                // 精確 eq（下拉）
    pub client_ip: Option<String>,            // 模糊 host(col)::text LIKE
    pub x_forwarded_for: Option<String>,      // 模糊 LOWER LIKE
    pub region: Option<String>,               // 模糊 LOWER LIKE
    pub created_from/created_to: Option<DateTimeWithTimeZone>,
}
pub async fn list<C>(conn,page,size,f:LoginAttemptFilter) -> Result<(Vec<Model>, u64), DbErr>
```

## 4. ★ facade `sys_user.rs`（改：+net-new `names_for_ids` enrich；R5）
```rust
pub async fn names_for_ids<C: ConnectionTrait>(conn:&C, ids:&[i64]) -> Result<HashMap<i64,String>, DbErr>
// Entity::find().filter(Id.is_in(ids)).all → id→user_name map；★ 不濾 deleted_at（含已刪、審計保留歷史名、沿 find_by_id）
```
既有 `find_by_user_name`(active)/`find_by_id`(含已刪)/`find_active_by_id`/`list_active`/`roles_for_users`〔sys_user_role〕不動。

## 5. fuzzy / IP expr（research R3/R4）
- **文字模糊**（entity_table/path/帳號/region/xff/trace）：`Expr::expr(Func::lower(Expr::col(col))).like(LikeExpr::new(format!("%{}%", escape_like(raw)).to_lowercase()).escape('\\'))`（沿 sys_user.rs:125-128、**非 PgExpr::ilike**）。
- **IP 模糊**（operator_ip/client_ip、INET）：`host(col)::text LIKE '%q%'`——net-new expr、`Expr::cust_with_values` 或 `cast_as`；**impl 須容器內驗確切 sea-query 渲染**（C-V-3 帶部分 IP 命中）。
- **精確**：`eq`（operation/method/http_status/entity_id/success）。**範圍**：`gte/lte`（created_at）。**operator_ids**：`is_in`。

## 6. handler `system_manage.rs`（改：+3 唯讀端點、沿 009 get_user_list、§5.8）
```rust
struct OperationLogQuery { current/size?, entity_table?, operation?, operator_name?, operator_ip?, entity_id?, trace_id?, created_from?, created_to? }（serde camelCase）
struct AccessLogQuery { current/size?, operator_name?, method?, path?, http_status?, client_ip?, x_forwarded_for?, region?, created_from?, created_to? }
struct LoginAttemptQuery { current/size?, attempted_user_name?, success?, client_ip?, x_forwarded_for?, region?, created_from?, created_to? }

get_operation_log/get_access_log/get_login_attempt(State, Extension<Claims>, Query<XxxLogQuery>) -> Res<PageRes<XxxLogItem>>
//   normalize（current/size、空字串守門、日期 parse、★ operator_name 模糊→sys_user user_name LIKE〔unfiltered〕→operator_ids）
//   → facade.list（逐欄 filter）→ operator 批次 enrich（records operator_id 集→names_for_ids〔unfiltered〕→operatorName）
//   → map Model→XxxLogItem（wire camelCase、IpNetwork→host 字串、nullable→null）→ PageRes{current〔1-based〕,size,total,records}
```
回型 `Result<Json<Res<Value>>, AppError>`、零 path-root entity::；**日期 parse（對齊 spec edge case L137、F2 定）：僅起/僅訖→寬鬆容忍（gte-only／lte-only）；畸形日期→`AppError::Biz("backend.biz.audit.invalidDateRange")` 2222、不靜默**。

## 7. main.rs router（改：+3 GET 路由 require_policy；鏡像 roles group、enforce.rs 不改）
`let audit = Router::new().route("/systemManage/getOperationLog", get(...get_operation_log).route_layer(require_policy(path,"GET")))...×3 .layer(enforce_mw);` + `.merge(audit)`。3 path/method 與 m005 seed 逐字對齊。

## 8. ★ m005 delta migration（`migration/src/m005_audit_log_query.rs`、research R6）
- Migrator：`lib.rs` +`mod m005_audit_log_query;`＋`Box::new(...)`（m004 後）。
- **up**（`get_connection().execute_unprepared` raw SQL）：① sys_menu `manage_audit`〔parent=subquery manage、menu_type=2、route_path='/manage/audit'、component='view.manage_audit'、i18n_key='route.manage_audit'、order、status=1、protected=false〕；② casbin_rule 4 列〔3 GET 端點 R_SUPER＋manage_audit menu policy v2='menu'、8-col〕；③ CREATE INDEX ×4〔sys_operation_log(created_at)／(operator_id,created_at)、sys_access_log(created_at)／(operator_id,created_at)、命名 idx_<table>_<cols>〕。**idempotent（F3 定）：sys_menu `ON CONFLICT (route_name) WHERE deleted_at IS NULL DO NOTHING`〔route_name 唯一索引為 partial〔WHERE deleted_at IS NULL〕、bare `ON CONFLICT (route_name)` 會 runtime error、鏡像 m002〕；casbin `ON CONFLICT (ptype,v0,v1,v2,v3,v4,v5) DO NOTHING`〔非 partial unique〕；索引 `CREATE INDEX IF NOT EXISTS`**。
- **down**：DELETE casbin by (v0,v1,v2) tuple＋DELETE sys_menu by route_name＋DROP INDEX IF EXISTS ×4。
- **★ up→down→up 可逆**（C-V-5）；**無新業務表、無 ALTER 既有日誌表**（§I.6 未觸）。sys_login_attempt 索引 007 已備。

## 9. wire 3 端 honest（research R8、§I.3 ⚠️r；3 型從零、nullable→`｜null`、無 type-lie）
- `OperationLogItem`：id:number／operation:enum 4／entityTable:string／entityId:`number｜null`／operatorId:`number｜null`／operatorName:`string｜null`／operatorIp:`string｜null`／traceId:`string｜null`／createTime:string／payloadBefore·payloadAfter:`Record<string,unknown>｜null`。
- `AccessLogItem`：id／operatorId:number／operatorName:`string｜null`／method／path／httpStatus:number／clientIp:string／xForwardedFor:`string｜null`／region:`string｜null`／traceId:`string｜null`／createTime。
- `LoginAttemptItem`：id／attemptedUserName:string／success:boolean／operatorId:`number｜null`／operatorName:`string｜null`／clientIp:string／xForwardedFor:`string｜null`／region:`string｜null`／createTime。

## 10. i18n keys（BASE-WEB-I18N-WIRING、⚠️y；先 Schema 後 locale）
- `page.manage.audit.{title, tab.operation, tab.access, tab.login, col.*〔time/operator/operation/entityTable/entityId/ip/method/path/status/region/account/result/payload〕, filter.*}`（zh-cn 简体/en-us）。
- `backend.biz.audit.invalidDateRange`（畸形日期 2222 biz、**非條件、F2 定**；Schema `App.I18n.Schema.backend.biz.audit`、locale `backend.biz.audit.*`）。

## 11. base-web wire＋frontend（WRAPPER／ADAPT／MODAL-WIRING (e)、100% 淨新）
- **L3 WRAPPER** `service/api/rev3-system-manage.ts`：+`fetchGetOperationLog(params)`／`fetchGetAccessLog(params)`／`fetchGetLoginAttempt(params)`（GET、params=filter+current/size）。
- **L1/L2 ADAPT** `typings/api/rev3-system-manage.d.ts`：+`OperationLogItem`/`AccessLogItem`/`LoginAttemptItem`（§9 honest）＋各 `XxxLogSearchParams`＋`XxxLogList=Common.PaginatingQueryRecord<Item>`。
- **L4 MODAL-WIRING (e) 新頁** `views/manage/audit/index.vue`（NTabs 3 tab）＋`modules/{operation-log-table,access-log-table,login-attempt-table}.vue`（各 NDataTable＋filter 列〔operation/success/method 下拉、日期 NDatePicker range、文字/IP/帳號 NInput 模糊、operator NInput by 名〕＋NPagination；op-log 行展開看 payload）。
- route：dynamic menu 自動帶（m005 menu seed）；**frozen 不改**（route store/transform/system-manage.ts/auth.ts/request）；無 .env flip；button-auth/其他 modal 無涉。

## 12. `server/tests/endpoint_coverage_lint.rs`（改：bump、research R7）
`AS_BUILT_ROUTES [&str;31]→[&str;34]`（+getOperationLog/getAccessLog/getLoginAttempt）。3 皆 policy-routes→Assertion A m005 seed 自動過；B registered==as-built。entity_access_lint：handler/main 零 path-root entity::；3 sink facade list 走 model/facade/ 豁免。

## 13. 排除聲明（OUT/MOOT）
- **MOOT（已 done）**：3 log entity（002）＋3 sink facade 寫端（005/007）＋AuditOperation enum＋INET/region（007 xdb）＋PageRes/§5.8 normalize/escape_like/ilike seam/require_policy/enforce_mw/roles_for_users/find_by_id/endpoint_coverage_lint/entity_access_lint（004-011）＋sys_login_attempt 索引（007）。
- **OUT（遞延）**：client_ip(peer)/xff_ip/real_ip 三欄統一 IP forensic 模型＋audit_ctx 寫端 peer/CF capture（D11、後續刀、同 §3.11）／§3.12 user 角色變更 payload delta（D4）／log retention（⚠️n）／審計匯出 CSV（未列）／2xx-5xx 類別 quick-filter（UX 增強）／pg_trgm fuzzy GIN 索引（scale follow-up、本刀 seq scan）。
