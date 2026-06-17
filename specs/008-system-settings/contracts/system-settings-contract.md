# Contract: System Settings 打樋（008 落定、跨 feature 權威）

> 本刀建立的不變式，後續 policy-governed 業務端點（波2+）、Menu 刀（波2 dynamic-menu）、行為島（波3 session_mode consumption）繼承。權威＝constitution §I.1/§I.2/§I.3/§I.6/§III＋DESIGN §3.4/§5.0/§5.2/§5.3/§8.1。

## 1. require_policy 政策強制 pattern（全專案首立、§3.4）
1. **兩層分離**：受保護業務路由＝`enforce_mw`（auth：bearer 3333→is_current 7777→注入 Claims）＋`require_policy`（authz：DB-fresh roles→casbin→5003）。auth-only 路由（如 /auth/getUserInfo）只掛 `enforce_mw`。
2. **`enforce_mw` 本體不改**（守 §3.4）；policy 強制為**獨立 per-route layer**、不擴 enforce_mw。
3. **授權 subject＝DB-fresh roles**（`roles_of_user(db, claims.uid)`）、**不信 `claims.roles`**（JWT 內嵌僅 hint、§I.3 FR-008／006 contract §2.2）。
4. **deny→`AppError::PermissionDenied`（5003／HTTP403）**；後續 policy-governed 端點沿此 pattern。

## 2. endpoint_coverage_lint 守恆（波0 出口三守恆之三、⚠️x）
1. 分類 main.rs 已註冊 route：**public**（/health、/auth/login）／**auth-only**（/auth/getUserInfo）／**policy-governed**（掛 require_policy 者）。
2. **斷言方向（非 §7.1 @35 字面）**：「每條已註冊 policy-governed route 必有對應 casbin p-policy seed」＋「registered route 集 == as-built registry（逐刀漸增）」。**非反向**（m002 預 seed 未註冊路由的 policy、不要求每 seed 必有 route）。
3. 三守恆自本刀全綠：`entity_access_lint`（004）＋`endpoint_coverage_lint`（008）＋migration up→down→up（002）。

## 3. system_settings 讀/改不變式
1. **讀**：super-only、回全列 KV（flat、不分頁、§5.0 system_settings 不套用 §5.8）。
2. **改**：super-only、單鍵 update value；**值須對 `value_type` 驗**（如 enum:on,off）、不符→biz 2222（在地化）；查無 key→biz 2222、no-op（不新增鍵、archetype A 無 partial-uniq）。
3. **改＋審計原子**（§5.2、archetype A 異動審計）：每次改值連同一筆 op-log（`operation='UPDATE'`、operator/operator_ip/trace、before/after）**同 txn**——審計寫失敗→變更回滾（**非** best-effort；異動審計同成同敗、無未審計變更）。
4. **無增刪鍵路徑**（§5.0「✓無刪除路徑」；soft-delete 欄存 schema＝seam、不 exercise）。

## 4. op-log operator 歸屬（007 seam 首 live consumer 兌現）
1. update handler 經 `ctx.to_audit_operator(claims.uid)`（007 helper）取 `(AuditOperator{id, ip:Some(client_ip)}, trace_id)` 餵 `mutate_in_txn`。
2. op-log `operator_id`/`operator_ip`(真 INET round-trip)/`trace_id` 由恆 None→真值（達成 005/007 移交）。

## 5. wire／i18n 不變式（§I.3 typings 權威＋§III 軌道）
1. **wire 3 端對齊**（rust DTO camelCase ↔ ts typings ↔ component state）；envelope `Res{data,code,msg}`、business error 走 HTTP 200（5003→403 為例外）。
2. **軌道（皆既授）**：rev3-* wrapper（WRAPPER §III.1、首個 rev3-* 檔）／新 typings 檔（ADAPT §III.1）／新管理頁＋route./page.* key（MODAL-WIRING (e) §III.2）／backend.biz.systemSettings.* 錯誤 key（BASE-WEB-I18N-WIRING (ii)(iii) §III.2、⚠️y canonical `backend.<root>.<entity>.<condition>` 首套用）。
3. **不改既有 base-web 檔**（auth.ts/system-manage.ts/route.ts/既有 system-manage.d.ts 不動；只新增＋locale/Schema 加 key、fork-delta rev3-inline 紀律）。

## 6. 本刀邊界（OUT／MOOT、各歸其刀）
- **MOOT（m002/前波已 done）**：端點 policy×2＋menu policy＋sys_menu 列（m002:162-165/251、**無 m005**）／schema＋entity＋seed（m001/002）／audit_ctx+to_audit_operator（007）／enforce_role_path_method（006）／mutate_in_txn（005）／envelope 13 碼（003）。
- **OUT（遞延）**：dynamic-menu（getUserRoutes＋`.env` dynamic 切換、拍板#7）＝**波2 Menu 刀**（本刀 static 頁、menu-Casbin-visibility 延波2；**analyze D1**：波1 非 super 亦見 system-settings 選單〔前端 menu 非 Casbin 過濾、API 擋 403 非破口〕→ 波2 以 getUserRoutes＋m002:165 menu policy 收選單可見性、非 super 不顯；finishing 登 CHECKLIST 波2 follow-up）；§5.6 redis pub-sub watcher＋`session_mode` 熱快取＋`single_session_default` consumption＝**波3**（行為島 §I.7 §4.3）；多 key keyed-map（⚠️l）；§5.8 分頁/filter/空字串守門首 exercise＝波2 User；DbErr 23505→2222（本刀 PK lookup 不觸、波2 CRUD）。
- 無 migration／無 schema/entity 變更／無新 crate／enforce_mw·audit_mw 不動／base-web 既有檔不改。
