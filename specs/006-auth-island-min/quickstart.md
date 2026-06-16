# Quickstart: 006-auth-island-min 驗證指南

> 從零驗證本刀（Auth 島最小段＋runtime 骨幹）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型/接線＝[data-model.md](data-model.md)；不變式＝[contracts/auth-island-contract.md](contracts/auth-island-contract.md)；ground-truth＝[research.md](research.md)。

## 前置
- dev stack 全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 002 seed：`Super`/`Admin`/`User` 密碼 `123456`、角色 R_SUPER/R_ADMIN/R_USER_COMMON、casbin 72 policy）。
- secret 已 provisioned（001）：`deploy/secrets/{jwt_secret,refresh_token_secret,database_url}.txt`；dev compose 給 `APP_JWT_*`/`APP_DATABASE_URL_FILE` env。
- rust 一律容器內跑；改 `.rs` 先 force-touch；rust serial。

## 驗證流程（7 步）

1. **time-pin 判定 ＋ 建置綠**（C-V-0）：加 `jsonwebtoken` 後**先** `cargo tree -i time`（real→pin time 0.3.37＋simple_asn1 0.6.3）；再 `cargo build -p server` 綀（config/state/auth/handler/facade 編譯）。

2. **純函式測**（C-V-1）：`cargo test -p server auth` → JWT roundtrip/過期/壞簽 reject、argon2id verify、claims serde、**Casbin enforce seam**（R_SUPER allow / R_USER_COMMON deny `/systemManage/deleteUser` DELETE＝5003 證面）。

3. **live curl 主鏈**（C-V-2）：stack healthy 後——
   - login `Super`/`123456` → 200 `{token,refreshToken}`；
   - getUserInfo（bearer）→ `{userId(string), userName, roles[R_SUPER], buttons[非空]}`；login `User` → userName==`User01`；
   - 1000（壞密碼／不存在帳號**不可區分**）；3333（缺/壞 token）；7777（同帳號二次 login、舊 token 被踢、新 token 正常）；
   - psql 驗 `sys_token` 寫入＋`sys_user.current_session_id` 更新（原子）。

4. **CDP i18n**（C-V-3、§3.6）：base-web 瀏覽器登入輸錯密碼 → toast 顯示在地化「用户名或密码错误」（非 raw key `auth.login.failed`）——驗 003 i18n 接線端到端。

5. **lint 守恆**（C-V-4）：`cargo test -p server --test entity_access_lint` → auth/handler/config/state 零 path-root `entity::`、續綠。

6. **prod image build**（C-V-5、★加 dep 紀律）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` → prod multi-stage 含新 dep 編譯綠、time-pin 不撞 1.86。

7. **零回歸＋範圍核**（C-V-6）：`curl /health` 回 `ok`；diff 確認零 migration/entity/base-web/i18n/compose/secret 變動。

## 預期結果（對應 SC）

| 步 | 對應 SC | 通過 |
|---|---|---|
| 1 | SC-007 | server 編譯綠、time-pin 不撞 |
| 2 | SC-003（5003 seam）／SC-001 純測面 | JWT/argon2/enforce 純函式綠 |
| 3 | SC-001/002/004/008 | login/getUserInfo/7777/atomic 寫入 |
| 4 | SC-006 | i18n 端到端 toast 在地化 |
| 5 | FR-007 facade 守恆 | lint 續綠 |
| 6 | SC-007（加 dep prod 驗） | prod image 編譯綠 |
| 7 | SC-007/SC-009 | /health 零回歸、範圍邊界守住 |

> SC-005（DB-fresh role 授權）由設計審查＋（改 DB 角色即時生效）證；SC-009（零 refresh 端點/menu/事件審計/多會話設定/lockout）由 diff／設計審查核。

## 不在本刀（各歸其刀）
- 波3：`/auth/refreshToken`＋rotation/reuse＋cleanup-job＋session 三態/熱切換＋Redis。
- 波2：getUserRoutes＋動態選單＋menu enforce＋route mode flip。
- 007：login 事件審計＋audit_ctx＋xdb；⚠️w lockout／⚠️m alt-login。
