# Phase 0 Research: 008-system-settings

> 接地源＝當前 lineage（rust-api worktree `fc4b50e`）親 grep＋4 平行 research dimension（R-A 簽名/碼/layer／R-B m005-seed／R-C base-web 路由/選單／R-D wire/i18n）＋主線親驗。**NEEDS CLARIFICATION = 0**（brainstorm＋specify 已拍；frontend scope 經 plan-phase 親驗後 user 拍定 Option A）。
> ★ 本刀借 rev2 029 設計、對齊當前 lineage：research **抓到 2 個 brainstorm 假設與實況偏差**（R1 m005 MOOT、R2 static 模式）——act-on-code 校正、見下。

## R1 — ★ m005 遷移 MOOT：m002 baseline 已 seed 齊 system-settings（親 grep 校正）

**Decision**：**本刀無 migration**——casbin 端點 policy（×2）＋menu-visibility policy＋sys_menu 列**皆已在 m002（rev2 baseline squash）seed**。brainstorm D4／§4.5「立 m005 seed」**整個拔除**（MOOT）。
**Rationale（親 grep `rust-api/migration/src/m002_rev2_seeds.rs`）**：
- `m002:162` `('p','R_SUPER','/systemManage/getSystemSettings','GET','','','',true)`（端點 policy、protected）。
- `m002:163` `('p','R_SUPER','/systemManage/updateSystemSetting','POST','','','',true)`（端點 policy）。
- `m002:165` `('p','R_SUPER','manage_system-settings','menu','','','',true)`（menu-visibility policy）。
- `m002:251` sys_menu 列：`('manage_system-settings', 2, 'manage_system-settings', '/manage/system-settings', 'view.manage_system-settings', 'mdi:cog', 1, 'route.manage_system-settings', 4, 1, true)`（parent=manage、menu_type=2、route_path=/manage/system-settings、component=view.manage_system-settings、i18n=route.manage_system-settings、protected）。
- `m002:352-368` down() 反向齊備（精確七元組 DELETE＋route_name IN）。
- brainstorm D4 只 grep 了 `m004_demo_menu_seeds.rs`（demo 選單、確認無 system-settings——`grep -c system m004`＝0）、**漏看 m002**（rev2 終態基線）。
**影響**：facade/handler/`require_policy` 直接對 m002 既存 policy 強制；`endpoint_coverage_lint` 的 system-settings 端點 policy 已存（印證 R6 斷言方向）；spec FR-008 的「立 m005」改為「policy 已就位、只需 require_policy 接線＋lint 驗」。**剩 rust-api 工作＝facade＋handler＋require_policy＋endpoint_coverage_lint＋測**（零 migration）。
**Alternatives**：建 m005 重 seed（否決——重複、且 m002 已 idempotent `ON CONFLICT DO NOTHING`、down() 已齊）。

## R2 — ★ base-web static 路由模式＋getUserRoutes=波2 → frontend Option A（親驗校正）

**Decision**：本刀前端＝**static 頁**（`views/manage/system-settings/index.vue` 經 elegant-router 編譯期自動生 route）＋wire＋i18n；頁可達、API 端 `require_policy` super-only 強制（403 首証）；**Casbin menu-visibility（getUserRoutes）＋`.env` dynamic 切換延波 2 Menu 刀**（user 拍 Option A、2026-06-18）。**波1 不加前端 role-meta gating**（避 throwaway；頁對已認證者可達、API 擋 super-only；選單-Casbin-可見性＝波2）。
**Rationale（親驗）**：
- `base-web/.env:17` `VITE_AUTH_ROUTE_MODE=static`（**非 dynamic**；brainstorm §2.4 假設 dynamic 有誤）。
- rust-api **無** `getUserRoutes`／`/route` 端點（`grep -rn getUserRoutes rust-api/server/src`＝空）→ dynamic-menu 後端**未實作**＝波2 Menu 刀（roadmap CHECKLIST §2 波2「Menu 刀 DB-driven＋runtime 讀」）。
- m002 seed 的 `manage_system-settings` 選單列為 **dynamic 模式**設計（`component=view.manage_system-settings` 由 getUserRoutes 餵）→ 波1 static 模式不消費、待波2 getUserRoutes 啟用。
- 拍板 #7（dynamic route mode）為**最終模式**；啟用時點＝波2 Menu 刀（getUserRoutes 落地）；波1 維持 static **非拍板 #7 violation**（pre-migration、排程性）。
- elegant-router 編譯期自 `views/manage/system-settings/index.vue` 生 route name＝`manage_system-settings`（對齊 m002:251 route_name、hyphen 字尾；R-C 預測 underscore 有誤、實況 hyphen）。
**影響**：`.vue`／wire／i18n 在波2 dynamic 沿用；波2 切 dynamic 時移除這條 static route 註冊（小 throwaway）；§I.2 menu-Casbin-enforce 機制延波2（波1 API 層 Casbin 強制已在）；spec US/FR-011/SC-005 前端面由 static 頁滿足。
**Alternatives**：Option C 前端延波2（否決——削弱 ③=B「在輕 entity 排練 wire+frontend」本意）；Option B 波1 拉 dynamic-menu 全套（否決——scope 膨脹、getUserRoutes 屬 Menu 刀）。

## R3 — require_policy per-route layer（首個 policy-governed 端點、DB-fresh）

**Decision**：新增 `require_policy(path, method)` per-route layer（`enforce_mw` 一行不動、守契約 §3.4）；取 `State<AppState>`＋`Extension<Claims>`（`enforce_mw` 已注入 Claims）→ **DB-fresh** `roles_of_user(&state.db, claims.uid).await?`（**不信 `claims.roles`**）→ `enforce_role_path_method(&*enforcer.read().await, &roles, path, method)` → false → `AppError::PermissionDenied`（5003／HTTP403）。
**Rationale（R-A 親 grep）**：`enforce_mw(State, Request, Next)->Result<Response,AppError>`（enforce.rs:128）用 `middleware::from_fn_with_state(state, fn)` 掛（main.rs:92-95）→ `require_policy` 同款 `from_fn_with_state` 可行；`enforce_role_path_method(enforcer,roles,path,method)->bool`（enforce.rs:90、C-V-1 已測）；`Claims{uid:i64, roles:Vec<String> hint-only, sid,...}`（jwt.rs:12-23、roles 僅 hint）；`roles_of_user<C:ConnectionTrait>(conn,uid)->Result<Vec<String>,DbErr>`（sys_user_role.rs:11、可傳 &DatabaseConnection）；`AppError::PermissionDenied`＝5003、http()→403（error.rs:50/67/91）。守 §I.3 FR-008／006 contract §2.2「claims.roles 僅 hint、enforce 一律 DB-fresh」。
**Alternatives**：擴 enforce_mw 收 policy spec（否決——改本體、違 §3.4）／handler 內自呼（否決——分散、lint 難立）。

## R4 — facade／handler 簽名與信封（act-on-code、零臆測）

**Decision／親驗（R-A file:line）**：
- `mutate_in_txn<C:TransactionTrait,R,F,Fut>(conn,f) -> Result<R,DbErr>`（audit.rs:65-78）；閉包回 `(txn, R, Option<AuditEvent>)`；`AuditOperation` 有 `Update` variant（audit.rs:18）；`AuditOperator{id:i64, ip:Option<IpNetwork>}`；`AuditSerialize` trait。
- `RequestContext::to_audit_operator(&self, uid:i64) -> (AuditOperator, Option<String>)`（audit_ctx.rs:47，純函式、回 `(AuditOperator{id:uid, ip:Some(IpNetwork::from(client_ip))}, trace_id)`）——本刀 update handler 即其首個 live consumer（R9）。
- `sys_operation_log::write_in_txn(&DatabaseTransaction, AuditEvent) -> Result<(),DbErr>`（append-only、mutate_in_txn 內呼）。
- `Res<T>{data,code,msg}`／`Res::ok(data)`（envelope.rs:20-49、欄序 data→code→msg、IntoResponse 預設 200）；handler 回型慣例＝`Result<Json<crate::envelope::Res<serde_json::Value>>, AppError>`（auth.rs 同款）。
- `AppError::Biz(Cow<str>)`＝2222 帶 i18n key（error.rs:41）；構造 `AppError::Biz(Cow::Borrowed("biz.systemSettings.<condition>"))`。
- `entity::system_settings::ActiveModel`：`setting_key`(String,PK,auto_inc=false)／`setting_value`／`value_type`／`description?`／6 審計欄（system_settings.rs:8-20）；Set 寫法 `Set(v.to_owned())`／`Set(Some(uid))`／`Set(None)`。
- 候選檔 `handler/system_settings.rs`／`facade/system_settings.rs` **確認不存在**（net-new）；`handler/mod.rs`／`facade/mod.rs` 待加 `pub mod system_settings;`。
**facade 設計**：`find_all(conn)->Result<Vec<Model>,DbErr>`（讀全列）；`update_by_key(conn,key,new_value,operator:AuditOperator,trace_id)->Result<Option<Model>,DbErr>`（mutate_in_txn：查無→Ok(None)；命中→Set setting_value＋updated_at/updated_by 成對＋同 txn op-log Update、before/after audit_json）；`*_active_model` 純測 seam。

## R5 — value_type 驗證（enum:on,off、handler 改前驗）

**Decision**：handler 於 update 前驗 `setting_value` 對該列 `value_type`；`value_type` 形如 `enum:on,off`（冒號後逗號分隔合法值集）→ 解析、`new_value ∈ 集`？否→`AppError::Biz(Cow::Borrowed("biz.systemSettings.invalidValue"))`（2222）。查無 key→`AppError::Biz(Cow::Borrowed("biz.systemSettings.notFound"))`（2222）。
**Rationale**：§5.4 envelope＋⚠️y per-entity key 規約首套用；驗在 handler（讀 value_type→驗）非 facade（facade 純寫）；目前只 enum 型（單一 seeded key），數值/字串/json 型隨需要擴充（純測涵蓋 enum 合法/非法）。
**Alternatives**：DB constraint 驗（否決——value_type 是 row 資料、非 schema 約束；handler 驗較彈性）。

## R6 — endpoint_coverage_lint 斷言形（as-built 漸增、非 §7.1 @35）

**Decision**：新 `server/tests/endpoint_coverage_lint.rs`（鏡像既有 `entity_access_lint` 只讀掃描形）；分類 `main.rs` 已註冊 route 為 **public**（/health、/auth/login）／**auth-only**（/auth/getUserInfo）／**policy-governed**（/systemManage/getSystemSettings、/systemManage/updateSystemSetting）；斷言＝**「每條已註冊 policy-governed route 必有對應 m00x casbin p-policy seed」＋「已註冊 route 集 == 預期 registry（逐刀漸增）」**。**非** DESIGN §7.1 `EXPECTED_ROUTE_COUNT=35` 字面。
**Rationale（R-A/R-B 親驗）**：m002 已 seed ~39 條端點 p-policy（含 getUserList/deleteUser… 等**尚未註冊**的路由、`m002:97-150`）→ 若斷言「seed==router==35」則 day-1 紅（只 2 條已註冊）。故方向＝「registered ⊆ seeded」（policy-governed route 必有 seed）＋「registered == as-built registry」（防漏掛/誤加）；**非反向**（不要求每 seed 必有 route、因 m002 預 seed 未來路由）。⚠️x 波0 豁免、本刀立。
**Alternatives**：照搬 §7.1 @35（否決——day-1 紅）；不立（否決——⚠️x 移波1 立）。**plan 期定確切斷言碼**（避免 fallback 4040 誤判；scan main.rs route 表）。

## R7 — base-web wire 3 端＋i18n（rev3-* WRAPPER／新 typings ADAPT／I18N-WIRING＋MODAL-WIRING(e) key）

**Decision／親驗（R-D）＋憲法軌道對齊**：
- **WRAPPER 軌道（§III.1）**：`service/api/rev3-system-settings.ts`（**新檔、rev3- 前綴**＝憲法 WRAPPER 紀律；R-D 觀察「base-web 目前無 rev3-* 檔」屬實、本刀為 rev3 **首個 rev3-* wrapper**、不改既有 system-manage.ts）：`fetchGetSystemSettings()`＋`fetchUpdateSystemSetting(key,value)`，鏡像 system-manage.ts 形（`request<T>(...)`）。
- **ADAPT 軌道（§III.1）**：`typings/api/rev3-system-settings.d.ts`（**新檔**＝ADAPT「新檔為主、不改既有」；augment `Api.SystemManage` 或新 namespace）：`SystemSetting{settingKey,settingValue,valueType,description?}`＋`UpdateSystemSettingReq{settingKey,settingValue}`（camelCase）。**不**擴 system-manage.d.ts（那是改既有檔、違 ADAPT）。
- **BASE-WEB-I18N-WIRING 軌道 (ii)(iii)（§III.2）**：`locales/langs/{zh-cn,en-us}.ts` 加 `backend.biz.systemSettings.{invalidValue,notFound}`（現 `backend.biz` 僅 `{error}`、app.d.ts:325）＋`typings/app.d.ts` `App.I18n.Schema` 的 `backend.biz` 擴 `systemSettings` 型（先 Schema 後 locale、否則 `$t` typed-key 失敗）。攔截器**無需改**（`service/request` 既有 `translateBackendMsg` 自動 `$t('backend.'+msg)`、R-D 親驗 request/index.ts）。
- **MODAL-WIRING (e) 軌道（§III.2）**：新頁 `views/manage/system-settings/index.vue`（＋可選 modules/）＋其 i18n key `route.manage_system-settings`（選單標題、對齊 m002:251）＋`page.manage.systemSettings.*`（頁內標籤）——(e) 明列「含 route.manage_<page>＋page.manage.<page>.* i18n key」。
**Rationale**：wire 3 端對齊（rust DTO camelCase ↔ ts SystemSetting ↔ component state）＝§I.3 typings 權威；i18n 兩家族＝backend.biz.*（錯誤訊息、I18N-WIRING (ii)）＋route./page.*（頁面標籤、MODAL-WIRING (e)）。
**Alternatives**：直名 `system-settings.ts`（R-D 建議、否決——違憲法 WRAPPER 軌道 rev3- 紀律）；擴 system-manage.d.ts（R-D 建議、否決——違 ADAPT「不改既有」）。

## R8 — DbErr 23505→2222 本刀不需（PK lookup、非 unique-violation）

**Decision**：本刀**不**落 `DbErr::sql_err()`→23505→2222 映射；查無 key→`Biz(2222,notFound)`（由 `update_by_key` 回 `Ok(None)`、handler 映）、非 DB unique 衝突。
**Rationale**：system_settings PK=`setting_key`、改既存 key＝UPDATE（PK lookup 命中→改值）、**不觸 23505**（無新增 key 路徑、archetype A 無 partial-uniq）。23505→2222（`From<DbErr>` or handler 分支）留**波2 首個有 unique 約束的 CRUD 寫端**（User/Role）帶入（§3.6/§3.8 移交 follow-up 同源）。
**Alternatives**：本刀預先落 23505 映射（否決——本刀不觸、過早抽象）。

## R9 — op-log threading 首個 live consumer（007 seam 兌現）

**Decision**：`update_setting` handler 經 `ctx.to_audit_operator(claims.uid)`（007 audit_ctx seam helper）取 `(AuditOperator{id,ip:Some(client_ip)}, trace_id)` 餵 `update_by_key`→`mutate_in_txn`→op-log；op-log `operator_id`/`operator_ip`(真 INET)/`trace_id` 由恆 None→真值。
**Rationale（R-A 親驗）**：007 已上線 `audit_ctx` 全域中介層（每請求建 `RequestContext` 塞 extensions）＋ `to_audit_operator` helper（audit_ctx.rs:47）；update handler 走 `enforce_mw`（已認證、Claims.uid 可取）＋可 `Extension<RequestContext>`；達成 005/007 移交的「op-log operator_ip 真實 INET round-trip live 驗」。
**Alternatives**：手構 AuditOperator（否決——007 已有 helper、復用）。

## 三-grep 紀律落地
- **facade/entity 返回型**：`find_all`→`Vec<Model>`、`update_by_key`→`Option<Model>`（R4 親 grep entity 10 欄＋mutate_in_txn 簽名）。
- **wire 3-端**：rust handler DTO（camelCase settingKey/settingValue/valueType/description）↔ ts `SystemSetting`（新 typings 檔）↔ component state（R7 親 grep base-web service/typings/i18n 慣例）；**首批業務 wire**、§I.3 兩端俱在。
- **命名對照**：route_name＝`manage_system-settings`（hyphen、m002:251 親驗、非 R-C 預測的 underscore）；端點 `/systemManage/getSystemSettings`·`/systemManage/updateSystemSetting`（m002:162-163 親驗）；`Biz(Cow)`/`PermissionDenied`/`roles_of_user`/`to_audit_operator` 皆親 grep actual code。
- **CDP smoke**：本刀有 modal/頁（system-settings 管理頁）→ C-V-CDP 經 front-nginx 真 `/api`（super toggle→存→toast＋DB／非 super→403 modal）；**不 defer**。
- **list filter 空字串守門**：N/A——getSystemSettings 回 flat 全列、無 filter/分頁（§5.0 system_settings 不套用 §5.8、首 exercise PageRes/空字串守門＝波2 User）。
