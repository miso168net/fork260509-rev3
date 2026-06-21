# C-V 驗收契約：XFF → real_ip 鑑識

> 階段 2 實作的 acceptance gate。命令一律**容器內** `docker exec`（host 無 rust toolchain）、**rust 全程 serial**、live `--test-threads=1`。dev stack：`docker compose -f docker-compose.yml -f docker-compose.dev.yml`（下稱 `$DC`）。

## C-V-0 — 容器內 build（含新 toml dep、防假綠）
```bash
$DC exec -T rust-api sh -c 'cd /app && find server/src entity/src migration/src -name "*.rs" -exec touch {} + && cargo build -p server'
# 新 toml(0.8 parse-only) subtree(winnow/serde_spanned/toml_datetime) 須 1.86 編得過；Cargo.lock 釘版
```

## C-V-1 — 純函式測（解析核心）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server normalize_ resolve_ apply_cf_overlay -- --nocapture'
```
覆蓋：`normalize_xff_tokens`（`+`/空白/逗號混切、剝 v4 `:port`/v6 `%zone`/`[..]:port`、garbage drop、空輸入）；`resolve` 四分支重映射 8 個既有測到 `(IpAddr,Confidence)` + 補 CDN-anchored/Tier-2/dual_role-soft/Tunnel/Fallback；`apply_cf_overlay`（verified×cip×base 矩陣）。**警覺「0 passed / N filtered out」＝filter 沒命中、不是綠。**

## C-V-2 — 12 解析案例轉測（research §4）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server resolve_cases -- --nocapture'
```
research-doc §4 的 12 案例（直連/CF/多層反代/注入/直連繞過/無CDN多跳/連續my-public/binding軟評分/dual_role盲區/IIS/Tunnel/fallback）逐案斷言 `(real_ip, confidence)`。

## C-V-3 — lint（既有兩支綠）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server --test entity_access_lint --test endpoint_coverage_lint'
```
`entity_access_lint`：handler/main 零 path-root `entity::`（IP 欄存取走 facade）。`endpoint_coverage_lint`：013 不加 endpoint/policy → 維持綠（不退化）。

## C-V-4 — migration 可逆 + fresh DB 全鏈
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo run -p migration -- up && cargo run -p migration -- down -n 1 && cargo run -p migration -- up'
# 驗 m006 up→down→up：欄名/欄數還原無殘留；fresh DB 跑 m001..m006 無誤
psql "$DATABASE_URL" -c '\d sys_access_log' -c '\d sys_operation_log'   # 確認欄名（real_ip/peer_ip/ip_confidence；operator_*）
```

## C-V-5 — live smoke：三表四欄真寫入（psql、非只看 HTTP 200）
```bash
$DC exec -T rust-api sh -c 'cd /app && DATABASE_URL=$DATABASE_URL cargo test -p server --lib audit_live -- --ignored --test-threads=1'
# 經真 server 發請求後 psql 驗：
psql "$DATABASE_URL" -c "SELECT real_ip, peer_ip, ip_confidence FROM sys_access_log ORDER BY created_at DESC LIMIT 3;"
psql "$DATABASE_URL" -c "SELECT operator_real_ip, operator_peer_ip, operator_ip_confidence FROM sys_operation_log ORDER BY created_at DESC LIMIT 3;"
# best-effort warn-drop：不能只看 HTTP 200；append-only 用 trace_id/delta 隔離、勿斷言絕對列數
# ip_host_like 改名後對 real_ip/peer_ip 的 host() 斷言須同改
```

## C-V-6 — CDP 012 審計中心（四欄顯示順序 + 篩選）
經 `:31080` 真發 request（CDP 9229；登入注入見 `tests/000-base-web-docker-bootstrap`）：
- 三分頁每列依序顯示 `ip_confidence`(NTag 著色) → `peer_ip` → `real_ip` → `x_forwarded_for`（operation 分頁 `operator_*`）。
- 三模糊篩（`real_ip`/`peer_ip`/`x_forwarded_for` 輸入子字串 → 只回含該子字串列）+ `ip_confidence` 下拉篩（選某態 → 只回該態列）皆運作。
- **curl 帶空 param 模擬前端**抓 list filter 空字串守門回歸（未填欄略過、不誤篩 0 列）。

## C-V-7 — curl wire（honest null）
```bash
curl -s ".../getAccessLog?current=1&size=5" -H "Authorization: Bearer $SUPER" | jq '.data.records[0] | {realIp, peerIp, ipConfidence, xForwardedFor}'
# 新欄出現（nullable 顯 null、非 skip）；ipConfidence ∈ 7 literal
```

## C-V-8 — prod target image build（新 workspace dep 紀律）
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 驗 multi-stage 逐 crate COPY 無缺口（新 toml dep 編入 prod runtime）
```

## C-V-9 — nginx geo 閘語法 + 零回歸
```bash
$DC exec -T front-nginx nginx -t                # geo/map 語法
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --force-recreate front-nginx   # 非 restart
curl -fsS http://127.0.0.1:31080/health         # /health ok
# 既有 X-Real-IP/X-Forwarded-For/X-Forwarded-Proto/X-Request-Id 不 regress；007 audit live path / 012 既有行為零回歸
```

## 通過標準
C-V-0~9 全綠 + final holistic review（fresh-agent 冷讀）無 blocker（5 US / 10 FR / 7 SC 全覆蓋、cross-unit 接縫一致）。
