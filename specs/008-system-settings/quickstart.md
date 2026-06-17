# Quickstart: 008-system-settings 驗證指南

> 從零驗證本刀（system_settings KV 打樋）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型/接線＝[data-model.md](data-model.md)；不變式＝[contracts/system-settings-contract.md](contracts/system-settings-contract.md)；ground-truth＝[research.md](research.md)。

## 前置
- dev stack 全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 m001 schema＋m002 seed〔含 single_session_default＋system-settings 端點 policy×2＋menu policy＋sys_menu 列〕＋`Super`/`Admin`/`User`/`123456`）。
- **無 migration**（m005 MOOT、research R1）；base-web `VITE_AUTH_ROUTE_MODE=static`（波1；dynamic-menu＝波2）。
- rust 一律容器內跑；改 `.rs` 先 force-touch；rust serial；live `--test-threads=1`。
- base-web commit `--no-verify`（§8.2.1）。

## 驗證流程（11 步、對應 C-V-0~10）
1. **build 綠**（C-V-0）：force-touch → `cargo build -p server --locked`（facade/handler/require_policy/lint 編譯、無新 dep）。
2. **facade active_model 純測**（C-V-1）：`cargo test -p server active_model` → setting_value Set／updated_at·by 成對。
3. **value_type 驗純測**（C-V-2）：`cargo test -p server value_type` → enum:on,off 合法/非法。
4. **endpoint_coverage_lint**（C-V-3、★⚠️x 波1 立）：`cargo test -p server --test endpoint_coverage_lint` → 三類 route 分類、policy-governed×2 對應 m002 seed。
5. **entity_access_lint 守恆**（C-V-4）：`cargo test -p server --test entity_access_lint` → handler/require_policy/main 零 path-root entity::。
6. **live op-log INET round-trip**（C-V-5）：`cargo test -p server -- --ignored --test-threads=1 system_settings_update` → op-log 末列 UPDATE/operator_id/operator_ip(真 INET)/trace 非空、值已改。
7. **live policy-gate**（C-V-6、★首 5003 live）：Super get→全列 KV／Super update→0000＋值變／**Admin/User→HTTP 403·code 5003**（psql 驗值）。
8. **CDP 經 front-nginx**（C-V-7）：Super 登入→/manage/system-settings 頁→toggle→存→toast＋DB 變／非法值→2222 在地化 toast／非 super API→403。
9. **base-web typecheck**（C-V-8）：`pnpm typecheck` → rev3-system-settings.ts＋SystemSetting typings＋backend.biz.systemSettings Schema 對齊（先 Schema 後 locale）。
10. **prod image build**（C-V-10、無新 crate、輕）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`。
11. **零回歸**（C-V-9）：`/health` ok；diff 零 migration/entity/schema；base-web 既有檔不改。

## 預期結果（對應 SC）
| 步 | 對應 SC | 通過 |
|---|---|---|
| 1 | （建置面） | 編譯綠、無新 dep |
| 2 | SC-002 | active_model 欄映射 |
| 3 | SC-003 | value_type 驗 |
| 4 | SC-004/SC-007 | endpoint_coverage_lint 綠、policy-governed 對應 seed |
| 5 | SC-002 | op-log operator_ip 真 INET round-trip |
| 6 | SC-007 | entity_access_lint 續綠 |
| 7 | SC-001/SC-002 | super 讀/改＋審計；非 super 403·5003（首 live） |
| 8 | SC-005 | CDP 頁端到端＋在地化 toast |
| 9 | SC-005 | wire 3 端零型謊＋i18n Schema |
| 10 | （建置面） | prod target 含新 handler/facade/lint |
| 11 | SC-006 | /health 零回歸、零 schema/entity 變更 |

## 不在本刀（各歸其刀）
- 波2 Menu 刀：dynamic-menu（getUserRoutes＋`.env` dynamic、拍板#7）→ 屆時 system-settings 選單由 m002 seed 的 sys_menu 列＋getUserRoutes Casbin 過濾驅動（取代波1 static route）。
- 波2 User：§5.8 分頁/filter/空字串守門首 exercise／DbErr 23505→2222 映射。
- 波3 Auth/Token/Session 合刀：§5.6 redis pub-sub watcher＋`session_mode` 熱快取＋`single_session_default` consumption（single-session 行為機讀 session_mode）。
- ⚠️l 多 key keyed-map（設計變更、需要時）。
