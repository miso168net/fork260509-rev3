# Quickstart: 009-user-management 驗證指南

> 從零驗證本刀（使用者 CRUD＋角色 M:N＝波2 資料島首刀）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型/接線＝[data-model.md](data-model.md)；不變式＝[contracts/user-management-contract.md](contracts/user-management-contract.md)；ground-truth＝[research.md](research.md)。

## 前置
- dev stack 全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 m001 schema＋m002 seed〔`Super`/`Admin`/`User`/`123456`＋6 user 端點 p-policy＋partial-unique〕＋m003 FK）。
- **無 migration**（表＋policy 已 seed、research R1）；base-web `VITE_AUTH_ROUTE_MODE=static`（波1；dynamic-menu/hasAuth＝波2 Menu 刀）。
- rust 一律容器內跑；改 `.rs` 先 force-touch；rust serial；live `--test-threads=1`＋`DATABASE_URL`。
- base-web commit `--no-verify`（§8.2.1）。

## 驗證流程（15 步、對應 C-V-0~14）
1. **build 綠**（C-V-0）：force-touch → `cargo build -p server --locked`（facade/handler/login gate/main/error/lint、無新 dep）。
2. **filter/page normalize＋escape_like 純測**（C-V-1）：`cargo test -p server normalize`（空字串→None／模糊 pattern／clamp）。
3. **active_model 純測**（C-V-2）：`cargo test -p server active_model`（create/update 欄映射、成對審計欄、update 不動 user_name/password）。
4. **id/enum wire 純測**（C-V-3）：`cargo test -p server wire`（2^53 guard、i16→'1'/'2'、Option<i64>→string/""）。
5. **endpoint_coverage_lint**（C-V-4、★bump +6）：`cargo test -p server --test endpoint_coverage_lint`（`[&str;11]`、registered==as-built、policy⊆seed）。
6. **entity_access_lint 守恆**（C-V-5）：`cargo test -p server --test entity_access_lint`（handler/error/main 零 path-root entity::）。
7. **live addUser**（C-V-6、★首 INSERT op-log）：`cargo test -p server -- --ignored --test-threads=1 add_user`（INSERT op-log entity_id+真 INET、argon2 verify、roles 指派；dup user_name→2222 非 5000）。
8. **live updateUser**（C-V-7）：`… update_user`（user_name/password 不變、roles 替換、UPDATE op-log；self-lock→2222）。
9. **live delete/batch**（C-V-8）：`… delete_user`（soft-delete、self→2222 整批拒、缺漏略過）。
10. **live getUserList**（C-V-9、★§5.8 首 exercise）：curl 帶**空 param**（回全部非 0 列）＋模糊 userName 子字串＋精確 userPhone＋超範圍頁（空 records+真 total）＋**零 password**。
11. **live policy-gate＋停用登入**（C-V-10）：Admin 讀 list 200/寫 403；User 讀 403；停用 user 登入→1000。
12. **CDP 經 front-nginx**（C-V-11、★modal 真發 request）：Super→user 頁→搜尋（空+模糊）→新增/改（角色 chip 真 code）/刪/批刪→真發 request+toast 在地化；非 super→403。
13. **base-web typecheck**（C-V-12）：`pnpm typecheck`（rev3-system-manage.ts+UserUpsertModel 對齊）。
14. **prod image build**（C-V-14、無新 crate）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`。
15. **零回歸**（C-V-13）：`/health` ok；diff 零 migration/entity/schema；blanket From<DbErr> 未改；base-web 既有檔不改。

## 預期結果（對應 SC）
| 步 | 對應 SC | 通過 |
|---|---|---|
| 2-4 | SC-001/003/004/010 | 純測綠（normalize/active_model/wire） |
| 5-6 | SC-009/010 | 三守恆綠（endpoint_coverage_lint bump、entity_access_lint） |
| 7 | SC-003 | addUser INSERT op-log 真 INET＋dup→2222 |
| 8 | SC-004 | updateUser 不動帳密、roles 替換、self-lock 擋 |
| 9 | SC-005 | delete/batch soft-delete、self 整批拒、缺漏略過 |
| 10 | SC-001/002 | list 分頁+模糊+精確+空字串守門+零 password |
| 11 | SC-006/007 | 非授權 403、停用登入 1000 |
| 12 | SC-008 | CDP 真發 request＋在地化 toast＋角色 chip |
| 13 | SC-008 | wire 3 端零型謊 |
| 14-15 | （建置/SC-010） | prod build＋零回歸/零 schema |

## 不在本刀（各歸其刀）
- 波2 Menu 刀：dynamic-menu（getUserRoutes）＋前端 hasAuth/選單可見性（取代波1 static、收 user 選單對非 super 可見）。
- 波3 Auth/Token/Session 合刀：updateUserSessionPolicy＋session-policy-modal＋停用即時 token 撤銷（停用即踢）。
- §8.6 Role 刀：完整 getRoleList/addRole/三權限 modal（本刀 getAllRoles 僅下拉、薄讀 sys_role）。
- 改密碼（updateUser 不動 password）／pg_trgm GIN index（filter 未來選項）。
