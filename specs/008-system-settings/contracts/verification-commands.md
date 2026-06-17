# C-V Contract: verification-commands（008-system-settings）

> 實機驗收命令全集。rust 一律**容器內**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**；**live `#[ignore]` 一律 `--test-threads=1`**（共用 op-log 表、非 parallel-safe）。**無新 workspace crate**（prod build 輕、見 C-V-10）。
> 預設帳號（m002 seed）：`Super`/`Admin`/`User`、密碼 `123456`。`Super`＝R_SUPER（policy 通過）、`Admin`/`User`＝非 super（policy deny→5003）。DB（容器內）：`/run/secrets/database_url`。psql：`docker compose … exec -T postgres psql -U soybean -d soybean_admin_rust -tAc "<sql>"`。
> **★ MOOT（無 migration）**：端點 policy（×2）＋menu policy＋sys_menu 列已 m002 seed（research R1）；本刀無 m005、無 schema 變更。

## C-V-0 · build 綠（無新 crate）
```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo build -p server --locked'
```
- facade/handler `system_settings`、`require_policy`（enforce.rs）、`endpoint_coverage_lint` 編譯綠；1.86 不撞；無新 dep。

## C-V-1 · facade `*_active_model` 純測 → FR-002
```bash
docker compose … exec -T rust-api sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server active_model'
```
- `update_by_key` 的 active_model seam：`setting_value` Set、`updated_at`/`updated_by` 成對 Set、其餘不動。⚠️「0 passed/N filtered」＝非綠。

## C-V-2 · value_type 驗純測 → FR-006/SC-003
```bash
docker compose … exec -T rust-api sh -c 'cd /app && cargo test -p server value_type'
```
- `validate_value_type("enum:on,off", "on")`=Ok／`("enum:on,off","maybe")`=Err(Biz invalidValue)；型解析正確。

## C-V-3 · `endpoint_coverage_lint`（⚠️x 波1 立）→ FR-008/SC-004
```bash
docker compose … exec -T rust-api sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test endpoint_coverage_lint'
```
- 已註冊 route 分類 public/auth-only/policy-governed；**policy-governed（system_settings ×2）必有對應 m002 casbin p-policy seed**；registered==as-built registry（非 §7.1 @35）。「N passed」非「0 filtered」。

## C-V-4 · `entity_access_lint` 守恆 → SC-007
```bash
docker compose … exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint'
```
- handler/`require_policy`(enforce.rs)/main 零 path-root `entity::`（entity 全在 facade、續綠）。

## C-V-5 · live super update→op-log INET round-trip（`--ignored --test-threads=1`）→ FR-003/FR-009/SC-002
```bash
docker compose … exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat /run/secrets/database_url) cargo test -p server -- --ignored --test-threads=1 system_settings_update'
```
- in-crate `#[ignore]` smoke（置 `facade/system_settings.rs`、外層 txn rollback 不污染 seed）：顯式 `AuditOperator{id,ip:Some(IpNetwork::from(..))}`＋trace 餵 `update_by_key`→psql `sys_operation_log` 末列 `operation='UPDATE'`/`operator_id`/`operator_ip`(真 INET)/`trace_id` 非空、`system_settings` 該 key 值已改。

## C-V-6 · live policy-gate（super 通過／非 super 5003·403）→ FR-003/004/SC-001
```bash
BASE=http://127.0.0.1:31081
# super：讀全列 + 改成功
TS=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s "$BASE/systemManage/getSystemSettings" -H "Authorization: Bearer $TS"          # 200 + 全列 KV
curl -s -X POST "$BASE/systemManage/updateSystemSetting" -H "Authorization: Bearer $TS" -H 'Content-Type: application/json' -d '{"settingKey":"single_session_default","settingValue":"on"}'  # 200
# 非 super（Admin）：讀/改 → 5003/403
TA=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' -d '{"userName":"Admin","password":"123456"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['token'])")
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/systemManage/getSystemSettings" -H "Authorization: Bearer $TA"   # 403
```
- super get→全列（含 single_session_default）；super update→0000＋值變（psql 證）；**Admin/User→HTTP 403、body code 5003、不洩值**（★首個 5003 live 證據）。psql 驗 system_settings 值。

## C-V-7 · CDP 經 front-nginx 真 `/api`（modal/頁）→ SC-005
```bash
# 經 :31080/api（front-nginx strip）；CDP scripts 見 docs/superpowers/000 + tests/000
```
- super 登入→ system-settings 管理頁（static route /manage/system-settings）→ toggle single_session_default→存→toast（成功 `$t`）＋DB 值變；改非法值→2222 toast 在地化（「設定值不符合型別」類）；非 super（Admin）打 API→403。**page static-reachable（波1）；選單-Casbin-visibility＝波2**。

## C-V-8 · base-web typecheck（wire 3 端＋i18n Schema）→ SC-005
```bash
docker compose … exec -T base-web sh -c 'cd /app && pnpm typecheck'   # --no-verify commit、見 §8.2.1
```
- `rev3-system-settings.ts` wrapper＋`SystemSetting` typings＋`backend.biz.systemSettings` Schema 型對齊（先 Schema 後 locale、否則 `$t` typed-key 失敗）；wire 3 端零型謊。

## C-V-9 · 零回歸 → SC-006
```bash
docker compose … exec -T rust-api sh -c 'cd /app && cargo build -p server --locked' ; curl -fsS http://127.0.0.1:31081/health   # ok
cd rust-api && git diff --name-only 006後..HEAD | grep -iE "migration/|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
```
- /health 零回歸；login/getUserInfo/enforce_mw/audit_mw 不變；diff **零 migration/entity/schema 變更**（m005 MOOT、research R1）；base-web 既有 auth.ts/system-manage.ts/route.ts 不改（只新增 rev3-* wrapper＋新 typings＋新頁＋locale 加 key）。

## C-V-10 · prod target image build（無新 crate、輕）→ build 面
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認新 handler/facade/`require_policy`/`endpoint_coverage_lint` 編入 prod target（無新 crate→無 Dockerfile COPY 變更；`--locked`）。

## 出口
C-V-0~10 全綠＝本刀 acceptance 通過；對應 spec SC-001~007。**無 migration（m005 MOOT）／無新 crate**。
