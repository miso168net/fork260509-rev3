#!/usr/bin/env bash
# pristine-replay.sh — 前代 35 支 migration pristine 重放 → normalize dump（C-V-2）
#
# 起手執行 C-V-0 前置檢查（fail 即停、不可豁免）；
# 建拋棄式 cv002-net + cv002-rev2-pg（冪等：起手 docker rm -f 舊容器），
# 以前代 image（rev2-admin-rust-api:latest）跑 migration up，斷言 seaql=35，
# 兩種 dump（schema / data）經 normalize.sh 落 /tmp。
#
# 輸出：/tmp/cv002-rev2-schema.sql（normalize 後）
#       /tmp/cv002-rev2-data.sql  （normalize 後）
# exit 非 0 ＝ 重放失敗。

set -euo pipefail

# workspace root（scripts 在 tests/002-rev2-schema-baseline/scripts/，上溯 3 層）
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS="$ROOT/tests/002-rev2-schema-baseline/scripts"
NORMALIZE="$SCRIPTS/normalize.sh"

# 前代資產路徑（功能必需的真實識別碼）
PREV_REPO="/mnt/d/AnewSpaces/x_Project/fork260509-rev2/rust-api"
PREV_IMAGE="rev2-admin-rust-api:latest"
PREV_PG_CONTAINER="rev2-admin-postgres-1"
PREV_SCHEMA_DUMP="/tmp/rev2-schema-dump.sql"

fail() { echo "❌ pristine-replay: $*" >&2; exit 1; }

wait_pg() {
  until docker exec "$1" pg_isready -U soybean -d soybean_admin_rust >/dev/null 2>&1; do sleep 1; done
  sleep 2
  docker exec "$1" pg_isready -U soybean -d soybean_admin_rust
}

# ─────────────────────────────────────────────────────────────
# C-V-0 · 前置檢查（fail 即停——資產不可用、驗收不得豁免）
# ─────────────────────────────────────────────────────────────
echo "── C-V-0 前置檢查 ──"

# (1) 前代 migration 恰 35 支
MIG_COUNT=$(ls "$PREV_REPO/migration/src/" 2>/dev/null | grep -c '^m20' || true)
[ "$MIG_COUNT" = "35" ] || fail "前代 migration 數 $MIG_COUNT ≠ 35（前代 repo 缺檔或路徑錯：$PREV_REPO）"
echo "  前代 migration 35 支 ✅"

# (2) 前代 image 在
docker image inspect "$PREV_IMAGE" -f 'OK' >/dev/null 2>&1 \
  || fail "前代 image $PREV_IMAGE 不在（回前代 workspace docker compose build 重建）"
echo "  前代 image $PREV_IMAGE ✅"

# (3) 轉錄權威 schema dump 在、否則重生（須前代 stack 在跑）
if [ ! -f "$PREV_SCHEMA_DUMP" ]; then
  echo "  $PREV_SCHEMA_DUMP 不在 → 自前代 stack 重生（須 $PREV_PG_CONTAINER 在跑）"
  docker ps --filter "name=$PREV_PG_CONTAINER" --format '{{.Names}}' | grep -q "$PREV_PG_CONTAINER" \
    || fail "前代 stack 容器 $PREV_PG_CONTAINER 未運行、無法重生 $PREV_SCHEMA_DUMP（先啟前代 dev stack）"
  docker exec "$PREV_PG_CONTAINER" pg_dump -U soybean -d soybean_admin_rust --schema-only > "$PREV_SCHEMA_DUMP" \
    || fail "重生 $PREV_SCHEMA_DUMP 失敗"
fi
echo "  轉錄權威 dump $PREV_SCHEMA_DUMP ✅"

# ─────────────────────────────────────────────────────────────
# C-V-2 · pristine 參考庫重放
# ─────────────────────────────────────────────────────────────
echo "── C-V-2 pristine 重放 ──"

# 冪等：起手清舊容器、建拋棄式網路
docker rm -f cv002-rev2-pg >/dev/null 2>&1 || true
docker network create cv002-net >/dev/null 2>&1 || true

docker run -d --name cv002-rev2-pg --network cv002-net \
  -e POSTGRES_USER=soybean -e POSTGRES_PASSWORD=cv002 -e POSTGRES_DB=soybean_admin_rust \
  postgres:17-alpine >/dev/null
echo "  cv002-rev2-pg 啟動，等待 pg ready…"
wait_pg cv002-rev2-pg

# 前代 image 跑 migration up（容器內視角連 cv002-rev2-pg:5432）
docker run --rm --network cv002-net \
  -e DATABASE_URL=postgres://soybean:cv002@cv002-rev2-pg:5432/soybean_admin_rust \
  "$PREV_IMAGE" migration up \
  || fail "前代 migration up 失敗（image 與源碼不同步？回前代 workspace 重 build）"

# 斷言 seaql=35
SEAQL=$(docker exec cv002-rev2-pg psql -U soybean -d soybean_admin_rust -tAc "SELECT count(*) FROM seaql_migrations;" | tr -d '[:space:]')
[ "$SEAQL" = "35" ] || fail "seaql_migrations 計數 $SEAQL ≠ 35（前代 image 與源碼不同步、回前代 workspace 重 build image 再跑）"
echo "  seaql_migrations = 35 ✅"

# schema dump → normalize → /tmp
docker exec cv002-rev2-pg pg_dump -U soybean -d soybean_admin_rust --schema-only --no-owner \
  | bash "$NORMALIZE" schema > /tmp/cv002-rev2-schema.sql
echo "  /tmp/cv002-rev2-schema.sql 產出（$(wc -l < /tmp/cv002-rev2-schema.sql) 行）"

# data dump（6 表）→ normalize → /tmp
docker exec cv002-rev2-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t sys_menu -t casbin_rule -t system_settings \
  | bash "$NORMALIZE" data > /tmp/cv002-rev2-data.sql
echo "  /tmp/cv002-rev2-data.sql 產出（$(wc -l < /tmp/cv002-rev2-data.sql) 行）"

echo ""
echo "✅ pristine-replay 完成：seaql=35、兩 dump 已 normalize 落 /tmp"
echo "   /tmp/cv002-rev2-schema.sql"
echo "   /tmp/cv002-rev2-data.sql"
echo "   （基準檔 git-track 由 T009 處理：cp → tests/002-rev2-schema-baseline/{rev2-schema-baseline.sql, rev2-data-baseline.sql}）"
