# Contract: User CRUD＋M:N（009 落定、跨 feature 權威）

> 本刀建立的不變式，後續資料島 CRUD（Role 刀 §8.6／Menu 刀）、行為島（波3 即時撤銷）繼承。權威＝constitution §I.1/§I.3/§I.6/§III＋DESIGN §3.3/§3.4/§5.0/§5.2/§5.8/§8.2＋DECISIONS ⚠️o/⚠️r/⚠️y。

## 1. data-island CRUD＋M:N 寫同 txn（全專案首立、§5.2/§I.6）
1. **寫＝原子**：create/update/delete 的實體異動＋M:N join 替換（`replace_roles_in_txn`）＋op-log 三者**同一 `mutate_in_txn`**——任一失敗整體 rollback（不存在未審計異動、不存在實體已改而 join 未同步的半套）。
2. **op-log 首個 INSERT consumer**：create 於 insert 後回填 `entity_id=Some(after.id)`、`payload_before=None`、`payload_after=after.audit_json()`；update/delete `entity_id=Some(id)`。`operator_ip` 真 INET（`ctx.to_audit_operator(claims.uid)`、007 seam、**不抄 rev2 ip:None**）。
3. **審計欄成對**（§I.6）：create set `created_at`+`created_by`；update set `updated_at`+`updated_by`；delete set `deleted_at`+`deleted_by`。`now`＝`sea_orm::sqlx::types::chrono::Utc::now().into()`（server 無 chrono、business 表顯式 set）。
4. **讀端 redact**：list/讀回應**永不含 password**（`AuditSerialize for sys_user` 已 redact、op-log 亦不洩）。

## 2. 23505→2222 sql_err 寫端 pattern（全專案首立、⚠️o）
1. **DB 能擋者（unique）→ 寫端 `e.sql_err()→Some(SqlErr::UniqueConstraintViolation(_))→Biz(2222)`**；**不做 app pre-check**（避 TOCTOU）。
2. **blanket `From<DbErr> for AppError`（→Internal/5000）不改**——僅在 addUser/updateUser 寫端 `.map_err` 攔截 unique、其餘 DbErr 續走 Internal。**禁裸 `?`**（會走 blanket From→23505 靜默變 5000 type-lie）。
3. 後續有 unique 約束的寫端（Role roleCode、Menu routeName）沿此 pattern。

## 3. §5.8 list pattern（全專案首立：空字串守門＋模糊＋分頁）
1. **空字串守門**：base-web axios 把未設 filter 序列化成 `?x=`→serde `Some("")`；handler **normalize `Some("")→None`** 後才套 filter（字串 `.filter(|v|!v.is_empty())`；enum/i16 `Some("")→Ok(None)`）。**全空 filter 回全部、不得 0 列**（curl≠modal、必 CDP 帶空 param 驗）。
2. **模糊 vs 精確**（per-field、user 拍）：字串文本欄（如 userName/nickName/userEmail）`PgExpr::ilike('%escape_like(t)%').escape('\\')`（大小寫不敏感子字串、wildcard escape）；電話/enum 欄精確 `.eq`。
3. **分頁**：`find_active().apply_if(filter).order_by_desc(Id).paginate(size)`→`num_items()`＝真 total、`fetch_page(current-1)`（0-based）；current 默 1、size 默 10 clamp[1,100]；**超範圍頁回空 records＋真 total**（`PageRes{current,size,total,records}`）。
4. **roles 批次**：list 的 M:N 讀用 `roles_for_users(&[i64])→HashMap`（無 N+1、固定查詢）。

## 4. self-guard＋batch 語意（§3.3 單一 operator gate spirit）
1. **cannot-delete-self**：單筆刪自己或批次含自己→`Biz("biz.user.cannotDeleteSelf")` **整批拒、無 partial**。
2. **self-lock 防護**：update 自己移除自身超管角色 ∥ 設自己停用→`Biz("biz.user.selfLockForbidden")` 整筆拒（防 admin 自鎖）。
3. **batch 缺漏 idempotent**：批次含已不存在/已被刪 id→靜默略過、有效者照刪（soft_delete no-op）。

## 5. 停用登入 gate（§I.7 行為島不前拉）
1. **入口擋**：login 密碼驗證後 `status==Some(2)→AppError::LoginFailed`（1000、統一失敗、防枚舉、復用既有碼/i18n）。
2. **只擋新登入**：已發 token 不即時撤銷（≤token 到期自然失效）；即時撤銷（停用即踢）＝波3、不動 token/single-session 狀態機。

## 6. wire／i18n 不變式（§I.3 typings 權威＋§III 軌道）
1. **wire 3 端對齊**（rust DTO camelCase ↔ typings ↔ component）；`CommonRecord.id`＝**JSON number**（⚠️r、非 auth `userId` string）；type-lie 於序列化邊界消解（`Option<i64>→string`、i16→`'1'/'2'`、datetime rfc3339、NULL→`""`）；2^53 fail-loud guard。
2. **軌道（皆既授）**：rev3-* wrapper（WRAPPER §III.1）／新 typings 檔（ADAPT §III.1）／MODAL-WIRING **(a)** 既有頁 handleSubmit+index.vue delete handler（§III.2）／`backend.biz.user.*`（I18N-WIRING (ii)、⚠️y）。**MW (b) hasAuth gating 延波2 Menu 刀**（授權靠後端 403、前端可見性收於 getUserRoutes）。
3. **不改既有 base-web 檔**（system-manage.ts/.d.ts/auth.ts/request 攔截器不動；只新增＋locale 加 key、fork-delta rev3-inline 紀律）。

## 7. endpoint_coverage_lint 漸增（⚠️x、波0 三守恆之三）
1. `AS_BUILT_ROUTES` 逐刀漸增（dedup by **distinct path**、陣列長度型註記手動 bump）；**與路由註冊同 commit**（S9）。
2. Assertion B registered==as-built；Assertion A policy-governed⊆m002 seed（非反向）。

## 8. 本刀邊界（OUT／MOOT）
- **MOOT（已 done）**：表+partial-unique+FK+6 端點 policy（m001/m002/m003）／entity／AuditSerialize+redact／mutate_in_txn/SoftDeletable/PageRes/to_audit_operator/require_policy/blanket From<DbErr>/envelope（004-008）／User→User01 alias（006）。
- **OUT（遞延）**：前端 hasAuth gating＋dynamic menu＝波2 Menu 刀／updateUserSessionPolicy+session-policy-modal＋即時 token 撤銷＝波3／完整 Role CRUD+三權限 modal＝§8.6 另刀（getAllRoles 僅下拉）／改密碼／pg_trgm GIN。
- 無 migration／無 schema/entity 變更／無新 crate／enforce_mw·require_policy·From<DbErr>·audit_mw 不動／base-web 既有檔不改。
