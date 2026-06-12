# Quickstart: 001-infra-deploy 驗證指南

> 從零到全 stack 就緒的可執行流程；完整驗收命令與期望輸出見 [contracts/verification-commands.md](contracts/verification-commands.md)。

## 前置需求

- Docker 29.x／Compose v5.x；WSL2 mirrored networking（`127.0.0.1` 自 host 可達）
- port 段 3XXXX 空閒；standalone base-web 若在跑先 `docker compose -f docker-compose.base-web.yml down`
- `psql`/`redis-cli`（host 端驗收**必備**——C-V-2/C-V-4 依賴）

## 一次性準備（兩步）

```bash
bash deploy/generate-secrets.sh      # 生成 6 個 secret 檔（gitignored）
bash deploy/generate-dev-cert.sh     # 生成 dev 自簽 cert（年度 renew）
```

## dev stack 啟動與驗收

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
```

期望：命令成功返回；`ps` 顯示 5 service healthy、migrate exited(0)。隨後跑 [C-V-2～C-V-5](contracts/verification-commands.md)（健檢 6 點／proxy 鏈／持久化／組態與殘留）。

首次啟動較慢屬預期：rust-api dev image build＋cargo 冷編譯（數分鐘，cargo cache 卷使後續啟動快）；base-web pnpm install（standalone 期已驗證的 90s 級 start_period）。

## prod baseline 演練（軟驗）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
docker run --rm -v rev3-admin_front_nginx_certs:/certs -v "$PWD/deploy/dev-certs":/src alpine \
  sh -c "cp /src/fullchain.pem /src/privkey.pem /certs/"
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --wait
# 驗 80→443 redirect 與 /health 例外（C-V-6），然後：
docker compose -f docker-compose.yml -f docker-compose.prod.yml down
```

## prod image build（紀律必跑）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api   # C-V-7
```

## 收尾

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml down   # 卷保留；要全清加 -v
```
