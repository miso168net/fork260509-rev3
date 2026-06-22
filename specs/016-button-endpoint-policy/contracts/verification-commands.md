# C-V 驗證指令：Button-Endpoint 授權治理（三維 RBAC runtime 編輯）

> 共用：`DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"`；rust **全程 serial**；live `#[ignore]` 測 `--test-threads=1` + `DATABASE_URL`；psql 經 postgres 容器；改 `.rs` 後先 **force-touch**；★ **i18n 改後 restart base-web 才能 CDP 驗**。**零新 crate、零 migration**。§4.2 5 invariants 逐條對應（§8.8 DoD）。

## C-V-0 — build 綠（含新 set_role_endpoints + registry）
```bash
$DC exec -T rust-api sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server'
```
涵蓋：新 `set_role_endpoints`／`SetEndpointsError/Outcome`／`ALL_ENDPOINT_POLICIES` const／`all_buttons`／`button_codes_for_role`／`endpoint_pairs_for_role`／6 handler 編譯。

## C-V-1 — lint 不變式（§I.6 / endpoint 覆蓋 / registry 防漂移）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint --test endpoint_coverage_lint'
```
- `entity_access_lint`：新 facade 在 `model/facade/` 豁免；handler/main 零 path-root `entity::`。
- `endpoint_coverage_lint`：① **AS_BUILT_ROUTES 37→43**（+6 button/endpoint 編輯端點）、registered==as-built（Assertion B）；② Assertion A：6 端點 `(path,method)` **已 seed**（`m002:148-153`）→ 零 migration 驗證；③ **新 registry assertion**：`ALL_ENDPOINT_POLICIES` ⊇ registered policy-governed endpoint（防漂移）。
> 看到「0 passed / N filtered out」立即警覺 filter 沒命中（§8.2）。

## C-V-2 — live button 維度（§4.2 ①④、US1、SC-001）
```bash
$DC exec -T rust-api sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && \
  DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo test -p server <button_live_test> -- --ignored --test-threads=1'
```
in-crate `#[ignore]` live（snapshot-restore guard、trace_id `"016-button-smoke"`、自清）：
- updateRoleButton 撤一 button code → psql 證 `casbin_rule` v2='button' 該列消失 + archive 有該列（archive-move）；getUserInfo/`buttons_for_roles` 反映。
- grant → casbin_rule 新列 + buttons 反映。
- restore（復用 015）→ 回現役 + archive 消費 + 審計。

## C-V-3 — ★ live endpoint 維度 + 鎖出守門（§4.2 ①②④、US2、SC-002/003）
```bash
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) \
  cargo test -p server <endpoint_live_test> -- --ignored --test-threads=1'
```
in-crate `#[ignore]` live（trace_id `"016-endpoint-smoke"`、snapshot-restore）：
- **set_role_endpoints 雙鍵 diff**：撤一【非保護】(path,method) → psql 證該 (v1=path,v2=method) 列消失 + archive 有該列；grant → 新列。
- **enforce 反映**：撤後該 role 對該 endpoint enforce 被拒（require_policy 路徑）。
- **★ 鎖出守門**：撤含【protected】endpoint（如 updateRoleEndpoints/getRoleMenu）→ 整批 `Rejected`、**現役與 archive 皆零變更**、回 `biz.role.endpointProtected`（恢復路徑保留、SC-003）。
- restore（復用 015、endpoint 維度）→ 回現役 + archive 消費。

## C-V-4 — PolicyMutated gate（§4.2 ③、US3、SC-004）
- updateRoleButton/Endpoints Rejected → **不** reload **不** publish（publish 計數=0）；Applied（含**空-diff** 送相同集合）→ **必** reload+publish（鏡像 015 gate 測法、復用 reload_and_publish）。

## C-V-5 — live policy-gate（curl、§4.2、FR-009、SC-006）
```bash
# Super → 200；Admin/User → 403/5003（DB-fresh roles、6 端點 R_SUPER-only）
curl -fsS -X GET  http://127.0.0.1:31081/systemManage/getAllButtons   -H "Authorization: Bearer $SUPER_TOKEN"
curl -fsS -X GET  http://127.0.0.1:31081/systemManage/getAllEndpoints -H "Authorization: Bearer $SUPER_TOKEN"
curl -s   -X POST http://127.0.0.1:31081/systemManage/updateRoleButton -H "Authorization: Bearer $ADMIN_TOKEN" -d '{"roleId":2,"buttonCodes":[]}'  # 期 403/5003
```

## C-V-6 — ★ 2-instance 跨副本收斂（§4.2 ⑤、US3、SC-005）
```bash
$DC --profile multi up -d rust-api-2 --wait     # :31082、shared pg/redis、watcher SUBSCRIBE casbin:policy:invalidate
```
- 副本 A updateRoleButton 撤某 button → psql 證 casbin_rule 改 → 副本 B `getUserInfo`（該 role user）buttons 反映（watcher 收斂）。
- 副本 A updateRoleEndpoints 撤某 endpoint → 副本 B 對該 (role,path,method) enforce 依最新被拒。
- A restore → B 恢復；`CLIENT KILL TYPE pubsub` → 重訂閱 → 後續仍收斂。
- 收尾 id-snapshot op-log 清理 + `--profile multi down`、dev DB 零殘留。

## C-V-7 — CDP 三維編輯 UI（MODAL-WIRING (c)、SC-006）
經 front-nginx `:31080`（CDP 9229、SOY_token 注入；★ **先 `restart base-web` 驗 i18n**）：
- Super → `/manage/role` → edit 某角色 drawer → **三鈕（選單/按鈕/端點授權）** 皆在。
- **button-auth-modal**（un-mock）：真打 getAllButtons/getRoleButton → 勾選 → updateRoleButton → psql 證 casbin_rule 改。
- **endpoint-auth-modal**（新）：真打 getAllEndpoints/getRoleEndpoints → 顯 (path,method) → 勾選 → updateRoleEndpoints → psql 證；撤 protected endpoint → 前端顯 `biz.role.endpointProtected` 在地化。
- §3.13 console error 不再（既有頁、無新 route）；i18n `endpointAuth` 標籤 resolve（非原始 key）。

## C-V-8 — 零回歸 + prod build（FR-010/011、SC-007/008）
```bash
# 零回歸全套（menu 維度 011/015 + button/endpoint 新測）
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo test -p server -- --ignored --test-threads=1'
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server'                # 非 ignored 全套
# zero migration
git diff --stat <merge-base>..HEAD -- rust-api/migration/   # 期空
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) sh -c "cargo run -p migration -- down -n 1 && cargo run -p migration -- up"'
# base-web typecheck
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'
# ★ prod target image build（即使無新 crate、仍驗 prod 多階段不破）
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 既有 menu/role/audit 零回歸；archive_reason "role_dimension_revoke"（menu/button）/"role_endpoint_revoke"（endpoint）並存、回收桶 v2-推導不破 012 audit_query 基線。

---

**invariant ↔ C-V 對照（§8.8 DoD）**：① DB-first→C-V-2/3（psql 證 DB、無 MgmtApi）｜② protected-reject→C-V-3（endpoint 鎖出）｜③ PolicyMutated gate→C-V-4｜④ 原子+審計→C-V-2/3｜⑤ reload+publish 跨副本→C-V-6。UI→C-V-7；gate/policy→C-V-5；零回歸→C-V-8。
