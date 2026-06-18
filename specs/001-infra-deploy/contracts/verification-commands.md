# C-V Contract: verification-commands（001-infra-deploy）

> 實機驗收命令全集（brainstorm 拍板 1＝B 實機）。執行前置：standalone base-web 先 `down`（port 31079 撞）。
> host 端需 `psql`／`redis-cli`（C-V-2/4 必備、非選配）。

## C-V-0 · 前置

```bash
docker compose -f docker-compose.base-web.yml down          # 避 31079 撞
bash deploy/generate-secrets.sh                              # 6 secrets → deploy/secrets/*.txt
bash deploy/generate-dev-cert.sh                             # 自簽 cert → deploy/dev-certs/
```

## C-V-1 · scaffold 獨立驗（worktree 內、不依賴 compose stack；host 無 cargo 時以 rust:1.86-slim-bookworm 容器執行等效）

```bash
cd rust-api && cargo build --bins && DATABASE_URL=postgres://cv1-help-probe cargo run --bin migration -- --help >/dev/null && cd ..
# 期望：2 binary 編譯通過＋migration CLI 可執行（exit 0 全鏈斷言）
# --help 也需 DB URL env（main.rs glue 先於 clap 解析；dummy 值即可、不會實連——T006 review M2）
# （rust 1.86 toolchain；time/home pin 生效＝lock 不被升版）
```

## C-V-2 · dev 硬出口（SC-001/002/003）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
# 期望：exit 0；ps 顯示 5 service healthy＋migrate Exited(0)

docker compose -f docker-compose.yml -f docker-compose.dev.yml ps -a

# gate 時序證據（SC-003／FR-002）：
MIG=$(docker compose -f docker-compose.yml -f docker-compose.dev.yml ps -aq migrate)
API=$(docker compose -f docker-compose.yml -f docker-compose.dev.yml ps -q rust-api)
NGX=$(docker compose -f docker-compose.yml -f docker-compose.dev.yml ps -q front-nginx)
docker inspect "$MIG" --format 'migrate FinishedAt: {{.State.FinishedAt}}'
docker inspect "$API" --format 'rust-api StartedAt: {{.State.StartedAt}}'
docker inspect "$NGX" --format 'front-nginx StartedAt: {{.State.StartedAt}}'
# 斷言①：migrate FinishedAt < rust-api StartedAt（閘門核心環）
# 斷言②：front-nginx StartedAt > rust-api StartedAt（入口最後就緒）
# 其餘環節：postgres healthy → migrate（migration 只需 DB、migrate depends_on 僅 postgres）；
#   redis healthy 是 rust-api 的 depends_on precondition（非 migrate；migration 不碰 redis）→
#   整鏈以 compose depends_on 宣告＋ up --wait exit 0 為接受證據
# fallback（inspect 不可用時）：docker compose ... logs -t migrate | tail -3（-t 帶時戳）

# 健檢 6 點（SC-002；照 CLAUDE.md §8.2.1）
curl -fsS http://127.0.0.1:31080/health                      # nginx 自答 ok
curl -kfsS https://127.0.0.1:31443/health                    # TLS 自簽 ok
curl -fsSi http://127.0.0.1:31081/health | grep -i "content-type: text/plain"   # rust-api 直連＋header 契約（L2）
curl -fsS http://127.0.0.1:31081/health                      # body=ok
curl -fsS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:31079/   # base-web 200
pg_isready -h 127.0.0.1 -p 35432
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning ping
```

## C-V-3 · proxy 鏈（SC-007；US2 四類請求）

```bash
curl -fsS http://127.0.0.1:31080/api/health                  # 期望 ok（strip /api → rust-api /health）
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:31080/api/metrics   # 期望 404（擋塊）
curl -fsS http://127.0.0.1:31080/ | head -c 200              # 期望 base-web HTML
curl -fsS http://127.0.0.1:31080/health                      # 期望 ok（入口自答、不依賴後端；US2 scenario 4）
```

## C-V-4 · 持久化（SC-004；FR-007 含 postgres＋redis 兩翼）

```bash
PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust \
  -c "CREATE TABLE IF NOT EXISTS cv_persist_probe(id int); INSERT INTO cv_persist_probe VALUES (1);"
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning SET cv_probe 1
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning SAVE             # RDB 同步落盤（T014 補：快照閾值內立即 down 會丟最後寫入）
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning CONFIG GET dir   # 期 /data（T014 結構斷言：--dir 必須指向 named volume；缺之＝T014 實抓 bug）

docker compose -f docker-compose.yml -f docker-compose.dev.yml down      # 卷保留
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait

PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust \
  -tc "SELECT count(*) FROM cv_persist_probe;"               # 期望 1
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning GET cv_probe   # 期望 1

PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust \
  -c "DROP TABLE cv_persist_probe;"
redis-cli -h 127.0.0.1 -p 36379 -a "$(cat deploy/secrets/redis_password.txt)" --no-auth-warning DEL cv_probe
```

## C-V-5 · 組態與殘留（SC-006；目前無豁免項）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml config -q     # dev 組合法
docker compose -f docker-compose.yml -f docker-compose.prod.yml config -q    # prod 組合法
docker compose -f docker-compose.rust-api.yml config -q                      # standalone 合法（FR-010）

# rev2 字樣＋全部舊 port 殘留（施加於部署層交付物；目前無豁免項——deploy/compose 不引用倉庫永久名）
# （嚴謹形：`git ls-files docker-compose*.yml deploy/ | xargs grep ...`——避開 gitignored 隨機生成物
#   〔secrets hex／certs base64〕理論上可含數字 port 子串的偶發誤中；T020 兩形式皆驗過歸零）
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌ 殘留" || echo "✅ 歸零"
# scaffold 豁免（T006 落地時新增）：migration/README.md 的 m001_rev2_schema／m002_rev2_seeds 為 002 刀規劃檔名（拍板 ⚠️t）＋其同行說明，非部署 token 殘留
grep -rinE "rev2|21079|21080|21081|21443" rust-api/server rust-api/migration rust-api/Cargo.toml 2>/dev/null | grep -vE "m00[12]_rev2_(schema|seeds)" && echo "❌" || echo "✅"
```

## C-V-6 · prod baseline sanity（SC-005；US3 軟驗）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
docker run --rm -v rev3-admin_front_nginx_certs:/certs -v "$PWD/deploy/dev-certs":/src alpine \
  sh -c "cp /src/fullchain.pem /src/privkey.pem /certs/"     # cert seed（前置條件——憑證卷空則 front-nginx 啟動失敗屬預期、不另測〔spec Edge case 4〕）
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

## C-V-8 · 負向與冪等（FR-005 fail-fast／Edge case 2/5）

```bash
# ① 缺失機密 fail-fast（FR-005／Edge case 1）：
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
mv deploy/secrets deploy/secrets.bak
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait 2>&1 | tail -3
# 期望：快速失敗、錯誤訊息指向缺失 secret 檔（compose file-secret 缺檔即拒啟）；不可無聲卡住
mv deploy/secrets.bak deploy/secrets

# ② migrate 失敗 → API 不啟動（Edge case 2）：**豁免不另測**——
#    由 compose `depends_on: condition: service_completed_successfully` 引擎語意保證；
#    正向時序證據已由 C-V-2 取得。

# ③ 運行中重複 up 冪等（Edge case 5）：
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
# 期望：第二次 exit 0、輸出顯示容器全部 unchanged/running、無資源重建
```
