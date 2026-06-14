# TRUSTED_PROXY_CIDRS 填寫指引（真實 client IP 解析）

> 007-audit-overlay。`rust-api` 由 `X-Forwarded-For` 解析「真實終端 client IP」寫入審計（access-log / login-attempt / op-log）。
> 解析只信任 **`TRUSTED_PROXY_CIDRS` 內列出的代理 hop**；集合外（不可信）來源的 forwarded 一律不採信（防偽造）。

## 語意（對應 FR-006/007）

- 值＝逗號分隔的 CIDR 清單（IPv4／IPv6 皆可；裸 IP 視為 `/32`、`/128`）。
- 解析邏輯（`server/src/state.rs::resolve_client_ip`）：
  1. 直連 peer ∉ 可信集合 → 直接採 peer（不信任何 XFF；擋偽造、亦為 dev/空集合預設）。
  2. peer ∈ 可信集合 → 由 XFF **由右往左**跳過可信 hop，第一個不可信者＝真實 client。
  3. 全可信／無 XFF → fail-safe 採 peer。
- **fail-safe 預設空**：未設或全部無效 token → 空集合 → 永遠採直連 peer（不會誤信 forwarded）。
- 無效 token 靜默丟棄（不影響其餘有效項）。

## dev

- 預設**留空**即可（採直連 peer）。
- 若要測「經 front-nginx 的真實 client IP 解析」，覆寫為內網段，例如：
  ```bash
  TRUSTED_PROXY_CIDRS="127.0.0.1/32,172.16.0.0/12" \
    docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
  ```
  （`172.16.0.0/12` 涵蓋 docker bridge 網段，使 front-nginx 這一 hop 可信。）

## prod（線上維護）

填入「**內網段 + 前置 CDN/CF 位址段**」兩部分：

1. **內網段**：front-nginx ↔ rust-api 所在的 compose 網段（`rev3-admin_rev3_net`，通常 `172.16.0.0/12` 範圍內；可 `docker network inspect rev3-admin_rev3_net` 查實際 subnet）。
2. **CDN/Cloudflare 位址段**（若前置 CF）：取自官方清單、**定期更新**（CF 會增刪段）：
   - IPv4：<https://www.cloudflare.com/ips-v4>
   - IPv6：<https://www.cloudflare.com/ips-v6>

設定方式（env 覆寫 `docker-compose.prod.yml` 的 `${TRUSTED_PROXY_CIDRS:-}`）：

```bash
TRUSTED_PROXY_CIDRS="172.16.0.0/12,173.245.48.0/20,103.21.244.0/22,2400:cb00::/32" \
  docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --wait
```

> ⚠️ 漏填某段 → 該 hop 視為不可信 → client_ip 會停在該代理 IP（保守、非偽造值）；多填無害但別填入終端使用者可控段。CF 段務必只取官方清單、勿手填猜測值。
