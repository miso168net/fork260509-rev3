# 008-system-settings — Phase 0 Brainstorm（spec-design）

> **波 1 第一刀**（波 0 地基 001~007 七刀全完成 2026-06-18 → 換波 1）。③=B 拍板（DECISIONS §1：`system_settings` 打樣為第一刀、推翻 User 直刀傾向、2026-06-16）。
> **打樣本意**：以最輕、低風險的 KV entity 便宜跑完 DESIGN §8.1 **9-step 全管線**（migration→entity→facade→handler→router+enforce→casbin seed→wire→frontend→test→CDP），骨架先打通、再上波 2 最重的 User 刀。
> **本檔來歷**：借**前代 rev2 029**（`system_settings` 讀全列＋單鍵改＋NSwitch toggle 頁）為設計參照、對齊**當前 lineage**（rust-api worktree `fc4b50e`）；只借設計、**code 全新寫**（§I.5／⚠️g 受控參照：讀允許、拷貝禁止）。本檔為 brainstorm 定稿的 spec-design，作 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §5.6（`system_settings` 熱 KV／pub-sub／`settings_watcher`——**本刀只做 CRUD 骨架、watcher/pub-sub/session_mode 熱路徑延波 3**、見 §3-D1／§6）＋§8.1（9-step 縱切工序）＋§5.0（entity×aspect 矩陣 `system_settings` 列）＋§5.3（RBAC Casbin enforce、super-only）＋§3.4（`enforce_mw` 本體不改、policy 另接）＋§3.3（單一 operator gate）＋§5.2／§5.7（mutation 同 txn op-log＋6 審計欄成對）＋§I.5（rust 全新寫；唯二拷貝例外＝`sea-orm-adapter`＋`xdb`，本刀皆不涉）＋§I.6（archetype A 業務全 6 審計欄、facade 唯一管道）＋§7.4（`/api` strip 前綴）。
> **相關拍板（DECISIONS §1）**：③＝B（第一刀位）／⚠️a（perf 保守預設 list p95<300ms·寫<500ms）／⚠️o（application-RI hybrid：intra 下沉 facade／跨 facade·restore 留 handler）／⚠️l（settings 多 key keyed-map＝**設計變更、延後**、本刀單鍵足）／⚠️x（`endpoint_coverage_lint` 波 0 出口豁免、**移波 1 首個 gated endpoint 立**＝本刀）／⚠️y（biz-msg i18n：前端譯·msg＝key、per-entity `2222` key 規約 003 已落、本刀首套用）。
> **衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（引用一律用穩定 §錨、不用揮發行號；本檔不引用本機 memory）。

---

## 1. 目標一句話

用最輕的 KV entity（`system_settings`）便宜跑完 §8.1 **9-step 全管線**、逐項 exercise §5.0 矩陣對 `system_settings` 適用的各面（§5.2 審計／§5.3 RBAC／§5.4 envelope／§5.5 single-session gate／§5.7 審計欄），並達成三個「全專案首次」：①**首個 policy-governed 端點**（super-only、`require_policy` per-route layer、**5003→403 live 首証**、`enforce_mw` 本體不改）②**首個 007 `audit_ctx` op-log threading 的 live consumer**（update handler 把 `RequestContext` 的 operator/IP/trace 餵 `mutate_in_txn`→op-log 由恆 None→真值）③**立 `endpoint_coverage_lint`**（⚠️x 波 0 豁免項補上、分類 public／auth-only／policy-governed 三類 route）。骨架打通供波 2 重刀 User 借鑑。**§5.6 watcher/pub-sub/session_mode 熱路徑延波 3**。

## 2. Context（探索蒐集、act-on-code 親驗）

### 2.1 前代 rev2 029 參照（借設計、§I.5／⚠️g、不照拷）
- rev2 029 `system_settings`：端點 `GET /systemManage/getSystemSettings`（讀全列 KV）＋`POST /systemManage/updateSystemSetting`（單鍵 key+value 改）；facade `find` ＋ `update_by_key`（同 txn op-log）；前端 `manage/system-settings/index.vue`（`single_session_default` enum 用 NSwitch toggle）；super-only 端點＋menu 可見性 policy；watcher 訂 `settings:invalidate` 重讀 `single_session_default`。
- 借：兩端點形／facade 形／前端 toggle 頁形／super-only。**code 全新寫**（rev2 為設計參照、讀允許拷貝禁止）。

### 2.2 ★ 當前 lineage 已落地（不重做）
- **entity `system_settings`（004 建、10 欄）已存在**：PK=`setting_key`（varchar、`auto_increment=false`）／`setting_value`／`value_type`／`description?`／6 審計欄（`created_at`／`created_by?`／`updated_at?`／`updated_by?`／`deleted_at?`／`deleted_by?`）＝archetype A。
- **schema＋seed 已落（m001 建表、m002 seed 1 列）**：`('single_session_default','off','enum:on,off','全站單一-session 預設')`。本刀**不動 schema、不改 entity**。
- **`audit_ctx` 全域中介層已上線（007）**：每請求建 `RequestContext{operator_id,client_ip,x_forwarded_for,region,trace_id}` 塞 extensions、handler 可 `Extension<RequestContext>` 取——**本刀 update handler 正是其首個 live consumer**。
- **`enforce_role_path_method(enforcer,roles,path,method)->bool` seam 已建（006、C-V-1 測過）**＋`enforce_mw`（bearer→is_current→注入 Claims、auth-only）——但 policy 決策**未進任何 live 路徑**（006 R-C 校正）。
- **`mutate_in_txn`（005）＋`From<DbErr> for AppError`→Internal（006）已在**；`DbErr::sql_err()`→23505→`2222` 映射**仍待**（本刀寫端可帶入，見 §3-D7）。

### 2.3 rust-api 現況（`fc4b50e` 親驗）
- `main.rs`：`audit_mw` 已掛最外層、`into_make_service_with_connect_info`、`/auth/*`＋`/health`＋fallback；無業務端點。
- `auth/enforce.rs`：`enforce_mw` auth-only、`enforce_role_path_method`／`buttons_for_roles` seam；**無 policy-enforcing layer**（待本刀建 `require_policy`）。
- `error.rs`：`AppError` 9 變體凍結 13 碼（003）；`5003` 變體（policy deny→HTTP 403）已在矩陣。
- `model/facade/`：`sys_user`／`sys_token`／`sys_operation_log`（op-log write_in_txn）／`sys_access_log`／`sys_login_attempt`／`sys_role`／`sys_menu`／`sys_user_role`；**無 `system_settings` facade**（待建）。
- workspace members＝`server/migration/sea-orm-adapter/entity/xdb`（本刀**不新增 crate**）。
- `server/tests/`：`entity_access_lint`（守恆綠）；**無 `endpoint_coverage_lint`**（待本刀立、⚠️x）。

### 2.4 base-web 現況（§I.1 權威、net-new、親驗）
- **無** system-settings 頁／service／typings：`views/manage/` 只有 `menu/role/user/user-detail/`；`service/api/system-manage.ts` 7 wrapper 無 settings；`typings/api/system-manage.d.ts` 無 `SystemSetting` 型。
- ⇒ wire 鏈**全 net-new**（借 rev2 029 設計、無 code 搬）：新 `manage/system-settings` 頁（MODAL-WIRING (e) 新管理頁）＋`service/api/rev3-system-settings.ts` wrapper（BASE-WEB-WRAPPER 軌道）＋`typings/api/*.d.ts` `SystemSetting` 型（BASE-WEB-ADAPT 軌道）。
- **⚠️ plan-phase 須接地**：base-web 路由模式（static route vs DB-driven menu）＋新頁如何註冊進選單／路由＋是否需 sys_menu seed 列——`/speckit-plan` research 須 grep base-web router mode（`build/plugins/router.ts`、route mode 設定）＋ m004 demo 選單是否已含 system-settings slot。本檔不臆測（act-on-code）。

### 2.5 §5.0 矩陣對 `system_settings` 的面（DESIGN §5.0 親查）
`| system_settings | soft-del ✓(無刪除路徑) | op-log ✓ | enforce ✓(Super) | search — | xdb — | archetype A(無 partial-uniq) |`
- **Exercise**：§5.2 審計同 txn／§5.3 RBAC super-only／§5.4 envelope／§5.5 single-session gate（受保護讀掛 is_current、`enforce_mw` 已有）／§5.7 6 審計欄成對寫。
- **N/A 或延後**：§5.1 soft-delete（schema 有欄、**無刪除路徑**＝seam only）／§5.6 熱 KV/pub-sub（**延波 3**、D1）／§5.8 search/filter/分頁（system_settings 不套用、首 exercise 派波 2 User、D3）／§5.9 region·xdb（不套用）／§5.10 AES 磁碟層（全庫一致、非本刀）。

### 2.6 消費者
- **直接**：admin 後台讀/改全站設定（KV）；波 1 打樣骨架達成（§8.1 9-step 全鏈）。
- **下游**：波 3 Auth/Token/Session 合刀（接 `session_mode` 熱快取＋`settings_watcher`＋redis pub-sub＋`single_session_default` consumption）／波 2 User 刀（借本刀 §8.1 全鏈骨架＋首 exercise PageRes/§5.8）。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | §5.6 watcher/pub-sub 範圍 | **本刀只做 CRUD 全鏈骨架；redis pub-sub `settings_watcher`＋`AppState.session_mode` 熱快取＋consumption 延波 3**（user 拍） | 打樣本意＝便宜練管線、非讓 `session_mode` 上線；redis 不在 AppState（006「single-session DB-only、pub/sub＝波 3」）；`settings:invalidate` watcher 與 `casbin:policy:invalidate` watcher 是波 3 行為島姊妹件；`single_session_default` 的真正 consumer（single-session 行為機）本就在波 3。`single_session_default` 列本刀可讀寫但 runtime 尚未消費＝**seam**、波 3 接。否決「本刀含完整 §5.6」（提前拉波 3 redis/watcher 進打樣、違便宜本意） |
| D2 | policy 強制接法 | **新增 per-route `require_policy(path,method)` layer、疊 `enforce_mw` 之後；`enforce_mw` 本體不動**（user 拍） | 守契約 §3.4（不改 `enforce_mw` 本體）；復用 006 `enforce_role_path_method` seam（C-V-1 已測）；設乾淨全專案 pattern（auth-only＝`enforce_mw`；policy-governed＝`enforce_mw`＋`require_policy`）；**5003→403 首証 live**。否決「擴 enforce_mw 收 policy spec」（改本體、語意混）／「handler 內自呼」（分散、無中央保證、lint 難立） |
| D3 | `get_system_settings` 回形 | **flat 陣列、不用 PageRes**（工程決定、user 核可） | §5.0 明定 system_settings 不套用 §5.8 分頁/filter；KV 列數極少。003-envelope 移交的 follow-up 原假設「system_settings 首 exercise PageRes」**改派波 2 User**（真有 list 的 entity）——本檔校正之 |
| D4 | 是否含 migration | **含 seed-only 遷移（暫名 m005）、非 schema**（工程決定、user 核可） | system_settings 表 m001 已建→**無 schema 遷移**；但 §8.1 step 6 要 casbin p-policy seed（2 端點 R_SUPER 逐條無 wildcard）＋新頁 menu 可見性 policy。**不是 007 那種「零 migration」**＝seed 性質。**m005 確切列**（已 grep m004＝66 demo 選單＋66 R_SUPER menu policy、**無** system-settings slot、**無** 端點 HTTP-method p-policy）：須補（a）2 端點 R_SUPER p-policy（b）新 sys_menu 列＋其 menu policy（無既有 slot 可復用）；plan 細化列序/欄 |
| D5 | 前端形 | **最小 generic KV 管理頁**（讀全列、render by `value_type`；現 1 列 `single_session_default`＝NSwitch on/off、存→update）（工程決定、user 核可） | 對齊 rev2 029 形＋YAGNI（多 key ⚠️l 延後）；generic-by-type 比硬編單 toggle 略前向相容、成本相當（現只 1 列） |
| D6 | op-log threading | **本刀 update handler＝007 threading 首個 live consumer**（工程決定、user 核可） | 007 `audit_ctx` 已上線、update 走 enforce_mw（已認證、operator_id 必 Some）→ handler 經 `ctx.to_audit_operator(claims.uid)`〔007 helper〕餵 `mutate_in_txn`→op-log `operator_id`/`operator_ip`/`trace_id` 由恆 None→真值（達成 005/007 移交的真實 INET round-trip live 驗） |
| D7 | value 驗證＋碼 | **handler 驗 `setting_value` 對 `value_type`（如 `enum:on,off`）；違→biz `2222`（`biz.systemSettings.*` i18n key、⚠️y 首套用）；DB unique/race→`sql_err()` 23505→`2222`** | §5.4 envelope＋⚠️y per-entity key 規約首套用；「DbErr::sql_err()→23505→2222 由首個 CRUD 寫端帶入」（003/005 移交 follow-up 同源）＝本刀 |
| D8 | enforce 涵蓋 | **讀＋寫端皆 super-only**（per §5.0「enforce ✓(Super)」＋rev2 029） | 設定敏感、讀亦限 super；兩端點皆掛 `require_policy` |
| D9 | soft-delete | **不開刪除路徑**（per §5.0「✓無刪除路徑」） | KV 鍵固定/seeded、admin 改值不刪鍵；soft-delete 欄存 schema＝seam，本刀無 delete 端點、不 exercise soft_delete 操作 |

## 4. 元件設計（act-on-code、當前 lineage seam 名）

### 4.1 `server/src/model/facade/system_settings.rs` 新（archetype A、entity:: 合法）
- `find_all(conn) -> Result<Vec<Model>, DbErr>`：讀全列（無刪除路徑、含所有 row）。
- `update_by_key(conn, key, new_value, operator: AuditOperator, trace_id) -> Result<Option<Model>, DbErr>`：經 `mutate_in_txn`——查 key（查無→`Ok(None)` no-op）／命中→改 `setting_value`＋`updated_at`/`updated_by` 成對（§5.7）／同 txn 落 op-log（`AuditOperation::Update`、before/after json、operator/operator_ip/trace、§5.2）。
- `*_active_model` seam 純測（欄映射、updated_at/by Set）；`facade/mod.rs` 註冊。**lint**：entity:: 僅此 facade 合法。

### 4.2 `server/src/handler/system_settings.rs` 新
- `get_system_settings(State, Extension<Claims>) -> Res<Vec<SystemSettingItem>>`：`find_all`→map DTO（camelCase `settingKey/settingValue/valueType/description`）→ flat 陣列（D3）。
- `update_setting(State, Extension<RequestContext>, Extension<Claims>, Json<UpdateReq>) -> Res<...>`：驗 `value_type`（D7、違→`2222`）→ 經 007 seam helper `ctx.to_audit_operator(claims.uid)` 取 `(AuditOperator{id,ip:Some(client_ip)}, trace_id)`（D6、復用既有 helper、不手構）→ `update_by_key`（no-op→`2222`/查無）→ envelope。
- DTO 零 path-root `entity::`（走 facade）；`UpdateReq{ settingKey, settingValue }`。

### 4.3 `server/src/auth/enforce.rs`（改：加 `require_policy` layer、`enforce_mw` 不動）
- `require_policy(path, method)`→ 回 middleware（取 `State<AppState>`＋`Extension<Claims>`）：**DB-fresh roles**——`facade::sys_user_role::roles_of_user(&state.db, claims.uid).await?`（**不信 `claims.roles`**：JWT 內嵌 roles 僅 hint、守 006 DB-fresh 授權不變式／DESIGN §3.4「subject＝DB-fresh role code 非 JWT claims」）→ `enforce_role_path_method(&*state.enforcer.read().await, &roles, path, method)` → false→`AppError::PermissionDenied`(5003／HTTP 403)。
- **`enforce_mw` 一行不動**；受保護業務路由＝`enforce_mw`（注入 Claims）＋ `require_policy`（DB-fresh 授權）兩層（per-route `route_layer`）。
- **perf**：per-request 多一次 `roles_of_user` join（在 ⚠️a p95<300ms 預算內；getUserInfo 已做同 join＝proven-affordable）。

### 4.4 `server/src/main.rs`（改：註冊 2 路由＋分層）
- `/systemManage/getSystemSettings`(GET)＋`/systemManage/updateSystemSetting`(POST)，各掛 `enforce_mw`→`require_policy(...)`；`audit_mw` 已最外層（007、access-log 自動覆蓋這兩端點）。`mod handler::system_settings;`。

### 4.5 seed migration（暫名 `m005_*`、seed-only、D4）
- casbin p-policy 逐條（無 wildcard）：`(R_SUPER, /systemManage/getSystemSettings, GET)`＋`(R_SUPER, /systemManage/updateSystemSetting, POST)`。
- 新頁 menu 可見性：新 sys_menu 列（system-settings 管理頁）＋對應 menu policy（m004 無既有 slot〔已 grep〕、見 D4）。
- 鏡像 002 migration 紀律（`mNNN_<name>`、⚠️k）。

### 4.6 `server/tests/endpoint_coverage_lint.rs` 新（⚠️x 波 1 立）
- 鎖 `main.rs` router 註冊 == 預期 route registry，分類 **public**（/health、/auth/login）／**auth-only**（/auth/getUserInfo）／**policy-governed**（system_settings ×2）三類；policy-governed route 必對應 casbin p-policy seed（防漏掛 `require_policy`／漏 seed）。
- **★ 斷言方向（非 §7.1 @35 字面）**：DESIGN §7.1 `EXPECTED_ROUTE_COUNT=35` 是 **rev2-full 最終目標、非波 1 斷言**——波 1 只註冊 2 條 gated route，而 m002 已**預 seed ~35 條端點 policy**（含尚未註冊的 getUserList/deleteUser…）。故波 1 lint 斷言＝**「as-built 已註冊 router == registry（逐刀漸增）」＋「每條已註冊 policy-governed route 必有對應 seed」**（**非**反向「每條 seed 必有 route」、因 m002 預 seed 未註冊路由）。**plan 定確切斷言碼形**（對齊 §8.4 三守恆、不照搬 §7.1 @35）。

### 4.7 wire（base-web、net-new）
- `service/api/rev3-system-settings.ts`：`fetchGetSystemSettings()`＋`fetchUpdateSystemSetting(key,value)`（BASE-WEB-WRAPPER 軌道、新檔不改既有 system-manage.ts）。
- `typings/api/*.d.ts`：`SystemSetting` 型（BASE-WEB-ADAPT 軌道、新增）。
- wire 3 端對齊（rust handler DTO ↔ ts inline type ↔ component state）；i18n key `biz.systemSettings.*`（⚠️y）。

### 4.8 frontend（base-web `views/manage/system-settings/`、MODAL-WIRING (e)）
- 新頁：載 `fetchGetSystemSettings`→ 表格 render KV（by `value_type`：`enum:on,off`→NSwitch）；改值→`fetchUpdateSystemSetting`→ envelope toast（成功/2222 經 `$t`）。**plan 須接地**路由/選單註冊（§2.4）。

## 5. wire / 碼 / INET
- **新 wire／業務端點 ×2**（首批業務 wire、§I.1：base-web 端點兩端俱在、§7.1 對齊 typings）。
- 碼：value 驗證/no-op→biz `2222`，wire `msg`＝`biz.systemSettings.<condition>`、locale 條目落 `backend.biz.systemSettings.<condition>`（⚠️y canonical 形「`backend.<root>.<entity>.<condition>`、wire 去前綴」＋⚠️aa BASE-WEB-I18N-WIRING ★ track；camelCase 守文法 conformance；首套用）；policy deny→`5003`/403（首 live）；成功→envelope `0000`。
- **INET**：op-log `operator_ip` 本刀首寫**真值**（007 threading 首 live consumer；達成 005/007 移交的「op-log operator_ip 真實 INET round-trip live 驗」）。

## 6. 範圍邊界

**IN**：facade `system_settings`（find_all＋update_by_key 同 txn op-log）／handler 2 端點（get＋update、value_type 驗）／`require_policy` layer＋`enforce_mw` 不動／main 2 路由分層／seed migration（端點 policy＋新頁 menu）／`endpoint_coverage_lint` 立／base-web wire（service wrapper＋typings）＋frontend 管理頁／純測＋live（update→op-log INET round-trip）＋CDP 全鏈＋5003 live／i18n `biz.systemSettings.*`。

**OUT（遞延）**：§5.6 redis pub-sub `settings_watcher`＋`AppState.session_mode` 熱快取＋`single_session_default` consumption（**波 3** Auth/Token/Session 合刀、D1）／多 key keyed-map（⚠️l 設計變更）／soft-delete 操作（無刪除路徑、seam only、D9）／§5.8 分頁·filter 首 exercise（波 2 User、D3）。

**MOOT（當前 lineage already-done、不重做）**：entity Model 建立（004）／schema＋seed（m001/m002）／`audit_ctx` RequestContext（007）／`enforce_role_path_method` seam（006）／`mutate_in_txn`＋`From<DbErr>`（005/006）。

## 7. enforce/policy pattern 留痕（`/speckit-plan` Constitution Check 對齊用）
- 本刀建 `require_policy` per-route layer＝全專案 policy 強制 pattern 之首；守契約 §3.4（`enforce_mw` 本體不改、**授權 subject＝DB-fresh roles 非 claims.roles**）。
- `endpoint_coverage_lint` 立＝補波 0 出口豁免項（⚠️x）；三守恆自此全綠（entity_access_lint＋endpoint_coverage_lint＋migration up→down→up）。
- 無 constitution amendment（§3.4/§5.3 既有授權；§III 軌道 RUSTAPI-SOURCE-ISOLATION／BASE-WEB-WRAPPER／BASE-WEB-ADAPT／MODAL-WIRING(e)／**BASE-WEB-I18N-WIRING ★（⚠️aa：加 `biz.systemSettings.*` 進 locales backend 命名空間＝scope (ii)）** 皆既授）。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）
- **FR-001** super 可讀全站設定全列（KV）。**FR-002** super 可改單一設定（key+value）、改值同 txn 落 op-log（operator/operator_ip/trace）。**FR-003** 讀＋寫端皆 **super-only**：非 super（含已認證非 super）→ `5003`/403、不洩值。
- **FR-004** `setting_value` 須對 `value_type` 驗（如 `enum:on,off`）、違→biz `2222`（i18n key）。**FR-005** 改不存在的 key → 明確錯（`2222`/查無）、不靜默。**FR-006** 端點走既有 envelope（`Res<T>`、碼/serde 不破 003 契約）。
- **FR-007** policy 強制經 `require_policy` per-route layer、`enforce_mw` 本體不改；**授權 subject＝DB-fresh roles（`roles_of_user`、不信 claims.roles 內嵌 hint、守 006 DB-fresh 授權不變式）**。**FR-008** `endpoint_coverage_lint` 鎖 router==registry==policy seed、分類三類 route。
- **FR-009** 寫端 operator/operator_ip/trace 由 `audit_ctx` RequestContext 取（007 seam 首 live consumer）、op-log 由恆 None→真值。**FR-010** 零 schema 變更／零 entity 改／零 base-web 既有檔改（只新增）／`enforce_mw`·`audit_mw` 零回歸。
- **SC**：SC-001 super get→全列 KV／非 super→5003·403（live＋CDP）。SC-002 super update single_session_default→DB 變＋op-log 一列 operator/operator_ip(真 INET)/trace 非空（live）。SC-003 value_type 違→2222（純測＋live）。SC-004 `endpoint_coverage_lint` 綠（三類 route 分類、policy-governed 對應 seed）。SC-005 wire 3 端對齊零型謊＋i18n toast 經 `$t`（CDP）。SC-006 零回歸（/health、login/getUserInfo/enforce 不變、零 schema/entity、base-web 既有檔不改）。SC-007 三守恆全綠（含新立 endpoint_coverage_lint）。

## 9. C-V 驗收（草案、live 一律 `--test-threads=1` serial；rust 容器內）
- **C-V-1** facade `*_active_model` 純測（欄映射/updated_at·by Set）→ FR-002。
- **C-V-2** value_type 驗純測（`enum:on,off` 合法/非法）→ FR-004/SC-003。
- **C-V-3** `endpoint_coverage_lint`（`cargo test -p server --test endpoint_coverage_lint`）→ FR-008/SC-004：三類 route 分類、policy-governed 對應 p-policy seed。
- **C-V-4** live super update→psql `system_settings`(值變)＋`sys_operation_log` 末列（operator_id/operator_ip 真 INET/trace 非空）→ FR-009/SC-002。
- **C-V-5** live super get→全列 KV／非 super（如 Admin/User token）→ 5003·HTTP403 → FR-003/SC-001。
- **C-V-6** CDP 經 front-nginx 真 `/api`：super 登入→system-settings 頁→toggle→存→toast＋DB 變；非 super→403 modal → SC-005。
- **C-V-7** 零回歸（/health ok、login/getUserInfo/enforce 不變、`entity_access_lint` 綠、diff 零 schema/entity、base-web 既有檔不改）→ SC-006/SC-007。
- **C-V-8** prod image build（無新 crate、輕；確認新 handler/facade/lint 編入 prod target）→ build 面。

## 10. Files（當前 lineage、BUILD vs ALREADY）
**BUILD（新/改）**：`rust-api/server/src/model/facade/system_settings.rs`（新）／`facade/mod.rs`（註冊）／`server/src/handler/system_settings.rs`（新）＋`handler/mod.rs`／`server/src/auth/enforce.rs`（加 `require_policy`、`enforce_mw` 不動）／`main.rs`（2 路由＋分層＋mod）／`rust-api/migration/src/m005_*.rs`＋`migration/src/lib.rs`（seed-only：端點 policy＋新頁 menu）／`server/tests/endpoint_coverage_lint.rs`（新）／base-web `src/service/api/rev3-system-settings.ts`（新）＋`src/typings/api/*.d.ts`（`SystemSetting`）＋`src/views/manage/system-settings/`（新頁）＋i18n locale `backend.biz.systemSettings.*`（zh-cn/en-us、⚠️aa BASE-WEB-I18N-WIRING ★ scope(ii)＋⚠️y 規約）。
**ALREADY（不動）**：`entity/src/system_settings.rs`（004）／schema＋seed（m001/m002）／`audit_ctx.rs`（007）／`enforce_mw`·`enforce_role_path_method`（006）／`mutate_in_txn`·`From<DbErr>`（005/006）／`error.rs` 13 碼（003）。

## 11. forward-compat / 下游
- **波 3**（Auth/Token/Session 合刀）：接 redis pub-sub＋`settings_watcher`（訂 `settings:invalidate`）＋`AppState.session_mode` 熱快取＋`single_session_default` consumption（single-session 行為機讀 session_mode）＋`casbin:policy:invalidate` watcher（policy reload）。本刀 `single_session_default` 讀寫 seam 已通。
- **波 2 User 刀**：借本刀 §8.1 全鏈骨架＋`require_policy` pattern；首 exercise PageRes/§5.8 分頁·filter（含空字串 filter 守門、curl≠modal）＋★MODAL-WIRING 重刀。
- **⚠️l 多 key**：單鍵 swap 推廣 keyed-map＝設計變更、需要時為之。
- **plan-phase 接地清單**：base-web 路由模式＋新頁選單/路由註冊機制（§2.4）／m005 確切列序（m004 無 slot 已確認、D4）／`endpoint_coverage_lint` 確切斷言形（§4.6）／DbErr 23505→2222 映射落點（D7）。
