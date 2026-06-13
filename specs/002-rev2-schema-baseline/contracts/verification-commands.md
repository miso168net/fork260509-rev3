# C-V Contract: verification-commands（002-rev2-schema-baseline）

> 實機驗收命令全集（斷言實作委派 tests/002 scripts——§0 I/O 表；本檔給出每條斷言的可跑形）。
> 拋棄式資源前綴 `cv002-`、結束即清。兩側 pg_dump 一律容器內 17.10（host 16 打 17 server 實測被拒）。
> normalize 五規則＝[migration-chain.md](migration-chain.md) §3 凍結；diff 非零先判「假紅（normalize 缺漏）vs 真 drift」——真 drift 修 migration、**不得調 normalize 遮差異**。

## §0 · tests/002 scripts I/O 契約（H4）

| script | args | 輸入 | 輸出 | 副作用／重跑語意 |
|---|---|---|---|---|
| `pristine-replay.sh` | 無 | rev2 image＋rev2 repo | `/tmp/cv002-rev2-schema.sql`＋`/tmp/cv002-rev2-data.sql`（normalize 後） | 建 `cv002-net`＋`cv002-rev2-pg`（起手 `docker rm -f` 舊容器、冪等重跑）；內建 pg 等待；斷言 seaql=35；exit 非 0＝重放失敗 |
| `normalize.sh` | `schema\|data [file]`（無 file 讀 stdin） | 原始 dump | normalize 後 dump → stdout | 純過濾、無副作用；schema 模式套規則 #1#2、data 模式套 #1~#5 |
| `diff-baseline.sh` | `[--reuse]` | rev2 側兩基準檔＋rust-api 源樹 | `/tmp/cv002-rev3-schema.sql`／`-data.sql`＋雙 diff 結果＋計數不變式＋VERIFY 3/3 | 建 `cv002-rev3-pg`（`--reuse`＝跳過建庫、直接對既有容器跑 dump+diff+斷言——C-V-5 重跑用）；exit 0＝全綠 |
| `delta-assert.sh` | `[cv002\|stack]`（預設 cv002） | 運行中目標庫 | delta 斷言全集結果 | `cv002` 模式＝docker exec cv002-rev3-pg（含排除式 data-diff 全量驗）；`stack` 模式＝host psql 35432（僅計數斷言——dev stack 無 dump 需求）；無建庫副作用 |

共用連線（容器內視角）：`CV002_DB_URL=postgres://soybean:cv002@cv002-rev3-pg:5432/soybean_admin_rust`
rev3 側 migration 執行形（**rev3 image 此時未 build、host 無 cargo——唯一可行形＝rust:1.86 容器**）：

```bash
RUN_MIG='docker run --rm --network cv002-net -v "$PWD/rust-api":/app -w /app \
  -v cv002-cargo:/usr/local/cargo -v cv002-target:/app/target \
  -e RUSTUP_TOOLCHAIN=1.86.0 -e DATABASE_URL=$CV002_DB_URL rust:1.86-slim-bookworm'
# 用法：eval $RUN_MIG cargo run --bin migration -- up -n 2
```

pg 等待形（postgres:17-alpine 無內建 HEALTHCHECK；sleep 2 跨 initdb 重啟窗口）：

```bash
wait_pg() { until docker exec "$1" pg_isready -U soybean -d soybean_admin_rust >/dev/null 2>&1; do sleep 1; done; sleep 2; docker exec "$1" pg_isready -U soybean -d soybean_admin_rust; }
```

## C-V-0 · 前置（併入 T008 起手；fail 即停——spec Edge case「資產不可用、驗收不得豁免」）

```bash
ls /mnt/d/AnewSpaces/x_Project/fork260509-rev2/rust-api/migration/src/ | grep -c '^m20'   # 期恰 35
docker image inspect rev2-admin-rust-api:latest -f OK                                      # rev2 image 在
docker compose -f docker-compose.yml -f docker-compose.dev.yml config --services | wc -l   # 期 6（5 service＋migrate；acme 掛 profiles:[prod] 不列——複驗 N1 實測；不要求運行中、C-V-7 才需啟動）
ls /tmp/rev2-schema-dump.sql || docker exec rev2-admin-postgres-1 pg_dump -U soybean -d soybean_admin_rust --schema-only > /tmp/rev2-schema-dump.sql   # 轉錄權威重生（須 rev2 stack 在跑；quickstart 前置同款）
# fail → rev2 repo／image 缺＝環境前置問題：回 rev2 workspace 重建（docker compose build）或還原 repo；不可豁免改用其他證據
```

## C-V-1 · 建置驗（adapter 拷入＋deps 後；容器 rust:1.86 等效、001 C-V-1 同形）

```bash
cd rust-api && cargo build --bins && cd ..
grep -c 'name = "time"' rust-api/Cargo.lock        # 期 0（R3 義務）
grep -c 'name = "casbin"' rust-api/Cargo.lock      # 期 ≥1
# fail → time≠0＝workspace sea-orm 條目走偏（回查 R3 宣告形）；編譯炸＝adapter 拷貝不完整或 features 缺（對照 R3 最小集逐 feature 補、記錄偏離）
```

## C-V-2 · pristine 參考庫重放（＝`pristine-replay.sh`）

```bash
docker rm -f cv002-rev2-pg 2>/dev/null; docker network create cv002-net 2>/dev/null || true
docker run -d --name cv002-rev2-pg --network cv002-net -e POSTGRES_USER=soybean -e POSTGRES_PASSWORD=cv002 -e POSTGRES_DB=soybean_admin_rust postgres:17-alpine
wait_pg cv002-rev2-pg
docker run --rm --network cv002-net -e DATABASE_URL=postgres://soybean:cv002@cv002-rev2-pg:5432/soybean_admin_rust rev2-admin-rust-api:latest migration up
docker exec cv002-rev2-pg psql -U soybean -d soybean_admin_rust -tAc "SELECT count(*) FROM seaql_migrations;"   # 期 35
docker exec cv002-rev2-pg pg_dump -U soybean -d soybean_admin_rust --schema-only --no-owner | bash tests/002-rev2-schema-baseline/scripts/normalize.sh schema > /tmp/cv002-rev2-schema.sql
docker exec cv002-rev2-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t sys_menu -t casbin_rule -t system_settings \
  | bash tests/002-rev2-schema-baseline/scripts/normalize.sh data > /tmp/cv002-rev2-data.sql
# 基準檔 git-track（T009）：cp 上述兩檔 → tests/002-rev2-schema-baseline/{rev2-schema-baseline.sql, rev2-data-baseline.sql}
# fail → seaql≠35＝rev2 image 與源碼不同步（回 rev2 workspace 重 build image 再跑）；dump 炸＝容器未 ready（wait_pg 檢查）
```

## C-V-3 · rev3 基線檢查點雙 diff（⚠️t 零差異斷言＝m001+m002；**m003 前**；＝`diff-baseline.sh`）

```bash
docker rm -f cv002-rev3-pg 2>/dev/null
docker run -d --name cv002-rev3-pg --network cv002-net -e POSTGRES_USER=soybean -e POSTGRES_PASSWORD=cv002 -e POSTGRES_DB=soybean_admin_rust postgres:17-alpine
wait_pg cv002-rev3-pg
eval $RUN_MIG cargo run --bin migration -- up -n 2          # 停在 m002 檢查點
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --schema-only --no-owner | bash tests/002-rev2-schema-baseline/scripts/normalize.sh schema > /tmp/cv002-rev3-schema.sql
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t sys_menu -t casbin_rule -t system_settings \
  | bash tests/002-rev2-schema-baseline/scripts/normalize.sh data > /tmp/cv002-rev3-data.sql
diff /tmp/cv002-rev2-schema.sql /tmp/cv002-rev3-schema.sql && echo "SCHEMA 零差異 ✅"
diff /tmp/cv002-rev2-data.sql   /tmp/cv002-rev3-data.sql   && echo "SEED 零差異 ✅"

# 計數不變式（psql 實形；P=docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc）：
P() { docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc "$1"; }
P "SELECT count(*) FROM sys_user;"                                        # 3
P "SELECT count(*) FROM sys_role;"                                        # 3
P "SELECT count(*) FROM sys_user_role;"                                   # 3
P "SELECT count(*) FROM sys_menu;"                                        # 10
P "SELECT count(*) FROM casbin_rule;"                                     # 72
P "SELECT count(*) FROM system_settings;"                                 # 1
P "SELECT count(*) FROM casbin_rule WHERE ptype='p';"                     # 72（g=0 由 72-72 推得，亦可 ptype='g' 期 0）
P "SELECT count(*) FROM casbin_rule WHERE protected;"                     # 19
P "SELECT count(*) FROM sys_menu WHERE protected;"                        # 8
P "SELECT string_agg(id::text,',' ORDER BY id) FROM sys_user;"            # 1,2,3
P "SELECT last_value||','||is_called FROM sys_user_id_seq;"               # 3,t
P "SELECT count(DISTINCT password) FROM sys_user;"                        # 1
P "SELECT count(*) FROM sys_user WHERE password LIKE '\$argon2id\$v=19\$%';"   # 3

# C-V-4 比對基準留存（M3 全量驗的 before 側——同庫 delta 前後對照）：
P "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM sys_menu WHERE id<=10) t;"    > /tmp/cv002-md5-menu10.txt
P "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM casbin_rule WHERE id<=72) t;" > /tmp/cv002-md5-casbin72.txt
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t system_settings \
  | bash tests/002-rev2-schema-baseline/scripts/normalize.sh data > /tmp/cv002-rev3-static4.sql

# 密碼可驗性 3/3（SC-004；env 注入避開 $ 二次展開——H2 修）：
for ID in 1 2 3; do
  HASH=$(P "SELECT password FROM sys_user WHERE id=$ID;")
  docker run --rm -e HASH="$HASH" -e ID="$ID" python:3.12-slim sh -c \
    'pip install -q argon2-cffi && python -c "import os; from argon2 import PasswordHasher; PasswordHasher().verify(os.environ[\"HASH\"],\"123456\"); print(\"VERIFY-OK\",os.environ[\"ID\"])"'
done   # 期 VERIFY-OK ×3
# fail → 先對 migration-chain.md §3 判假紅 vs 真 drift；真 drift＝修 m001（schema 側）/m002（data 側）重跑本節；hash 驗證炸＝檢查 env 注入形（禁止把 $HASH 內嵌雙引號字串）
```

## C-V-4 · delta 套用＋斷言（同一 cv002-rev3-pg 續跑；＝`delta-assert.sh cv002`）

```bash
eval $RUN_MIG cargo run --bin migration -- up               # 套 m003+m004
P "SELECT count(*) FROM pg_constraint WHERE contype='f';"                       # 2
P "SELECT count(*) FROM pg_constraint WHERE contype='f' AND confdeltype='r';"   # 2（RESTRICT）
P "SELECT count(*) FROM sys_menu;"                                              # 76
P "SELECT count(*) FROM casbin_rule;"                                           # 138
P "SELECT count(*) FROM casbin_rule WHERE v2='menu';"                           # 83
# FR-006 直接斷言（M2 修）：demo 66 列 policy 全部且僅授 R_SUPER——
P "SELECT count(*) FROM casbin_rule WHERE ptype='p' AND v2='menu' AND v0='R_SUPER' AND v1 IN (SELECT route_name FROM sys_menu WHERE id>10);"   # 66
P "SELECT count(*) FROM casbin_rule WHERE v2='menu' AND v0<>'R_SUPER' AND v1 IN (SELECT route_name FROM sys_menu WHERE id>10);"               # 0
# 基線全量不變（M3 修——排除式全量驗、取代 spot-check；before 側已於 C-V-3 留存）：
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t system_settings \
  | bash tests/002-rev2-schema-baseline/scripts/normalize.sh data > /tmp/cv002-delta-static4.sql
diff /tmp/cv002-rev3-static4.sql /tmp/cv002-delta-static4.sql && echo "靜態 4 表全量不變 ✅"
# sys_menu/casbin_rule（delta 有新增）排除新增列後 checksum 與 C-V-3 留存值比對：
P "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM sys_menu WHERE id<=10) t;"      # == /tmp/cv002-md5-menu10.txt
P "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM casbin_rule WHERE id<=72) t;"   # == /tmp/cv002-md5-casbin72.txt
# fail → FK 斷言炸＝修 m003；demo 計數/授權炸＝修 m004（對照 demo-menu-enumeration 不變式）；基線 md5 變＝m004 誤改基線列（檢查 UPDATE/DELETE 範圍）
```

## C-V-5 · up→down→up 守恆（波 0 出口條件項）

```bash
eval $RUN_MIG cargo run --bin migration -- down -n 4
P "SELECT count(*) FROM pg_tables WHERE schemaname='public';"   # 1（僅 seaql_migrations）
eval $RUN_MIG cargo run --bin migration -- up -n 2
bash tests/002-rev2-schema-baseline/scripts/diff-baseline.sh --reuse    # C-V-3 雙 diff＋不變式重跑→仍綠（終態等價＝SC-003）
eval $RUN_MIG cargo run --bin migration -- up
bash tests/002-rev2-schema-baseline/scripts/delta-assert.sh cv002       # C-V-4 重斷言→綠
# fail → down 殘表＝對應 migration down() 不對稱（修該支）；重建後 diff 紅＝up 非冪等構造（查 m001/m002 內 if_not_exists／ON CONFLICT 形）
```

## C-V-6 · 冪等

```bash
eval $RUN_MIG cargo run --bin migration -- up; echo exit=$?    # 期 exit=0＋無 pending（L9 修：分號形、恆報實際碼）
# 列數全不變斷言集（L5 口徑明定）：sys_user 3／sys_role 3／sys_user_role 3／system_settings 1／sys_menu 76／casbin_rule 138
# fail → 第二次 up 改變列數＝某支 migration 缺冪等鍵（查 ON CONFLICT／IF NOT EXISTS）
```

## C-V-7 · dev stack migrate gate 實機（001 基建上；＝`delta-assert.sh stack`）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait; echo exit=$?
PG() { PGPASSWORD=$(cat deploy/secrets/postgres_password.txt) psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust -tAc "$1"; }
PG "SELECT count(*) FROM pg_tables WHERE schemaname='public';"   # 12
# 計數斷言集同 C-V-4 stack 模式（host psql 查詢 OK、僅 pg_dump 受版本限制）：3/3/3/1/76/138/83/19/8/FK=2
curl -fsS http://127.0.0.1:31080/api/health                      # ok（既有功能不退化）
# fail → migrate gate 卡住＝docker compose logs migrate 查首輪錯誤；rust-api unhealthy＝001 基建問題（非本刀）先排除
```

## C-V-8 · prod target image build（**必含**——本刀新增 workspace crate sea-orm-adapter，CLAUDE.md §3 紀律）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 期：builder COPY 齊（server＋migration＋sea-orm-adapter）、3-stage 全過
# fail → manifest/COPY 缺行＝補 deploy/Dockerfile.rust-api.txt Manifest／Source 段（T004）；注意 adapter examples/ 為資料檔非 cargo target、免 COPY
```

## C-V-9 · 殘留 grep（H1 修訂形）

```bash
# 部署層零豁免（不變）：
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌" || echo "✅"
# rust-api（adapter 目錄整體排除——byte-identical 拷貝物、由 byte-diff 把關取代 grep）：
grep -rinE "rev2|21079|21080|21081|21443" rust-api/server rust-api/migration rust-api/Cargo.toml 2>/dev/null \
  | grep -vE "m00[0-9]_rev2_" | grep -v "migration/README" && echo "❌" || echo "✅"
#（內容錨定豁免 m00X_rev2_：同時涵蓋檔名命中與 lib.rs 掛載行；README 既有 002 預告豁免沿 001）
# adapter byte-diff 把關（取代 grep；M1 拍板形）：
diff -r rust-api/sea-orm-adapter /mnt/d/AnewSpaces/x_Project/fork260509-rev2/rust-api/sea-orm-adapter
# 期：唯一差異＝Cargo.toml 檔頭 provenance 注記 1 行（rev3 來源鏈更新、原 rev1 鏈注記保留——T001 拍板形）；其餘 byte-identical
# fail → 出現非檔頭差異＝拷貝汙染（重拷）；grep ❌＝逐筆判定（新增豁免須在本檔留痕）

# 清理：
docker rm -f cv002-rev2-pg cv002-rev3-pg 2>/dev/null; docker network rm cv002-net 2>/dev/null
docker volume rm cv002-cargo cv002-target 2>/dev/null
```
