#!/usr/bin/env bash
# diff-baseline.sh — rev3 基線檢查點雙 diff（C-V-3；m001+m002、m003 前）
#
# 用法：
#   diff-baseline.sh           # 全程：建 cv002-rev3-pg → up -n 2 → dump+normalize+雙 diff+不變式+VERIFY
#   diff-baseline.sh --reuse   # 跳過建庫，直接對既有 cv002-rev3-pg 重跑 dump+diff+斷言（C-V-5 重跑用）
#
# 前置：pristine-replay.sh 已產 /tmp/cv002-rev2-{schema,data}.sql（C-V-2 基準）。
# 輸出：/tmp/cv002-rev3-schema.sql、/tmp/cv002-rev3-data.sql
#       雙 diff 結果（SCHEMA 零差異 ✅ / SEED 零差異 ✅）
#       計數不變式全集 + VERIFY 3/3
#       C-V-4 比對基準留存（/tmp/cv002-md5-menu10.txt、-casbin72.txt、cv002-rev3-static4.sql）
# exit 0 ＝ 全綠。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS="$ROOT/tests/002-rev2-schema-baseline/scripts"
NORMALIZE="$SCRIPTS/normalize.sh"

REUSE=0
[ "${1:-}" = "--reuse" ] && REUSE=1

fail() { echo "❌ diff-baseline: $*" >&2; exit 1; }

wait_pg() {
  until docker exec "$1" pg_isready -U soybean -d soybean_admin_rust >/dev/null 2>&1; do sleep 1; done
  sleep 2
  docker exec "$1" pg_isready -U soybean -d soybean_admin_rust
}

# rev3 側連線（容器內視角）
CV002_DB_URL='postgres://soybean:cv002@cv002-rev3-pg:5432/soybean_admin_rust'

# rev3 migration 執行形（rev3 image 此時未 build、host 無 cargo → rust:1.86 容器）
# 注意：eval 展開時 $CV002_DB_URL / $PWD 才解析，故此處用單引號保留
RUN_MIG='docker run --rm --network cv002-net -v "$ROOT/rust-api":/app -w /app \
  -v cv002-cargo:/usr/local/cargo -v cv002-target:/app/target \
  -e RUSTUP_TOOLCHAIN=1.86.0 -e DATABASE_URL=$CV002_DB_URL rust:1.86-slim-bookworm'

# psql helper（cv002-rev3-pg）
P() { docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc "$1" | tr -d '[:space:]'; }

# 前置：C-V-2 基準檔存在
[ -f /tmp/cv002-rev2-schema.sql ] || fail "/tmp/cv002-rev2-schema.sql 不在（先跑 pristine-replay.sh）"
[ -f /tmp/cv002-rev2-data.sql ]   || fail "/tmp/cv002-rev2-data.sql 不在（先跑 pristine-replay.sh）"

if [ "$REUSE" = "0" ]; then
  echo "── 建 cv002-rev3-pg + 套 m001+m002（up -n 2）──"
  docker network create cv002-net >/dev/null 2>&1 || true
  docker rm -f cv002-rev3-pg >/dev/null 2>&1 || true
  docker run -d --name cv002-rev3-pg --network cv002-net \
    -e POSTGRES_USER=soybean -e POSTGRES_PASSWORD=cv002 -e POSTGRES_DB=soybean_admin_rust \
    postgres:17-alpine >/dev/null
  echo "  cv002-rev3-pg 啟動，等待 pg ready…"
  wait_pg cv002-rev3-pg
  echo "  跑 rev3 migration up -n 2（停在 m002 檢查點）…"
  eval "$RUN_MIG" cargo run --bin migration -- up -n 2 \
    || fail "rev3 migration up -n 2 失敗"
else
  echo "── --reuse：對既有 cv002-rev3-pg 重跑（不建庫）──"
  docker inspect cv002-rev3-pg >/dev/null 2>&1 || fail "--reuse 但 cv002-rev3-pg 不存在"
fi

# ── 雙 diff（normalize 後）──
echo "── 雙 diff（schema / seed 零差異斷言）──"
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --schema-only --no-owner \
  | bash "$NORMALIZE" schema > /tmp/cv002-rev3-schema.sql
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t sys_menu -t casbin_rule -t system_settings \
  | bash "$NORMALIZE" data > /tmp/cv002-rev3-data.sql

if diff /tmp/cv002-rev2-schema.sql /tmp/cv002-rev3-schema.sql; then
  echo "SCHEMA 零差異 ✅"
else
  fail "SCHEMA diff 非零（先對 migration-chain.md §3 判假紅 vs 真 drift；真 drift 修 m001 重跑、不得調 normalize）"
fi
if diff /tmp/cv002-rev2-data.sql /tmp/cv002-rev3-data.sql; then
  echo "SEED 零差異 ✅"
else
  fail "SEED diff 非零（先判假紅 vs 真 drift；真 drift 修 m002 重跑、不得調 normalize）"
fi

# ── 計數不變式（C-V-3 全集）──
# 注：sys_user_id_seq 為 sequence 關係，`SELECT last_value||','||is_called` 字串拼接時
#     is_called 輸出 `true`（非分欄查詢的 `t`）——序列關係特有形；rev2 重放庫與 rev3 兩側
#     皆 `3,true`、值一致（last_value=3／is_called=true），期望值對齊此實際輸出。
echo "── 計數不變式 ──"
assert_eq() { # $1=label $2=actual $3=expect
  [ "$2" = "$3" ] && echo "  $1 = $2 ✅" || fail "$1 = $2 ≠ 期望 $3"
}
assert_eq "sys_user count"                "$(P "SELECT count(*) FROM sys_user;")"                                            3
assert_eq "sys_role count"                "$(P "SELECT count(*) FROM sys_role;")"                                            3
assert_eq "sys_user_role count"           "$(P "SELECT count(*) FROM sys_user_role;")"                                       3
assert_eq "sys_menu count"                "$(P "SELECT count(*) FROM sys_menu;")"                                            10
assert_eq "casbin_rule count"             "$(P "SELECT count(*) FROM casbin_rule;")"                                        72
assert_eq "system_settings count"         "$(P "SELECT count(*) FROM system_settings;")"                                     1
assert_eq "casbin ptype=p"                "$(P "SELECT count(*) FROM casbin_rule WHERE ptype='p';")"                        72
assert_eq "casbin protected"              "$(P "SELECT count(*) FROM casbin_rule WHERE protected;")"                        19
assert_eq "sys_menu protected"            "$(P "SELECT count(*) FROM sys_menu WHERE protected;")"                            8
assert_eq "sys_user id set"               "$(P "SELECT string_agg(id::text,',' ORDER BY id) FROM sys_user;")"           "1,2,3"
assert_eq "sys_user_id_seq last/is_called" "$(P "SELECT last_value||','||is_called FROM sys_user_id_seq;")"            "3,true"
assert_eq "distinct password"             "$(P "SELECT count(DISTINCT password) FROM sys_user;")"                            1
assert_eq "argon2 前綴 ×3"                "$(P "SELECT count(*) FROM sys_user WHERE password LIKE '\$argon2id\$v=19\$%';")"    3

# ── C-V-4 比對基準留存（M3 全量驗的 before 側）──
echo "── 留存 C-V-4 比對基準 ──"
docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM sys_menu WHERE id<=10) t;" \
  | tr -d '[:space:]' > /tmp/cv002-md5-menu10.txt
docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM casbin_rule WHERE id<=72) t;" \
  | tr -d '[:space:]' > /tmp/cv002-md5-casbin72.txt
docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t system_settings \
  | bash "$NORMALIZE" data > /tmp/cv002-rev3-static4.sql
echo "  /tmp/cv002-md5-menu10.txt /tmp/cv002-md5-casbin72.txt /tmp/cv002-rev3-static4.sql 留存 ✅"

# ── 密碼可驗性 3/3（SC-004；env 注入避 $ 二次展開——H2 修）──
echo "── VERIFY 密碼可驗性 3/3 ──"
VERIFY_OK=0
for ID in 1 2 3; do
  HASH=$(docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc "SELECT password FROM sys_user WHERE id=$ID;" | tr -d '[:space:]')
  if docker run --rm -e HASH="$HASH" -e ID="$ID" python:3.12-slim sh -c \
       'pip install -q argon2-cffi && python -c "import os; from argon2 import PasswordHasher; PasswordHasher().verify(os.environ[\"HASH\"],\"123456\"); print(\"VERIFY-OK\",os.environ[\"ID\"])"'; then
    VERIFY_OK=$((VERIFY_OK + 1))
  else
    fail "id=$ID 密碼 123456 驗證失敗（檢查 env 注入形、禁把 \$HASH 內嵌雙引號字串）"
  fi
done
[ "$VERIFY_OK" = "3" ] || fail "VERIFY 僅 $VERIFY_OK/3 通過"
echo "  VERIFY-OK ×3 ✅"

echo ""
echo "✅ diff-baseline 全綠：SCHEMA 零差異 + SEED 零差異 + 計數不變式 + VERIFY 3/3"
