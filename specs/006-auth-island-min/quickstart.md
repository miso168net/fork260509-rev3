# Quickstart: 006-auth-island-min 驗證指南

> 從零到「jwt/bearer/argon2/enforce 純測綠＋全棧 curl（login→getUserInfo→enforce-proof→refresh）綠＋CDP browser smoke（base-web 攔截器解析真 rust-api envelope）綠」；完整命令見 [contracts/verification-commands.md](contracts/verification-commands.md)（C-V-1~7）、契約見 [contracts/auth-contract.md](contracts/auth-contract.md)。

## 前置需求

- rust-api worktree 可建（host 無 cargo → rust:1.86 容器；warm cargo cache、target 卷 cv006-target）。
- server 內加模組（`auth/`＋`handler/`＋`state.rs`、改 `main.rs`/`error.rs`）；deps +`jsonwebtoken 9`（新）＋`argon2`/`casbin`/`sea-orm-adapter`（既有 workspace/path）；**無 migration、無新 crate**。
- 全棧 smoke 需 front-nginx+base-web+rust-api+postgres+migrate（m002 seed user `Super`/`123456`＋casbin policy）。
- CDP smoke 需 base-web 指向真 rust-api（改 `.env`/proxy、BASE-WEB-ADAPT 軌）＋CDP `:9229`。
- JWT secret：`deploy/secrets/jwt_secret.txt`＋`refresh_token_secret.txt`（001 已備、`_FILE` 讀）。

## 驗證主線（依序）

```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv006-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'

# 1. 建置（+jsonwebtoken/argon2/casbin/sea-orm-adapter；首次非 --offline 補 lock）   …C-V-1
eval $RUN cargo build --bins
grep -nE 'jsonwebtoken' rust-api/server/Cargo.toml          # 期含

# 2. 純單元測試（jwt/bearer/argon2/enforce-decision、零 DB/HTTP）                  …C-V-2
eval $RUN cargo test -p server --offline

# 3.（建議）prod target build（server 新 sea-orm-adapter path dep 的 COPY 驗）       …C-V-3
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api

# 4. 全棧 实机 smoke（curl 經 /api）                                               …C-V-4
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
curl -fsS -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}'
#  → code:"0000"＋token/refreshToken；getUserInfo(Bearer)→userId(string)/roles/buttons；refresh 壞→8888；enforce-proof 200/403/3333

# 5. CDP browser smoke（base-web 真打 rust-api、攔截器解析 envelope）                …C-V-5
node tests/000-base-web-docker-bootstrap/scripts/cdp-login.mjs    # 或 006 變體

# 6. 殘留 grep（部署層＋auth 新寫零 rev2、JWT_ISS/AUD=rev3-admin）                  …C-V-6
grep -rnE 'rev2-admin' rust-api/server/src/auth/ && echo "❌" || echo "✅"
```

期望：純測全綠（jwt roundtrip/竄改/過期/aud reject、bearer 抽取、argon2 roundtrip、enforce 三欄判定）＋全棧 curl（login 0000／失敗一致 1000／getUserInfo userId-string／refresh 壞→8888／enforce-proof 200·403·3333）＋CDP（base-web 攔截器對真 rust-api envelope 判讀正確、login→getUserInfo、static 止）＋grep ✅。

## test-first TDD 紀律

純函式（jwt/bearer/argon2/enforce-decision）**先寫測（red）再實作（green）**——red 對 R1/R2/R3 rev2/wire 參照形校形、**不調測試遷就實作**。handler 行為（envelope codes、refresh 反迴圈 8888、userId string 2^53）＋enforce-proof（Super/無 policy/bad token）＋wire 對齊由 §6 全棧 curl＋§7 CDP 證（compile 證不了的 runtime 對齊核心）。

## ⚠️ 關鍵注意

- **refresh 反迴圈鐵律**：`/auth/refreshToken` 失敗回 **8888**（非 3333/9999/9998）——否則 base-web 攔截器 refresh 死循環（R2、官方 docs 紀律）。
- **userId string + 2^53 守衛**（⚠️r）：`user.id`(i64)→string、超 2^53 fail-loud（不靜默截斷）。
- **enforce DB-error fail-closed 5003**（DESIGN line 686）：role-lookup DbErr→deny(5003)＋log（非放行、非 internal）；spec FR-005「可區分」讀為 log 層（見 research R6、留 analyze）。
- **stateless 剝離**：無 sys_token/session/redis/single-session；Claims 無 sid/jti；refresh 無 reuse 偵測——全波 3。
- **CDP static 模式**：`VITE_AUTH_ROUTE_MODE=static`→不呼 getUserRoutes→CDP 驗到 getUserInfo 天然完整；route-mount 延波 2 Menu。

## 收尾

```bash
docker volume rm cv006-target 2>/dev/null
docker compose -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null
```
