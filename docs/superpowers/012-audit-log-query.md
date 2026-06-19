# 012-audit-log-query — Phase 0 Brainstorm（spec-design）

> **波 2 殿後刀＝審計查詢讀端＋UI**（資料島群 User→Menu→Role 之後的 read-only reporting 刀）。本檔＝階段 0 brainstorm 產出，作為階段 1 `/speckit-specify` 的 input。
> act-on-code 接地源＝當前 lineage（rust-api `30de791`／base-web `caa1e4bc`、皆 011 收刀後）親 grep＋psql ground-truth；rev2 設計借鏡不照拷（§I.5／RUSTAPI-SOURCE-ISOLATION：rev2 **零讀端**、無 source 可拷、wire 從零）。
> 拍板已於 brainstorm 對話定（user 親決）：**D1 UI＝單頁三分頁（審計中心 /manage/audit）**／**D4 §3.12 user 角色變更 payload delta＝延後**／**D5 m005 delta migration＝接受**（破 009/010/011 零-migration 連勝、合 ⚠️t）／**D11 client_ip/xff_ip/real_ip 三欄統一 IP forensic 模型＝延後**（讀端先行、012 讀現 schema、IP 模型+寫端 ALTER 留後續刀、§11）／**D12 逐欄 fuzzy/exact filter**（文字/IP 欄模糊、enum/bool/數字精確/下拉、日期範圍；全表 §4.1）。

---

## 1. 目標一句話

把三張 append-only 日誌表（005/007 既建）接出**唯讀查詢端＋Super-only「審計中心」頁**：`getOperationLog`（誰改了什麼資料）／`getAccessLog`（誰存取了哪些 API）／`getLoginAttempt`（誰嘗試登入、成敗）——各 §5.8 分頁/filter，前端單頁三分頁。**首個波 2 帶 migration 的刀**（m005 delta：menu seed + 3 讀端 policy + filter 索引）；**零 CRUD、零寫端**（讀 op-log、不寫 op-log）。

## 2. Context（探索蒐集、act-on-code 親驗）

### 2.1 前代 rev2 參照（無、wire 從零）
rev2 三 sink facade 寫端在、**讀端零、前端零**（無 audit feature）。故 wire 從零設計、無 mock 可鏡像（§I.5 設計繼承僅及 005/007 寫端基建：`AuditEvent`/`AuditOperation`/INET/region）。⚠️b（DECISIONS §1）已拍：做、排波 2 殿後（read-only reporting 可殿後讓核心 CRUD 先清波 2）。

### 2.2 ★ 當前 lineage 已落地（不重做、MOOT）
- **entity**（002 baseline、`entity` crate、append-only archetype B）：
  - `sys_operation_log`（10 欄）：id／operation／entity_table／entity_id?／payload_before?(Json)／payload_after?(Json)／operator_id?／operator_ip?(INET)／trace_id?／created_at。
  - `sys_access_log`（10 欄）：id／operator_id(**NOT NULL**)／method／path／http_status(i32)／client_ip(INET NOT NULL)／x_forwarded_for?／region?／trace_id?／created_at。
  - `sys_login_attempt`（9 欄）：id／attempted_user_name／success(bool)／operator_id?／client_ip(INET NOT NULL)／x_forwarded_for?／region?／trace_id?／created_at。
- **facade（全寫端 sink、零讀方法）**：
  - `sys_operation_log::write_in_txn(txn, AuditEvent)`（005、INSERT-only、archetype B）。
  - `sys_access_log::write(db, &AccessLogEvent)`＋`access_log_active_model`（純 seam）＋pub `AccessLogEvent`（007、best-effort）。
  - `sys_login_attempt::write(db, &LoginAttemptEvent)`＋`login_attempt_active_model`（純 seam）＋pub `LoginAttemptEvent`（007、exactly-one per attempt）。
- **AuditOperation 封閉詞彙**（005、§3.8 契約）：`INSERT`／`UPDATE`／`SOFT_DELETE`／`RESTORE`（`as_str()`）——op-log filter by-operation 下拉須對齊此 enum、勿造 `DELETE` 等失準值。
- **infra 復用**：`require_policy`（008）／`PageRes`（009、`{current,size,total,records}` camelCase）／§5.8 normalize（`normalize_str_filter` 空字串守門／`normalize_enum_filter`／`normalize_current`(default 1 floor 1)／`normalize_size`(default 10 clamp[1,100])、009）／`enforce_mw`＋DB-fresh `roles_of_user`（006）／`sys_user` 批次解析（`roles_for_users` 批次精神、009、供 operator_id→user_name enrich）／`endpoint_coverage_lint`（現 AS_BUILT `[&str;31]`）＋`entity_access_lint`。
- **psql ground-truth（現有資料、讀端對象）**：sys_operation_log 41 列（含 011 起的 `entity_table='casbin_rule'` policy 異動列）／sys_access_log 723 列／sys_login_attempt 213 列。
- **既有索引**：`sys_login_attempt`：`idx_login_attempt_ip_time`(client_ip,created_at)＋`idx_login_attempt_user_time`(user_name,created_at)（007 lockout 用、本刀 filter 復用＝「login 已就緒」）；`sys_operation_log`／`sys_access_log` **僅 pkey**（filter 索引待 m005 補）。

### 2.3 rust-api GAPS（`30de791` 親驗、本刀 BUILD）— 3 net-new 讀端
| 端點 | method | seed v0 | protected | 性質 |
|---|---|---|---|---|
| `/systemManage/getOperationLog` | GET | R_SUPER | f | sys_operation_log 讀（§5.8 分頁/filter） |
| `/systemManage/getAccessLog` | GET | R_SUPER | f | sys_access_log 讀 |
| `/systemManage/getLoginAttempt` | GET | R_SUPER | f | sys_login_attempt 讀 |

> 3 讀端 policy **未 seed**（psql 驗空）→ m005 補（**非零-migration**）。皆 R_SUPER-only（⚠️b super-only 稽核；R_ADMIN 不給）。

### 2.4 base-web 現況（§I.1 權威、`caa1e4bc` 親驗）— **100% 淨新**
- `views/manage/` 只有 menu/role/system-settings/user/user-detail；**無 audit/log/monitor 任何頁/folder**。
- typings（api/system-manage.d.ts／app.d.ts）**零** OperationLog/AccessLog/LoginAttempt/Audit 型。
- 路由/i18n **零** audit 鍵。
- **結論：非 mock→real、是全新頁**——3 wire 型從零定義（honest：nullable 欄一律 `string | null`，不重蹈 §3.12/§3.13 type-lie 家族）。

### 2.5 DESIGN §8.2／§5.0／§5.8 對應面
- DESIGN §8.2：⚠️b 審計讀端＋UI＝波 2 殿後刀（read-only reporting）；MODAL-WIRING use (e)＝新管理頁。
- DESIGN §5.8：§5.8 分頁/filter（空字串守門）＝本刀 3 端點復用；perf ⚠️a（p95 讀 < 300ms、靠 filter 索引）。
- §5.0/§I.7：日誌表非行為島、無狀態機；本刀純讀，不觸行為島。

### 2.6 三端 wire shapes（rust ↔ base-web ↔ §I.3、⚠️r 逐欄忠實、honest typings）
| wire | base-web typing（淨新 honest） | rust 來源 | 映射 |
|---|---|---|---|
| `OperationLog.id`／各 id | number | i64 | number（⚠️r 管理域） |
| `operation` | `'INSERT'\|'UPDATE'\|'SOFT_DELETE'\|'RESTORE'` | String（AuditOperation） | enum 對齊（§3.8 契約） |
| `operatorId` | `number \| null` | Option<i64>（access_log NOT NULL→number） | 直 |
| `operatorName`（★ enrich） | `string \| null` | sys_user 批次解析（operator_id→user_name、**unfiltered 含已刪**） | server enrich；null=僅系統 op（operator_id NULL） |
| `operatorIp`（op-log）／`clientIp`（access·login、=**解析後** IP） | `string \| null` | IpNetwork（INET） | 序列化字串、`host()` 去 mask；模糊 `::text LIKE`（D12） |
| `xForwardedFor`（access·login、**原始 XFF** 鏈） | `string \| null` | Option<String>（TEXT） | 直、模糊 LIKE。★ 現 schema 不對稱：op-log 僅 operator_ip、無 xff（D11 統一模型延後） |
| `region` | `string \| null` | Option<String> | 直、模糊 LIKE |
| `payloadBefore`/`payloadAfter` | `Record<string,any> \| null` | Option<Json> | jsonb 原樣、前端展開顯示 |
| `success` | boolean | bool | 直 |
| `createTime` | string | DateTimeWithTimeZone | 直 |
| filter `createdFrom`/`createdTo` | string（ISO） | parse→DateTimeWithTimeZone 範圍 | 時序稽核核心（D8） |
> 全淨新型→**零既有 type-lie 風險**、本刀立 honest 先例（nullable→`string｜null`）。

### 2.7 消費者／被消費
- **本刀消費**：005/007 三 sink 寫入的真實資料（41/723/213 列）；009 `roles_for_users` 批次精神（operator enrich）；§5.8/PageRes（009-011）。
- **本刀被未來消費**：⚠️w login lockout（消費 sys_login_attempt 讀端＋索引）；波 3 policy-governance（op-log `entity_table='casbin_rule'` 列＝policy 異動稽核軌）。
- **收掉的既有 follow-up**：§3.4（sys_access_log/sys_login_attempt 的 `client_ip` IpNetwork **decode round-trip** 首次以 entity Model 讀回）／§3.8（op-log `operation` 字串契約對齊：by-operation filter rust enum↔base-web 下拉一致）。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | UI 版面 | **單頁三分頁**（**user 拍**）：側欄 1 項「審計中心」→ `/manage/audit`，頁內 3 tab（操作異動/API 存取/登入嘗試）。m005 seed 1 列 sys_menu + 1 menu policy、前端 1 頁元件 + 3 tab 子表 | 三 log 為一個稽核 concern 的三視角、集中側欄乾淨、menu seed 最少。否決「三獨立側欄頁」（側欄多 4 項、3 頁元件、4 menu seed） |
| D2 | 端點形 | **3 忠實端點**（getOperationLog/getAccessLog/getLoginAttempt、工程）：各自 §5.8 list fn + filter DTO，忠實對映 3 張不同 schema | 否決「1 通用 audit 端點 + type 參數」（union 形漏抽象、3 schema 硬塞一型、filter 尷尬；省 code 不值）。對齊 DESIGN「3 端點」意圖 |
| D3 | operator 顯示 | **server 端批次 enrich `operator_id→user_name`**（沿 009 `roles_for_users` 批次、免 N+1、工程） | 審計要顯示「誰」（名）非裸 id；前端保持 dumb。★ enrich 用 **unfiltered** sys_user lookup（**含 soft-deleted**、沿 006 `find_by_id` 不濾 deleted_at）→ 歷史操作者即使後來被刪仍顯示名（審計正確性）；`operatorName` null **僅**當 operator_id NULL（系統 op） |
| D4 | §3.12 user 角色變更 payload delta | **延後**（**user 拍**）：審計頁顯示現有 op-log payload；009 addUser/updateUser payload 只存 `sys_user` Model、不含 `sys_user_role` 角色集 delta（「user X 角色由 [A]→[A,B]」現查不到） | retrofit 009 寫端＝動已完成 feature + **歷史 41 列補不回** = read 刀 scope creep。文件化此限制、未來寫端增強刀再補（注：011 updateRoleMenu payload **有**存 route_name 集 before/after、role-menu 變更已可審） |
| D5 | migration | **m005 delta migration**（**user 拍**、首個波 2 migration）：① `manage_audit` sys_menu 1 列（parent=manage）；② casbin seed 3 讀端 R_SUPER + `manage_audit` menu policy（v2='menu'）；③ `sys_operation_log`/`sys_access_log` filter 索引（login 已備） | 審計頁 menu/policy/索引 rev2 終態無、psql 驗皆空 → **不可免**、不動 frozen m002（rev2 終態 baseline、⚠️t）、以 m005 delta 顯式分離（合 ⚠️t）。破 009/010/011 零-migration、但正當（淨新功能非基線缺口） |
| D6 | typings | **3 wire 型從零 honest**（nullable→`string｜null`／`number｜null`、工程） | 100% 淨新無既有型可守、立 honest 先例、避免 §3.12/§3.13 type-lie 家族；⚠️r id 域 number |
| D7 | 授權 | **3 端點 R_SUPER-only**（沿 ⚠️b super-only、工程）；menu policy 亦僅 R_SUPER | 稽核敏感、super-only；R_ADMIN/User→5003。審計頁 dynamic menu 僅 super 見 |
| D8 | 時序 filter | **created_at 範圍（from/to）必備**（工程） | 三表皆 time-series、查「某段時間」是稽核核心；ISO 字串→DateTimeWithTimeZone 範圍 |
| D9 | payload 顯示 | **op-log before/after jsonb 前端展開顯示**（工程/UX） | payload 為 jsonb 快照、表格行可展開看 diff；access/login 無 payload |
| D10 | log retention/cleanup | **out of scope（⚠️n、拍）** | 本刀純讀；日誌無限長清理＝另一開放拍板 ⚠️n、波次未定、不在本刀 |
| D11 | 3-IP forensic 模型（client_ip=peer/xff_ip/real_ip 三表統一） | **延後**（**user 拍 C：讀端先行**）：012 讀【現】schema 既有 IP 欄〔op-log `operator_ip`／access·login `client_ip`〔=已解析〕+`x_forwarded_for`〔=原始 XFF 鏈〕〕；三欄統一 forensic 模型〔ALTER 3 表加 client_ip(peer)/xff_ip/real_ip + audit_ctx 存 peer〔ConnectInfo 已取得未存〕+ CF-Connecting-IP header + 串 3 IP 進 3 sink/`AuditEvent`/`AuditOperator`〕＝**後續刀**（§11） | read 刀先交付；IP 模型動 frozen entity（002）+ 005/007 audit infra（同 §3.11 XFF 完整化）= 獨立刀較乾淨、ALTER 既有資料表需 backfill 策略。現 schema：access/login `client_ip` 實為**解析後** IP〔UI 標「Client IP(解析)」避誤導〕、`x_forwarded_for`＝原始 XFF |
| D12 | per-field filter fuzzy/exact | **逐欄拍**（**user 拍**、補「你沒讓我選」）：文字/IP 欄**模糊**〔IP `host(col)::text LIKE`、XFF/path/帳號/region/entity_table/trace `LOWER LIKE ESCAPE`〕、enum/bool/數字**精確/下拉**、created_at **範圍**；operator 篩 **by 名模糊**（handler resolve user_name→ids→`operator_id IN`）。全表 §4.1 | 審計常按部分 IP/路徑/帳號搜尋（模糊）；operation/method/success 為有限集（下拉精確）。**4 子選擇我定預設（可改）**：entity_table=模糊／operator=by名模糊／http_status=精確(number)〔2xx/4xx/5xx 類別 quick-filter＝UX 增強 follow-up〕／trace_id=模糊 |

## 4. 元件設計（act-on-code、當前 lineage seam 名）

### 4.1 facade（3 sink facade 各加讀 fn、append-only 純 SELECT）＋逐欄 filter（D12）
3 檔各加（既有 write 方法不動）：`list(conn, current:u64, size:u64, filter: XxxLogFilter) -> Result<(Vec<Model>, u64), DbErr>`（SELECT + count(*)、order by `created_at DESC, id DESC`〔穩定〕、§5.8 空字串守門、`entity::` 走 lint 豁免）。逐欄 filter mode（D12；**模糊**＝`LOWER(col) LIKE … ESCAPE`〔沿 009 校正、非 `PgExpr::ilike`〕、**IP 模糊**＝`host(col)::text LIKE`、**精確**＝`eq`、**範圍**＝`gte/lte`）：

| Tab | 欄位（現 schema）→ filter mode |
|---|---|
| **操作異動** sys_operation_log | operation〔精確下拉 enum〕／entity_table〔模糊〕／operator〔模糊 by 名→handler resolve→`operator_id IN`〕／operator_ip〔模糊 host()::text〕／entity_id〔精確 i64〕／trace_id〔模糊〕／created_at〔範圍 from/to〕 |
| **API 存取** sys_access_log | operator〔模糊 by 名〕／method〔精確下拉〕／path〔模糊〕／http_status〔精確 i32；2xx/4xx/5xx 類別 quick-filter＝UX 增強 follow-up〕／client_ip〔模糊、UI 標「解析」〕／x_forwarded_for〔模糊 TEXT〕／region〔模糊〕／created_at〔範圍〕 |
| **登入嘗試** sys_login_attempt | attempted_user_name〔模糊〕／success〔精確下拉 bool〕／client_ip〔模糊〕／x_forwarded_for〔模糊 TEXT〕／region〔模糊〕／created_at〔範圍〕 |

各 `XxxLogFilter` struct（Option 欄、對映上表；模糊欄收字串、operator 收 handler-resolved `operator_ids: Option<Vec<i64>>`、IP 收字串、created_from/to 收 DateTimeWithTimeZone）。
> 純讀無 mutate_in_txn、無 op-log（讀者非寫者）；無 build_active_model（無寫）。★ **operator by 名**：handler 先 `sys_user` user_name `LIKE` → user_id 集（**unfiltered 含已刪**、與 enrich 一致）→ facade `operator_id IN`；名無匹配→空頁。★ **IP 模糊**：INET 欄 `host(col)::text LIKE`（host 去 /32 mask、利於部分比對；XFF 已 TEXT 直 LIKE）。

### 4.2 handler（system_manage.rs +3、沿 009 get_user_list、§5.8）
`get_operation_log`／`get_access_log`／`get_login_attempt`（State, Extension<Claims>, Query<XxxLogQuery>）-> `Res<PageRes<XxxLogItem>>`：normalize（current/size、空字串守門 str/enum、日期 parse、★ `operatorName` 模糊→`sys_user` user_name `LIKE` 解析成 `operator_ids`〔unfiltered〕）→ facade.list〔逐欄 filter D12〕 → **operator 批次 enrich**（收集 records 的 operator_id 集 → `sys_user` 批次查 user_name map〔**unfiltered 含 soft-deleted**、審計保留已刪操作者名、沿 006 find_by_id 不濾 deleted_at〕 → 填 operatorName）→ PageRes。回型 `Result<Json<Res<Value>>, AppError>`、handler 零 path-root `entity::`（資料經 facade、enrich 經 sys_user facade 批次 fn）。日期 parse 失敗→`biz.audit.invalidDateRange` 2222（或寬鬆忽略、plan 定）。

### 4.3 main（3 路由 require_policy + lint）
入 systemManage 群：getOperationLog/getAccessLog/getLoginAttempt 各 GET `route_layer(require_policy(path,"GET"))` R_SUPER + 外層 enforce_mw（不改 enforce.rs）。`endpoint_coverage_lint` `AS_BUILT_ROUTES [&str;31]→[&str;34]`（+3、同 commit；3 policy m005 seed）。

### 4.4 ★ m005 delta migration（首個波 2 migration、不動 frozen m002）
新 `migration/src/m005_audit_read.rs`（Migrator 註冊）：
- **up**：① INSERT sys_menu `manage_audit`（menu_type=目錄子頁、route_name='manage_audit'、parent=subquery manage、component='view.manage_audit'、status=啟用、order）；② INSERT casbin_rule 4 列（`('p','R_SUPER','/systemManage/getOperationLog','GET',...)` ×3 端點 + `('p','R_SUPER','manage_audit','menu',...)` menu policy、沿 m002 row pattern、protected=false created_by=NULL）；③ `CREATE INDEX`（btree）：sys_operation_log(created_at desc)〔預設排序+範圍〕／(operator_id,created_at)；sys_access_log(created_at desc)／(operator_id,created_at)（精確索引集 plan 定）。★ **模糊 LIKE filter（IP/path/帳號/region/entity_table/trace）靠 seq scan**（super-only 中量〔現 700 列級〕、⚠️a 預算內）；`pg_trgm` GIN 為 scale 預留 perf follow-up（避免 m005 引 `CREATE EXTENSION`）。sys_login_attempt 索引 007 已備（ip/user × created_at）。
- **down**：對稱 DELETE/DROP INDEX（**up→down→up 可逆**、波 0 出口紀律沿用）。
- ★ 注意：menu seed 後 dynamic getUserRoutes Super 即見「審計中心」（無前端 view 會報 `View component not found` console error〔沿 010 §3.13 manage_policy-archive 同形〕→ base-web view 須同刀落、避免 dangling）。

### 4.5 base-web 審計中心頁（MODAL-WIRING (e) 新管理頁、100% 淨新）
- **WRAPPER** `service/api/rev3-system-manage.ts`：+`fetchGetOperationLog(params)`／`fetchGetAccessLog(params)`／`fetchGetLoginAttempt(params)`（GET、params=filter+分頁）。
- **ADAPT** `typings/api/rev3-system-manage.d.ts`：+`OperationLogItem`／`AccessLogItem`／`LoginAttemptItem`（honest、nullable→`｜null`）＋各 SearchParams＋`XxxLogList=PaginatingQueryRecord<Item>`。
- **MODAL-WIRING (e) 新頁** `views/manage/audit/index.vue`（NTabs 3 tab）＋3 tab 子元件（`modules/operation-log-table.vue`／`access-log-table.vue`／`login-attempt-table.vue`，各 NDataTable + filter 列 + NPagination、operation 下拉對齊 enum、success 下拉、日期範圍 NDatePicker、op-log payload 行展開）。
- **i18n** `app.d.ts` Schema + `langs/{zh-cn,en-us}` `page.manage.audit.*`（tab/欄/filter label）＋（若有 biz err）`backend.biz.audit.*`（先 Schema 後 locale）。
- route：dynamic menu 自動帶（m005 menu seed）；route store/transform/system-manage.ts/auth.ts/request **frozen 不改**；無 .env flip。

### 4.6 error.rs 消費（沿 009、不改 blanket）
讀端少 biz err；若日期 parse 嚴格→`AppError::Biz("biz.audit.invalidDateRange")` 2222（或寬鬆忽略、plan 定）；無 23505（純讀無寫）。blanket `From<DbErr>` 不改。

## 5. wire / 碼 / INET / i18n
- wire id：各 log `id` number（⚠️r）；operatorId/entityId `number｜null`；operation enum 對齊 §3.8。
- INET：operator_ip/client_ip 序列化為字串（IpNetwork→字串、§3.4 首次 decode round-trip 讀回 access/login 的 client_ip）；**模糊查詢 `host(col)::text LIKE`**（D12）。XFF（x_forwarded_for、TEXT）直 LIKE。
- operator 篩 **by 名**：handler `sys_user` user_name `LIKE`→user_id 集（unfiltered 含已刪、與 enrich 一致）→facade `operator_id IN`；名無匹配→空頁。
- biz key（極少）：`backend.biz.audit.invalidDateRange`（若嚴格、⚠️y）。
- i18n page：`page.manage.audit.{title, tab.operation, tab.access, tab.login, col.*, filter.*}`（先 Schema 後 locale、沿 009/010/011）。
- op-log：**本刀不寫 op-log**（讀者；查詢動作不審計自身、沿一般讀端慣例）。

## 6. 範圍邊界

**IN**：3 sink facade 讀 fn（list §5.8 filter + count）／handler 3 端點（operator 批次 enrich、日期範圍、空字串守門）／main 3 路由 R_SUPER + lint `[31→34]`／**m005 delta migration**（manage_audit menu seed + 3 讀端 policy + manage_audit menu policy + operation/access filter 索引）／base-web 審計中心頁（NTabs 3 tab + 3 子表 + 3 wrapper + 3 honest typing + i18n）／純測（filter where 組裝/operator enrich map、若抽純函式）＋live（3 端點分頁/filter 對真實 41/723/213 列、policy-gate 5003）＋CDP（審計中心頁 3 tab 真發 + filter + 分頁 + payload 展開）。

**OUT（遞延）**：**client_ip/xff_ip/real_ip 三欄統一 IP forensic 模型 + audit_ctx 寫端 peer/CF capture（D11、後續刀、§11；ALTER 3 表 + 005/007 audit infra、同 §3.11 XFF 完整化）**／§3.12 user 角色變更 payload delta（D4、未來寫端增強刀）／log retention/cleanup（⚠️n、波次未定）／審計資料匯出（CSV/Excel、未列需求、不做）／即時 streaming/tail（非需求）／op-log 自身查詢動作審計（讀者不自審）／圖表/儀表板（波 4 obs，非本刀）。

**MOOT（lineage already-done、不重做）**：3 log entity（002）＋3 sink facade 寫端（005/007）＋`AuditOperation` enum＋INET/region resolution（007 xdb）＋`PageRes`/§5.8 normalize/`require_policy`/`enforce_mw`/`endpoint_coverage_lint`/`entity_access_lint`（004-011）＋`sys_user` 批次解析（009）＋sys_login_attempt 索引（007）。

## 7. enforce/track pattern 留痕（`/speckit-plan` Constitution Check 對齊用）
- **§I.1 base-web 權威**：審計頁 100% 淨新（MODAL-WIRING (e)）→ rust 補 3 對應讀端；兩端俱在（本刀同時建兩端）。
- **§I.2 menu-Casbin-enforce**：manage_audit menu policy（v2='menu'、R_SUPER）→ dynamic getUserRoutes 僅 super 見審計中心（沿 010 讀寫閉環的讀端）。
- **§I.3 typings 權威／⚠️r**：3 wire 型 honest 從零、id number、nullable→`｜null`（無 type-lie）。
- **§I.6 審計欄**：本刀**讀** op-log、**不寫**（無寫端審計欄義務）；讀端不 mutate。
- **§I.7 行為島**：日誌表非行為島（無狀態機）、純讀不觸；op-log `entity_table='casbin_rule'` 列＝011 policy 寫的審計軌、本刀如實顯示。
- **★ migration（D5）**：首個波 2 migration＝m005 delta（不動 frozen m002、合 ⚠️t「delta 顯式分離」）；plan Constitution Check Q8（新 migration？§I.6 六審計欄？）須評估——本刀 migration **無新業務表**（僅 seed 列 + 索引）、不觸 archetype A 六審計欄義務。
- **MODAL-WIRING (e)**：§III 軌道「新管理頁」已授（軌道快查 §6）。
- 無新 crate。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）
**FR（草案）**：FR-1 super 可分頁/filter 瀏覽操作異動日誌（entity_table/operation/operator/日期）。FR-2 super 可瀏覽 API 存取日誌（operator/method/path/status/region/日期）。FR-3 super 可瀏覽登入嘗試（帳號/成敗/IP/region/日期）。FR-4 三端點顯示操作者**名**（operator_id→user_name unfiltered enrich、含已刪操作者仍顯示名、null 僅系統 op）。FR-5 op-log 行可展開看 payload before/after。FR-6 越權：3 端點 R_SUPER-only、非授權→403 不洩資料、授權依系統當下角色。FR-7 空字串 filter 守門（未設 filter 略過、§5.8）。FR-8 created_at 範圍 filter。FR-9 零回歸（login/getUserInfo/getUserRoutes/User/Menu/Role 不變）、m005 up→down→up 可逆。FR-10 wire honest（nullable→`｜null`、無 type-lie）。FR-11 逐欄 filter mode（D12：文字/IP/path/帳號/region/entity_table/trace **模糊**〔含 operator by 名〕、operation/method/success **精確下拉**、http_status/entity_id 精確數字、created_at **範圍**）。

**SC（草案）**：SC-1 三端點分頁/filter 100% 正確（對真實 41/723/213 列、空字串略過）——live+CDP。SC-2 operator name enrich 100% 正確（id→名、null 安全）。SC-3 越權 403、授權依當下角色——live+CDP。SC-4 op-log payload 展開顯示——CDP。SC-5 端點守恆（endpoint_coverage_lint `[34]` + entity_access_lint）。SC-6 零回歸、零既有檔改（base-web frozen、enforce_mw/require_policy/From<DbErr> 不變）。SC-7 m005 up→down→up 可逆、無新業務表。SC-8 全鏈真發 request、訊息在地化——CDP。

## 9. C-V 驗收（草案、live 一律 `--test-threads=1` serial+DATABASE_URL；rust 容器內 `docker exec`、改 .rs 先 force-touch）
C-V-0 build `--locked`（無新 crate）。C-V-1 純測（filter where 組裝/operator enrich map/日期 parse、若抽純函式）。C-V-2 lint（endpoint_coverage_lint `[34]` + entity_access_lint）。C-V-3 live 3 端點分頁/filter（對真實列、空字串守門回全部、operation/success 精確、日期範圍、★ **模糊**〔path/帳號/IP `host()::text LIKE`/region/entity_table 部分比對命中〕、★ **operator by 名**〔user_name LIKE→ids→`operator_id IN`、含已刪〕、operator enrich 名）。C-V-4 live policy-gate（Admin/User 對 3 端點→5003）。C-V-5 ★ **m005 migration up→down→up 可逆**（波 0 出口紀律；migrate down 還原 seed/索引、up 重建）。C-V-6 base-web typecheck（3 honest typing、無 type-lie）。C-V-7 CDP（審計中心頁 3 tab 真發 request + filter + 分頁 + op-log payload 展開 + operator 名顯示 + hasAuth super-only〔非 super 不見審計中心 menu〕）。C-V-8 零回歸（diff base-web frozen 未改、enforce_mw/require_policy/From<DbErr>/login/getUserRoutes/008-011 不變；migration 僅 seed+索引無業務表）。C-V-9 prod target image build。
> ★ 讀端 live 測**唯讀無污染**（純 SELECT、無寫、無 cleanup 需求、異於 011 casbin 寫）；惟 m005 已套用於 dev DB（seed 列 + 索引在）。

## 10. Files（當前 lineage、BUILD vs ALREADY）
**BUILD（改/新）**：
- `rust-api/server/src/model/facade/{sys_operation_log,sys_access_log,sys_login_attempt}.rs`（各加 `list` + `XxxLogFilter`）
- `rust-api/server/src/handler/system_manage.rs`（+3 端點 + 3 Query DTO + operator enrich）
- `rust-api/server/src/main.rs`（+3 路由 require_policy）
- `rust-api/migration/src/m005_audit_read.rs`（**新**、Migrator 註冊）
- `rust-api/server/tests/endpoint_coverage_lint.rs`（`[&str;31]→[&str;34]`）
- `rust-api/server/src/model/facade/sys_user.rs`（若需新增 operator 批次解析 fn〔或復用既有〕）
- base-web `src/service/api/rev3-system-manage.ts`（+3 wrapper）＋`src/typings/api/rev3-system-manage.d.ts`（+3 honest typing）＋`src/views/manage/audit/{index.vue, modules/*.vue}`（新頁 3 tab）＋`src/locales/langs/{zh-cn,en-us}.ts`＋`src/typings/app.d.ts`（`page.manage.audit.*`）

**ALREADY（不動）**：`entity/src/{sys_operation_log,sys_access_log,sys_login_attempt}.rs`／3 sink facade 寫方法／m001-m004／`AuditOperation`／`require_policy`·`enforce_mw`·`PageRes`·§5.8 normalize·`endpoint_coverage_lint`·`entity_access_lint`·`From<DbErr>`（004-011）／sys_login_attempt 索引（007）／base-web route store·transform·system-manage.ts·auth.ts·request·既有 manage 頁／login/getUserInfo/getUserRoutes 端點。

## 11. forward-compat / 下游 + plan-phase 接地清單
- **plan Phase 0 research 必 grep**：(a) 3 sink facade 真實 Model 欄/返回型（對齊 list fn 返 raw Model）；(b) §5.8 normalize helper 確切簽名 + PageRes 形（009）；(c) sys_user 批次解析既有 fn（`roles_for_users` 是否含 user_name map、或需新 `names_of_users`）；(d) m002 sys_menu/casbin INSERT 確切欄序（m005 對齊）；(e) Migrator 註冊點（m004 後接 m005）；(f) 既有索引 DDL 形（m005 CREATE INDEX 對齊）；(g) wire 3 端對齊（base-web inline 型 ↔ rust DTO ↔ tab 元件 state）。
- **新 migration ⇒ prod build**：m005 加 migration（無新 crate）；C-V 跑 prod target build（migrate stage 套 m005）。
- **CDP 不 defer**：審計中心 3 tab 真發 + filter + 分頁 + payload 展開＝必 browser 軌（curl≠modal）。
- **下游**：⚠️w login lockout 復用 sys_login_attempt 讀端 + 索引；波 3 policy-governance 用 op-log `entity_table='casbin_rule'` 列審計軌。本刀收 §3.4（access/login client_ip decode round-trip）/§3.8（operation 字串契約對齊）。
- **follow-up 預期**：★ **3-IP forensic 模型刀（D11 延後、user 拍 C）**——ALTER `sys_operation_log`/`sys_access_log`/`sys_login_attempt` 三表統一加 `client_ip`(peer)/`xff_ip`/`real_ip`〔現 access/login `client_ip`=已解析→語意併入 `real_ip`、`x_forwarded_for`→`xff_ip`、新增 peer〕；`audit_ctx` 存 peer〔`ConnectInfo` 已取得未存〕+ `resolve_client_ip` 完整化〔§3.11：multi-hop/trusted-CIDR config〕+ **Cloudflare CF-Connecting-IP** header；串 3 IP 進 `AuditEvent`/`AuditOperator`/`AccessLogEvent`/`LoginAttemptEvent` 與 3 sink 寫；既有列 backfill 策略〔peer null／解析值遷 real_ip〕。動 frozen entity（002）+005/007 audit infra、宜與 §3.11 一刀收。本刀（012）讀現 schema、IP 欄模糊查詢已備、模型升級後讀端 wire 隨之擴。／§3.12 user 角色變更 payload delta（D4 延後、未來寫端刀）／log retention（⚠️n）／審計匯出（未列、若需另開）。

## 12. Workflow 單元分解（預想、階段 2 依實際相依定；rust 全程 serial）
- **U1 rust 讀端 + migration**：m005 migration（menu/policy seed + 索引、up→down→up 驗）＋3 sink facade `list` + filter ＋handler 3 端點（operator enrich）＋main 3 路由 ＋lint `[34]`＋純測（filter/enrich）＋live（3 端點分頁/filter/policy-gate）。
- **U2 base-web 審計中心頁**：3 wrapper ＋3 honest typing ＋audit/index.vue 3 tab + 3 子表 ＋i18n ＋typecheck ＋CDP（3 tab 真發 + filter + 分頁 + payload 展開 + super-only gating）。
- US「越權」acceptance（policy-gate live + lint）散入 U1 邊界自驗；零回歸 + m005 up/down/up + prod build 收口。
- 注：m005 menu seed 後 view 須同刀（U1 seed→U2 view）避免 dangling component error（沿 010 §3.13）→ U1/U2 可同 feature 內、U2 view 落地前 dev 容器 Super 暫見 console warn（無害、U2 收）。
