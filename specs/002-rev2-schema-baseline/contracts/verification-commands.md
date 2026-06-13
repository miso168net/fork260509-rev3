# C-V Contract: verification-commands（002-rev2-schema-baseline）

> 實機驗收命令全集。拋棄式資源命名前綴 `cv002-`、結束即清。兩側 pg_dump 一律容器內 17.10（host 16 實測被拒）。
> normalize 五規則＝[migration-chain.md](migration-chain.md) §3 凍結；diff 非零先判「假紅（normalize 缺漏）vs 真 drift」——真 drift 修 migration、**不得調 normalize 遮差異**。

## C-V-0 · 前置

```bash
ls /mnt/d/AnewSpaces/x_Project/fork260509-rev2/rust-api/migration/src/ | wc -l   # rev2 源碼在（≥35）
docker image inspect rev2-admin-rust-api:latest -f OK                             # rev2 既有 image 在
docker compose -f docker-compose.yml -f docker-compose.dev.yml ps --format '{{.Service}}' | wc -l   # 001 stack 5 service
```

## C-V-1 · 建置驗（adapter 拷入＋deps 後；容器 rust:1.86 等效、001 C-V-1 同形）

```bash
cd rust-api && cargo build --bins && cd ..        # workspace 含 sea-orm-adapter member 全綠
grep -c 'name = "time"' rust-api/Cargo.lock        # 期 0（R3 義務；非 0＝宣告形走偏、回查 workspace sea-orm 條目）
grep -c 'name = "casbin"' rust-api/Cargo.lock      # 期 ≥1（adapter 鏈成立）
```

## C-V-2 · pristine 參考庫重放（rev2 側）

```bash
docker network create cv002-net
docker run -d --name cv002-rev2-pg --network cv002-net -e POSTGRES_USER=soybean -e POSTGRES_PASSWORD=cv002 -e POSTGRES_DB=soybean_admin_rust postgres:17-alpine
# 等 healthy 後：
docker run --rm --network cv002-net -e DATABASE_URL=postgres://soybean:cv002@cv002-rev2-pg:5432/soybean_admin_rust rev2-admin-rust-api:latest migration up
docker exec cv002-rev2-pg psql -U soybean -d soybean_admin_rust -tc "SELECT count(*) FROM seaql_migrations;"   # 期 35
bash tests/002-rev2-schema-baseline/scripts/normalize.sh <(docker exec cv002-rev2-pg pg_dump -U soybean -d soybean_admin_rust --schema-only --no-owner) > /tmp/cv002-rev2-schema.sql
# data dump（6 seed 表）同形 normalize → /tmp/cv002-rev2-data.sql
```

## C-V-3 · rev3 基線檢查點雙 diff（⚠️t 零差異斷言＝m001+m002；**m003 前**）

```bash
docker run -d --name cv002-rev3-pg --network cv002-net -e POSTGRES_USER=soybean -e POSTGRES_PASSWORD=cv002 -e POSTGRES_DB=soybean_admin_rust postgres:17-alpine
cd rust-api && DATABASE_URL=postgres://soybean:cv002@127.0.0.1:<mapped>/soybean_admin_rust cargo run --bin migration -- up -n 2 && cd ..   # 停在 m002 檢查點（或容器內跑、形同 C-V-2）
# 雙 dump＋normalize → diff：
diff /tmp/cv002-rev2-schema.sql /tmp/cv002-rev3-schema.sql && echo "SCHEMA 零差異 ✅"
diff /tmp/cv002-rev2-data.sql   /tmp/cv002-rev3-data.sql   && echo "SEED 零差異 ✅"
# 計數不變式（rev3 側）：
# 92 列/6 表：sys_user 3｜sys_role 3｜sys_user_role 3｜sys_menu 10｜casbin_rule 72｜system_settings 1
# casbin p=72/g=0；protected：casbin 19、menu 8；sys_user id 恰 {1,2,3}；sys_user_id_seq last_value=3/is_called=t
# argon2：COUNT(DISTINCT password)=1 且前綴 '$argon2id$v=19$'
# 密碼可驗性（SC-004）：
HASH=$(docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc "SELECT password FROM sys_user WHERE id=1;")
docker run --rm python:3.12-slim sh -c "pip install -q argon2-cffi && python -c \"from argon2 import PasswordHasher; PasswordHasher().verify('$HASH','123456'); print('VERIFY-OK')\""
```

## C-V-4 · delta 套用＋斷言（同一 cv002-rev3-pg 續跑）

```bash
cd rust-api && DATABASE_URL=... cargo run --bin migration -- up && cd ..   # 套 m003+m004
# FK ×2＋RESTRICT：
docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tc "SELECT count(*) FROM pg_constraint WHERE contype='f';"                  # 期 2
docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tc "SELECT count(*) FROM pg_constraint WHERE contype='f' AND confdeltype='r';"  # 期 2（RESTRICT）
# demo 斷言：sys_menu 總 10+66=76；casbin v2='menu' 17+66=83；casbin 總 72+66=138
# 基線不變：92 列原值 spot-check（sys_user 3 列、protected 19/8 不變、settings 1 列原值）
# delta 套用後不再跑零差異 diff（與 rev2 必然有差——契約語意）
```

## C-V-5 · up→down→up 守恆（波 0 出口條件項）

```bash
cd rust-api && DATABASE_URL=... cargo run --bin migration -- down -n 4 && cd ..   # 全鏈回滾
docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tc "SELECT count(*) FROM pg_tables WHERE schemaname='public';"   # 期 1（僅 seaql_migrations）
cd rust-api && DATABASE_URL=... cargo run --bin migration -- up -n 2 && cd ..     # 重建至檢查點
# C-V-3 雙 diff 重跑 → 仍零差異（終態等價＝SC-003）；再 up 補 delta → C-V-4 斷言重跑綠
```

## C-V-6 · 冪等

```bash
cd rust-api && DATABASE_URL=... cargo run --bin migration -- up && echo exit=$?   # 第二次：exit 0、無 pending、列數全不變
```

## C-V-7 · dev stack migrate gate 實機（001 基建上）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait; echo exit=$?   # migrate one-shot 套 4 支 → rust-api healthy
PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust -tc "SELECT count(*) FROM pg_tables WHERE schemaname='public';"   # 期 12
# 92+66 列計數同 C-V-3/4 斷言（host psql 查詢 OK、僅 pg_dump 受版本限制）
curl -fsS http://127.0.0.1:31080/api/health    # 既有功能不退化
```

## C-V-8 · prod target image build（**必含**——本刀新增 workspace crate sea-orm-adapter，CLAUDE.md §3 紀律）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 期：builder COPY 齊（server+migration+sea-orm-adapter）、3-stage 全過
```

## C-V-9 · 殘留 grep（規則修訂版）

```bash
# 部署層零豁免（不變）：
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌" || echo "✅"
# rust-api scaffold（002 修訂：m00*_rev2_* migration 檔＝本刀交付物、檔名與內容性引用整檔豁免）：
grep -rinE "rev2|21079|21080|21081|21443" rust-api/server rust-api/migration rust-api/Cargo.toml rust-api/sea-orm-adapter 2>/dev/null \
  | grep -vE "migration/(src/)?(m00[0-9]_rev2_|README)" | grep -vE "sea-orm-adapter/Cargo.toml:1:" && echo "❌" || echo "✅"
# （adapter Cargo.toml 首行拷貝來源注記豁免；發現其他命中＝逐筆判定）

# 清理：
docker rm -f cv002-rev2-pg cv002-rev3-pg && docker network rm cv002-net
```
