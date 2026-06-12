# C-V Contract: verification-commands（001-infra-deploy）

> 實機驗收命令全集（brainstorm 拍板 1＝B 實機）。執行前置：standalone base-web 先 `down`（port 31079 撞）。

## C-V-0 · 前置

```bash
docker compose -f docker-compose.base-web.yml down          # 避 31079 撞
bash deploy/generate-secrets.sh                              # 6 secrets → deploy/secrets/*.txt
bash deploy/generate-dev-cert.sh                             # 自簽 cert → deploy/dev-certs/
```

## C-V-1 · scaffold 獨立驗（worktree 內、不依賴 docker）

```bash
cd rust-api && cargo build --bins && cargo run --bin migration -- --help >/dev/null 2>&1; cd ..
# 期望：2 binary 編譯通過（rust 1.86 toolchain；time/home pin 生效＝lock 不被升版）
```

## C-V-2 · dev 硬出口（SC-001/002/003）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
# 期望：exit 0；ps 顯示 5 service healthy＋migrate Exited(0)

docker compose -f docker-compose.yml -f docker-compose.dev.yml ps -a
# 期望：front-nginx/base-web/rust-api/postgres/redis-stack = healthy；migrate = exited(0)

# gate 時序證據（SC-003）：migrate 完成時間 < rust-api 啟動時間
docker inspect rev3-admin-migrate-1 --format '{{.State.FinishedAt}}' 2>/dev/null || docker compose -f docker-compose.yml -f docker-compose.dev.yml logs migrate | tail -3
docker inspect $(docker compose -f docker-compose.yml -f docker-compose.dev.yml ps -q rust-api) --format '{{.State.StartedAt}}'

# 健檢 6 點（SC-002；照 CLAUDE.md §8.2.1）
curl -fsS http://127.0.0.1:31080/health                      # nginx 自答 ok
curl -kfsS https://127.0.0.1:31443/health                    # TLS 自簽 ok
curl -fsS http://127.0.0.1:31081/health                      # rust-api 直連 ok
curl -fsS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:31079/   # base-web 200
pg_isready -h 127.0.0.1 -p 35432
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning ping
```

## C-V-3 · proxy 鏈（SC-007；US2）

```bash
curl -fsS http://127.0.0.1:31080/api/health                  # 期望 ok（strip /api → rust-api /health）
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:31080/api/metrics   # 期望 404（擋塊）
curl -fsS http://127.0.0.1:31080/ | head -c 200              # 期望 base-web HTML
```

## C-V-4 · 持久化（SC-004）

```bash
PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust \
  -c "CREATE TABLE IF NOT EXISTS cv_persist_probe(id int); INSERT INTO cv_persist_probe VALUES (1);"
docker compose -f docker-compose.yml -f docker-compose.dev.yml down      # 卷保留
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust \
  -tc "SELECT count(*) FROM cv_persist_probe;"               # 期望 1
PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust \
  -c "DROP TABLE cv_persist_probe;"                          # 清 probe
```

## C-V-5 · 組態與殘留（SC-006）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml config -q    # dev 組合法
docker compose -f docker-compose.yml -f docker-compose.prod.yml config -q   # prod 組合法
grep -ri "rev2" docker-compose*.yml deploy/ && echo "❌ 殘留" || echo "✅ 歸零"
grep -ri "rev2\|2107\|2108\|2143" rust-api/server rust-api/migration rust-api/Cargo.toml 2>/dev/null && echo "❌" || echo "✅"
```

## C-V-6 · prod baseline sanity（SC-005；US3 軟驗）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
docker run --rm -v rev3-admin_front_nginx_certs:/certs -v "$PWD/deploy/dev-certs":/src alpine \
  sh -c "cp /src/fullchain.pem /src/privkey.pem /certs/"     # cert seed
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --wait
curl -fsS http://127.0.0.1/health                            # 80 例外路徑 ok
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/   # 期望 301（→https）
docker compose -f docker-compose.yml -f docker-compose.prod.yml down
```

## C-V-7 · prod target image build（CLAUDE.md §3 紀律——本刀新增 workspace crate，必含）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 期望：builder stage COPY 齊全（server+migration）、3-stage 全過、無 manifest parse error
# 理由：dev bind-mount 整個 rust-api/ 會遮住 Dockerfile 逐 crate COPY 缺口（rev2 三度踩雷）
```
