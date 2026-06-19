# Implementation Plan: 012-audit-log-query（審計查詢讀端＋審計中心、波2 殿後刀）

**Branch**: `012-audit-log-query` | **Date**: 2026-06-19 | **Spec**: [spec.md](spec.md)

**Input**: [spec.md](spec.md)＋brainstorm `docs/superpowers/012-audit-log-query.md`（plan-phase act-on-code research 見 [research.md](research.md)）

## Summary

把三張既有 append-only 日誌表接出**唯讀查詢端＋Super-only「審計中心」單頁三分頁**：`getOperationLog`／`getAccessLog`／`getLoginAttempt`（皆 R_SUPER、GET、§5.8 分頁/filter）＋逐欄 fuzzy/exact 篩選（文字/IP 模糊、enum/數字精確、日期範圍、operator 按名）＋operator 名 enrich（含已刪）＋op-log payload 展開。**首個波 2 帶 migration 的刀**＝**m005 delta**（manage_audit menu seed＋3 讀端 R_SUPER policy＋manage_audit menu policy＋operation/access filter 索引；**無新業務表、無 ALTER 既有日誌表、up→down→up 可逆**）。**唯讀、零寫端、零 op-log 寫、live 無 cleanup**。三欄統一 IP forensic 模型（client_ip/xff_ip/real_ip、D11）＋user 角色變更 payload delta（D4）＝後續刀。

**plan-phase research 親驗（act-on-code、見 [research.md](research.md)）**：
1. **3 sink facade +list（R1）**：鏡像 `sys_role::list`（`(conn,page〔0-based〕,size,filter)->(Vec<Model>,u64)`、`.apply_if`/`.paginate.fetch_page.num_items`、order_by_desc created_at,id）；write sink 不動。
2. **§5.8 reuse（R2）**：normalize_* helper／escape_like／PageRes／get_user_list 模板。
3. **fuzzy 文字（R3）**：`Func::lower(col).like(LikeExpr.escape('\\'))`——**非 PgExpr::ilike**（sea-query 0.32.7 bug、沿 009 校正）。
4. **★ IP 模糊（R4）**：`host(col)::text LIKE`——**net-new SQL 形、無 codebase 先例、impl 須容器內驗渲染**（C-V-3 首要驗）；xff TEXT 直 LIKE。
5. **operator enrich（R5）**：**net-new `sys_user::names_for_ids`（unfiltered 含已刪）**；無既有批次 id→name 解析。
6. **m005 delta（R6）**：Migrator m004 後、execute_unprepared raw SQL、鏡像 m002 seed/m001 index。
7. **main/lint（R7）**：audit Router group 3 GET require_policy＋enforce_mw；`AS_BUILT [31→34]`。
8. **wire honest（R8）**：3 item 型從零、nullable→`｜null`、id number。

## Technical Context

**Language/Version**: Rust 1.86.0＋TypeScript/Vue 3。
**Primary Dependencies**: server **無新增 dep／無新 crate**（既有 sea-orm 1.1.20／axum 0.7）。base-web 零新 npm dep。
**Storage**: PostgreSQL（m001 schema）。本刀 **m005 delta migration**（sys_menu seed 1＋casbin policy 4＋filter 索引 4；**無新業務表、無 ALTER 既有日誌表**）；3 日誌表（sys_operation_log 10 欄／sys_access_log 10 欄／sys_login_attempt 9 欄、archetype B append-only）皆 002 既建。
**Testing**: rust 純測（filter where 組裝／operator-name 解析／IP-expr builder／normalize、若抽純函式）＋live `#[ignore]` smoke（3 端點分頁/filter／**IP 模糊 host()::text LIKE**／operator by 名／enrich、**唯讀無污染**）＋`endpoint_coverage_lint`(34)＋`entity_access_lint`＋**m005 up→down→up**。base-web `pnpm typecheck`＋CDP。**live `--test-threads=1`**；**★ 唯讀純 SELECT、無寫、無 cleanup**（異於 011 casbin 寫）。C-V 全集＝[contracts/verification-commands.md](contracts/verification-commands.md)。
**Target Platform**: 001 dev/prod 容器堆疊。
**Project Type**: web。rust：L4 facade（3 sink `list`＋filter＋`sys_user::names_for_ids`）＋L5 handler（system_manage.rs +3＋operator enrich＋日期 parse）＋L4 main（3 路由 require_policy）＋L8 lint bump＋migration（m005）；base-web L3 wrapper（rev3 3 fn）＋L1/L2 typings（3 honest item）＋L4 view（MODAL-WIRING (e) 審計中心 3 tab + 3 子表）＋Schema＋locale（`page.manage.audit.*`）。**無 .env flip**。
**Performance Goals**: 讀端分頁（⚠️a p95<300ms、靠 m005 btree 索引 created_at／operator_id）；模糊 LIKE（IP/path/帳號）seq scan（super-only 中量〔現 700 列級〕、⚠️a 預算內；pg_trgm GIN 為 scale follow-up、本刀不引 CREATE EXTENSION）。
**Constraints**: `enforce_mw`／`require_policy`／`From<DbErr>`／既有 3 日誌表 entity／3 sink 寫方法 本體不改；**唯讀無寫無 op-log**；**m005 delta（無新業務表、可逆）**；無新 crate；**base-web 既有檔不改**（route store/transform/system-manage.ts/auth.ts/request；無既有 audit 頁）；**★ IP 模糊 `host()::text LIKE` net-new、impl 驗**；無 .env flip；push/merge 凍結至 finishing（§I.4）。
**Scale/Scope**: 3 唯讀端點＋base-web 審計中心頁；現 sys_operation_log 41／access 723／login 213 列、production 增長（retention＝⚠️n OOS）。

## Constitution Check

*constitution-rev3 **v1.1.1** §IV 九題逐答——Phase 0 前＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | §I.1 base-web 權威？rust 缺 endpoint？ | **PASS**——審計頁 base-web 端【缺】（100% 淨新）；本刀同時建 base-web 審計中心頁＋rust 補 3 讀端；兩端俱在 |
| 2 | base-web inline MODAL-WIRING？fork-delta？ | **PASS**——MODAL-WIRING **(e) 新管理頁**（審計中心）＋WRAPPER（rev3 3 fn）＋ADAPT（3 honest item）＋I18N-WIRING（`page.manage.audit.*`）皆既授；route store/transform/system-manage.ts/auth.ts/request **frozen 不動**；rev3-inline 標記 |
| 3 | menu 走 Casbin enforce？demo ⚠️p？ | **PASS**——`manage_audit` menu policy（v2='menu'、R_SUPER）→ dynamic getUserRoutes 僅 super 見審計中心（§I.2）；⚠️p N/A（無 demo menu 新增） |
| 4 | wire §I.3 typings？ | **PASS**——3 item 型從零 honest（nullable→`string｜null`／`number｜null`）、id 域 number（⚠️r）、operation enum 對齊 005、IpNetwork→字串；無 type-lie（淨新無既有型可違） |
| 5 | rev2 source 拷貝？ | **PASS**——rev2 **零讀端**、wire 從零、code 全新寫（§I.5）；僅設計繼承 005/007 寫端基建（AuditOperation/INET/region） |
| 6 | §II 拍板 #1~#13 抵觸？ | **PASS**——無；⚠️r id 忠實（number、nullable honest） |
| 7 | §III ★ 軌道？邊界內？ | **PASS**——MODAL-WIRING (e)＋WRAPPER＋ADAPT＋BASE-WEB-I18N-WIRING 既授；frozen 檔不動 |
| 8 | 新建業務表（migration）？§I.6 六審計欄？ | **PASS（未觸新業務表）**——m005 delta＝`manage_audit` sys_menu seed 1＋casbin policy seed 4＋operation/access filter 索引 4；**無新業務表、無 ALTER 既有日誌表**；3 日誌表 archetype B（append-only、002 既建）、§I.6 archetype A 六審計欄義務**未觸**；唯讀**不寫**審計欄 |
| 9 | 觸 §I.7 行為島（token/policy/single-session）？ | **PASS**——日誌表**非行為島**（無狀態機）；本刀**純讀不觸**任何 invariant（不寫 policy/token/session）；op-log `entity_table='casbin_rule'` 列＝011 policy 寫之稽核軌、本刀**如實顯示、不寫** |

**Gate 結論：9/9 PASS；無 Amendment；m005 delta（無新業務表、無 ALTER、up→down→up 可逆）；無新 crate；唯讀無寫無 op-log；Q8 §I.6 未觸（無新業務表）、Q9 §I.7 純讀不觸行為島；Complexity Tracking 不適用。**

> **無新 crate ⇒ prod build 輕**：3 讀端皆 server 內 facade/handler/模組＋m005 migration（無 workspace crate 新增）；C-V 仍跑 prod target build。

## Project Structure

### Documentation (this feature)
```text
specs/012-audit-log-query/
├── spec.md              # /speckit-specify ✅（7 US／12 FR／9 SC／6 Clarifications）
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1 list・R2 §5.8・R3 fuzzy・R4 IP-expr net-new・R5 names_for_ids・R6 m005・R7 main/lint・R8 wire）
├── data-model.md        # Phase 1 ✅（3 facade list+filter＋names_for_ids＋3 handler＋m005＋wire＋base-web）
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   ├── verification-commands.md      # C-V-0~9
│   └── audit-log-query-contract.md   # 跨 feature 不變式（唯讀讀端／enrich／fuzzy・IP／m005 delta／R_SUPER／wire honest）
└── checklists/requirements.md        # 17/17 ✅
```

### Source Code (repository root)
```text
rust-api/server/src/
├── model/facade/sys_operation_log.rs  # 改：+list(§5.8 filter)+OperationLogFilter（write sink 不動）
├── model/facade/sys_access_log.rs     # 改：+list+AccessLogFilter
├── model/facade/sys_login_attempt.rs  # 改：+list+LoginAttemptFilter
├── model/facade/sys_user.rs           # 改：+names_for_ids（net-new、unfiltered 含已刪、enrich）
├── handler/system_manage.rs           # 改：+get_operation_log/get_access_log/get_login_attempt+3 Query DTO+operator enrich+日期 parse+IP/text fuzzy 組裝
├── main.rs                            # 改：audit Router group 3 GET route_layer(require_policy)+.merge(audit)（enforce.rs 不改）
└── (error.rs 不改 blanket)            # 唯一 biz：畸形日期 invalidDateRange 2222（僅起/僅訖寬鬆容忍、F2 定）
rust-api/migration/src/
├── m005_audit_log_query.rs            # ★ 新：up（sys_menu manage_audit+casbin 4+索引 4、execute_unprepared）/down（對稱、可逆）
└── lib.rs                             # 改：+mod m005_audit_log_query+Box::new（m004 後）
rust-api/server/tests/endpoint_coverage_lint.rs  # 改：AS_BUILT_ROUTES [&str;31]→[&str;34]（+3）
base-web/src/
├── service/api/rev3-system-manage.ts      # 改（WRAPPER）：+fetchGetOperationLog/AccessLog/LoginAttempt
├── typings/api/rev3-system-manage.d.ts    # 改（ADAPT）：+OperationLogItem/AccessLogItem/LoginAttemptItem（honest）+SearchParams+XxxLogList
├── views/manage/audit/index.vue           # ★ 新（MODAL-WIRING (e)）：NTabs 3 tab
├── views/manage/audit/modules/{operation-log-table,access-log-table,login-attempt-table}.vue  # ★ 新：NDataTable+filter+NPagination+payload 展開
├── typings/app.d.ts                        # 改（I18N-WIRING）：Schema page.manage.audit.*（先 Schema 後 locale）
└── locales/langs/{zh-cn,en-us}.ts          # 改：page.manage.audit.*
# ALREADY（不動）：entity/src/{sys_operation_log,sys_access_log,sys_login_attempt}.rs／3 sink 寫方法／m001-m004／AuditOperation／require_policy・enforce_mw・PageRes・§5.8 normalize・escape_like・ilike seam・roles_for_users・find_by_id・endpoint_coverage_lint・entity_access_lint・From<DbErr>／sys_login_attempt 索引（007）／base-web route store・transform・system-manage.ts・auth.ts・request・既有 manage 頁
```

**Structure Decision**：web。rust：facade（3 sink list＋filter＋names_for_ids enrich）＋handler（3 端點＋operator enrich）＋main（audit group）＋m005 migration＋lint bump。base-web：WRAPPER＋ADAPT＋MODAL-WIRING (e) 審計中心＋locale（既有檔不改、無 .env flip）。**m005 delta（無新業務表）／無新 crate／唯讀**。

## Complexity Tracking

> 無 Constitution violation（9/9 PASS）→ 不適用。

## 實作注意（移交 tasks；~2 Workflow 單元 §12）

1. **★ 順序（rust serial、容器內、改 .rs 先 force-touch）**：U1 rust 讀端＋m005（3 sink list＋filter／`sys_user::names_for_ids`／handler 3＋operator enrich／main 3 路由／lint[34]／**m005 migration**〔seed+index、up→down→up 驗〕／純測〔filter/enrich/IP-expr 若抽純〕／live〔3 端點分頁/filter/**IP 模糊**/operator by 名/enrich、**唯讀無污染**〕）→ U2 base-web 審計中心頁（3 wrapper＋3 honest typing＋audit/index.vue 3 tab+3 子表＋i18n＋typecheck＋CDP）。
2. **★ IP 模糊 `host(col)::text LIKE`＝net-new、無 codebase 先例**（R4）：U1 facade live smoke **首要驗**（C-V-3 帶 dev DB 已知 client_ip 片段、確認 sea-query 渲染正確命中）；確切 expr（`Expr::cust_with_values` vs `cast_as`）impl 容器內定。
3. **operator enrich net-new `names_for_ids`（unfiltered 含已刪）**（R5）；operatorName 模糊篩＝handler user_name LIKE→ids→`operator_id IN`。
4. **m005 delta（R6）**：Migrator m004 後；execute_unprepared raw SQL（鏡像 m002 seed／m001 index）；sys_menu manage_audit＋casbin 4＋索引 4；**idempotent（F3）：sys_menu `ON CONFLICT (route_name) WHERE deleted_at IS NULL DO NOTHING`〔partial unique〕／casbin `(ptype,v0..v5)`／索引 `IF NOT EXISTS`**；**無新業務表、無 ALTER**；**up→down→up 可逆**（C-V-5）。
5. **★ 唯讀無污染**：3 讀端純 SELECT、不寫日誌/不寫 op-log；live/CDP **無 cleanup**（異於 011）；對 dev DB 現有資料取已知值驗 filter。
6. **fuzzy `LOWER LIKE ESCAPE`（非 PgExpr::ilike、沿 009 校正）**（R3）；escape_like 復用。
7. **lint（R7）**：`AS_BUILT [31→34]`；3 audit policy m005 seed；entity_access：handler/main 零 path-root entity::、3 sink list 走 model/facade/ 豁免。
8. **base-web**：rev3 wrapper 3／3 honest item（nullable→`｜null`）／MODAL-WIRING (e) 審計中心 3 tab／`page.manage.audit.*` i18n 先 Schema 後 locale／frozen 既有檔不改／無 .env flip。
9. **m005 menu seed → view 須同刀**（U1 seed→U2 view）避 dangling component error（沿 010 §3.13 manage_policy-archive）；U2 view 落地前 dev Super 點 /manage/audit 會 **throw**（`getViewName` 對缺 view 之 dynamic route throw `View component … not found`、`base-web/src/router/elegant/transform.ts:58-66`）、**非 console warn**——故 view 與 m005 menu seed 同 feature 收口（F5）。
10. **容器內 build/test**（host 無 cargo）／force-touch／**live `--test-threads=1`＋DATABASE_URL**／逐單元兩段式 commit（worktree→pin、S9）／base-web `--no-verify`／**不 push/merge（§I.4）**／CDP 不 defer（唯讀無 cleanup）。
11. **零回歸（FR-012/SC-008）**：enforce_mw/require_policy/From<DbErr>/既有 3 日誌表 entity/3 sink 寫/login/getUserInfo/getUserRoutes/health/008-011 不變；m005 僅 seed+index（無業務表）、up→down→up 可逆；base-web frozen 不改。
