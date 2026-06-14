# C-V Contract: verification-commands（006-auth-island-min）

> 驗收＝容器 `cargo build`（+jsonwebtoken/argon2/casbin/sea-orm-adapter）＋純 `cargo test`（jwt/bearer/argon2/enforce-decision，**零 DB/HTTP**）＋bounded **全棧 curl** 实机 smoke（login→getUserInfo→enforce-proof→refresh）＋**CDP browser smoke**（base-web 攔截器解析 envelope）＋殘留 grep＋/health 不退化。
> **非新 crate**（server 內加模組＋既有 sea-orm-adapter path dep）⇒ 無強制獨立 prod image build；但 server 首次依賴 sea-orm-adapter（path），**建議跑一次 prod target build 確認 COPY 無缺**（rev2 COPY-gap 教訓、C-V-3）。host 無 cargo → rust:1.86 容器；warm cargo cache 重用、target 卷 cv006-target。

容器形（純測共用）：
```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv006-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'
```

## C-V-1 · 建置驗（+deps／MSRV）

```bash
eval $RUN cargo build --bins      # 首次非 --offline（補 jsonwebtoken+ring 鏈 lock）；之後可 --offline
# 期：server +jsonwebtoken 9/argon2/casbin/sea-orm-adapter 編譯綠
grep -nE 'jsonwebtoken' rust-api/Cargo.toml rust-api/server/Cargo.toml   # 期 workspace+server 皆含
grep -c 'name = "jsonwebtoken"' rust-api/Cargo.lock                      # 期 ≥1（新增）
grep -c 'name = "ring"' rust-api/Cargo.lock                              # 期 ≥1（jsonwebtoken 9 依賴）
# MSRV（§3.8）：jsonwebtoken 9(~1.63)/ring 0.17(1.61) ≤ 1.86 → 1.86 編得過即證；若編譯報 MSRV error → cargo update -p <crate> --precise <1.86-safe>
# fail → deps 漏加／MSRV 超界（回查 R5）
```

## C-V-2 · 純單元測試（test-first；零 DB/HTTP、不含 #[ignore]）

```bash
eval $RUN cargo test -p server --offline
# 期全綠，涵蓋（contracts/auth-contract.md §1-4）：
#  jwt：sign→verify roundtrip／竄改 reject／過期 reject(leeway=0)／aud 不符 reject
#  bearer：Bearer 抽取／無前綴·空·小寫→None／trim
#  argon2：hash→verify true／錯密碼 false／壞 phc false（roundtrip 自含、不依賴 seed 字串）
#  enforce decision：(role,path,method) 三欄精確 allow/deny
#  ＋既有 003 envelope/error 測＋004 lint(22)/facade 測仍綠
# 註：#[ignore] live smoke＋CDP 不在此跑
```

## C-V-3 · prod target build（非強制、建議；server 首次依賴 sea-orm-adapter path）

```bash
# server 新增 sea-orm-adapter path dep ⇒ 確認 prod multi-stage Dockerfile 的 sea-orm-adapter COPY 涵蓋 server 的依賴（rev2 COPY-gap 教訓、CLAUDE.md §3）
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 期綠；fail → prod Dockerfile 缺 sea-orm-adapter／jsonwebtoken 編譯問題（dev bind-mount 會遮、故此處顯式驗）
```

## C-V-4 · bounded 全棧 实机 smoke（curl 經 /api；postgres+migrate seed）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait     # 全棧（front-nginx+base-web+rust-api+postgres+migrate）
# 解析網路名（★ rev3-admin_rev3_net、非 stale _default）
NET=$(docker network ls --format '{{.Name}}' | grep rev3 | head -1)
# login（Super/123456、runtime argon2 hash）
curl -fsS -X POST http://127.0.0.1:31080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"Super","password":"123456"}'        # 期 code:"0000"＋data.token/refreshToken
# 失敗一致（帳號枚舉防護）
curl -s -X POST http://127.0.0.1:31080/api/auth/login -d '{"userName":"Super","password":"wrong"}'   # 期 code:"1000"
curl -s -X POST http://127.0.0.1:31080/api/auth/login -d '{"userName":"NoSuch","password":"123456"}' # 期 code:"1000"（與上不可區分）
# getUserInfo
TOKEN=...; curl -fsS http://127.0.0.1:31080/api/auth/getUserInfo -H "Authorization: Bearer $TOKEN"
  # 期 code:"0000"＋data.userId(string)/userName/roles(含 R_SUPER)/buttons([])
# refresh（壞 refresh→8888 非 3333、反迴圈）
curl -s -X POST http://127.0.0.1:31080/api/auth/refreshToken -d '{"refreshToken":"bad"}'   # 期 code:"8888"
# enforce-proof（注入拋棄式 policy 後）：Super→200／無 policy role→403/5003／bad token→3333；測後清 policy
# 期（contracts/auth-contract.md §6）全綠
# fail → 對 R1/R2 校 handler/enforce 形
```

## C-V-5 · CDP browser smoke（§3.6 directed；base-web 真打 rust-api）

```bash
# base-web 指向真 rust-api（改 .env VITE_SERVICE_BASE_URL/proxy 或 smoke compose env、BASE-WEB-ADAPT 軌）；VITE_AUTH_ROUTE_MODE=static
# CDP ws://127.0.0.1:9229（注意 origin localhost≠127.0.0.1）；沿用 tests/000 scripts 形
node tests/000-base-web-docker-bootstrap/scripts/cdp-login.mjs   # 或 006 專用 login smoke 變體
# 期（contracts/auth-contract.md §7）：pwd-login submit → 攔截器讀 /auth/login envelope code:"0000" → 存 token →
#   /auth/getUserInfo envelope 解析 → userInfo 填；驗到此止（static 不呼 getUserRoutes、route-mount 延波 2）
# 目標：證 base-web 攔截器對真 rust-api envelope 的 code/data/msg 判讀正確（curl 直送 ≠ base-web 判讀）
```

## C-V-6 · 殘留 grep（部署層零 rev2／auth 新寫零 rev2 token）

```bash
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌" || echo "✅"
grep -rinE "rev2|21079|21080|21081" rust-api/server/src/auth/ rust-api/server/src/handler/auth.rs rust-api/server/src/state.rs 2>/dev/null && echo "❌" || echo "✅"
# JWT_ISS/JWT_AUD 應為 "rev3-admin"（非 rev2-admin）：
grep -rnE 'rev2-admin' rust-api/server/src/auth/ && echo "❌ 殘 rev2-admin" || echo "✅ rev3-admin"
# 期 ✅ ✅ ✅；清理拋棄式卷：docker volume rm cv006-target；docker compose ... down
```

## C-V-7 · /health 不退化（universal 例外、靜態）

```bash
grep -nE 'async fn health|"ok"' rust-api/server/src/main.rs    # 期：health 簽名與 "ok" 不變（main.rs router 重寫但 /health 保留）
```

## 驗收不變式總表
- C-V-1：+jsonwebtoken/argon2/casbin/sea-orm-adapter 編譯綠；MSRV ≤ 1.86（jsonwebtoken+ring 鏈）。
- C-V-2：jwt/bearer/argon2/enforce-decision 純測綠；003/004 既有測續綠。
- C-V-3：prod target build 綠（server 新 sea-orm-adapter path dep 的 COPY 無缺）。
- C-V-4：全棧 curl login(0000)/失敗一致(1000)/getUserInfo(0000,userId string)/refresh 壞→8888/enforce-proof 200·403·3333。
- C-V-5：CDP base-web 攔截器解析真 rust-api envelope（login→getUserInfo、static 止）。
- C-V-6：部署層＋auth 新寫零 rev2 token、JWT_ISS/AUD＝rev3-admin。
- C-V-7：`/health` "ok" 不變（main.rs 重寫不退化、SC-007）。
