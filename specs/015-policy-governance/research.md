# Phase 0 Research: Policy 治理島（授權規則回收桶）

> 接地自 pin rust-api `7ec8fc3` / base-web `f3b2bf07`（4-agent 平行 act-on-code grounding）。**本刀零 migration、零新 crate**——皆讀寫既有 schema（`casbin_rule` ⇄ `sys_casbin_policy_archive`）+ 既有 Redis 基建（014 建）。

## ★ 接地關鍵發現（決定本刀規模）

1. **零 migration 確認**（item 8 核心）：`sys_casbin_policy_archive`（13 欄、`m001:665`）＋ 2 endpoint policy seed（`/systemManage/getArchivedPolicies` GET、`/systemManage/restorePolicy` POST、`m002:166-167`）＋ menu policy（`m002:168`/`:253`）＋ sys_role_policy（`m002:356-358`）**全波0已備**（rev2 034/035 終態 squash）。本刀只【註冊 endpoint + 實作 + bump `AS_BUILT_ROUTES` 35→37】。
2. **archive facade 不存在**——`model/facade/sys_casbin_policy_archive.rs` 須新建（沿 `sys_casbin_rule.rs` 範式）。
3. **`archive.created_at` NULLABLE vs `casbin_rule.created_at` NN**（★ 跨表型不對稱）——restore（archive→live）須 coerce `created_at: None → now()`（或保 Some）；archive-move（live→archive）：casbin_rule.created_at NN → archive.created_at=Some(it)、無虞。
4. **011 reload-on-`changed` vs §4.2 ③「空-diff Applied 仍 reload」**——須 reconcile（見 D3、本刀對齊 §4.2）。
5. **`role_menu_loop` 測 teardown 缺 archive 清理**——revoke 改 archive 後會留 archive 殘留、破 byte-identity 斷言（見 D6）。

## D1 — archive-move（revoke：HARD DELETE → snapshot+archive+delete）

**接地**：`set_role_dimension(conn:&C, role_code:&str, dimension:&str, desired_objs:&[String], meta:AuditMeta, role_id:i64) -> Result<SetDimensionOutcome{changed:bool}, SetDimensionError{Db(DbErr),Rejected(Vec<String>)}>`（`sys_casbin_rule.rs:47-54`）。revoke 現為 HARD DELETE（`:109-118`：`delete_many().filter(Ptype=p,V0=role_code,V2=dimension).filter(V1.is_in(to_revoke))`）。protected-reject（`:98-105`、BEFORE delete、回 `Ok((txn,Err(protected_revoked),None))`）。grant insert（`:120-139`：protected:false, created_at=Utc::now(), created_by=Some(operator)）。

**Decision**：revoke 改——先 **SELECT to-revoke 的完整 casbin_rule 列**（含 created_at/created_by）→ **INSERT into sys_casbin_policy_archive**（ptype/v0-v5 照搬、`created_at=Some(live.created_at)`、`created_by=live.created_by`、`archived_at=now`、`archived_by=Some(operator.id)`、`archive_reason="role_dimension_revoke"`〔≤32 char〕）→ **DELETE casbin_rule**（**同一 txn、原子**）。protected-reject 維持 BEFORE 任何寫（零回歸）。
**Rationale**：archive-move 必在 delete 前（防資料丟失、R1 risk）；同 txn 保 ④原子；`archive_reason` NN 須填（`m001:738`、32 char）。
**Alternatives**：soft-delete casbin_rule（加 deleted_at）——違零 migration、且 casbin adapter `load_policy` 會讀到 soft-deleted（除非改 adapter）；棄。

## D2 — restore + getArchivedPolicies + 2 endpoint

**接地**：archive entity 13 欄（id/ptype/v0-v5/`created_at:Option`/created_by:Option/`archived_at:NN`/archived_by:Option/archive_reason:String、`sys_casbin_policy_archive.rs:8-23`）。endpoint seed 已備（`m002:166-167`）；main.rs 路由範式＝per-domain group、外層 `enforce_mw` + 內層 `require_policy`（m002 seed）。`mutate_in_txn`（audit.rs:84-97）：closure 回 `(txn, R, Option<AuditEvent>)`，Some→同 txn 寫 op-log、None→commit 無 op-log。

**Decision**：
- **archive facade**（新 `sys_casbin_policy_archive.rs`）：`list(conn, role_code?, dimension?, page, size) -> (Vec<Model>, total)`（鏡像 `sys_operation_log` list）；`restore(conn, archive_id, meta) -> RestoreOutcome`。
- **restore 邏輯**：read archive row by id（None→**NotFound** 2222）→ **live 7-col pre-check**（casbin_rule 已有同 ptype/v0-v5 列？已 live→**NoOp**：DELETE archive row、不 INSERT、不審計、回 0000）→ else INSERT casbin_rule（ptype/v0-v5 照搬、protected:false、`created_at=archive.created_at.unwrap_or(now)`、created_by=archive.created_by）+ DELETE archive row + **restore 審計 `{role:v0, target:v1, dimension:v2}`**（同 txn 原子、④）。
- **handler**：`getArchivedPolicies`（GET、`PageRes<ArchivedPolicy>`、honest）；`restorePolicy`（POST {id}、Applied/NoOp→`0000`、NotFound→`2222`）。
- **main.rs**：新 route group（getArchivedPolicies GET + restorePolicy POST、R_SUPER、`require_policy`、m002 seed 已備）；`AS_BUILT_ROUTES` 35→37（`endpoint_coverage_lint:85-121`）。
**Rationale**：restore 三結局（移回/NoOp/NotFound）= §4.2 對外碼；NoOp 消費 archive 列（不留懸空）；審計記 `{role,target,dimension}`（非懸空 archive_id、④）。
**Alternatives**：restore by {role,target,dimension}——UI 已有 archive row id、by-id 直接；審計仍記 {role,target,dimension}。

## D3 — PolicyMutated gate（reload+publish on Applied、§4.2 align）

**接地**：011 handler（`system_manage.rs:1118-1127`）現 `if outcome.changed { enforcer.write().await.load_policy() }`（**local-only、reload-on-`changed`**）。`changed=!to_revoke.is_empty()||!to_grant.is_empty()`（`:107`）。§4.2 ③：「只有結構性真變更才 reload_and_publish（Rejected/restore NoOp/NotFound 跳）；惟**空-diff Applied 與 menu-found-但-無-policy 仍 reload（刻意、不優化）**」。

**Decision**：抽 `reload_and_publish(&state)` helper＝`enforcer.write().load_policy()` + `redis publish casbin:policy:invalidate`（best-effort、fail-OPEN）。gate：
- `set_role_dimension`（updateRoleMenu）：**Ok(Applied) → reload_and_publish**（含空-diff、§4.2「不優化」；**調整 011 的 `outcome.changed` gate**）；`Err(Rejected)` → 跳。
- `restorePolicy`：Applied（真移回）→ reload_and_publish；NoOp/NotFound → 跳。
**Rationale**：§4.2 ③ 凍結「空-diff Applied 仍 reload」；011 的空-diff-skip 與之不符、本刀對齊（`load_policy` 冪等、多一次無害）。reload+publish 綁定（⑤）。
**Alternatives**：維持 011 reload-on-`changed`——違 §4.2 ③（須 amend）；棄。version/hash 去重（R2 gap）——§4.2 明文「不優化」、YAGNI、棄。

## D4 — 跨實例 pub-sub（casbin:policy:invalidate + spawn_policy_watcher）

**接地**：014 `spawn_settings_watcher`（`main.rs:523-567`、SUBSCRIBE settings:invalidate→重載 single_session_default、30s backoff 重訂閱）；`SETTINGS_INVALIDATE_CHANNEL`（`main.rs:38`）；RedisHandle `subscribe_pubsub`（`redis.rs:107`）+ publish；system_settings PUBLISH（`system_settings.rs:110-114`）。enforcer 型＝`Arc<RwLock<Enforcer>>`（state.rs/`enforce.rs:52-58`）。

**Decision**：
- 新 `CASBIN_INVALIDATE_CHANNEL="casbin:policy:invalidate"`。
- `reload_and_publish`（D3）publish 此 channel（best-effort、fail-OPEN）。
- 新 `spawn_policy_watcher(redis, enforcer)`（**獨立 task、鏡像 `spawn_settings_watcher`**）：SUBSCRIBE casbin:policy:invalidate → `enforcer.write().await.load_policy()`；斷線 30s backoff 重訂閱（韌性、fail-OPEN）；boot spawn。
**Rationale**：獨立 watcher = 單一職責（settings/policy 各一 channel、各一 reload action）；復用 014 範式（subscribe loop + 重訂閱）。
**Alternatives**：擴充既有 settings watcher 多工 dispatch——耦合兩 reload 語意、棄（獨立更清）。
**Risk（R2、登記非阻塞）**：Redis-down watcher 無限 30s backoff（副本靜默發散）——fail-OPEN tradeoff、本機唯一真相 DB；RwLock write 期 enforce 讀阻塞——`load_policy` 短、可接受。

## D5 — base-web policy-archive 回收桶 UI（MODAL-WIRING (e)）

**接地**：`rev3-system-manage.d.ts`（rev3 型 declaration-merge、不動 frozen；list=`Common.PaginatingQueryRecord<T>`、SearchParams=`RecordNullable<{}&CommonSearchParams>`、id `number`）；`rev3-system-manage.ts`（直 import `../request`、fetchXxx→request、`String(id)` 寫、`pruneNullParams` 濾空 query、views 直路徑 import）；010 menu restore（NPopconfirm→handleRestore→fetchRestoreMenu、`menu/index.vue:183-201/262-267`）；012 audit（多 tab + `operation-log-table.vue`：searchParams 全 null、`useNaivePaginatedTable`、onPaginationParamsChange、reset/search）；`app.d.ts` I18n.Schema page.manage.<page>；locales `manage.{}` tree。

**Decision**：
- **typings**（rev3-system-manage.d.ts、rev3-inline 新型）：`ArchivedPolicy{id:number, roleCode:string, target:string, dimension:string, archivedTime:string, archivedBy:number|null, archiveReason:string, createdTime:string|null}` + `ArchivedPolicySearchParams`（RecordNullable、roleCode/dimension filter + CommonSearchParams）+ `ArchivedPolicyList=Common.PaginatingQueryRecord<ArchivedPolicy>`。
- **service**（rev3-system-manage.ts、WRAPPER）：`fetchGetArchivedPolicies(params?)→request<ArchivedPolicyList>`（`pruneNullParams`）；`fetchRestorePolicy(id:number)→request<null>`（POST `/systemManage/restorePolicy` {id:String(id)}）。
- **view**（新 `views/manage/policy-archive/{index.vue, modules/policy-archive-table.vue}`、MODAL-WIRING (e)）：NDataTable（col：role/target/dimension/archivedTime/archivedBy/reason）+ filter（role/dimension）+ restore 鈕（NPopconfirm→fetchRestorePolicy→reload list）；hasAuth gating；鏡像 012 list + 010 restore。
- **i18n**：`app.d.ts` Schema `page.manage.policyArchive.*`（**先 Schema**）→ locales zh-cn/en-us `manage.policyArchive`（**後 locale**、`base-web-i18n-schema` gotcha）。
**Rationale**：嚴格鏡像既有頁（MODAL-WIRING (e) 紀律）；建 view 即消解 §3.13 console error（種子 menu 終於有 component）。
**Risk（R3）**：i18n Schema-先-locale-後；vite 熱載新 service fn（views 直路徑 import、非 barrel）；`String(id)` 寫（漏→2222）；`pruneNullParams` 濾空 query（漏→空字串 400/全列）；`components.d.ts` auto-gen（新 naive-ui 元件首用觸發、§4.1 commit 注意）。

## D6 — 零回歸 + 2-instance 驗證 + lints

**接地**：`role_menu_loop` 測（`sys_casbin_rule.rs:185-303`、snapshot-restore guard）teardown（`:279-299`）byte-restore casbin_rule + reload + 清 op-log（entity_table='casbin_rule' AND entity_id=role_id、`:285-290`）——**但不清 archive**。trace_id "role-menu-loop-smoke"（`:271`）。`docker-compose.dev.yml` rust-api-2（`:108-146`、profiles:[multi]、:31082、shared pg/redis、獨立 rust_api2_target）。`entity_access_lint`（archive facade 須在 model/facade/ 豁免）；`endpoint_coverage_lint`（AS_BUILT 35→37、Assertion A 已 seed）。

**Decision**：
- **`role_menu_loop` teardown +archive 清理**（`:290` 後）：`DELETE sys_casbin_policy_archive WHERE ptype='p' AND v0=code AND v2='menu'`（清 revoke→archive 殘留、保 byte-identity 斷言）。
- **2-instance（C-V）**：rust-api-2 起、副本 A revoke→psql 證 archive 列 + 副本 B enforce 依最新（casbin:policy:invalidate watcher 收斂）；A restore→B 恢復；`CLIENT KILL TYPE pubsub`→重訂閱韌性。
- **lints**：archive facade 在 model/facade/（`entity_access_lint` 豁免）；`AS_BUILT_ROUTES` 35→37。
**Risk（R4）**：op-log+archive teardown 清理順序（強異常處理）；`archive_reason` NN 須填（D1）；`--test-threads=1` serial（archive insert/delete txn lock）；新 endpoint cargo test bare-filter 偽綠坑（用 `--test <name>`、見 §8.2）。

## 收掉的 plan-level opens

- `archive_reason`＝`"role_dimension_revoke"`（≤32 char、固定）——非 user 拍板。
- watcher＝獨立 `spawn_policy_watcher`（非擴充 settings watcher）——工程決定。
- restore by archive_id（UI 傳 row id）、審計記 `{role,target,dimension}`（④）——非懸空 archive_id。
- getArchivedPolicies 分頁＋role/dimension filter（鏡像 012、`pruneNullParams` 空字串守門）——honest typing。
- gate reconcile（D3）＝對齊 §4.2「空-diff Applied 仍 reload」、調整 011——§4.2-faithful、**非 amend**（§I.7 留欄級/常數於非凍結面；reload 觸發語意屬 §4.2 ③ 凍結、本刀使 011 合規）。
- A 拍板（un-protect 不做）= §4.2-faithful（做它須 §V.2 amend ②）。
