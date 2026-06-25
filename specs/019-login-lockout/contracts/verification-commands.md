# C-V 驗收契約：019-login-lockout

> 階段 2 acceptance gate。rust 容器內 `docker exec`、**全程 serial**、live `--test-threads=1`。dev stack：`docker compose -f docker-compose.yml -f docker-compose.dev.yml`（下稱 `$DC`）。psql 走 postgres 容器（rust-api 無 psql）。取 Super token 見 `tests/000-base-web-docker-bootstrap`。**0 新 crate／0 migration／0 新 route**。
>
> **★ 測試隔離（必守、防污染共用 dev DB／鎖到下游 serial live smoke）**：
> - per-user live 測一律用**拋棄式 `attempted_user_name`**（如 `lockout_probe_<rand>`）、**絕不用 seed Super/Admin/User**（否則把 seed 帳號鎖 15 分、後續別 feature live smoke 連不上）。
> - per-ip live 測（≥20 次跨帳號）會把**該測試 IP** 對**所有帳號**鎖 15 分 → live `#[ignore]` smoke 必用**短窗 const override**（test-only 小窗值）使其快速自解、或排最後並註明窗等待。
> - 滑動窗恢復一律純函式 + 短窗 override 測（**不 live 等 15 分**）。

## C-V-0 — 容器內 build（防 /mnt/d stale-mtime 假綠；無新 crate）
```bash
$DC exec -T rust-api sh -c 'cd /app && find server/src entity/src -name "*.rs" -exec touch {} + && cargo build -p server'
# 0 新 workspace crate；count 方法 + gate 編得過
```

## C-V-1 — 純函式測（decision seam `is_locked_out`、test-first）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server is_locked_out -- --nocapture'
```
覆蓋：門檻邊界（per-user 剛好 5/低於 4/高於 6、per-ip 剛好 20/低於/高於）、**OR 語意**（per-ip 觸發但 per-user 未達／反之／both 達）、both 皆 0 未鎖。**警覺「0 passed / N filtered out」＝filter 沒命中、不是綠**（CLAUDE.md §8.2）。

## C-V-2 — lint（兩支綠、無新 route、count 走 facade）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint --test endpoint_coverage_lint'
```
`entity_access_lint`：新 count 方法走 **facade**（`sys_login_attempt` 內）、handler 零 path-root `entity::sys_login_attempt`。`endpoint_coverage_lint`：`/auth/login` 既在、**無新 route**、registered==as-built 不變。

## C-V-3 — live per-user 鎖（curl + psql；拋棄式帳號）
```bash
U="lockout_probe_$RANDOM"
# 連送 5 次失敗（不存在帳號亦寫失敗列＝防枚舉 FR-015）
for i in $(seq 1 5); do
  curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"$U\",\"password\":\"wrong\"}"
done   # 前 5 次 → code 1000（LoginFailed）
# 第 6 次（即使帶任意密碼）→ code 2222、msg="auth.login.locked"（FR-001/009）
curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"$U\",\"password\":\"whatever\"}"
# 另一拋棄式帳號不受影響（per-user 隔離 SC-001）
curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"lockout_other_$RANDOM\",\"password\":\"wrong\"}"   # → 1000（非 2222）
# psql 驗：該 user 有 ≥6 列 success=false（含第 6 次 gated 列、operator_id NULL、ctx 四欄照填 FR-008）
psql ... -c "SELECT success, operator_id, real_ip, ip_confidence, trace_id FROM sys_login_attempt WHERE attempted_user_name='$U' ORDER BY id;"
```

## C-V-4 — live per-ip 鎖（短窗 override、跨多帳號）
```bash
# ★ 用 test-only 短窗 const（或 in-crate #[ignore] live、見 C-V-6）跑、避免把測試 IP 對所有帳號鎖 15 分。
# 自同一來源對 ≥20 個不同拋棄式帳號各送 1 次失敗（各未達 per-user 5、純測 per-ip）：
for i in $(seq 1 20); do
  curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"ipprobe_${i}_$RANDOM\",\"password\":\"wrong\"}"
done
# 第 21 次（任一新帳號）→ code 2222（per-ip 鎖 FR-002/SC-002）
curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"ipprobe_21_$RANDOM\",\"password\":\"wrong\"}"
```
> per-ip 門檻 20 刻意高（免鎖 NAT/共用 IP）；dev 直連 :31081 的 real_ip 解析見 013（host→容器 peer）。

## C-V-5 — EXPLAIN 驗索引使用（per-ip / per-user count 走複合索引）
```bash
psql ... -c "EXPLAIN SELECT count(*) FROM sys_login_attempt WHERE real_ip='203.0.113.9' AND success=false AND created_at >= now()-interval '900 seconds';"
#   → 預期 Index/Bitmap scan on idx_login_attempt_ip_time（非 Seq Scan）
psql ... -c "EXPLAIN SELECT count(*) FROM sys_login_attempt WHERE attempted_user_name='probe' AND success=false AND created_at >= now()-interval '900 seconds';"
#   → 預期 Index/Bitmap scan on idx_login_attempt_user_time
```
> 註：rust 端 count 的 since 走 app `Utc::now()-900s`（D-03）；此處 EXPLAIN 用 PG `now()-interval` 僅驗**索引選用**等價、非比對時鐘來源。

## C-V-6 — in-crate #[ignore] live smoke（count 方法 + gate + 滑動窗恢復；DB-gated、短窗 override）
```bash
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$(cat $APP_DATABASE_URL_FILE) cargo test -p server --lib lockout_live -- --ignored --test-threads=1 --nocapture'
```
- `server` 為 bin-only crate（無 lib.rs 對外 API）→ 需呼叫 facade count 的測試放 **in-crate `#[cfg(test)] + #[ignore]` + env-gate**（預設 `cargo test` 跳過、無 DB 仍綠；CLAUDE.md §8.2）。
- 覆蓋：count_failed_by_{ip,user}_since 回真數（含 gated 列 sticky FR-008）；**滑動窗恢復**＝寫舊失敗列（`created_at` 設窗外）→ count 不計→ 未鎖（FR-006、用短窗 const 或直接控 created_at、不等 15 分）；**IpAddr→IpNetwork 轉換一致**（D-04：count.eq 命中寫端列）。
- `--test-threads=1` 必加（共用 `sys_login_attempt`、非 parallel-safe；多緒 `--ignored` 會偽失敗）。

## C-V-7 — CDP browser smoke（鎖中 toast 在地化；curl≠modal）
經 `:31080` CDP（登入注入見 `tests/000`）：
- 對拋棄式帳號連續失敗達門檻 → login form 顯示**在地化 toast**「登入失敗次數過多，請稍後再試」（zh-cn）／「Too many failed login attempts...」（en-us 切語系驗）。
- 驗 2222+`msg=auth.login.locked` 經 `translateBackendMsg`→`$t("backend.auth.login.locked")` 自動成 toast（**免改 login form**、R3/D-05）；vite 熱載新 locale key 後該 toast 才在地化（curl 直送看不到此在地化、必走 CDP）。

## C-V-8 — prod target image build（§3 紀律保險；無新 crate、惟 rust 動 build）
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 0 新 workspace crate ⇒ 不觸「新 crate⇒四處 COPY」；此步防 dev bind-mount 遮蓋 prod multi-stage 編譯破口（§3 Phase 1 紀律）
```

## C-V-9 — 零回歸
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server -- --test-threads=1'   # 既有 unit 全綠（login 6 路徑、decide_rotation 等）
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'                              # backend.auth.login.locked Schema 對齊（先 Schema 後 locale）
curl -fsS :31080/health                                                            # 200
# 正確登入零回歸：Super/Admin/User 正常密碼 login → 0000（未達門檻、gate 放行；★ 別在 per-ip 測污染的 IP 上跑、或先等窗滑出）
curl -s :31081/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}'   # → 0000
```

## 通過標準
C-V-0~9 全綠 + final holistic review（fresh-agent 冷讀）無 blocker：3 US（per-user P1／per-ip P2／合法者保護 P3）、15 FR、7 SC 全覆蓋；13 碼矩陣不變（2222 既有、不破 ⚠️f）；既有 login 6 路徑/best-effort 寫不破；entity_access_lint/endpoint_coverage_lint 綠。
