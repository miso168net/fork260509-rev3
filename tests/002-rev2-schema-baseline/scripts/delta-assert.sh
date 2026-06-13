#!/usr/bin/env bash
# delta-assert.sh — delta（m003+m004）套用後斷言全集
#
# 用法：
#   delta-assert.sh [cv002]   # 預設；docker exec cv002-rev3-pg（含排除式 data-diff 全量驗）……C-V-4
#   delta-assert.sh stack     # host psql 35432（僅計數斷言、無 dump 需求）……C-V-7 stack 模式
#
# 前置（cv002 模式）：cv002-rev3-pg 已套 m003+m004（delta 已 up）；
#                     C-V-3 比對基準在 /tmp（md5-menu10 / md5-casbin72 / cv002-rev3-static4.sql）。
# 無建庫副作用。exit 0 ＝ 全綠。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS="$ROOT/tests/002-rev2-schema-baseline/scripts"
NORMALIZE="$SCRIPTS/normalize.sh"

MODE="${1:-cv002}"
case "$MODE" in
  cv002|stack) ;;
  *) echo "delta-assert.sh: 用法 delta-assert.sh [cv002|stack]（預設 cv002）" >&2; exit 2 ;;
esac

fail() { echo "❌ delta-assert($MODE): $*" >&2; exit 1; }
assert_eq() { # $1=label $2=actual $3=expect
  [ "$2" = "$3" ] && echo "  $1 = $2 ✅" || fail "$1 = $2 ≠ 期望 $3"
}

# ─────────────────────────────────────────────────────────────
# stack 模式：host psql 35432（僅計數斷言）……C-V-7
# ─────────────────────────────────────────────────────────────
if [ "$MODE" = "stack" ]; then
  echo "── delta-assert stack（host psql 35432、僅計數斷言）──"
  SECRET="$ROOT/deploy/secrets/postgres_password.txt"
  [ -f "$SECRET" ] || fail "找不到 $SECRET（dev stack secret）"
  PG() { PGPASSWORD=$(cat "$SECRET") psql -h 127.0.0.1 -p 35432 -U soybean -d soybean_admin_rust -tAc "$1" | tr -d '[:space:]'; }

  assert_eq "public 表數"        "$(PG "SELECT count(*) FROM pg_tables WHERE schemaname='public';")"                        12
  assert_eq "sys_user"           "$(PG "SELECT count(*) FROM sys_user;")"                                                    3
  assert_eq "sys_role"           "$(PG "SELECT count(*) FROM sys_role;")"                                                    3
  assert_eq "sys_user_role"      "$(PG "SELECT count(*) FROM sys_user_role;")"                                               3
  assert_eq "system_settings"    "$(PG "SELECT count(*) FROM system_settings;")"                                            1
  assert_eq "sys_menu"           "$(PG "SELECT count(*) FROM sys_menu;")"                                                   76
  assert_eq "casbin_rule"        "$(PG "SELECT count(*) FROM casbin_rule;")"                                               138
  assert_eq "casbin v2=menu"     "$(PG "SELECT count(*) FROM casbin_rule WHERE v2='menu';")"                               83
  assert_eq "casbin protected"   "$(PG "SELECT count(*) FROM casbin_rule WHERE protected;")"                               19
  assert_eq "sys_menu protected" "$(PG "SELECT count(*) FROM sys_menu WHERE protected;")"                                   8
  assert_eq "FK 數"              "$(PG "SELECT count(*) FROM pg_constraint WHERE contype='f';")"                             2
  echo ""
  echo "✅ delta-assert stack 全綠（計數斷言集 3/3/3/1/76/138/83/19/8/FK=2、public 12 表）"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# cv002 模式：docker exec cv002-rev3-pg（含排除式 data-diff 全量驗）……C-V-4
# ─────────────────────────────────────────────────────────────
echo "── delta-assert cv002（cv002-rev3-pg、delta 全量斷言）──"
docker inspect cv002-rev3-pg >/dev/null 2>&1 || fail "cv002-rev3-pg 不存在（先跑 diff-baseline.sh + delta up）"
P() { docker exec cv002-rev3-pg psql -U soybean -d soybean_admin_rust -tAc "$1" | tr -d '[:space:]'; }

# ── FK 斷言（m003）──
assert_eq "FK 數(contype=f)"            "$(P "SELECT count(*) FROM pg_constraint WHERE contype='f';")"                      2
assert_eq "FK RESTRICT(confdeltype=r)"  "$(P "SELECT count(*) FROM pg_constraint WHERE contype='f' AND confdeltype='r';")"  2

# ── menu / casbin 計數（m004）──
assert_eq "sys_menu"        "$(P "SELECT count(*) FROM sys_menu;")"                  76
assert_eq "casbin_rule"     "$(P "SELECT count(*) FROM casbin_rule;")"             138
assert_eq "casbin v2=menu"  "$(P "SELECT count(*) FROM casbin_rule WHERE v2='menu';")" 83

# ── FR-006 直接斷言：demo 66 列 policy 全部且僅授 R_SUPER（M2 修）──
assert_eq "demo policy R_SUPER 66" \
  "$(P "SELECT count(*) FROM casbin_rule WHERE ptype='p' AND v2='menu' AND v0='R_SUPER' AND v1 IN (SELECT route_name FROM sys_menu WHERE id>10);")" \
  66
assert_eq "demo policy 非 R_SUPER 0" \
  "$(P "SELECT count(*) FROM casbin_rule WHERE v2='menu' AND v0<>'R_SUPER' AND v1 IN (SELECT route_name FROM sys_menu WHERE id>10);")" \
  0

# ── 基線全量不變（M3 修——排除式全量驗）──
echo "── 基線全量不變（靜態 4 表 diff + menu/casbin md5 對 C-V-3 留存值）──"
[ -f /tmp/cv002-rev3-static4.sql ] || fail "/tmp/cv002-rev3-static4.sql 不在（先跑 diff-baseline.sh 留存 before 側）"
[ -f /tmp/cv002-md5-menu10.txt ]   || fail "/tmp/cv002-md5-menu10.txt 不在（先跑 diff-baseline.sh）"
[ -f /tmp/cv002-md5-casbin72.txt ] || fail "/tmp/cv002-md5-casbin72.txt 不在（先跑 diff-baseline.sh）"

docker exec cv002-rev3-pg pg_dump -U soybean -d soybean_admin_rust --data-only --no-owner \
  -t sys_user -t sys_role -t sys_user_role -t system_settings \
  | bash "$NORMALIZE" data > /tmp/cv002-delta-static4.sql
if diff /tmp/cv002-rev3-static4.sql /tmp/cv002-delta-static4.sql; then
  echo "靜態 4 表全量不變 ✅"
else
  fail "靜態 4 表 diff 非零（m004 誤改基線列、檢查 UPDATE/DELETE 範圍）"
fi

# sys_menu / casbin_rule（delta 有新增）排除新增列後 checksum 對 C-V-3 留存值
MENU10_NOW=$(P "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM sys_menu WHERE id<=10) t;")
CASBIN72_NOW=$(P "SELECT md5(string_agg(t::text,'|' ORDER BY id)) FROM (SELECT * FROM casbin_rule WHERE id<=72) t;")
assert_eq "sys_menu id<=10 md5"   "$MENU10_NOW"   "$(cat /tmp/cv002-md5-menu10.txt)"
assert_eq "casbin id<=72 md5"     "$CASBIN72_NOW" "$(cat /tmp/cv002-md5-casbin72.txt)"

echo ""
echo "✅ delta-assert cv002 全綠：FK=2(RESTRICT)、menu76/casbin138(menu維83)、demo 66 僅 R_SUPER、基線全量不變"
