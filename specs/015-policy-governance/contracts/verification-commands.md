# C-V 驗證指令：Policy 治理島（授權規則回收桶）

> 共用：`DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"`；rust **全程 serial**；live `#[ignore]` 測 `--test-threads=1` + `DATABASE_URL`；psql 經 postgres 容器；改 `.rs` 後先 **force-touch**（WSL2 stale-mtime）。**零新 crate、零 migration**。§4.2 5 invariants 逐條對應（§8.8 DoD）。

## C-V-0 — build 綠（含新 archive facade）
```bash
$DC exec -T rust-api sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server'
```
涵蓋：新 `model/facade/sys_casbin_policy_archive.rs`（archive-move/restore/list）＋ `set_role_dimension` revoke 改寫 ＋ handler 2 端點 ＋ `spawn_policy_watcher` ＋ `reload_and_publish` helper 編譯。

## C-V-1 — lint 不變式（§I.6 / endpoint 覆蓋）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint --test endpoint_coverage_lint'
```
- `entity_access_lint`：新 archive facade 在 `model/facade/` 豁免；handler/main **零 path-root `entity::`**。
- `endpoint_coverage_lint`：① **AS_BUILT_ROUTES 35→37**（+getArchivedPolicies GET +restorePolicy POST）、registered==as-built；② Assertion A：2 endpoint `(path,method)` **已 seed**（`m002:166-167`、`require_policy` ⊆ migration concat）→ **零 migration 驗證**（無新 seed、無新 mNNN）。
> 看到「0 passed / N filtered out」立即警覺 filter 沒命中（§8.2）。

## C-V-2 — live archive-move + restore（§4.2 ①④、US1、SC-001/002）
```bash
$DC exec -T rust-api sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && \
  DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo test -p server <archive_restore_live_test> -- --ignored --test-threads=1'
```
in-crate `#[ignore]` live（snapshot-restore guard、trace_id `"015-archive-restore-smoke"`、自清）驗：
- **archive-move**：revoke 一條非 protected → psql 證 `sys_casbin_policy_archive` 有該列（ptype/v0/v1/v2 + archived_at + archived_by + archive_reason='role_dimension_revoke'）**且** `casbin_rule` live 列消失（**同 txn 原子**）。
- **restore Applied**：restore 該 archive id → `casbin_rule` 回該列（created_at coerce）+ archive 列刪 + op-log 審計 `{role,target,dimension}`（trace_id 隔離、非懸空 archive_id）。
- **restore NoOp**：對「已 live」的 archive id restore → 回 `0000`、archive 列被消費、casbin_rule **不重複**、無變更審計。
- **restore NotFound**：對不存在 archive id → `2222`、零變更、無審計。

psql 範本：
```bash
$DC exec -T postgres psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT v0,v1,v2,archive_reason FROM sys_casbin_policy_archive WHERE v0='<role>' AND v2='<dim>';"
```

## C-V-3 — protected-reject 零回歸 + PolicyMutated gate（§4.2 ②③、US3、SC-003/004）
```bash
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) \
  cargo test -p server <gate_protected_live_test> -- --ignored --test-threads=1'
```
- **protected-reject**：`to_revoke` 含 protected 核心 → 整批 `Rejected` `2222`、**現役與 archive 皆零變更**（011 零回歸；BEFORE 任何寫）。
- **gate**：Rejected / restore NoOp / restore NotFound → **不** `reload_and_publish`（不 reload enforcer、不 PUBLISH）；Applied（含**空-diff** set_role_dimension）/ restore Applied → **必** reload+publish（驗 enforce 行為變更 or publish 計數）。

## C-V-4 — live policy-gate（curl、§4.2、FR-009、SC-006）
```bash
# Super → 200；Admin/User → 403/5003（無資料外洩、DB-fresh roles）
curl -fsS -X GET  http://127.0.0.1:31081/systemManage/getArchivedPolicies -H "Authorization: Bearer $SUPER_TOKEN"
curl -fsS -X POST http://127.0.0.1:31081/systemManage/restorePolicy -H "Authorization: Bearer $ADMIN_TOKEN" -d '{"id":"1"}'  # 期 403/5003
```

## C-V-5 — ★ 2-instance 跨副本收斂（§4.2 ⑤、US2、SC-005）
```bash
$DC --profile multi up -d rust-api-2 --wait     # 第二副本 :31082、shared pg/redis、watcher SUBSCRIBE casbin:policy:invalidate
```
- 副本 A（:31081）revoke 某授權 → psql 證 archive 列 → 副本 B（:31082）對該 user/resource enforce **依最新被拒**（casbin:policy:invalidate watcher 收斂）。
- A restore → B 後續放行。
- **watcher 韌性**：`$DC exec -T redis-stack redis-cli CLIENT KILL TYPE pubsub` → 重訂閱 → 後續變更仍收斂（不永久脫鉤）。

## C-V-6 — CDP 回收桶 UI（MODAL-WIRING (e)、FR-007、SC-006）
經 front-nginx `:31080`（CDP 9229、SOY_token 注入、curl≠modal）：
- Super → `/manage/policy-archive` → **list archived**（真打 getArchivedPolicies、非 fake data）+ **restore 鈕**（NPopconfirm）真打 restorePolicy → psql 證 live/archive 移動。
- **Super-only**：Admin/User 側欄無此頁、直呼 → `5003`。
- 建 view 後 `transform.ts` 不再報「View component not found」（§3.13 console error 消解）。

## C-V-7 — 零回歸 + prod build（FR-010/011、SC-007/008）
```bash
# 零回歸全套（role_menu_loop teardown +archive 清理後仍綠）
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo test -p server -- --ignored --test-threads=1'
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server'                # 非 ignored 全套
# zero migration（無新 mNNN；up→down→up 仍綠）
git diff --stat <merge-base>..HEAD -- rust-api/migration/   # 期空
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) sh -c "cargo run -p migration -- down -n 1 && cargo run -p migration -- up"'
# base-web typecheck
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'
# ★ prod target image build（即使無新 crate、仍驗 prod 多階段不破）
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- `role_menu_loop` teardown 已加 archive 清理（`DELETE sys_casbin_policy_archive WHERE ptype='p' AND v0=code AND v2='menu'`）→ `--ignored` 全套 byte-identity 斷言不破。
- 既有授權/角色/選單/稽核零回歸；現役授權終態與先前一致。

---

**invariant ↔ C-V 對照（§8.8 DoD）**：① DB-first→C-V-2（psql 證 DB 移動、無 MgmtApi）｜② protected-reject→C-V-3｜③ PolicyMutated gate→C-V-3｜④ 原子+restore 審計→C-V-2｜⑤ reload+publish 跨副本→C-V-5。UI→C-V-6；gate/policy→C-V-4；零回歸→C-V-7。
