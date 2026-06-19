# Contract: 審計查詢讀端＋審計中心（012 落定、跨 feature 權威）

> 本刀建立的不變式，後續刀（3-IP forensic 模型刀／⚠️w login lockout／波3 policy-governance 之 op-log 稽核軌消費）繼承。權威＝constitution §I.1/§I.2/§I.3/§I.6/§I.7/§III＋DESIGN §8.2＋DECISIONS ⚠️b/⚠️r/⚠️y/⚠️n＋brainstorm D1-D12（讀端先行、IP 模型延後）。

## 1. 唯讀讀端（3 sink facade +list、§5.8、沿 009/011）
1. **3 list fn**：`sys_operation_log::list`／`sys_access_log::list`／`sys_login_attempt::list`〔`(conn,page〔0-based〕,size,filter)->(Vec<Model>,u64)`、`.apply_if` 逐欄、`order_by_desc(created_at,id)`、`.paginate.fetch_page.num_items`〕；鏡像 `sys_role::list`。
2. **§5.8**：handler normalize（current/size、空字串守門 `Some("")→None`）＋`PageRes{current〔1-based〕,size,total,records}`；沿 009 `get_user_list`。
3. **唯讀**：純 SELECT、**無 mutate_in_txn、無寫 op-log**（查詢不自審、append-only 日誌表零寫）；live/CDP 測**無 cleanup**（不污染）。

## 2. operator enrich（net-new `sys_user::names_for_ids`、unfiltered）
1. `names_for_ids(conn,&[i64])->HashMap<i64,String>`——`Id.is_in(ids)`、**不濾 deleted_at**（含已刪、審計保留歷史操作者名、沿 006 find_by_id）。
2. handler：records `operator_id` 集（去 None/去重）→ names_for_ids → `operatorName`；null **僅** operator_id NULL（系統 op）。
3. **operatorName 模糊篩**：handler user_name `LOWER LIKE`（unfiltered）→ `operator_ids`→ facade `operator_id IN`；無匹配→空頁。

## 3. fuzzy / IP filter（D12；沿 009 校正、IP net-new）
1. **文字模糊**（entity_table/path/帳號/region/xff/trace）：`Func::lower(Expr::col(col)).like(LikeExpr::new("%{escape_like}%").escape('\\'))`——**絕不 `PgExpr::ilike`**（sea-query 0.32.7 bug、user-management-contract §3.2 跨 feature 權威繼承）。
2. **IP 模糊**（operator_ip/client_ip、INET）：`host(col)::text LIKE '%q%'`（host 去 mask）——**net-new SQL 形、無 codebase 先例、impl 須容器內驗渲染**（C-V-3 首要驗）。`x_forwarded_for`（TEXT）直 `LOWER LIKE`。
3. **精確**：operation/method/http_status/entity_id/success＝`eq`；**範圍**：created_at＝`gte/lte`；**operator**：`is_in`（by 名解析）。

## 4. m005 delta migration（seed+index、無業務表、可逆）
1. **m005**（`m005_audit_log_query.rs`、Migrator m004 後）：sys_menu `manage_audit`（parent=manage、menu_type=2、`view.manage_audit`、protected=false）＋casbin 4 列（3 GET R_SUPER＋manage_audit menu v2='menu'）＋filter 索引 4（operation/access × created_at, operator_id+created_at）；execute_unprepared raw SQL、鏡像 m002 seed／m001 index。
2. **無新業務表、無 ALTER 既有日誌表**（§I.6 archetype A 六審計欄義務未觸；日誌表 archetype B 既建 002）；**up→down→up 可逆**（C-V-5、波 0 出口紀律）。
3. **下游復用**：3-IP forensic 模型刀（D11）若 ALTER 日誌表加 client_ip(peer)/xff_ip/real_ip＝獨立 migration、與本刀讀端 wire 擴充對齊；本刀 manage_audit menu／3 端點 policy 可被審計增強刀沿用。

## 5. 授權（R_SUPER-only、沿 ⚠️b super-only）
1. 3 讀端 require_policy R_SUPER；menu policy R_SUPER（dynamic getUserRoutes 僅 super 見審計中心）。Admin/User→403/5003 不洩資料；授權依 DB-fresh `roles_of_user`（不信 claims）。

## 6. wire / i18n 不變式（§I.3 typings 權威、⚠️r、honest）
1. **wire id 域＝number**（各 log id／operatorId／entityId、⚠️r）；IpNetwork→字串（host 去 mask）；nullable→`string｜null`／`number｜null`（**honest、立先例、避 §3.12/§3.13 type-lie 家族**）；operation enum 對齊 005 AuditOperation（`INSERT/UPDATE/SOFT_DELETE/RESTORE`）。
2. **i18n**：`page.manage.audit.*`（先 Schema 後 locale、⚠️y）；唯一可能 biz＝`backend.biz.audit.invalidDateRange`。
3. **軌道（皆既授）**：rev3-* WRAPPER（3 fetch fn）／ADAPT（3 honest item 型）／MODAL-WIRING **(e)** 新管理頁（審計中心）／`page.manage.audit.*` I18N-WIRING。**route store/transform/system-manage.ts/auth.ts/request/既有 manage 頁不改**；無 .env flip。

## 7. endpoint_coverage_lint 漸增（⚠️x）
1. `AS_BUILT_ROUTES [31→34]`（+3 audit GET、與註冊同 commit）。
2. 3 端點皆 policy-governed（require_policy R_SUPER）→Assertion A m005 seed 自動過；B registered==as-built。handler/main 零 path-root entity::。

## 8. 本刀邊界（OUT／MOOT）
- **MOOT（已 done）**：3 log entity（002）／3 sink facade 寫端（005/007）／AuditOperation／INET·region（007）／PageRes·§5.8·escape_like·ilike·require_policy·enforce_mw·roles_for_users·find_by_id·endpoint_coverage_lint·entity_access_lint（004-011）／sys_login_attempt 索引（007）。
- **OUT（遞延）**：client_ip(peer)/xff_ip/real_ip 三欄統一 IP forensic 模型＋audit_ctx 寫端 peer/CF capture（D11、後續刀、同 §3.11 XFF 完整化+Cloudflare）／§3.12 user 角色變更 payload delta（D4）／log retention（⚠️n）／審計匯出 CSV（未列）／2xx-5xx 類別 quick-filter（UX 增強）／pg_trgm fuzzy GIN（scale follow-up）。
- 無 schema 業務表變更／無新 crate／enforce_mw·require_policy·From<DbErr> 不動／base-web frozen 不改／無 .env flip／**唯讀無寫無 cleanup**。
