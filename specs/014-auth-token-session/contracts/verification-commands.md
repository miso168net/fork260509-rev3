# C-V 驗收契約：Auth/Token/Session 合刀

> 階段 2 acceptance gate。rust 容器內 `docker exec`、全程 serial、live `--test-threads=1`。dev stack：`docker compose -f docker-compose.yml -f docker-compose.dev.yml`（下稱 `$DC`）。取 Super token 見 `tests/000-base-web-docker-bootstrap`。psql 走 postgres 容器（rust-api 無 psql）；redis-cli 走 redis-stack 容器或 `$DC exec redis-stack redis-cli`。

## C-V-0 — 容器內 build（含新 Redis crate + cleanup-job crate、防假綠）
```bash
$DC exec -T rust-api sh -c 'cd /app && find . -name "*.rs" -exec touch {} + && cargo build -p server && cargo build -p cleanup-job'
# 新 Redis crate subtree 須 1.86 編過（Cargo.lock 釘版、沿 toml/time MSRV）；cleanup-job 新 crate 編得過
```

## C-V-1 — 純函式測（decision seam）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server decide_rotation resolve_policy -- --nocapture'
```
覆蓋：`decide_rotation` 四分支（active→Rotate／used&<grace→Benign／used≥grace·revoked·used_at=NULL→Reuse／notfound、grace 邊界、fail-closed）；`resolve_policy` 三態 × 全域 on/off。**警覺「0 passed / N filtered out」＝沒命中。**

## C-V-2 — lint（兩支綠 + 新端點納入 coverage）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint --test endpoint_coverage_lint'
```
`endpoint_coverage_lint`：新 `/auth/refreshToken`（public、內部驗 refresh、非 enforce_mw 後）納入分類、registered==as-built（`[&str;N]` bump）。`entity_access_lint`：sys_token/sys_user 寫走 facade、零 path-root `entity::`。

## C-V-3 — live token rotation（curl + psql + redis）
```bash
# 1) login 取 access+refresh；2) 以 refresh 打 /auth/refreshToken
curl -s .../auth/refreshToken -H 'Content-Type: application/json' -d '{"refreshToken":"<R1>"}'   # → 新 pair（Rotate）
# 同一 R1 立刻再送（grace 內）→ 仍發新對（Benign、不撤）
# 隔 >30s 或對已輪替的舊 R1 再送 → code 8888（Reuse）、psql 證該 rotation_chain 整鏈 status='revoked'
psql ... -c "SELECT rotation_chain, status, used_at FROM sys_token WHERE user_id=<uid> ORDER BY id DESC LIMIT 5;"
# refresh JWT 驗章失敗（亂改）→ 8888；handler 絕不回 3333/9999/9998
```

## C-V-4 — live single-session（resolve_policy 生效、7777）
```bash
# 全域 single_session_default='on'（008 update）→ 同帳號 B 裝置 login → A 的 access token 下個請求 → 7777
# 全域 'off' → A、B 並存（getUserInfo 皆 200、不踢）
# per-user：updateUser 設某 user session_policy='on'（全域 off 時）→ 該 user 仍單一登入
psql ... -c "SELECT id, session_policy, current_session_id FROM sys_user WHERE id=<uid>;"
```

## C-V-5 — live 硬即時撤銷（denylist、8888）
```bash
# user 持有效 access token → updateUser(status=2 停用) 或 deleteUser → 該 token 下個請求立即 8888（不分 policy、不等過期）
redis-cli GET "revoked:user:<uid>"   # 存在、值=revoked_at
# re-enable（status=1）→ 新 login 的 token 正常通關（iat>revoked_at）
# Redis 不可達模擬（停 redis-stack）→ denylist 查 fail-OPEN（不誤鎖全站、既有 token 仍通至過期）
```

## C-V-6 — ★ 多實例 2-instance（C1 驗證版、跨進程收斂 + watcher 韌性）
```bash
$DC --profile multi up -d rust-api-2 --wait   # 第二 instance :31082、共享 DB+Redis
# A(:31081) 切 single_session_default='on' → B(:31082) 後續請求以 on 施行（watcher 收斂、settings:invalidate）
# A login → B 讀 shared pointer（DB+Redis sess）→ 踢舊會話（7777）
# A 停用某 user → B 查 denylist 一致拒（8888）
$DC exec -T redis-stack redis-cli CLIENT KILL TYPE pubsub   # 模擬 watcher 斷線
# → 等重訂閱後、再切 single_session_default → B 仍收斂（watcher 重訂閱韌性）
$DC --profile multi down rust-api-2   # 收尾（dev 預設仍 1 instance）
```

## C-V-7 — cleanup-job（dry-run / --execute / 冪等）
```bash
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo run -p cleanup-job'              # dry-run 只 count、不刪
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo run -p cleanup-job -- --execute' # 刪 expires_at<now-60s
# 立刻再跑 --execute → 冪等（刪 0 列）；psql 證未過期 token 原封
```

## C-V-8 — CDP 兩通道 + per-user UI
經 `:31080` CDP（登入注入見 tests/000）：
- **7777**（他處登入）→ modal 提示後乾淨登出導回 /login；**8888**（reuse/停用）→ 直接登出導回 /login（無白屏、無 refresh 迴圈）。
- 009 編輯 user → `session_policy` NSelect（inherit/on/off）改值 → updateUser 真打、psql 證 `sys_user.session_policy` 改。

## C-V-9 — ★ prod target image build（新 cleanup-job crate + Redis crate）
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# ★ 新 workspace crate cleanup-job ⇒ prod Dockerfile 須補 COPY（Manifest 段 cleanup-job/Cargo.toml + Source 段 cleanup-job/src）；
#   builder --bins 須含 cleanup-job binary；新 Redis crate subtree --locked 編入。dev bind-mount 遮 COPY 缺口、此步才暴露（§3 Phase 1 紀律）。
```

## C-V-10 — 零回歸
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server -- --test-threads=1'         # 既有 130+ unit 全綠
$DC exec -T rust-api sh -c 'cd /app && cargo run -p migration -- up && ... down -n 1 && ... up'  # 無新 migration、仍可逆
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'                                    # session_policy typing 對齊
curl -fsS :31080/health   # 200；006 login/getUserInfo/enforce、009 CRUD、008 設定、013 audit 既有行為不破
```

## 通過標準
C-V-0~10 全綠 + final holistic review（fresh-agent 冷讀）無 blocker（5 US / 14 FR / 10 SC 全覆蓋、§I.7 §4.1+§4.3 invariants 逐條有自動化驗證〔§8.8 DoD〕、cross-unit 接縫一致）。
