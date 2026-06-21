# Quickstart 驗證指南：XFF → real_ip 鑑識

> 端到端驗證本功能可運作。精確命令見 [contracts/verification-commands.md](./contracts/verification-commands.md)；schema/型見 [data-model.md](./data-model.md)。

## 前置
- dev stack 起：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`
- 預設帳號 `Super/123456`（審計中心 Super-only）。

## 1. 設定信任拓樸（TrustModel TOML）
放 `deploy/trust-model.toml`、由 `TRUST_MODEL_FILE` env 指向、bind-mount 進 rust-api 容器（缺檔 → fallback flat `TRUSTED_PROXY_CIDRS` → all-direct）：

```toml
[[cdn]]                                    # Tier-1 位置錨；宣告該 CDN 權威 header
networks = ["162.158.0.0/15", "104.16.0.0/13"]   # Cloudflare 邊緣段（operator 自填官方 list）
connecting_ip_header = "CF-Connecting-IP"

[[my_public]]                              # 我方反代 public 出口
networks = ["198.51.100.7"]
dual_role = true                           # 此 IP 也可能當直連 client → Tier-2 走過降 PROXY_SOFT

[[my_public]]
networks = ["198.51.100.8"]
dual_role = false

internal_default = ["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","127.0.0.0/8","::1","fc00::/7"]

[[bindings]]                               # 特例：某 public 專屬內網
public = "198.51.100.8"
internal = ["10.0.0.0/24"]
dual_role = false
```

nginx CF 閘（regular + tunnel 都認）：`geo $remote_addr $x_cf_verified { default 0; 162.158.0.0/15 1; 127.0.0.1/32 1; ... }` + 轉發 `CF-Connecting-IP`/`X-CF-Verified`（見 data-model / research-doc §13.3）。

## 2. 驗證解析正確（US1、SC-001/002）
以代表性轉發鏈發請求（curl 帶 `X-Forwarded-For`，dev 直連 `:31081`；或經 nginx `:31080`），psql 看寫入的 `real_ip` + `ip_confidence`：

| 情境 | XFF / header | 期望 real_ip / confidence |
|---|---|---|
| 標準 CF | `203.0.113.9, 162.158.108.56` + X-CF-Verified:1 + CF-Connecting-IP:203.0.113.9 | `203.0.113.9` / `cdn_verified` |
| 注入假 IP 左段 | `1.2.3.4, 203.0.113.9, 162.158.108.56` | `203.0.113.9`（忽略 1.2.3.4） |
| IIS 格式 | `115.164.87.108,+162.158.108.56:13814` | `115.164.87.108` / `cdn_anchored` |
| Tunnel | `203.0.113.9, 127.0.0.1` + X-CF-Verified:1 | `203.0.113.9` / `cdn_verified` |
| 整鏈受信 | `198.51.100.8, 10.0.0.5` | peer / `fallback` |

```bash
psql "$DATABASE_URL" -c "SELECT real_ip, peer_ip, ip_confidence, x_forwarded_for FROM sys_access_log ORDER BY created_at DESC LIMIT 5;"
```

## 3. 驗證審計中心（US2/US3、SC-004）
CDP 經 `:31080` 開審計中心三分頁：
- 每列依序見 `ip_confidence`(NTag 著色) / `peer_ip` / `real_ip` / `x_forwarded_for`。
- 三模糊篩（任一 IP 欄輸入子字串）+ `ip_confidence` 下拉篩（選 `cdn_mismatch`/`fallback` 複查低可信）→ 結果正確。

## 4. 驗證 migration 可逆（SC-006）
```bash
$DC exec -T rust-api sh -c 'cd /app && cargo run -p migration -- up && cargo run -p migration -- down -n 1 && cargo run -p migration -- up'
```
欄名/欄數還原無殘留。

## 5. 零回歸（SC-007）
`/health` ok；既有 nginx header 不變；007 audit live path / 012 既有審計查詢行為不變。

> 完整 acceptance（含 prod build、純測矩陣、12 案例）走 contracts/verification-commands.md 的 C-V-0~9。
